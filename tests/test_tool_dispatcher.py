import json
import unittest

from datetime import datetime
from decimal import Decimal
from unittest.mock import MagicMock

from aiaf.tool_dispatcher import (
    record_model_tool_request,
    execute_tool
)


class TestModelProposalPersistence(unittest.TestCase):

    def setUp(self):

        self.cursor = MagicMock()

        self.tool_request = {
            "ToolCode": "GetCustomerBalance",
            "CustomerCode": "CUST-1001"
        }

        self.row = [
            30,
            20,
            10,
            "GetCustomerBalance",
            '{"CustomerCode":"CUST-1001"}',
            datetime(2026, 11, 15, 12, 0),
            "NOT_EVALUATED"
        ]

        self.cursor.fetchone.return_value = self.row

    def record_proposal(self):

        return record_model_tool_request(
            self.cursor,
            10,
            20,
            self.tool_request
        )

    def test_successful_proposal(self):

        result = self.record_proposal()

        self.assertEqual(result["ModelToolRequestId"], 30)
        self.assertEqual(result["ModelExecutionId"], 20)
        self.assertEqual(result["InteractionId"], 10)
        self.assertEqual(result["ToolCode"], "GetCustomerBalance")
        self.assertEqual(
            result["AuthorizationDecision"],
            "NOT_EVALUATED"
        )

        self.cursor.execute.assert_called_once()

        args = self.cursor.execute.call_args.args

        self.assertIn(
            "aiaf.usp_RecordModelToolRequest", args[0]
        )

        self.assertEqual(
            args[1:],
            (10, 20, "GetCustomerBalance", "CUST-1001")
        )

    def test_no_supported_tool_proposal(self):

        self.tool_request = {
            "ToolCode": "NO_SUPPORTED_TOOL",
            "CustomerCode": ""
        }

        self.row[3] = "NO_SUPPORTED_TOOL"
        self.row[4] = '{"CustomerCode":""}'

        result = self.record_proposal()

        self.assertEqual(
            result["ToolCode"], "NO_SUPPORTED_TOOL"
        )

        self.assertEqual(
            json.loads(result["RequestArguments"]),
            {"CustomerCode": ""}
        )

    def test_invalid_input_identifiers(self):

        for value in (None, True, False, 0, -1, "10", 10.0):

            for identifiers in ((value, 20), (10, value)):

                with self.subTest(identifiers=identifiers):

                    with self.assertRaises(ValueError):

                        record_model_tool_request(
                            self.cursor,
                            *identifiers,
                            self.tool_request
                        )

        self.cursor.execute.assert_not_called()

    def test_invalid_tool_request(self):

        self.tool_request["ToolCode"] = "DeleteCustomer"

        with self.assertRaises(ValueError):
            self.record_proposal()

        self.cursor.execute.assert_not_called()

    def test_missing_persistence_evidence(self):

        self.cursor.fetchone.return_value = None

        with self.assertRaisesRegex(
            RuntimeError,
            "Model proposal persistence returned no evidence"
        ):
            self.record_proposal()

    def test_invalid_persistence_identifiers(self):

        original = self.row.copy()

        for index in (0, 1, 2):

            for value in (None, True, 0, -1, "10", 10.0):

                with self.subTest(index=index, value=value):

                    self.row[:] = original
                    self.row[index] = value

                    with self.assertRaisesRegex(
                        RuntimeError,
                        "Model proposal evidence mismatch"
                    ):
                        self.record_proposal()

    def test_mismatched_persistence_evidence(self):

        original = self.row.copy()

        scenarios = [
            (1, 999),
            (2, 999),
            (3, "DeleteCustomer"),
            (3, "NO_SUPPORTED_TOOL"),
            (6, "ALLOWED"),
            (6, "DENIED"),
            (6, None)
        ]

        for index, value in scenarios:

            with self.subTest(index=index, value=value):

                self.row[:] = original
                self.row[index] = value

                with self.assertRaisesRegex(
                    RuntimeError,
                    "Model proposal evidence mismatch"
                ):
                    self.record_proposal()

    def test_invalid_persisted_json(self):

        for value in (None, "", "{invalid"):

            with self.subTest(value=value):

                self.row[4] = value

                with self.assertRaisesRegex(
                    RuntimeError,
                    "Invalid persisted model proposal arguments"
                ):
                    self.record_proposal()

    def test_mismatched_persisted_arguments(self):

        scenarios = [
            '{"CustomerCode":"CUST-1003"}',
            '{"CustomerCode":null}',
            '{"CustomerCode":1001}',
            '{"CustomerCode":"CUST-1001","Extra":true}',
            '{}',
            '[]',
            'null'
        ]

        for value in scenarios:

            with self.subTest(value=value):

                self.row[4] = value

                with self.assertRaisesRegex(
                    RuntimeError,
                    "Model proposal arguments mismatch"
                ):
                    self.record_proposal()

    def test_database_exception_propagates(self):

        self.cursor.execute.side_effect = RuntimeError(
            "Database unavailable"
        )

        with self.assertRaisesRegex(
            RuntimeError,
            "Database unavailable"
        ):
            self.record_proposal()


