import json
import unittest

from copy import deepcopy
from decimal import Decimal
from unittest.mock import MagicMock

from aiaf.output_validation import (
    validate_output,
    record_output_validation
)


class TestOutputValidation(unittest.TestCase):

    def setUp(self):

        self.proposal = {
            "InteractionId": 1,
            "ModelToolRequestId": 1,
            "ToolCode": "GetCustomerBalance",
            "RequestArguments": '{"CustomerCode":"CUST-1001"}'
        }

        self.tool_result = {
            "InteractionId": 1,
            "ModelToolRequestId": 1,
            "AIToolCallId": 1,
            "ToolCode": "GetCustomerBalance",
            "AuthorizationDecision": "ALLOWED",
            "ExecutionStatus": "SUCCEEDED",
            "RowsReturned": 1,
            "Data": [
                {
                    "CustomerCode": "CUST-1001",
                    "CustomerName": "Northwind Industrial",
                    "OutstandingBalance": Decimal("14200.00"),
                    "DisputedBalance": Decimal("4200.00"),
                    "OpenInvoiceCount": 3,
                    "DisputedInvoiceCount": 1
                }
            ]
        }

    def assert_blocked(
        self,
        expected_rules,
        proposal=None,
        tool_result=None
    ):

        result = validate_output(
            self.proposal if proposal is None else proposal,
            self.tool_result if tool_result is None else tool_result
        )

        self.assertEqual(
            result["ValidationDecision"], "BLOCKED"
        )

        self.assertEqual(len(result["Findings"]), 5)

        blocked_rules = {
            finding["RuleCode"]
            for finding in result["Findings"]
            if finding["ValidationDecision"] == "BLOCKED"
        }

        self.assertEqual(blocked_rules, set(expected_rules))

        self.assertEqual(
            result["DetectionCount"],
            len(blocked_rules)
        )

        for finding in result["Findings"]:

            self.assertEqual(
                finding["DetectionCount"],
                1 if finding["ValidationDecision"] == "BLOCKED"
                else 0
            )

    def test_valid_result(self):

        result = validate_output(
            self.proposal,
            self.tool_result
        )

        self.assertEqual(
            result["ValidationDecision"], "PASSED"
        )

        self.assertEqual(result["DetectionCount"], 0)
        self.assertEqual(len(result["Findings"]), 5)

        for finding in result["Findings"]:

            self.assertEqual(
                finding["ValidationDecision"], "PASSED"
            )

            self.assertEqual(finding["DetectionCount"], 0)

    def test_unauthorized_result(self):

        self.tool_result["AuthorizationDecision"] = "DENIED"

        self.assert_blocked(["OUTPUT_AUTHORIZATION"])

    def test_failed_execution(self):

        self.tool_result["ExecutionStatus"] = "FAILED"

        self.assert_blocked(["OUTPUT_AUTHORIZATION"])

    def test_incorrect_authorization_binding(self):

        invalid_values = [
            ("InteractionId", 999),
            ("InteractionId", True),
            ("ModelToolRequestId", 999),
            ("ModelToolRequestId", True),
            ("ToolCode", "DeleteCustomer"),
            ("AIToolCallId", 0),
            ("AIToolCallId", -1),
            ("AIToolCallId", True),
            ("AIToolCallId", None)
        ]

        for field, value in invalid_values:

            with self.subTest(field=field, value=value):

                result = deepcopy(self.tool_result)

                result[field] = value

                self.assert_blocked(
                    ["OUTPUT_AUTHORIZATION"],
                    tool_result=result
                )

    def test_missing_authorization_identifiers(self):

        for field in (
            "InteractionId",
            "ModelToolRequestId",
            "ToolCode"
        ):

            with self.subTest(field=field):

                proposal = deepcopy(self.proposal)
                result = deepcopy(self.tool_result)

                del proposal[field]
                del result[field]

                self.assert_blocked(
                    ["OUTPUT_AUTHORIZATION"],
                    proposal=proposal,
                    tool_result=result
                )

    def test_unexpected_column(self):

        self.tool_result["Data"][0][
            "SocialSecurityNumber"
        ] = "123-45-6789"

        self.assert_blocked([
            "OUTPUT_SCHEMA",
            "OUTPUT_FINANCIAL_INTEGRITY",
            "OUTPUT_CUSTOMER_BINDING"
        ])

    def test_missing_column(self):

        del self.tool_result["Data"][0]["DisputedBalance"]

        self.assert_blocked([
            "OUTPUT_SCHEMA",
            "OUTPUT_FINANCIAL_INTEGRITY",
            "OUTPUT_CUSTOMER_BINDING"
        ])

    def test_incorrect_row_count(self):

        for value in (0, 2, True, "1", None):

            with self.subTest(value=value):

                result = deepcopy(self.tool_result)

                result["RowsReturned"] = value

                self.assert_blocked(
                    [
                        "OUTPUT_ROW_COUNT",
                        "OUTPUT_SCHEMA",
                        "OUTPUT_FINANCIAL_INTEGRITY",
                        "OUTPUT_CUSTOMER_BINDING"
                    ],
                    tool_result=result
                )

    def test_invalid_data_collection(self):

        invalid_data = [
            [],
            None,
            {},
            "Not a result",
            [
                deepcopy(self.tool_result["Data"][0]),
                deepcopy(self.tool_result["Data"][0])
            ]
        ]

        for data in invalid_data:

            with self.subTest(data=data):

                result = deepcopy(self.tool_result)

                result["Data"] = data

                self.assert_blocked(
                    [
                        "OUTPUT_ROW_COUNT",
                        "OUTPUT_SCHEMA",
                        "OUTPUT_FINANCIAL_INTEGRITY",
                        "OUTPUT_CUSTOMER_BINDING"
                    ],
                    tool_result=result
                )

    def test_invalid_financial_values(self):

        invalid_values = [
            ("OutstandingBalance", Decimal("-1.00")),
            ("DisputedBalance", Decimal("-1.00")),
            ("DisputedBalance", Decimal("20000.00")),
            ("OutstandingBalance", "14200.00"),
            ("OutstandingBalance", 14200.00),
            ("OutstandingBalance", None),
            ("OutstandingBalance", Decimal("NaN")),
            ("OutstandingBalance", Decimal("Infinity")),
            ("OpenInvoiceCount", -1),
            ("OpenInvoiceCount", True),
            ("OpenInvoiceCount", 0),
            ("DisputedInvoiceCount", 4),
            ("DisputedInvoiceCount", 0),
            ("DisputedInvoiceCount", "1")
        ]

        for field, value in invalid_values:

            with self.subTest(field=field, value=value):

                result = deepcopy(self.tool_result)

                result["Data"][0][field] = value

                self.assert_blocked(
                    ["OUTPUT_FINANCIAL_INTEGRITY"],
                    tool_result=result
                )

    def test_valid_zero_balance(self):

        self.tool_result["Data"][0].update({
            "OutstandingBalance": Decimal("0.00"),
            "DisputedBalance": Decimal("0.00"),
            "OpenInvoiceCount": 0,
            "DisputedInvoiceCount": 0
        })

        result = validate_output(
            self.proposal,
            self.tool_result
        )

        self.assertEqual(
            result["ValidationDecision"], "PASSED"
        )

        self.assertEqual(result["DetectionCount"], 0)

    def test_invalid_customer_binding(self):

        invalid_values = [
            ("CustomerCode", "CUST-1003"),
            ("CustomerCode", "CUST-ABCD"),
            ("CustomerCode", 1001),
            ("CustomerCode", None),
            ("CustomerName", ""),
            ("CustomerName", "   "),
            ("CustomerName", "Northwind\nIndustrial"),
            ("CustomerName", "X" * 401),
            ("CustomerName", None)
        ]

        for field, value in invalid_values:

            with self.subTest(field=field, value=value):

                result = deepcopy(self.tool_result)

                result["Data"][0][field] = value

                self.assert_blocked(
                    ["OUTPUT_CUSTOMER_BINDING"],
                    tool_result=result
                )

    def test_invalid_request_arguments(self):

        for arguments in (
            "Not JSON",
            "{}",
            "[]",
            "null",
            None,
            '{"CustomerCode":"CUST-1003"}'
        ):

            with self.subTest(arguments=arguments):

                proposal = deepcopy(self.proposal)

                proposal["RequestArguments"] = arguments

                self.assert_blocked(
                    ["OUTPUT_CUSTOMER_BINDING"],
                    proposal=proposal
                )

    def test_rule_metadata(self):

        result = validate_output(
            self.proposal,
            self.tool_result
        )

        expected = {
            "OUTPUT_AUTHORIZATION": "CONFIDENTIAL",
            "OUTPUT_ROW_COUNT": "INTERNAL",
            "OUTPUT_SCHEMA": "CONFIDENTIAL",
            "OUTPUT_FINANCIAL_INTEGRITY": "CONFIDENTIAL",
            "OUTPUT_CUSTOMER_BINDING": "CONFIDENTIAL"
        }

        actual = {
            finding["RuleCode"]: finding["DataClassification"]
            for finding in result["Findings"]
        }

        self.assertEqual(actual, expected)

        for finding in result["Findings"]:

            self.assertEqual(finding["RuleVersion"], 1)

    def test_validation_contains_no_business_data(self):

        self.tool_result["Data"][0][
            "SocialSecurityNumber"
        ] = "123-45-6789"

        result = validate_output(
            self.proposal,
            self.tool_result
        )

        serialized = json.dumps(result)

        for sensitive_value in (
            "123-45-6789",
            "Northwind Industrial",
            "14200",
            "4200",
            "CUST-1001"
        ):

            self.assertNotIn(sensitive_value, serialized)

        expected_fields = {
            "RuleCode",
            "RuleVersion",
            "DataClassification",
            "ValidationDecision",
            "DetectionCount"
        }

        for finding in result["Findings"]:

            self.assertEqual(
                set(finding.keys()),
                expected_fields
            )


