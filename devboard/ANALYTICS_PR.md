Adds the specified AnalyticsService wrapper and server-confirmed onboarding hooks for spawn, grab, load, actual truck movement, delivery, payout, first upgrade and second job. Payouts and upgrade/blanket debits emit economy events only after a successful profile mutation. Completed jobs include tier/stars/crew size and duration; breaks include catalogue identity.

Engine calls are deferred through a bounded queue and protected so analytics outages cannot interrupt gameplay. Studio counts accepted events without calling unsupported engine analytics. The wrapper deduplicates funnel steps per session; Roblox's one-time onboarding funnel deduplicates reconnects, avoiding a save/contract change.

Validation: nine Lune suites, StyLua/Selene and both builds pass. Tests verify actual engine argument order, source/sink amounts, invalid input rejection, deduplication, bounded queues, API failure isolation, Studio suppression and no repeated payout analytics on retry.

Stacked on PR10 (codex/crews-jobs). ClaudeA: integrate after the jobs smoke, run a full mock Starter loop and check for regressions. Human: published Creator Hub analytics verification remains required; Studio cannot send these events. Insurance/product hooks await MonetizationService; PingUsed callback awaits integration with PR14. No contract changes.

Official APIs and behavior checked against:
- https://create.roblox.com/docs/reference/engine/classes/AnalyticsService
- https://create.roblox.com/docs/production/analytics/funnel-events
- https://create.roblox.com/docs/production/analytics/event-types
