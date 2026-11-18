/*
    AIAF Synthetic Customer Authorizations

    Establishes application-specific customer access
    for a fictional Accounts Receivable employee.

    Demonstrates three authorization scenarios:
        - Read and request financial actions
        - Read only
        - No authorized access

    Application and customer relationships are
    resolved using business keys.

    Intended exclusively for demonstration and
    integration testing.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

INSERT INTO aiaf.AICustomerAccess
(
    ApplicationId,
    RequestingIdentity,
    CustomerId,
    CanRead,
    CanRequestFinancialAction,
    GrantedAt,
    GrantedBy,
    ExpiresAt,
    IsEnabled
)
SELECT
    A.ApplicationId,
    P.RequestingIdentity,
    C.CustomerId,
    P.CanRead,
    P.CanRequestFinancialAction,
    SYSUTCDATETIME(),
    A.AccountableOwner,
    NULL,
    1
FROM
(
    VALUES
    (
        'ACME_ACCOUNTS_RECEIVABLE_AI',
        'jeannine@acme.example',
        'CUST-1001',
        1,
        1
    ),
    (
        'ACME_ACCOUNTS_RECEIVABLE_AI',
        'jeannine@acme.example',
        'CUST-1002',
        1,
        0
    )
) AS P
(
    ApplicationCode,
    RequestingIdentity,
    CustomerCode,
    CanRead,
    CanRequestFinancialAction
)
INNER JOIN aiaf.AIApplication AS A
    ON A.ApplicationCode = P.ApplicationCode
INNER JOIN acme.Customer AS C
    ON C.CustomerCode = P.CustomerCode;

IF @@ROWCOUNT <> 2
BEGIN
    THROW 52611,
        'Synthetic customer authorization seed failed. Expected two authorizations.',
        1;
END;

COMMIT TRANSACTION;

PRINT 'AIAF synthetic customer authorizations created.';
GO