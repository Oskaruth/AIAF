# AIAF — Article Series

The **“AI Has Your Data. Now What?”** series on [Sherpa of Data](https://sherpaofdata.com/) explains the ideas, experiments, failures, and design decisions behind the **AI Interaction Audit Framework (AIAF)**.

This directory is intended to contain **Markdown copies of the published articles**, in publication order, so readers can follow the framework's evolution without leaving GitHub. The original articles remain the publication source; each local copy should link back to its original post.

> **Historical examples are educational snapshots, not installation instructions.** Earlier articles may contain SQL objects, procedures, and Python examples that have since changed. For a supported fresh installation, follow [Getting Started](../GETTING_STARTED.md) and use only `tools/Install-AIAF.ps1` from the repository root.

## Reading order

This index lists the fifteen archived articles. Original publication URLs can be added as they are verified.

| Part | Article | Published | Local Markdown | Original post |
|---|---|---|---|---|
| 01 | AI Has Your Data. Now What? | 2026-08-20 | [Read](part-01-ai-has-your-data-now-what.md) | — |
| 02 | Your Prompt Is Data | 2026-08-27 | [Read](part-02-your-prompt-is-data.md) | — |
| 03 | Congratulations, You Just Logged the SSN | 2026-09-03 | [Read](part-03-congratulations-you-just-logged-the-ssn.md) | — |
| 04 | Should an AI Decide Whether Another AI Is Safe? | 2026-09-10 | [Read](part-04-should-an-ai-decide-whether-another-ai-is-safe.md) | — |
| 05 | Your AI Passed Security Review Six Months Ago. So What? | 2026-09-17 | [Read](part-05-your-ai-passed-security-review-six-months-ago-so-what.md) | — |
| 06 | Your AI Didn't Just Read the Prompt | 2026-09-24 | [Read](part-06-your-ai-didnt-just-read-the-prompt.md) | — |
| 07 | Can You Reproduce What Your AI Said Tuesday? | 2026-10-01 | [Read](part-07-can-you-reproduce-what-your-ai-said-tuesday.md) | — |
| 08 | Who Let the AI Touch the Database? | 2026-10-08 | [Read](part-08-who-let-the-ai-touch-the-database.md) | — |
| 09 | Give Your AI Tools, Not Passwords | 2026-10-15 | [Read](part-09-give-your-ai-tools-not-passwords.md) | — |
| 10 | Your AI Wants to UPDATE Production | 2026-10-22 | [Read](part-10-your-ai-wants-to-update-production.md) | — |
| 11 | Your AI Audit Log Says Nothing Bad Happened. Can You Prove It? | 2026-10-29 | [Read](part-11-your-ai-audit-log-says-nothing-bad-happened-can-you-prove-it.md) | — |
| 12 | Who Watches the AI Watching the AI? | 2026-11-05 | [Read](part-12-who-watches-the-ai-watching-the-ai.md) | — |
| 13 | Your AI Is Drifting. Are You Measuring It? | 2026-11-12 | [Read](part-13-your-ai-is-drifting-are-you-measuring-it.md) | — |
| 14 | The Quarterly AI Review Nobody Is Doing Yet | 2026-11-19 | [Read](part-14-the-quarterly-ai-review-nobody-is-doing-yet.md) | — |
| 15 | We Built the Framework. Now Let's See If It Actually Works. | 2026-11-26 | [Read](part-15-we-built-the-framework-now-lets-see-if-it-actually-works.md) | — |

## Conventions for each archived article

Use a stable filename such as `part-01-short-descriptive-slug.md` and include:

- The original published title and date.
- A link to the original Sherpa of Data article.
- The article text in Markdown, preserving the original technical context and examples.
- An optional short **Current implementation note** identifying material differences from the current AIAF repository, without rewriting history.
- Links to the relevant current documentation or source files where useful.

If an article has illustrations, link to the original article or add repository-appropriate assets only when their inclusion and licensing are confirmed. Avoid committing credentials, private data, or machine-specific connection details.

## Current reference documentation

- [Project overview](../../README.md)
- [Getting Started](../GETTING_STARTED.md) — supported deployment path
- [Testing and Verification](../TESTING.md) — current integration and SQL evidence checks
- [Reference Architecture](../ARCHITECTURE.md) — current design
- [Production Readiness](../PRODUCTION_READINESS.md) — known limitations and hardening work

**The model requests. The system decides. The architecture keeps the receipts.**
