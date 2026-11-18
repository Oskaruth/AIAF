import json
import re

from decimal import Decimal


RULE_DEFINITIONS = {
    "OUTPUT_AUTHORIZATION": "CONFIDENTIAL",
    "OUTPUT_ROW_COUNT": "INTERNAL",
    "OUTPUT_SCHEMA": "CONFIDENTIAL",
    "OUTPUT_FINANCIAL_INTEGRITY": "CONFIDENTIAL",
    "OUTPUT_CUSTOMER_BINDING": "CONFIDENTIAL"
}


EXPECTED_COLUMNS = {
    "CustomerCode",
    "CustomerName",
    "OutstandingBalance",
    "DisputedBalance",
    "OpenInvoiceCount",
    "DisputedInvoiceCount"
}


def validate_output(proposal, tool_result):

    findings = []

    def add_finding(rule_code, passed):

        findings.append({
            "RuleCode": rule_code,
            "RuleVersion": 1,
            "DataClassification": RULE_DEFINITIONS[rule_code],
            "ValidationDecision": (
                "PASSED" if passed else "BLOCKED"
            ),
            "DetectionCount": 0 if passed else 1
        })

    data = tool_result.get("Data", [])

    # Rule 1: Authorization and successful execution.

    authorization_valid = (
        tool_result.get("AuthorizationDecision") == "ALLOWED"
        and tool_result.get("ExecutionStatus") == "SUCCEEDED"
        and type(proposal.get("InteractionId")) is int
        and proposal["InteractionId"] > 0
        and type(tool_result.get("InteractionId")) is int
        and tool_result["InteractionId"]
            == proposal["InteractionId"]
        and type(proposal.get("ModelToolRequestId")) is int
        and proposal["ModelToolRequestId"] > 0
        and type(tool_result.get("ModelToolRequestId")) is int
        and tool_result["ModelToolRequestId"]
            == proposal["ModelToolRequestId"]
        and proposal.get("ToolCode") == "GetCustomerBalance"
        and tool_result.get("ToolCode")
            == proposal["ToolCode"]
        and type(tool_result.get("AIToolCallId")) is int
        and tool_result["AIToolCallId"] > 0
    )

    add_finding(
        "OUTPUT_AUTHORIZATION",
        authorization_valid
    )

    # Rule 2: Expected number of rows.

    row_count_valid = (
        isinstance(data, list)
        and len(data) == 1
        and type(tool_result.get("RowsReturned")) is int
        and tool_result["RowsReturned"] == 1
    )

    add_finding(
        "OUTPUT_ROW_COUNT",
        row_count_valid
    )

    # Rule 3: Expected output schema.

    record = data[0] if row_count_valid else {}

    schema_valid = (
        isinstance(record, dict)
        and set(record.keys()) == EXPECTED_COLUMNS
    )

    add_finding(
        "OUTPUT_SCHEMA",
        schema_valid
    )

    # Rule 4: Financial integrity.

    financial_valid = False

    if schema_valid:

        outstanding = record["OutstandingBalance"]
        disputed = record["DisputedBalance"]
        open_count = record["OpenInvoiceCount"]
        disputed_count = record["DisputedInvoiceCount"]

        financial_valid = (
            isinstance(outstanding, Decimal)
            and isinstance(disputed, Decimal)
            and outstanding.is_finite()
            and disputed.is_finite()
            and outstanding >= 0
            and disputed >= 0
            and disputed <= outstanding
            and type(open_count) is int
            and type(disputed_count) is int
            and open_count >= 0
            and disputed_count >= 0
            and disputed_count <= open_count
            and (outstanding > 0) == (open_count > 0)
            and (disputed > 0) == (disputed_count > 0)
        )

    add_finding(
        "OUTPUT_FINANCIAL_INTEGRITY",
        financial_valid
    )

    # Rule 5: Customer binding.

    customer_valid = False

    if schema_valid:

        try:

            arguments = json.loads(
                proposal["RequestArguments"]
            )

            customer_code = record["CustomerCode"]
            customer_name = record["CustomerName"]

            customer_valid = (
                isinstance(customer_code, str)
                and re.fullmatch(
                    r"CUST-[0-9]{4}",
                    customer_code
                ) is not None
                and customer_code == arguments["CustomerCode"]
                and isinstance(customer_name, str)
                and bool(customer_name.strip())
                and len(customer_name) <= 400
                and customer_name.isprintable()
            )

        except (ValueError, KeyError, TypeError):

            customer_valid = False

    add_finding(
        "OUTPUT_CUSTOMER_BINDING",
        customer_valid
    )

    detection_count = sum(
        finding["DetectionCount"]
        for finding in findings
    )

    return {
        "ValidationDecision": (
            "PASSED" if detection_count == 0 else "BLOCKED"
        ),
        "DetectionCount": detection_count,
        "Findings": findings
    }

def record_output_validation(
    cursor,
    interaction_id,
    ai_tool_call_id,
    findings
):

    cursor.execute(
        """
        EXEC aiaf.usp_RecordOutputValidation
            @InteractionId = ?,
            @AIToolCallId = ?,
            @Findings = ?;
        """,
        interaction_id,
        ai_tool_call_id,
        json.dumps(findings)
    )

    row = cursor.fetchone()

    if row is None:

        raise RuntimeError(
            "Output validation persistence returned no evidence."
        )

    return {
        "InteractionId": row[0],
        "AIToolCallId": row[1],
        "ValidationDecision": row[2],
        "DetectionCount": row[3]
    }

if __name__ == "__main__":

    from copy import deepcopy

    proposal = {
        "InteractionId": 1,
        "ModelToolRequestId": 1,
        "ToolCode": "GetCustomerBalance",
        "RequestArguments": '{"CustomerCode":"CUST-1001"}'
    }

    valid_result = {
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

    test_cases = {
        "Valid result": deepcopy(valid_result),
        "Unauthorized result": deepcopy(valid_result),
        "Unexpected column": deepcopy(valid_result),
        "Incorrect customer": deepcopy(valid_result),
        "Invalid financial balance": deepcopy(valid_result),
        "Incorrect row count": deepcopy(valid_result),
        "Incorrect financial data type": deepcopy(valid_result),
        "Incorrect proposal binding": deepcopy(valid_result)
    }

    test_cases["Unauthorized result"][
        "AuthorizationDecision"
    ] = "DENIED"

    test_cases["Unexpected column"]["Data"][0][
        "SocialSecurityNumber"
    ] = "123-45-6789"

    test_cases["Incorrect customer"]["Data"][0][
        "CustomerCode"
    ] = "CUST-1003"

    test_cases["Invalid financial balance"]["Data"][0][
        "DisputedBalance"
    ] = Decimal("20000.00")

    test_cases["Incorrect row count"][
        "RowsReturned"
    ] = 2

    test_cases["Incorrect financial data type"]["Data"][0][
        "OutstandingBalance"
    ] = "14200.00"

    test_cases["Incorrect proposal binding"][
        "ModelToolRequestId"
    ] = 999

    for test_name, result in test_cases.items():

        validation = validate_output(proposal, result)

        expected = (
            "PASSED"
            if test_name == "Valid result"
            else "BLOCKED"
        )

        test_result = (
            "PASS"
            if validation["ValidationDecision"] == expected
            else "FAIL"
        )

        print(f"\nTEST: {test_name}")
        print(f"Expected: {expected}")
        print(f"Actual:   {validation['ValidationDecision']}")
        print(f"Result:   {test_result}")

        for finding in validation["Findings"]:

            if finding["ValidationDecision"] == "BLOCKED":

                print(f"  Blocked by: {finding['RuleCode']}")