/*
    AIAF Synthetic Customer Data

    Creates three fictional customers supporting
    different financial and authorization scenarios.

    All customer information is synthetic and intended
    exclusively for demonstration and integration testing.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

INSERT INTO acme.Customer
(
    CustomerCode,
    CustomerName,
    CreditLimit,
    IsActive
)
VALUES
(
    'CUST-1001',
    'Northwind Industrial',
    25000.00,
    1
),
(
    'CUST-1002',
    'Contoso Equipment',
    75000.00,
    1
),
(
    'CUST-1003',
    'Fabrikam Logistics',
    150000.00,
    1
);

COMMIT TRANSACTION;

PRINT 'AIAF synthetic customer data created.';
GO