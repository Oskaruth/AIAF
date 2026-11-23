SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [aiaf].[AIModelToolRequest](
	[ModelToolRequestId] [bigint] IDENTITY(1,1) NOT NULL,
	[ModelExecutionId] [bigint] NOT NULL,
	[ToolCode] [varchar](100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[RequestArguments] [varchar](max) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[RequestedAt] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_AIModelToolRequest] PRIMARY KEY CLUSTERED
(
	[ModelToolRequestId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_AIModelToolRequest_ModelExecution] UNIQUE NONCLUSTERED
(
	[ModelExecutionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

ALTER AUTHORIZATION ON [aiaf].[AIModelToolRequest] TO  SCHEMA OWNER
GO

ALTER TABLE [aiaf].[AIModelToolRequest] ADD  CONSTRAINT [DF_AIModelToolRequest_RequestedAt]  DEFAULT (sysutcdatetime()) FOR [RequestedAt]
GO

ALTER TABLE [aiaf].[AIModelToolRequest]  WITH CHECK ADD  CONSTRAINT [CK_AIModelToolRequest_Arguments] CHECK  ((isjson([RequestArguments],OBJECT)=(1)))
GO

ALTER TABLE [aiaf].[AIModelToolRequest] CHECK CONSTRAINT [CK_AIModelToolRequest_Arguments]
GO

ALTER TABLE [aiaf].[AIModelToolRequest]  WITH CHECK ADD  CONSTRAINT [CK_AIModelToolRequest_ToolCode] CHECK  ((len(Trim([ToolCode]))>(0)))
GO

ALTER TABLE [aiaf].[AIModelToolRequest] CHECK CONSTRAINT [CK_AIModelToolRequest_ToolCode]
GO
