ALTER TABLE [aiaf].[AIToolCall]  WITH CHECK ADD  CONSTRAINT [FK_AIToolCall_ModelToolRequest] FOREIGN KEY([ModelToolRequestId])
REFERENCES [aiaf].[AIModelToolRequest] ([ModelToolRequestId])
GO

ALTER TABLE [aiaf].[AIToolCall] CHECK CONSTRAINT [FK_AIToolCall_ModelToolRequest]
GO
