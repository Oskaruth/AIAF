ALTER TABLE [aiaf].[AIValidation]  WITH CHECK ADD  CONSTRAINT [FK_AIValidation_AIInteraction] FOREIGN KEY([InteractionId])
REFERENCES [aiaf].[AIInteraction] ([InteractionId])
GO

ALTER TABLE [aiaf].[AIValidation] CHECK CONSTRAINT [FK_AIValidation_AIInteraction]
GO
