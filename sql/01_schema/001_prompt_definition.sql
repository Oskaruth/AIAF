/*
AIAF — Article #2: Your Prompt Is Data

Stores versioned prompt definitions.
A prompt definition is an enterprise artifact, not an individual user's raw request.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'aiaf.PromptDefinition', N'U') IS NULL
BEGIN
    CREATE TABLE aiaf.PromptDefinition
    (
        PromptDefinitionId bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_PromptDefinition PRIMARY KEY,

        PromptCode varchar(100) NOT NULL,
        PromptName nvarchar(200) NOT NULL,
        PromptType varchar(30) NOT NULL,
        VersionNumber int NOT NULL,
        PromptTemplate nvarchar(max) NOT NULL,
        EffectiveFrom datetime2(3) NOT NULL,
        EffectiveTo datetime2(3) NULL,
        IsActive bit NOT NULL
            CONSTRAINT DF_PromptDefinition_IsActive DEFAULT (1),

        CreatedAt datetime2(3) NOT NULL
            CONSTRAINT DF_PromptDefinition_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CreatedBy nvarchar(256) NOT NULL,
        ChangeReason nvarchar(1000) NULL,

        CONSTRAINT UQ_PromptDefinition_CodeVersion
            UNIQUE (PromptCode, VersionNumber),

        CONSTRAINT CK_PromptDefinition_VersionNumber
            CHECK (VersionNumber > 0),

        CONSTRAINT CK_PromptDefinition_EffectiveDates
            CHECK (EffectiveTo IS NULL OR EffectiveTo > EffectiveFrom)
    );

    CREATE INDEX IX_PromptDefinition_Active
        ON aiaf.PromptDefinition (PromptCode, IsActive, EffectiveFrom DESC);
END;
GO
