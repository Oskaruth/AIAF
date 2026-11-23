/*  AI Interaction Audit Framework (AIAF)

    Independent integration test verification — version 2 (17 scenarios)

    Purpose:
        Verify persisted evidence against the expected
        outcomes of the live integration test suite.

    Requirements:
        SQL Server 2022 or later
        A deployed AIAF database
        An authorized audit verification identity

    Execute against the database used by the test runner.   */

USE [AIAF_IntegrationTest];
GO
SET NOCOUNT ON;

-- Change this identifier for each new Python integration run.
DECLARE @RunId UNIQUEIDENTIFIER = 'c0d82c26-e62c-4e49-9e16-955beab55dc1';

IF DB_NAME() <> N'AIAF_IntegrationTest'
    THROW 52501, 'Wrong database: independent verification requires AIAF_IntegrationTest.', 1;
IF @RunId IS NULL
    THROW 52502, 'Specify a non-null integration run ID.', 1;

DROP TABLE IF EXISTS #ExpectedResults;

CREATE TABLE #ExpectedResults
(   ScenarioCode                 VARCHAR(100) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY,
    InteractionStatus            VARCHAR(30)  COLLATE DATABASE_DEFAULT NOT NULL,
    CompletionReason             VARCHAR(100) COLLATE DATABASE_DEFAULT NOT NULL,
    GovernanceDecision           VARCHAR(20)  COLLATE DATABASE_DEFAULT NOT NULL,
    InputValidationRecords       INT          NOT NULL,
    InputDetections              INT          NOT NULL,
    ModelExecutions              INT          NOT NULL,
    ModelExecutionStatus         VARCHAR(30)  COLLATE DATABASE_DEFAULT NULL,
    ModelErrorCode               VARCHAR(100) COLLATE DATABASE_DEFAULT NULL,
    ModelToolRequests            INT          NOT NULL,
    ToolCode                     VARCHAR(100) COLLATE DATABASE_DEFAULT NULL,
    ToolCalls                    INT          NOT NULL,
    ToolAuthorizationDecision    VARCHAR(20)  COLLATE DATABASE_DEFAULT NULL,
    ToolAuthorizationReason      VARCHAR(100) COLLATE DATABASE_DEFAULT NULL,
    ToolExecutionStatus          VARCHAR(30)  COLLATE DATABASE_DEFAULT NULL,
    RowsReturned                 BIGINT       NULL,
    OutputValidationRecords      INT          NOT NULL,
    OutputDetections             INT          NOT NULL,
    LedgerEvents                 INT          NOT NULL      );

INSERT INTO #ExpectedResults
VALUES
(   'AUTHORIZED_CUSTOMER',
    'COMPLETED',
    'OUTPUT_APPROVED_FOR_RELEASE',
    'ALLOWED',
    3, 0,
    1, 'SUCCEEDED', NULL,
    1, 'GetCustomerBalance',
    1, 'ALLOWED', 'CUSTOMER_READ_AUTHORIZED',
    'SUCCEEDED', 1,
    5, 0, 8 ),
(   'UNRECOGNIZED_IDENTITY',
    'BLOCKED',
    'TOOL_AUTHORIZATION_DENIED',
    'ALLOWED',
    3, 0,
    1, 'SUCCEEDED', NULL,
    1, 'GetCustomerBalance',
    1, 'DENIED', 'CUSTOMER_ACCESS_DENIED',
    'NOT_EXECUTED', 0,
    0, 0, 7     ),
(   'UNAUTHORIZED_CUSTOMER',
    'BLOCKED',
    'TOOL_AUTHORIZATION_DENIED',
    'ALLOWED',
    3, 0,
    1, 'SUCCEEDED', NULL,
    1, 'GetCustomerBalance',
    1, 'DENIED', 'CUSTOMER_ACCESS_DENIED',
    'NOT_EXECUTED', 0,
    0, 0, 7     ),
(   'SENSITIVE_INPUT',
    'COMPLETED',
    'OUTPUT_APPROVED_FOR_RELEASE',
    'ALLOWED',
    3, 1,
    1, 'SUCCEEDED', NULL,
    1, 'GetCustomerBalance',
    1, 'ALLOWED', 'CUSTOMER_READ_AUTHORIZED',
    'SUCCEEDED', 1,
    5, 0, 8     ),
(   'UNSUPPORTED_REQUEST',
    'BLOCKED',
    'NO_SUPPORTED_TOOL',
    'ALLOWED',
    3, 0,
    1, 'SUCCEEDED', NULL,
    1, 'NO_SUPPORTED_TOOL',
    0, NULL, NULL,
    NULL, NULL,
    0, 0, 6     ),
(   'UNEXPECTED_COLUMN',
    'BLOCKED',
    'OUTPUT_VALIDATION_BLOCKED',
    'ALLOWED',
    3, 0,
    1, 'SUCCEEDED', NULL,
    1, 'GetCustomerBalance',
    1, 'ALLOWED', 'CUSTOMER_READ_AUTHORIZED',
    'SUCCEEDED', 1,
    5, 3, 8     ),
(   'INCORRECT_CUSTOMER',
    'BLOCKED',
    'OUTPUT_VALIDATION_BLOCKED',
    'ALLOWED',
    3, 0,
    1, 'SUCCEEDED', NULL,
    1, 'GetCustomerBalance',
    1, 'ALLOWED', 'CUSTOMER_READ_AUTHORIZED',
    'SUCCEEDED', 1,
    5, 1, 8     ),
(   'INVALID_FINANCIAL_BALANCE',
    'BLOCKED',
    'OUTPUT_VALIDATION_BLOCKED',
    'ALLOWED',
    3, 0,
    1, 'SUCCEEDED', NULL,
    1, 'GetCustomerBalance',
    1, 'ALLOWED', 'CUSTOMER_READ_AUTHORIZED',
    'SUCCEEDED', 1,
    5, 1, 8     ),
