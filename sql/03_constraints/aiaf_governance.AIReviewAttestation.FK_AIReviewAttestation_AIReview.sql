ALTER TABLE [aiaf_governance].[AIReviewAttestation]  WITH CHECK ADD  CONSTRAINT [FK_AIReviewAttestation_AIReview] FOREIGN KEY([ReviewId])
REFERENCES [aiaf_governance].[AIReview] ([ReviewId])
GO

ALTER TABLE [aiaf_governance].[AIReviewAttestation] CHECK CONSTRAINT [FK_AIReviewAttestation_AIReview]
GO
