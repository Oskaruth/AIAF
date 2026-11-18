SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [aiaf].[AIApplication](
	[ApplicationId] [bigint] IDENTITY(1,1) NOT NULL,
	[ApplicationCode] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[ApplicationName] [varchar](400) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[BusinessPurpose] [varchar](4000) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[AccountableOwner] [varchar](1024) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[RiskClassification] [varchar](20) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[IsEnabled] [bit] NOT NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_AIApplication] PRIMARY KEY CLUSTERED
(
	[ApplicationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_AIApplication_ApplicationCode] UNIQUE NONCLUSTERED
(
	[ApplicationCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

GO

ALTER AUTHORIZATION ON [aiaf].[AIApplication] TO  SCHEMA OWNER
GO

ALTER TABLE [aiaf].[AIApplication] ADD  CONSTRAINT [DF_AIApplication_IsEnabled]  DEFAULT ((0)) FOR [IsEnabled]
GO

ALTER TABLE [aiaf].[AIApplication] ADD  CONSTRAINT [DF_AIApplication_CreatedAt]  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [aiaf].[AIApplication]  WITH CHECK ADD  CONSTRAINT [CK_AIApplication_Accountability] CHECK  ((len(Trim([AccountableOwner]))>(0) AND len(Trim([BusinessPurpose]))>(0)))
GO

ALTER TABLE [aiaf].[AIApplication] CHECK CONSTRAINT [CK_AIApplication_Accountability]
GO

ALTER TABLE [aiaf].[AIApplication]  WITH CHECK ADD  CONSTRAINT [CK_AIApplication_RiskClassification] CHECK  (([RiskClassification]='CRITICAL' OR [RiskClassification]='HIGH' OR [RiskClassification]='MEDIUM' OR [RiskClassification]='LOW'))
GO

ALTER TABLE [aiaf].[AIApplication] CHECK CONSTRAINT [CK_AIApplication_RiskClassification]
GO
