/*
    AIAF Synthetic Invoice Data

    Creates eight fictional invoices covering:
        - Fully outstanding invoices
        - Partially paid invoices
        - Fully paid invoices
        - Disputed invoices

    Customer relationships are resolved using business
    keys rather than hardcoded identity values.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

INSERT INTO acme.Invoice
(
    CustomerId,
    InvoiceNumber,
    InvoiceDate,
    DueDate,
    InvoiceAmount,
    OutstandingAmount,
    IsDisputed
)
SELECT
    C.CustomerId,
    I.InvoiceNumber,
    I.InvoiceDate,
    I.DueDate,
    I.InvoiceAmount,
    I.OutstandingAmount,
    I.IsDisputed
FROM
(
    VALUES
        ('CUST-1001', 'INV-10001', '20260901', '20261001',  8500.00,  8500.00, 0),
        ('CUST-1001', 'INV-10002', '20260915', '20261015',  4200.00,  4200.00, 1),
        ('CUST-1001', 'INV-10003', '20261001', '20261031',  6000.00,  1500.00, 0),
        ('CUST-1001', 'INV-10004', '20261015', '20261114',  3000.00,     0.00, 0),
        ('CUST-1002', 'INV-10005', '20261001', '20261031', 32000.00, 32000.00, 0),
        ('CUST-1002', 'INV-10006', '20261015', '20261114', 18000.00,  9000.00, 1),
        ('CUST-1003', 'INV-10007', '20261001', '20261031', 85000.00, 85000.00, 0),
        ('CUST-1003', 'INV-10008', '20261015', '20261114', 24000.00, 24000.00, 0)
) AS I
(
    CustomerCode,
    InvoiceNumber,
    InvoiceDate,
    DueDate,
    InvoiceAmount,
    OutstandingAmount,
    IsDisputed
)
INNER JOIN acme.Customer AS C
    ON C.CustomerCode = I.CustomerCode;

IF @@ROWCOUNT <> 8
BEGIN
    THROW 52610,
        'Synthetic invoice seed failed. Expected eight invoices.',
        1;
END;

COMMIT TRANSACTION;

PRINT 'AIAF synthetic invoice data created.';
GO