(   'MODEL_UNAVAILABLE',
    'FAILED',
    'MODEL_EXECUTION_FAILED',
    'ALLOWED',
    3, 0,
    1, 'FAILED', 'MODEL_CONNECTION_ERROR',
    0, NULL,
    0, NULL, NULL,
    NULL, NULL,
    0, 0, 5     ),
(   'GOVERNANCE_SUSPENSION',
    'BLOCKED',
    'GOVERNANCE_SUSPENDED',
    'DENIED',
    0, 0,
    0, NULL, NULL,
    0, NULL,
    0, NULL, NULL,
    NULL, NULL,
    0, 0, 2     ),
(   'AUDIT_WRITE_FAILURE',
    'FAILED', 'PROCESSING_EXCEPTION', 'ALLOWED',
    3, 0, 1, 'SUCCEEDED', NULL,
    1, 'GetCustomerBalance', 1, 'ALLOWED', 'CUSTOMER_READ_AUTHORIZED',
    'SUCCEEDED', 1, 0, 0, 7 ),
(   'EXPIRED_CUSTOMER_ACCESS',
    'BLOCKED', 'TOOL_AUTHORIZATION_DENIED', 'ALLOWED',
    3, 0, 1, 'SUCCEEDED', NULL,
    1, 'GetCustomerBalance', 1, 'DENIED', 'CUSTOMER_ACCESS_DENIED',
    'NOT_EXECUTED', 0, 0, 0, 7 ),
(   'MALFORMED_MODEL_JSON',
    'FAILED', 'MODEL_RESPONSE_INVALID', 'ALLOWED',
    3, 0, 1, 'SUCCEEDED', 'INVALID_MODEL_OUTPUT',
    0, NULL, 0, NULL, NULL, NULL, NULL, 0, 0, 5 ),
(   'UNSUPPORTED_MODEL_TOOL',
    'FAILED', 'MODEL_RESPONSE_INVALID', 'ALLOWED',
    3, 0, 1, 'SUCCEEDED', 'INVALID_MODEL_OUTPUT',
    0, NULL, 0, NULL, NULL, NULL, NULL, 0, 0, 5 ),
(   'MISSING_MODEL_ARGUMENT',
    'FAILED', 'MODEL_RESPONSE_INVALID', 'ALLOWED',
    3, 0, 1, 'SUCCEEDED', 'INVALID_MODEL_OUTPUT',
    0, NULL, 0, NULL, NULL, NULL, NULL, 0, 0, 5 ),
(   'PROMPT_INJECTION',
    'FAILED', 'MODEL_RESPONSE_INVALID', 'ALLOWED',
    3, 0, 1, 'SUCCEEDED', 'INVALID_MODEL_OUTPUT',
    0, NULL, 0, NULL, NULL, NULL, NULL, 0, 0, 5 ),
(   'PROMPT_INJECTION_AUTHORIZATION',
    'BLOCKED', 'TOOL_AUTHORIZATION_DENIED', 'ALLOWED',
    3, 0, 1, 'SUCCEEDED', NULL,
    1, 'GetCustomerBalance', 1, 'DENIED', 'CUSTOMER_ACCESS_DENIED',
    'NOT_EXECUTED', 0, 0, 0, 7 );

SELECT *
FROM #ExpectedResults
ORDER BY ScenarioCode;

SELECT
    COUNT(*) AS ExpectedScenarios,
    SUM(InputValidationRecords) AS InputValidationRecords,
    SUM(InputDetections) AS InputDetections,
    SUM(ModelExecutions) AS ModelExecutions,
    SUM(ModelToolRequests) AS ModelToolRequests,
    SUM(ToolCalls) AS ToolCalls,
    SUM(OutputValidationRecords) AS OutputValidationRecords,
    SUM(OutputDetections) AS OutputDetections,
    SUM(LedgerEvents) AS LedgerEvents
FROM #ExpectedResults;

/*
    Section B: Collect actual integration evidence
*/

DECLARE @RunPrefix VARCHAR(100);

SET @RunPrefix = CONCAT(
    'AIAF_INTEGRATION|',
    CONVERT(VARCHAR(36), @RunId),
    '|'
);

DROP TABLE IF EXISTS #RunInteractions;
DROP TABLE IF EXISTS #ActualResults;

SELECT
    I.InteractionId,
    SUBSTRING(
        I.BusinessPurpose,
        LEN(@RunPrefix) + 1,
        2000
    ) AS ScenarioCode,
    A.ApplicationCode,
    I.RequestingIdentity,
    I.InteractionStatus,
    I.CorrelationId,
    I.InteractionAt,
    I.CompletedAt
INTO #RunInteractions
FROM aiaf.AIInteraction AS I
LEFT JOIN aiaf.AIApplication AS A
    ON A.ApplicationId = I.ApplicationId
WHERE @RunId IS NOT NULL
    AND LEFT(
        I.BusinessPurpose,
        LEN(@RunPrefix)
    ) = @RunPrefix;


CREATE UNIQUE CLUSTERED INDEX IX_RunInteractions
    ON #RunInteractions (InteractionId);


SELECT
    I.ScenarioCode,
    I.InteractionId,
    I.ApplicationCode,
    I.RequestingIdentity,
    I.InteractionStatus,

    COALESCE(
        F.CompletionReason,
        CASE
            WHEN G.GovernanceDecision = 'DENIED'
                THEN G.GateReason
        END
    ) AS CompletionReason,

    G.GovernanceDecision,

    V.InputValidationRecords,
    V.InputDetections,

    M.ModelExecutions,
    M.ModelExecutionStatus,
    M.ModelErrorCode,

    P.ModelToolRequests,
    P.ToolCode,

    T.ToolCalls,
    T.ToolAuthorizationDecision,
    T.ToolAuthorizationReason,
    T.ToolExecutionStatus,
    T.RowsReturned,

    V.OutputValidationRecords,
    V.OutputDetections,

    E.LedgerEvents,

    -- Additional verification evidence
    M.ModelResponseValidationDecision,
    M.InputTokens,
    M.OutputTokens,
    M.TotalCost,
    M.CostBasis,

    P.RequestArguments,

    V.InputRulesPassed,
    V.InputRulesSanitized,
    V.InputRulesBlocked,
    V.OutputRulesPassed,
    V.OutputRulesBlocked,
    V.PersistedContentRecords,

    G.GovernanceGateEvents,
    F.FinalizationEvents,
    F.ResponseDeliveryConfirmed,

    I.CorrelationId,
    I.InteractionAt,
    I.CompletedAt,

    DATEDIFF_BIG(
        MILLISECOND,
        I.InteractionAt,
        I.CompletedAt
    ) AS InteractionDurationMs

