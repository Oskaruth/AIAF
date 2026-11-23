ALTER TABLE [aiaf].[AIToolCall]  WITH CHECK ADD  CONSTRAINT [FK_AIToolCall_AIInteraction] FOREIGN KEY([InteractionId])
REFERENCES [aiaf].[AIInteraction] ([InteractionId])
GO

ALTER TABLE [aiaf].[AIToolCall] CHECK CONSTRAINT [FK_AIToolCall_AIInteraction]
GO
