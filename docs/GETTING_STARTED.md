# AIAF — Getting started

**Reference environment:** SQL Server 2022 Developer Edition (Windows), Python, Ollama, `qwen3:8b`  
**Lab validated:** November 15, 2026  
**Scope:** Synthetic, read-only accounts-receivable workflow; not a production deployment.

See [Architecture](ARCHITECTURE.md) and [Production readiness](PRODUCTION_READINESS.md) before adapting this lab to real data.

> The model requests. The system decides.

## 1. Before you begin

Use an isolated development instance and synthetic data only. SQL Server Developer Edition is not licensed for production use. Install:

- SQL Server 2022 Developer Edition or a compatible later version, with a supported current patch level.
- SQL Server Management Studio (SSMS), or another SQL client capable of executing batches containing `GO`.
- Python 3 (3.11 or later is a suggested starting point, not a verified minimum).
- Microsoft ODBC Driver 18 for SQL Server.
- Ollama and sufficient disk space and memory for the approximately 5.2 GB `qwen3:8b` model. Performance depends on hardware.
- Git (optional if using a repository archive).

The original lab used SQL Server 2022, Windows integrated authentication, and a local Ollama endpoint. No cloud API key is required. Initial model download requires internet access. Local inference still consumes compute resources.

## 2. Obtain the repository and prepare Python

Clone the AIAF repository using its GitHub **Code** menu, then open PowerShell in the repository root. Alternatively, extract its archive and open that directory.

```powershell
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install pyodbc
.\.venv\Scripts\python.exe --version
.\.venv\Scripts\python.exe -c "import pyodbc; print(pyodbc.drivers())"
```

Verify that `ODBC Driver 18 for SQL Server` appears. Use the virtual environment interpreter for subsequent Python commands. If a dependency manifest is supplied with the finalized release, prefer its pinned versions. The original exact Python and pyodbc versions are not established here.

## 3. Prepare SQL Server

Connect to your development instance in SSMS using an administrator authorized to create a dedicated lab database. Run the following only for a new lab; do not drop or overwrite existing databases.

```sql
USE master;
GO
IF DB_ID(N'AIAF_Lab') IS NULL
    CREATE DATABASE AIAF_Lab COLLATE Latin1_General_100_CI_AS_SC_UTF8;
GO
ALTER DATABASE AIAF_Lab SET COMPATIBILITY_LEVEL = 160;
ALTER DATABASE AIAF_Lab SET ALLOW_SNAPSHOT_ISOLATION ON;
GO
USE AIAF_Lab;
GO
SELECT @@VERSION AS SqlVersion, DB_NAME() AS DatabaseName;
SELECT compatibility_level, snapshot_isolation_state_desc,
       is_read_committed_snapshot_on
FROM sys.databases WHERE database_id = DB_ID();
```

The original lab used compatibility 160, snapshot isolation enabled and read-committed snapshot disabled. Database-wide ledger is not required: the event table itself is append-only ledger enabled.

### SQL deployment order — release assembly checkpoint

The final numbered deployment scripts and their paths must be reconciled against the completed repository before this section can serve as an unattended installation. Earlier article scripts are incremental demonstrations and may define incompatible earlier versions of objects. Do not blindly execute every historical script or seed twice. Use the final definitions in dependency order:

| Order | Required objects / data |
|---|---|
| 1 | Schemas `aiaf`, `aiaf_governance`, `acme`, `aiaf_tool` (and `aiaf_lab` if needed by historical demos) |
| 2 | Application registry; synthetic Customer and Invoice tables; core AIInteraction and AIToolCall tables; governance review, item, action and attestation tables; customer entitlements |
| 3 | AIInteractionEvent append-only ledger; AIModelExecution; AIModelToolRequest; final AIToolCall proposal FK and unique index; AIValidation with input/output linkage; final constraints and indexes |
| 4 | Governance freeze and attestation procedures; governance gate; begin interaction; input validation; model execution recording; model proposal recording; final GetCustomerBalance; output validation; interaction finalization; operating cost view |
| 5 | Runtime role, test user, schema denials and individual procedure execution grants; governance roles if running review demos |
| 6 | Synthetic customers/invoices, application registrations, entitlements, frozen and attested reviews (approved AR and suspended Customer Service) |
| 7 | Optional earlier heartbeat, drift and historical test fixtures; keep these separate from fresh end-to-end tests |

Create ledger tables using their final ledger-enabled definitions, not ordinary tables that you expect to convert in place. Ensure final foreign keys and procedure versions are installed; historical examples are not substitutes for the latest implementation. Create reviews using the freeze/attestation procedures so evidence hashes and decisions agree. Do not copy historical identity values or hashes as if they were portable seed data.

**Current blocker:** A consolidated clean-install SQL script set has not yet been verified against a fresh database. If the release does not include the final definitions and seed scripts, stop here and obtain them before proceeding. This document is a setup and validation guide, not a replacement for those scripts.

