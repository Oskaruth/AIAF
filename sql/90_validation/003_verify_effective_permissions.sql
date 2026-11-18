/*
    AIAF Effective Permissions Verification

    Requirements:
        Core AIAF database objects
        Core AIAF security roles and permissions
        Optional AIAF test principals
        Permission to impersonate the test principals

    No persistent database changes are made.
*/

SET NOCOUNT ON;

DROP TABLE IF EXISTS #PermissionChecks;

CREATE TABLE #PermissionChecks
(
    CheckId int IDENTITY(1,1) PRIMARY KEY,
    PrincipalName sysname COLLATE DATABASE_DEFAULT NOT NULL,
    SecurableName nvarchar(517) COLLATE DATABASE_DEFAULT NOT NULL,
    SecurableType varchar(20) COLLATE DATABASE_DEFAULT NOT NULL,
    PermissionName sysname COLLATE DATABASE_DEFAULT NOT NULL,
    ExpectedValue int NOT NULL,
    ActualValue int NULL
);

-- =====================================================
-- Runtime: approved execution interfaces (7 checks)
-- =====================================================

INSERT INTO #PermissionChecks
(
    PrincipalName,
    SecurableName,
    SecurableType,
    PermissionName,
    ExpectedValue
)
SELECT
    'AIAF_TestRuntime',
    P.ObjectName,
    'OBJECT',
    'EXECUTE',
    1
FROM
(
    VALUES
        ('aiaf.usp_BeginInteraction'),
        ('aiaf.usp_CompleteInteraction'),
        ('aiaf.usp_RecordInputValidation'),
        ('aiaf.usp_RecordModelExecution'),
        ('aiaf.usp_RecordModelToolRequest'),
        ('aiaf.usp_RecordOutputValidation'),
        ('aiaf_tool.GetCustomerBalance')
) AS P(ObjectName);

-- =====================================================
-- Runtime: prohibited schema access (13 checks)
-- =====================================================

INSERT INTO #PermissionChecks
(
    PrincipalName,
    SecurableName,
    SecurableType,
    PermissionName,
    ExpectedValue
)
SELECT
    'AIAF_TestRuntime',
    S.SchemaName,
    'SCHEMA',
    P.PermissionName,
    0
FROM
(
    VALUES
        ('acme'),
        ('aiaf'),
        ('aiaf_governance')
) AS S(SchemaName)
CROSS JOIN
(
    VALUES
        ('SELECT'),
        ('INSERT'),
        ('UPDATE'),
        ('DELETE')
) AS P(PermissionName);

INSERT INTO #PermissionChecks
VALUES
(
    'AIAF_TestRuntime',
    'aiaf_governance',
    'SCHEMA',
    'EXECUTE',
    0,
    NULL
);

-- =====================================================
-- Runtime: prohibited internal interfaces and
-- representative direct object access (7 checks)
-- =====================================================

INSERT INTO #PermissionChecks
VALUES
('AIAF_TestRuntime', 'aiaf.usp_EvaluateGovernanceGate',
    'OBJECT', 'EXECUTE', 0, NULL),
('AIAF_TestRuntime', 'aiaf_governance.usp_FreezeReview',
    'OBJECT', 'EXECUTE', 0, NULL),
('AIAF_TestRuntime', 'aiaf_governance.usp_AttestReview',
    'OBJECT', 'EXECUTE', 0, NULL),
('AIAF_TestRuntime', 'acme.Customer',
    'OBJECT', 'SELECT', 0, NULL),
('AIAF_TestRuntime', 'acme.Invoice',
    'OBJECT', 'SELECT', 0, NULL),
('AIAF_TestRuntime', 'aiaf.AIInteractionEvent',
    'OBJECT', 'SELECT', 0, NULL),
('AIAF_TestRuntime', 'aiaf.AIInteractionEvent',
    'OBJECT', 'INSERT', 0, NULL);

-- =====================================================
-- Governance: schema permissions (12 checks)
-- =====================================================

INSERT INTO #PermissionChecks
(
    PrincipalName,
    SecurableName,
    SecurableType,
    PermissionName,
    ExpectedValue
)
SELECT
    U.PrincipalName,
    'aiaf_governance',
    'SCHEMA',
    P.PermissionName,
    P.ExpectedValue
