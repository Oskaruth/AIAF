# AIAF — AI Interaction Audit Framework

**A reference implementation for governing, validating, and auditing AI interactions with enterprise data.**

AI applications do more than generate text. They interpret requests, consult models, propose tool calls, retrieve business data, and return results. A database permission check alone cannot explain every decision along that path.

AIAF explores a practical question:

> **When AI interacts with enterprise data, can we reconstruct what happened, what was allowed, what was blocked, and why?**

The framework treats an AI interaction as an auditable data pipeline, with explicit governance, authorization, validation, and lifecycle evidence.

**Project status:** Validated development reference implementation. **Not production-certified or a turnkey security product.** See [Production Readiness](docs/PRODUCTION_READINESS.md) for outstanding work and limitations.

## What AIAF demonstrates

- **Governance before execution:** Check application approval and suspension status before permitting model-driven work.
- **Controlled tool use:** Treat model-generated tool requests as proposals; enforce authorization in application and database controls rather than trusting the model.
- **Input and output validation:** Inspect and sanitize selected inputs; validate retrieved results before release.
- **Interaction lifecycle tracking:** Record whether requests completed, were blocked, or failed, with supporting evidence.
- **Auditable events:** Persist structured evidence, including append-only SQL Server ledger events, without treating unrestricted raw prompt retention as a prerequisite for auditability.
- **Independent verification:** Compare recorded SQL Server evidence against expected integration-test outcomes, separately from the Python test runner.

AIAF's initial example is a **synthetic, read-only accounts-receivable workflow**. It is deliberately narrow so the security and evidence boundaries can be inspected and tested.

## Quick start

**Requirements include:** SQL Server 2022 or later, PowerShell with the `SqlServer` module, Python, Microsoft ODBC Driver 18 for SQL Server, and Ollama for live model-based integration tests. See the [full prerequisites](docs/GETTING_STARTED.md#1-prerequisites) for the supported lab setup.

1. Clone the repository and open PowerShell at the repository root.
2. Create a **new, empty** SQL Server database using the settings in [Getting Started](docs/GETTING_STARTED.md).
3. Preview the deployment:

   ```powershell
   .\tools\Install-AIAF.ps1 `
       -ServerInstance 'localhost' `
       -DatabaseName 'AIAF_Lab' `
       -Mode IntegrationTest `
       -PlanOnly
   ```

4. If the plan and preflight checks pass, install by running the same command **without** `-PlanOnly`:

   ```powershell
   .\tools\Install-AIAF.ps1 `
       -ServerInstance 'localhost' `
       -DatabaseName 'AIAF_Lab' `
       -Mode IntegrationTest
   ```

   Adjust the instance and database names for your environment. For local laboratory SQL Server certificates, the installer also supports `-TrustServerCertificate`; use properly validated certificates outside the lab.

5. Configure Python and Ollama, then follow [Testing and Verification](docs/TESTING.md) to run the integration suite and independent SQL verifier.

**Use only [`tools/Install-AIAF.ps1`](tools/Install-AIAF.ps1) as the installation entry point.** Deployment script selection and ordering are controlled by [`tools/AIAF.Deployment.psd1`](tools/AIAF.Deployment.psd1). Do not run historical article SQL scripts as an installation sequence.

### Installation modes

| Mode | Purpose |
|---|---|
| `Core` | Framework deployment without synthetic demonstration data |
| `Demo` | Framework plus synthetic demonstration data |
| `IntegrationTest` | Dedicated laboratory deployment with integration-test fixtures and principals |

`Core` is the default installer mode. `IntegrationTest` is **not** appropriate for a production database. The installer targets a pre-created, empty database; it is not an in-place upgrade tool and does not automatically roll back a partially failed installation.

## Tested behavior

On **November 23, 2026**, a clean `IntegrationTest` installation was exercised on SQL Server 2022 compatibility level 160:

| Validation | Observed result |
|---|---:|
| Installer preflight | 20/20 passed |
| Deployment scripts | 76/76 completed |
| Installer security checks | 9/9 passed |
| Effective permission checks | 54/54 passed |
| Python integration scenarios | 17/17 passed |
| Independent SQL scenario verification | 17/17 passed |
| Independent SQL verification failures | 0 |
| Recorded ledger events for the verified run | 108 |
| Persisted validation content records for the verified run | 0 |

The independent SQL verifier can automatically select the latest discoverable integration run; an explicit RunId can also be supplied. See [Testing and Verification](docs/TESTING.md) for commands, scenario coverage, and the limits of what these results establish.

These are **development validation results**, not claims of comprehensive prompt-injection protection, production resilience, or independently verified ledger digest custody.

## Documentation

| Start here | What you'll find |
|---|---|
| [Getting Started](docs/GETTING_STARTED.md) | Prerequisites, database preparation, canonical installer, deployment modes, and first run |
| [Testing and Verification](docs/TESTING.md) | Unit and integration testing, security checks, SQL evidence verification, and troubleshooting |
| [Architecture](docs/ARCHITECTURE.md) | Components, trust boundaries, data flow, and architectural decisions |
| [Production Readiness](docs/PRODUCTION_READINESS.md) | Known limitations, hardening backlog, and production acceptance considerations |
| [Architecture Notes](docs/architecture/README.md) | Supporting technical design material as it is added |
| [Article Series](docs/articles/README.md) | Educational walkthroughs and the history of how AIAF evolved |

## Learn through the articles

The **“AI Has Your Data. Now What?”** series on [Sherpa of Data](https://sherpaofdata.com/) explores the decisions and experiments behind AIAF. The [`docs/articles/`](docs/articles/) directory is intended to hold Markdown editions of the published articles, organized in reading order and linked to their originals.

The articles are **educational snapshots**. Their SQL examples may reflect earlier iterations and should not replace the canonical installer or current reference documentation.

## Security and operational boundaries

AIAF is a reference architecture, not a substitute for application authentication, enterprise authorization, data classification, secure operations, or independent security review. Its synthetic fixtures, test identities, and fault-injection paths belong in isolated environments. The current framework also has production-hardening work remaining, including recovery of abandoned or stuck interactions.

The design intentionally distinguishes **recording evidence** from **retaining every raw prompt, result, or tool payload**. Auditability should not create an uncontrolled second store of sensitive data.

## Contributing and feedback

Issues, tests, architecture critiques, and pull requests are welcome. Especially useful contributions include reproducible failure cases, additional negative security tests, documentation corrections, and proposals that preserve the separation between model requests and enforced authorization.

If you find a way to break something, document the conditions and expected behavior. That's how the framework gets better.

## License

Released under the [MIT License](LICENSE).

---

**The model requests. The system decides. The architecture keeps the receipts.**