INTO #ActualResults
FROM #RunInteractions AS I

OUTER APPLY
(
    SELECT
        COUNT(
            CASE WHEN V.ValidationStage = 'INPUT'
                THEN 1 END
        ) AS InputValidationRecords,

        COALESCE(SUM(
            CASE WHEN V.ValidationStage = 'INPUT'
                THEN V.DetectionCount ELSE 0 END
        ), 0) AS InputDetections,

        COUNT(
            CASE WHEN V.ValidationStage = 'OUTPUT'
                THEN 1 END
        ) AS OutputValidationRecords,

        COALESCE(SUM(
            CASE WHEN V.ValidationStage = 'OUTPUT'
                THEN V.DetectionCount ELSE 0 END
        ), 0) AS OutputDetections,

        COUNT(
            CASE WHEN V.ValidationStage = 'INPUT'
                AND V.ValidationDecision = 'PASSED'
                THEN 1 END
        ) AS InputRulesPassed,

        COUNT(
            CASE WHEN V.ValidationStage = 'INPUT'
                AND V.ValidationDecision = 'SANITIZED'
                THEN 1 END
        ) AS InputRulesSanitized,

        COUNT(
            CASE WHEN V.ValidationStage = 'INPUT'
                AND V.ValidationDecision = 'BLOCKED'
                THEN 1 END
        ) AS InputRulesBlocked,

        COUNT(
            CASE WHEN V.ValidationStage = 'OUTPUT'
                AND V.ValidationDecision = 'PASSED'
                THEN 1 END
        ) AS OutputRulesPassed,

        COUNT(
            CASE WHEN V.ValidationStage = 'OUTPUT'
                AND V.ValidationDecision = 'BLOCKED'
                THEN 1 END
        ) AS OutputRulesBlocked,

        COUNT(
            CASE WHEN V.SanitizedContent IS NOT NULL
                THEN 1 END
        ) AS PersistedContentRecords

    FROM aiaf.AIValidation AS V
    WHERE V.InteractionId = I.InteractionId
) AS V

OUTER APPLY
(
    SELECT
        COUNT(*) AS ModelExecutions,
        MAX(M.ExecutionStatus) AS ModelExecutionStatus,
        MAX(M.ErrorCode) AS ModelErrorCode,

        MAX(M.ResponseValidationDecision)
            AS ModelResponseValidationDecision,

        MAX(M.InputTokens) AS InputTokens,
        MAX(M.OutputTokens) AS OutputTokens,
        MAX(M.TotalCost) AS TotalCost,
        MAX(M.CostBasis) AS CostBasis

    FROM aiaf.AIModelExecution AS M
    WHERE M.InteractionId = I.InteractionId
) AS M

OUTER APPLY
(
    SELECT
        COUNT(*) AS ModelToolRequests,
        MAX(P.ToolCode) AS ToolCode,
        MAX(P.RequestArguments) AS RequestArguments

    FROM aiaf.AIModelToolRequest AS P
    INNER JOIN aiaf.AIModelExecution AS M
        ON M.ModelExecutionId = P.ModelExecutionId
    WHERE M.InteractionId = I.InteractionId
) AS P

OUTER APPLY
(
    SELECT
        COUNT(*) AS ToolCalls,

        MAX(T.AuthorizationDecision)
            AS ToolAuthorizationDecision,

        MAX(T.AuthorizationReason)
            AS ToolAuthorizationReason,

        MAX(T.ExecutionStatus)
            AS ToolExecutionStatus,

        MAX(T.RowsReturned) AS RowsReturned

    FROM aiaf.AIToolCall AS T
    WHERE T.InteractionId = I.InteractionId
) AS T

OUTER APPLY
(
    SELECT
        COUNT(*) AS GovernanceGateEvents,

        MAX(JSON_VALUE(
            E.EventDetails,
            '$.GateDecision'
        )) AS GovernanceDecision,

        MAX(JSON_VALUE(
            E.EventDetails,
            '$.GateReason'
        )) AS GateReason

    FROM aiaf.AIInteractionEvent AS E
    WHERE E.InteractionId = I.InteractionId
        AND E.EventCode = 'GOVERNANCE_GATE_EVALUATED'
) AS G

OUTER APPLY
(
    SELECT
        COUNT(*) AS FinalizationEvents,

        MAX(JSON_VALUE(
            E.EventDetails,
            '$.CompletionReason'
        )) AS CompletionReason,

        MAX(JSON_VALUE(
            E.EventDetails,
            '$.ResponseDeliveryConfirmed'
        )) AS ResponseDeliveryConfirmed

    FROM aiaf.AIInteractionEvent AS E
    WHERE E.InteractionId = I.InteractionId
        AND E.EventCode = 'INTERACTION_FINALIZED'
) AS F

OUTER APPLY
(
    SELECT
        COUNT(*) AS LedgerEvents

    FROM aiaf.AIInteractionEvent AS E
    WHERE E.InteractionId = I.InteractionId
) AS E;


/*
    Actual scenario evidence
*/

SELECT *
FROM #ActualResults
ORDER BY ScenarioCode, InteractionId;


/*
    Actual aggregate evidence
*/

