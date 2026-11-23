-- =====================================================
-- AIAF automated testing principals
-- =====================================================
-- OPTIONAL: Install in development/test environments.
-- These database users have no associated server login.
-- They support permission testing through EXECUTE AS.
-- =====================================================

CREATE USER [AIAF_TestRuntime]
    WITHOUT LOGIN
    WITH DEFAULT_SCHEMA = [dbo];

CREATE USER [AIAF_TestReader]
    WITHOUT LOGIN
    WITH DEFAULT_SCHEMA = [dbo];

CREATE USER [AIAF_TestReviewer]
    WITHOUT LOGIN
    WITH DEFAULT_SCHEMA = [dbo];

CREATE USER [AIAF_TestAttestor]
    WITHOUT LOGIN
    WITH DEFAULT_SCHEMA = [dbo];
GO

GRANT CONNECT TO [AIAF_TestRuntime];
GRANT CONNECT TO [AIAF_TestReader];
GRANT CONNECT TO [AIAF_TestReviewer];
GRANT CONNECT TO [AIAF_TestAttestor];
GO

ALTER ROLE [AIAF_Runtime]
    ADD MEMBER [AIAF_TestRuntime];

ALTER ROLE [AIAF_GovernanceReader]
    ADD MEMBER [AIAF_TestReader];

ALTER ROLE [AIAF_GovernanceReviewer]
    ADD MEMBER [AIAF_TestReviewer];

ALTER ROLE [AIAF_GovernanceAttestor]
    ADD MEMBER [AIAF_TestAttestor];
GO