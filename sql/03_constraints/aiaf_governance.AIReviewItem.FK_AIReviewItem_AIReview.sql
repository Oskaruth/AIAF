ALTER TABLE [aiaf_governance].[AIReviewItem]  WITH CHECK ADD  CONSTRAINT [FK_AIReviewItem_AIReview] FOREIGN KEY([ReviewId])
REFERENCES [aiaf_governance].[AIReview] ([ReviewId])
GO

ALTER TABLE [aiaf_governance].[AIReviewItem] CHECK CONSTRAINT [FK_AIReviewItem_AIReview]
GO
