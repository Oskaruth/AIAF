# Getting Started with AIAF

**Status:** Validated clean-install development reference implementation (November 23, 2026).
**Supported deployment entry point:** `tools/Install-AIAF.ps1`
**Scope:** SQL Server 2022 or later; a dedicated development or test database is recommended for the walkthrough. This is **not** a production certification.

AIAF treats an AI interaction as a governed data pipeline. The model requests; the system decides; the architecture keeps the receipts.

For design details, see [Architecture](ARCHITECTURE.md). For testing and evidence checks, see [Testing](TESTING.md). Before handling real data, read [Production Readiness](PRODUCTION_READINESS.md).

## 1. Prerequisites

- SQL Server 2022 or later, with permission to provision and install objects into a dedicated database. SQL Server Developer Edition is for nonproduction use only.
- PowerShell and the Microsoft `SqlServer` PowerShell module, meeting the minimum versions specified by `tools/AIAF.Deployment.psd1`. The canonical installer checks these requirements. Do not use the legacy `SQLPS` module.
- SQL Server Management Studio or another SQL client for database preparation and verification.
- For Python testing: Python 3, Microsoft ODBC Driver 18 for SQL Server, and the repository's Python dependencies (including `pyodbc`).
- For live model integration tests: Ollama with the model configured by the Python application. The reference lab used `qwen3:8b`.
- Git, or a downloaded repository archive.

From the repository root, verify the SQL Server PowerShell module:

```powershell
Get-Module SqlServer -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1 Name, Version
```

If it is missing, install it according to your organization's PowerShell module policy. Do not substitute an older `sqlcmd`-based deployment script for the canonical installer.

## 2. Get the repository and prepare Python

Clone the repository using its GitHub **Code** menu, or download and extract an archive. Run the following commands from the repository root:

```powershell
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install pyodbc
.\.venv\Scripts\python.exe -c "import pyodbc; print(pyodbc.drivers())"
```

Confirm `ODBC Driver 18 for SQL Server` is listed. Install any additional dependencies required by the checked-out Python application before running its tests; use a repository dependency manifest when one is available.

## 3. Create an empty target database

**The installer does not create the database.** Prepare a new, empty database first. The following example is for an isolated lab and does not overwrite an existing database:

```sql
USE master;
GO
IF DB_ID(N'AIAF_Lab') IS NOT NULL
    THROW 50001, 'AIAF_Lab already exists. Choose a new, empty database.', 1;
GO
CREATE DATABASE AIAF_Lab COLLATE Latin1_General_100_CI_AS_SC_UTF8;
GO
ALTER DATABASE AIAF_Lab SET COMPATIBILITY_LEVEL = 160;
ALTER DATABASE AIAF_Lab SET ALLOW_SNAPSHOT_ISOLATION ON;
GO
SELECT name, compatibility_level, collation_name,
       snapshot_isolation_state_desc, is_read_committed_snapshot_on,
       is_trustworthy_on, is_db_chaining_on, is_ledger_on
FROM sys.databases
WHERE name = N'AIAF_Lab';
```

The validated lab used compatibility level 160, snapshot isolation enabled, read-committed snapshot disabled, trustworthy disabled, database chaining disabled, and database-level ledger disabled. AIAF uses an append-only ledger **table**; database-level ledger is not required.

## 4. Choose an installation mode

| Mode | Purpose | Appropriate use |
|---|---|---|
| `Core` | Framework without synthetic demo fixtures | Baseline framework installation |
| `Demo` | Framework plus synthetic demonstration data | Isolated demos and exploration |
| `IntegrationTest` | Full laboratory fixtures and test principals | Dedicated automated/live integration test database only |

`Core` is the default when `-Mode` is omitted. **Never use `IntegrationTest` against a production database.**

The deployment sequence is controlled by `tools/AIAF.Deployment.psd1`. Do not manually execute the historical numbered SQL examples from articles as an installation procedure.

## 5. Preview, then install

From the repository root, run the canonical installer in preview mode:

```powershell
.\tools\Install-AIAF.ps1 `
    -ServerInstance 'localhost' `
    -DatabaseName 'AIAF_Lab' `
    -Mode IntegrationTest `
    -TrustServerCertificate `
    -PlanOnly
```

Replace `localhost` with your SQL Server instance name. `-TrustServerCertificate` is a **local lab convenience**; production connections should validate the SQL Server certificate.

Review the preflight and deployment plan. If preflight fails, correct the reported issue rather than bypassing the check. When ready, execute the installation by omitting `-PlanOnly`:

```powershell
.\tools\Install-AIAF.ps1 `
    -ServerInstance 'localhost' `
    -DatabaseName 'AIAF_Lab' `
    -Mode IntegrationTest `
    -TrustServerCertificate
```

For a framework-only installation, use `-Mode Core` instead. For a synthetic demonstration installation, use `-Mode Demo`.

Other supported installer options include `-QueryTimeout` and `-LogDirectory`. Use `Get-Help .\tools\Install-AIAF.ps1` or inspect the script's parameter declaration for the exact interface in your checkout.

**Fresh-install only:** the installer refuses to deploy over an existing AIAF installation. It does not automatically remove objects after a partial failure. Preserve logs and investigate failures; use a newly provisioned empty database for a clean retry. There is no supported in-place upgrade or automatic rollback path documented here.

## 6. Validate the installation

The installer performs deployment checks, including preflight and security validation. Inspect its results and logs; do not equate a script exit with production readiness.

You can independently inspect important installed objects:

```sql
USE AIAF_Lab;
GO
SELECT s.name AS SchemaName, t.name AS TableName, t.ledger_type_desc
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'aiaf' AND t.name = N'AIInteractionEvent';

