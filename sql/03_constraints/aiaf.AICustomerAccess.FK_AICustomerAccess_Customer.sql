ALTER TABLE [aiaf].[AICustomerAccess]  WITH CHECK ADD  CONSTRAINT [FK_AICustomerAccess_Customer] FOREIGN KEY([CustomerId])
REFERENCES [acme].[Customer] ([CustomerId])
GO

ALTER TABLE [aiaf].[AICustomerAccess] CHECK CONSTRAINT [FK_AICustomerAccess_Customer]
GO
