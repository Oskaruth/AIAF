SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE aiaf_governance.usp_AttestReview
    @ReviewId bigint,
    @AttestingIdentity varchar(1024),
    @AttestingRole varchar(100),
    @AttestationDecision varchar(30),
    @AttestationReason varchar(8000),
    @EvidencePackageHash varbinary(32)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ReviewStatus varchar(30);
    DECLARE @StoredHash binary(32);
    DECLARE @EvidencePackage varchar(max);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            @ReviewStatus = ReviewStatus,
            @StoredHash = EvidencePackageHash,
            @EvidencePackage = EvidencePackage
        FROM aiaf_governance.AIReview
            WITH (UPDLOCK, HOLDLOCK)
        WHERE ReviewId = @ReviewId;

        IF @ReviewStatus IS NULL
            THROW 51200, 'Review not found.', 1;

        IF @ReviewStatus <> 'FROZEN'
            THROW 51201, 'Review must be frozen before attestation.', 1;

        IF @EvidencePackageHash IS NULL
           OR DATALENGTH(@EvidencePackageHash) <> 32
           OR @StoredHash IS NULL
           OR @EvidencePackageHash <> @StoredHash
            THROW 51202, 'Evidence package hash does not match.', 1;

        IF @EvidencePackage IS NULL
           OR HASHBYTES('SHA2_256', @EvidencePackage) <> @StoredHash
            THROW 51203, 'Stored evidence package failed integrity verification.', 1;

        IF @AttestationDecision IS NULL
           OR @AttestationDecision NOT IN
           (
               'APPROVED',
               'CONDITIONALLY_APPROVED',
               'RESTRICTED',
               'SUSPENDED',
               'REJECTED'
           )
            THROW 51204, 'Invalid attestation decision.', 1;

        IF NULLIF(TRIM(@AttestingIdentity), '') IS NULL
           OR NULLIF(TRIM(@AttestingRole), '') IS NULL
           OR NULLIF(TRIM(@AttestationReason), '') IS NULL
            THROW 51205, 'Attestation accountability metadata is required.', 1;

        IF @AttestationDecision NOT IN ('SUSPENDED', 'REJECTED')
           AND EXISTS
           (
               SELECT 1
               FROM OPENJSON(@EvidencePackage, '$.ReviewItems')
               WITH
               (
                   ReviewerDecision varchar(30)
                       '$.ReviewerDecision'
               )
               WHERE ReviewerDecision = 'SUSPEND'
           )
            THROW 51206, 'Approval blocked by suspension decision.', 1;

        IF @AttestationDecision IN
           ('APPROVED', 'CONDITIONALLY_APPROVED')
           AND EXISTS
           (
               SELECT 1
               FROM OPENJSON(@EvidencePackage, '$.ReviewItems')
               WITH
               (
                   ReviewerDecision varchar(30)
                       '$.ReviewerDecision'
               )
               WHERE ReviewerDecision = 'RESTRICT'
           )
            THROW 51207, 'Approval blocked by restriction decision.', 1;

        IF @AttestationDecision = 'APPROVED'
           AND EXISTS
           (
               SELECT 1
               FROM OPENJSON(@EvidencePackage, '$.ReviewItems')
               WITH
               (
                   RemediationActions nvarchar(max) AS JSON
               ) AS i
               CROSS APPLY OPENJSON(i.RemediationActions)
               WITH
               (
                   ActionStatus varchar(30)
                       '$.ActionStatus'
               ) AS a
               WHERE a.ActionStatus <> 'COMPLETED'
           )
            THROW 51208, 'Unresolved remediation prevents unconditional approval.', 1;

        INSERT INTO aiaf_governance.AIReviewAttestation
        (
            ReviewId,
            AttestingIdentity,
            AttestingRole,
            AttestationDecision,
            AttestationReason,
            EvidencePackageHash
        )
        VALUES
        (
            @ReviewId,
            @AttestingIdentity,
            @AttestingRole,
            @AttestationDecision,
            @AttestationReason,
            @EvidencePackageHash
        );

        UPDATE aiaf_governance.AIReview
        SET
            ReviewStatus = 'COMPLETED',
            CompletedAt = SYSUTCDATETIME()
        WHERE ReviewId = @ReviewId;

        COMMIT TRANSACTION;

        SELECT
            AttestationId,
            ReviewId,
            AttestingIdentity,
            AttestationDecision,
            AttestedAt,
            CONVERT(varchar(64), EvidencePackageHash, 2)
                AS EvidencePackageHash
        FROM aiaf_governance.AIReviewAttestation
        WHERE ReviewId = @ReviewId;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;

GO

ALTER AUTHORIZATION ON [aiaf_governance].[usp_AttestReview] TO  SCHEMA OWNER
GO