SELECT name, type_desc
FROM sys.database_principals
WHERE name IN (N'AIAF_Runtime', N'AIAF_TestRuntime');
```

In the `IntegrationTest` lab, the event table should report `APPEND_ONLY_LEDGER_TABLE`. Object existence alone does not prove effective permissions; rely on the installer's security checks and the testing procedures in [Testing](TESTING.md).

On November 23, 2026, the clean `IntegrationTest` deployment was validated on SQL Server 2022: 76/76 deployment scripts, 9/9 security checks, and 54/54 effective permission checks passed. These are results from a specific validated lab run, not universal guarantees.

## 7. Configure the Python integration environment

The Python integration suite requires the `IntegrationTest` mode and its synthetic fixtures. Configure your environment to match the database you installed:

```powershell
$env:PYTHONPATH = (Resolve-Path .\python).Path
$env:AIAF_DB_SERVER = 'localhost'
$env:AIAF_DB_NAME = 'AIAF_Lab'
$env:AIAF_DB_DRIVER = 'ODBC Driver 18 for SQL Server'
$env:AIAF_DB_TRUST_CERTIFICATE = 'yes'  # local lab only
$env:AIAF_MODEL_NAME = 'qwen3:8b'
$env:AIAF_OLLAMA_URL = 'http://localhost:11434/api/generate'
$env:AIAF_MODEL_TIMEOUT_SECONDS = '120'
```

Check Ollama and the model:

```powershell
ollama --version
ollama pull qwen3:8b
ollama list
Test-NetConnection -ComputerName 127.0.0.1 -Port 11434 -InformationLevel Quiet
```

Keep the inference endpoint local and do not expose it unauthenticated. The test suite includes a deliberately simulated model outage; see [Testing](TESTING.md) for its endpoint requirements.

## 8. Run the integration tests and independent verification

From the repository root, run the consolidated Python integration suite using the prepared environment:

```powershell
.\.venv\Scripts\python.exe -m tests.integration.run_integration_tests
$LASTEXITCODE
```

The validated suite contains **17 scenarios** covering authorized and unauthorized access, input and output validation, governance suspension, model failures, malformed model responses, unsupported tool requests, and prompt-injection cases. A scenario that ends `BLOCKED` or `FAILED` can be a **passing test** when that is the expected safe outcome.

Next, open `tests/integration/verify_integration_results.sql` in SSMS, connect to the **same database**, and execute the full script under an authorized verification identity.

By default, `@RunId = NULL` tells the verifier to **automatically select the latest identifiable integration run**. To verify a specific run instead, set `@RunId` to the GUID printed by the Python suite. The verifier checks persisted evidence independently of the Python test assertions and raises an error on verification failure. Do not choose an older passing run to conceal a newer incomplete or failed run.

The validated November 23, 2026 run passed **17/17 Python scenarios and 17/17 independent SQL scenario checks**, with **zero assertion failures**, **108 ledger events**, and **zero persisted validation content records**. See [Testing](TESTING.md) for the scenario matrix, expected evidence counts, and verification limitations.

## 9. Optional: database ledger digest verification

The independent integration verifier checks ledger **event evidence and sequences**. That is **not** the same as cryptographic ledger integrity verification against an independently retained digest.

For a separate, privileged lab exercise:

```sql
USE AIAF_Lab;
GO
EXEC sys.sp_generate_database_ledger_digest;
SELECT block_id, block_size, transactions_root_hash, previous_block_hash
FROM sys.database_ledger_blocks
ORDER BY block_id;
```

Retain the generated digest outside the database and repository in a protected location. For cryptographic verification, supply a previously saved, trusted digest to `sys.sp_verify_database_ledger`. Do not generate a fresh digest and treat it as independent evidence of historical integrity. For production, digest custody and periodic verification require independent operational controls.

## 10. Troubleshooting and safety

| Symptom | What to check |
|---|---|
| Installer preflight fails | Empty target database, required settings, module versions, permissions, and manifest inventory |
| Installer rejects the target | Existing AIAF objects or principals; use a fresh database rather than forcing a reinstall |
| Installation stops partway through | Installer logs and failed phase; no automatic rollback or safe rerun is assumed |
| SQL connection or TLS error | Instance name, authentication, network access, and certificate configuration |
| Python cannot connect | ODBC Driver 18, environment variables, database permissions, and test runtime identity |
| Model unavailable unexpectedly | Ollama process, model name, configured URL, and port |
| Python scenarios fail | Inspect scenario output and persisted evidence; do not weaken assertions just to get a pass |
| SQL verifier fails | Inspect assertion-level failures and selected RunId; preserve failed evidence |
| Interaction remains processing | Preserve evidence and investigate; abandoned/stuck interaction recovery remains a production-hardening item |

**Security and operational limits:** AIAF is a validated development reference implementation, not a certified production security system. The tests do not establish comprehensive prompt-injection protection, complete sensitive-data prevention, exactly-once processing, crash recovery, end-user delivery confirmation, or independently trusted ledger integrity. Read [Production Readiness](PRODUCTION_READINESS.md) before considering a production adaptation.

**Trust nothing. Test everything. Keep the receipts.**
