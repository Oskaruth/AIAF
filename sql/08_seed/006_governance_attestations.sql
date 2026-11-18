/*
    AIAF Synthetic Governance Attestations

    Completes the governance lifecycle for the two
    synthetic Acme AI applications.

    Customer Service AI:
        Attestation decision: SUSPENDED

    Accounts Receivable AI:
        Attestation decision: APPROVED

    Evidence packages and SHA-256 hashes are generated
    through the existing AIAF governance procedures.

    No historical evidence packages, hashes or
    attestations are imported.

    Intended exclusively for demonstration and
    integration testing.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @CustomerServiceReviewId bigint,
    @AccountsReceivableReviewId bigint,
    @CustomerServiceOwner varchar(1024),
    @AccountsReceivableOwner varchar(1024),
    @EvidencePackageHash binary(32);

-- =====================================================
-- Resolve synthetic governance reviews
-- =====================================================

SELECT
    @CustomerServiceReviewId = R.ReviewId,
    @CustomerServiceOwner = R.AccountableOwner
FROM aiaf_governance.AIReview AS R
WHERE R.ApplicationCode = 'ACME_CUSTOMER_SERVICE_AI'
    AND R.ReviewName =
        'Synthetic Customer Service AI Governance Review'
    AND R.ReviewStatus = 'IN_REVIEW';

IF @@ROWCOUNT <> 1
BEGIN
    THROW 52614,
        'Expected one Customer Service synthetic governance review.',
        1;
END;

SELECT
    @AccountsReceivableReviewId = R.ReviewId,
    @AccountsReceivableOwner = R.AccountableOwner
FROM aiaf_governance.AIReview AS R
WHERE R.ApplicationCode = 'ACME_ACCOUNTS_RECEIVABLE_AI'
    AND R.ReviewName =
        'Synthetic Accounts Receivable AI Governance Review'
    AND R.ReviewStatus = 'IN_REVIEW';

IF @@ROWCOUNT <> 1
BEGIN
    THROW 52615,
        'Expected one Accounts Receivable synthetic governance review.',
        1;
END;

-- =====================================================
-- Freeze Customer Service governance evidence
-- =====================================================

EXEC aiaf_governance.usp_FreezeReview
    @ReviewId = @CustomerServiceReviewId;

SET @EvidencePackageHash = NULL;

SELECT
    @EvidencePackageHash = EvidencePackageHash
FROM aiaf_governance.AIReview
WHERE ReviewId = @CustomerServiceReviewId
    AND ReviewStatus = 'FROZEN';

IF @EvidencePackageHash IS NULL
BEGIN
    THROW 52616,
        'Customer Service evidence package was not frozen successfully.',
        1;
END;

-- =====================================================
-- Suspend Customer Service AI
-- =====================================================

EXEC aiaf_governance.usp_AttestReview
    @ReviewId = @CustomerServiceReviewId,
    @AttestingIdentity = @CustomerServiceOwner,
    @AttestingRole = 'APPLICATION_OWNER',
    @AttestationDecision = 'SUSPENDED',
    @AttestationReason =
        'Synthetic laboratory suspension scenario. Application operation is not authorized until simulated audit pipeline deficiencies are resolved.',
    @EvidencePackageHash = @EvidencePackageHash;

-- =====================================================
-- Freeze Accounts Receivable governance evidence
-- =====================================================

EXEC aiaf_governance.usp_FreezeReview
    @ReviewId = @AccountsReceivableReviewId;

SET @EvidencePackageHash = NULL;

SELECT
    @EvidencePackageHash = EvidencePackageHash
FROM aiaf_governance.AIReview
WHERE ReviewId = @AccountsReceivableReviewId
    AND ReviewStatus = 'FROZEN';

IF @EvidencePackageHash IS NULL
BEGIN
    THROW 52617,
        'Accounts Receivable evidence package was not frozen successfully.',
        1;
END;

-- =====================================================
-- Approve Accounts Receivable AI
-- =====================================================

EXEC aiaf_governance.usp_AttestReview
    @ReviewId = @AccountsReceivableReviewId,
    @AttestingIdentity = @AccountsReceivableOwner,
    @AttestingRole = 'APPLICATION_OWNER',
    @AttestationDecision = 'APPROVED',
    @AttestationReason =
        'Synthetic approval for controlled AIAF laboratory testing only.',
    @EvidencePackageHash = @EvidencePackageHash;

-- =====================================================
-- Verify governance seed results
-- =====================================================

DECLARE @ExpectedResults TABLE
(
    ReviewId bigint PRIMARY KEY,
    AttestationDecision varchar(30)
        COLLATE DATABASE_DEFAULT NOT NULL
);

INSERT INTO @ExpectedResults
VALUES
    (@CustomerServiceReviewId, 'SUSPENDED'),
    (@AccountsReceivableReviewId, 'APPROVED');

IF EXISTS
(
    SELECT 1
    FROM @ExpectedResults AS E
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM aiaf_governance.AIReview AS R
        INNER JOIN aiaf_governance.AIReviewAttestation AS A
            ON A.ReviewId = R.ReviewId
        WHERE R.ReviewId = E.ReviewId
            AND R.ReviewStatus = 'COMPLETED'
            AND R.CompletedAt IS NOT NULL
            AND R.FrozenAt IS NOT NULL
            AND R.EvidencePackage IS NOT NULL
            AND R.EvidencePackageHash IS NOT NULL
            AND A.AttestationDecision = E.AttestationDecision
            AND A.EvidencePackageHash = R.EvidencePackageHash
            AND R.EvidencePackageHash =
                HASHBYTES('SHA2_256', R.EvidencePackage)
    )
)
BEGIN
    THROW 52618,
        'Synthetic governance attestation verification failed.',
        1;
END;

SELECT
    R.ApplicationCode,
    R.ReviewId,
    R.ReviewStatus,
    A.AttestationDecision,
    R.FrozenAt,
    R.CompletedAt,
    R.EvidencePackageHash,
    'PASS' AS VerificationResult
FROM aiaf_governance.AIReview AS R
INNER JOIN aiaf_governance.AIReviewAttestation AS A
    ON A.ReviewId = R.ReviewId
WHERE R.ReviewId IN
(
    @CustomerServiceReviewId,
    @AccountsReceivableReviewId
)
ORDER BY R.ApplicationCode;

PRINT 'AIAF synthetic governance attestations created and verified.';
GO