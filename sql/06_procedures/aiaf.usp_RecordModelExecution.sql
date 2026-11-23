SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE       PROCEDURE [aiaf].[usp_RecordModelExecution]
    @InteractionId bigint,
    @ModelProvider varchar(100),
    @ModelName varchar(200),
    @PromptVersion int,
    @ExecutionPurpose varchar(50),
    @StartedAt datetime2(3),
    @CompletedAt datetime2(3),
    @DurationMs bigint,
    @ExecutionStatus varchar(20),
    @ResponseValidationDecision varchar(20),
    @ExecutionEnvironment varchar(20),
    @TelemetrySource varchar(20),
    @ModelVersion varchar(200) = NULL,
    @ModelLoadDurationMs bigint = NULL,
    @InputTokens bigint = NULL,
    @OutputTokens bigint = NULL,
    @CachedInputTokens bigint = NULL,
    @CurrencyCode char(3) = NULL,
    @InputCost decimal(19,10) = NULL,
    @OutputCost decimal(19,10) = NULL,
    @OtherCost decimal(19,10) = NULL,
    @CostBasis varchar(30) = 'UNAVAILABLE',
    @PricingReference varchar(200) = NULL,
    @ErrorCode varchar(100) = NULL,
    @ServerDurationMs bigint = NULL,
    @PromptEvalDurationMs bigint = NULL,
    @OutputEvalDurationMs bigint = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @InteractionStatus varchar(30),
        @ModelExecutionId bigint,
        @TotalCost decimal(19,10),
        @EventDetails varchar(max),
        @EventOutcome varchar(20);

    IF @@TRANCOUNT <> 0
        THROW 51700, 'Caller-owned transactions are not supported.', 1;

    IF @ExecutionStatus IS NULL
       OR @ResponseValidationDecision IS NULL
       OR NOT
       (
           (
               @ExecutionStatus = 'SUCCEEDED'
               AND @ResponseValidationDecision IN ('PASSED', 'FAILED')
           )
           OR
           (
               @ExecutionStatus IN ('FAILED', 'TIMEOUT')
               AND @ResponseValidationDecision = 'NOT_EVALUATED'
           )
       )
    BEGIN
        THROW 51701, 'Invalid execution and validation outcomes.', 1;
    END;

    IF @ExecutionPurpose IS NULL
       OR @ExecutionPurpose NOT IN
       (
           'TOOL_SELECTION',
           'RESPONSE_GENERATION',
           'CLASSIFICATION'
       )
    BEGIN
        THROW 51702, 'Unsupported execution purpose.', 1;
    END;

    IF @CostBasis IN
       (
           'RATE_CARD_ESTIMATE',
           'INFRASTRUCTURE_ESTIMATE'
       )
       AND NULLIF(TRIM(@PricingReference), '') IS NULL
    BEGIN
        THROW 51703, 'Estimated costs require a pricing reference.', 1;
    END;

    BEGIN TRY

        BEGIN TRANSACTION;

        SELECT
            @InteractionStatus = InteractionStatus
        FROM aiaf.AIInteraction WITH (UPDLOCK, HOLDLOCK)
        WHERE InteractionId = @InteractionId;

        IF @InteractionStatus IS NULL
           OR @InteractionStatus <> 'PROCESSING'
        BEGIN
            THROW 51704, 'Interaction is not eligible for model execution.', 1;
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM aiaf.AIInteractionEvent
            WHERE InteractionId = @InteractionId
              AND EventCode = 'INPUT_VALIDATED'
              AND ComponentCode = 'INPUT_VALIDATION'
              AND EventOutcome = 'PASSED'
        )
        BEGIN
            THROW 51705, 'Input validation evidence is required.', 1;
        END;

        INSERT INTO aiaf.AIModelExecution
        (
            InteractionId,
            ModelProvider,
            ModelName,
            ExecutionEnvironment,
            TelemetrySource,
            ModelVersion,
            PromptVersion,
            ExecutionPurpose,
            StartedAt,
            CompletedAt,
            DurationMs,
            ModelLoadDurationMs,
            ServerDurationMs,
            PromptEvalDurationMs,
            OutputEvalDurationMs,
            InputTokens,
            OutputTokens,
            CachedInputTokens,
            CurrencyCode,
            InputCost,
            OutputCost,
            OtherCost,
            CostBasis,
            PricingReference,
            ExecutionStatus,
            ResponseValidationDecision,
            ErrorCode
        )
        VALUES
        (
            @InteractionId,
            @ModelProvider,
            @ModelName,
            @ExecutionEnvironment,
            @TelemetrySource,
            @ModelVersion,
            @PromptVersion,
            @ExecutionPurpose,
            @StartedAt,
            @CompletedAt,
            @DurationMs,
            @ModelLoadDurationMs,
            @ServerDurationMs,
            @PromptEvalDurationMs,
            @OutputEvalDurationMs,
            @InputTokens,
            @OutputTokens,
            @CachedInputTokens,
            @CurrencyCode,
            @InputCost,
            @OutputCost,
            @OtherCost,
            @CostBasis,
            @PricingReference,
            @ExecutionStatus,
            @ResponseValidationDecision,
            @ErrorCode
        );

        SET @ModelExecutionId = SCOPE_IDENTITY();

        SELECT @TotalCost = TotalCost
        FROM aiaf.AIModelExecution
        WHERE ModelExecutionId = @ModelExecutionId;

        SET @EventOutcome =
            CASE
                WHEN @ExecutionStatus = 'SUCCEEDED'
                 AND @ResponseValidationDecision = 'PASSED'
                    THEN 'PASSED'
                ELSE 'FAILED'
            END;

        SELECT @EventDetails =
        (
            SELECT
                @ModelExecutionId AS ModelExecutionId,
                @ModelProvider AS ModelProvider,
                @ModelName AS ModelName,
                @ExecutionEnvironment AS ExecutionEnvironment,
                @TelemetrySource AS TelemetrySource,
                @ModelVersion AS ModelVersion,
                @PromptVersion AS PromptVersion,
                @ExecutionPurpose AS ExecutionPurpose,
                @StartedAt AS StartedAt,
                @CompletedAt AS CompletedAt,
                @DurationMs AS DurationMs,
                @ModelLoadDurationMs AS ModelLoadDurationMs,
                @ServerDurationMs AS ServerDurationMs,
                @PromptEvalDurationMs AS PromptEvalDurationMs,
                @OutputEvalDurationMs AS OutputEvalDurationMs,
                @InputTokens AS InputTokens,
                @OutputTokens AS OutputTokens,
                @CachedInputTokens AS CachedInputTokens,
                @CurrencyCode AS CurrencyCode,
                @InputCost AS InputCost,
                @OutputCost AS OutputCost,
                @OtherCost AS OtherCost,
                @TotalCost AS TotalCost,
                @CostBasis AS CostBasis,
                @PricingReference AS PricingReference,
                @ExecutionStatus AS ExecutionStatus,
                @ResponseValidationDecision
                    AS ResponseValidationDecision,
                @ErrorCode AS ErrorCode
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
            'MODEL_EXECUTION_RECORDED',
            'MODEL_EXECUTION',
            @EventOutcome,
            @EventDetails
        );

        COMMIT TRANSACTION;

        SELECT
            @ModelExecutionId AS ModelExecutionId,
            @InteractionId AS InteractionId,
            @ExecutionStatus AS ExecutionStatus,
            @ResponseValidationDecision
                AS ResponseValidationDecision,
            @InputTokens AS InputTokens,
            @OutputTokens AS OutputTokens,
            @TotalCost AS TotalCost,
            @CurrencyCode AS CurrencyCode,
            @CostBasis AS CostBasis;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;

GO

ALTER AUTHORIZATION ON [aiaf].[usp_RecordModelExecution] TO  SCHEMA OWNER
GO
