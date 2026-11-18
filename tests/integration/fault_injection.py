from decimal import Decimal

from aiaf.tool_dispatcher import execute_tool


FAULT_CODES = (
    "UNEXPECTED_COLUMN",
    "INCORRECT_CUSTOMER",
    "INVALID_FINANCIAL_BALANCE"
)


def inject_output_fault(tool_result, fault_code):

    if fault_code not in FAULT_CODES:
        raise ValueError("Unknown fault injection code.")

    if (
        tool_result.get("AuthorizationDecision") != "ALLOWED"
        or tool_result.get("ExecutionStatus") != "SUCCEEDED"
        or len(tool_result.get("Data", [])) != 1
    ):
        raise RuntimeError(
            "Fault injection requires a successful "
            "and authorized tool result."
        )

    record = tool_result["Data"][0]

    if fault_code == "UNEXPECTED_COLUMN":

        record["SSN"] = "123-45-6789"

    elif fault_code == "INCORRECT_CUSTOMER":

        record["CustomerCode"] = "CUST-1003"
        record["CustomerName"] = "Fabrikam Logistics"

    elif fault_code == "INVALID_FINANCIAL_BALANCE":

        record["DisputedBalance"] = (
            record["OutstandingBalance"]
            + Decimal("1000.00")
        )

    return tool_result


def build_fault_injector(fault_code):

    if fault_code not in FAULT_CODES:
        raise ValueError("Unknown fault injection code.")

    def execute_with_fault(cursor, proposal):

        result = execute_tool(cursor, proposal)

        return inject_output_fault(
            result,
            fault_code
        )

    return execute_with_fault