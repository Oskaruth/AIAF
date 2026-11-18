import unittest
from decimal import Decimal

from unittest.mock import MagicMock, patch

from aiaf.pipeline import process_request


class TestPipeline(unittest.TestCase):

    def setUp(self):

        self.context = {
            "application_code": "ACME_ACCOUNTS_RECEIVABLE_AI",
            "requesting_identity": "Jeannine",
            "workflow_code": "CUSTOMER_BALANCE",
            "business_purpose": "Review customer balance",
            "execution_environment": "TEST"
        }

        self.prompt = (
            "What is the outstanding balance for CUST-1001?"
        )

        self.connection = MagicMock()
        self.cursor = MagicMock()

        self.connection.cursor.return_value = self.cursor

        self.safe_rejection = (
            "The request could not be completed."
        )

    @patch("aiaf.pipeline.get_connection")
    def test_invalid_request_context(self, connect):

        for field in self.context:

            for value in (None, "", " ", 123):

                with self.subTest(field=field, value=value):

                    context = self.context.copy()
                    context[field] = value

                    with self.assertRaises(ValueError):

                        process_request(
                            self.prompt,
                            **context
                        )

        connect.assert_not_called()

    @patch("aiaf.pipeline.get_connection")
    def test_invalid_prompt(self, connect):

        for prompt in (None, "", " ", 123):

            with self.subTest(prompt=prompt):

                with self.assertRaises(ValueError):

                    process_request(
                        prompt,
                        **self.context
                    )

        connect.assert_not_called()

    @patch("aiaf.pipeline.get_connection")
    def test_invalid_execution_environment(self, connect):

        context = self.context.copy()
        context["execution_environment"] = "UNKNOWN"

        with self.assertRaises(ValueError):

            process_request(
                self.prompt,
                **context
            )

        connect.assert_not_called()

    @patch("aiaf.pipeline.get_connection")
    def test_connection_failure(self, connect):

        connect.side_effect = RuntimeError(
            "SENSITIVE_DATABASE_ERROR"
        )

        with self.assertLogs("aiaf.pipeline", level="ERROR") as logs:

            response = process_request(
                self.prompt,
                **self.context
            )

        self.assertEqual(response, self.safe_rejection)

        self.assertNotIn(
            "SENSITIVE_DATABASE_ERROR",
            "\n".join(logs.output)
        )

    @patch("aiaf.pipeline.get_connection")
    def test_cursor_creation_failure(self, connect):

        connect.return_value = self.connection

        self.connection.cursor.side_effect = RuntimeError(
            "Cursor creation failed."
        )

        with self.assertLogs("aiaf.pipeline", level="ERROR"):

            response = process_request(
                self.prompt,
                **self.context
            )

        self.assertEqual(response, self.safe_rejection)

        self.connection.close.assert_called_once()

    @patch("aiaf.pipeline._process_request")
    @patch("aiaf.pipeline.get_connection")
    def test_successful_resource_cleanup(
        self,
        connect,
        orchestrate
    ):

        connect.return_value = self.connection

        orchestrate.return_value = "Approved response."

        response = process_request(
            self.prompt,
            **self.context
        )

        self.assertEqual(response, "Approved response.")

        self.cursor.close.assert_called_once()
        self.connection.close.assert_called_once()

        orchestrate.assert_called_once_with(
            self.cursor,
            self.prompt,
            **self.context
        )

    @patch("aiaf.pipeline._process_request")
    @patch("aiaf.pipeline.get_connection")
    def test_cleanup_after_processing_failure(
        self,
        connect,
        orchestrate
    ):

        connect.return_value = self.connection

        orchestrate.side_effect = RuntimeError(
            "SENSITIVE_PROCESSING_ERROR"
        )

        with self.assertLogs("aiaf.pipeline", level="ERROR") as logs:

            response = process_request(
                self.prompt,
                **self.context
            )

        self.assertEqual(response, self.safe_rejection)

        self.cursor.close.assert_called_once()
        self.connection.close.assert_called_once()

        self.assertNotIn(
            "SENSITIVE_PROCESSING_ERROR",
            "\n".join(logs.output)
        )

    @patch("aiaf.pipeline._process_request")
    @patch("aiaf.pipeline.get_connection")
    def test_cursor_cleanup_failure_prevents_release(
        self,
        connect,
        orchestrate
    ):

        connect.return_value = self.connection

        orchestrate.return_value = "SENSITIVE_APPROVED_DATA"

        self.cursor.close.side_effect = RuntimeError(
            "Cursor cleanup failed."
        )

        with self.assertLogs("aiaf.pipeline", level="ERROR"):

            response = process_request(
                self.prompt,
                **self.context
            )

        self.assertEqual(response, self.safe_rejection)

        self.connection.close.assert_called_once()

    @patch("aiaf.pipeline._process_request")
    @patch("aiaf.pipeline.get_connection")
    def test_connection_cleanup_failure_prevents_release(
        self,
        connect,
        orchestrate
    ):

        connect.return_value = self.connection

        orchestrate.return_value = "SENSITIVE_APPROVED_DATA"

        self.connection.close.side_effect = RuntimeError(
            "Connection cleanup failed."
        )

        with self.assertLogs("aiaf.pipeline", level="ERROR"):

            response = process_request(
                self.prompt,
                **self.context
            )

        self.assertEqual(response, self.safe_rejection)

        self.cursor.close.assert_called_once()
        self.connection.close.assert_called_once()

