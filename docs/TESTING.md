# AIAF Testing and Verification

## 1. Overview

The AI Interaction Audit Framework (AIAF) implements multiple layers of testing to validate application behavior, database security controls, governance enforcement, and persisted audit evidence.

A successful AI response is not sufficient evidence that an AI architecture is operating correctly.

AIAF testing is designed to establish that:

- Authorized requests are processed correctly.
- Unauthorized requests are blocked.
- Governance decisions are enforced before model execution.
- Sensitive input is sanitized.
- Model-generated tool requests are independently authorized.
- Retrieved information is validated before release.
- Model failures are handled safely.
- Audit evidence accurately reflects the expected interaction lifecycle.
- Selected sensitive payloads are not persisted in audit records.

**Trust nothing. Test everything. Keep the receipts.**

## 2. Testing Architecture

AIAF uses four complementary layers of verification.

| Testing Layer | Purpose |
|---|---|
| Python unit testing | Validate individual application components and execution paths. |
| SQL Server security testing | Validate effective database permissions and runtime restrictions. |
| Live integration testing | Exercise the application using an actual language model and database. |
| Independent evidence verification | Compare persisted database evidence against expected scenario outcomes. |

Application integration testing and independent evidence verification are intentionally separate.

A successful application test does not automatically establish that the appropriate audit evidence was persisted.

Similarly, the presence of audit evidence does not automatically establish that an application behaved correctly.

## 3. Repository Structure

The testing framework is organized as follows:

```text
tests/
├── __init__.py
├── test_input_validation.py
├── test_interaction_lifecycle.py
├── test_model_client.py
├── test_output_validation.py
├── test_pipeline.py
├── test_response_formatter.py
├── test_tool_dispatcher.py
└── integration/
    ├── __init__.py
    ├── fault_injection.py
    ├── integration_support.py
    ├── run_integration_tests.py
    └── verify_integration_results.sql
```

Fault injection and integration testing support are isolated from the application package.

The application does not require access to the testing framework during normal execution.

## 4. Prerequisites

The reference implementation requires:

- SQL Server 2022 or later.
- A deployed AIAF database.
- A supported Python environment.
- The pyodbc Python package.
- Microsoft ODBC Driver 18 for SQL Server.
- Ollama with the configured language model available locally.
- A configured restricted database runtime identity.
- Synthetic application, customer, invoice, authorization, and governance reference data.

Live integration tests must be executed against a dedicated testing environment.

Do not execute the integration suite against a production database.

## 5. Environment Configuration

Execute the following commands from the root of the AIAF repository.

The following example uses PowerShell:

```powershell
$env:PYTHONPATH = (Resolve-Path .\python).Path

$env:AIAF_DB_SERVER = "localhost"
$env:AIAF_DB_NAME = "AIAF_Lab"
$env:AIAF_DB_DRIVER = "ODBC Driver 18 for SQL Server"
$env:AIAF_DB_TRUST_CERTIFICATE = "yes"

$env:AIAF_MODEL_NAME = "qwen3:8b"
$env:AIAF_OLLAMA_URL = "http://localhost:11434/api/generate"
$env:AIAF_MODEL_TIMEOUT_SECONDS = "120"
```

Adjust these values to match the local testing environment.

Trusting the SQL Server certificate is provided as a convenience for local laboratory environments. Production deployments should use properly validated certificates.

Verify that the language model is installed:

```powershell
ollama list
```

Verify that the live model endpoint is reachable:

```powershell
Test-NetConnection -ComputerName 127.0.0.1 `
    -Port 11434 -InformationLevel Quiet
```

Expected result:

```text
True
```

Verify that the port used for simulated model unavailability is not reachable:

```powershell
Test-NetConnection -ComputerName 127.0.0.1 `
    -Port 11435 -InformationLevel Quiet
```

Expected result:

```text
False
```

The simulated model outage test temporarily redirects model requests to the unused endpoint. It does not require shutting down the live Ollama service.

## 6. Python Unit Testing

Execute the unit test suite:

```powershell
python -m unittest discover -s tests -p "test_*.py" -v
```

The initial validated release contains 103 unit tests covering seven application components.

| Component | Test Coverage Area |
|---|---|
| Input validation | Sensitive data detection and sanitization |
| Interaction lifecycle | Interaction creation and terminal state handling |
| Model client | Model communication, response validation, and telemetry |
| Output validation | Schema, authorization, customer binding, and financial integrity |
| Pipeline | Application orchestration and failure handling |
| Response formatter | Authorized response and rejection message formatting |
| Tool dispatcher | Tool proposal handling and execution result validation |

