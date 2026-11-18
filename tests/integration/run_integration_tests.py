
import logging
import sys

from contextlib import ExitStack
from dataclasses import dataclass
from unittest.mock import patch
from uuid import uuid4

from tests.integration.integration_support import (
    run_integration_request,
    verify_integration_environment
)

from tests.integration.fault_injection import (
    build_fault_injector
)


logger = logging.getLogger(__name__)


CUSTOMER_PROMPT = (
    "What is the outstanding balance for CUST-1001?"
)

AUTHORIZED_RESPONSE = "\n".join([
    "Customer: Northwind Industrial",
    "Customer Code: CUST-1001",
    "Outstanding Balance: $14,200.00",
    "Disputed Balance: $4,200.00",
    "Open Invoices: 3",
    "Disputed Invoices: 1"
])

AUTHORIZATION_DENIED_RESPONSE = (
    "You are not authorized to retrieve "
    "the requested information."
)

UNSUPPORTED_RESPONSE = (
    "This request is not supported by this application."
)

OUTPUT_BLOCKED_RESPONSE = (
    "The requested information could not be safely returned."
)

MODEL_FAILURE_RESPONSE = (
    "The request could not be processed."
)

GOVERNANCE_DENIED_RESPONSE = (
    "This application is not currently authorized "
    "to process the request."
)


@dataclass(frozen=True)
class Scenario:

    code: str
    prompt: str
    expected_response: str

    requesting_identity: str = "jeannine@acme.example"
    application_code: str = "ACME_ACCOUNTS_RECEIVABLE_AI"

    fault_code: str | None = None
    model_unavailable: bool = False
    expect_no_model_invocation: bool = False


SCENARIOS = (

    Scenario(
        code="AUTHORIZED_CUSTOMER",
        prompt=CUSTOMER_PROMPT,
        expected_response=AUTHORIZED_RESPONSE
    ),

    Scenario(
        code="UNRECOGNIZED_IDENTITY",
        prompt=CUSTOMER_PROMPT,
        expected_response=AUTHORIZATION_DENIED_RESPONSE,
        requesting_identity="Jeannine"
    ),

    Scenario(
        code="UNAUTHORIZED_CUSTOMER",
        prompt=(
            "What is the outstanding balance for CUST-1003?"
        ),
        expected_response=AUTHORIZATION_DENIED_RESPONSE
    ),

    Scenario(
        code="SENSITIVE_INPUT",
        prompt=(
            "My SSN is 123-45-6789. "
            "What is the outstanding balance for CUST-1001?"
        ),
        expected_response=AUTHORIZED_RESPONSE
    ),

    Scenario(
        code="UNSUPPORTED_REQUEST",
        prompt="DROP TABLE acme.Customer;",
        expected_response=UNSUPPORTED_RESPONSE
    ),

    Scenario(
        code="UNEXPECTED_COLUMN",
        prompt=CUSTOMER_PROMPT,
        expected_response=OUTPUT_BLOCKED_RESPONSE,
        fault_code="UNEXPECTED_COLUMN"
    ),

    Scenario(
        code="INCORRECT_CUSTOMER",
        prompt=CUSTOMER_PROMPT,
        expected_response=OUTPUT_BLOCKED_RESPONSE,
        fault_code="INCORRECT_CUSTOMER"
    ),

    Scenario(
        code="INVALID_FINANCIAL_BALANCE",
        prompt=CUSTOMER_PROMPT,
        expected_response=OUTPUT_BLOCKED_RESPONSE,
        fault_code="INVALID_FINANCIAL_BALANCE"
    ),

    Scenario(
        code="MODEL_UNAVAILABLE",
        prompt=CUSTOMER_PROMPT,
        expected_response=MODEL_FAILURE_RESPONSE,
        model_unavailable=True
    ),

    Scenario(
        code="GOVERNANCE_SUSPENSION",
        prompt=CUSTOMER_PROMPT,
        expected_response=GOVERNANCE_DENIED_RESPONSE,
        application_code="ACME_CUSTOMER_SERVICE_AI",
        expect_no_model_invocation=True
    )
)