### Check required objects

```sql
USE AIAF_Lab;
GO
SELECT v.ObjectName, CASE WHEN OBJECT_ID(v.ObjectName) IS NULL
    THEN 'MISSING' ELSE 'PRESENT' END AS ObjectStatus
FROM (VALUES
 ('aiaf.AIApplication'), ('aiaf.AIInteraction'),
 ('aiaf.AIInteractionEvent'), ('aiaf.AICustomerAccess'),
 ('aiaf.AIModelExecution'), ('aiaf.AIModelToolRequest'),
 ('aiaf.AIToolCall'), ('aiaf.AIValidation'),
 ('aiaf_governance.AIReview'), ('aiaf_governance.AIReviewItem'),
 ('aiaf_governance.AIReviewAction'), ('aiaf_governance.AIReviewAttestation'),
 ('acme.Customer'), ('acme.Invoice'),
 ('aiaf_governance.usp_FreezeReview'), ('aiaf_governance.usp_AttestReview'),
 ('aiaf.usp_EvaluateGovernanceGate'), ('aiaf.usp_BeginInteraction'),
 ('aiaf.usp_RecordInputValidation'), ('aiaf.usp_RecordModelExecution'),
 ('aiaf.usp_RecordModelToolRequest'), ('aiaf_tool.GetCustomerBalance'),
 ('aiaf.usp_RecordOutputValidation'), ('aiaf.usp_CompleteInteraction')
) v(ObjectName);

SELECT name, type_desc FROM sys.database_principals
WHERE name IN ('AIAF_Runtime','AIAF_TestRuntime');
SELECT name, ledger_type_desc FROM sys.tables
WHERE object_id = OBJECT_ID('aiaf.AIInteractionEvent');
```

All listed objects should exist, both principals should exist and the event table must report `APPEND_ONLY_LEDGER_TABLE`. Presence does not verify procedure contents or permissions.

### Verify synthetic fixtures

| Customer | Code | Outstanding | Disputed | Open / disputed invoices | Jeannine read access |
|---|---|---:|---:|---|---|
| Northwind Industrial | CUST-1001 | $14,200 | $4,200 | 3 / 1 | Yes |
| Contoso | CUST-1002 | $41,000 | $9,000 | 2 / 1 | Yes |
| Fabrikam Logistics | CUST-1003 | $109,000 | $0 | Not required for tests | No |

The requesting identity is `jeannine@acme.example`. `ACME_ACCOUNTS_RECEIVABLE_AI` must be enabled and have a valid APPROVED attestation; `ACME_CUSTOMER_SERVICE_AI` must be enabled and SUSPENDED by governance. Do not substitute merely disabling the second application: that exercises a different gate reason.

## 4. Configure and test Ollama

```powershell
ollama --version
ollama pull qwen3:8b
ollama list
Invoke-RestMethod -Uri 'http://localhost:11434/api/tags'
```

If the endpoint is unavailable, start Ollama (or run `ollama serve` if it is not already running). Keep it local; do not expose an unauthenticated inference endpoint to the network.

```powershell
$body = @{model='qwen3:8b';prompt='Reply with OK';stream=$false;think=$false} | ConvertTo-Json
Invoke-RestMethod -Uri 'http://localhost:11434/api/generate' -Method Post -ContentType 'application/json' -Body $body
```

Verify a response is returned. This is only a connectivity check, not a security or structured-output test. The model tag can resolve to a different artifact over time; record the installed model ID and Ollama version for reproducibility.

## 5. Configure the Python reference implementation

Expected final modules (under `python/` in the proposed repository layout):

- `database.py`, `pipeline.py`, `model_client.py`
- `input_validation.py`, `output_validation.py`, `tool_dispatcher.py`
- `interaction_lifecycle.py`, `response_formatter.py`, `fault_injection.py`

In `database.py`, configure your SQL instance and database. Example lab connection string:

```python
connection_string = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=localhost;DATABASE=AIAF_Lab;"
    "Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;"
)
# get_connection() returns pyodbc.connect(connection_string, autocommit=True)
```

Use your actual server/instance name instead of `localhost`. `TrustServerCertificate=yes` is a lab-only exception; use validated TLS for production. The lab uses autocommit because the security procedures manage their own transactions and several reject caller-owned transactions.

The Python process connects as an authorized development Windows login, then uses `EXECUTE AS USER = 'AIAF_TestRuntime'` and `REVERT`. This simulates a restricted runtime database principal, not an authenticated end-user boundary. Do not reuse a database administrator as an application login in production.

In `model_client.py`, verify `MODEL_NAME = "qwen3:8b"` and `OLLAMA_URL = "http://localhost:11434/api/generate"`. In the final `pipeline.py`, the approved application is the default, with an `application_code` override for the suspension test. Neither the identity nor application should be chosen by untrusted prompt content.

