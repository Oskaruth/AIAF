/*
    AIAF Synthetic Governance Reviews

    Creates two laboratory governance scenarios:

        Customer Service AI:
            Critical audit pipeline finding
            Suspension recommended
            Open remediation action

        Accounts Receivable AI:
            Initial application review
            Approval recommended

    All evidence is explicitly synthetic.

    Evidence packages and attestations will be
    generated separately through AIAF procedures.

    Intended exclusively for demonstration and
    integration testing.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @Now datetime2(3) = SYSUTCDATETIME(),
    @CustomerServiceReviewId bigint,
    @AccountsReceivableReviewId bigint,
    @SuspensionReviewItemId bigint;

BEGIN TRANSACTION;

-- =====================================================
-- Customer Service AI governance review
-- =====================================================

INSERT INTO aiaf_governance.AIReview
(
    ApplicationCode,
    ReviewName,
    ReviewPeriodStart,
    ReviewPeriodEnd,
    AccountableOwner,
    DueAt,
    ReviewStatus,
    CreatedAt
)
SELECT
    ApplicationCode,
    'Synthetic Customer Service AI Governance Review',
    DATEADD(DAY, -30, @Now),
    @Now,
    AccountableOwner,
    DATEADD(DAY, 14, @Now),
    'IN_REVIEW',
    @Now
FROM aiaf.AIApplication
WHERE ApplicationCode = 'ACME_CUSTOMER_SERVICE_AI';

IF @@ROWCOUNT <> 1
BEGIN
    THROW 52612,
        'Customer Service application configuration not found.',
        1;
END;

SET @CustomerServiceReviewId = SCOPE_IDENTITY();

-- =====================================================
-- Accounts Receivable AI governance review
-- =====================================================

INSERT INTO aiaf_governance.AIReview
(
    ApplicationCode,
    ReviewName,
    ReviewPeriodStart,
    ReviewPeriodEnd,
    AccountableOwner,
    DueAt,
    ReviewStatus,
    CreatedAt
)
SELECT
    ApplicationCode,
    'Synthetic Accounts Receivable AI Governance Review',
    DATEADD(DAY, -30, @Now),
    @Now,
    AccountableOwner,
    DATEADD(DAY, 14, @Now),
    'IN_REVIEW',
    @Now
FROM aiaf.AIApplication
WHERE ApplicationCode = 'ACME_ACCOUNTS_RECEIVABLE_AI';

IF @@ROWCOUNT <> 1
BEGIN
    THROW 52613,
        'Accounts Receivable application configuration not found.',
        1;
END;

SET @AccountsReceivableReviewId = SCOPE_IDENTITY();

-- =====================================================
-- Synthetic audit pipeline failure
-- =====================================================

INSERT INTO aiaf_governance.AIReviewItem
(
    ReviewId,
    ReviewArea,
    FindingCode,
    FindingDescription,
    Severity,
    EvidenceSnapshot,
    EvidenceEvaluatedAt,
    ReviewerIdentity,
    ReviewerDecision,
    DecisionReason,
    DecisionAt,
    CreatedAt
)
VALUES
(
    @CustomerServiceReviewId,
    'AUDIT_PIPELINE',
    'STALE',
    'Simulated audit pipeline failure requiring application suspension.',
    'CRITICAL',
    N'{
        "EvidenceType": "LAB_SIMULATION",
        "SyntheticEvidence": true,
        "PipelineName": "AIAF_SYNTHETIC_STOPPED",
        "MinutesSinceHeartbeat": 47,
        "StaleThresholdMinutes": 15,
        "EvaluationResult": "STALE",
        "Scope": "Synthetic governance suspension scenario."
    }',
    @Now,
    'data.operations@acme.example',
    'SUSPEND',
    'Suspend application operation until audit processing and evidence completeness are verified.',
    @Now,
    @Now
);

SET @SuspensionReviewItemId = SCOPE_IDENTITY();

-- =====================================================
-- Synthetic remediation action
-- =====================================================

INSERT INTO aiaf_governance.AIReviewAction
(
    ReviewItemId,
    ActionDescription,
    AssignedOwner,
    DueAt,
    ActionStatus,
    CreatedAt
)
VALUES
(
    @SuspensionReviewItemId,
    'Restore audit processing, reconcile missing evidence and verify recovery before resuming operation.',
    'data.operations@acme.example',
    DATEADD(DAY, 7, @Now),
    'OPEN',
    @Now
);

-- =====================================================
-- Synthetic initial application acceptance
-- =====================================================

INSERT INTO aiaf_governance.AIReviewItem
(
    ReviewId,
    ReviewArea,
    FindingCode,
    FindingDescription,
    Severity,
    EvidenceSnapshot,
    EvidenceEvaluatedAt,
    ReviewerIdentity,
    ReviewerDecision,
    DecisionReason,
    DecisionAt,
    CreatedAt
)
VALUES
(
    @AccountsReceivableReviewId,
    'INITIAL_GOVERNANCE',
    'LAB_APPLICATION_ACCEPTED',
    'Simulated initial review for laboratory testing.',
    'INFO',
    N'{
        "EvidenceType": "LAB_SIMULATION",
        "EvaluationCode": "INITIAL_APPLICATION_REVIEW",
        "EvaluationResult": "ACCEPTED",
        "SyntheticEvidence": true,
        "Scope": "Approval for controlled AIAF laboratory testing only."
    }',
    @Now,
    'data.governance@acme.example',
    'ACCEPTED',
    'Synthetic approval scenario for controlled laboratory testing.',
    @Now,
    @Now
);

COMMIT TRANSACTION;

PRINT 'AIAF synthetic governance reviews created.';
GO