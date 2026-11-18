import json

from .model_client import validate_tool_request


def _valid_identifier(value):

    return type(value) is int and value > 0


def record_model_tool_request(
    cursor,
    interaction_id,
    model_execution_id,
    tool_request
):

    if not (
        _valid_identifier(interaction_id)
        and _valid_identifier(model_execution_id)
    ):

        raise ValueError(
            "Invalid model proposal identifiers."
        )

    tool_request = validate_tool_request(tool_request)

    cursor.execute(
        """
        EXEC aiaf.usp_RecordModelToolRequest
            @InteractionId = ?,
            @ModelExecutionId = ?,
            @ToolCode = ?,
            @CustomerCode = ?;
        """,
        interaction_id,
        model_execution_id,
        tool_request["ToolCode"],
        tool_request["CustomerCode"]
    )

    row = cursor.fetchone()

    if row is None:

        raise RuntimeError(
            "Model proposal persistence returned no evidence."
        )

    proposal = {
        "ModelToolRequestId": row[0],
        "ModelExecutionId": row[1],
        "InteractionId": row[2],
        "ToolCode": row[3],
        "RequestArguments": row[4],
        "RequestedAt": row[5],
        "AuthorizationDecision": row[6]
    }

    if not (
        _valid_identifier(proposal["ModelToolRequestId"])
        and _valid_identifier(proposal["ModelExecutionId"])
        and _valid_identifier(proposal["InteractionId"])
        and proposal["InteractionId"] == interaction_id
        and proposal["ModelExecutionId"] == model_execution_id
        and proposal["ToolCode"] == tool_request["ToolCode"]
        and proposal["AuthorizationDecision"] == "NOT_EVALUATED"
    ):

        raise RuntimeError(
            "Model proposal evidence mismatch."
        )

    try:

        arguments = json.loads(
            proposal["RequestArguments"]
        )

    except (ValueError, TypeError):

        raise RuntimeError(
            "Invalid persisted model proposal arguments."
        ) from None

    if (
        not isinstance(arguments, dict)
        or arguments != {
            "CustomerCode": tool_request["CustomerCode"]
        }
    ):

        raise RuntimeError(
            "Model proposal arguments mismatch."
        )

    return proposal


def execute_tool(cursor, proposal):

    interaction_id = proposal.get("InteractionId")
    model_tool_request_id = proposal.get("ModelToolRequestId")
    tool_code = proposal.get("ToolCode")

    if not (
        _valid_identifier(interaction_id)
        and _valid_identifier(model_tool_request_id)
    ):

        raise ValueError(
            "Invalid tool execution identifiers."
        )

    if tool_code == "NO_SUPPORTED_TOOL":

        return {
            "InteractionId": interaction_id,
            "ModelToolRequestId": model_tool_request_id,
            "ToolCode": tool_code,
            "AuthorizationDecision": "NOT_EVALUATED",
            "AuthorizationReason": "NO_SUPPORTED_TOOL",
            "ExecutionStatus": "NOT_EXECUTED",
            "RowsReturned": 0,
            "Data": []
        }

    if tool_code != "GetCustomerBalance":

        raise ValueError("Unsupported tool requested.")

    cursor.execute(
        """
        EXEC aiaf_tool.GetCustomerBalance
            @InteractionId = ?,
            @ModelToolRequestId = ?;
        """,
        interaction_id,
        model_tool_request_id
    )

    row = cursor.fetchone()

    if row is None:

        raise RuntimeError(
            "Tool returned no authorization evidence."
        )

    result = {
        "InteractionId": row[0],
        "ModelToolRequestId": model_tool_request_id,
        "AIToolCallId": row[1],
        "ToolCode": tool_code,
        "AuthorizationDecision": row[2],
        "AuthorizationReason": row[3],
        "ExecutionStatus": row[4],
        "RowsReturned": row[5],
        "Data": []
    }

    if not (
        _valid_identifier(result["InteractionId"])
        and result["InteractionId"] == interaction_id
        and _valid_identifier(result["AIToolCallId"])
        and type(result["RowsReturned"]) is int
        and result["RowsReturned"] >= 0
    ):

        raise RuntimeError(
            "Tool execution evidence mismatch."
        )

    valid_outcomes = {
        ("ALLOWED", "SUCCEEDED"),
        ("ALLOWED", "FAILED"),
        ("DENIED", "NOT_EXECUTED"),
        ("ERROR", "NOT_EXECUTED")
    }

    outcome = (
        result["AuthorizationDecision"],
        result["ExecutionStatus"]
    )

    if outcome not in valid_outcomes:

        raise RuntimeError(
            "Invalid tool execution outcome."
        )

    if outcome == ("ALLOWED", "SUCCEEDED"):

        if not cursor.nextset() or cursor.description is None:

            raise RuntimeError(
                "Expected tool result set is missing."
            )

        columns = [
            column[0]
            for column in cursor.description
        ]

        if len(columns) != len(set(columns)):

            raise RuntimeError(
                "Duplicate tool result columns."
            )

        records = cursor.fetchall()

        if len(records) != result["RowsReturned"]:

            raise RuntimeError(
                "Tool result count mismatch."
            )

        if any(
            len(record) != len(columns)
            for record in records
        ):

            raise RuntimeError(
                "Tool result column count mismatch."
            )

        result["Data"] = [
            dict(zip(columns, record))
            for record in records
        ]

    elif result["RowsReturned"] != 0:

        raise RuntimeError(
            "Unexpected rows for unsuccessful tool execution."
        )

    return result