SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [aiaf_governance].[AIReviewAction](
	[ReviewActionId] [bigint] IDENTITY(1,1) NOT NULL,
	[ReviewItemId] [bigint] NOT NULL,
	[ActionDescription] [varchar](8000) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[AssignedOwner] [varchar](1024) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[DueAt] [datetime2](3) NOT NULL,
	[ActionStatus] [varchar](30) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[CompletedAt] [datetime2](3) NULL,
	[CompletionEvidence] [varchar](max) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
 CONSTRAINT [PK_AIReviewAction] PRIMARY KEY CLUSTERED
(
	[ReviewActionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

ALTER AUTHORIZATION ON [aiaf_governance].[AIReviewAction] TO  SCHEMA OWNER
GO

ALTER TABLE [aiaf_governance].[AIReviewAction] ADD  CONSTRAINT [DF_AIReviewAction_Status]  DEFAULT ('OPEN') FOR [ActionStatus]
GO

ALTER TABLE [aiaf_governance].[AIReviewAction] ADD  CONSTRAINT [DF_AIReviewAction_CreatedAt]  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [aiaf_governance].[AIReviewAction]  WITH CHECK ADD  CONSTRAINT [CK_AIReviewAction_Completion] CHECK  (([ActionStatus]='COMPLETED' AND [CompletedAt] IS NOT NULL AND [CompletionEvidence] IS NOT NULL AND len(Trim([CompletionEvidence]))>(0) OR [ActionStatus]<>'COMPLETED' AND [CompletedAt] IS NULL))
GO

ALTER TABLE [aiaf_governance].[AIReviewAction] CHECK CONSTRAINT [CK_AIReviewAction_Completion]
GO

ALTER TABLE [aiaf_governance].[AIReviewAction]  WITH CHECK ADD  CONSTRAINT [CK_AIReviewAction_Owner] CHECK  ((len(Trim([AssignedOwner]))>(0)))
GO

ALTER TABLE [aiaf_governance].[AIReviewAction] CHECK CONSTRAINT [CK_AIReviewAction_Owner]
GO

ALTER TABLE [aiaf_governance].[AIReviewAction]  WITH CHECK ADD  CONSTRAINT [CK_AIReviewAction_Status] CHECK  (([ActionStatus]='CANCELLED' OR [ActionStatus]='COMPLETED' OR [ActionStatus]='IN_PROGRESS' OR [ActionStatus]='OPEN'))
GO

ALTER TABLE [aiaf_governance].[AIReviewAction] CHECK CONSTRAINT [CK_AIReviewAction_Status]
GO
