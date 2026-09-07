# AI Has Your Data. Now What?

The AIAF reference implementation is being built alongside the **AI Has Your Data. Now What?** article series.

Only concepts from published articles are included in the current repository implementation.

## Published

### Article #1
**We Spent Decades Securing the Database. Then We Connected an AI to It.**

Introduces the central AIAF idea:

> When AI touches enterprise data, the interaction itself becomes enterprise data.

### Article #2
**Your Prompt Is Data**

Introduces:

- versioned prompt definitions
- interaction identity
- requestor identity
- parent/child interactions
- the first AIAF interaction receipt

SQL objects:

- `aiaf.PromptDefinition`
- `aiaf.AIInteraction`

### Article #3
**Congratulations, You Logged the SSN**

Introduces:

- classification before persistence
- logging as data movement
- audit metadata
- sanitized interaction history
- restricted raw evidence as a separate security decision

SQL objects:

- `aiaf.DataClassification`
- `aiaf.InteractionClassification`
- `aiaf.SanitizedInteractionContent`

The repository deliberately does **not** create a raw-evidence table at this stage.
