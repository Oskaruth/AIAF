SET ANSI_PADDING ON

GO

CREATE NONCLUSTERED INDEX [IX_AIModelExecution_StartedAt] ON [aiaf].[AIModelExecution]
(
	[StartedAt] ASC,
	[ModelProvider] ASC,
	[ModelName] ASC
)
INCLUDE([InputTokens],[OutputTokens],[DurationMs],[TotalCost],[CostBasis],[CurrencyCode],[ExecutionStatus]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
