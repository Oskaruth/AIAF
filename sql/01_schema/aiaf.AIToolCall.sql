SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [aiaf].[AIToolCall](
	[AIToolCallId] [bigint] IDENTITY(1,1) NOT NULL,
	[InteractionId] [bigint] NOT NULL,
	[ToolCode] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[RequestedAt] [datetime2](3) NOT NULL,
	[AuthorizationDecision] [varchar](20) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[ExecutionStatus] [varchar](30) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[RequestArguments] [varchar](max) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
	[AuthorizationReason] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
	[CompletedAt] [datetime2](3) NULL,
	[RowsReturned] [int] NULL,
	[ModelToolRequestId] [bigint] NULL,
 CONSTRAINT [PK_AIToolCall] PRIMARY KEY CLUSTERED
(
	[AIToolCallId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

ALTER AUTHORIZATION ON [aiaf].[AIToolCall] TO  SCHEMA OWNER
GO

ALTER TABLE [aiaf].[AIToolCall]  WITH CHECK ADD  CONSTRAINT [CK_AIToolCall_Authorization] CHECK  (([AuthorizationDecision]='ERROR' OR [AuthorizationDecision]='DENIED' OR [AuthorizationDecision]='ALLOWED'))
GO

ALTER TABLE [aiaf].[AIToolCall] CHECK CONSTRAINT [CK_AIToolCall_Authorization]
GO

ALTER TABLE [aiaf].[AIToolCall]  WITH CHECK ADD  CONSTRAINT [CK_AIToolCall_ExecutionAuthorization] CHECK  (([AuthorizationDecision]='ALLOWED' OR [ExecutionStatus]='NOT_EXECUTED'))
GO

ALTER TABLE [aiaf].[AIToolCall] CHECK CONSTRAINT [CK_AIToolCall_ExecutionAuthorization]
GO

ALTER TABLE [aiaf].[AIToolCall]  WITH CHECK ADD  CONSTRAINT [CK_AIToolCall_ExecutionStatus] CHECK  (([ExecutionStatus]='NOT_EXECUTED' OR [ExecutionStatus]='FAILED' OR [ExecutionStatus]='SUCCEEDED'))
GO

ALTER TABLE [aiaf].[AIToolCall] CHECK CONSTRAINT [CK_AIToolCall_ExecutionStatus]
GO

ALTER TABLE [aiaf].[AIToolCall]  WITH CHECK ADD  CONSTRAINT [CK_AIToolCall_RequestArguments] CHECK  ((isjson([RequestArguments],OBJECT)=(1)))
GO

ALTER TABLE [aiaf].[AIToolCall] CHECK CONSTRAINT [CK_AIToolCall_RequestArguments]
GO

ALTER TABLE [aiaf].[AIToolCall]  WITH CHECK ADD  CONSTRAINT [CK_AIToolCall_RowsReturned] CHECK  (([RowsReturned]>=(0)))
GO

ALTER TABLE [aiaf].[AIToolCall] CHECK CONSTRAINT [CK_AIToolCall_RowsReturned]
GO
