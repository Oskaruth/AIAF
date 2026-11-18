ALTER TABLE [aiaf].[AICustomerAccess]  WITH CHECK ADD  CONSTRAINT [FK_AICustomerAccess_AIApplication] FOREIGN KEY([ApplicationId])
REFERENCES [aiaf].[AIApplication] ([ApplicationId])
GO

ALTER TABLE [aiaf].[AICustomerAccess] CHECK CONSTRAINT [FK_AICustomerAccess_AIApplication]
GO
