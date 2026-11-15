# AI Interaction Audit Framework (AIAF)
## Reference architecture

**Status:** Validated development proof of concept | **Reference implementation:** SQL Server 2022, Python, Ollama | **Validation date:** 2026-11-15

> The AI provides intelligence. The architecture provides control.

## 1. Purpose and scope

AIAF demonstrates how an enterprise can constrain, observe and audit AI-mediated access to data. It is a provider-neutral architectural pattern with a concrete local implementation, not a production security product or compliance certification. The Acme Manufacturing accounts-receivable scenario uses synthetic customer and invoice data. The implemented workflow is read-only; approval-controlled financial writes are a design topic, not an implemented capability of this pipeline.

The central principle is that the model requests a capability; deterministic controls decide whether it may be exercised. An AI interaction is enterprise data in its own right, but recording that interaction must not create a second unrestricted copy of the business data.

## 2. Architectural principles

- Deny by default; enforce application governance before invoking the model.
- Separate application approval, requesting identity, tool selection, data authorization and response release.
- Expose narrowly scoped tools instead of arbitrary SQL or database credentials to the model.
- Validate untrusted inputs and outputs using deterministic rules.
- Record decisions, identifiers, rule versions and operating telemetry rather than raw sensitive payloads.
- Distinguish blocked requests, operational failures and successful release approval.
- Protect audit evidence with cryptographic checkpoints stored outside the database.
- Treat missing telemetry as unknown, never as zero.

## 3. Runtime architecture

```mermaid
flowchart TD
    U[Request and configured identity] --> B[Register interaction]
    B --> G{Governance gate}
    G -->|Denied| X[Blocked]
    G -->|Allowed| I[Input sanitization and validation evidence]
    I --> M[Ollama model: structured tool selection]
    M --> V{Model response valid?}
    V -->|No| F[Failed]
    V -->|Yes| P[Persist tool proposal]
    P -->|No supported tool| X
    P -->|GetCustomerBalance| A{Deterministic authorization}
    A -->|Denied| X
    A -->|Allowed| T[Controlled SQL procedure returns data]
    T --> O{Output validation}
    O -->|Blocked| X
    O -->|Passed| C[Finalize: completed / approved for release]
    C --> R[Deterministic response formatting]
    B -. evidence .-> L[(Append-only event ledger)]
    G -. evidence .-> L
    I -. evidence .-> L
    M -. evidence .-> L
    P -. evidence .-> L
    A -. evidence .-> L
    O -. evidence .-> L
    C -. evidence .-> L
    X -. evidence .-> L
    F -. evidence .-> L
    L --> D[Export database ledger digest]
    D --> E[External checkpoint storage]
```

The diagram depicts intended logical flow, not an exhaustive exception-handling state machine. Unexpected application or database failures can leave interactions in PROCESSING. Financial data is returned to the trusted Python process for validation and formatting; it is not sent back to the model. The model receives sanitized input and a synthetic customer directory for tool selection.

## 4. Components and responsibilities

| Component | Responsibility |
|---|---|
| `pipeline.py` | Orchestrate gates, evidence persistence, execution and release |
| `database.py` | SQL connection; development Windows authentication |
| `input_validation.py` | Pattern-based detection and sanitization of SSNs, card-like numbers and email addresses |
| `model_client.py` | Ollama structured tool selection, response contract validation and execution telemetry |
| `tool_dispatcher.py` | Persist proposals and dispatch allowlisted tools |
| `output_validation.py` | Validate tool result and persist rule outcomes |
| `interaction_lifecycle.py` | Request SQL-derived terminal decision |
| `response_formatter.py` | Render approved results or generic rejection messages without another model call |
| `fault_injection.py` | Development-only output corruption test harness |
| SQL Server | Governance, entitlement checks, controlled data access, lifecycle evidence and ledger |

### Data domains

