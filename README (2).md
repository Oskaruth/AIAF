# AIAF SQL — Published Through Article #3

This folder contains the SQL Server reference implementation that has been introduced in the published **AI Has Your Data. Now What?** articles through Article #3.

## Execution Order

Run the scripts in this order:

```text
00_setup/
  001_create_aiaf_schema.sql

01_schema/
  001_prompt_definition.sql
  002_ai_interaction.sql
  003_data_classification.sql
  004_interaction_classification.sql
  005_sanitized_interaction_content.sql

02_reference_data/
  001_data_classifications.sql

99_demo/
  001_prompt_versioning_demo.sql
  002_sensitive_data_handling_demo.sql
```

The scripts assume you have already selected the SQL Server database in which you want to install the AIAF objects.

## Design Notes

AIAF internal identifiers use `bigint IDENTITY(1,1)`.

The `AIInteraction` table intentionally does **not** contain a raw user-prompt column.

Article #3 introduces the distinction between:

- audit metadata
- sanitized interaction history
- restricted raw evidence

No raw-evidence table is created yet. That is deliberate.

> Logging is data movement.

The reference implementation should not create a second sensitive-data repository merely because somebody said, "log everything."
