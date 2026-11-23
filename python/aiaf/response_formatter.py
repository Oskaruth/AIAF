def format_customer_balance(record):

    return (
        f"Customer: {record['CustomerName']}\n"
        f"Customer Code: {record['CustomerCode']}\n"
        f"Outstanding Balance: "
        f"${record['OutstandingBalance']:,.2f}\n"
        f"Disputed Balance: "
        f"${record['DisputedBalance']:,.2f}\n"
        f"Open Invoices: "
        f"{record['OpenInvoiceCount']:,}\n"
        f"Disputed Invoices: "
        f"{record['DisputedInvoiceCount']:,}"
    )


def format_rejection(completion_reason):

    responses = {
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

    return responses.get(
        completion_reason,
        "The request could not be completed."
    )