class TestToolExecution(unittest.TestCase):

    def setUp(self):

        self.cursor = MagicMock()

        self.proposal = {
            "InteractionId": 10,
            "ModelExecutionId": 20,
            "ModelToolRequestId": 30,
            "ToolCode": "GetCustomerBalance",
            "RequestArguments":
                '{"CustomerCode":"CUST-1001"}',
            "AuthorizationDecision": "NOT_EVALUATED"
        }

        self.row = [
            10,
            40,
            "ALLOWED",
            "CUSTOMER_READ_AUTHORIZED",
            "SUCCEEDED",
            1
        ]

        self.columns = [
            "CustomerCode",
            "CustomerName",
            "OutstandingBalance",
            "DisputedBalance",
            "OpenInvoiceCount",
            "DisputedInvoiceCount"
        ]

        self.records = [
            (
                "CUST-1001",
                "Northwind Industrial",
                Decimal("14200.00"),
                Decimal("4200.00"),
                3,
                1
            )
        ]

        self.cursor.fetchone.return_value = self.row

        self.cursor.nextset.return_value = True

        self.cursor.description = [
            (column,) for column in self.columns
        ]

        self.cursor.fetchall.return_value = self.records

    def execute(self):

        return execute_tool(
            self.cursor,
            self.proposal
        )

    def test_successful_execution(self):

        result = self.execute()

        self.assertEqual(result["InteractionId"], 10)
        self.assertEqual(result["ModelToolRequestId"], 30)
        self.assertEqual(result["AIToolCallId"], 40)
        self.assertEqual(result["AuthorizationDecision"], "ALLOWED")
        self.assertEqual(result["ExecutionStatus"], "SUCCEEDED")
        self.assertEqual(result["RowsReturned"], 1)

        self.assertEqual(
            result["Data"],
            [dict(zip(self.columns, self.records[0]))]
        )

        self.cursor.execute.assert_called_once()

        args = self.cursor.execute.call_args.args

        self.assertIn(
            "aiaf_tool.GetCustomerBalance", args[0]
        )

        self.assertEqual(args[1:], (10, 30))

    def test_denied_execution(self):

        self.row[:] = [
            10, 40,
            "DENIED",
            "CUSTOMER_ACCESS_DENIED",
            "NOT_EXECUTED",
            0
        ]

        result = self.execute()

        self.assertEqual(result["AuthorizationDecision"], "DENIED")
        self.assertEqual(result["Data"], [])

        self.cursor.nextset.assert_not_called()
        self.cursor.fetchall.assert_not_called()

    def test_failed_execution(self):

        self.row[:] = [
            10, 40,
            "ALLOWED",
            "TOOL_EXECUTION_FAILED",
            "FAILED",
            0
        ]

        result = self.execute()

        self.assertEqual(result["ExecutionStatus"], "FAILED")
        self.assertEqual(result["Data"], [])

        self.cursor.fetchall.assert_not_called()

    def test_authorization_error(self):

        self.row[:] = [
            10, 40,
            "ERROR",
            "AUTHORIZATION_ERROR",
            "NOT_EXECUTED",
            0
        ]

        result = self.execute()

        self.assertEqual(result["AuthorizationDecision"], "ERROR")
        self.assertEqual(result["Data"], [])

        self.cursor.fetchall.assert_not_called()

    def test_no_supported_tool(self):

        self.proposal["ToolCode"] = "NO_SUPPORTED_TOOL"

        result = self.execute()

        self.assertEqual(
            result["AuthorizationDecision"],
            "NOT_EVALUATED"
        )

        self.assertEqual(
            result["ExecutionStatus"], "NOT_EXECUTED"
        )

        self.assertEqual(result["RowsReturned"], 0)
        self.assertEqual(result["Data"], [])

        self.cursor.execute.assert_not_called()

    def test_unsupported_tool(self):

        self.proposal["ToolCode"] = "DeleteCustomer"

        with self.assertRaisesRegex(
            ValueError,
            "Unsupported tool requested"
        ):
            self.execute()

        self.cursor.execute.assert_not_called()

    def test_invalid_proposal_identifiers(self):

        original = self.proposal.copy()

        for field in ("InteractionId", "ModelToolRequestId"):

            for value in (None, True, 0, -1, "10", 10.0):

                with self.subTest(field=field, value=value):

                    self.proposal = original.copy()
                    self.proposal[field] = value

                    with self.assertRaises(ValueError):
                        self.execute()

        self.cursor.execute.assert_not_called()

    def test_missing_authorization_evidence(self):

        self.cursor.fetchone.return_value = None

        with self.assertRaisesRegex(
            RuntimeError,
            "Tool returned no authorization evidence"
        ):
            self.execute()

    def test_invalid_execution_evidence(self):

        original = self.row.copy()

        scenarios = [
            (0, 999),
            (0, True),
            (0, None),
            (1, True),
            (1, 0),
            (1, -1),
            (1, None),
            (5, True),
            (5, -1),
            (5, "1"),
            (5, 1.0),
            (5, None)
        ]

        for index, value in scenarios:

            with self.subTest(index=index, value=value):

                self.row[:] = original
                self.row[index] = value

                with self.assertRaisesRegex(
                    RuntimeError,
                    "Tool execution evidence mismatch"
                ):
                    self.execute()

        self.cursor.fetchall.assert_not_called()

    def test_invalid_execution_outcomes(self):

        scenarios = [
            ("DENIED", "SUCCEEDED"),
            ("DENIED", "FAILED"),
            ("ERROR", "SUCCEEDED"),
            ("UNKNOWN", "SUCCEEDED"),
            ("ALLOWED", "NOT_EXECUTED"),
            ("ALLOWED", "UNKNOWN"),
            (None, None)
        ]

        for authorization, execution in scenarios:

            with self.subTest(
                authorization=authorization,
                execution=execution
            ):

                self.row[2] = authorization
                self.row[4] = execution

                with self.assertRaisesRegex(
                    RuntimeError,
                    "Invalid tool execution outcome"
                ):
                    self.execute()

        self.cursor.fetchall.assert_not_called()

    def test_missing_result_set(self):

        self.cursor.nextset.return_value = False

        with self.assertRaisesRegex(
            RuntimeError,
            "Expected tool result set is missing"
        ):
            self.execute()

    def test_missing_result_description(self):

        self.cursor.description = None

        with self.assertRaisesRegex(
            RuntimeError,
            "Expected tool result set is missing"
        ):
            self.execute()

    def test_duplicate_result_columns(self):

        self.cursor.description = [
            ("CustomerCode",),
            ("CustomerCode",)
        ]

        with self.assertRaisesRegex(
            RuntimeError,
            "Duplicate tool result columns"
        ):
            self.execute()

        self.cursor.fetchall.assert_not_called()

    def test_result_count_mismatch(self):

        self.row[5] = 2

        with self.assertRaisesRegex(
            RuntimeError,
            "Tool result count mismatch"
        ):
            self.execute()

    def test_result_column_count_mismatch(self):

        self.cursor.fetchall.return_value = [
            self.records[0][:-1]
        ]

        with self.assertRaisesRegex(
            RuntimeError,
            "Tool result column count mismatch"
        ):
            self.execute()

    def test_unexpected_rows_for_unsuccessful_execution(self):

        self.row[:] = [
            10, 40,
            "DENIED",
            "CUSTOMER_ACCESS_DENIED",
            "NOT_EXECUTED",
            1
        ]

        with self.assertRaisesRegex(
            RuntimeError,
            "Unexpected rows for unsuccessful tool execution"
        ):
            self.execute()

        self.cursor.fetchall.assert_not_called()

    def test_database_exception_propagates(self):

        self.cursor.execute.side_effect = RuntimeError(
            "Database unavailable"
        )

        with self.assertRaisesRegex(
            RuntimeError,
            "Database unavailable"
        ):
            self.execute()


if __name__ == "__main__":
    unittest.main()