Expected result:

```text
Ran 103 tests

OK
```

Unit tests use controlled inputs and mocks where appropriate. They do not replace live integration testing.

## 7. Database Security Verification

AIAF separates application execution permissions from administrative and governance permissions.

The runtime identity is expected to execute approved stored procedures while being restricted from directly reading or modifying protected tables.

Database security testing should verify:

- Execution of approved application procedures.
- Denial of direct access to protected application data.
- Denial of direct modification of audit evidence.
- Denial of unauthorized governance operations.
- Absence of database owner privileges.
- Correct assignment of runtime role membership.

The original laboratory implementation passed 20 effective permission checks and one restricted Python database connection check.

The repeatable database security verification scripts will be incorporated into the deployment testing package.

### Laboratory Runtime Identity

The live integration suite uses the `AIAF_TestRuntime` database user to exercise restricted runtime permissions.

The integration testing helper uses SQL Server impersonation to establish the restricted execution context and verifies that context before processing requests.

This is a laboratory testing mechanism, not a recommended production authentication architecture.

## 8. Live Integration Testing

Execute the consolidated integration suite:

```powershell
python -m tests.integration.run_integration_tests
```

The runner generates a unique identifier for each execution and associates that identifier with the business purpose of each interaction.

This allows the persisted evidence for a specific test run to be independently retrieved without relying on interaction identifiers assigned by the database.

### Integration Scenarios

| Scenario | Expected Interaction Status | Expected Completion Reason |
|---|---|---|
| AUTHORIZED_CUSTOMER | COMPLETED | OUTPUT_APPROVED_FOR_RELEASE |
| UNRECOGNIZED_IDENTITY | BLOCKED | TOOL_AUTHORIZATION_DENIED |
| UNAUTHORIZED_CUSTOMER | BLOCKED | TOOL_AUTHORIZATION_DENIED |
| SENSITIVE_INPUT | COMPLETED | OUTPUT_APPROVED_FOR_RELEASE |
| UNSUPPORTED_REQUEST | BLOCKED | NO_SUPPORTED_TOOL |
| UNEXPECTED_COLUMN | BLOCKED | OUTPUT_VALIDATION_BLOCKED |
| INCORRECT_CUSTOMER | BLOCKED | OUTPUT_VALIDATION_BLOCKED |
| INVALID_FINANCIAL_BALANCE | BLOCKED | OUTPUT_VALIDATION_BLOCKED |
| MODEL_UNAVAILABLE | FAILED | MODEL_EXECUTION_FAILED |
| GOVERNANCE_SUSPENSION | BLOCKED | GOVERNANCE_SUSPENDED |

An interaction with a status of BLOCKED or FAILED may represent a successful integration test.

The test evaluates whether the system behaved as expected, not whether the AI successfully returned information.

### Fault Injection

The integration suite deliberately introduces three output defects:

- An unexpected sensitive column.
- A customer identifier that does not match the requested customer.
- An invalid financial balance.

These defects are introduced into the retrieved results before application output validation.

The underlying model execution, tool authorization, and database retrieval remain active.

This demonstrates that successful data retrieval does not bypass independent output validation.

Fault injection is implemented exclusively within the testing framework.

### Expected Integration Summary

```text
PASSED: 10/10
FAILED: 0
RUN ID: <generated-run-id>
INDEPENDENT SQL VERIFICATION: PENDING
```

The runner returns exit code 0 when all application integration tests pass and a nonzero exit code when one or more tests fail.

In PowerShell, inspect the exit code immediately after execution:

```powershell
$LASTEXITCODE
```

Retain the generated Run ID for independent evidence verification.

## 9. Independent SQL Evidence Verification

Open the following script in SQL Server Management Studio:

```text
tests/integration/verify_integration_results.sql
```

Set the Run ID to the value generated by the integration test runner:

```sql
DECLARE @RunId UNIQUEIDENTIFIER =
    '<generated-run-id>';
```

Execute the complete script against the same database used for integration testing under an authorized verification identity.

The verification script reads persisted evidence and uses temporary tables to evaluate expected and actual results.

It does not modify permanent AIAF records.

### Verification Areas

The independent verifier evaluates:

- Scenario coverage and duplicate interactions.
- Interaction status and completion reason.
- Governance decisions.
- Input validation counts and detections.
- Model execution status and telemetry.
- Model-generated tool requests.
- Tool authorization and execution outcomes.
- Returned row counts.
- Individual validation rule outcomes.
- Output validation counts and detections.
- Interaction lifecycle timestamps.
- Ledger event counts and sequences.
- Targeted sensitive payload leakage.
- Response delivery confirmation semantics.

