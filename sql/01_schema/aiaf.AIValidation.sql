SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [aiaf].[AIValidation](
	[ValidationId] [bigint] IDENTITY(1,1) NOT NULL,
	[InteractionId] [bigint] NOT NULL,
	[ValidationStage] [varchar](20) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[RuleCode] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[RuleVersion] [int] NOT NULL,
	[DataClassification] [varchar](30) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[ValidationDecision] [varchar](20) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[DetectionCount] [int] NOT NULL,
	[SanitizedContent] [varchar](max) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
	[EvaluatedAt] [datetime2](3) NOT NULL,
	[AIToolCallId] [bigint] NULL,
 CONSTRAINT [PK_AIValidation] PRIMARY KEY CLUSTERED
(
	[ValidationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

ALTER AUTHORIZATION ON [aiaf].[AIValidation] TO  SCHEMA OWNER
GO

ALTER TABLE [aiaf].[AIValidation] ADD  CONSTRAINT [DF_AIValidation_EvaluatedAt]  DEFAULT (sysutcdatetime()) FOR [EvaluatedAt]
GO

ALTER TABLE [aiaf].[AIValidation]  WITH CHECK ADD  CONSTRAINT [CK_AIValidation_BlockedContent] CHECK  (([ValidationDecision]='SANITIZED' OR [ValidationDecision]='PASSED' OR [SanitizedContent] IS NULL))
GO

ALTER TABLE [aiaf].[AIValidation] CHECK CONSTRAINT [CK_AIValidation_BlockedContent]
GO

ALTER TABLE [aiaf].[AIValidation]  WITH CHECK ADD  CONSTRAINT [CK_AIValidation_Classification] CHECK  (([DataClassification]='UNKNOWN' OR [DataClassification]='RESTRICTED' OR [DataClassification]='CONFIDENTIAL' OR [DataClassification]='INTERNAL' OR [DataClassification]='PUBLIC'))
GO

ALTER TABLE [aiaf].[AIValidation] CHECK CONSTRAINT [CK_AIValidation_Classification]
GO

ALTER TABLE [aiaf].[AIValidation]  WITH CHECK ADD  CONSTRAINT [CK_AIValidation_Decision] CHECK  (([ValidationDecision]='ERROR' OR [ValidationDecision]='BLOCKED' OR [ValidationDecision]='SANITIZED' OR [ValidationDecision]='PASSED'))
GO

ALTER TABLE [aiaf].[AIValidation] CHECK CONSTRAINT [CK_AIValidation_Decision]
GO

ALTER TABLE [aiaf].[AIValidation]  WITH CHECK ADD  CONSTRAINT [CK_AIValidation_DetectionCount] CHECK  (([DetectionCount]>=(0)))
GO

ALTER TABLE [aiaf].[AIValidation] CHECK CONSTRAINT [CK_AIValidation_DetectionCount]
GO

ALTER TABLE [aiaf].[AIValidation]  WITH CHECK ADD  CONSTRAINT [CK_AIValidation_RuleVersion] CHECK  (([RuleVersion]>(0)))
GO

ALTER TABLE [aiaf].[AIValidation] CHECK CONSTRAINT [CK_AIValidation_RuleVersion]
GO

ALTER TABLE [aiaf].[AIValidation]  WITH CHECK ADD  CONSTRAINT [CK_AIValidation_Stage] CHECK  (([ValidationStage]='OUTPUT' OR [ValidationStage]='INPUT'))
GO

ALTER TABLE [aiaf].[AIValidation] CHECK CONSTRAINT [CK_AIValidation_Stage]
GO

ALTER TABLE [aiaf].[AIValidation]  WITH CHECK ADD  CONSTRAINT [CK_AIValidation_StageToolCall] CHECK  (([ValidationStage]='INPUT' AND [AIToolCallId] IS NULL OR [ValidationStage]='OUTPUT' AND [AIToolCallId] IS NOT NULL))
GO

ALTER TABLE [aiaf].[AIValidation] CHECK CONSTRAINT [CK_AIValidation_StageToolCall]
GO
