ALTER TABLE [aiaf_governance].[AIReviewAction]  WITH CHECK ADD  CONSTRAINT [FK_AIReviewAction_AIReviewItem] FOREIGN KEY([ReviewItemId])
REFERENCES [aiaf_governance].[AIReviewItem] ([ReviewItemId])
GO

ALTER TABLE [aiaf_governance].[AIReviewAction] CHECK CONSTRAINT [FK_AIReviewAction_AIReviewItem]
GO
