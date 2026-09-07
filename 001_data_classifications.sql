/*
AIAF — Article #3 reference data

Seeds the initial enterprise classification levels used by the examples.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

MERGE aiaf.DataClassification AS tgt
USING
(
    VALUES
        ('Public',       1, N'Information approved for public disclosure.',                         1, NULL),
        ('Internal',     2, N'Information intended for internal business use.',                     1, 365),
        ('Confidential', 3, N'Sensitive business or personal information requiring tighter access.', 0, 90),
        ('Restricted',   4, N'Highly sensitive information subject to strict handling controls.',     0, 0)
) AS src
(
    ClassificationName,
    ClassificationLevel,
    Description,
    RawRetentionAllowed,
    DefaultRetentionDays
)
ON tgt.ClassificationName = src.ClassificationName

WHEN MATCHED THEN
    UPDATE SET
        ClassificationLevel = src.ClassificationLevel,
        Description = src.Description,
        RawRetentionAllowed = src.RawRetentionAllowed,
        DefaultRetentionDays = src.DefaultRetentionDays

WHEN NOT MATCHED THEN
    INSERT
    (
        ClassificationName,
        ClassificationLevel,
        Description,
        RawRetentionAllowed,
        DefaultRetentionDays
    )
    VALUES
    (
        src.ClassificationName,
        src.ClassificationLevel,
        src.Description,
        src.RawRetentionAllowed,
        src.DefaultRetentionDays
    );
GO
