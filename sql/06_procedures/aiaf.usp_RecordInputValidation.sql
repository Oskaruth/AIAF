SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE   PROCEDURE aiaf.usp_RecordInputValidation
    @InteractionId bigint,
    @Findings nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @InteractionStatus varchar(30),
        @DetectionCount int,
        @ValidationDecision varchar(20),
        @EventDetails varchar(max);

    IF @@TRANCOUNT <> 0
        THROW 51600, 'Caller-owned transactions are not supported.', 1;

    IF ISNULL(ISJSON(@Findings, ARRAY), 0) <> 1
        THROW 51601, 'Invalid validation findings.', 1;

    DECLARE @Rules TABLE
    (
        RuleCode varchar(100) PRIMARY KEY,
        RuleVersion int NOT NULL,
        DataClassification varchar(30) NOT NULL,
        ValidationDecision varchar(20) NOT NULL,
        DetectionCount int NOT NULL
    );

    INSERT INTO @Rules
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

    IF (SELECT COUNT(*) FROM @Rules) <> 3
       OR EXISTS
       (
           SELECT 1
           FROM @Rules
           WHERE RuleCode NOT IN
           (
               'US_SSN_PATTERN',
               'PAYMENT_CARD_PATTERN',
               'EMAIL_ADDRESS_PATTERN'
           )
           OR RuleVersion <> 1
           OR DetectionCount < 0
           OR ValidationDecision <>
               CASE WHEN DetectionCount > 0
                    THEN 'SANITIZED'
                    ELSE 'PASSED'
               END
           OR DataClassification <>
               CASE WHEN RuleCode = 'EMAIL_ADDRESS_PATTERN'
                    THEN 'CONFIDENTIAL'
                    ELSE 'RESTRICTED'
               END
       )
    BEGIN
        THROW 51602, 'Unexpected validation rule results.', 1;
    END;

    BEGIN TRY

        BEGIN TRANSACTION;

        SELECT @InteractionStatus = InteractionStatus
        FROM aiaf.AIInteraction WITH (UPDLOCK, HOLDLOCK)
        WHERE InteractionId = @InteractionId;

        IF @InteractionStatus IS NULL
           OR @InteractionStatus <> 'RECEIVED'
        BEGIN
            THROW 51603, 'Interaction is not eligible for validation.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM aiaf.AIValidation
            WHERE InteractionId = @InteractionId
              AND ValidationStage = 'INPUT'
        )
        BEGIN
            THROW 51604, 'Input validation already recorded.', 1;
        END;

        INSERT INTO aiaf.AIValidation
        (
            InteractionId,
            ValidationStage,
            RuleCode,
            RuleVersion,
            DataClassification,
            ValidationDecision,
            DetectionCount
        )
        SELECT
            @InteractionId,
            'INPUT',
            RuleCode,
            RuleVersion,
            DataClassification,
            ValidationDecision,
            DetectionCount
        FROM @Rules;

        SELECT @DetectionCount = SUM(DetectionCount)
        FROM @Rules;

        SET @ValidationDecision =
            CASE WHEN @DetectionCount > 0
                 THEN 'SANITIZED'
                 ELSE 'PASSED'
            END;

        SELECT @EventDetails =
        (
            SELECT
                @ValidationDecision AS ValidationDecision,
                @DetectionCount AS DetectionCount,
                3 AS RulesEvaluated,
                CAST(0 AS bit) AS RawContentPersisted,
                CAST(0 AS bit) AS SanitizedContentPersisted,
                JSON_QUERY
                (
                    (
                        SELECT *
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
            'INPUT_VALIDATED',
            'INPUT_VALIDATION',
            'PASSED',
            @EventDetails
        );

        UPDATE aiaf.AIInteraction
        SET InteractionStatus = 'PROCESSING'
        WHERE InteractionId = @InteractionId;

        COMMIT TRANSACTION;

        SELECT
            @InteractionId AS InteractionId,
            @ValidationDecision AS ValidationDecision,
            @DetectionCount AS DetectionCount,
            'PROCESSING' AS InteractionStatus;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;

GO

ALTER AUTHORIZATION ON [aiaf].[usp_RecordInputValidation] TO  SCHEMA OWNER
GO
