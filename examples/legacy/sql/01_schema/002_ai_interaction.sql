/*
AIAF — Article #2: Your Prompt Is Data

Creates the interaction receipt.

Important:
Raw user prompt content is intentionally NOT stored here.
Article #3 explains why.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'aiaf.AIInteraction', N'U') IS NULL
BEGIN
    CREATE TABLE aiaf.AIInteraction
    (
        InteractionId bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_AIInteraction PRIMARY KEY,

        ParentInteractionId bigint NULL,
        PromptDefinitionId bigint NULL,

        RequestorType varchar(30) NOT NULL,
        RequestorIdentifier nvarchar(256) NOT NULL,
        ApplicationName nvarchar(200) NOT NULL,

        StartedAt datetime2(3) NOT NULL
            CONSTRAINT DF_AIInteraction_StartedAt DEFAULT (SYSUTCDATETIME()),
        CompletedAt datetime2(3) NULL,

        Status varchar(30) NOT NULL,

        CONSTRAINT FK_AIInteraction_Parent
            FOREIGN KEY (ParentInteractionId)
            REFERENCES aiaf.AIInteraction (InteractionId),

        CONSTRAINT FK_AIInteraction_PromptDefinition
            FOREIGN KEY (PromptDefinitionId)
            REFERENCES aiaf.PromptDefinition (PromptDefinitionId),

        CONSTRAINT CK_AIInteraction_Status
            CHECK (Status IN
            (
                'RECEIVED',
                'IN_PROGRESS',
                'COMPLETED',
                'DENIED',
                'FAILED'
            )),

        CONSTRAINT CK_AIInteraction_RequestorType
            CHECK (RequestorType IN
            (
                'PERSON',
                'APPLICATION',
                'SERVICE_PRINCIPAL',
                'AGENT'
            )),

        CONSTRAINT CK_AIInteraction_CompletedAt
            CHECK (CompletedAt IS NULL OR CompletedAt >= StartedAt)
    );

    CREATE INDEX IX_AIInteraction_StartedAt
        ON aiaf.AIInteraction (StartedAt DESC);

    CREATE INDEX IX_AIInteraction_Requestor
        ON aiaf.AIInteraction (RequestorType, RequestorIdentifier, StartedAt DESC);

    CREATE INDEX IX_AIInteraction_PromptDefinition
        ON aiaf.AIInteraction (PromptDefinitionId, StartedAt DESC);
END;
GO
