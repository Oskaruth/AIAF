ALTER TABLE [aiaf].[AIModelToolRequest]  WITH CHECK ADD  CONSTRAINT [FK_AIModelToolRequest_ModelExecution] FOREIGN KEY([ModelExecutionId])
REFERENCES [aiaf].[AIModelExecution] ([ModelExecutionId])
GO

ALTER TABLE [aiaf].[AIModelToolRequest] CHECK CONSTRAINT [FK_AIModelToolRequest_ModelExecution]
GO
