# AIAF Architecture

AIAF treats an AI interaction as a data pipeline rather than a simple prompt-and-response exchange.

At the point covered by the first three published articles, the architecture is focused on capturing enough evidence to answer:

- Who initiated the interaction?
- Which prompt definition and version applied?
- When did the interaction occur?
- What classification of information was detected?
- What sanitized evidence can safely be retained?
- Was the request completed, denied, or failed?

AIAF intentionally separates **what happened** from **every byte that passed through the system**.

That distinction matters because prompts, responses, retrieved context, and tool parameters can themselves contain sensitive information.

> Auditability does not require blindly retaining everything.

## Architecture and Documentation

- [Reference Architecture](docs/ARCHITECTURE.md) — Architectural principles, components, trust boundaries, runtime enforcement, and demonstrated capabilities.
- [Production Readiness Considerations](docs/PRODUCTION_READINESS.md) — Deployment requirements, known limitations, security considerations, and production acceptance criteria.

AIAF is a reference architecture and validated development proof of concept, not a turnkey production security product.
