SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE   PROCEDURE aiaf_governance.usp_FreezeReview
    @ReviewId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ReviewStatus varchar(30);
    DECLARE @FrozenAt datetime2(3) = SYSUTCDATETIME();
    DECLARE @EvidencePackage varchar(max);
    DECLARE @EvidencePackageHash binary(32);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @ReviewStatus = ReviewStatus
        FROM aiaf_governance.AIReview
            WITH (UPDLOCK, HOLDLOCK)
        WHERE ReviewId = @ReviewId;

        IF @ReviewStatus IS NULL
            THROW 51100, 'Review not found.', 1;

        IF @ReviewStatus NOT IN ('DRAFT', 'IN_REVIEW')
            THROW 51101, 'Review cannot be frozen in its current state.', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM aiaf_governance.AIReviewItem
                WITH (UPDLOCK, HOLDLOCK)
            WHERE ReviewId = @ReviewId
        )
            THROW 51102, 'Cannot freeze an empty review.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM aiaf_governance.AIReviewItem
                WITH (UPDLOCK, HOLDLOCK)
            WHERE ReviewId = @ReviewId
              AND ReviewerDecision = 'PENDING'
        )
            THROW 51103, 'Review contains pending decisions.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM aiaf_governance.AIReviewItem AS i
                WITH (UPDLOCK, HOLDLOCK)
            WHERE i.ReviewId = @ReviewId
              AND i.ReviewerDecision IN
                  ('INVESTIGATE', 'REMEDIATE',
                   'RESTRICT', 'SUSPEND')
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM aiaf_governance.AIReviewAction AS a
                      WITH (UPDLOCK, HOLDLOCK)
                  WHERE a.ReviewItemId = i.ReviewItemId
                    AND a.ActionStatus <> 'CANCELLED'
              )
        )
            THROW 51104, 'Required remediation action is missing.', 1;

        SELECT @EvidencePackage =
        (
            SELECT
                1 AS PackageVersion,
                r.ReviewId,
                r.ApplicationCode,
                r.ReviewName,
                r.ReviewPeriodStart,
                r.ReviewPeriodEnd,
                r.AccountableOwner,
                r.DueAt,
                @FrozenAt AS FrozenAt,

                JSON_QUERY
                (
                    (
                        SELECT
                            i.ReviewItemId,
                            i.ReviewArea,
                            i.FindingCode,
                            i.FindingDescription,
                            i.Severity,
                            i.EvidenceEvaluatedAt,

                            JSON_QUERY(i.EvidenceSnapshot)
                                AS EvidenceSnapshot,

                            i.ReviewerIdentity,
                            i.ReviewerDecision,
                            i.DecisionReason,
                            i.DecisionAt,

                            JSON_QUERY
                            (
                                (
                                    SELECT
                                        a.ReviewActionId,
                                        a.ActionDescription,
                                        a.AssignedOwner,
                                        a.DueAt,
                                        a.ActionStatus,
                                        a.CreatedAt,
                                        a.CompletedAt,
                                        a.CompletionEvidence
                                    FROM
                                        aiaf_governance.AIReviewAction AS a
                                        WITH (HOLDLOCK)
                                    WHERE a.ReviewItemId =
                                          i.ReviewItemId
                                    ORDER BY a.ReviewActionId
                                    FOR JSON PATH,
                                        INCLUDE_NULL_VALUES
                                )
                            ) AS RemediationActions

                        FROM aiaf_governance.AIReviewItem AS i
                            WITH (HOLDLOCK)
                        WHERE i.ReviewId = r.ReviewId
                        ORDER BY i.ReviewItemId
                        FOR JSON PATH, INCLUDE_NULL_VALUES
                    )
                ) AS ReviewItems

            FROM aiaf_governance.AIReview AS r
            WHERE r.ReviewId = @ReviewId
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        SET @EvidencePackageHash =
            HASHBYTES('SHA2_256', @EvidencePackage);

        UPDATE aiaf_governance.AIReview
        SET
            ReviewStatus = 'FROZEN',
            FrozenAt = @FrozenAt,
            EvidencePackage = @EvidencePackage,
            EvidencePackageHash = @EvidencePackageHash
        WHERE ReviewId = @ReviewId;

        COMMIT TRANSACTION;

        SELECT
            ReviewId,
            ReviewStatus,
            FrozenAt,
            DATALENGTH(EvidencePackage) AS PackageBytes,
            CONVERT(varchar(64), EvidencePackageHash, 2)
                AS EvidencePackageHash
        FROM aiaf_governance.AIReview
        WHERE ReviewId = @ReviewId;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;

GO

ALTER AUTHORIZATION ON [aiaf_governance].[usp_FreezeReview] TO  SCHEMA OWNER
GO
