SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [aiaf].[AIModelExecution](
	[ModelExecutionId] [bigint] IDENTITY(1,1) NOT NULL,
	[InteractionId] [bigint] NOT NULL,
	[ModelProvider] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[ModelName] [varchar](200) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[ModelVersion] [varchar](200) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
	[PromptVersion] [int] NOT NULL,
	[ExecutionPurpose] [varchar](50) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[StartedAt] [datetime2](3) NOT NULL,
	[CompletedAt] [datetime2](3) NOT NULL,
	[DurationMs] [bigint] NOT NULL,
	[ModelLoadDurationMs] [bigint] NULL,
	[InputTokens] [bigint] NULL,
	[OutputTokens] [bigint] NULL,
	[CachedInputTokens] [bigint] NULL,
	[CurrencyCode] [char](3) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
	[InputCost] [decimal](19, 10) NULL,
	[OutputCost] [decimal](19, 10) NULL,
	[OtherCost] [decimal](19, 10) NULL,
	[TotalCost]  AS (case when [InputCost] IS NOT NULL AND [OutputCost] IS NOT NULL AND [OtherCost] IS NOT NULL then CONVERT([decimal](19,10),([InputCost]+[OutputCost])+[OtherCost])  end) PERSISTED,
	[CostBasis] [varchar](30) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[PricingReference] [varchar](200) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
	[ExecutionStatus] [varchar](20) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[ResponseValidationDecision] [varchar](20) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[ErrorCode] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
	[RecordedAt] [datetime2](3) NOT NULL,
	[ServerDurationMs] [bigint] NULL,
	[PromptEvalDurationMs] [bigint] NULL,
	[OutputEvalDurationMs] [bigint] NULL,
	[InputTokensPerSecond]  AS (CONVERT([decimal](19,2),([InputTokens]*(1000.0))/nullif([PromptEvalDurationMs],(0)))),
	[OutputTokensPerSecond]  AS (CONVERT([decimal](19,2),([OutputTokens]*(1000.0))/nullif([OutputEvalDurationMs],(0)))),
	[ClientServerDurationDifferenceMs]  AS ([DurationMs]-[ServerDurationMs]),
	[ExecutionEnvironment] [varchar](20) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[TelemetrySource] [varchar](20) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
 CONSTRAINT [PK_AIModelExecution] PRIMARY KEY CLUSTERED
(
	[ModelExecutionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

GO

ALTER AUTHORIZATION ON [aiaf].[AIModelExecution] TO  SCHEMA OWNER
GO

ALTER TABLE [aiaf].[AIModelExecution] ADD  CONSTRAINT [DF_AIModelExecution_CostBasis]  DEFAULT ('UNAVAILABLE') FOR [CostBasis]
GO

ALTER TABLE [aiaf].[AIModelExecution] ADD  CONSTRAINT [DF_AIModelExecution_RecordedAt]  DEFAULT (sysutcdatetime()) FOR [RecordedAt]
GO

ALTER TABLE [aiaf].[AIModelExecution]  WITH CHECK ADD  CONSTRAINT [CK_AIModelExecution_CostBasis] CHECK  (([CostBasis]='UNAVAILABLE' OR [CostBasis]='INFRASTRUCTURE_ESTIMATE' OR [CostBasis]='RATE_CARD_ESTIMATE' OR [CostBasis]='PROVIDER_REPORTED'))
GO

ALTER TABLE [aiaf].[AIModelExecution] CHECK CONSTRAINT [CK_AIModelExecution_CostBasis]
GO

ALTER TABLE [aiaf].[AIModelExecution]  WITH CHECK ADD  CONSTRAINT [CK_AIModelExecution_Costs] CHECK  (([InputCost]>=(0) AND [OutputCost]>=(0) AND [OtherCost]>=(0)))
GO

ALTER TABLE [aiaf].[AIModelExecution] CHECK CONSTRAINT [CK_AIModelExecution_Costs]
GO

ALTER TABLE [aiaf].[AIModelExecution]  WITH CHECK ADD  CONSTRAINT [CK_AIModelExecution_Currency] CHECK  (([CostBasis]='UNAVAILABLE' AND [CurrencyCode] IS NULL AND [InputCost] IS NULL AND [OutputCost] IS NULL AND [OtherCost] IS NULL OR [CostBasis]<>'UNAVAILABLE' AND [CurrencyCode] IS NOT NULL AND [InputCost] IS NOT NULL AND [OutputCost] IS NOT NULL AND [OtherCost] IS NOT NULL))
GO

ALTER TABLE [aiaf].[AIModelExecution] CHECK CONSTRAINT [CK_AIModelExecution_Currency]
GO

ALTER TABLE [aiaf].[AIModelExecution]  WITH CHECK ADD  CONSTRAINT [CK_AIModelExecution_Duration] CHECK  (([DurationMs]>=(0) AND [ModelLoadDurationMs]>=(0) AND [CompletedAt]>=[StartedAt]))
GO

ALTER TABLE [aiaf].[AIModelExecution] CHECK CONSTRAINT [CK_AIModelExecution_Duration]
GO

ALTER TABLE [aiaf].[AIModelExecution]  WITH CHECK ADD  CONSTRAINT [CK_AIModelExecution_Environment] CHECK  (([ExecutionEnvironment]='PRODUCTION' OR [ExecutionEnvironment]='QA' OR [ExecutionEnvironment]='TEST' OR [ExecutionEnvironment]='DEVELOPMENT'))
GO

ALTER TABLE [aiaf].[AIModelExecution] CHECK CONSTRAINT [CK_AIModelExecution_Environment]
GO

ALTER TABLE [aiaf].[AIModelExecution]  WITH CHECK ADD  CONSTRAINT [CK_AIModelExecution_PromptVersion] CHECK  (([PromptVersion]>(0)))
GO

ALTER TABLE [aiaf].[AIModelExecution] CHECK CONSTRAINT [CK_AIModelExecution_PromptVersion]
GO

ALTER TABLE [aiaf].[AIModelExecution]  WITH CHECK ADD  CONSTRAINT [CK_AIModelExecution_ServerDurations] CHECK  (([ServerDurationMs]>=(0) AND [PromptEvalDurationMs]>=(0) AND [OutputEvalDurationMs]>=(0)))
GO

ALTER TABLE [aiaf].[AIModelExecution] CHECK CONSTRAINT [CK_AIModelExecution_ServerDurations]
GO

ALTER TABLE [aiaf].[AIModelExecution]  WITH CHECK ADD  CONSTRAINT [CK_AIModelExecution_Status] CHECK  (([ExecutionStatus]='TIMEOUT' OR [ExecutionStatus]='FAILED' OR [ExecutionStatus]='SUCCEEDED'))
GO

ALTER TABLE [aiaf].[AIModelExecution] CHECK CONSTRAINT [CK_AIModelExecution_Status]
GO

ALTER TABLE [aiaf].[AIModelExecution]  WITH CHECK ADD  CONSTRAINT [CK_AIModelExecution_TelemetrySource] CHECK  (([TelemetrySource]='REPLAY' OR [TelemetrySource]='SYNTHETIC' OR [TelemetrySource]='LIVE'))
GO

ALTER TABLE [aiaf].[AIModelExecution] CHECK CONSTRAINT [CK_AIModelExecution_TelemetrySource]
GO

ALTER TABLE [aiaf].[AIModelExecution]  WITH CHECK ADD  CONSTRAINT [CK_AIModelExecution_Tokens] CHECK  (([InputTokens]>=(0) AND [OutputTokens]>=(0) AND [CachedInputTokens]>=(0) AND ([CachedInputTokens] IS NULL OR [InputTokens] IS NOT NULL AND [CachedInputTokens]<=[InputTokens])))
GO

ALTER TABLE [aiaf].[AIModelExecution] CHECK CONSTRAINT [CK_AIModelExecution_Tokens]
GO

ALTER TABLE [aiaf].[AIModelExecution]  WITH CHECK ADD  CONSTRAINT [CK_AIModelExecution_Validation] CHECK  (([ResponseValidationDecision]='NOT_EVALUATED' OR [ResponseValidationDecision]='FAILED' OR [ResponseValidationDecision]='PASSED'))
GO

ALTER TABLE [aiaf].[AIModelExecution] CHECK CONSTRAINT [CK_AIModelExecution_Validation]
GO
