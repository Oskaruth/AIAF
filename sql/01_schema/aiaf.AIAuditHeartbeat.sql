SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [aiaf].[AIAuditHeartbeat](
	[AuditHeartbeatId] [bigint] IDENTITY(1,1) NOT NULL,
	[PipelineName] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[ProcessedEventCount] [int] NOT NULL,
	[HeartbeatAt] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_AIAuditHeartbeat] PRIMARY KEY CLUSTERED
(
	[AuditHeartbeatId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

GO

ALTER AUTHORIZATION ON [aiaf].[AIAuditHeartbeat] TO  SCHEMA OWNER
GO

ALTER TABLE [aiaf].[AIAuditHeartbeat]  WITH CHECK ADD  CONSTRAINT [CK_AIAuditHeartbeat_EventCount] CHECK  (([ProcessedEventCount]>=(0)))
GO

ALTER TABLE [aiaf].[AIAuditHeartbeat] CHECK CONSTRAINT [CK_AIAuditHeartbeat_EventCount]
GO