def run_scenario(run_id, scenario):

    business_purpose = (
        f"AIAF_INTEGRATION|{run_id}|{scenario.code}"
    )

    with ExitStack() as stack:

        model_request = None
        fault_injector = None

        if scenario.fault_code is not None:

            fault_injector = stack.enter_context(
                patch(
                    "aiaf.pipeline.execute_tool",
                    side_effect=build_fault_injector(
                        scenario.fault_code
                    )
                )
            )

        if scenario.model_unavailable:

            stack.enter_context(
                patch(
                    "aiaf.model_client.OLLAMA_URL",
                    "http://127.0.0.1:11435/api/generate"
                )
            )

        if scenario.expect_no_model_invocation:

            model_request = stack.enter_context(
                patch("aiaf.pipeline.request_tool")
            )

        response = run_integration_request(
            scenario.prompt,
            application_code=scenario.application_code,
            requesting_identity=scenario.requesting_identity,
            business_purpose=business_purpose
        )

        if model_request is not None:
            model_request.assert_not_called()

        if fault_injector is not None:
            fault_injector.assert_called_once()

        if response != scenario.expected_response:

            raise AssertionError(
                "Application response did not match "
                "the expected response."
            )


def main():

    logging.basicConfig(
        level=logging.INFO,
        format="%(levelname)s | %(message)s"
    )

    run_id = str(uuid4())

    results = []

    print("\n" + "=" * 70, flush=True)
    print("AIAF LIVE INTEGRATION TESTS", flush=True)
    print("=" * 70, flush=True)
    print(f"RUN ID: {run_id}", flush=True)
    print(f"SCENARIOS: {len(SCENARIOS)}", flush=True)

    # -------------------------------------------------
    # Mandatory environment preflight
    # -------------------------------------------------

    print("\n" + "-" * 70, flush=True)
    print("INTEGRATION ENVIRONMENT PREFLIGHT", flush=True)
    print("-" * 70, flush=True)

    try:

        evidence = verify_integration_environment()

    except Exception as exc:

        logger.error(
            "Integration preflight failed: %s",
            exc
        )

        print("PREFLIGHT: FAIL", flush=True)
        print("SCENARIOS EXECUTED: 0", flush=True)

        return 2

    print(
        f"Expected server:    {evidence['expected_server']}",
        flush=True
    )
    print(
        f"Connected server:   {evidence['actual_server']}",
        flush=True
    )
    print(
        f"Expected database:  {evidence['expected_database']}",
        flush=True
    )
    print(
        f"Connected database: {evidence['actual_database']}",
        flush=True
    )
    print(
        f"Original login:     {evidence['original_login']}",
        flush=True
    )
    print(
        f"Runtime identity:   {evidence['database_user']}",
        flush=True
    )
    print(
        f"Runtime member:     {evidence['is_runtime_member']}",
        flush=True
    )
    print(
        f"DB owner member:    {evidence['is_db_owner']}",
        flush=True
    )

    print("PREFLIGHT: PASS", flush=True)

    # -------------------------------------------------
    # Execute integration scenarios
    # -------------------------------------------------

    for index, scenario in enumerate(SCENARIOS, start=1):

        print("\n" + "-" * 70, flush=True)

        print(
            f"[{index}/{len(SCENARIOS)}] {scenario.code}",
            flush=True
        )

        print("-" * 70, flush=True)

        try:

            run_scenario(run_id, scenario)

        except Exception as exc:

            results.append((scenario.code, False))

            logger.error(
                "Integration scenario failed: "
                "scenario=%s error_type=%s",
                scenario.code,
                type(exc).__name__
            )

            print("APPLICATION TEST: FAIL", flush=True)

        else:

            results.append((scenario.code, True))

            print("APPLICATION TEST: PASS", flush=True)

    # -------------------------------------------------
    # Summarize integration results
    # -------------------------------------------------

    passed = sum(success for _, success in results)
    failed = len(results) - passed

    print("\n" + "=" * 70, flush=True)
    print("INTEGRATION TEST SUMMARY", flush=True)
    print("=" * 70, flush=True)

    for code, success in results:

        status = "PASS" if success else "FAIL"

        print(f"{code:<30} {status}", flush=True)

    print("-" * 70, flush=True)
    print(f"PASSED: {passed}/{len(SCENARIOS)}", flush=True)
    print(f"FAILED: {failed}", flush=True)
    print(f"RUN ID: {run_id}", flush=True)
    print("INDEPENDENT SQL VERIFICATION: PENDING", flush=True)

    return 0 if failed == 0 else 1


if __name__ == "__main__":

    sys.exit(main())