-- AIAF core database security roles.
-- All application roles are owned by dbo.

CREATE ROLE [AIAF_Runtime]
    AUTHORIZATION [dbo];
GO

CREATE ROLE [AIAF_GovernanceReader]
    AUTHORIZATION [dbo];
GO

CREATE ROLE [AIAF_GovernanceReviewer]
    AUTHORIZATION [dbo];
GO

CREATE ROLE [AIAF_GovernanceAttestor]
    AUTHORIZATION [dbo];
GO