FROM
(
    VALUES
        ('AIAF_TestReader'),
        ('AIAF_TestReviewer'),
        ('AIAF_TestAttestor')
) AS U(PrincipalName)
CROSS JOIN
(
    VALUES
        ('SELECT', 1),
        ('INSERT', 0),
        ('UPDATE', 0),
        ('DELETE', 0)
) AS P(PermissionName, ExpectedValue);

-- =====================================================
-- Governance: separation of duties (6 checks)
-- =====================================================

INSERT INTO #PermissionChecks
VALUES
('AIAF_TestReader', 'aiaf_governance.usp_FreezeReview',
    'OBJECT', 'EXECUTE', 0, NULL),
('AIAF_TestReader', 'aiaf_governance.usp_AttestReview',
    'OBJECT', 'EXECUTE', 0, NULL),

('AIAF_TestReviewer', 'aiaf_governance.usp_FreezeReview',
    'OBJECT', 'EXECUTE', 1, NULL),
('AIAF_TestReviewer', 'aiaf_governance.usp_AttestReview',
    'OBJECT', 'EXECUTE', 0, NULL),

('AIAF_TestAttestor', 'aiaf_governance.usp_FreezeReview',
    'OBJECT', 'EXECUTE', 0, NULL),
('AIAF_TestAttestor', 'aiaf_governance.usp_AttestReview',
    'OBJECT', 'EXECUTE', 1, NULL);

-- =====================================================
-- Governance: prohibited business and runtime access
-- (9 checks)
-- =====================================================

INSERT INTO #PermissionChecks
(
    PrincipalName,
    SecurableName,
    SecurableType,
    PermissionName,
    ExpectedValue
)
SELECT
    U.PrincipalName,
    P.SecurableName,
    'OBJECT',
    P.PermissionName,
    0
FROM
(
    VALUES
        ('AIAF_TestReader'),
        ('AIAF_TestReviewer'),
        ('AIAF_TestAttestor')
) AS U(PrincipalName)
CROSS JOIN
(
    VALUES
        ('acme.Customer', 'SELECT'),
        ('aiaf.usp_BeginInteraction', 'EXECUTE'),
        ('aiaf_tool.GetCustomerBalance', 'EXECUTE')
) AS P(SecurableName, PermissionName);

-- =====================================================
-- Validate test principal configuration
-- =====================================================

DECLARE @TestPrincipals TABLE
(
    PrincipalName sysname COLLATE DATABASE_DEFAULT,
    ExpectedRole sysname COLLATE DATABASE_DEFAULT
);

INSERT INTO @TestPrincipals
VALUES
('AIAF_TestRuntime', 'AIAF_Runtime'),
('AIAF_TestReader', 'AIAF_GovernanceReader'),
('AIAF_TestReviewer', 'AIAF_GovernanceReviewer'),
('AIAF_TestAttestor', 'AIAF_GovernanceAttestor');

IF EXISTS
(
    SELECT 1
    FROM @TestPrincipals AS T
    LEFT JOIN sys.database_principals AS P
        ON P.name = T.PrincipalName
    WHERE P.principal_id IS NULL
       OR P.type <> 'S'
       OR P.authentication_type <> 0
)
BEGIN
    THROW 52601,
        'Required loginless test principals are missing or invalid.',
        1;
END;

-- Ensure every test principal belongs only to its
-- designated explicitly assigned database role.

IF EXISTS
(
    SELECT 1
    FROM @TestPrincipals AS T
    LEFT JOIN sys.database_principals AS M
        ON M.name = T.PrincipalName
    LEFT JOIN sys.database_role_members AS RM
        ON RM.member_principal_id = M.principal_id
    LEFT JOIN sys.database_principals AS R
        ON R.principal_id = RM.role_principal_id
    GROUP BY T.PrincipalName, T.ExpectedRole
    HAVING COUNT(R.principal_id) <> 1
        OR MAX(R.name) <> T.ExpectedRole
)
BEGIN
    THROW 52602,
        'Unexpected test principal role membership.',
        1;
END;

-- Validate that every securable exists before
-- evaluating permissions under restricted identities.