class TestPipelineOrchestration(unittest.TestCase):

    def configure_approved_governance(self):

        self.mocks["begin_interaction"].return_value = {
            "InteractionId": 1001,
            "CorrelationId": "test-correlation-id",
            "GateDecision": "ALLOWED",
            "GateReason": "GOVERNANCE_APPROVED"
        }

    def configure_valid_input(self):

        self.mocks["sanitize_input"].return_value = {
            "SanitizedContent": self.prompt,
            "ValidationDecision": "PASSED",
            "Findings": []
        }

        self.mocks["record_input_validation"].return_value = {
            "InteractionId": 1001,
            "ValidationDecision": "PASSED",
            "DetectionCount": 0,
            "InteractionStatus": "PROCESSING"
        }

    def assert_model_not_called(self):

        for dependency in (
            "request_tool",
            "record_model_execution",
            "record_model_tool_request",
            "execute_tool",
            "validate_output",
            "record_output_validation",
            "complete_interaction",
            "format_customer_balance"
        ):

            self.mocks[dependency].assert_not_called()

    def test_input_validation_failure(self):

        self.configure_approved_governance()

        self.mocks["sanitize_input"].side_effect = (
            RuntimeError("SENSITIVE_INPUT_ERROR")
        )

        with self.assertLogs(
            "aiaf.pipeline",
            level="ERROR"
        ) as logs:

            response = process_request(
                self.prompt,
                **self.context
            )

        self.assertEqual(
            response,
            "The request could not be completed."
        )

        self.assertNotIn(
            "SENSITIVE_INPUT_ERROR",
            "\n".join(logs.output)
        )

        self.mocks[
            "record_input_validation"
        ].assert_not_called()

        self.assert_model_not_called()
        self.assert_resources_closed()

    def test_input_persistence_failure(self):

        self.configure_approved_governance()
        self.configure_valid_input()

        self.mocks["record_input_validation"].side_effect = (
            RuntimeError("SENSITIVE_PERSISTENCE_ERROR")
        )

        with self.assertLogs(
            "aiaf.pipeline",
            level="ERROR"
        ) as logs:

            response = process_request(
                self.prompt,
                **self.context
            )

        self.assertEqual(
            response,
            "The request could not be completed."
        )

        self.assertNotIn(
            "SENSITIVE_PERSISTENCE_ERROR",
            "\n".join(logs.output)
        )

        self.assert_model_not_called()
        self.assert_resources_closed()

    def test_invalid_input_evidence(self):

        invalid_evidence = (
            ("InteractionId", None),
            ("InteractionId", 1002),
            ("InteractionId", "1001"),
            ("InteractionId", True),
            ("InteractionStatus", "COMPLETED"),
            ("InteractionStatus", "RECEIVED"),
            ("ValidationDecision", "BLOCKED"),
            ("ValidationDecision", "SANITIZED"),
            ("ValidationDecision", None),
            ("DetectionCount", 1),
            ("DetectionCount", -1),
            ("DetectionCount", False),
            ("DetectionCount", "0"),
            ("DetectionCount", None)
        )

        for field, value in invalid_evidence:

            with self.subTest(field=field, value=value):

                self.connection.reset_mock()
                self.cursor.reset_mock()

                for dependency in self.mocks.values():

                    dependency.reset_mock()

                self.configure_approved_governance()
                self.configure_valid_input()

                evidence = self.mocks[
                    "record_input_validation"
                ].return_value

                evidence[field] = value

                with self.assertLogs(
                    "aiaf.pipeline",
                    level="ERROR"
                ):

                    response = process_request(
                        self.prompt,
                        **self.context
                    )

                self.assertEqual(
                    response,
                    "The request could not be completed."
                )

                self.assert_model_not_called()
                self.assert_resources_closed()

    def setUp(self):

        self.context = {
            "application_code": "ACME_ACCOUNTS_RECEIVABLE_AI",
            "requesting_identity": "Jeannine",
            "workflow_code": "CUSTOMER_BALANCE",
            "business_purpose": "Review customer balance",
            "execution_environment": "TEST"
        }

        self.prompt = (
            "What is the outstanding balance for CUST-1001?"
        )

        self.connection = MagicMock()
        self.cursor = MagicMock()

        self.connection.cursor.return_value = self.cursor

        dependencies = (
            "get_connection",
            "begin_interaction",
            "sanitize_input",
            "record_input_validation",
            "request_tool",
            "record_model_execution",
            "record_model_tool_request",
            "execute_tool",
            "validate_output",
            "record_output_validation",
            "complete_interaction",
            "format_customer_balance"
        )

        self.mocks = {}

        for dependency in dependencies:

            patcher = patch(
                f"aiaf.pipeline.{dependency}"
            )

            self.mocks[dependency] = patcher.start()

            self.addCleanup(patcher.stop)

        self.mocks["get_connection"].return_value = (
            self.connection
        )

    def assert_downstream_not_called(self):

        for dependency in (
            "sanitize_input",
            "record_input_validation",
            "request_tool",
            "record_model_execution",
            "record_model_tool_request",
            "execute_tool",
            "validate_output",
            "record_output_validation",
            "complete_interaction",
            "format_customer_balance"
        ):

            self.mocks[dependency].assert_not_called()

    def assert_resources_closed(self):

        self.cursor.close.assert_called_once()
        self.connection.close.assert_called_once()

    def test_governance_denials(self):

        for reason in (
            "GOVERNANCE_SUSPENDED",
            "GOVERNANCE_REJECTED",
            "APPLICATION_DISABLED",
            "APPLICATION_NOT_REGISTERED",
            "NO_GOVERNANCE_ATTESTATION",
            "EVIDENCE_INTEGRITY_FAILURE",
            "CONDITIONS_NOT_EVALUATED",
            "RESTRICTIONS_NOT_EVALUATED"
        ):

            with self.subTest(reason=reason):

                self.connection.reset_mock()
                self.cursor.reset_mock()

                self.mocks["begin_interaction"].reset_mock()

                self.mocks["begin_interaction"].return_value = {
                    "InteractionId": 1001,
                    "CorrelationId": "test-correlation-id",
                    "GateDecision": "DENIED",
                    "GateReason": reason
                }

                with self.assertLogs(
                    "aiaf.pipeline",
                    level="WARNING"
                ):

                    response = process_request(
                        self.prompt,
                        **self.context
                    )

                self.assertEqual(
                    response,
                    "This application is not currently "
                    "authorized to process the request."
                )

                self.mocks[
                    "begin_interaction"
                ].assert_called_once()

                self.assert_downstream_not_called()
                self.assert_resources_closed()

    def test_governance_persistence_failure(self):

        self.mocks["begin_interaction"].side_effect = (
            RuntimeError("SENSITIVE_GOVERNANCE_ERROR")
        )

        with self.assertLogs(
            "aiaf.pipeline",
            level="ERROR"
        ) as logs:

            response = process_request(
                self.prompt,
                **self.context
            )

        self.assertEqual(
            response,
            "The request could not be completed."
        )

        self.assertNotIn(
            "SENSITIVE_GOVERNANCE_ERROR",
            "\n".join(logs.output)
        )

        self.assert_downstream_not_called()
        self.assert_resources_closed()

    def configure_valid_model(self):

        self.mocks["request_tool"].return_value = {
            "ExecutionStatus": "SUCCEEDED",
            "ResponseValidationDecision": "PASSED",
            "ToolRequest": {
                "ToolCode": "GetCustomerBalance",
                "CustomerCode": "CUST-1001"
            }
        }

        self.mocks["record_model_execution"].return_value = {
            "InteractionId": 1001,
            "ModelExecutionId": 2001,
            "ExecutionStatus": "SUCCEEDED",
            "ResponseValidationDecision": "PASSED",
            "InputTokens": 120,
            "OutputTokens": 25,
            "TotalCost": None,
            "CurrencyCode": None,
            "CostBasis": "UNAVAILABLE"
        }

    def assert_tool_not_called(self):

        for dependency in (
            "record_model_tool_request",
            "execute_tool",
            "validate_output",
            "record_output_validation",
            "format_customer_balance"
        ):

            self.mocks[dependency].assert_not_called()

    def test_model_failure_outcomes(self):

        scenarios = (
            (
                "FAILED",
                "NOT_EVALUATED",
                "MODEL_EXECUTION_FAILED"
            ),
            (
                "TIMEOUT",
                "NOT_EVALUATED",
                "MODEL_EXECUTION_FAILED"
            ),
            (
                "SUCCEEDED",
                "FAILED",
                "MODEL_RESPONSE_INVALID"
            )
        )

        for status, decision, reason in scenarios:

            with self.subTest(
                status=status,
                decision=decision
            ):

                self.connection.reset_mock()
                self.cursor.reset_mock()

                for dependency in self.mocks.values():

                    dependency.reset_mock()

                self.configure_approved_governance()
                self.configure_valid_input()
                self.configure_valid_model()

                execution = self.mocks[
                    "request_tool"
                ].return_value

                execution["ExecutionStatus"] = status
                execution["ResponseValidationDecision"] = decision
                execution["ToolRequest"] = None

                evidence = self.mocks[
                    "record_model_execution"
                ].return_value

                evidence["ExecutionStatus"] = status
                evidence["ResponseValidationDecision"] = decision

                self.mocks[
                    "complete_interaction"
                ].return_value = {
                    "InteractionId": 1001,
                    "InteractionStatus": "FAILED",
                    "CompletionReason": reason
                }

                response = process_request(
                    self.prompt,
                    **self.context
                )

                self.assertEqual(
                    response,
                    "The request could not be processed."
                )

                self.mocks[
                    "record_model_execution"
                ].assert_called_once()

                self.mocks[
                    "complete_interaction"
                ].assert_called_once_with(
                    self.cursor,
                    1001
                )

                self.assert_tool_not_called()
                self.assert_resources_closed()

    def test_model_persistence_failure(self):

        self.configure_approved_governance()
        self.configure_valid_input()
        self.configure_valid_model()

        self.mocks["record_model_execution"].side_effect = (
            RuntimeError("SENSITIVE_MODEL_PERSISTENCE_ERROR")
        )

        with self.assertLogs(
            "aiaf.pipeline",
            level="ERROR"
        ) as logs:

            response = process_request(
                self.prompt,
                **self.context
            )

        self.assertEqual(
            response,
            "The request could not be completed."
        )

        self.assertNotIn(
            "SENSITIVE_MODEL_PERSISTENCE_ERROR",
            "\n".join(logs.output)
        )

        self.mocks[
            "complete_interaction"
        ].assert_not_called()

        self.assert_tool_not_called()
        self.assert_resources_closed()

    def test_invalid_model_evidence(self):

        invalid_evidence = (
            ("InteractionId", 1002),
            ("InteractionId", None),
            ("InteractionId", "1001"),
            ("ExecutionStatus", "FAILED"),
            ("ExecutionStatus", None),
            ("ResponseValidationDecision", "FAILED"),
            ("ResponseValidationDecision", None)
        )

        for field, value in invalid_evidence:

            with self.subTest(field=field, value=value):

                self.connection.reset_mock()
                self.cursor.reset_mock()

                for dependency in self.mocks.values():

                    dependency.reset_mock()

                self.configure_approved_governance()
                self.configure_valid_input()
                self.configure_valid_model()

                evidence = self.mocks[
                    "record_model_execution"
                ].return_value

                evidence[field] = value

                with self.assertLogs(
                    "aiaf.pipeline",
                    level="ERROR"
                ):

                    response = process_request(
                        self.prompt,
                        **self.context
                    )

                self.assertEqual(
                    response,
                    "The request could not be completed."
                )

                self.mocks[
                    "complete_interaction"
                ].assert_not_called()

                self.assert_tool_not_called()
                self.assert_resources_closed()

    def configure_valid_proposal(self):
        self.configure_approved_governance()
        self.configure_valid_input()
        self.configure_valid_model()
        self.mocks["record_model_tool_request"].return_value = {
            "InteractionId": 1001, "ModelExecutionId": 2001,
            "ModelToolRequestId": 3001, "ToolCode": "GetCustomerBalance",
            "RequestArguments": '{"CustomerCode":"CUST-1001"}',
            "AuthorizationDecision": "NOT_EVALUATED"
        }

    def assert_output_not_called(self):
        for dependency in ("validate_output", "record_output_validation",
                           "format_customer_balance"):
            self.mocks[dependency].assert_not_called()

    def test_proposal_persistence_failure(self):

        self.configure_valid_proposal()

        self.mocks["record_model_tool_request"].side_effect = (
            RuntimeError("SENSITIVE_PROPOSAL_ERROR")
        )

        with self.assertLogs(
            "aiaf.pipeline",
            level="ERROR"
        ) as logs:

            response = process_request(
                self.prompt,
                **self.context
            )

        self.assertEqual(
            response,
            "The request could not be completed."
        )

        self.assertNotIn(
            "SENSITIVE_PROPOSAL_ERROR",
            "\n".join(logs.output)
        )

        self.mocks["execute_tool"].assert_not_called()
        self.mocks["complete_interaction"].assert_not_called()

        self.assert_output_not_called()
        self.assert_resources_closed()

    def test_unsuccessful_tool_outcomes(self):

        scenarios = (
            (
                "DENIED",
                "NOT_EXECUTED",
                "CUSTOMER_ACCESS_DENIED",
                "BLOCKED",
                "TOOL_AUTHORIZATION_DENIED",
                "You are not authorized to retrieve "
                "the requested information."
            ),
            (
                "ALLOWED",
                "FAILED",
                "CUSTOMER_READ_AUTHORIZED",
                "FAILED",
                "TOOL_EXECUTION_FAILED",
                "The requested information could not be retrieved."
            ),
            (
                "ERROR",
                "NOT_EXECUTED",
                "AUTHORIZATION_ERROR",
                "FAILED",
                "TOOL_EXECUTION_FAILED",
                "The requested information could not be retrieved."
            )
        )

        for (
            authorization,
            execution,
            authorization_reason,
            final_status,
            completion_reason,
            expected_response
        ) in scenarios:

            with self.subTest(
                authorization=authorization,
                execution=execution
            ):

                self.connection.reset_mock()
                self.cursor.reset_mock()

                for dependency in self.mocks.values():

                    dependency.reset_mock()

                self.configure_valid_proposal()

                self.mocks["execute_tool"].return_value = {
                    "InteractionId": 1001,
                    "ModelToolRequestId": 3001,
                    "AIToolCallId": 4001,
                    "ToolCode": "GetCustomerBalance",
                    "AuthorizationDecision": authorization,
                    "AuthorizationReason": authorization_reason,
                    "ExecutionStatus": execution,
                    "RowsReturned": 0,
                    "Data": []
                }

                self.mocks[
                    "complete_interaction"
                ].return_value = {
                    "InteractionId": 1001,
                    "InteractionStatus": final_status,
                    "CompletionReason": completion_reason
                }

                response = process_request(
                    self.prompt,
                    **self.context
                )

                self.assertEqual(
                    response,
                    expected_response
                )

                self.mocks["execute_tool"].assert_called_once_with(
                    self.cursor,
                    self.mocks[
                        "record_model_tool_request"
                    ].return_value
                )

                self.mocks[
                    "complete_interaction"
                ].assert_called_once_with(
                    self.cursor,
                    1001
                )

                self.assert_output_not_called()
                self.assert_resources_closed()

    def test_no_supported_tool(self):

        self.configure_valid_proposal()

        self.mocks["request_tool"].return_value[
            "ToolRequest"
        ] = {
            "ToolCode": "NO_SUPPORTED_TOOL",
            "CustomerCode": ""
        }

        proposal = self.mocks[
            "record_model_tool_request"
        ].return_value

        proposal["ToolCode"] = "NO_SUPPORTED_TOOL"
        proposal["RequestArguments"] = '{"CustomerCode":""}'

        self.mocks["execute_tool"].return_value = {
            "InteractionId": 1001,
            "ModelToolRequestId": 3001,
            "ToolCode": "NO_SUPPORTED_TOOL",
            "AuthorizationDecision": "NOT_EVALUATED",
            "AuthorizationReason": "NO_SUPPORTED_TOOL",
            "ExecutionStatus": "NOT_EXECUTED",
            "RowsReturned": 0,
            "Data": []
        }

        self.mocks[
            "complete_interaction"
        ].return_value = {
            "InteractionId": 1001,
            "InteractionStatus": "BLOCKED",
            "CompletionReason": "NO_SUPPORTED_TOOL"
        }

        response = process_request(
            "DROP TABLE acme.Customer;",
            **self.context
        )

        self.assertEqual(
            response,
            "This request is not supported by this application."
        )

        self.mocks["execute_tool"].assert_called_once_with(
            self.cursor,
            proposal
        )

        self.mocks[
            "complete_interaction"
        ].assert_called_once_with(
            self.cursor,
            1001
        )

        self.assert_output_not_called()
        self.assert_resources_closed()

    def test_tool_execution_exception(self):

        self.configure_valid_proposal()

        self.mocks["execute_tool"].side_effect = (
            RuntimeError("SENSITIVE_TOOL_EXECUTION_ERROR")
        )

        with self.assertLogs(
            "aiaf.pipeline",
            level="ERROR"
        ) as logs:

            response = process_request(
                self.prompt,
                **self.context
            )

        self.assertEqual(
            response,
            "The request could not be completed."
        )

        self.assertNotIn(
            "SENSITIVE_TOOL_EXECUTION_ERROR",
            "\n".join(logs.output)
        )

        self.mocks["complete_interaction"].assert_not_called()

        self.assert_output_not_called()
        self.assert_resources_closed()

    def configure_valid_output(self):
        self.configure_valid_proposal()
        self.mocks["execute_tool"].return_value = {
            "InteractionId": 1001, "ModelToolRequestId": 3001,
            "AIToolCallId": 4001, "ToolCode": "GetCustomerBalance",
            "AuthorizationDecision": "ALLOWED",
            "AuthorizationReason": "CUSTOMER_READ_AUTHORIZED",
            "ExecutionStatus": "SUCCEEDED", "RowsReturned": 1,
            "Data": [{"CustomerCode": "CUST-1001",
                      "CustomerName": "Northwind Industrial",
                      "OutstandingBalance": Decimal("14200.00"),
                      "DisputedBalance": Decimal("4200.00"),
                      "OpenInvoiceCount": 3, "DisputedInvoiceCount": 1}]
        }
        self.mocks["validate_output"].return_value = {
            "ValidationDecision": "PASSED", "DetectionCount": 0,
            "Findings": [{"RuleCode": code, "RuleVersion": 1,
                          "DataClassification": classification,
                          "ValidationDecision": "PASSED", "DetectionCount": 0}
                         for code, classification in (
                             ("OUTPUT_AUTHORIZATION", "CONFIDENTIAL"),
                             ("OUTPUT_ROW_COUNT", "INTERNAL"),
                             ("OUTPUT_SCHEMA", "CONFIDENTIAL"),
                             ("OUTPUT_FINANCIAL_INTEGRITY", "CONFIDENTIAL"),
                             ("OUTPUT_CUSTOMER_BINDING", "CONFIDENTIAL"))]
        }
        self.mocks["record_output_validation"].return_value = {
            "InteractionId": 1001, "AIToolCallId": 4001,
            "ValidationDecision": "PASSED", "DetectionCount": 0
        }
        self.mocks["complete_interaction"].return_value = {
            "InteractionId": 1001, "InteractionStatus": "COMPLETED",
            "CompletionReason": "OUTPUT_APPROVED_FOR_RELEASE"
        }
        self.mocks["format_customer_balance"].return_value = "Approved balance."

    def assert_no_output_release(self):
        self.mocks["format_customer_balance"].assert_not_called()
        self.assertEqual(self.mocks["execute_tool"].return_value["Data"], [])
        self.assert_resources_closed()

    def test_output_validation_blocked(self):
        self.configure_valid_output()
        validation = self.mocks["validate_output"].return_value
        validation.update(ValidationDecision="BLOCKED", DetectionCount=1)
        validation["Findings"][-1].update(ValidationDecision="BLOCKED", DetectionCount=1)
        self.mocks["record_output_validation"].return_value.update(
            ValidationDecision="BLOCKED", DetectionCount=1)
        self.mocks["complete_interaction"].return_value.update(
            InteractionStatus="BLOCKED", CompletionReason="OUTPUT_VALIDATION_BLOCKED")
        response = process_request(self.prompt, **self.context)
        self.assertEqual(response, "The requested information could not be safely returned.")
        self.mocks["record_output_validation"].assert_called_once_with(
            self.cursor, 1001, 4001, validation["Findings"])
        self.mocks["complete_interaction"].assert_called_once_with(self.cursor, 1001)
        self.assert_no_output_release()

    def test_output_stage_exceptions(self):
        for stage in ("validate_output", "record_output_validation", "complete_interaction"):
            with self.subTest(stage=stage):
                self.connection.reset_mock()
                self.cursor.reset_mock()
                for dependency in self.mocks.values():
                    dependency.reset_mock(side_effect=True)
                self.configure_valid_output()
                self.mocks[stage].side_effect = RuntimeError("SENSITIVE_OUTPUT_ERROR")
                with self.assertLogs("aiaf.pipeline", level="ERROR") as logs:
                    response = process_request(self.prompt, **self.context)
                self.assertEqual(response, "The request could not be completed.")
                self.assertNotIn("SENSITIVE_OUTPUT_ERROR", "\n".join(logs.output))
                self.mocks[stage].assert_called_once()
                if stage == "validate_output":
                    self.mocks["record_output_validation"].assert_not_called()
                if stage != "complete_interaction":
                    self.mocks["complete_interaction"].assert_not_called()
                self.assert_no_output_release()

    def test_invalid_output_evidence(self):
        cases = (("InteractionId", 1002), ("InteractionId", None),
                 ("AIToolCallId", 4002), ("AIToolCallId", True),
                 ("ValidationDecision", "BLOCKED"), ("ValidationDecision", None),
                 ("DetectionCount", 1), ("DetectionCount", -1),
                 ("DetectionCount", False), ("DetectionCount", "0"))
        for field, value in cases:
            with self.subTest(field=field, value=value):
                self.connection.reset_mock()
                self.cursor.reset_mock()
                for dependency in self.mocks.values():
                    dependency.reset_mock()
                self.configure_valid_output()
                self.mocks["record_output_validation"].return_value[field] = value
                with self.assertLogs("aiaf.pipeline", level="ERROR"):
                    response = process_request(self.prompt, **self.context)
                self.assertEqual(response, "The request could not be completed.")
                self.mocks["complete_interaction"].assert_not_called()
                self.assert_no_output_release()

    def test_completion_does_not_approve_release(self):
        for field, value in (("InteractionStatus", "FAILED"),
                             ("InteractionStatus", "BLOCKED"),
                             ("CompletionReason", "UNKNOWN")):
            with self.subTest(field=field, value=value):
                self.connection.reset_mock()
                self.cursor.reset_mock()
                for dependency in self.mocks.values():
                    dependency.reset_mock()
                self.configure_valid_output()
                self.mocks["complete_interaction"].return_value[field] = value
                response = process_request(self.prompt, **self.context)
                self.assertEqual(response, "The requested information could not be safely returned.")
                self.mocks["complete_interaction"].assert_called_once_with(self.cursor, 1001)
                self.assert_no_output_release()

    def test_successful_output_release(self):
        self.configure_valid_output()
        record = self.mocks["execute_tool"].return_value["Data"][0].copy()
        order = []
        def complete(*args):
            order.append("complete")
            return self.mocks["complete_interaction"].return_value
        def format_balance(*args):
            order.append("format")
            return "Approved balance."
        self.mocks["complete_interaction"].side_effect = complete
        self.mocks["format_customer_balance"].side_effect = format_balance
        response = process_request(self.prompt, **self.context)
        self.assertEqual(response, "Approved balance.")
        self.assertEqual(order, ["complete", "format"])
        self.mocks["format_customer_balance"].assert_called_once_with(record)
        self.assertEqual(self.mocks["execute_tool"].return_value["Data"], [])
        self.assert_resources_closed()

if __name__ == "__main__":

    unittest.main()