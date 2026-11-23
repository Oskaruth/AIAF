/*
    AIAF integration-test fixture (LAB ONLY)

    Run after sql/08_seed/006_governance_attestations.sql.
    Does not alter the ACME application governance decisions.
    Re-runnable: refuses to overwrite existing, divergent governance state.
    Intended for isolated integration-test databases only.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @Now datetime2(3) = SYSUTCDATETIME(),
    @ApplicationId bigint,
    @TestCustomerId bigint,
    @ReviewId bigint,
    @EvidencePackageHash binary(32),
    @ApplicationCode varchar(100) = 'AIAF_APPROVED_TEST',
    @ReviewName varchar(255) = 'AIAF Approved Path - Initial Governance Review';

-- Register functional-test application, without changing existing configuration.
IF NOT EXISTS (SELECT 1 FROM aiaf.AIApplication WHERE ApplicationCode = @ApplicationCode)
BEGIN
    INSERT INTO aiaf.AIApplication
        (ApplicationCode, ApplicationName, BusinessPurpose,
         AccountableOwner, RiskClassification, IsEnabled)
    VALUES
        (@ApplicationCode, 'AIAF Approved Path Functional Test',
         'Validate the AIAF governance approval and interaction lifecycle in an isolated test database.',
         'AIAF Functional Test', 'LOW', 1);
END;

SELECT @ApplicationId = ApplicationId
FROM aiaf.AIApplication
WHERE ApplicationCode = @ApplicationCode
  AND ApplicationName = 'AIAF Approved Path Functional Test'
  AND AccountableOwner = 'AIAF Functional Test'
  AND RiskClassification = 'LOW'
  AND IsEnabled = 1;

IF @ApplicationId IS NULL
    THROW 52702, 'Existing functional-test application differs from expected fixture configuration.', 1;

-- Create a single review only if the application has no governance review yet.
IF NOT EXISTS (SELECT 1 FROM aiaf_governance.AIReview WHERE ApplicationCode = @ApplicationCode)
BEGIN
    INSERT INTO aiaf_governance.AIReview
        (ApplicationCode, ReviewName, ReviewPeriodStart, ReviewPeriodEnd,
         AccountableOwner, DueAt, ReviewStatus, CreatedAt)
    VALUES
        (@ApplicationCode, @ReviewName, DATEADD(DAY, -30, @Now), @Now,
         'AIAF Functional Test', DATEADD(DAY, 14, @Now), 'IN_REVIEW', @Now);

    SET @ReviewId = CONVERT(bigint, SCOPE_IDENTITY());

    INSERT INTO aiaf_governance.AIReviewItem
        (ReviewId, ReviewArea, FindingCode, FindingDescription, Severity,
         EvidenceSnapshot, EvidenceEvaluatedAt, ReviewerIdentity,
         ReviewerDecision, DecisionReason, DecisionAt, CreatedAt)
    VALUES
        (@ReviewId, 'INITIAL_GOVERNANCE', 'LAB_APPLICATION_ACCEPTED',
         'Synthetic initial review of the AIAF approved-path functional-test application.',
         'INFO',
         N'{"EvidenceType":"LAB_SIMULATION","SyntheticEvidence":true,"EvaluationResult":"ACCEPTED","Scope":"AIAF integration testing only"}',
         @Now, 'AIAF_FUNCTIONAL_TEST_SETUP', 'ACCEPTED',
         'Approved solely for controlled functional integration testing.',
         @Now, @Now);

    -- Procedures own the evidence package, hash, and attestation lifecycle.
    EXEC aiaf_governance.usp_FreezeReview @ReviewId = @ReviewId;

    SELECT @EvidencePackageHash = EvidencePackageHash
    FROM aiaf_governance.AIReview
    WHERE ReviewId = @ReviewId AND ReviewStatus = 'FROZEN';

    IF @EvidencePackageHash IS NULL
        THROW 52703, 'Failed to freeze functional-test governance evidence.', 1;

    EXEC aiaf_governance.usp_AttestReview
        @ReviewId = @ReviewId,
        @AttestingIdentity = 'AIAF Functional Test',
        @AttestingRole = 'APPLICATION_OWNER',
        @AttestationDecision = 'APPROVED',
        @AttestationReason = 'Synthetic approval for isolated AIAF integration tests only.',
        @EvidencePackageHash = @EvidencePackageHash;
END;

-- Require exactly one valid, approved review; never silently repair a mismatch.
IF (SELECT COUNT(*) FROM aiaf_governance.AIReview WHERE ApplicationCode = @ApplicationCode) <> 1
    THROW 52704, 'Functional-test application must have exactly one governance review.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM aiaf_governance.AIReview AS r
    JOIN aiaf_governance.AIReviewAttestation AS a ON a.ReviewId = r.ReviewId
    WHERE r.ApplicationCode = @ApplicationCode
      AND r.ReviewName = @ReviewName
      AND r.ReviewStatus = 'COMPLETED'
      AND a.AttestationDecision = 'APPROVED'
      AND r.EvidencePackage IS NOT NULL
      AND r.EvidencePackageHash IS NOT NULL
      AND a.EvidencePackageHash = r.EvidencePackageHash
      AND HASHBYTES('SHA2_256', r.EvidencePackage) = r.EvidencePackageHash
)
    THROW 52705, 'Functional-test governance approval or evidence verification failed.', 1;

-- Install dedicated integration-test financial data. Never repurpose ACME demo customers.
BEGIN TRANSACTION;

SELECT @TestCustomerId = CustomerId
FROM acme.Customer WITH (UPDLOCK, HOLDLOCK)
WHERE CustomerCode = 'CUST-0001';

IF @TestCustomerId IS NULL
BEGIN
    INSERT INTO acme.Customer (CustomerCode, CustomerName, CreditLimit, IsActive)
    VALUES ('CUST-0001', 'AIAF Functional Test Customer', 25000.00, 1);
    SET @TestCustomerId = CONVERT(bigint, SCOPE_IDENTITY());
END;

IF NOT EXISTS
(
    SELECT 1 FROM acme.Customer
    WHERE CustomerId = @TestCustomerId
      AND CustomerCode = 'CUST-0001'
      AND CustomerName = 'AIAF Functional Test Customer'
      AND IsActive = 1
)
    THROW 52709, 'Existing CUST-0001 differs from the integration fixture.', 1;

-- The tool aggregates outstanding amounts, including disputed outstanding amounts.
IF NOT EXISTS (SELECT 1 FROM acme.Invoice WHERE InvoiceNumber = 'AIAF-TEST-001')
    INSERT INTO acme.Invoice
        (CustomerId, InvoiceNumber, InvoiceDate, DueDate,
         InvoiceAmount, OutstandingAmount, IsDisputed)
    VALUES
        (@TestCustomerId, 'AIAF-TEST-001', '2026-10-01', '2026-10-31',
         1000.00, 1000.00, 0);

IF NOT EXISTS (SELECT 1 FROM acme.Invoice WHERE InvoiceNumber = 'AIAF-TEST-002')
    INSERT INTO acme.Invoice
        (CustomerId, InvoiceNumber, InvoiceDate, DueDate,
         InvoiceAmount, OutstandingAmount, IsDisputed)
    VALUES
        (@TestCustomerId, 'AIAF-TEST-002', '2026-10-01', '2026-10-31',
         750.00, 750.00, 1);

-- Reject existing divergent invoice data, including extra invoices for this customer.
IF (SELECT COUNT(*) FROM acme.Invoice WHERE CustomerId = @TestCustomerId) <> 2
   OR NOT EXISTS
   (
       SELECT 1 FROM acme.Invoice
       WHERE CustomerId = @TestCustomerId AND InvoiceNumber = 'AIAF-TEST-001'
         AND InvoiceAmount = 1000.00 AND OutstandingAmount = 1000.00 AND IsDisputed = 0
   )
   OR NOT EXISTS
   (
       SELECT 1 FROM acme.Invoice
       WHERE CustomerId = @TestCustomerId AND InvoiceNumber = 'AIAF-TEST-002'
         AND InvoiceAmount = 750.00 AND OutstandingAmount = 750.00 AND IsDisputed = 1
   )
    THROW 52710, 'Integration-test invoices differ from the expected fixture.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM acme.Invoice
    WHERE CustomerId = @TestCustomerId
    GROUP BY CustomerId
    HAVING SUM(OutstandingAmount) = 1750.00
       AND SUM(CASE WHEN IsDisputed = 1 THEN OutstandingAmount ELSE 0 END) = 750.00
       AND SUM(CASE WHEN OutstandingAmount > 0 THEN 1 ELSE 0 END) = 2
       AND SUM(CASE WHEN IsDisputed = 1 AND OutstandingAmount > 0 THEN 1 ELSE 0 END) = 1
)
    THROW 52711, 'Integration-test invoice aggregates do not match Python expectations.', 1;

-- Migrate only the two fixture identities away from the old CustomerId=1 grants.
-- Never touch unrelated application/customer authorizations.
DELETE FROM aiaf.AICustomerAccess
WHERE ApplicationId = @ApplicationId
  AND CustomerId = 1
  AND @TestCustomerId <> 1
  AND RequestingIdentity IN ('aiaf-functional-test-user', 'aiaf-expired-test-user')
  AND CanRead = 1 AND CanRequestFinancialAction = 0
  AND GrantedBy IN ('AIAF_FUNCTIONAL_TEST_SETUP', 'AIAF_INTEGRATION_TEST_SETUP');

IF NOT EXISTS
(
    SELECT 1 FROM aiaf.AICustomerAccess
    WHERE ApplicationId = @ApplicationId AND CustomerId = @TestCustomerId
      AND RequestingIdentity = 'aiaf-functional-test-user'
)
BEGIN
    INSERT INTO aiaf.AICustomerAccess
        (ApplicationId, RequestingIdentity, CustomerId, CanRead,
         CanRequestFinancialAction, GrantedAt, GrantedBy, ExpiresAt, IsEnabled)
    VALUES
        (@ApplicationId, 'aiaf-functional-test-user', @TestCustomerId, 1, 0,
         @Now, 'AIAF_FUNCTIONAL_TEST_SETUP', NULL, 1);
END;

IF NOT EXISTS
(
    SELECT 1 FROM aiaf.AICustomerAccess
    WHERE ApplicationId = @ApplicationId AND CustomerId = @TestCustomerId
      AND RequestingIdentity = 'aiaf-expired-test-user'
)
BEGIN
    INSERT INTO aiaf.AICustomerAccess
        (ApplicationId, RequestingIdentity, CustomerId, CanRead,
         CanRequestFinancialAction, GrantedAt, GrantedBy, ExpiresAt, IsEnabled)
    VALUES
        (@ApplicationId, 'aiaf-expired-test-user', @TestCustomerId, 1, 0,
         DATEADD(DAY, -31, @Now), 'AIAF_INTEGRATION_TEST_SETUP',
         DATEADD(DAY, -1, @Now), 1);
END;

IF (SELECT COUNT(*) FROM aiaf.AICustomerAccess
    WHERE ApplicationId = @ApplicationId AND RequestingIdentity = 'aiaf-functional-test-user') <> 1
   OR NOT EXISTS
   (
       SELECT 1 FROM aiaf.AICustomerAccess
       WHERE ApplicationId = @ApplicationId AND CustomerId = @TestCustomerId
         AND RequestingIdentity = 'aiaf-functional-test-user'
         AND CanRead = 1 AND CanRequestFinancialAction = 0
         AND IsEnabled = 1 AND ExpiresAt IS NULL
   )
    THROW 52706, 'Functional-test read authorization verification failed.', 1;

IF (SELECT COUNT(*) FROM aiaf.AICustomerAccess
    WHERE ApplicationId = @ApplicationId AND RequestingIdentity = 'aiaf-expired-test-user') <> 1
   OR NOT EXISTS
   (
       SELECT 1 FROM aiaf.AICustomerAccess
       WHERE ApplicationId = @ApplicationId AND CustomerId = @TestCustomerId
         AND RequestingIdentity = 'aiaf-expired-test-user'
         AND CanRead = 1 AND CanRequestFinancialAction = 0
         AND IsEnabled = 1 AND ExpiresAt < SYSUTCDATETIME()
   )
    THROW 52707, 'Expired-test authorization verification failed.', 1;

IF EXISTS
(
    SELECT 1 FROM aiaf.AICustomerAccess
    WHERE ApplicationId = @ApplicationId
      AND RequestingIdentity = 'aiaf-unauthorized-test-user'
)
    THROW 52708, 'Unauthorized-test identity must have no customer grants.', 1;

COMMIT TRANSACTION;

PRINT 'AIAF integration fixture created and verified.';
GO