IF EXISTS
(
    SELECT 1
    FROM #PermissionChecks
    WHERE
        (SecurableType = 'OBJECT'
            AND OBJECT_ID(SecurableName) IS NULL)
        OR
        (SecurableType = 'SCHEMA'
            AND SCHEMA_ID(SecurableName) IS NULL)
)
BEGIN
    THROW 52603,
        'One or more required securables do not exist.',
        1;
END;

-- =====================================================
-- Execute effective permission checks
-- =====================================================

DECLARE
    @CheckId int,
    @PrincipalName sysname,
    @ExpectedRole sysname,
    @SecurableName nvarchar(517),
    @SecurableType varchar(20),
    @PermissionName sysname,
    @ActualValue int,
    @ExecutingAsUser bit = 0;

DECLARE PermissionCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT
    C.CheckId,
    C.PrincipalName,
    T.ExpectedRole,
    C.SecurableName,
    C.SecurableType,
    C.PermissionName
FROM #PermissionChecks AS C
INNER JOIN @TestPrincipals AS T
    ON T.PrincipalName = C.PrincipalName
ORDER BY C.CheckId;

BEGIN TRY

    OPEN PermissionCursor;

    FETCH NEXT FROM PermissionCursor
    INTO @CheckId, @PrincipalName, @ExpectedRole,
         @SecurableName, @SecurableType, @PermissionName;

    WHILE @@FETCH_STATUS = 0
    BEGIN

        EXECUTE AS USER = @PrincipalName;

        SET @ExecutingAsUser = 1;

        IF USER_NAME() <> @PrincipalName
           OR ISNULL(IS_ROLEMEMBER(@ExpectedRole), -1) <> 1
           OR ISNULL(IS_ROLEMEMBER('db_owner'), -1) <> 0
        BEGIN
            THROW 52604,
                'Unexpected execution identity or role membership.',
                1;
        END;

        SET @ActualValue = HAS_PERMS_BY_NAME
        (
            @SecurableName,
            @SecurableType,
            @PermissionName
        );

        REVERT;

        SET @ExecutingAsUser = 0;

        UPDATE #PermissionChecks
        SET ActualValue = @ActualValue
        WHERE CheckId = @CheckId;

        FETCH NEXT FROM PermissionCursor
        INTO @CheckId, @PrincipalName, @ExpectedRole,
             @SecurableName, @SecurableType, @PermissionName;

    END;

    CLOSE PermissionCursor;
    DEALLOCATE PermissionCursor;

END TRY
BEGIN CATCH

    IF @ExecutingAsUser = 1
    BEGIN
        REVERT;
    END;

    IF CURSOR_STATUS('local', 'PermissionCursor') >= 0
        CLOSE PermissionCursor;

    IF CURSOR_STATUS('local', 'PermissionCursor') >= -1
        DEALLOCATE PermissionCursor;

    THROW;

END CATCH;

-- =====================================================
-- Results
-- =====================================================

SELECT
    CheckId,
    PrincipalName,
    SecurableName,
    SecurableType,
    PermissionName,
    ExpectedValue,
    ActualValue,
    CASE
        WHEN ActualValue = ExpectedValue THEN 'PASS'
        ELSE 'FAIL'
    END AS Result
FROM #PermissionChecks
ORDER BY CheckId;

SELECT
    PrincipalName,
    COUNT(*) AS TotalChecks,
    SUM(CASE WHEN ActualValue = ExpectedValue
             THEN 1 ELSE 0 END) AS PassedChecks,
    SUM(CASE WHEN ActualValue = ExpectedValue
             THEN 0 ELSE 1 END) AS FailedChecks
FROM #PermissionChecks
GROUP BY PrincipalName
ORDER BY PrincipalName;

SELECT
    COUNT(*) AS TotalChecks,
    SUM(CASE WHEN ActualValue = ExpectedValue
             THEN 1 ELSE 0 END) AS PassedChecks,
    SUM(CASE WHEN ActualValue = ExpectedValue
             THEN 0 ELSE 1 END) AS FailedChecks
FROM #PermissionChecks;

IF EXISTS
(
    SELECT 1
    FROM #PermissionChecks
    WHERE ActualValue IS NULL
       OR ActualValue <> ExpectedValue
)
BEGIN
    THROW 52605,
        'AIAF effective permissions verification failed.',
        1;
END;

PRINT 'AIAF effective permissions verification passed.';