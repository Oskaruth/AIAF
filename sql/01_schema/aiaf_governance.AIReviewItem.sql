SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [aiaf_governance].[AIReviewItem](
	[ReviewItemId] [bigint] IDENTITY(1,1) NOT NULL,
	[ReviewId] [bigint] NOT NULL,
	[ReviewArea] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[FindingCode] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[FindingDescription] [varchar](8000) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[Severity] [varchar](20) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[EvidenceSnapshot] [varchar](max) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[EvidenceEvaluatedAt] [datetime2](3) NOT NULL,
	[ReviewerIdentity] [varchar](1024) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
	[ReviewerDecision] [varchar](30) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[DecisionReason] [varchar](8000) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
	[DecisionAt] [datetime2](3) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_AIReviewItem] PRIMARY KEY CLUSTERED
(
	[ReviewItemId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

ALTER AUTHORIZATION ON [aiaf_governance].[AIReviewItem] TO  SCHEMA OWNER
GO

ALTER TABLE [aiaf_governance].[AIReviewItem] ADD  CONSTRAINT [DF_AIReviewItem_Decision]  DEFAULT ('PENDING') FOR [ReviewerDecision]
GO

ALTER TABLE [aiaf_governance].[AIReviewItem] ADD  CONSTRAINT [DF_AIReviewItem_CreatedAt]  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [aiaf_governance].[AIReviewItem]  WITH CHECK ADD  CONSTRAINT [CK_AIReviewItem_Decision] CHECK  (([ReviewerDecision]='SUSPEND' OR [ReviewerDecision]='RESTRICT' OR [ReviewerDecision]='REMEDIATE' OR [ReviewerDecision]='INVESTIGATE' OR [ReviewerDecision]='ACCEPTED' OR [ReviewerDecision]='PENDING'))
GO

ALTER TABLE [aiaf_governance].[AIReviewItem] CHECK CONSTRAINT [CK_AIReviewItem_Decision]
GO

ALTER TABLE [aiaf_governance].[AIReviewItem]  WITH CHECK ADD  CONSTRAINT [CK_AIReviewItem_DecisionMetadata] CHECK  (([ReviewerDecision]='PENDING' AND [ReviewerIdentity] IS NULL AND [DecisionAt] IS NULL AND [DecisionReason] IS NULL OR [ReviewerDecision]<>'PENDING' AND [ReviewerIdentity] IS NOT NULL AND [DecisionAt] IS NOT NULL AND [DecisionReason] IS NOT NULL AND len(Trim([ReviewerIdentity]))>(0) AND len(Trim([DecisionReason]))>(0)))
GO

ALTER TABLE [aiaf_governance].[AIReviewItem] CHECK CONSTRAINT [CK_AIReviewItem_DecisionMetadata]
GO

ALTER TABLE [aiaf_governance].[AIReviewItem]  WITH CHECK ADD  CONSTRAINT [CK_AIReviewItem_EvidenceJSON] CHECK  ((isjson([EvidenceSnapshot],OBJECT)=(1)))
GO

ALTER TABLE [aiaf_governance].[AIReviewItem] CHECK CONSTRAINT [CK_AIReviewItem_EvidenceJSON]
GO

ALTER TABLE [aiaf_governance].[AIReviewItem]  WITH CHECK ADD  CONSTRAINT [CK_AIReviewItem_Severity] CHECK  (([Severity]='CRITICAL' OR [Severity]='HIGH' OR [Severity]='MEDIUM' OR [Severity]='LOW' OR [Severity]='INFO'))
GO

ALTER TABLE [aiaf_governance].[AIReviewItem] CHECK CONSTRAINT [CK_AIReviewItem_Severity]
GO
