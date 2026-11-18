ALTER TABLE [aiaf].[AIModelExecution]  WITH CHECK ADD  CONSTRAINT [FK_AIModelExecution_AIInteraction] FOREIGN KEY([InteractionId])
REFERENCES [aiaf].[AIInteraction] ([InteractionId])
GO

ALTER TABLE [aiaf].[AIModelExecution] CHECK CONSTRAINT [FK_AIModelExecution_AIInteraction]
GO
