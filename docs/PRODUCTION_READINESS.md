# AIAF — Production readiness considerations

**Status:** Development reference implementation; not approved for production deployment.  
**Assessment basis:** Demonstrated SQL Server 2022 / Python / Ollama lab as of 2026-11-15.  
**Companion:** [Reference architecture](ARCHITECTURE.md).

## 1. Decision and scope

The lab demonstrates a controlled read-only customer-balance workflow, runtime governance, model/tool separation, validation, audit evidence and ledger verification. It does not establish production security, compliance, availability or operational supportability. The following is a recommended deployment backlog; priorities are proposed, not an organizational risk acceptance decision.

**P0:** Required before production access to sensitive enterprise data. **P1:** Required for supported ongoing operation; complete before broad rollout or explicitly accept residual risk. **P2:** Conditional enhancement, required if the relevant capability is introduced.

## 2. Readiness register

| ID | Priority | Lab limitation / risk | Recommended control | Suggested owner |
|---|---|---|---|---|
| PR-01 | P0 | Application and user identity asserted by harness; shared runtime can misattribute requests | Bind application and user claims to verified identity; prevent cross-interaction impersonation; use separate service principals | IAM / application engineering |
| PR-02 | P0 | Runtime trusts caller-reported validation, model results and telemetry | Isolate trusted validator/executor; authenticate service boundaries; bind evidence to request and tool result; reconcile independent receipts | Security architecture |
| PR-03 | P0 | Governance gate lacks expiry, pending-review policy and continuous revocation enforcement | Define approval validity, condition evaluation, fail-closed policy and release-time revocation behavior | Governance / security |
| PR-04 | P0 | Customer access is evaluated at tool execution; revocation may race with release | Define authorization linearization point, recheck where required, test concurrent revocation, tenant and field-level scope | Data security |
| PR-05 | P0 | Regex sanitization covers only limited patterns; synthetic directory is supplied to model | Classify data, minimize context, authorize retrieval, deploy tested DLP and provider boundary controls | Privacy / data governance |
| PR-06 | P0 | Output rules validate shape and consistency, not all sensitive content or source truth; raw results enter Python memory | Treat runtime as sensitive boundary; minimize tool projection, validate semantics, restrict egress, test free-text leakage | Application / data owner |
| PR-07 | P0 | Digest export is local, not independently protected; other tables are mutable | Independent immutable checkpoint storage, separate admin roles, periodic verification and reconciliation of nonledger records | Security operations / DBA |
| PR-08 | P0 | Development impersonation, broad trusted login and TrustServerCertificate=yes | Dedicated least-privilege identities; validated TLS; secret management; procedure permission review and hardened hosts | Platform / DBA |
| PR-09 | P0 | Unhandled exceptions and interrupted steps can leave nonterminal interactions; evidence persistence can fail | Durable lifecycle recovery, bounded retries, timeout and cancellation policy, fail closed on evidence failure | Application / SRE |
| PR-10 | P0 | Fault injection and diagnostic output present in development code | Separate test entry points and deployable package; prohibit fault controls in production; sanitize logs | DevSecOps |
| PR-11 | P1 | No delivery receipt or exactly-once guarantee | Define release versus delivery; idempotency, durable delivery receipts if needed, retry and disconnect behavior | Application / SRE |
| PR-12 | P1 | Model version not pinned in recorded live metadata; prompt version integer only | Artifact digest, model/config inventory, versioned prompts and policies, controlled deployment and reproducibility evidence | MLOps |
| PR-13 | P1 | Absent billing and partial usage telemetry | Provider reconciliation, cost basis/version, coverage measures, budget alerts and missing-data reporting | FinOps |
| PR-14 | P1 | Earlier heartbeat/drift demonstrations are not wired into an independently supervised production monitor | External health checks, expected demand, stale-interaction detection, alert routing, drift baselines and incident response | SRE / security operations |
| PR-15 | P1 | Synthetic, replay, manual and fault-injection evidence can contaminate operating metrics | Separate environments; explicit scenario and evidence provenance; reporting exclusions; preserve historical evidence | Data engineering |
| PR-16 | P0 | No defined retention schedule or deletion policy; ledger cannot be treated as ordinary mutable storage | Minimize persisted fields, classify metadata, set retention and legal hold rules, validate backup and disposal strategy | Privacy / legal / DBA |
| PR-17 | P1 | No validated HA, restore, capacity or disaster-recovery objectives | Load and concurrency tests; restore and ledger verification drills; RPO/RTO, patching and availability design | Platform / DBA |
| PR-18 | P1 | Some rejected procedure calls throw without independent rejection evidence | Record security failures through protected monitoring; reconcile attempted and persisted operations | Security operations |
| PR-19 | P2 | Financial writes not implemented | Separate action entitlement, human approval bound to canonical payload hash, expiry, concurrency, idempotency and uncertain-outcome reconciliation | Business owner / security |
| PR-20 | P1 | No complete software supply-chain or deployment assessment | Pin dependencies, scan packages/images, review code and migrations, manage SBOM and rollback | DevSecOps |

## 3. Trust boundaries and threat model

| Boundary | Example threat | Required assurance |
|---|---|---|
| User → gateway | Impersonation, injection, unauthorized application selection | Verified claims, rate limits, untrusted input handling |
| Gateway → model | Sensitive prompt leakage, provider retention, malicious output | Data minimization, approved provider terms/config, schema validation |
| Model → tool dispatcher | Invented tool, altered argument, replay | Allowlist, persisted proposal binding, one-time execution and independent authorization |
| Runtime → database | Privilege escalation, forged evidence, cross-tenant access | Least privilege, authenticated service identity, controlled procedures and independent audit |
| Tool result → release | Wrong customer, excess columns, sensitive free text, revocation | Output validation, release-time policy, secure memory and egress controls |
| Database → evidence storage | Privileged tampering, omitted events, compromised digest | Independent checkpoint custody, verification, completeness reconciliation and access monitoring |
| Operations → production | Debug output, test flags, unsafe upgrades | Environment isolation, controlled deployment and change approval |

