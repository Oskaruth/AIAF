SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [aiaf_governance].[AIReview](
	[ReviewId] [bigint] IDENTITY(1,1) NOT NULL,
	[ApplicationCode] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[ReviewName] [varchar](800) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[ReviewPeriodStart] [datetime2](3) NOT NULL,
	[ReviewPeriodEnd] [datetime2](3) NOT NULL,
	[AccountableOwner] [varchar](1024) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[DueAt] [datetime2](3) NOT NULL,
	[ReviewStatus] [varchar](30) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[FrozenAt] [datetime2](3) NULL,
	[CompletedAt] [datetime2](3) NULL,
	[EvidencePackage] [varchar](max) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
	[EvidencePackageHash] [binary](32) NULL,
 CONSTRAINT [PK_AIReview] PRIMARY KEY CLUSTERED
(
	[ReviewId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_AIReview_Application_Period] UNIQUE NONCLUSTERED
(
	[ApplicationCode] ASC,
	[ReviewPeriodStart] ASC,
	[ReviewPeriodEnd] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

ALTER AUTHORIZATION ON [aiaf_governance].[AIReview] TO  SCHEMA OWNER
GO

ALTER TABLE [aiaf_governance].[AIReview] ADD  CONSTRAINT [DF_AIReview_Status]  DEFAULT ('DRAFT') FOR [ReviewStatus]
GO

ALTER TABLE [aiaf_governance].[AIReview] ADD  CONSTRAINT [DF_AIReview_CreatedAt]  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [aiaf_governance].[AIReview]  WITH CHECK ADD  CONSTRAINT [CK_AIReview_Completion] CHECK  (([ReviewStatus]='COMPLETED' AND [CompletedAt] IS NOT NULL OR [ReviewStatus]<>'COMPLETED' AND [CompletedAt] IS NULL))
GO

ALTER TABLE [aiaf_governance].[AIReview] CHECK CONSTRAINT [CK_AIReview_Completion]
GO

ALTER TABLE [aiaf_governance].[AIReview]  WITH CHECK ADD  CONSTRAINT [CK_AIReview_EvidenceJSON] CHECK  ((isjson([EvidencePackage],OBJECT)=(1)))
GO

ALTER TABLE [aiaf_governance].[AIReview] CHECK CONSTRAINT [CK_AIReview_EvidenceJSON]
GO

ALTER TABLE [aiaf_governance].[AIReview]  WITH CHECK ADD  CONSTRAINT [CK_AIReview_FrozenEvidence] CHECK  (([FrozenAt] IS NULL AND [EvidencePackage] IS NULL AND [EvidencePackageHash] IS NULL OR [FrozenAt] IS NOT NULL AND [EvidencePackage] IS NOT NULL AND [EvidencePackageHash] IS NOT NULL))
GO

ALTER TABLE [aiaf_governance].[AIReview] CHECK CONSTRAINT [CK_AIReview_FrozenEvidence]
GO

ALTER TABLE [aiaf_governance].[AIReview]  WITH CHECK ADD  CONSTRAINT [CK_AIReview_FrozenStatus] CHECK  ((NOT ([ReviewStatus]='COMPLETED' OR [ReviewStatus]='FROZEN') OR [FrozenAt] IS NOT NULL))
GO

ALTER TABLE [aiaf_governance].[AIReview] CHECK CONSTRAINT [CK_AIReview_FrozenStatus]
GO

ALTER TABLE [aiaf_governance].[AIReview]  WITH CHECK ADD  CONSTRAINT [CK_AIReview_Period] CHECK  (([ReviewPeriodEnd]>[ReviewPeriodStart]))
GO

ALTER TABLE [aiaf_governance].[AIReview] CHECK CONSTRAINT [CK_AIReview_Period]
GO

ALTER TABLE [aiaf_governance].[AIReview]  WITH CHECK ADD  CONSTRAINT [CK_AIReview_Status] CHECK  (([ReviewStatus]='CANCELLED' OR [ReviewStatus]='COMPLETED' OR [ReviewStatus]='FROZEN' OR [ReviewStatus]='IN_REVIEW' OR [ReviewStatus]='DRAFT'))
GO

ALTER TABLE [aiaf_governance].[AIReview] CHECK CONSTRAINT [CK_AIReview_Status]
GO
