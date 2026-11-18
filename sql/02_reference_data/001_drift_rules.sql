/*
    AIAF Sample Behavioral Drift Configuration

    Demonstrates monitoring changes in tool utilization
    between baseline and current observation periods.

    This is sample configuration, not a universal
    recommendation for production thresholds.
*/

SET NOCOUNT ON;

INSERT INTO aiaf.AIDriftRule
(
    WorkflowCode,
    ToolCode,
    MinimumBaselineInteractions,
    MinimumCurrentInteractions,
    MinimumPercentagePointChange,
    IsEnabled
)
VALUES
(
    'CUSTOMER_BALANCE_INQUIRY',
    'GetCustomerNotes',
    100,
    100,
    10.00,
    1
);
GO