| Schema / object | Purpose |
|---|---|
| `acme.Customer`, `acme.Invoice` | Synthetic operational data |
| `aiaf.AIApplication` | Registered application, owner, purpose, risk and enabled status |
| `aiaf.AICustomerAccess` | Application- and identity-specific customer entitlements, expiry and enabled status |
| `aiaf.AIInteraction` | Root interaction, correlation identifier, purpose and lifecycle |
| `aiaf.AIModelExecution` | Provider, model, prompt version, timing, usage, cost and execution outcome |
| `aiaf.AIModelToolRequest` | Structured proposal linked to a model execution |
| `aiaf.AIToolCall` | Authorization and execution outcome linked to the proposal |
| `aiaf.AIValidation` | Versioned input/output rule outcomes; output linked to tool call |
| `aiaf.AIInteractionEvent` | Append-only ledger evidence |
| `aiaf.AIAuditHeartbeat`, `aiaf.AIDriftRule` | Earlier-series monitoring and drift demonstration |
| `aiaf_governance.AIReview`, `AIReviewItem`, `AIReviewAction`, `AIReviewAttestation` | Periodic review, findings, remediation and attestation |
| `aiaf.vw_AIModelOperatingCost` | Aggregated live model telemetry by operating dimensions |

```mermaid
erDiagram
    AIApplication ||--o{ AIInteraction : registers
    AIApplication ||--o{ AICustomerAccess : scopes
    Customer ||--o{ AICustomerAccess : grants
    Customer ||--o{ Invoice : owns
    AIInteraction ||--o{ AIModelExecution : records
    AIModelExecution ||--o| AIModelToolRequest : proposes
    AIModelToolRequest o|--o| AIToolCall : links
    AIInteraction ||--o{ AIToolCall : records
    AIInteraction ||--o{ AIValidation : evaluates
    AIToolCall o|--o{ AIValidation : output_checks
    AIInteraction ||--o{ AIInteractionEvent : evidences
    AIReview ||--o{ AIReviewItem : contains
    AIReviewItem ||--o{ AIReviewAction : remediates
    AIReview ||--o{ AIReviewAttestation : attests
```

Logical relationship view; legacy interactions and tool calls can lack newer linkage fields. Governance associates reviews to applications by application code; do not infer a physical foreign key from that association.

## 5. Governance and authorization

The review workflow freezes an ordered evidence package, hashes it using SHA-256 and binds attestations to that hash. Review completion is not equivalent to approval. The runtime gate evaluates application registration, enabled state, latest completed attestation and evidence hash consistency. Only APPROVED is admitted; SUSPENDED, REJECTED, RESTRICTED, CONDITIONALLY_APPROVED, missing or invalid attestations fail closed in this implementation.

`aiaf.usp_BeginInteraction` registers the interaction and records governance evidence. `aiaf_tool.GetCustomerBalance` reevaluates governance and checks current customer entitlement, including active customer, enabled grant, read permission and expiry. The procedure consumes the persisted proposal identifier, not a new customer argument supplied at dispatch time. A denied or nonexistent customer produces a generic access denial rather than a balance or existence disclosure.

The runtime database role is restricted to approved procedure execution and denied direct access to protected schemas. Governance roles separate review freezing and attestation. Development tests use database impersonation; authentication of application and end-user identity is not implemented. SQL ownership chaining supports controlled access without granting direct table reads.

## 6. Validation and model contract

Input rules version 1 detect SSN, payment-card-like and email patterns. Matches are replaced in memory; only findings are persisted. This is limited regex-based sanitization, not comprehensive DLP. The model must return exactly `ToolCode` and `CustomerCode`, with either `GetCustomerBalance` and a valid customer code or `NO_SUPPORTED_TOOL` and an empty code. Invalid model output is rejected. A valid proposal conveys no authorization.

Output validation evaluates five rules: `OUTPUT_AUTHORIZATION`, `OUTPUT_ROW_COUNT`, `OUTPUT_SCHEMA`, `OUTPUT_FINANCIAL_INTEGRITY`, `OUTPUT_CUSTOMER_BINDING`. These verify successful authorized execution and linkage, one result row, exact expected columns, numeric/count consistency and binding to the proposed customer. Expected fields are CustomerCode, CustomerName, OutstandingBalance, DisputedBalance, OpenInvoiceCount and DisputedInvoiceCount. These checks do not independently establish financial accuracy or eliminate every disclosure channel.

The SQL validation procedures enforce rule-set and metadata consistency but trust the runtime's reported observations. Only a persisted passing output assessment and SQL-derived completion decision permit normal release. The formatter uses USD presentation as a lab convention.

## 7. Lifecycle and evidence

