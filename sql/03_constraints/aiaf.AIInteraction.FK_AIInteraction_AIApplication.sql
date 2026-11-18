ALTER TABLE [aiaf].[AIInteraction]  WITH CHECK ADD  CONSTRAINT [FK_AIInteraction_AIApplication] FOREIGN KEY([ApplicationId])
REFERENCES [aiaf].[AIApplication] ([ApplicationId])
GO

ALTER TABLE [aiaf].[AIInteraction] CHECK CONSTRAINT [FK_AIInteraction_AIApplication]
GO
