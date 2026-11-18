import json
import logging

from contextlib import closing

from .database import get_connection
from .input_validation import sanitize_input
from .model_client import request_tool
from .interaction_lifecycle import complete_interaction

from .response_formatter import (
    format_customer_balance,
    format_rejection
)

from .output_validation import (
    validate_output,
    record_output_validation
)

from .tool_dispatcher import (
    record_model_tool_request,
    execute_tool
)


logger = logging.getLogger(__name__)

def _valid_identifier(value):

    return type(value) is int and value > 0


def _valid_count(value):

    return type(value) is int and value >= 0

def begin_interaction(
    cursor,
    application_code,
    requesting_identity,
    workflow_code,
    business_purpose
):

    cursor.execute("""
        DECLARE
            @InteractionId bigint,
            @CorrelationId varchar(100),
            @GateDecision varchar(20),
            @GateReason varchar(100);

        EXEC aiaf.usp_BeginInteraction
            @ApplicationCode = ?,
            @RequestingIdentity = ?,
            @WorkflowCode = ?,
            @BusinessPurpose = ?,
            @InteractionId = @InteractionId OUTPUT,
            @CorrelationId = @CorrelationId OUTPUT,
            @GateDecision = @GateDecision OUTPUT,
            @GateReason = @GateReason OUTPUT;

        SELECT
            @InteractionId,
            @CorrelationId,
            @GateDecision,
            @GateReason;
    """,
        application_code,
        requesting_identity,
        workflow_code,
        business_purpose
    )

    row = cursor.fetchone()

    if row is None:

        raise RuntimeError(
            "Interaction initialization returned no evidence."
        )

    evidence = {
        "InteractionId": row[0],
        "CorrelationId": row[1],
        "GateDecision": row[2],
        "GateReason": row[3]
    }

    if not (
        _valid_identifier(evidence["InteractionId"])
        and isinstance(evidence["CorrelationId"], str)
        and evidence["CorrelationId"].strip()
        and evidence["GateDecision"] in ("ALLOWED", "DENIED")
        and isinstance(evidence["GateReason"], str)
        and evidence["GateReason"].strip()
    ):

        raise RuntimeError(
            "Invalid interaction initialization evidence."
        )

    if (
        evidence["GateDecision"] == "ALLOWED"
        and evidence["GateReason"] != "GOVERNANCE_APPROVED"
    ):

        raise RuntimeError(
            "Invalid governance approval evidence."
        )

    return evidence

def record_input_validation(cursor, interaction_id, findings):

    cursor.execute("""
        EXEC aiaf.usp_RecordInputValidation
            @InteractionId = ?,
            @Findings = ?;
    """,
        interaction_id,
        json.dumps(findings)
    )

    row = cursor.fetchone()

    if row is None:

        raise RuntimeError(
            "Input validation persistence returned no evidence."
        )

    evidence = {
        "InteractionId": row[0],
        "ValidationDecision": row[1],
        "DetectionCount": row[2],
        "InteractionStatus": row[3]
    }

    if not (
        _valid_identifier(interaction_id)
        and _valid_identifier(evidence["InteractionId"])
        and evidence["InteractionId"] == interaction_id
        and _valid_count(evidence["DetectionCount"])
        and evidence["ValidationDecision"] in (
            "PASSED",
            "SANITIZED"
        )
        and evidence["InteractionStatus"] == "PROCESSING"
    ):

        raise RuntimeError(
            "Invalid input validation persistence evidence."
        )

    expected_decision = (
        "SANITIZED"
        if evidence["DetectionCount"] > 0
        else "PASSED"
    )

    if evidence["ValidationDecision"] != expected_decision:

        raise RuntimeError(
            "Inconsistent input validation evidence."
        )

    return evidence