SELECT
    @RunId AS RunId,
    COUNT(*) AS ActualInteractions,
    COUNT(DISTINCT ScenarioCode) AS ActualScenarios,

    COALESCE(SUM(InputValidationRecords), 0)
        AS InputValidationRecords,

    COALESCE(SUM(InputDetections), 0)
        AS InputDetections,

    COALESCE(SUM(ModelExecutions), 0)
        AS ModelExecutions,

    COALESCE(SUM(ModelToolRequests), 0)
        AS ModelToolRequests,

    COALESCE(SUM(ToolCalls), 0)
        AS ToolCalls,

    COALESCE(SUM(OutputValidationRecords), 0)
        AS OutputValidationRecords,

    COALESCE(SUM(OutputDetections), 0)
        AS OutputDetections,

    COALESCE(SUM(LedgerEvents), 0)
        AS LedgerEvents,

    COALESCE(SUM(PersistedContentRecords), 0)
        AS PersistedContentRecords

FROM #ActualResults;


/*
    Scenario coverage
*/

SELECT
    COALESCE(E.ScenarioCode, A.ScenarioCode)
        AS ScenarioCode,

    CASE WHEN E.ScenarioCode IS NULL
        THEN 0 ELSE 1
    END AS ExpectedInteractions,

    COUNT(A.InteractionId) AS ActualInteractions,

    CASE
        WHEN E.ScenarioCode IS NULL
            THEN 'UNEXPECTED'
        WHEN COUNT(A.InteractionId) = 0
            THEN 'MISSING'
        WHEN COUNT(A.InteractionId) > 1
            THEN 'DUPLICATE'
        ELSE 'PRESENT'
    END AS CoverageStatus

FROM #ExpectedResults AS E
FULL OUTER JOIN #ActualResults AS A
    ON A.ScenarioCode = E.ScenarioCode

GROUP BY
    E.ScenarioCode,
    A.ScenarioCode

ORDER BY ScenarioCode;

/*
    Section C: Automated evidence verification
*/

DROP TABLE IF EXISTS #VerificationFailures;

CREATE TABLE #VerificationFailures
(
    VerificationFailureId INT IDENTITY(1,1) PRIMARY KEY,
    ScenarioCode VARCHAR(2000)
        COLLATE DATABASE_DEFAULT NOT NULL,
    InteractionId BIGINT NULL,
    AssertionCode VARCHAR(100)
        COLLATE DATABASE_DEFAULT NOT NULL,
    ExpectedValue NVARCHAR(4000)
        COLLATE DATABASE_DEFAULT NULL,
    ActualValue NVARCHAR(4000)
        COLLATE DATABASE_DEFAULT NULL
);

/*
    C.1: Scenario coverage
*/

INSERT INTO #VerificationFailures
(
    ScenarioCode,
    InteractionId,
    AssertionCode,
    ExpectedValue,
    ActualValue
)
SELECT
    E.ScenarioCode,
    NULL,
    'SCENARIO_INTERACTION_COUNT',
    '1',
    CONVERT(NVARCHAR(20), COUNT(A.InteractionId))
FROM #ExpectedResults AS E
LEFT JOIN #ActualResults AS A
    ON A.ScenarioCode = E.ScenarioCode
GROUP BY E.ScenarioCode
HAVING COUNT(A.InteractionId) <> 1;


INSERT INTO #VerificationFailures
(
    ScenarioCode,
    InteractionId,
    AssertionCode,
    ExpectedValue,
    ActualValue
)
SELECT
    A.ScenarioCode,
    A.InteractionId,
    'UNEXPECTED_SCENARIO',
    'DEFINED_SCENARIO',
    'UNDEFINED_SCENARIO'
FROM #ActualResults AS A
WHERE NOT EXISTS
(
    SELECT 1
    FROM #ExpectedResults AS E
    WHERE E.ScenarioCode = A.ScenarioCode
);

INSERT INTO #VerificationFailures
(ScenarioCode, InteractionId, AssertionCode, ExpectedValue, ActualValue)
SELECT 'RUN_TOTAL', NULL, 'TOTAL_INTERACTIONS', '17', CONVERT(NVARCHAR(20),COUNT(*))
FROM #RunInteractions
HAVING COUNT(*) <> 17;

/*
    C.2: Core evidence assertions
*/

INSERT INTO #VerificationFailures
(
    ScenarioCode,
    InteractionId,
    AssertionCode,
    ExpectedValue,
    ActualValue
)
SELECT
    E.ScenarioCode,
    A.InteractionId,
    C.AssertionCode,
    C.ExpectedValue,
    C.ActualValue
FROM #ExpectedResults AS E
INNER JOIN #ActualResults AS A
    ON A.ScenarioCode = E.ScenarioCode
CROSS APPLY
(
    VALUES
    ('INTERACTION_STATUS',
        E.InteractionStatus,
        A.InteractionStatus),

    ('COMPLETION_REASON',
        E.CompletionReason,
        A.CompletionReason),

    ('GOVERNANCE_DECISION',
        E.GovernanceDecision,
        A.GovernanceDecision),

    ('INPUT_VALIDATION_COUNT',
        CONVERT(NVARCHAR(20), E.InputValidationRecords),
        CONVERT(NVARCHAR(20), A.InputValidationRecords)),

    ('INPUT_DETECTIONS',
        CONVERT(NVARCHAR(20), E.InputDetections),
        CONVERT(NVARCHAR(20), A.InputDetections)),

    ('MODEL_EXECUTION_COUNT',
        CONVERT(NVARCHAR(20), E.ModelExecutions),
        CONVERT(NVARCHAR(20), A.ModelExecutions)),

    ('MODEL_EXECUTION_STATUS',
        E.ModelExecutionStatus,
        A.ModelExecutionStatus),

    ('MODEL_ERROR_CODE',
        E.ModelErrorCode,
        A.ModelErrorCode),

    ('MODEL_TOOL_REQUEST_COUNT',
        CONVERT(NVARCHAR(20), E.ModelToolRequests),
        CONVERT(NVARCHAR(20), A.ModelToolRequests)),

    ('TOOL_CODE',
        E.ToolCode,
        A.ToolCode),

    ('TOOL_CALL_COUNT',
        CONVERT(NVARCHAR(20), E.ToolCalls),
        CONVERT(NVARCHAR(20), A.ToolCalls)),

    ('TOOL_AUTHORIZATION_DECISION',
        E.ToolAuthorizationDecision,
        A.ToolAuthorizationDecision),

    ('TOOL_AUTHORIZATION_REASON',
        E.ToolAuthorizationReason,
        A.ToolAuthorizationReason),

    ('TOOL_EXECUTION_STATUS',
        E.ToolExecutionStatus,
        A.ToolExecutionStatus),

    ('ROWS_RETURNED',
        CONVERT(NVARCHAR(20), E.RowsReturned),
        CONVERT(NVARCHAR(20), A.RowsReturned)),

    ('OUTPUT_VALIDATION_COUNT',
        CONVERT(NVARCHAR(20), E.OutputValidationRecords),
        CONVERT(NVARCHAR(20), A.OutputValidationRecords)),

    ('OUTPUT_DETECTIONS',
        CONVERT(NVARCHAR(20), E.OutputDetections),
        CONVERT(NVARCHAR(20), A.OutputDetections)),

    ('LEDGER_EVENT_COUNT',
        CONVERT(NVARCHAR(20), E.LedgerEvents),
        CONVERT(NVARCHAR(20), A.LedgerEvents))

) AS C
(
    AssertionCode,
    ExpectedValue,
    ActualValue
)
WHERE C.ExpectedValue IS DISTINCT FROM C.ActualValue;

