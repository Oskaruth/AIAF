SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER   PROCEDURE [aiaf].[usp_FailInteraction]
    @InteractionId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @@TRANCOUNT <> 0
        THROW 52200,
            'Caller-owned transactions are not supported.', 1;

    IF @InteractionId IS NULL OR @InteractionId <= 0
        THROW 52201,
            'Invalid interaction identifier.', 1;

    DECLARE
        @InteractionStatus varchar(30),
        @CompletedAt datetime2(3),
        @EventDetails varchar(max);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            @InteractionStatus = InteractionStatus
        FROM aiaf.AIInteraction WITH (UPDLOCK, HOLDLOCK)
        WHERE InteractionId = @InteractionId;

        IF @InteractionStatus IS NULL
            THROW 52202,
                'Interaction not found.', 1;

        IF @InteractionStatus <> 'PROCESSING'
            THROW 52203,
                'Interaction is not eligible for failure finalization.', 1;

        SET @CompletedAt = SYSUTCDATETIME();

        UPDATE aiaf.AIInteraction
        SET
            InteractionStatus = 'FAILED',
            CompletedAt = @CompletedAt
        WHERE InteractionId = @InteractionId;

        SET @EventDetails =
        (
            SELECT
                'FAILED' AS InteractionStatus,
                'PROCESSING_EXCEPTION' AS CompletionReason,
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
            'FAILED',
            @EventDetails
        );

        COMMIT TRANSACTION;

        SELECT
            @InteractionId AS InteractionId,
            CAST('FAILED' AS varchar(30)) AS InteractionStatus,
            CAST('PROCESSING_EXCEPTION' AS varchar(100))
                AS CompletionReason,
            @CompletedAt AS CompletedAt;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;

GO
