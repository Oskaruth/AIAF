SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE   PROCEDURE aiaf.usp_EvaluateGovernanceGate
    @ApplicationCode varchar(100),
    @ApplicationId bigint OUTPUT,
    @ReviewId bigint OUTPUT,
    @AttestationId bigint OUTPUT,
    @GovernanceDecision varchar(30) OUTPUT,
    @GateDecision varchar(20) OUTPUT,
    @GateReason varchar(100) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsEnabled bit;
    DECLARE @EvidencePackage varchar(max);
    DECLARE @ReviewHash binary(32);
    DECLARE @AttestationHash binary(32);

    SELECT
        @ApplicationId = NULL,
        @ReviewId = NULL,
        @AttestationId = NULL,
        @GovernanceDecision = NULL,
        @GateDecision = 'DENIED',
        @GateReason = 'APPLICATION_NOT_REGISTERED';

    SELECT
        @ApplicationId = ApplicationId,
        @IsEnabled = IsEnabled
    FROM aiaf.AIApplication
    WHERE ApplicationCode = @ApplicationCode;

    IF @ApplicationId IS NULL
        RETURN;

    IF @IsEnabled = 0
    BEGIN
        SET @GateReason = 'APPLICATION_DISABLED';
        RETURN;
    END;

    SELECT TOP (1)
        @ReviewId = r.ReviewId,
        @AttestationId = a.AttestationId,
        @GovernanceDecision = a.AttestationDecision,
        @EvidencePackage = r.EvidencePackage,
        @ReviewHash = r.EvidencePackageHash,
        @AttestationHash = a.EvidencePackageHash
    FROM aiaf_governance.AIReview AS r
    INNER JOIN aiaf_governance.AIReviewAttestation AS a
        ON a.ReviewId = r.ReviewId
    WHERE r.ApplicationCode = @ApplicationCode
      AND r.ReviewStatus = 'COMPLETED'
    ORDER BY
        a.AttestedAt DESC,
        a.AttestationId DESC;

    IF @AttestationId IS NULL
    BEGIN
        SET @GateReason = 'NO_GOVERNANCE_ATTESTATION';
        RETURN;
    END;

    IF @EvidencePackage IS NULL
       OR @ReviewHash IS NULL
       OR @AttestationHash IS NULL
       OR @ReviewHash <> @AttestationHash
       OR HASHBYTES('SHA2_256', @EvidencePackage)
          <> @ReviewHash
    BEGIN
        SET @GateReason = 'EVIDENCE_INTEGRITY_FAILURE';
        RETURN;
    END;

    IF @GovernanceDecision = 'APPROVED'
    BEGIN
        SET @GateDecision = 'ALLOWED';
        SET @GateReason = 'GOVERNANCE_APPROVED';
        RETURN;
    END;

    SET @GateReason =
        CASE @GovernanceDecision
            WHEN 'SUSPENDED'
                THEN 'GOVERNANCE_SUSPENDED'
            WHEN 'REJECTED'
                THEN 'GOVERNANCE_REJECTED'
            WHEN 'RESTRICTED'
                THEN 'RESTRICTIONS_NOT_EVALUATED'
            WHEN 'CONDITIONALLY_APPROVED'
                THEN 'CONDITIONS_NOT_EVALUATED'
            ELSE 'UNKNOWN_GOVERNANCE_DECISION'
        END;
END;

GO

ALTER AUTHORIZATION ON [aiaf].[usp_EvaluateGovernanceGate] TO  SCHEMA OWNER
GO