/*
    C.2a: Explicit fail-closed checks, independent of the expected matrix.
    A denied tool must never report execution or return data.
*/
INSERT INTO #VerificationFailures
(ScenarioCode, InteractionId, AssertionCode, ExpectedValue, ActualValue)
SELECT A.ScenarioCode, A.InteractionId,
       'DENIED_TOOL_MUST_NOT_EXECUTE',
       'NOT_EXECUTED; RowsReturned=0',
       CONCAT(COALESCE(A.ToolExecutionStatus,'NULL'),
              '; RowsReturned=', COALESCE(CONVERT(VARCHAR(30),A.RowsReturned),'NULL'))
FROM #ActualResults AS A
WHERE A.ToolAuthorizationDecision = 'DENIED'
  AND (A.ToolExecutionStatus IS DISTINCT FROM 'NOT_EXECUTED'
       OR A.RowsReturned IS DISTINCT FROM CONVERT(BIGINT,0));

/* Governance denial must prevent downstream model/tool execution. */
INSERT INTO #VerificationFailures
(ScenarioCode, InteractionId, AssertionCode, ExpectedValue, ActualValue)
SELECT A.ScenarioCode, A.InteractionId,
       'GOVERNANCE_DENIAL_MUST_SHORT_CIRCUIT',
       'ModelExecutions=0; ModelToolRequests=0; ToolCalls=0',
       CONCAT('ModelExecutions=', A.ModelExecutions,
              '; ModelToolRequests=', A.ModelToolRequests,
              '; ToolCalls=', A.ToolCalls)
FROM #ActualResults AS A
WHERE A.GovernanceDecision = 'DENIED'
  AND (A.ModelExecutions <> 0 OR A.ModelToolRequests <> 0 OR A.ToolCalls <> 0);

/*
    C.3: Additional security evidence
*/

INSERT INTO #VerificationFailures
(
    ScenarioCode,
    InteractionId,
    AssertionCode,
    ExpectedValue,
    ActualValue
)
SELECT
    E.ScenarioCode,
    A.InteractionId,
    C.AssertionCode,
    C.ExpectedValue,
    C.ActualValue

FROM #ExpectedResults AS E

INNER JOIN #ActualResults AS A
    ON A.ScenarioCode = E.ScenarioCode

CROSS APPLY
(
    VALUES
    (
        'APPLICATION_CODE',
        CONVERT(NVARCHAR(4000),
            CASE
                WHEN E.ScenarioCode = 'GOVERNANCE_SUSPENSION'
                    THEN 'ACME_CUSTOMER_SERVICE_AI'
                ELSE 'AIAF_APPROVED_TEST'
            END
        ),
        CONVERT(NVARCHAR(4000), A.ApplicationCode)
    ),
    (
        'REQUESTING_IDENTITY',
        CASE
            WHEN E.ScenarioCode = 'UNRECOGNIZED_IDENTITY'
                THEN 'Jeannine'
            WHEN E.ScenarioCode IN ('UNAUTHORIZED_CUSTOMER', 'PROMPT_INJECTION', 'PROMPT_INJECTION_AUTHORIZATION')
                THEN 'aiaf-unauthorized-test-user'
            WHEN E.ScenarioCode = 'EXPIRED_CUSTOMER_ACCESS'
                THEN 'aiaf-expired-test-user'
            ELSE 'aiaf-functional-test-user'
        END,
        A.RequestingIdentity
    ),
    (
        'MODEL_RESPONSE_VALIDATION',
        CASE
            WHEN E.ModelExecutions = 0
                THEN NULL
            WHEN E.ScenarioCode = 'MODEL_UNAVAILABLE'
                THEN 'NOT_EVALUATED'
            WHEN E.ScenarioCode IN (
                'MALFORMED_MODEL_JSON', 'UNSUPPORTED_MODEL_TOOL',
                'MISSING_MODEL_ARGUMENT', 'PROMPT_INJECTION')
                THEN 'FAILED'
            ELSE 'PASSED'
        END,
        A.ModelResponseValidationDecision
    ),
    (
        'INPUT_RULES_PASSED',
        CONVERT(NVARCHAR(20),
            E.InputValidationRecords - E.InputDetections
        ),
        CONVERT(NVARCHAR(20), A.InputRulesPassed)
    ),
    (
        'INPUT_RULES_SANITIZED',
        CONVERT(NVARCHAR(20), E.InputDetections),
        CONVERT(NVARCHAR(20), A.InputRulesSanitized)
    ),
    (
        'INPUT_RULES_BLOCKED',
        '0',
        CONVERT(NVARCHAR(20), A.InputRulesBlocked)
    ),
    (
        'OUTPUT_RULES_PASSED',
        CONVERT(NVARCHAR(20),
            E.OutputValidationRecords - E.OutputDetections
        ),
        CONVERT(NVARCHAR(20), A.OutputRulesPassed)
    ),
    (
        'OUTPUT_RULES_BLOCKED',
        CONVERT(NVARCHAR(20), E.OutputDetections),
        CONVERT(NVARCHAR(20), A.OutputRulesBlocked)
    ),
    (
        'GOVERNANCE_GATE_EVENT_COUNT',
        '1',
        CONVERT(NVARCHAR(20), A.GovernanceGateEvents)
    ),
    (
        'FINALIZATION_EVENT_COUNT',
        CASE
            WHEN E.ScenarioCode = 'GOVERNANCE_SUSPENSION'
                THEN '0'
            ELSE '1'
        END,
        CONVERT(NVARCHAR(20), A.FinalizationEvents)
    ),
    (
        'RESPONSE_DELIVERY_CONFIRMED',
        CASE
            WHEN E.ScenarioCode = 'GOVERNANCE_SUSPENSION'
                THEN NULL
            ELSE 'false'
        END,
        A.ResponseDeliveryConfirmed
    ),
    (
        'PERSISTED_VALIDATION_CONTENT',
        '0',
        CONVERT(NVARCHAR(20), A.PersistedContentRecords)
    ),
    (
        'MODEL_REQUEST_CUSTOMER',
        CASE
            WHEN E.ModelToolRequests = 0
                THEN NULL
            WHEN E.ScenarioCode = 'UNSUPPORTED_REQUEST'
                THEN ''
            ELSE 'CUST-0001'
        END,
        JSON_VALUE(A.RequestArguments, '$.CustomerCode')
    ),
    (
        'CORRELATION_ID_PRESENT',
        '1',
        CASE
            WHEN NULLIF(TRIM(A.CorrelationId), '') IS NULL
                THEN '0'
            ELSE '1'
        END
    ),
    (
        'TERMINAL_TIMESTAMP_PRESENT',
        '1',
        CASE
            WHEN A.CompletedAt IS NULL THEN '0'
            ELSE '1'
        END
    ),
    (
        'INTERACTION_TIMESTAMP_ORDER',
        '1',
        CASE
            WHEN A.CompletedAt >= A.InteractionAt THEN '1'
            ELSE '0'
        END
    )
) AS C
(
    AssertionCode,
    ExpectedValue,
    ActualValue
)

