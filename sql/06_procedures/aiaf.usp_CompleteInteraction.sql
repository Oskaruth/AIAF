SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE OR ALTER   PROCEDURE [aiaf].[usp_CompleteInteraction]
    @InteractionId bigint,
    @ProcessingFailed bit = 0
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @@TRANCOUNT <> 0
        THROW 52100,
            'Caller-owned transactions are not supported.', 1;

    IF @ProcessingFailed = 1
    BEGIN
        EXEC aiaf.usp_FailInteraction @InteractionId = @InteractionId;

        RETURN;
    END;

    DECLARE
        @InteractionStatus varchar(30),
        @FinalStatus varchar(30),
        @CompletionReason varchar(100),
        @ModelExecutionId bigint,
        @ModelExecutionStatus varchar(20),
        @ResponseValidationDecision varchar(20),
        @ModelToolRequestId bigint,
        @ToolCode varchar(100),
        @AIToolCallId bigint,
        @AuthorizationDecision varchar(20),
        @ToolExecutionStatus varchar(30),
        @RowsReturned int,
        @OutputRulesEvaluated int,
        @OutputRulesPassed int,
        @OutputRulesBlocked int,
        @CompletedAt datetime2(3),
        @EventDetails varchar(max);

    BEGIN TRY

        BEGIN TRANSACTION;

        ---------------------------------------------------
        -- Lock and verify the interaction.
        ---------------------------------------------------

        SELECT
            @InteractionStatus = InteractionStatus
        FROM aiaf.AIInteraction WITH (UPDLOCK, HOLDLOCK)
        WHERE InteractionId = @InteractionId;

        IF @InteractionStatus IS NULL
            THROW 52101,
                'Interaction not found.', 1;

        IF @InteractionStatus <> 'PROCESSING'
            THROW 52102,
                'Interaction is not eligible for completion.', 1;

        ---------------------------------------------------
        -- Verify input validation evidence.
        ---------------------------------------------------

        IF NOT EXISTS
        (
            SELECT 1
            FROM aiaf.AIInteractionEvent
            WHERE InteractionId = @InteractionId
              AND EventCode = 'INPUT_VALIDATED'
              AND ComponentCode = 'INPUT_VALIDATION'
              AND EventOutcome = 'PASSED'
        )
            THROW 52103,
                'Required input validation evidence is missing.', 1;

        ---------------------------------------------------
        -- Our current workflow supports exactly one
        -- live tool-selection model execution.
        ---------------------------------------------------

        IF
        (
            SELECT COUNT_BIG(*)
            FROM aiaf.AIModelExecution
            WHERE InteractionId = @InteractionId
              AND ExecutionPurpose = 'TOOL_SELECTION'
              AND TelemetrySource = 'LIVE'
        ) <> 1
            THROW 52104,
                'Expected exactly one live model execution.', 1;

        SELECT
            @ModelExecutionId = ModelExecutionId,
            @ModelExecutionStatus = ExecutionStatus,
            @ResponseValidationDecision =
                ResponseValidationDecision
        FROM aiaf.AIModelExecution
        WHERE InteractionId = @InteractionId
          AND ExecutionPurpose = 'TOOL_SELECTION'
          AND TelemetrySource = 'LIVE';

        ---------------------------------------------------
        -- Evaluate the model execution.
        ---------------------------------------------------

        IF @ModelExecutionStatus <> 'SUCCEEDED'
        BEGIN

            SET @FinalStatus = 'FAILED';
            SET @CompletionReason = 'MODEL_EXECUTION_FAILED';

        END
        ELSE IF @ResponseValidationDecision <> 'PASSED'
        BEGIN

            SET @FinalStatus = 'FAILED';
            SET @CompletionReason = 'MODEL_RESPONSE_INVALID';

        END
        ELSE
        BEGIN

            ------------------------------------------------
            -- Retrieve the recorded model proposal.
            ------------------------------------------------

            SELECT
                @ModelToolRequestId = ModelToolRequestId,
                @ToolCode = ToolCode
            FROM aiaf.AIModelToolRequest
            WHERE ModelExecutionId = @ModelExecutionId;

            IF @ModelToolRequestId IS NULL
                THROW 52105,
                    'Required model proposal is missing.', 1;

            IF @ToolCode = 'NO_SUPPORTED_TOOL'
            BEGIN

                SET @FinalStatus = 'BLOCKED';
                SET @CompletionReason = 'NO_SUPPORTED_TOOL';

            END
            ELSE
            BEGIN

                --------------------------------------------
                -- Retrieve the tool execution evidence.
                --------------------------------------------

                SELECT
                    @AIToolCallId = AIToolCallId,
                    @AuthorizationDecision =
                        AuthorizationDecision,
                    @ToolExecutionStatus = ExecutionStatus,
                    @RowsReturned = RowsReturned
                FROM aiaf.AIToolCall
                WHERE ModelToolRequestId = @ModelToolRequestId
                  AND InteractionId = @InteractionId
                  AND ToolCode = @ToolCode;

                IF @AIToolCallId IS NULL
                    THROW 52106,
                        'Required tool execution evidence is missing.', 1;

                IF @AuthorizationDecision = 'DENIED'
                BEGIN

                    SET @FinalStatus = 'BLOCKED';
                    SET @CompletionReason =
                        'TOOL_AUTHORIZATION_DENIED';

                END
                ELSE IF @AuthorizationDecision <> 'ALLOWED'
                    OR @ToolExecutionStatus <> 'SUCCEEDED'
                BEGIN

                    SET @FinalStatus = 'FAILED';
                    SET @CompletionReason =
                        'TOOL_EXECUTION_FAILED';

                END
                ELSE
                BEGIN

                    ----------------------------------------
                    -- Evaluate persisted output validation.
                    ----------------------------------------

                    SELECT
                        @OutputRulesEvaluated = COUNT(*),
                        @OutputRulesPassed = COUNT
                        (
                            CASE
                                WHEN ValidationDecision = 'PASSED'
                                    AND DetectionCount = 0
                                THEN 1
                            END
                        ),
                        @OutputRulesBlocked = COUNT
                        (
                            CASE
                                WHEN ValidationDecision = 'BLOCKED'
                                    AND DetectionCount = 1
                                THEN 1
                            END
                        )
                    FROM aiaf.AIValidation
                    WHERE InteractionId = @InteractionId
                      AND AIToolCallId = @AIToolCallId
                      AND ValidationStage = 'OUTPUT'
                      AND RuleVersion = 1;

                    IF @OutputRulesEvaluated <> 5
                        THROW 52107,
                            'Required output validation evidence is missing.', 1;

                    IF @OutputRulesBlocked > 0
                    BEGIN

                        SET @FinalStatus = 'BLOCKED';
                        SET @CompletionReason =
                            'OUTPUT_VALIDATION_BLOCKED';

                    END
                    ELSE IF @OutputRulesPassed = 5
                        AND @RowsReturned = 1
                    BEGIN

                        SET @FinalStatus = 'COMPLETED';
                        SET @CompletionReason =
                            'OUTPUT_APPROVED_FOR_RELEASE';

                    END
                    ELSE
                    BEGIN

                        THROW 52108,
                            'Output validation evidence is inconsistent.', 1;

                    END;

                END;

            END;

        END;

        ---------------------------------------------------
        -- Persist the terminal interaction status.
        ---------------------------------------------------

        SET @CompletedAt = SYSUTCDATETIME();

        UPDATE aiaf.AIInteraction
        SET
            InteractionStatus = @FinalStatus,
            CompletedAt = @CompletedAt
        WHERE InteractionId = @InteractionId;

        ---------------------------------------------------
        -- Record the evidence supporting completion.
        ---------------------------------------------------

        SET @EventDetails =
        (
            SELECT
                @FinalStatus AS InteractionStatus,
                @CompletionReason AS CompletionReason,
                @ModelExecutionId AS ModelExecutionId,
                @ModelToolRequestId AS ModelToolRequestId,
                @AIToolCallId AS AIToolCallId,
                @AuthorizationDecision AS AuthorizationDecision,
                @ToolExecutionStatus AS ExecutionStatus,
                @OutputRulesEvaluated AS OutputRulesEvaluated,
                @OutputRulesPassed AS OutputRulesPassed,
                @OutputRulesBlocked AS OutputRulesBlocked,
                CAST(0 AS bit) AS ResponseDeliveryConfirmed,
                @CompletedAt AS CompletedAt
            FOR JSON PATH,
                INCLUDE_NULL_VALUES,
                WITHOUT_ARRAY_WRAPPER
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
            'INTERACTION_FINALIZED',
            'INTERACTION_LIFECYCLE',
            CASE @FinalStatus
                WHEN 'COMPLETED' THEN 'PASSED'
                WHEN 'BLOCKED' THEN 'DENIED'
                ELSE 'FAILED'
            END,
            @EventDetails
        );

        COMMIT TRANSACTION;

        SELECT
            @InteractionId AS InteractionId,
            @FinalStatus AS InteractionStatus,
            @CompletionReason AS CompletionReason,
            @CompletedAt AS CompletedAt;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;

END;

GO
