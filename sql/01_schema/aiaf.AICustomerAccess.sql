SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [aiaf].[AICustomerAccess](
	[CustomerAccessId] [bigint] IDENTITY(1,1) NOT NULL,
	[ApplicationId] [bigint] NOT NULL,
	[RequestingIdentity] [varchar](1024) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[CustomerId] [bigint] NOT NULL,
	[CanRead] [bit] NOT NULL,
	[CanRequestFinancialAction] [bit] NOT NULL,
	[GrantedAt] [datetime2](3) NOT NULL,
	[GrantedBy] [varchar](1024) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[ExpiresAt] [datetime2](3) NULL,
	[IsEnabled] [bit] NOT NULL,
 CONSTRAINT [PK_AICustomerAccess] PRIMARY KEY CLUSTERED
(
	[CustomerAccessId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_AICustomerAccess] UNIQUE NONCLUSTERED
(
	[ApplicationId] ASC,
	[CustomerId] ASC,
	[RequestingIdentity] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

GO

ALTER AUTHORIZATION ON [aiaf].[AICustomerAccess] TO  SCHEMA OWNER
GO

ALTER TABLE [aiaf].[AICustomerAccess] ADD  DEFAULT ((0)) FOR [CanRead]
GO

ALTER TABLE [aiaf].[AICustomerAccess] ADD  DEFAULT ((0)) FOR [CanRequestFinancialAction]
GO

ALTER TABLE [aiaf].[AICustomerAccess] ADD  DEFAULT (sysutcdatetime()) FOR [GrantedAt]
GO

ALTER TABLE [aiaf].[AICustomerAccess] ADD  DEFAULT ((1)) FOR [IsEnabled]
GO

ALTER TABLE [aiaf].[AICustomerAccess]  WITH CHECK ADD  CONSTRAINT [CK_AICustomerAccess_Expiration] CHECK  (([ExpiresAt] IS NULL OR [ExpiresAt]>[GrantedAt]))
GO

ALTER TABLE [aiaf].[AICustomerAccess] CHECK CONSTRAINT [CK_AICustomerAccess_Expiration]
GO
