import re

RULES = [
    (
        "US_SSN_PATTERN",
        1,
        "RESTRICTED",
        re.compile(r"\b\d{3}-\d{2}-\d{4}\b"),
        "[REDACTED_SSN]"
    ),
    (
        "PAYMENT_CARD_PATTERN",
        1,
        "RESTRICTED",
        re.compile(r"(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)"),
        "[REDACTED_CARD]"
    ),
    (
        "EMAIL_ADDRESS_PATTERN",
        1,
        "CONFIDENTIAL",
        re.compile(
            r"\b[A-Za-z0-9._%+-]+"
            r"@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"
        ),
        "[REDACTED_EMAIL]"
    )
]


def sanitize_input(content: str) -> dict:

    sanitized = content
    findings = []

    for code, version, classification, pattern, replacement in RULES:

        sanitized, count = pattern.subn(
            replacement,
            sanitized
        )

        findings.append({
            "RuleCode": code,
            "RuleVersion": version,
            "DataClassification": classification,
            "ValidationDecision": (
                "SANITIZED" if count else "PASSED"
            ),
            "DetectionCount": count
        })

    return {
        "SanitizedContent": sanitized,
        "ValidationDecision": (
            "SANITIZED"
            if any(f["DetectionCount"] for f in findings)
            else "PASSED"
        ),
        "Findings": findings
    }

if __name__ == "__main__":

    import json

    test_cases = {
        "Clean request":
            "What is the outstanding balance for Northwind?",

        "SSN":
            "Review Northwind. The owner's SSN is 123-45-6789.",

        "Payment card":
            "Check the payment for card 4111-1111-1111-1111.",

        "Email":
            "Review the account for customer@example.com.",

        "Multiple sensitive values":
            "Contact customer@example.com regarding "
            "SSN 123-45-6789 and card 4111-1111-1111-1111."
    }

    for test_name, content in test_cases.items():

        result = sanitize_input(content)

        print(f"\nTEST: {test_name}")
        print(json.dumps(result, indent=4))