From the repository root:

```powershell
.\.venv\Scripts\python.exe -c "import sys; sys.path.insert(0,'python'); from database import get_connection; c=get_connection(); print(c.cursor().execute('SELECT DB_NAME()').fetchone()[0]); c.close()"
.\.venv\Scripts\python.exe .\python\pipeline.py
```

Adjust paths if the finalized repository layout differs. Confirm the database name is `AIAF_Lab`. The pipeline's main harness runs four basic scenarios; avoid running it if you only want the nine-scenario test suite below.

## 6. Run the end-to-end tests

The lab used `test_response_delivery.py`, `test_model_unavailable.py` and `test_governance_suspension.py`. The following commands assume the final test files reside under `tests/` and modules under `python/`; their repository placement is a proposed release convention.

```powershell
$env:PYTHONPATH = (Resolve-Path .\python).Path
.\.venv\Scripts\python.exe .\tests\test_response_delivery.py
.\.venv\Scripts\python.exe .\tests\test_model_unavailable.py
.\.venv\Scripts\python.exe .\tests\test_governance_suspension.py
```

The unavailable-model test temporarily redirects the endpoint to port 11435; verify nothing is listening there before running it. It restores the normal URL afterward. Fault-injection tests are development-only and must never be deployed as production request options.

| Scenario | Expected terminal status | Expected evidence / response |
|---|---|---|
| Authorized Northwind | COMPLETED | OUTPUT_APPROVED_FOR_RELEASE; $14,200 outstanding, $4,200 disputed, 3 open / 1 disputed |
| Unauthorized Fabrikam | BLOCKED | TOOL_AUTHORIZATION_DENIED; no financial response |
| Northwind with synthetic SSN | COMPLETED | One input detection, sanitized before model; same authorized balance |
| DROP TABLE prompt injection | BLOCKED | NO_SUPPORTED_TOOL; no tool executed for the demonstrated prompt |
| Unexpected SSN column | BLOCKED | OUTPUT_VALIDATION_BLOCKED; 3 blocked rules |
| Incorrect customer | BLOCKED | OUTPUT_VALIDATION_BLOCKED; 1 blocked rule |
| Invalid financial balance | BLOCKED | OUTPUT_VALIDATION_BLOCKED; 1 blocked rule |
| Model unavailable | FAILED | MODEL_EXECUTION_FAILED; MODEL_CONNECTION_ERROR; no tool proposal |
| Suspended application | BLOCKED | GOVERNANCE_SUSPENDED; no input validation or model invocation |

Inspect each returned response and persisted evidence. Model selection is probabilistic even at temperature zero; deviations should be investigated rather than disguised as passes. The security contract must prevent unauthorized access even if the model selects the wrong tool. COMPLETED denotes approval for release, not confirmed delivery.

## 7. Verify persisted evidence

Before running the suite, record the maximum interaction ID (use zero for empty tables):

```sql
SELECT COALESCE(MAX(InteractionId),0) AS BeforeInteractionId
FROM aiaf.AIInteraction;
```

After running the suite, replace the example `0` below with that saved value. Run in an isolated lab without concurrent requests. Inspect outcomes without selecting raw financial information.

```sql
DECLARE @Before bigint = 0; -- replace with captured watermark
SELECT i.InteractionId, i.CorrelationId, i.InteractionStatus,
       i.CompletedAt, m.ExecutionStatus AS ModelStatus,
       m.ErrorCode, p.ToolCode, t.AuthorizationDecision,
       t.AuthorizationReason, t.RowsReturned,
       JSON_VALUE(f.EventDetails,'$.CompletionReason') AS CompletionReason
FROM aiaf.AIInteraction i
LEFT JOIN aiaf.AIModelExecution m ON m.InteractionId=i.InteractionId
LEFT JOIN aiaf.AIModelToolRequest p ON p.ModelExecutionId=m.ModelExecutionId
LEFT JOIN aiaf.AIToolCall t ON t.ModelToolRequestId=p.ModelToolRequestId
LEFT JOIN aiaf.AIInteractionEvent f ON f.InteractionId=i.InteractionId
    AND f.EventCode='INTERACTION_FINALIZED'
WHERE i.InteractionId>@Before ORDER BY i.InteractionId;

SELECT v.InteractionId,v.ValidationStage,v.RuleCode,
       v.RuleVersion,v.ValidationDecision,v.DetectionCount,
       CASE WHEN v.SanitizedContent IS NULL THEN 0 ELSE 1 END AS ContentPersisted
FROM aiaf.AIValidation v WHERE v.InteractionId>@Before
ORDER BY v.InteractionId,v.ValidationId;

SELECT InteractionId,InteractionEventId,EventCode,EventOutcome,EventDetails
FROM aiaf.AIInteractionEvent WHERE InteractionId>@Before
ORDER BY InteractionId,InteractionEventId;
```

