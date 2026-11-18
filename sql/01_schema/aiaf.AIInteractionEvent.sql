SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [aiaf].[AIInteractionEvent](
	[InteractionEventId] [bigint] IDENTITY(1,1) NOT NULL,
	[InteractionId] [bigint] NOT NULL,
	[EventCode] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[ComponentCode] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[EventOutcome] [varchar](20) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[EventAt] [datetime2](3) NOT NULL,
	[EventDetails] [varchar](max) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
	[ledger_start_transaction_id] [bigint] GENERATED ALWAYS AS transaction_id START HIDDEN NOT NULL,
	[ledger_start_sequence_number] [bigint] GENERATED ALWAYS AS sequence_number START HIDDEN NOT NULL,
 CONSTRAINT [PK_AIInteractionEvent] PRIMARY KEY CLUSTERED
(
	[InteractionEventId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
WITH
(
LEDGER = ON (APPEND_ONLY = ON, LEDGER_VIEW = [aiaf].[AIInteractionEvent_Ledger] (TRANSACTION_ID_COLUMN_NAME = [ledger_transaction_id], SEQUENCE_NUMBER_COLUMN_NAME = [ledger_sequence_number], OPERATION_TYPE_COLUMN_NAME = [ledger_operation_type], OPERATION_TYPE_DESC_COLUMN_NAME = [ledger_operation_type_desc]))
)

GO

ALTER AUTHORIZATION ON [aiaf].[AIInteractionEvent] TO  SCHEMA OWNER
GO

ALTER TABLE [aiaf].[AIInteractionEvent] ADD  CONSTRAINT [DF_AIInteractionEvent_EventAt]  DEFAULT (sysutcdatetime()) FOR [EventAt]
GO

ALTER TABLE [aiaf].[AIInteractionEvent]  WITH CHECK ADD  CONSTRAINT [CK_AIInteractionEvent_EventDetails] CHECK  ((isjson([EventDetails],OBJECT)=(1)))
GO

ALTER TABLE [aiaf].[AIInteractionEvent] CHECK CONSTRAINT [CK_AIInteractionEvent_EventDetails]
GO

ALTER TABLE [aiaf].[AIInteractionEvent]  WITH CHECK ADD  CONSTRAINT [CK_AIInteractionEvent_EventOutcome] CHECK  (([EventOutcome]='PENDING' OR [EventOutcome]='FAILED' OR [EventOutcome]='DENIED' OR [EventOutcome]='PASSED' OR [EventOutcome]='INFO'))
GO

ALTER TABLE [aiaf].[AIInteractionEvent] CHECK CONSTRAINT [CK_AIInteractionEvent_EventOutcome]
GO
