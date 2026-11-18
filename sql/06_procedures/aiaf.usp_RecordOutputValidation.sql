SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE aiaf.usp_RecordOutputValidation
    @InteractionId bigint,
    @AIToolCallId bigint,
    @Findings nvarchar(max)
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @@TRANCOUNT <> 0
        THROW 52000,
            'Caller-owned transactions are not supported.', 1;

    IF ISNULL(ISJSON(@Findings, ARRAY), 0) <> 1
        THROW 52001,
            'Validation findings must be a JSON array.', 1;

    DECLARE @Rules TABLE
    (
        RuleCode varchar(100) NOT NULL PRIMARY KEY,
        RuleVersion int NOT NULL,
        DataClassification varchar(30) NOT NULL,
        ValidationDecision varchar(20) NOT NULL,
        DetectionCount int NOT NULL
    );

    DECLARE @ExpectedRules TABLE
    (
        RuleCode varchar(100) NOT NULL PRIMARY KEY,
        DataClassification varchar(30) NOT NULL
    );

    INSERT INTO @ExpectedRules
    VALUES
        ('OUTPUT_AUTHORIZATION',       'CONFIDENTIAL'),
        ('OUTPUT_ROW_COUNT',            'INTERNAL'),
        ('OUTPUT_SCHEMA',               'CONFIDENTIAL'),
        ('OUTPUT_FINANCIAL_INTEGRITY',  'CONFIDENTIAL'),
        ('OUTPUT_CUSTOMER_BINDING',     'CONFIDENTIAL');

    DECLARE
        @DetectionCount int,
        @ValidationDecision varchar(20),
        @EventDetails varchar(max),
        @EvaluatedAt datetime2(3);

    BEGIN TRY

        INSERT INTO @Rules
        (
            RuleCode,
            RuleVersion,
            DataClassification,
            ValidationDecision,
            DetectionCount
        )
        SELECT
            RuleCode,
            RuleVersion,
            DataClassification,
            ValidationDecision,
            DetectionCount
        FROM OPENJSON(@Findings)
        WITH
        (
            RuleCode varchar(100),
            RuleVersion int,
            DataClassification varchar(30),
            ValidationDecision varchar(20),
            DetectionCount int
        );

        ---------------------------------------------------
        -- Validate the rule contract.
        ---------------------------------------------------

        IF (SELECT COUNT(*) FROM @Rules) <> 5
            OR EXISTS
            (
                SELECT 1
                FROM @Rules AS r
                LEFT JOIN @ExpectedRules AS e
                    ON e.RuleCode = r.RuleCode
                WHERE e.RuleCode IS NULL
                   OR r.RuleVersion <> 1
                   OR r.DataClassification <> e.DataClassification
                   OR r.ValidationDecision NOT IN
                      ('PASSED', 'BLOCKED')
                   OR r.DetectionCount NOT IN (0, 1)
                   OR
                   (
                       r.ValidationDecision = 'PASSED'
                       AND r.DetectionCount <> 0
                   )
                   OR
                   (
                       r.ValidationDecision = 'BLOCKED'
                       AND r.DetectionCount <> 1
                   )
            )
            THROW 52002,
                'Invalid output validation findings.', 1;

        BEGIN TRANSACTION;

        ---------------------------------------------------
        -- Validate interaction eligibility.
        ---------------------------------------------------

        IF NOT EXISTS
        (
            SELECT 1
            FROM aiaf.AIInteraction WITH (UPDLOCK, HOLDLOCK)
            WHERE InteractionId = @InteractionId
              AND InteractionStatus = 'PROCESSING'
        )
            THROW 52003,
                'Interaction is not eligible.', 1;

        ---------------------------------------------------
        -- Verify the tool execution evidence.
        ---------------------------------------------------

        IF NOT EXISTS
        (
            SELECT 1
            FROM aiaf.AIToolCall AS t
                WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN aiaf.AIModelToolRequest AS r
                ON r.ModelToolRequestId = t.ModelToolRequestId
            INNER JOIN aiaf.AIModelExecution AS m
                ON m.ModelExecutionId = r.ModelExecutionId
            WHERE t.AIToolCallId = @AIToolCallId
              AND t.InteractionId = @InteractionId
              AND m.InteractionId = @InteractionId
              AND t.ToolCode = 'GetCustomerBalance'
              AND r.ToolCode = t.ToolCode
              AND t.AuthorizationDecision = 'ALLOWED'
              AND t.ExecutionStatus = 'SUCCEEDED'
        )
            THROW 52004,
                'Eligible tool execution not found.', 1;

        ---------------------------------------------------
        -- Prevent duplicate output validation.
        ---------------------------------------------------

        IF EXISTS
        (
            SELECT 1
            FROM aiaf.AIValidation WITH (UPDLOCK, HOLDLOCK)
            WHERE AIToolCallId = @AIToolCallId
              AND ValidationStage = 'OUTPUT'
        )
            THROW 52005,
                'Output validation already recorded.', 1;

        SELECT @DetectionCount = SUM(DetectionCount)
        FROM @Rules;

        SET @ValidationDecision =
            CASE
                WHEN @DetectionCount = 0 THEN 'PASSED'
                ELSE 'BLOCKED'
            END;

        -- Independently verify the persisted row count
        -- before accepting an overall PASSED result.

        IF @ValidationDecision = 'PASSED'
            AND NOT EXISTS
            (
                SELECT 1
                FROM aiaf.AIToolCall
                WHERE AIToolCallId = @AIToolCallId
                  AND RowsReturned = 1
            )
            THROW 52006,
                'Persisted tool row count is invalid.', 1;

        SET @EvaluatedAt = SYSUTCDATETIME();

        ---------------------------------------------------
        -- Persist validation metadata only.
        ---------------------------------------------------

        INSERT INTO aiaf.AIValidation
        (
            InteractionId,
            AIToolCallId,
            ValidationStage,
            RuleCode,
            RuleVersion,
            DataClassification,
            ValidationDecision,
            DetectionCount,
            EvaluatedAt
        )
        SELECT
            @InteractionId,
            @AIToolCallId,
            'OUTPUT',
            RuleCode,
            RuleVersion,
            DataClassification,
            ValidationDecision,
            DetectionCount,
            @EvaluatedAt
        FROM @Rules;

        ---------------------------------------------------
        -- Construct ledger evidence.
        ---------------------------------------------------

        SET @EventDetails =
        (
            SELECT
                @AIToolCallId AS AIToolCallId,
                @ValidationDecision AS ValidationDecision,
                @DetectionCount AS DetectionCount,
                5 AS RulesEvaluated,
                CAST(0 AS bit) AS FinancialDataPersisted,
                JSON_QUERY
                (
                    (
                        SELECT
                            RuleCode,
                            RuleVersion,
                            DataClassification,
                            ValidationDecision,
                            DetectionCount
                        FROM @Rules
                        ORDER BY RuleCode
                        FOR JSON PATH
                    )
                ) AS Findings
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        INSERT INTO aiaf.AIInteractionEvent
        (
            InteractionId,
            EventCode,
            ComponentCode,
            EventOutcome,
            EventDetails
        )
        VALUES
        (
            @InteractionId,
            'OUTPUT_VALIDATED',
            'OUTPUT_VALIDATION',
            CASE
                WHEN @ValidationDecision = 'PASSED'
                    THEN 'PASSED'
                ELSE 'DENIED'
            END,
            @EventDetails
        );

        COMMIT TRANSACTION;

        SELECT
            @InteractionId AS InteractionId,
            @AIToolCallId AS AIToolCallId,
            @ValidationDecision AS ValidationDecision,
            @DetectionCount AS DetectionCount;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;

END;

GO

ALTER AUTHORIZATION ON [aiaf].[usp_RecordOutputValidation] TO  SCHEMA OWNER
GO