Expected for exactly one clean nine-test run: 2 completed, 6 blocked, 1 failed; 8 model execution records (including failed attempt), 7 proposals, 6 tool calls, 24 input rule records, 25 output rule records, 8 finalization events. The governance-blocked interaction is terminal at registration and has no separate finalization event. All new validation records should have `ContentPersisted=0`. Review event details for unexpected payloads; null validation content alone does not prove absence of leakage elsewhere. Historical inventory counts and interaction IDs are not fresh-install targets.

### Verify restricted database access

Run as the lab administrator in a dedicated SSMS session:

```sql
EXECUTE AS USER = 'AIAF_TestRuntime';
SELECT USER_NAME() AS RuntimeUser;
BEGIN TRY
    SELECT TOP (1) CustomerId FROM acme.Customer;
    SELECT 'FAIL: direct table access permitted' AS TestResult;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
REVERT;
```

Expect permission denied (229), while approved procedure-based tests succeed. Repeat for direct audit writes, entitlement changes and governance procedure execution in a controlled test transaction or against disposable fixtures; do not perform destructive operations against retained evidence. An unexpected grant is a release blocker.

## 8. Generate, export and verify a ledger digest

Use a privileged verification session, not the application runtime.

```sql
USE AIAF_Lab;
GO
EXEC sys.sp_generate_database_ledger_digest;
SELECT block_id, block_size, transactions_root_hash, previous_block_hash
FROM sys.database_ledger_blocks ORDER BY block_id;
```

Copy the complete `latest_digest` JSON from your own database to a file outside the repository and SQL Server, e.g. `%USERPROFILE%\AIAF_Evidence\Digests\AIAF_Lab_checkpoint.json`. Do not reuse the historical digest from the article. Retain the original bytes and never modify that file for negative tests.

To verify, paste the saved JSON object (not a newly generated digest) into the following template:

```sql
DECLARE @Digest nvarchar(max) = N'<paste saved JSON object here>';
IF ISJSON(@Digest, OBJECT) <> 1
    THROW 50000, 'A saved digest JSON object is required.', 1;
DECLARE @Digests nvarchar(max) = N'[' + @Digest + N']';
EXEC sys.sp_verify_database_ledger @digests = @Digests;
```

Expect a successful `last_verified_block_id` result covering the checkpoint. For a negative test, use a separate in-memory copy of the JSON and change one hexadecimal digit of its `hash` field. Run verification with that copy. The original lab received errors 37368 (hash mismatch) and 37392 (verification failed). Do not change database data or the retained checkpoint.

Local file export demonstrates the mechanism, not independent immutable custody. Production requires independently administered, protected storage and periodic verification. Ledger protects recorded events against tampering relative to a trusted checkpoint; it does not establish original event truth or completeness.

## 9. Troubleshooting

| Symptom | Check |
|---|---|
| ODBC driver not found | Driver 18 installation, interpreter architecture, `pyodbc.drivers()` |
| Login or certificate error | SQL instance name, Windows identity, network/TLS configuration; avoid weakening production TLS |
| Procedure not found or wrong parameters | Final deployment version, database context, schema, migration order |
| Governance denied for AR | Enabled application, completed approved review with consistent evidence and attestation hashes |
| All customer requests denied | Exact configured identity, application-specific grants, active customers, expiry |
| SQL caller transaction rejected | `autocommit=True`; procedures own their transactions |
| Model connection error | Ollama running, endpoint, model installed, fault test restored URL |
| Unexpected model output | Model/version, structured output schema and prompt; preserve failed evidence |
| Ledger blocks empty | Inspect `sys.database_ledger_transactions`; generate digest and recheck blocks; investigate any errors |
| Interaction remains PROCESSING | Inspect last event and application error; preserve evidence, do not manually label completed to hide failure |
| Output values differ | Confirm synthetic seed values and test isolation; do not weaken validation to make a test pass |

## 10. Repeatability and publication checklist

A successful re-run requires expected security outcomes, not matching historical identity values, timestamps, model timings or digest hashes. Preserve failed runs and distinguish test/fault scenarios from operational metrics. Never use live customer data merely to make the demo realistic.

Before declaring the repository clone-and-run ready, reconcile final SQL and Python filenames, assemble clean-install migrations and deterministic seed scripts, pin verified dependencies, run the full suite in a fresh database, and record actual environment and results. Do not commit credentials, virtual environments, raw sensitive prompts, local model files or independently retained digests. Add the architecture and production readiness documents to the README navigation.

The nine end-to-end scenarios and original/modified-digest tests succeeded in the incremental development lab. A clean installation from the final repository has not yet been demonstrated. This distinction is intentional.

**Trust nothing. Test everything. Keep the receipts.**