WHERE C.ExpectedValue IS DISTINCT FROM C.ActualValue;

/*
    C.4: Individual validation rule assertions
*/

DROP TABLE IF EXISTS #ExpectedValidationRules;

CREATE TABLE #ExpectedValidationRules
(
    ScenarioCode VARCHAR(100)
        COLLATE DATABASE_DEFAULT NOT NULL,

    ValidationStage VARCHAR(20)
        COLLATE DATABASE_DEFAULT NOT NULL,

    RuleCode VARCHAR(100)
        COLLATE DATABASE_DEFAULT NOT NULL,

    RuleVersion INT NOT NULL,

    ValidationDecision VARCHAR(20)
        COLLATE DATABASE_DEFAULT NOT NULL,

    DetectionCount INT NOT NULL,

    PRIMARY KEY
    (
        ScenarioCode,
        ValidationStage,
        RuleCode
    )
);


/*
    Expected input rules
*/

INSERT INTO #ExpectedValidationRules
SELECT
    E.ScenarioCode,
    'INPUT',
    R.RuleCode,
    1,

    CASE
        WHEN E.ScenarioCode = 'SENSITIVE_INPUT'
            AND R.RuleCode = 'US_SSN_PATTERN'
            THEN 'SANITIZED'
        ELSE 'PASSED'
    END,

    CASE
        WHEN E.ScenarioCode = 'SENSITIVE_INPUT'
            AND R.RuleCode = 'US_SSN_PATTERN'
            THEN 1
        ELSE 0
    END

FROM #ExpectedResults AS E

CROSS JOIN
(
    VALUES
        ('US_SSN_PATTERN'),
        ('PAYMENT_CARD_PATTERN'),
        ('EMAIL_ADDRESS_PATTERN')
) AS R (RuleCode)

WHERE E.InputValidationRecords > 0;


/*
    Expected output rules
*/

INSERT INTO #ExpectedValidationRules
SELECT
    E.ScenarioCode,
    'OUTPUT',
    R.RuleCode,
    1,

    CASE WHEN F.IsBlocked = 1
        THEN 'BLOCKED'
        ELSE 'PASSED'
    END,

    F.IsBlocked

FROM #ExpectedResults AS E

CROSS JOIN
(
    VALUES
        ('OUTPUT_AUTHORIZATION'),
        ('OUTPUT_ROW_COUNT'),
        ('OUTPUT_SCHEMA'),
        ('OUTPUT_FINANCIAL_INTEGRITY'),
        ('OUTPUT_CUSTOMER_BINDING')
) AS R (RuleCode)

CROSS APPLY
(
    SELECT
        CASE
            WHEN E.ScenarioCode = 'UNEXPECTED_COLUMN'
                AND R.RuleCode IN
                (
                    'OUTPUT_SCHEMA',
                    'OUTPUT_FINANCIAL_INTEGRITY',
                    'OUTPUT_CUSTOMER_BINDING'
                )
                THEN 1

            WHEN E.ScenarioCode = 'INCORRECT_CUSTOMER'
                AND R.RuleCode = 'OUTPUT_CUSTOMER_BINDING'
                THEN 1

            WHEN E.ScenarioCode = 'INVALID_FINANCIAL_BALANCE'
                AND R.RuleCode = 'OUTPUT_FINANCIAL_INTEGRITY'
                THEN 1

            ELSE 0
        END AS IsBlocked
) AS F

WHERE E.OutputValidationRecords > 0;


/*
    Missing, duplicate or incorrect rule evidence
*/

