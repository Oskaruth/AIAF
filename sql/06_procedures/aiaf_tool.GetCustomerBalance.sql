SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE       PROCEDURE [aiaf_tool].[GetCustomerBalance]
    @InteractionId bigint,
    @ModelToolRequestId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @ApplicationId bigint,
        @ApplicationCode varchar(100),
        @RequestingIdentity varchar(1024),
        @InteractionStatus varchar(30),
        @CustomerId bigint,
        @GateApplicationId bigint,
        @ReviewId bigint,
        @AttestationId bigint,
        @GovernanceDecision varchar(30),
        @GateDecision varchar(20),
        @GateReason varchar(100),
        @AuthorizationDecision varchar(20) = 'DENIED',
        @AuthorizationReason varchar(100),
        @ExecutionStatus varchar(30) = 'NOT_EXECUTED',
        @RequestedAt datetime2(3) = SYSUTCDATETIME(),
        @RequestArguments varchar(max),
        @EventDetails varchar(max),
        @AIToolCallId bigint,
        @CustomerCode varchar(50),
        @ModelExecutionId bigint,
        @RequestedToolCode varchar(100),
        @RowsReturned int = 0;

    DECLARE @Result TABLE
    (
        CustomerCode varchar(50),
        CustomerName varchar(400),
        OutstandingBalance decimal(38,2),
        DisputedBalance decimal(38,2),
        OpenInvoiceCount bigint,
        DisputedInvoiceCount bigint
    );

    IF @@TRANCOUNT <> 0
        THROW 51500, 'Caller-owned transactions are not supported.', 1;

    BEGIN TRY

        BEGIN TRANSACTION;

        SELECT
            @ApplicationId = i.ApplicationId,
            @ApplicationCode = a.ApplicationCode,
            @RequestingIdentity = i.RequestingIdentity,
            @InteractionStatus = i.InteractionStatus
        FROM aiaf.AIInteraction AS i WITH (UPDLOCK, HOLDLOCK)
        LEFT JOIN aiaf.AIApplication AS a
            ON a.ApplicationId = i.ApplicationId
        WHERE i.InteractionId = @InteractionId;

        IF @InteractionStatus IS NULL
            THROW 51501, 'Interaction not found.', 1;

        -------------------------------------------------------
        -- Retrieve the recorded model proposal.
        -------------------------------------------------------

        SELECT
            @ModelExecutionId = m.ModelExecutionId,
            @RequestedToolCode = r.ToolCode,
            @CustomerCode = JSON_VALUE
            (
                r.RequestArguments,
                '$.CustomerCode'
            )
        FROM aiaf.AIModelToolRequest AS r
            WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN aiaf.AIModelExecution AS m
            WITH (UPDLOCK, HOLDLOCK)
            ON m.ModelExecutionId = r.ModelExecutionId
        WHERE r.ModelToolRequestId = @ModelToolRequestId
          AND m.InteractionId = @InteractionId
          AND m.ExecutionPurpose = 'TOOL_SELECTION'
          AND m.ExecutionStatus = 'SUCCEEDED'
          AND m.ResponseValidationDecision = 'PASSED'
          AND m.TelemetrySource = 'LIVE';

        IF @ModelExecutionId IS NULL
            THROW 51901,
                'Eligible model tool request not found.', 1;


        -------------------------------------------------------
        -- Verify that the proposal matches this tool.
        -------------------------------------------------------

        IF @RequestedToolCode IS NULL
            OR @RequestedToolCode COLLATE Latin1_General_100_BIN2
                <> 'GetCustomerBalance'
            THROW 51902,
                'Model proposal does not match this tool.', 1;


        -------------------------------------------------------
        -- Validate the recorded arguments.
        -------------------------------------------------------

        IF @CustomerCode IS NULL
            OR DATALENGTH(@CustomerCode) <> 9
            OR @CustomerCode COLLATE Latin1_General_100_BIN2
                NOT LIKE 'CUST-[0-9][0-9][0-9][0-9]'
            THROW 51903,
                'Invalid recorded customer code.', 1;


        -------------------------------------------------------
        -- Prevent repeat execution of a model proposal.
        -------------------------------------------------------

        IF EXISTS
        (
            SELECT 1
            FROM aiaf.AIToolCall WITH (UPDLOCK, HOLDLOCK)
            WHERE ModelToolRequestId = @ModelToolRequestId
        )
            THROW 51904,
                'Model tool request already evaluated.', 1;

        SELECT @RequestArguments =
        (
            SELECT @CustomerCode AS CustomerCode
            FOR JSON PATH,
                INCLUDE_NULL_VALUES,
                WITHOUT_ARRAY_WRAPPER
        );

        IF @InteractionStatus <> 'PROCESSING'
        BEGIN

            SET @AuthorizationReason =
                'INTERACTION_NOT_ELIGIBLE';

        END
        ELSE IF NOT EXISTS
                (
                    SELECT 1
                    FROM aiaf.AIInteractionEvent
                    WHERE InteractionId = @InteractionId
                      AND EventCode = 'INPUT_VALIDATED'
                      AND ComponentCode = 'INPUT_VALIDATION'
                      AND EventOutcome = 'PASSED'
                )
                BEGIN
                    SET @AuthorizationReason = 'INPUT_VALIDATION_REQUIRED';
                END
        ELSE
        BEGIN

            EXEC aiaf.usp_EvaluateGovernanceGate
                @ApplicationCode = @ApplicationCode,
                @ApplicationId = @GateApplicationId OUTPUT,
                @ReviewId = @ReviewId OUTPUT,
                @AttestationId = @AttestationId OUTPUT,
                @GovernanceDecision = @GovernanceDecision OUTPUT,
                @GateDecision = @GateDecision OUTPUT,
                @GateReason = @GateReason OUTPUT;

            IF @GateDecision <> 'ALLOWED'
            BEGIN

                SET @AuthorizationReason = @GateReason;

            END
            ELSE
            BEGIN

                SELECT @CustomerId = CustomerId
                FROM acme.Customer
                WHERE CustomerCode = @CustomerCode
                  AND IsActive = 1;

                IF EXISTS
                (
                    SELECT 1
                    FROM aiaf.AICustomerAccess
                        WITH (UPDLOCK, HOLDLOCK)
                    WHERE ApplicationId = @ApplicationId
                      AND RequestingIdentity = @RequestingIdentity
                      AND CustomerId = @CustomerId
                      AND CanRead = 1
                      AND IsEnabled = 1
                      AND GrantedAt <= SYSUTCDATETIME()
                      AND
                      (
                          ExpiresAt IS NULL
                          OR ExpiresAt > SYSUTCDATETIME()
                      )
                )
                BEGIN

                    SET @AuthorizationDecision = 'ALLOWED';
                    SET @AuthorizationReason =
                        'CUSTOMER_READ_AUTHORIZED';

                END
                ELSE
                BEGIN

                    SET @AuthorizationReason =
                        'CUSTOMER_ACCESS_DENIED';

                END;

            END;

        END;

        IF @AuthorizationDecision = 'ALLOWED'
        BEGIN

            INSERT INTO @Result
            SELECT
                c.CustomerCode,
                c.CustomerName,
                COALESCE(SUM(i.OutstandingAmount), 0),
                COALESCE
                (
                    SUM
                    (
                        CASE WHEN i.IsDisputed = 1
                             THEN i.OutstandingAmount
                             ELSE 0
                        END
                    ), 0
                ),
                COUNT_BIG
                (
                    CASE WHEN i.OutstandingAmount > 0
                         THEN 1 END
                ),
                COUNT_BIG
                (
                    CASE WHEN i.IsDisputed = 1
                              AND i.OutstandingAmount > 0
                         THEN 1 END
                )
            FROM acme.Customer AS c
            LEFT JOIN acme.Invoice AS i
                ON i.CustomerId = c.CustomerId
            WHERE c.CustomerId = @CustomerId
            GROUP BY
                c.CustomerCode,
                c.CustomerName;

            SET @RowsReturned = @@ROWCOUNT;
            SET @ExecutionStatus = 'SUCCEEDED';

        END;

        INSERT INTO aiaf.AIToolCall
        (
            InteractionId,
            ModelToolRequestId,
            ToolCode,
            RequestedAt,
            AuthorizationDecision,
            ExecutionStatus,
            RequestArguments,
            AuthorizationReason,
            CompletedAt,
            RowsReturned
        )
        VALUES
        (
            @InteractionId,
            @ModelToolRequestId,
            'GetCustomerBalance',
            @RequestedAt,
            @AuthorizationDecision,
            @ExecutionStatus,
            @RequestArguments,
            @AuthorizationReason,
            SYSUTCDATETIME(),
            @RowsReturned
        );

        SET @AIToolCallId = SCOPE_IDENTITY();

        SELECT @EventDetails =
        (
            SELECT
                @AIToolCallId AS AIToolCallId,
                @ModelToolRequestId AS ModelToolRequestId,
                @ModelExecutionId AS ModelExecutionId,
                'GetCustomerBalance' AS ToolCode,
                @CustomerCode AS CustomerCode,
                @ReviewId AS ReviewId,
                @AttestationId AS AttestationId,
                @AuthorizationDecision AS AuthorizationDecision,
                @AuthorizationReason AS AuthorizationReason,
                @ExecutionStatus AS ExecutionStatus,
                @RowsReturned AS RowsReturned
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
            'TOOL_CALL_EVALUATED',
            'TOOL_EXECUTION',
            CASE
                WHEN @AuthorizationDecision = 'ALLOWED'
                    THEN 'PASSED'
                ELSE 'DENIED'
            END,
            @EventDetails
        );

        COMMIT TRANSACTION;

        SELECT
            @InteractionId AS InteractionId,
            @AIToolCallId AS AIToolCallId,
            @AuthorizationDecision AS AuthorizationDecision,
            @AuthorizationReason AS AuthorizationReason,
            @ExecutionStatus AS ExecutionStatus,
            @RowsReturned AS RowsReturned;

        IF @AuthorizationDecision = 'ALLOWED'
        BEGIN

            SELECT *
            FROM @Result;

        END;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;


GO

ALTER AUTHORIZATION ON [aiaf_tool].[GetCustomerBalance] TO  SCHEMA OWNER
GO
