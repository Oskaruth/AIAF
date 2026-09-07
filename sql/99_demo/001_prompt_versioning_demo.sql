/*
AIAF — Article #2 demo
Your Prompt Is Data

Shows why prompt definitions should be versioned.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @Now datetime2(3) = SYSUTCDATETIME();

IF NOT EXISTS
(
    SELECT 1
    FROM aiaf.PromptDefinition
    WHERE PromptCode = 'FIN-AR-004'
      AND VersionNumber = 1
)
BEGIN
    INSERT aiaf.PromptDefinition
    (
        PromptCode,
        PromptName,
        PromptType,
        VersionNumber,
        PromptTemplate,
        EffectiveFrom,
        EffectiveTo,
        IsActive,
        CreatedBy,
        ChangeReason
    )
    VALUES
    (
        'FIN-AR-004',
        N'Overdue Customer Outreach',
        'SYSTEM',
        1,
        N'Identify customers with invoices more than 60 days overdue.',
        DATEADD(day, -90, @Now),
        DATEADD(day, -60, @Now),
        0,
        N'aiaf-demo',
        N'Initial version.'
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM aiaf.PromptDefinition
    WHERE PromptCode = 'FIN-AR-004'
      AND VersionNumber = 2
)
BEGIN
    INSERT aiaf.PromptDefinition
    (
        PromptCode,
        PromptName,
        PromptType,
        VersionNumber,
        PromptTemplate,
        EffectiveFrom,
        EffectiveTo,
        IsActive,
        CreatedBy,
        ChangeReason
    )
    VALUES
    (
        'FIN-AR-004',
        N'Overdue Customer Outreach',
        'SYSTEM',
        2,
        N'Identify customers with invoices more than 30 days overdue.',
        DATEADD(day, -60, @Now),
        DATEADD(day, -30, @Now),
        0,
        N'aiaf-demo',
        N'Business expanded outreach window.'
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM aiaf.PromptDefinition
    WHERE PromptCode = 'FIN-AR-004'
      AND VersionNumber = 3
)
BEGIN
    INSERT aiaf.PromptDefinition
    (
        PromptCode,
        PromptName,
        PromptType,
        VersionNumber,
        PromptTemplate,
        EffectiveFrom,
        EffectiveTo,
        IsActive,
        CreatedBy,
        ChangeReason
    )
    VALUES
    (
        'FIN-AR-004',
        N'Overdue Customer Outreach',
        'SYSTEM',
        3,
        N'Identify customers with invoices more than 30 days overdue, excluding customers with active disputes.',
        DATEADD(day, -30, @Now),
        NULL,
        1,
        N'aiaf-demo',
        N'Exclude customers with active disputes.'
    );
END;

DECLARE @PromptDefinitionId bigint;

SELECT @PromptDefinitionId = PromptDefinitionId
FROM aiaf.PromptDefinition
WHERE PromptCode = 'FIN-AR-004'
  AND VersionNumber = 3;

INSERT aiaf.AIInteraction
(
    ParentInteractionId,
    PromptDefinitionId,
    RequestorType,
    RequestorIdentifier,
    ApplicationName,
    Status
)
VALUES
(
    NULL,
    @PromptDefinitionId,
    'PERSON',
    N'alice@example.invalid',
    N'Sherpa Accounts Receivable Assistant',
    'RECEIVED'
);

DECLARE @InteractionId bigint = SCOPE_IDENTITY();

UPDATE aiaf.AIInteraction
SET
    CompletedAt = SYSUTCDATETIME(),
    Status = 'COMPLETED'
WHERE InteractionId = @InteractionId;

SELECT
    i.InteractionId,
    i.RequestorType,
    i.RequestorIdentifier,
    i.ApplicationName,
    i.Status,
    p.PromptCode,
    p.VersionNumber,
    p.PromptTemplate,
    i.StartedAt,
    i.CompletedAt
FROM aiaf.AIInteraction AS i
INNER JOIN aiaf.PromptDefinition AS p
    ON p.PromptDefinitionId = i.PromptDefinitionId
WHERE i.InteractionId = @InteractionId;

SELECT
    PromptCode,
    VersionNumber,
    PromptTemplate,
    EffectiveFrom,
    EffectiveTo,
    IsActive,
    ChangeReason
FROM aiaf.PromptDefinition
WHERE PromptCode = 'FIN-AR-004'
ORDER BY VersionNumber;
GO
