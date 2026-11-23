/*
    AIAF Synthetic Application Configuration

    Creates two fictional Acme AI applications for
    demonstration and integration testing.

    Both applications are enabled at the configuration
    level. Their authorization to operate is determined
    separately by the governance gate.

    This script is intended for a fresh installation.
    Do not deploy synthetic application configuration
    into a production environment.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

INSERT INTO aiaf.AIApplication
(
    ApplicationCode,
    ApplicationName,
    BusinessPurpose,
    AccountableOwner,
    RiskClassification,
    IsEnabled
)
VALUES
(
    'ACME_CUSTOMER_SERVICE_AI',
    'Acme Customer Service Assistant',
    'Assist customer service representatives with authorized customer information and inquiries.',
    'customer.service.director@acme.example',
    'HIGH',
    1
),
(
    'ACME_ACCOUNTS_RECEIVABLE_AI',
    'Acme Accounts Receivable Assistant',
    'Assist accounting personnel with authorized customer balances, invoices, payments, disputes and controlled financial action requests.',
    'accounting.director@acme.example',
    'HIGH',
    1
);

COMMIT TRANSACTION;

PRINT 'AIAF synthetic application configuration created.';
GO