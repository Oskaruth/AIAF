ALTER TABLE [aiaf].[AIInteractionEvent]  WITH CHECK ADD  CONSTRAINT [FK_AIInteractionEvent_AIInteraction] FOREIGN KEY([InteractionId])
REFERENCES [aiaf].[AIInteraction] ([InteractionId])
GO

ALTER TABLE [aiaf].[AIInteractionEvent] CHECK CONSTRAINT [FK_AIInteractionEvent_AIInteraction]
GO