INSERT INTO #VerificationFailures
(
    ScenarioCode,
    InteractionId,
    AssertionCode,
    ExpectedValue,
    ActualValue
)
SELECT
    R.ScenarioCode,
    A.InteractionId,

    CONCAT(
        'VALIDATION_RULE:',
        R.ValidationStage,
        ':',
        R.RuleCode
    ),

    CONCAT(
        'Count=1; Version=', R.RuleVersion,
        '; Decision=', R.ValidationDecision,
        '; Detections=', R.DetectionCount
    ),

    CONCAT(
        'Count=', V.RuleCount,
        '; Version=', V.RuleVersion,
        '; Decision=', V.ValidationDecision,
        '; Detections=', V.DetectionCount
    )

FROM #ExpectedValidationRules AS R

INNER JOIN #ActualResults AS A
    ON A.ScenarioCode = R.ScenarioCode

OUTER APPLY
(
    SELECT
        COUNT(*) AS RuleCount,
        MAX(V.RuleVersion) AS RuleVersion,
        MAX(V.ValidationDecision) AS ValidationDecision,
        MAX(V.DetectionCount) AS DetectionCount

    FROM aiaf.AIValidation AS V

    WHERE V.InteractionId = A.InteractionId
        AND V.ValidationStage = R.ValidationStage
        AND V.RuleCode = R.RuleCode
) AS V

WHERE V.RuleCount <> 1
    OR V.RuleVersion IS DISTINCT FROM R.RuleVersion
    OR V.ValidationDecision
        IS DISTINCT FROM R.ValidationDecision
    OR V.DetectionCount
        IS DISTINCT FROM R.DetectionCount;


/*
    Unexpected validation rules
*/

INSERT INTO #VerificationFailures
(
    ScenarioCode,
    InteractionId,
    AssertionCode,
    ExpectedValue,
    ActualValue
)
SELECT
    A.ScenarioCode,
    A.InteractionId,
    'UNEXPECTED_VALIDATION_RULE',
    'DEFINED_RULE',
    CONCAT(V.ValidationStage, ':', V.RuleCode)

FROM #ActualResults AS A

INNER JOIN aiaf.AIValidation AS V
    ON V.InteractionId = A.InteractionId

WHERE NOT EXISTS
(
    SELECT 1
    FROM #ExpectedValidationRules AS R

    WHERE R.ScenarioCode = A.ScenarioCode
        AND R.ValidationStage = V.ValidationStage
        AND R.RuleCode = V.RuleCode
);


/*
    Expected validation rule inventory
*/

SELECT
    ValidationStage,
    ValidationDecision,
    COUNT(*) AS ExpectedRules,
    SUM(DetectionCount) AS ExpectedDetections

FROM #ExpectedValidationRules

GROUP BY
    ValidationStage,
    ValidationDecision

ORDER BY
    ValidationStage,
    ValidationDecision;

/*
    C.5: Model execution telemetry assertions
*/

INSERT INTO #VerificationFailures
(
    ScenarioCode,
    InteractionId,
    AssertionCode,
    ExpectedValue,
    ActualValue
)
SELECT
    A.ScenarioCode,
    A.InteractionId,
    C.AssertionCode,
    C.ExpectedValue,
    C.ActualValue

FROM #ActualResults AS A

INNER JOIN aiaf.AIModelExecution AS M
    ON M.InteractionId = A.InteractionId

CROSS APPLY
(
    VALUES
    (
        'MODEL_EXECUTION_ENVIRONMENT',
        'TEST',
        M.ExecutionEnvironment
    ),
    (
        'MODEL_TELEMETRY_SOURCE',
        'LIVE',
        M.TelemetrySource
    ),
    (
        'MODEL_EXECUTION_PURPOSE',
        'TOOL_SELECTION',
        M.ExecutionPurpose
    ),
    (
        'MODEL_PROVIDER',
        'OLLAMA',
        M.ModelProvider
    ),
    (
        'MODEL_PROMPT_VERSION',
        '2',
        CONVERT(VARCHAR(20), M.PromptVersion)
    ),
    (
        'MODEL_DURATION_VALID',
        '1',
        CASE
            WHEN M.DurationMs >= 0 THEN '1'
            ELSE '0'
        END
    ),
    (
        'MODEL_TIMESTAMP_ORDER',
        '1',
        CASE
            WHEN M.CompletedAt >= M.StartedAt THEN '1'
            ELSE '0'
        END
    ),
    (
        'MODEL_COST_BASIS',
        'UNAVAILABLE',
        M.CostBasis
    ),
    (
        'MODEL_COST_UNAVAILABLE',
        '1',
        CASE
            WHEN M.InputCost IS NULL
                AND M.OutputCost IS NULL
                AND M.OtherCost IS NULL
                AND M.TotalCost IS NULL
                AND M.CurrencyCode IS NULL
                THEN '1'
            ELSE '0'
        END
    ),
    (
        'MODEL_TOKEN_TELEMETRY_VALID',
        '1',
        CASE
            WHEN A.ScenarioCode = 'MODEL_UNAVAILABLE'
                AND M.InputTokens IS NULL
                AND M.OutputTokens IS NULL
                AND M.CachedInputTokens IS NULL
                THEN '1'

            WHEN A.ScenarioCode <> 'MODEL_UNAVAILABLE'
                AND M.InputTokens >= 0
                AND M.OutputTokens > 0
                THEN '1'

            ELSE '0'
        END
    )
) AS C
(
    AssertionCode,
    ExpectedValue,
    ActualValue
)

WHERE C.ExpectedValue IS DISTINCT FROM C.ActualValue;

/*
    C.6: Ledger event sequence assertions
*/

DROP TABLE IF EXISTS #ExpectedLedgerSequences;

CREATE TABLE #ExpectedLedgerSequences
(
    ScenarioCode VARCHAR(100)
        COLLATE DATABASE_DEFAULT PRIMARY KEY,

    EventSequence NVARCHAR(2000)
        COLLATE DATABASE_DEFAULT NOT NULL
);

