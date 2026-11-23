SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [aiaf].[AIDriftRule](
	[DriftRuleId] [bigint] IDENTITY(1,1) NOT NULL,
	[WorkflowCode] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[ToolCode] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[MinimumBaselineInteractions] [int] NOT NULL,
	[MinimumCurrentInteractions] [int] NOT NULL,
	[MinimumPercentagePointChange] [decimal](6, 2) NOT NULL,
	[IsEnabled] [bit] NOT NULL,
 CONSTRAINT [PK_AIDriftRule] PRIMARY KEY CLUSTERED
(
	[DriftRuleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_AIDriftRule_Workflow_Tool] UNIQUE NONCLUSTERED
(
	[WorkflowCode] ASC,
	[ToolCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

GO

ALTER AUTHORIZATION ON [aiaf].[AIDriftRule] TO  SCHEMA OWNER
GO

ALTER TABLE [aiaf].[AIDriftRule] ADD  CONSTRAINT [DF_AIDriftRule_IsEnabled]  DEFAULT ((1)) FOR [IsEnabled]
GO

ALTER TABLE [aiaf].[AIDriftRule]  WITH CHECK ADD  CONSTRAINT [CK_AIDriftRule_MinimumInteractions] CHECK  (([MinimumBaselineInteractions]>(0) AND [MinimumCurrentInteractions]>(0)))
GO

ALTER TABLE [aiaf].[AIDriftRule] CHECK CONSTRAINT [CK_AIDriftRule_MinimumInteractions]
GO

ALTER TABLE [aiaf].[AIDriftRule]  WITH CHECK ADD  CONSTRAINT [CK_AIDriftRule_PercentagePointChange] CHECK  (([MinimumPercentagePointChange]>(0) AND [MinimumPercentagePointChange]<=(100)))
GO

ALTER TABLE [aiaf].[AIDriftRule] CHECK CONSTRAINT [CK_AIDriftRule_PercentagePointChange]
GO
