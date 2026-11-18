/*
    AIAF Security Configuration Verification

    Purpose:
        Verify core database roles, schema ownership
        and explicit role permissions.

    Requirements:
        AIAF database objects and core security installed.
        Sufficient permissions to inspect database metadata.

    Expected result:
        All 9 checks pass.

    This script does not modify persistent database objects.
*/

SET NOCOUNT ON;

DROP TABLE IF EXISTS #SecurityResults;
DROP TABLE IF EXISTS #ExpectedPermissions;
DROP TABLE IF EXISTS #ActualPermissions;

CREATE TABLE #SecurityResults
(
    CheckName varchar(200) NOT NULL,
    ExpectedValue int NOT NULL,
    ActualValue int NOT NULL
);

CREATE TABLE #ExpectedPermissions
(
    RoleName sysname COLLATE DATABASE_DEFAULT NOT NULL,
    PermissionState varchar(60) COLLATE DATABASE_DEFAULT NOT NULL,
    PermissionName sysname COLLATE DATABASE_DEFAULT NOT NULL,
    PermissionScope varchar(60) COLLATE DATABASE_DEFAULT NOT NULL,
    SecurableName nvarchar(517) COLLATE DATABASE_DEFAULT NOT NULL
);

-- =====================================================
-- Expected runtime permissions
-- =====================================================

INSERT INTO #ExpectedPermissions
SELECT
    'AIAF_Runtime',
    'DENY',
    P.PermissionName,
    'SCHEMA',
    S.SchemaName
FROM
(
    VALUES ('[acme]'),
           ('[aiaf]'),
           ('[aiaf_governance]')
) AS S(SchemaName)
CROSS JOIN
(
    VALUES ('SELECT'),
           ('INSERT'),
           ('UPDATE'),
           ('DELETE')
) AS P(PermissionName);

INSERT INTO #ExpectedPermissions
VALUES
(
    'AIAF_Runtime',
    'DENY',
    'EXECUTE',
    'SCHEMA',
    '[aiaf_governance]'
);

INSERT INTO #ExpectedPermissions
SELECT
    'AIAF_Runtime',
    'GRANT',
    'EXECUTE',
    'OBJECT_OR_COLUMN',
    P.ObjectName
FROM
(
    VALUES
        ('[aiaf].[usp_BeginInteraction]'),
        ('[aiaf].[usp_CompleteInteraction]'),
        ('[aiaf].[usp_RecordInputValidation]'),
        ('[aiaf].[usp_RecordModelExecution]'),
        ('[aiaf].[usp_RecordModelToolRequest]'),
        ('[aiaf].[usp_RecordOutputValidation]'),
        ('[aiaf_tool].[GetCustomerBalance]')
) AS P(ObjectName);

-- =====================================================
-- Expected governance permissions
-- =====================================================

INSERT INTO #ExpectedPermissions
SELECT
    R.RoleName,
    P.PermissionState,
    P.PermissionName,
    'SCHEMA',
    '[aiaf_governance]'
FROM
(
    VALUES
        ('AIAF_GovernanceReader'),
        ('AIAF_GovernanceReviewer'),
        ('AIAF_GovernanceAttestor')
) AS R(RoleName)
CROSS JOIN
(
    VALUES
        ('GRANT', 'SELECT'),
        ('DENY', 'INSERT'),
        ('DENY', 'UPDATE'),
        ('DENY', 'DELETE')
) AS P(PermissionState, PermissionName);

INSERT INTO #ExpectedPermissions
VALUES
(
    'AIAF_GovernanceReviewer',
    'GRANT',
    'EXECUTE',
    'OBJECT_OR_COLUMN',
    '[aiaf_governance].[usp_FreezeReview]'
),
(
    'AIAF_GovernanceAttestor',
    'GRANT',
    'EXECUTE',
    'OBJECT_OR_COLUMN',
    '[aiaf_governance].[usp_AttestReview]'
);

-- =====================================================
-- Capture actual permissions
-- =====================================================

SELECT
    P.name COLLATE DATABASE_DEFAULT AS RoleName,
    D.state_desc COLLATE DATABASE_DEFAULT AS PermissionState,
    D.permission_name COLLATE DATABASE_DEFAULT AS PermissionName,
    D.class_desc COLLATE DATABASE_DEFAULT AS PermissionScope,

    (
        CASE D.class
            WHEN 0 THEN QUOTENAME(DB_NAME())
            WHEN 3 THEN QUOTENAME(SCHEMA_NAME(D.major_id))
            WHEN 1 THEN
                QUOTENAME(OBJECT_SCHEMA_NAME(D.major_id))
                + '.'
                + QUOTENAME(OBJECT_NAME(D.major_id))
                + CASE
                    WHEN D.minor_id > 0
                    THEN '.' + QUOTENAME(
                        COL_NAME(D.major_id, D.minor_id)
                    )
                    ELSE ''
                  END
            ELSE CONVERT(nvarchar(20), D.major_id)
        END
    ) COLLATE DATABASE_DEFAULT AS SecurableName