class TestOutputValidationPersistence(unittest.TestCase):

    def setUp(self):

        self.cursor = MagicMock()

        self.findings = [
            {
                "RuleCode": "OUTPUT_AUTHORIZATION",
                "RuleVersion": 1,
                "DataClassification": "CONFIDENTIAL",
                "ValidationDecision": "PASSED",
                "DetectionCount": 0
            }
        ]

    def test_successful_persistence(self):

        self.cursor.fetchone.return_value = (
            1001, 2001, "PASSED", 0
        )

        result = record_output_validation(
            self.cursor,
            1001,
            2001,
            self.findings
        )

        self.assertEqual(result, {
            "InteractionId": 1001,
            "AIToolCallId": 2001,
            "ValidationDecision": "PASSED",
            "DetectionCount": 0
        })

        self.cursor.execute.assert_called_once()

        sql, interaction_id, tool_call_id, findings = (
            self.cursor.execute.call_args.args
        )

        self.assertIn(
            "EXEC aiaf.usp_RecordOutputValidation",
            sql
        )

        self.assertEqual(interaction_id, 1001)
        self.assertEqual(tool_call_id, 2001)
        self.assertEqual(json.loads(findings), self.findings)

    def test_missing_persistence_evidence(self):

        self.cursor.fetchone.return_value = None

        with self.assertRaisesRegex(
            RuntimeError,
            "Output validation persistence returned no evidence."
        ):

            record_output_validation(
                self.cursor,
                1001,
                2001,
                self.findings
            )

    def test_database_exception_propagates(self):

        self.cursor.execute.side_effect = RuntimeError(
            "Simulated database failure."
        )

        with self.assertRaisesRegex(
            RuntimeError,
            "Simulated database failure."
        ):

            record_output_validation(
                self.cursor,
                1001,
                2001,
                self.findings
            )

        self.cursor.fetchone.assert_not_called()


if __name__ == "__main__":
    unittest.main()