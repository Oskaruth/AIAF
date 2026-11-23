/*
AIAF — Article #3: Congratulations, You Logged the SSN

Defines enterprise data classifications used to describe
what kinds of data were detected in an interaction.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'aiaf.DataClassification', N'U') IS NULL
BEGIN
    CREATE TABLE aiaf.DataClassification
    (
        DataClassificationId bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_DataClassification PRIMARY KEY,

        ClassificationName varchar(50) NOT NULL,
        ClassificationLevel int NOT NULL,
        Description nvarchar(1000) NULL,

        RawRetentionAllowed bit NOT NULL,
        DefaultRetentionDays int NULL,

        CreatedAt datetime2(3) NOT NULL
            CONSTRAINT DF_DataClassification_CreatedAt DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT UQ_DataClassification_Name
            UNIQUE (ClassificationName),

        CONSTRAINT CK_DataClassification_Level
            CHECK (ClassificationLevel > 0),

        CONSTRAINT CK_DataClassification_RetentionDays
            CHECK (DefaultRetentionDays IS NULL OR DefaultRetentionDays >= 0)
    );
END;
GO