INSERT INTO #ExpectedLedgerSequences
SELECT
    E.ScenarioCode,

    CONCAT(
        'INTERACTION_RECEIVED',
        '|GOVERNANCE_GATE_EVALUATED',

        CASE WHEN E.InputValidationRecords > 0
            THEN '|INPUT_VALIDATED'
            ELSE ''
        END,

        CASE WHEN E.ModelExecutions > 0
            THEN '|MODEL_EXECUTION_RECORDED'
            ELSE ''
        END,

        CASE WHEN E.ModelToolRequests > 0
            THEN '|MODEL_TOOL_REQUEST_RECORDED'
            ELSE ''
        END,

        CASE WHEN E.ToolCalls > 0
            THEN '|TOOL_CALL_EVALUATED'
            ELSE ''
        END,

        CASE WHEN E.OutputValidationRecords > 0
            THEN '|OUTPUT_VALIDATED'
            ELSE ''
        END,

        CASE
            WHEN E.ScenarioCode <> 'GOVERNANCE_SUSPENSION'
                THEN '|INTERACTION_FINALIZED'
            ELSE ''
        END
    )

FROM #ExpectedResults AS E;


INSERT INTO #VerificationFailures
(
    ScenarioCode,
    InteractionId,
    AssertionCode,
    ExpectedValue,
    ActualValue
)
SELECT
    A.ScenarioCode,
    A.InteractionId,
    'LEDGER_EVENT_SEQUENCE',
    E.EventSequence,
    L.EventSequence

FROM #ActualResults AS A

INNER JOIN #ExpectedLedgerSequences AS E
    ON E.ScenarioCode = A.ScenarioCode

OUTER APPLY
(
    SELECT
        STRING_AGG(
            CONVERT(NVARCHAR(MAX), L.EventCode),
            '|'
        ) WITHIN GROUP
        (
            ORDER BY L.InteractionEventId
        ) AS EventSequence

    FROM aiaf.AIInteractionEvent AS L
    WHERE L.InteractionId = A.InteractionId
) AS L

WHERE E.EventSequence IS DISTINCT FROM L.EventSequence;

/*
    C.7: Targeted sensitive payload assertions
*/

INSERT INTO #VerificationFailures
(
    ScenarioCode,
    InteractionId,
    AssertionCode,
    ExpectedValue,
    ActualValue
)
SELECT DISTINCT
    A.ScenarioCode,
    A.InteractionId,
    CONCAT('LEDGER_PAYLOAD_LEAK:', P.PayloadCode),
    'NOT_PRESENT',
    'PRESENT'

FROM #ActualResults AS A

INNER JOIN aiaf.AIInteractionEvent AS E
    ON E.InteractionId = A.InteractionId

CROSS JOIN
(
    VALUES
        ('SYNTHETIC_SSN', '123-45-6789'),
        ('CUSTOMER_NAME_FIELD', '"CustomerName"'),
        ('OUTSTANDING_BALANCE_FIELD', '"OutstandingBalance"'),
        ('DISPUTED_BALANCE_FIELD', '"DisputedBalance"'),
        ('OPEN_INVOICE_COUNT_FIELD', '"OpenInvoiceCount"'),
        ('DISPUTED_INVOICE_COUNT_FIELD', '"DisputedInvoiceCount"'),
        ('SYNTHETIC_CUSTOMER_NAME', 'AIAF Functional Test Customer'),
        ('DDL_REQUEST', 'DROP TABLE acme.Customer')
) AS P
(
    PayloadCode,
    PayloadValue
)

WHERE CHARINDEX(
    P.PayloadValue,
    E.EventDetails
) > 0;

/*
    Section D: Final verification results
*/

SELECT
    ScenarioCode,
    InteractionId,
    AssertionCode,
    ExpectedValue,
    ActualValue

FROM #VerificationFailures

ORDER BY
    ScenarioCode,
    AssertionCode,
    InteractionId;


/*
    Individual scenario results
*/

SELECT
    E.ScenarioCode,

    (
        SELECT COUNT(*)
        FROM #ActualResults AS A
        WHERE A.ScenarioCode = E.ScenarioCode
    ) AS ActualInteractions,

    F.FailureCount,

    CASE
        WHEN F.FailureCount = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS VerificationStatus

FROM #ExpectedResults AS E

OUTER APPLY
(
    SELECT COUNT(*) AS FailureCount

    FROM #VerificationFailures AS F
    WHERE F.ScenarioCode = E.ScenarioCode
) AS F

ORDER BY E.ScenarioCode;


/*
    Overall verification result
*/

DECLARE @VerificationFailures INT;
DECLARE @ExpectedScenarios INT;
DECLARE @PassedScenarios INT;

SELECT @VerificationFailures = COUNT(*)
FROM #VerificationFailures;

SELECT @ExpectedScenarios = COUNT(*)
FROM #ExpectedResults;

SELECT @PassedScenarios = COUNT(*)
FROM #ExpectedResults AS E
WHERE NOT EXISTS
(
    SELECT 1
    FROM #VerificationFailures AS F
    WHERE F.ScenarioCode = E.ScenarioCode
);

SELECT
    @RunId AS RunId,
    DB_NAME() AS DatabaseName,
    SYSUTCDATETIME() AS VerifiedAtUtc,
    @ExpectedScenarios AS ExpectedScenarios,
    @PassedScenarios AS PassedScenarios,
    @ExpectedScenarios - @PassedScenarios AS FailedScenarios,
    @VerificationFailures AS VerificationFailures,

    CASE
        WHEN @RunId IS NOT NULL
            AND @ExpectedScenarios = 17
            AND @VerificationFailures = 0
            AND @PassedScenarios = @ExpectedScenarios
            THEN 'PASS'
        ELSE 'FAIL'
    END AS VerificationStatus;


/*
    Fail explicitly for automation and CI/CD.
*/

IF @RunId IS NULL OR @ExpectedScenarios <> 17 OR @VerificationFailures > 0
    OR @PassedScenarios <> @ExpectedScenarios
BEGIN
    THROW 52500,
        'AIAF independent integration verification failed.',
        1;
END;

PRINT 'AIAF independent integration verification PASSED.';