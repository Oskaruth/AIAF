# AIAF --- AI Interaction Audit Framework

**A provider-neutral reference architecture for securing, validating,
observing, and auditing AI interactions with enterprise data.**

AI applications don't just query data.

They receive prompts, apply system instructions, retrieve context, call
models, invoke tools, make authorization decisions, generate responses,
and increasingly take actions.

Traditional data security can tell us whether an identity was authorized
to access a database.

That is no longer the whole story.

AIAF is an open-source reference implementation exploring a larger
question:

> **When AI touches enterprise data, can we reconstruct what happened
> --- and prove it?**

------------------------------------------------------------------------

## Why AIAF?

Imagine an AI interaction results in a business decision.

Six months later, can you determine:

-   Who initiated the interaction?
-   What did they ask?
-   Which system prompt and prompt version were used?
-   What data did the AI actually receive?
-   Which model and model configuration were used?
-   Which security and validation rules were evaluated?
-   Which policy version authorized or denied the interaction?
-   What tools did the AI call?
-   What actions were requested?
-   Did a human approve those actions?
-   What response was returned?
-   Has the behavior of the system changed since then?

If the answer is:

> "Probably."

...we have some architecture to build.

------------------------------------------------------------------------

## Core Principle

> **When AI touches enterprise data, the interaction itself becomes
> enterprise data.**

AIAF treats an AI interaction as a data pipeline:

``` text
Request
   ↓
Classification
   ↓
Deterministic Validation
   ↓
Semantic Validation
   ↓
Authorization
   ↓
Context Retrieval
   ↓
Model Execution
   ↓
Tool Requests
   ↓
Human Approval (when required)
   ↓
Tool Execution
   ↓
Response Validation
   ↓
Response
   ↓
Outcome / Feedback
```

AIAF captures evidence throughout that pipeline so interactions can be
investigated, analyzed, replayed against changing policies, and
monitored for behavioral drift.

------------------------------------------------------------------------

## What AIAF Is

AIAF is a **reference architecture and working laboratory** for
exploring patterns around:

-   AI interaction auditing
-   Prompt and configuration versioning
-   Data classification
-   Sensitive-data handling
-   Deterministic validation
-   Semantic validation
-   Policy enforcement
-   Policy versioning
-   Historical policy replay
-   Context and RAG lineage
-   Tool authorization
-   Human approval
-   Agent actions
-   Tamper evidence
-   AI observability
-   Behavioral and policy drift

The project is intentionally designed to evolve as these problems are
explored.

------------------------------------------------------------------------

## What AIAF Is Not

AIAF is **not a commercial AI security product**.

Installing this repository does not magically make an AI application
secure.

It does not replace:

-   Identity and access management
-   Database security
-   Network security
-   Encryption
-   Data governance
-   Application security
-   Secure software development
-   Regulatory or legal review
-   Organizational security policies

AIAF explores the architectural controls and evidence that become
necessary **around** those existing capabilities when AI begins
interacting with enterprise data.

------------------------------------------------------------------------

## Reference Implementation

The reference implementation currently uses:

### SQL Server 2025

Stores the AIAF audit, policy, validation, classification, and
interaction data.

### Python

Provides the reference application and orchestration layer.

### Ollama

Runs the models used by the reference implementation locally.

**Ollama is not an AIAF requirement.**

It was deliberately chosen so the project does not depend on Azure, AWS,
Google, or another commercial AI platform.

AIAF is intended to remain provider-neutral.

Bring your own model.

The architectural controls should survive the swap.

------------------------------------------------------------------------

## Sherpa of Data Dataset

The repository includes a synthetic dataset designed specifically for
the AIAF examples.

It contains fictional:

-   Customers
-   Employees
-   Orders
-   Invoices
-   Payments
-   Support interactions
-   Internal notes
-   Sensitive and restricted information

The dataset intentionally contains data with different security
classifications so that we can build --- and break --- realistic AI
security scenarios.

**No real customer or personal data should be used in the AIAF
demonstration environment.**