### Expected Aggregate Evidence

A successful execution of the ten-scenario integration suite is expected to produce:

| Evidence Type | Expected Count |
|---|---:|
| Interactions | 10 |
| Input validation records | 27 |
| Model executions | 9 |
| Model tool requests | 8 |
| Tool calls | 7 |
| Output validation records | 25 |
| Ledger events | 67 |
| **Total persisted evidence records** | **153** |

Additional expected metrics:

| Metric | Expected Count |
|---|---:|
| Input detections | 1 |
| Output detections | 5 |
| Persisted validation content records | 0 |

Detection counts are attributes of validation records and are not additional persisted evidence records.

### Expected Final Verification Results

| Metric | Expected Result |
|---|---|
| ExpectedScenarios | 10 |
| PassedScenarios | 10 |
| FailedScenarios | 0 |
| VerificationFailures | 0 |
| VerificationStatus | PASS |

Successful verification produces the following message:

```text
AIAF independent integration verification PASSED.
```

If verification fails, the script returns assertion-level failure details and raises SQL Server error 52500.

A missing Run ID or missing interaction evidence must never produce a successful verification result.

## 10. Validated Reference Execution

The consolidated integration suite was successfully executed and independently verified on November 16, 2026.

| Metric | Validated Result |
|---|---:|
| Python unit tests | 103 |
| Live application integration tests passed | 10 of 10 |
| Independently verified integration scenarios | 10 of 10 |
| Persisted evidence records | 153 |
| Verification failures | 0 |
| Persisted validation content records | 0 |

The ten integration scenarios resulted in:

- Two interactions completed and approved for response release.
- Seven interactions blocked.
- One interaction failed safely.

Five interactions successfully retrieved authorized customer information.

Three of those five interactions were subsequently blocked by independent output validation.

This demonstrates the architectural distinction between authorization to retrieve information and authorization to release information.

## 11. Troubleshooting

### Python Import Errors

Verify that execution is occurring from the repository root and that the application package is available through the Python path.

```powershell
$env:PYTHONPATH = (Resolve-Path .\python).Path
```

### Database Connection Failures

Verify:

- SQL Server availability.
- Database name and server configuration.
- ODBC driver installation.
- Authentication and certificate configuration.
- Runtime identity and role configuration.

### Model Connection Failures

Verify that Ollama is running, the configured model is installed, and the configured endpoint is reachable.

Model connection failure is expected only in the deliberately simulated MODEL_UNAVAILABLE scenario.

### Unexpected Model Responses

Language model behavior may vary between models, versions, configurations, and executions.

A model that produces an unexpected tool request or invalid response may cause an integration test to fail.

Investigate the behavior rather than weakening the expected result solely to obtain a passing test.

### SQL Verification Failure

Review the assertion-level failure result set.

Each reported failure identifies the scenario, interaction identifier where available, assertion code, expected value, and actual value.

Do not delete or modify persisted evidence simply to make verification pass.

### SQL Aggregate Warnings

SQL Server may report that NULL values were eliminated by aggregate operations.

These warnings can occur during legitimate aggregation of optional evidence and telemetry fields.

They do not independently indicate verification failure.

Unknown or unavailable telemetry must not be converted to zero merely to suppress warnings.

### Performance Variability

Live integration tests depend on local hardware, model initialization, available memory, database connectivity, and other environmental factors.

The integration suite is a functional verification suite, not a performance benchmark.

## 12. Testing Limitations

AIAF is an architectural reference implementation, not a certified security product.

Successful testing does not establish:

- Comprehensive protection against prompt injection.
- Comprehensive sensitive data detection or prevention.
- Independent authentication of every asserted identity.
- Independent verification of every application-reported fact.
- Production scalability or performance guarantees.
- Comprehensive concurrency and crash recovery behavior.
- Exactly-once interaction processing.
- Confirmed end-user delivery of approved responses.
- Cryptographic ledger integrity verification through an independently trusted digest.

Ledger event sequence verification validates expected recorded events. It is not equivalent to cryptographic ledger verification.

Sensitive payload checks are targeted assertions against known synthetic test data. They are not a comprehensive data loss prevention mechanism.

Production adoption requires additional security engineering, operational controls, independent review, and environment-specific testing.

## 13. Testing Philosophy

The objective of AIAF testing is not to demonstrate that an AI model can be trusted.

The objective is to demonstrate that an architecture can control what an AI model is permitted to do, validate the results of those actions, and retain evidence of the decisions made throughout the interaction.

The model requests.

The system decides.

The architecture keeps the receipts.