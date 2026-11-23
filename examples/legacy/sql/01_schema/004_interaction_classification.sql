/*
AIAF — Article #3: Congratulations, You Logged the SSN

Records classifications detected during an interaction.

This table records the evidence that a classification was detected.
It does NOT store the sensitive value itself.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'aiaf.InteractionClassification', N'U') IS NULL
BEGIN
    CREATE TABLE aiaf.InteractionClassification
    (
        InteractionClassificationId bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_InteractionClassification PRIMARY KEY,

        InteractionId bigint NOT NULL,
        DataClassificationId bigint NOT NULL,

        DetectionType varchar(50) NOT NULL,
        DetectionMethod nvarchar(200) NULL,
        DetectionCount int NOT NULL
            CONSTRAINT DF_InteractionClassification_DetectionCount DEFAULT (1),

        DetectedAt datetime2(3) NOT NULL
            CONSTRAINT DF_InteractionClassification_DetectedAt DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT FK_InteractionClassification_Interaction
            FOREIGN KEY (InteractionId)
            REFERENCES aiaf.AIInteraction (InteractionId),

        CONSTRAINT FK_InteractionClassification_DataClassification
            FOREIGN KEY (DataClassificationId)
            REFERENCES aiaf.DataClassification (DataClassificationId),

        CONSTRAINT CK_InteractionClassification_DetectionCount
            CHECK (DetectionCount > 0)
    );

    CREATE INDEX IX_InteractionClassification_Interaction
        ON aiaf.InteractionClassification
        (
            InteractionId,
            DataClassificationId
        );
END;
GO