```mermaid
stateDiagram-v2
    [*] --> RECEIVED: Governance allows
    [*] --> BLOCKED: Governance denies
    RECEIVED --> PROCESSING: Input validation recorded
    PROCESSING --> COMPLETED: Output approved
    PROCESSING --> BLOCKED: Unsupported / denied / unsafe output
    PROCESSING --> FAILED: Recorded model or tool failure
    COMPLETED --> [*]
    BLOCKED --> [*]
    FAILED --> [*]
```

LEGACY and AWAITING_APPROVAL also exist in the schema but are not active states in this read-only path. `aiaf.usp_CompleteInteraction` derives outcomes from persisted evidence rather than accepting a caller-supplied success flag. COMPLETED means authorized for release, not confirmed delivery. An interruption before finalization may leave an orphaned nonterminal interaction. The implementation does not guarantee exactly-once delivery.

Evidence chain: interaction → model execution → proposal → tool call → output validation → finalization. Correlation and relational identifiers allow reconstruction of decisions. Principal identity, application/workflow, customer code, timing and authorization details remain sensitive metadata. Neither raw/sanitized prompt text nor financial result values are persisted by the normal audit path. Diagnostic and infrastructure logging must also be controlled.

## 8. Operating telemetry

Capture provider/model, prompt version, timestamps, client and server timings, load duration, token counts, execution status, error code, environment and telemetry source. Cost fields support reported or estimated cost with basis and reference; local Ollama usage does not supply billing costs, so cost is NULL. LIVE denotes live provider invocation or attempt, not production traffic. SYNTHETIC and REPLAY distinguish other observations. The operating-cost view filters LIVE but does not by itself exclude deliberate faults or identify every test scenario. Coverage and cost basis must accompany monetary totals; unknown cost is not free usage.

## 9. Cryptographic audit evidence

`aiaf.AIInteractionEvent` is an append-only ledger table. SQL Server computes transaction and block hashes. Export `sys.sp_generate_database_ledger_digest` output to external storage and verify against the previously captured checkpoint using `sys.sp_verify_database_ledger @digests` (JSON array). A new digest generated immediately before verification is not a substitute for a trusted historical anchor.

The lab verified block 0 and showed that a deliberately altered supplied hash is rejected (errors 37368 and 37392). This is a digest mismatch test, not an actual database tampering experiment. Only ledger-protected events receive this protection; ordinary framework tables do not. Ledger integrity does not prove event truth, completeness or confidentiality. External local file storage is not an independently protected immutable trust boundary.

## 10. Demonstrated results

Final inventory from the development database on 2026-11-15 (includes earlier-series fixtures and intermediate tests):

| Metric | Count |
|---|---:|
| Interactions | 1,105 |
| Applications | 2 |
| Model executions | 28 |
| Model tool requests | 20 |
| Tool calls | 1,269 |
| Validations | 133 |
| Output validations (subset) | 55 |
| Finalization events | 15 |
| Ledger events | 201 |
| Ledger transactions | 168 |
| Ledger blocks | 1 |

Final end-to-end scenarios:

| Interaction | Scenario | Observed outcome |
|---:|---|---|
| 1097 | Authorized Northwind request | COMPLETED |
| 1098 | Unauthorized Fabrikam request | BLOCKED |
| 1099 | Sensitive SSN input; authorized request | COMPLETED after sanitization |
| 1100 | Prompt injection / unsupported tool | BLOCKED |
| 1101 | Unexpected output column | BLOCKED |
| 1102 | Incorrect customer binding | BLOCKED |
| 1103 | Invalid financial balance | BLOCKED |
| 1104 | Model unavailable | FAILED; MODEL_CONNECTION_ERROR |
| 1105 | Suspended application | BLOCKED before model invocation |

Nine scenarios matched expected outcomes; no unauthorized financial response was observed in these tests. This is not a statistical security guarantee. Earlier manual validation (1085), retrospective finalization (1089–1095), deliberate faults (1093–1095, 1101–1103), and abandoned interaction 1096 must be distinguished from normal operations. Historical fixtures should not be used as production performance or security metrics.

## 11. Related documentation

See [Production readiness considerations](PRODUCTION_READINESS.md) for deployment gaps and acceptance criteria. This document reflects the observed lab and established design, not a fresh repository source-code audit.

> Trust nothing. Test everything. Keep the receipts.
