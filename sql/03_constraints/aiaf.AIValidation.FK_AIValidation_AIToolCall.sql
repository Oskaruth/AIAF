ALTER TABLE [aiaf].[AIValidation]  WITH CHECK ADD  CONSTRAINT [FK_AIValidation_AIToolCall] FOREIGN KEY([AIToolCallId])
REFERENCES [aiaf].[AIToolCall] ([AIToolCallId])
GO

ALTER TABLE [aiaf].[AIValidation] CHECK CONSTRAINT [FK_AIValidation_AIToolCall]
GO