INTO #ActualPermissions
FROM sys.database_permissions AS D
INNER JOIN sys.database_principals AS P
    ON P.principal_id = D.grantee_principal_id
WHERE P.name IN
(
    'AIAF_Runtime',
    'AIAF_GovernanceReader',
    'AIAF_GovernanceReviewer',
    'AIAF_GovernanceAttestor'
);

-- =====================================================
-- Check 1: Required database roles
-- =====================================================

INSERT INTO #SecurityResults
SELECT
    'Required database roles',
    4,
    COUNT(*)
FROM sys.database_principals
WHERE type = 'R'
AND is_fixed_role = 0
AND name IN
(
    'AIAF_Runtime',
    'AIAF_GovernanceReader',
    'AIAF_GovernanceReviewer',
    'AIAF_GovernanceAttestor'
);

-- =====================================================
-- Check 2: Role ownership
-- =====================================================

INSERT INTO #SecurityResults
SELECT
    'Roles owned by dbo',
    4,
    COUNT(*)
FROM sys.database_principals
WHERE type = 'R'
AND USER_NAME(owning_principal_id) = 'dbo'
AND name IN
(
    'AIAF_Runtime',
    'AIAF_GovernanceReader',
    'AIAF_GovernanceReviewer',
    'AIAF_GovernanceAttestor'
);

-- =====================================================
-- Check 3: Schema ownership
-- =====================================================

INSERT INTO #SecurityResults
SELECT
    'Schemas owned by dbo',
    4,
    COUNT(*)
FROM sys.schemas
WHERE USER_NAME(principal_id) = 'dbo'
AND name IN
(
    'acme',
    'aiaf',
    'aiaf_governance',
    'aiaf_tool'
);

-- =====================================================
-- Checks 4-7: Explicit permission counts
-- =====================================================

INSERT INTO #SecurityResults
SELECT
    'Expected permission definitions',
    34,
    COUNT(*)
FROM #ExpectedPermissions;

INSERT INTO #SecurityResults
SELECT
    'Actual explicit role permissions',
    34,
    COUNT(*)
FROM #ActualPermissions;

INSERT INTO #SecurityResults
SELECT
    'Explicit role grants',
    12,
    COUNT(*)
FROM #ActualPermissions
WHERE PermissionState = 'GRANT';

INSERT INTO #SecurityResults
SELECT
    'Explicit role denies',
    22,
    COUNT(*)
FROM #ActualPermissions
WHERE PermissionState = 'DENY';

-- =====================================================
-- Check 8: Missing permissions
-- =====================================================

INSERT INTO #SecurityResults
SELECT
    'Missing expected permissions',
    0,
    COUNT(*)
FROM
(
    SELECT * FROM #ExpectedPermissions

    EXCEPT

    SELECT * FROM #ActualPermissions
) AS MissingPermissions;

-- =====================================================
-- Check 9: Unexpected permissions
-- =====================================================

INSERT INTO #SecurityResults
SELECT
    'Unexpected permissions',
    0,
    COUNT(*)
FROM
(
    SELECT * FROM #ActualPermissions

    EXCEPT

    SELECT * FROM #ExpectedPermissions
) AS UnexpectedPermissions;

-- =====================================================
-- Display permission discrepancies
-- =====================================================

SELECT
    'MISSING' AS Discrepancy,
    D.*
FROM
(
    SELECT * FROM #ExpectedPermissions

    EXCEPT

    SELECT * FROM #ActualPermissions
) AS D;

SELECT
    'UNEXPECTED' AS Discrepancy,
    D.*
FROM
(
    SELECT * FROM #ActualPermissions

    EXCEPT

    SELECT * FROM #ExpectedPermissions
) AS D;

-- =====================================================
-- Display verification results
-- =====================================================

SELECT
    CheckName,
    ExpectedValue,
    ActualValue,
    CASE
        WHEN ExpectedValue = ActualValue THEN 'PASS'
        ELSE 'FAIL'
    END AS Result
FROM #SecurityResults
ORDER BY CheckName;

SELECT
    COUNT(*) AS TotalChecks,
    SUM(
        CASE WHEN ExpectedValue = ActualValue
             THEN 1 ELSE 0 END
    ) AS PassedChecks,
    SUM(
        CASE WHEN ExpectedValue <> ActualValue
             THEN 1 ELSE 0 END
    ) AS FailedChecks
FROM #SecurityResults;

IF EXISTS
(
    SELECT 1
    FROM #SecurityResults
    WHERE ExpectedValue <> ActualValue
)
BEGIN
    THROW 52600,
        'AIAF security configuration verification failed.',
        1;
END;

PRINT 'AIAF security configuration verification passed.';