------------------------------------------------------------------------

## Keep the Receipts

A central design principle of AIAF is that auditability does **not**
mean blindly logging everything.

Prompts, responses, retrieved context, and tool parameters can
themselves contain sensitive information.

AIAF therefore distinguishes between:

### Audit Metadata

Evidence describing what happened without unnecessarily retaining
sensitive content.

### Sanitized Interaction History

Redacted or transformed interaction content suitable for analysis,
troubleshooting, drift detection, and policy replay.

### Restricted Raw Evidence

Original interaction content retained only when organizational policy
explicitly requires it and protected accordingly.

> **Logging is data movement.**

Creating an audit trail should not accidentally create a new
uncontrolled sensitive-data repository.

------------------------------------------------------------------------

## Validation Philosophy

AIAF uses three broad validation layers:

### Deterministic

Use deterministic controls when the decision can be made reliably using
rules, patterns, schemas, allow lists, permissions, or other explicit
logic.

### Semantic

Use semantic validation when understanding meaning or intent is actually
required.

### Human

Require human approval when business risk or judgment warrants it.

The guiding principle is:

> **Use the simplest control that can reliably make the decision.**

More AI does not automatically mean more security.

------------------------------------------------------------------------

## Policy Replay

Security policies change.

An interaction that was legitimately allowed six months ago may not be
permitted today.

AIAF preserves the original policy decision while allowing historical
interactions to be evaluated against newer policies.

This lets us ask:

> **What would today's security policy do with yesterday's AI
> behavior?**

without rewriting history or re-executing the original business action.

This can help identify the impact of policy changes before they are
deployed.

------------------------------------------------------------------------

## Repository Structure

``` text
aiaf/
│
├── docs/            Architecture and article documentation
├── sql/             SQL Server AIAF implementation
├── python/          Python reference application
├── dataset/         Synthetic Sherpa of Data dataset
├── policies/        Example policy definitions
├── tests/           Automated tests and attack scenarios
└── scripts/         Installation and reset utilities
```

The repository is organized around the architecture rather than
individual articles.

Each article builds upon the same implementation.

Git tags/releases preserve the state of AIAF corresponding to individual
articles.

------------------------------------------------------------------------

## Building --- and Breaking --- AIAF

This project intentionally includes security test scenarios.

We will attempt things such as:

-   Submitting restricted information
-   Circumventing simplistic validation
-   Requesting unauthorized data
-   Prompt injection
-   Abusing overly broad database access
-   Calling unauthorized tools
-   Requesting dangerous agent actions
-   Testing changed policies against historical behavior

These scenarios exist to demonstrate defensive architecture in a
controlled environment using synthetic data.

**Do not run these experiments against systems or data you are not
authorized to test.**

------------------------------------------------------------------------

## Project Status

🚧 **AIAF is under active development.**

The architecture is being built incrementally alongside the **AI Has
Your Data. Now What?** article series.

Expect the schema, Python implementation, policies, and documentation to
evolve as additional security and auditing scenarios are introduced.

That evolution is intentional.

------------------------------------------------------------------------

## AI Has Your Data. Now What?

AIAF accompanies the **AI Has Your Data. Now What?** technical article
series.

Current topics include:

1.  **We Spent Decades Securing the Database. Then We Connected an AI to
    It.**
2.  **Your Prompt Is Data**
3.  **Congratulations, You Logged the SSN**
4.  **Should an AI Decide Whether Another AI Is Safe?**
5.  **Your AI Passed Security Review Six Months Ago. So What?**

Upcoming topics will explore context lineage, model reproducibility,
database access, agent tools, human approval, tamper evidence,
observability, and AI drift.

------------------------------------------------------------------------

## Contributing

AIAF is intended to be a practical exploration of AI data architecture.

Issues, discussions, testing scenarios, architecture critiques, and pull
requests are welcome.

If you find a way to break something:

**Excellent.**

Please tell us how.

That's rather the point.

------------------------------------------------------------------------

## License

AIAF is licensed under the MIT License.

See `LICENSE` for details.
