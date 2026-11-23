import unittest

from aiaf.input_validation import sanitize_input


class TestInputValidation(unittest.TestCase):

    def test_clean_request(self):

        content = "What is the outstanding balance for Northwind?"
        result = sanitize_input(content)

        self.assertEqual(result["ValidationDecision"], "PASSED")
        self.assertEqual(result["SanitizedContent"], content)
        self.assertEqual(len(result["Findings"]), 3)

        for finding in result["Findings"]:
            self.assertEqual(finding["DetectionCount"], 0)
            self.assertEqual(finding["ValidationDecision"], "PASSED")

    def assert_sanitized(self, content, expected, expected_counts):

        result = sanitize_input(content)

        self.assertEqual(result["ValidationDecision"], "SANITIZED")
        self.assertEqual(result["SanitizedContent"], expected)

        actual_counts = {
            finding["RuleCode"]: finding["DetectionCount"]
            for finding in result["Findings"]
        }

        self.assertEqual(actual_counts, expected_counts)

        for finding in result["Findings"]:
            self.assertEqual(finding["RuleVersion"], 1)
            self.assertEqual(
                finding["ValidationDecision"],
                "SANITIZED" if finding["DetectionCount"] else "PASSED"
            )

    def test_ssn(self):

        self.assert_sanitized(
            "Review Northwind. The owner's SSN is 123-45-6789.",
            "Review Northwind. The owner's SSN is [REDACTED_SSN].",
            {
                "US_SSN_PATTERN": 1,
                "PAYMENT_CARD_PATTERN": 0,
                "EMAIL_ADDRESS_PATTERN": 0
            }
        )

    def test_payment_card(self):

        self.assert_sanitized(
            "Check the payment for card 4111-1111-1111-1111.",
            "Check the payment for card [REDACTED_CARD].",
            {
                "US_SSN_PATTERN": 0,
                "PAYMENT_CARD_PATTERN": 1,
                "EMAIL_ADDRESS_PATTERN": 0
            }
        )

    def test_email(self):

        self.assert_sanitized(
            "Review the account for customer@example.com.",
            "Review the account for [REDACTED_EMAIL].",
            {
                "US_SSN_PATTERN": 0,
                "PAYMENT_CARD_PATTERN": 0,
                "EMAIL_ADDRESS_PATTERN": 1
            }
        )

    def test_multiple_sensitive_values(self):

        self.assert_sanitized(
            "Contact customer@example.com regarding "
            "SSN 123-45-6789 and card 4111-1111-1111-1111.",

            "Contact [REDACTED_EMAIL] regarding "
            "SSN [REDACTED_SSN] and card [REDACTED_CARD].",

            {
                "US_SSN_PATTERN": 1,
                "PAYMENT_CARD_PATTERN": 1,
                "EMAIL_ADDRESS_PATTERN": 1
            }
        )

    def test_rule_metadata(self):

        result = sanitize_input("Clean request")

        expected = {
            "US_SSN_PATTERN": (1, "RESTRICTED"),
            "PAYMENT_CARD_PATTERN": (1, "RESTRICTED"),
            "EMAIL_ADDRESS_PATTERN": (1, "CONFIDENTIAL")
        }

        actual = {
            finding["RuleCode"]: (
                finding["RuleVersion"],
                finding["DataClassification"]
            )
            for finding in result["Findings"]
        }

        self.assertEqual(actual, expected)


if __name__ == "__main__":
    unittest.main()