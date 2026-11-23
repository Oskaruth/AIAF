SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE   PROCEDURE aiaf.usp_BeginInteraction
    @ApplicationCode varchar(100),
    @RequestingIdentity varchar(1024),
    @WorkflowCode varchar(100),
    @BusinessPurpose varchar(2000),
    @InteractionId bigint OUTPUT,
    @CorrelationId varchar(100) OUTPUT,
    @GateDecision varchar(20) OUTPUT,
    @GateReason varchar(100) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @ApplicationId bigint,
        @ReviewId bigint,
        @AttestationId bigint,
        @GovernanceDecision varchar(30),
        @InteractionAt datetime2(3),
        @EventDetails varchar(max);

    SELECT
        @InteractionId = NULL,
        @CorrelationId = CONVERT(varchar(36), NEWID()),
        @GateDecision = 'DENIED',
        @GateReason = 'NOT_EVALUATED',
        @InteractionAt = SYSUTCDATETIME();

    IF NULLIF(TRIM(@RequestingIdentity), '') IS NULL
       OR NULLIF(TRIM(@WorkflowCode), '') IS NULL
       OR NULLIF(TRIM(@BusinessPurpose), '') IS NULL
       OR NULLIF(TRIM(@ApplicationCode), '') IS NULL
    BEGIN
        THROW 51400, 'Required interaction context is missing.', 1;
    END;

    BEGIN TRY

        BEGIN TRANSACTION;

        EXEC aiaf.usp_EvaluateGovernanceGate
            @ApplicationCode = @ApplicationCode,
            @ApplicationId = @ApplicationId OUTPUT,
            @ReviewId = @ReviewId OUTPUT,
            @AttestationId = @AttestationId OUTPUT,
            @GovernanceDecision = @GovernanceDecision OUTPUT,
            @GateDecision = @GateDecision OUTPUT,
            @GateReason = @GateReason OUTPUT;

        INSERT INTO aiaf.AIInteraction
        (
            ApplicationId,
            CorrelationId,
            RequestingIdentity,
            WorkflowCode,
            BusinessPurpose,
            InteractionAt,
            InteractionStatus,
            CompletedAt
        )
        VALUES
        (
            @ApplicationId,
            @CorrelationId,
            @RequestingIdentity,
            @WorkflowCode,
            @BusinessPurpose,
            @InteractionAt,
            CASE
                WHEN @GateDecision = 'ALLOWED'
                    THEN 'RECEIVED'
                ELSE 'BLOCKED'
            END,
            CASE
                WHEN @GateDecision = 'ALLOWED'
                    THEN NULL
                ELSE SYSUTCDATETIME()
            END
        );

        SET @InteractionId = SCOPE_IDENTITY();

        SELECT @EventDetails =
        (
            SELECT
                @ApplicationCode AS ApplicationCode,
                @CorrelationId AS CorrelationId,
                @WorkflowCode AS WorkflowCode
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
            'INTERACTION_RECEIVED',
            'INTERACTION_GATEWAY',
            'INFO',
            @EventDetails
        );

        SELECT @EventDetails =
        (
            SELECT
                @ApplicationCode AS ApplicationCode,
                @ReviewId AS ReviewId,
                @AttestationId AS AttestationId,
                @GovernanceDecision AS GovernanceDecision,
                @GateDecision AS GateDecision,
                @GateReason AS GateReason
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
            'GOVERNANCE_GATE_EVALUATED',
            'GOVERNANCE',
            CASE
                WHEN @GateDecision = 'ALLOWED'
                    THEN 'PASSED'
                ELSE 'DENIED'
            END,
            @EventDetails
        );

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @InteractionId = NULL;
        SET @GateDecision = 'DENIED';
        SET @GateReason = 'INTERACTION_GATEWAY_ERROR';

        THROW;

    END CATCH;
END;

GO

ALTER AUTHORIZATION ON [aiaf].[usp_BeginInteraction] TO  SCHEMA OWNER
GO