The LLM is not trusted to determine authority. The Python runtime, database procedures, identity service and evidence custody are security-critical components. A compromised trusted component can fabricate plausible audit events; append-only storage does not resolve this on its own.

## 4. Recommended production design requirements

### Identity and authorization

Use verified end-user and workload identities; derive application context from trusted configuration. Prevent a runtime from supplying arbitrary identities or manipulating another interaction. Enforce least privilege at tool and data scopes. Define entitlement expiry, revocation, segregation of duties, emergency suspend and access review procedures. For conditional approvals, represent machine-enforceable predicates and deny when evaluation is unavailable.

### Data protection and evidence

Maintain a data inventory covering prompts, context, provider traffic, results, identifiers, errors, telemetry, backups and logs. Audit metadata can itself reveal identity, customer relationships and activity. Use encryption, access restrictions and retention policy. Do not persist raw prompts or financial responses by default. Avoid using unkeyed hashes of predictable sensitive values as a privacy mechanism. If restricted raw evidence is required, design a separate approved evidence store and access workflow rather than expanding the general audit table.

Store digests outside the database in independently administered immutable storage. Schedule generation and verification; alert on failure or stale checkpoints; test verification after restore. Reconcile ledger event counts and business/control decisions against independently collected request and execution evidence. Decide which additional records require ledger protection or equivalent integrity guarantees. Successful verification proves consistency against a trusted checkpoint, not correctness of events or current authorization.

### Reliability and response semantics

Define explicit failure paths for input validation errors, unavailable database, tool exceptions, model timeout, missing evidence, formatting error and delivery interruption. A request must never release protected content when authorization or required evidence is unavailable. Define an orphan reconciliation process; do not retrospectively mark an interaction successful without supporting evidence. Keep COMPLETED (release approved) separate from delivery confirmation. For future writes, distinguish UNKNOWN from FAILED and never blindly retry uncertain side effects.

### Monitoring and cost

Monitor terminal outcomes, reasons, stale PROCESSING interactions, latency percentiles, provider failures, rule detections, denied-tool bursts, drift and evidence gaps. A blocked request is not automatically an outage. Validate monitoring independently of the system being monitored. Track token and monetary coverage separately; reconcile provider billing and distinguish reported costs from estimates. Exclude lab/test activity from production reporting and avoid documenting elapsed retrospective test intervals as actual processing latency.

## 5. Production acceptance tests

These are proposed acceptance criteria, not tests claimed to have been executed by the lab.

| Test | Passing condition |
|---|---|
| Identity spoofing / cross-interaction replay | Unauthenticated or misbound request rejected; evidence correlated |
| Disabled, expired or revoked approval | No unauthorized tool execution or release; policy timing documented |
| Entitlement revocation race | Behavior matches defined authorization boundary, with no prohibited release |
| Malicious model proposal | Unknown tool, invalid arguments and mismatched proposal rejected |
| Sensitive context and output | Adversarial corpus tested across free text, structured data, logs and provider traffic |
| Evidence forgery / dropped event | Independent reconciliation detects mismatch; required evidence failure prevents release |
| Database or provider outage | Bounded failure, generic user response, recoverable or reconciled interaction |
| Crash between every pipeline stage | No unsafe release; deterministic recovery or explicit unresolved status |
| Delivery interruption | Acknowledgment status accurate; no false confirmed delivery |
| Digest mismatch and restore | Trusted digest verifies restored valid ledger; invalid checkpoint rejected and alerted |
| Privilege and configuration review | No direct unauthorized data access, no production test hooks, validated TLS |
| Capacity and recovery | Agreed workload SLOs, RPO/RTO and restore tests meet business requirements |
| Cost and reporting | Known/unknown coverage accurate; test activity excluded; billing reconciled |
| Financial writes (only if enabled) | Approved payload binding, segregation, expiry and uncertain-outcome recovery tested |

## 6. Rollout and sign-off

1. Isolated development with synthetic data; preserve repeatable positive and negative tests.
2. Security/design review and threat model; resolve P0 risks and define measurable service objectives.
3. Controlled nonproduction integration with representative classified data only after authorization and privacy approval.
4. Limited production pilot after P0 gates pass; documented owners, monitoring, rollback and incident response in place.
5. Expand only after acceptance criteria and operational evidence meet agreed requirements; schedule periodic and change-triggered reviews.

Suggested sign-off participants: accountable business owner, data owner, security/IAM, privacy/legal as applicable, platform/DBA, application owner, operations and FinOps. Record evidence references, finding owners, deadlines and explicit residual-risk decisions. No sign-off is implied by completion of this document.

## 7. Lab evidence caveats

The nine final scenarios matched their expected outcomes; original digest verification returned block 0 and an altered digest was rejected. This does not establish coverage against arbitrary attacks. Earlier interactions include synthetic/replay telemetry, manual evidence, retrospective completion and deliberate faults. Interaction 1096 illustrates an abandoned PROCESSING request after a pipeline error. Preserve such records; annotate or classify them rather than silently rewriting history. The lab has not demonstrated independent authenticated receipts, immutable external storage, full DLP, concurrent revocation, production-scale operation or recovery. Repository source was not independently inspected for this assessment.

> Security isn't what you've designed. It's what you've actually deployed and verified.
