SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE   PROCEDURE aiaf.usp_RecordModelToolRequest
    @InteractionId bigint,
    @ModelExecutionId bigint,
    @ToolCode varchar(100),
    @CustomerCode varchar(50)
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @@TRANCOUNT > 0
        THROW 51800,
            'Caller-owned transactions are not supported.', 1;

    DECLARE
        @ModelToolRequestId bigint,
        @RequestArguments varchar(max),
        @EventDetails varchar(max),
        @RequestedAt datetime2(3),
        @EventOutcome varchar(20);

    -------------------------------------------------------
    -- Validate the supported tool contract.
    -------------------------------------------------------

    IF @ToolCode IS NULL
        OR @ToolCode COLLATE Latin1_General_100_BIN2 NOT IN
        (
            'GetCustomerBalance',
            'NO_SUPPORTED_TOOL'
        )
        THROW 51801,
            'Unsupported tool code.', 1;

    IF @ToolCode = 'GetCustomerBalance'
        AND
        (
            @CustomerCode IS NULL
            OR DATALENGTH(@CustomerCode) <> 9
            OR @CustomerCode COLLATE Latin1_General_100_BIN2
                NOT LIKE 'CUST-[0-9][0-9][0-9][0-9]'
        )
        THROW 51802,
            'Invalid customer code.', 1;

    IF @ToolCode = 'NO_SUPPORTED_TOOL'
        AND
        (
            @CustomerCode IS NULL
            OR DATALENGTH(@CustomerCode) <> 0
        )
        THROW 51803,
            'Unexpected customer code.', 1;

    BEGIN TRY

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
            THROW 51804,
                'Interaction is not eligible.', 1;

        ---------------------------------------------------
        -- Validate model execution evidence.
        ---------------------------------------------------

        IF NOT EXISTS
        (
            SELECT 1
            FROM aiaf.AIModelExecution
                WITH (UPDLOCK, HOLDLOCK)
            WHERE ModelExecutionId = @ModelExecutionId
              AND InteractionId = @InteractionId
              AND ExecutionPurpose = 'TOOL_SELECTION'
              AND ExecutionStatus = 'SUCCEEDED'
              AND ResponseValidationDecision = 'PASSED'
              AND TelemetrySource = 'LIVE'
        )
            THROW 51805,
                'Eligible model execution not found.', 1;

        ---------------------------------------------------
        -- Prevent duplicate proposals.
        ---------------------------------------------------

        IF EXISTS
        (
            SELECT 1
            FROM aiaf.AIModelToolRequest
                WITH (UPDLOCK, HOLDLOCK)
            WHERE ModelExecutionId = @ModelExecutionId
        )
            THROW 51806,
                'Model tool request already recorded.', 1;

        ---------------------------------------------------
        -- Construct controlled request arguments.
        ---------------------------------------------------

        SET @RequestArguments =
        (
            SELECT
                @CustomerCode AS CustomerCode
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        SET @RequestedAt = SYSUTCDATETIME();

        ---------------------------------------------------
        -- Record the model proposal.
        ---------------------------------------------------

        INSERT INTO aiaf.AIModelToolRequest
        (
            ModelExecutionId,
            ToolCode,
            RequestArguments,
            RequestedAt
        )
        VALUES
        (
            @ModelExecutionId,
            @ToolCode,
            @RequestArguments,
            @RequestedAt
        );

        SET @ModelToolRequestId =
            CONVERT(bigint, SCOPE_IDENTITY());

        ---------------------------------------------------
        -- Construct append-only audit evidence.
        ---------------------------------------------------

        SET @EventOutcome =
            CASE
                WHEN @ToolCode = 'NO_SUPPORTED_TOOL'
                    THEN 'INFO'
                ELSE 'PENDING'
            END;

        SET @EventDetails =
        (
            SELECT
                @ModelToolRequestId AS ModelToolRequestId,
                @ModelExecutionId AS ModelExecutionId,
                @ToolCode AS ToolCode,
                JSON_QUERY(@RequestArguments)
                    AS RequestArguments,
                'NOT_EVALUATED' AS AuthorizationDecision
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
            'MODEL_TOOL_REQUEST_RECORDED',
            'TOOL_SELECTION',
            @EventOutcome,
            @EventDetails
        );

        COMMIT TRANSACTION;

        SELECT
            @ModelToolRequestId AS ModelToolRequestId,
            @ModelExecutionId AS ModelExecutionId,
            @InteractionId AS InteractionId,
            @ToolCode AS ToolCode,
            @RequestArguments AS RequestArguments,
            @RequestedAt AS RequestedAt,
            'NOT_EVALUATED' AS AuthorizationDecision;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;

END;

GO

ALTER AUTHORIZATION ON [aiaf].[usp_RecordModelToolRequest] TO  SCHEMA OWNER
GO
