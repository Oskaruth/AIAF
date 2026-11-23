SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [acme].[Invoice](
	[InvoiceId] [bigint] IDENTITY(1,1) NOT NULL,
	[CustomerId] [bigint] NOT NULL,
	[InvoiceNumber] [varchar](50) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NOT NULL,
	[InvoiceDate] [date] NOT NULL,
	[DueDate] [date] NOT NULL,
	[InvoiceAmount] [decimal](19, 2) NOT NULL,
	[OutstandingAmount] [decimal](19, 2) NOT NULL,
	[IsDisputed] [bit] NOT NULL,
 CONSTRAINT [PK_Invoice] PRIMARY KEY CLUSTERED
(
	[InvoiceId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Invoice_InvoiceNumber] UNIQUE NONCLUSTERED
(
	[InvoiceNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

GO

ALTER AUTHORIZATION ON [acme].[Invoice] TO  SCHEMA OWNER
GO

ALTER TABLE [acme].[Invoice] ADD  DEFAULT ((0)) FOR [IsDisputed]
GO

ALTER TABLE [acme].[Invoice]  WITH CHECK ADD  CONSTRAINT [CK_Invoice_Amounts] CHECK  (([InvoiceAmount]>=(0) AND [OutstandingAmount]>=(0) AND [OutstandingAmount]<=[InvoiceAmount]))
GO

ALTER TABLE [acme].[Invoice] CHECK CONSTRAINT [CK_Invoice_Amounts]
GO

ALTER TABLE [acme].[Invoice]  WITH CHECK ADD  CONSTRAINT [CK_Invoice_Dates] CHECK  (([DueDate]>=[InvoiceDate]))
GO

ALTER TABLE [acme].[Invoice] CHECK CONSTRAINT [CK_Invoice_Dates]
GO
