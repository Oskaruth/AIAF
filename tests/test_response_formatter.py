import unittest

from decimal import Decimal

from aiaf.response_formatter import (
    format_customer_balance,
    format_rejection
)


class TestCustomerBalanceFormatting(unittest.TestCase):

    def setUp(self):

        self.record = {
            "CustomerCode": "CUST-1001",
            "CustomerName": "Northwind Industrial",
            "OutstandingBalance": Decimal("14200.00"),
            "DisputedBalance": Decimal("4200.00"),
            "OpenInvoiceCount": 3,
            "DisputedInvoiceCount": 1
        }

    def test_standard_response(self):

        expected = (
            "Customer: Northwind Industrial\n"
            "Customer Code: CUST-1001\n"
            "Outstanding Balance: $14,200.00\n"
            "Disputed Balance: $4,200.00\n"
            "Open Invoices: 3\n"
            "Disputed Invoices: 1"
        )

        self.assertEqual(
            format_customer_balance(self.record),
            expected
        )

    def test_zero_balance(self):

        self.record.update({
            "OutstandingBalance": Decimal("0.00"),
            "DisputedBalance": Decimal("0.00"),
            "OpenInvoiceCount": 0,
            "DisputedInvoiceCount": 0
        })

        result = format_customer_balance(self.record)

        self.assertIn(
            "Outstanding Balance: $0.00", result
        )

        self.assertIn(
            "Disputed Balance: $0.00", result
        )

        self.assertIn("Open Invoices: 0", result)
        self.assertIn("Disputed Invoices: 0", result)

    def test_large_financial_values(self):

        self.record.update({
            "OutstandingBalance": Decimal("1234567890.12"),
            "DisputedBalance": Decimal("1234567.89"),
            "OpenInvoiceCount": 123456,
            "DisputedInvoiceCount": 1234
        })

        result = format_customer_balance(self.record)

        self.assertIn(
            "Outstanding Balance: $1,234,567,890.12",
            result
        )

        self.assertIn(
            "Disputed Balance: $1,234,567.89",
            result
        )

        self.assertIn("Open Invoices: 123,456", result)
        self.assertIn("Disputed Invoices: 1,234", result)

    def test_decimal_precision(self):

        self.record.update({
            "OutstandingBalance": Decimal("100.01"),
            "DisputedBalance": Decimal("0.01")
        })

        result = format_customer_balance(self.record)

        self.assertIn(
            "Outstanding Balance: $100.01", result
        )

        self.assertIn(
            "Disputed Balance: $0.01", result
        )

    def test_unexpected_fields_not_exposed(self):

        expected = format_customer_balance(self.record)

        self.record.update({
            "SocialSecurityNumber": "123-45-6789",
            "InternalNotes": "Confidential accounting notes",
            "CreditLimit": Decimal("25000.00"),
            "ConnectionString": "SERVER=internal-server"
        })

        result = format_customer_balance(self.record)

        self.assertEqual(result, expected)

    def test_formatter_does_not_modify_record(self):

        original = self.record.copy()

        format_customer_balance(self.record)

        self.assertEqual(self.record, original)


class TestRejectionFormatting(unittest.TestCase):

    def test_known_rejection_reasons(self):

        expected_responses = {
            "TOOL_AUTHORIZATION_DENIED":
                "You are not authorized to retrieve "
                "the requested information.",

            "NO_SUPPORTED_TOOL":
                "This request is not supported "
                "by this application.",

            "OUTPUT_VALIDATION_BLOCKED":
                "The requested information could not "
                "be safely returned.",

            "MODEL_EXECUTION_FAILED":
                "The request could not be processed.",

            "MODEL_RESPONSE_INVALID":
                "The request could not be processed.",

            "TOOL_EXECUTION_FAILED":
                "The requested information could not "
                "be retrieved."
        }

        for reason, expected in expected_responses.items():

            with self.subTest(reason=reason):

                self.assertEqual(
                    format_rejection(reason),
                    expected
                )

    def test_unknown_rejection_reason(self):

        self.assertEqual(
            format_rejection("UNKNOWN_FAILURE"),
            "The request could not be completed."
        )

    def test_missing_rejection_reason(self):

        for reason in (None, ""):

            with self.subTest(reason=reason):

                self.assertEqual(
                    format_rejection(reason),
                    "The request could not be completed."
                )

    def test_internal_error_not_exposed(self):

        internal_errors = [
            "SQL Server error 229: Permission denied.",
            "Connection failed: internal-server",
            "MODEL_CONNECTION_ERROR",
            "GOVERNANCE_SUSPENDED",
            "CUSTOMER_ACCESS_DENIED",
            "EVIDENCE_INTEGRITY_FAILURE",
            "Traceback: unexpected exception"
        ]

        for error in internal_errors:

            with self.subTest(error=error):

                self.assertEqual(
                    format_rejection(error),
                    "The request could not be completed."
                )


if __name__ == "__main__":
    unittest.main()