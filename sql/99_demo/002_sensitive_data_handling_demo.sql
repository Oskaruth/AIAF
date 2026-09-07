/*
AIAF — Article #3 demo
Congratulations, You Logged the SSN

The raw request in this example is intentionally represented only
inside this script as test input.

The demonstration persists:
  - interaction metadata
  - the fact that restricted data was detected
  - sanitized content

It intentionally does NOT persist the sensitive value.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @PromptDefinitionId bigint;

SELECT TOP (1)
    @PromptDefinitionId = PromptDefinitionId
FROM aiaf.PromptDefinition
WHERE PromptCode = 'FIN-AR-004'
ORDER BY VersionNumber DESC;

IF @PromptDefinitionId IS NULL
BEGIN
    THROW 50001, 'Run 001_prompt_versioning_demo.sql before this demo.', 1;
END;

DECLARE @RestrictedClassificationId bigint;

SELECT
    @RestrictedClassificationId = DataClassificationId
FROM aiaf.DataClassification
WHERE ClassificationName = 'Restricted';

IF @RestrictedClassificationId IS NULL
BEGIN
    THROW 50002, 'Run 001_data_classifications.sql before this demo.', 1;
END;

/*
Synthetic test input only.

A production implementation should classify and sanitize before deciding
what, if anything, is appropriate to persist.
*/
DECLARE @RawTestInput nvarchar(max) =
    N'Customer John Smith has SSN 123-45-6789 and account 900042. Can I increase his credit limit?';

DECLARE @SanitizedInput nvarchar(max) =
    N'Customer [CUSTOMER] has SSN [REDACTED] and account [ACCOUNT]. Can I increase the credit limit?';

INSERT aiaf.AIInteraction
(
    ParentInteractionId,
    PromptDefinitionId,
    RequestorType,
    RequestorIdentifier,
    ApplicationName,
    CompletedAt,
    Status
)
VALUES
(
    NULL,
    @PromptDefinitionId,
    'PERSON',
    N'bob@example.invalid',
    N'Sherpa Accounts Receivable Assistant',
    SYSUTCDATETIME(),
    'DENIED'
);

DECLARE @InteractionId bigint = SCOPE_IDENTITY();

INSERT aiaf.InteractionClassification
(
    InteractionId,
    DataClassificationId,
    DetectionType,
    DetectionMethod,
    DetectionCount
)
VALUES
(
    @InteractionId,
    @RestrictedClassificationId,
    'POSSIBLE_SSN_PATTERN',
    N'Deterministic pattern detection',
    1
);

INSERT aiaf.SanitizedInteractionContent
(
    InteractionId,
    ContentType,
    SanitizedContent,
    SanitizationMethod
)
VALUES
(
    @InteractionId,
    'USER_PROMPT',
    @SanitizedInput,
    N'Replaced customer identity, SSN pattern, and account identifier with placeholders'
);

/*
Notice what is NOT inserted anywhere:
    @RawTestInput

That is intentional.
*/

SELECT
    i.InteractionId,
    i.RequestorIdentifier,
    i.ApplicationName,
    i.Status,
    dc.ClassificationName,
    ic.DetectionType,
    ic.DetectionMethod,
    ic.DetectionCount,
    sic.ContentType,
    sic.SanitizedContent,
    sic.SanitizationMethod
FROM aiaf.AIInteraction AS i
LEFT JOIN aiaf.InteractionClassification AS ic
    ON ic.InteractionId = i.InteractionId
LEFT JOIN aiaf.DataClassification AS dc
    ON dc.DataClassificationId = ic.DataClassificationId
LEFT JOIN aiaf.SanitizedInteractionContent AS sic
    ON sic.InteractionId = i.InteractionId
WHERE i.InteractionId = @InteractionId;
GO
