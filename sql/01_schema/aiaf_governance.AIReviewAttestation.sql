SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [aiaf_governance].[AIReviewAttestation](
	[AttestationId] [bigint] IDENTITY(1,1) NOT NULL,
	[ReviewId] [bigint] NOT NULL,
	[AttestingIdentity] [varchar](1024) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[AttestingRole] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[AttestationDecision] [varchar](30) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[AttestationReason] [varchar](8000) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[EvidencePackageHash] [binary](32) NOT NULL,
	[AttestedAt] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_AIReviewAttestation] PRIMARY KEY CLUSTERED
(
	[AttestationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

GO

ALTER AUTHORIZATION ON [aiaf_governance].[AIReviewAttestation] TO  SCHEMA OWNER
GO

ALTER TABLE [aiaf_governance].[AIReviewAttestation] ADD  CONSTRAINT [DF_AIReviewAttestation_AttestedAt]  DEFAULT (sysutcdatetime()) FOR [AttestedAt]
GO

ALTER TABLE [aiaf_governance].[AIReviewAttestation]  WITH CHECK ADD  CONSTRAINT [CK_AIReviewAttestation_Decision] CHECK  (([AttestationDecision]='REJECTED' OR [AttestationDecision]='SUSPENDED' OR [AttestationDecision]='RESTRICTED' OR [AttestationDecision]='CONDITIONALLY_APPROVED' OR [AttestationDecision]='APPROVED'))
GO

ALTER TABLE [aiaf_governance].[AIReviewAttestation] CHECK CONSTRAINT [CK_AIReviewAttestation_Decision]
GO

ALTER TABLE [aiaf_governance].[AIReviewAttestation]  WITH CHECK ADD  CONSTRAINT [CK_AIReviewAttestation_Metadata] CHECK  ((len(Trim([AttestingIdentity]))>(0) AND len(Trim([AttestingRole]))>(0) AND len(Trim([AttestationReason]))>(0)))
GO

ALTER TABLE [aiaf_governance].[AIReviewAttestation] CHECK CONSTRAINT [CK_AIReviewAttestation_Metadata]
GO
