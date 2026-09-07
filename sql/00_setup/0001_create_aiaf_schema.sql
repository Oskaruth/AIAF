/*
AIAF — AI Interaction Audit Framework
Published foundation through Article #3.

Creates the aiaf schema used by the reference implementation.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.schemas
    WHERE name = N'aiaf'
)
BEGIN
    EXEC(N'CREATE SCHEMA aiaf AUTHORIZATION dbo;');
END;
GO
