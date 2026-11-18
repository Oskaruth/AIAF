ALTER TABLE [acme].[Invoice]  WITH CHECK ADD  CONSTRAINT [FK_Invoice_Customer] FOREIGN KEY([CustomerId])
REFERENCES [acme].[Customer] ([CustomerId])
GO

ALTER TABLE [acme].[Invoice] CHECK CONSTRAINT [FK_Invoice_Customer]
GO
