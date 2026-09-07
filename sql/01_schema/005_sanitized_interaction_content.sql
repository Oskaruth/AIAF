/*
AIAF — Article #3: Congratulations, You Logged the SSN

Stores sanitized interaction content that is appropriate for
troubleshooting, analysis, and future auditing.

This is intentionally separate from raw evidence.
AIAF does not create a raw-evidence table at this stage.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'aiaf.SanitizedInteractionContent', N'U') IS NULL
BEGIN
    CREATE TABLE aiaf.SanitizedInteractionContent
    (
        SanitizedInteractionContentId bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_SanitizedInteractionContent PRIMARY KEY,

        InteractionId bigint NOT NULL,

        ContentType varchar(50) NOT NULL,
        SanitizedContent nvarchar(max) NOT NULL,
        SanitizationMethod nvarchar(200) NOT NULL,

        SanitizedAt datetime2(3) NOT NULL
            CONSTRAINT DF_SanitizedInteractionContent_SanitizedAt
            DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT FK_SanitizedInteractionContent_Interaction
            FOREIGN KEY (InteractionId)
            REFERENCES aiaf.AIInteraction (InteractionId)
    );

    CREATE INDEX IX_SanitizedInteractionContent_Interaction
        ON aiaf.SanitizedInteractionContent
        (
            InteractionId,
            ContentType,
            SanitizedAt
        );
END;
GO
