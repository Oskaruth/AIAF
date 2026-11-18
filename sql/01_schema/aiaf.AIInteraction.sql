SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [aiaf].[AIInteraction](
	[InteractionId] [bigint] IDENTITY(1,1) NOT NULL,
	[RequestingIdentity] [varchar](1024) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[WorkflowCode] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[InteractionAt] [datetime2](3) NOT NULL,
	[ExperimentPeriod] [varchar](20) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
	[ApplicationId] [bigint] NULL,
	[CorrelationId] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
	[BusinessPurpose] [varchar](2000) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
	[InteractionStatus] [varchar](30) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[CompletedAt] [datetime2](3) NULL,
 CONSTRAINT [PK_AIInteraction] PRIMARY KEY CLUSTERED
(
	[InteractionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

GO

ALTER AUTHORIZATION ON [aiaf].[AIInteraction] TO  SCHEMA OWNER
GO

ALTER TABLE [aiaf].[AIInteraction] ADD  CONSTRAINT [DF_AIInteraction_InteractionStatus]  DEFAULT ('LEGACY') FOR [InteractionStatus]
GO

ALTER TABLE [aiaf].[AIInteraction]  WITH CHECK ADD  CONSTRAINT [CK_AIInteraction_Completion] CHECK  ((([InteractionStatus]='FAILED' OR [InteractionStatus]='COMPLETED' OR [InteractionStatus]='BLOCKED') AND [CompletedAt] IS NOT NULL AND [CompletedAt]>=[InteractionAt] OR ([InteractionStatus]='AWAITING_APPROVAL' OR [InteractionStatus]='PROCESSING' OR [InteractionStatus]='RECEIVED' OR [InteractionStatus]='LEGACY') AND [CompletedAt] IS NULL))
GO

ALTER TABLE [aiaf].[AIInteraction] CHECK CONSTRAINT [CK_AIInteraction_Completion]
GO

ALTER TABLE [aiaf].[AIInteraction]  WITH CHECK ADD  CONSTRAINT [CK_AIInteraction_ExperimentPeriod] CHECK  (([ExperimentPeriod]='CURRENT' OR [ExperimentPeriod]='BASELINE'))
GO

ALTER TABLE [aiaf].[AIInteraction] CHECK CONSTRAINT [CK_AIInteraction_ExperimentPeriod]
GO

ALTER TABLE [aiaf].[AIInteraction]  WITH CHECK ADD  CONSTRAINT [CK_AIInteraction_InteractionStatus] CHECK  (([InteractionStatus]='FAILED' OR [InteractionStatus]='COMPLETED' OR [InteractionStatus]='AWAITING_APPROVAL' OR [InteractionStatus]='PROCESSING' OR [InteractionStatus]='BLOCKED' OR [InteractionStatus]='RECEIVED' OR [InteractionStatus]='LEGACY'))
GO

ALTER TABLE [aiaf].[AIInteraction] CHECK CONSTRAINT [CK_AIInteraction_InteractionStatus]
GO

ALTER TABLE [aiaf].[AIInteraction]  WITH CHECK ADD  CONSTRAINT [CK_AIInteraction_RequiredContext] CHECK  (([InteractionStatus]='LEGACY' OR ([ApplicationId] IS NOT NULL OR [InteractionStatus]='BLOCKED') AND [CorrelationId] IS NOT NULL AND len(Trim([CorrelationId]))>(0) AND [BusinessPurpose] IS NOT NULL AND len(Trim([BusinessPurpose]))>(0)))
GO

ALTER TABLE [aiaf].[AIInteraction] CHECK CONSTRAINT [CK_AIInteraction_RequiredContext]
GO
