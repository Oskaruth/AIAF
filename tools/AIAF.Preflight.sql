/*
    AIAF Installation Preflight

    Read-only inspection of the target SQL Server
    instance and database.

    This script does not modify server or database
    configuration and does not create any objects.
*/

SET NOCOUNT ON;

-- =====================================================
-- Server and database configuration
-- =====================================================

SELECT
    @@SERVERNAME AS ServerName,
    DB_NAME() AS DatabaseName,
    CONVERT(varchar(128),
        SERVERPROPERTY('ProductVersion')) AS ProductVersion,
    CONVERT(int,
        SERVERPROPERTY('ProductMajorVersion')) AS ProductMajorVersion,
    CONVERT(varchar(128),
        SERVERPROPERTY('Edition')) AS Edition,
    CONVERT(int,
        SERVERPROPERTY('EngineEdition')) AS EngineEdition,
    D.database_id AS DatabaseId,
    D.compatibility_level AS CompatibilityLevel,
    D.collation_name AS CollationName,
    D.state_desc AS DatabaseState,
    D.user_access_desc AS UserAccess,
    D.is_read_only AS IsReadOnly,
    D.snapshot_isolation_state_desc AS SnapshotIsolationState,
    D.is_read_committed_snapshot_on AS IsReadCommittedSnapshotOn,
    D.is_trustworthy_on AS IsTrustworthyOn,
    D.is_db_chaining_on AS IsDatabaseChainingOn,
	(
		SELECT CONVERT(int, value)
		FROM sys.configurations
		WHERE name = N'cross db ownership chaining'
	) AS ServerCrossDbChainingConfigured,
	(
		SELECT CONVERT(int, value_in_use)
		FROM sys.configurations
		WHERE name = N'cross db ownership chaining'
	) AS ServerCrossDbChainingRunning,
    D.is_ledger_on AS IsLedgerDatabase,
    ORIGINAL_LOGIN() AS InstallationLogin,
    USER_NAME() AS InstallationDatabaseUser,
    IS_ROLEMEMBER('db_owner') AS IsDbOwner,
    IS_SRVROLEMEMBER('sysadmin') AS IsSysAdmin
FROM sys.databases AS D
WHERE D.database_id = DB_ID();

-- =====================================================
-- Existing AIAF schemas
-- =====================================================

SELECT
    S.name AS SchemaName,
    USER_NAME(S.principal_id) AS SchemaOwner
FROM sys.schemas AS S
WHERE S.name IN
(
    'acme',
    'aiaf',
    'aiaf_governance',
    'aiaf_tool'
)
ORDER BY S.name;

-- =====================================================
-- Existing objects within AIAF schemas
-- =====================================================

SELECT
    S.name AS SchemaName,
    O.name AS ObjectName,
    O.type_desc AS ObjectType
FROM sys.objects AS O
INNER JOIN sys.schemas AS S
    ON S.schema_id = O.schema_id
WHERE S.name IN
(
    'acme',
    'aiaf',
    'aiaf_governance',
    'aiaf_tool'
)
    AND O.is_ms_shipped = 0
ORDER BY
    S.name,
    O.name;

-- =====================================================
-- Existing AIAF security principals
-- =====================================================

SELECT
    P.name AS PrincipalName,
    P.type_desc AS PrincipalType,
    P.authentication_type_desc AS AuthenticationType
FROM sys.database_principals AS P
WHERE P.name IN
(
    'AIAF_Runtime',
    'AIAF_GovernanceReader',
    'AIAF_GovernanceReviewer',
    'AIAF_GovernanceAttestor',
    'AIAF_TestRuntime',
    'AIAF_TestReader',
    'AIAF_TestReviewer',
    'AIAF_TestAttestor'
)
ORDER BY P.name;