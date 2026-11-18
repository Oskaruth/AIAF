SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE   VIEW aiaf.vw_AIModelOperatingCost
AS

SELECT
    CAST(m.StartedAt AS date) AS ExecutionDate,
    a.ApplicationCode,
    i.WorkflowCode,
    m.ExecutionEnvironment,
    m.ModelProvider,
    m.ModelName,
    m.PromptVersion,
    m.CurrencyCode,
    m.CostBasis,

    COUNT_BIG(*) AS ModelExecutions,

    SUM(m.InputTokens) AS TotalInputTokens,
    SUM(m.OutputTokens) AS TotalOutputTokens,

    SUM(m.TotalCost) AS TotalKnownCost,

    COUNT_BIG
    (
        CASE WHEN m.TotalCost IS NOT NULL
             THEN 1 END
    ) AS ExecutionsWithKnownCost,

    COUNT_BIG
    (
        CASE WHEN m.TotalCost IS NULL
             THEN 1 END
    ) AS ExecutionsWithUnknownCost,

    CAST
    (
        100.0 * COUNT_BIG(m.TotalCost)
        / NULLIF(COUNT_BIG(*), 0)
        AS decimal(5,2)
    ) AS CostCoveragePct

FROM aiaf.AIModelExecution AS m
INNER JOIN aiaf.AIInteraction AS i
    ON i.InteractionId = m.InteractionId
INNER JOIN aiaf.AIApplication AS a
    ON a.ApplicationId = i.ApplicationId

WHERE m.TelemetrySource = 'LIVE'

GROUP BY
    CAST(m.StartedAt AS date),
    a.ApplicationCode,
    i.WorkflowCode,
    m.ExecutionEnvironment,
    m.ModelProvider,
    m.ModelName,
    m.PromptVersion,
    m.CurrencyCode,
    m.CostBasis;

GO

ALTER AUTHORIZATION ON [aiaf].[vw_AIModelOperatingCost] TO  SCHEMA OWNER
GO
