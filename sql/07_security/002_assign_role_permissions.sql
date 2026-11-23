-- =====================================================
-- AIAF Runtime
-- =====================================================

-- Explicitly prohibit direct access to application data.

DENY SELECT, INSERT, UPDATE, DELETE
    ON SCHEMA::[acme]
    TO [AIAF_Runtime];

DENY SELECT, INSERT, UPDATE, DELETE
    ON SCHEMA::[aiaf]
    TO [AIAF_Runtime];

DENY SELECT, INSERT, UPDATE, DELETE, EXECUTE
    ON SCHEMA::[aiaf_governance]
    TO [AIAF_Runtime];

-- Permit only the supported runtime interfaces.

GRANT EXECUTE
    ON OBJECT::[aiaf].[usp_BeginInteraction]
    TO [AIAF_Runtime];

GRANT EXECUTE
    ON OBJECT::[aiaf].[usp_CompleteInteraction]
    TO [AIAF_Runtime];

GRANT EXECUTE
    ON OBJECT::[aiaf].[usp_RecordInputValidation]
    TO [AIAF_Runtime];

GRANT EXECUTE
    ON OBJECT::[aiaf].[usp_RecordModelExecution]
    TO [AIAF_Runtime];

GRANT EXECUTE
    ON OBJECT::[aiaf].[usp_RecordModelToolRequest]
    TO [AIAF_Runtime];

GRANT EXECUTE
    ON OBJECT::[aiaf].[usp_RecordOutputValidation]
    TO [AIAF_Runtime];

GRANT EXECUTE
    ON OBJECT::[aiaf_tool].[GetCustomerBalance]
    TO [AIAF_Runtime];
GO

-- =====================================================
-- AIAF Governance Reader
-- =====================================================

GRANT SELECT
    ON SCHEMA::[aiaf_governance]
    TO [AIAF_GovernanceReader];

DENY INSERT, UPDATE, DELETE
    ON SCHEMA::[aiaf_governance]
    TO [AIAF_GovernanceReader];
GO

-- =====================================================
-- AIAF Governance Reviewer
-- =====================================================

GRANT SELECT
    ON SCHEMA::[aiaf_governance]
    TO [AIAF_GovernanceReviewer];

DENY INSERT, UPDATE, DELETE
    ON SCHEMA::[aiaf_governance]
    TO [AIAF_GovernanceReviewer];

GRANT EXECUTE
    ON OBJECT::[aiaf_governance].[usp_FreezeReview]
    TO [AIAF_GovernanceReviewer];
GO

-- =====================================================
-- AIAF Governance Attestor
-- =====================================================

GRANT SELECT
    ON SCHEMA::[aiaf_governance]
    TO [AIAF_GovernanceAttestor];

DENY INSERT, UPDATE, DELETE
    ON SCHEMA::[aiaf_governance]
    TO [AIAF_GovernanceAttestor];

GRANT EXECUTE
    ON OBJECT::[aiaf_governance].[usp_AttestReview]
    TO [AIAF_GovernanceAttestor];
GO