def record_model_execution(
    cursor,
    interaction_id,
    execution,
    execution_environment
):

    cursor.execute(
        """
        EXEC aiaf.usp_RecordModelExecution
            @InteractionId = ?,
            @ModelProvider = ?,
            @ModelName = ?,
            @ModelVersion = ?,
            @PromptVersion = ?,
            @ExecutionPurpose = ?,
            @ExecutionEnvironment = ?,
            @TelemetrySource = ?,
            @StartedAt = ?,
            @CompletedAt = ?,
            @DurationMs = ?,
            @ModelLoadDurationMs = ?,
            @ServerDurationMs = ?,
            @PromptEvalDurationMs = ?,
            @OutputEvalDurationMs = ?,
            @InputTokens = ?,
            @OutputTokens = ?,
            @CachedInputTokens = ?,
            @CurrencyCode = ?,
            @InputCost = ?,
            @OutputCost = ?,
            @OtherCost = ?,
            @CostBasis = ?,
            @PricingReference = ?,
            @ExecutionStatus = ?,
            @ResponseValidationDecision = ?,
            @ErrorCode = ?;
        """,
        interaction_id,
        execution["ModelProvider"],
        execution["ModelName"],
        execution["ModelVersion"],
        execution["PromptVersion"],
        execution["ExecutionPurpose"],
        execution_environment,
        "LIVE",
        execution["StartedAt"],
        execution["CompletedAt"],
        execution["DurationMs"],
        execution["ModelLoadDurationMs"],
        execution["ServerDurationMs"],
        execution["PromptEvalDurationMs"],
        execution["OutputEvalDurationMs"],
        execution["InputTokens"],
        execution["OutputTokens"],
        execution["CachedInputTokens"],
        execution["CurrencyCode"],
        execution["InputCost"],
        execution["OutputCost"],
        execution["OtherCost"],
        execution["CostBasis"],
        execution["PricingReference"],
        execution["ExecutionStatus"],
        execution["ResponseValidationDecision"],
        execution["ErrorCode"]
    )

    row = cursor.fetchone()

    if row is None:

        raise RuntimeError(
            "Model execution persistence returned no evidence."
        )

    evidence = {
        "ModelExecutionId": row[0],
        "InteractionId": row[1],
        "ExecutionStatus": row[2],
        "ResponseValidationDecision": row[3],
        "InputTokens": row[4],
        "OutputTokens": row[5],
        "TotalCost": row[6],
        "CurrencyCode": row[7],
        "CostBasis": row[8]
    }

    if not (
        _valid_identifier(interaction_id)
        and _valid_identifier(evidence["ModelExecutionId"])
        and _valid_identifier(evidence["InteractionId"])
        and evidence["InteractionId"] == interaction_id
        and evidence["ExecutionStatus"]
            == execution["ExecutionStatus"]
        and evidence["ResponseValidationDecision"]
            == execution["ResponseValidationDecision"]
    ):

        raise RuntimeError(
            "Invalid model execution persistence evidence."
        )

    for field in ("InputTokens", "OutputTokens"):

        if evidence[field] is not None:

            if not _valid_count(evidence[field]):

                raise RuntimeError(
                    "Invalid model token telemetry."
                )

    return evidence

def process_request(
    raw_prompt,
    *,
    application_code,
    requesting_identity,
    workflow_code,
    business_purpose,
    execution_environment="DEVELOPMENT"
):

    request_context = {
        "ApplicationCode": (application_code, 100),
        "RequestingIdentity": (requesting_identity, 1024),
        "WorkflowCode": (workflow_code, 100),
        "BusinessPurpose": (business_purpose, 2000)
    }

    for field, (value, max_length) in request_context.items():

        if (
            not isinstance(value, str)
            or not value.strip()
            or len(value) > max_length
        ):

            raise ValueError(
                f"Invalid request context: {field}."
            )

    if execution_environment not in (
        "DEVELOPMENT",
        "TEST",
        "QA",
        "PRODUCTION"
    ):

        raise ValueError(
            "Invalid execution environment."
        )

    if not isinstance(raw_prompt, str) or not raw_prompt.strip():

        raise ValueError(
            "A nonempty request is required."
        )

    try:
        with closing(get_connection()) as conn:
            with closing(conn.cursor()) as cursor:
                response = _process_request(
                    cursor,
                    raw_prompt,
                    application_code=application_code,
                    requesting_identity=requesting_identity,
                    workflow_code=workflow_code,
                    business_purpose=business_purpose,
                    execution_environment=execution_environment
                )
        return response
    except Exception:
        # Never emit raw exception messages or tracebacks here.
        logger.error("Request processing failed.")
        return format_rejection(None)


def _process_request(
    cursor,
    raw_prompt,
    *,
    application_code,
    requesting_identity,
    workflow_code,
    business_purpose,
    execution_environment
):
    tool_result = None

    def finalize_request(interaction_id):
        completion = complete_interaction(cursor, interaction_id)
        if not (
            _valid_identifier(completion["InteractionId"])
            and completion["InteractionId"] == interaction_id
            and completion["InteractionStatus"] in (
                "COMPLETED", "BLOCKED", "FAILED"
            )
        ):
            raise RuntimeError("Invalid completion evidence.")
        logger.info(
            "Interaction finalized: interaction_id=%s status=%s",
            interaction_id,
            completion["InteractionStatus"]
        )
        return completion

    try:
        # Step 1: Begin interaction and evaluate governance.

        interaction = begin_interaction(
            cursor,
            application_code,
            requesting_identity,
            workflow_code,
            business_purpose
        )

        logger.info(
            "Governance evaluated: interaction_id=%s decision=%s",
            interaction["InteractionId"],
            interaction["GateDecision"]
        )

        if interaction["GateDecision"] != "ALLOWED":

            logger.warning(
                "Interaction blocked by governance."
            )

            return (
                "This application is not currently "
                "authorized to process the request."
            )

        interaction_id = interaction["InteractionId"]

        # Step 2: Classify and sanitize input.

        validation = sanitize_input(raw_prompt)

        # Step 3: Persist input validation evidence.

        evidence = record_input_validation(
            cursor,
            interaction_id,
            validation["Findings"]
        )

        logger.info(
            "Input validation: interaction_id=%s decision=%s detections=%s",
            interaction_id,
            evidence["ValidationDecision"],
            evidence["DetectionCount"]
        )

        if not (
            _valid_identifier(evidence["InteractionId"])
            and evidence["InteractionId"] == interaction_id
            and evidence["InteractionStatus"] == "PROCESSING"
            and evidence["ValidationDecision"] in (
                "PASSED",
                "SANITIZED"
            )
            and evidence["ValidationDecision"]
                == validation["ValidationDecision"]
            and _valid_count(evidence["DetectionCount"])
            and evidence["DetectionCount"] == sum(
                finding["DetectionCount"]
                for finding in validation["Findings"]
            )
        ):

            raise RuntimeError(
                "Input validation evidence mismatch."
            )

        # Step 4: Execute the model.

        execution = request_tool(
            validation["SanitizedContent"]
        )

        # Step 5: Record model execution telemetry.
        # Audit both successful and failed executions.

        model_evidence = record_model_execution(
            cursor,
            interaction_id,
            execution,
            execution_environment
        )

        logger.info(
            "Model execution: interaction_id=%s status=%s validation=%s",
            interaction_id,
            model_evidence["ExecutionStatus"],
            model_evidence["ResponseValidationDecision"]
        )

        # Step 6: Evaluate execution outcome.

        if (
            model_evidence["InteractionId"] != interaction_id
            or model_evidence["ExecutionStatus"] != execution["ExecutionStatus"]
            or model_evidence["ResponseValidationDecision"]
                != execution["ResponseValidationDecision"]
        ):
            raise RuntimeError("Model execution evidence mismatch.")

        if (
            model_evidence["ExecutionStatus"] != "SUCCEEDED"
            or model_evidence["ResponseValidationDecision"] != "PASSED"
        ):
            completion = finalize_request(interaction_id)
            return format_rejection(completion["CompletionReason"])

        # Step 7: Persist the validated model proposal.

        proposal = record_model_tool_request(
            cursor,
            interaction_id,
            model_evidence["ModelExecutionId"],
            execution["ToolRequest"]
        )

        logger.info(
            "Model proposal recorded: interaction_id=%s proposal_id=%s",
            interaction_id,
            proposal["ModelToolRequestId"]
        )

        # Step 8: Execute using the recorded proposal.

        tool_result = execute_tool(
            cursor,
            proposal
        )

        # Step 9: Log controlled execution metadata.

        logger.info(
            "Tool execution: interaction_id=%s authorization=%s status=%s",
            interaction_id,
            tool_result["AuthorizationDecision"],
            tool_result["ExecutionStatus"]
        )

        # Step 10: Determine whether financial output
        # is eligible for validation.

        if (
            tool_result["AuthorizationDecision"] != "ALLOWED"
            or tool_result["ExecutionStatus"] != "SUCCEEDED"
        ):

            logger.info(
                "Output validation not required."
            )

            completion = finalize_request(interaction_id)

            return format_rejection(
                completion["CompletionReason"]
            )

        # Step 11: Validate the financial output.

        validation = validate_output(
            proposal,
            tool_result
        )

        # Step 12: Persist output validation evidence.

        output_evidence = record_output_validation(
            cursor,
            interaction_id,
            tool_result["AIToolCallId"],
            validation["Findings"]
        )

        # Step 13: Verify persisted evidence.

        if not (
            _valid_identifier(
                output_evidence["InteractionId"]
            )
            and output_evidence["InteractionId"]
                == interaction_id
            and _valid_identifier(
                output_evidence["AIToolCallId"]
            )
            and _valid_identifier(
                tool_result["AIToolCallId"]
            )
            and output_evidence["AIToolCallId"]
                == tool_result["AIToolCallId"]
            and output_evidence["ValidationDecision"] in (
                "PASSED",
                "BLOCKED"
            )
            and output_evidence["ValidationDecision"]
                == validation["ValidationDecision"]
            and _valid_count(
                output_evidence["DetectionCount"]
            )
            and _valid_count(
                validation["DetectionCount"]
            )
            and output_evidence["DetectionCount"]
                == validation["DetectionCount"]
            and (
                (
                    output_evidence["ValidationDecision"]
                        == "PASSED"
                    and output_evidence["DetectionCount"] == 0
                )
                or
                (
                    output_evidence["ValidationDecision"]
                        == "BLOCKED"
                    and output_evidence["DetectionCount"] > 0
                )
            )
        ):

            raise RuntimeError(
                "Output validation evidence mismatch."
            )

        logger.info(
            "Output validation: interaction_id=%s decision=%s detections=%s",
            interaction_id,
            output_evidence["ValidationDecision"],
            output_evidence["DetectionCount"]
        )

        # Step 14: Finalize the interaction.

        completion = finalize_request(interaction_id)

        # Step 15: Enforce the release boundary.

        if not (
            _valid_identifier(completion["InteractionId"])
            and completion["InteractionId"] == interaction_id
            and validation["ValidationDecision"] == "PASSED"
            and output_evidence["ValidationDecision"] == "PASSED"
            and _valid_count(validation["DetectionCount"])
            and validation["DetectionCount"] == 0
            and _valid_count(output_evidence["DetectionCount"])
            and output_evidence["DetectionCount"] == 0
            and completion["InteractionStatus"] == "COMPLETED"
            and completion["CompletionReason"]
                == "OUTPUT_APPROVED_FOR_RELEASE"
            and tool_result["AuthorizationDecision"] == "ALLOWED"
            and tool_result["ExecutionStatus"] == "SUCCEEDED"
            and _valid_count(tool_result["RowsReturned"])
            and tool_result["RowsReturned"] == 1
            and isinstance(tool_result["Data"], list)
            and len(tool_result["Data"]) == 1
        ):

            logger.warning(
                "Output blocked: interaction_id=%s",
                interaction_id
            )

            return format_rejection(
                "OUTPUT_VALIDATION_BLOCKED"
            )

        # Step 16: Format the authorized response.

        logger.info(
            "Output approved for release: interaction_id=%s",
            interaction_id
        )

        response = format_customer_balance(
            tool_result["Data"][0]
        )

        return response
    finally:
        if isinstance(tool_result, dict):
            data = tool_result.get("Data")
            if isinstance(data, list):
                data.clear()
