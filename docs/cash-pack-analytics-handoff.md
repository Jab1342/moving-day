# Cash-pack economy events

Cash receipts previously changed the profile balance without recording an economy source event. MonetizationService now enqueues an IAP/Cash economy event with the configured pack amount, committed ending balance and stable SKU after a new successful profile mutation. Existing receipt entries, save retries, unknown IDs and rejected mutations do not emit an event.

AnalyticsService accepts an optional bounded transaction category; other callers retain Gameplay. Engine analytics runs through its existing deferred queue, outside ProcessReceipt. An analytics exception cannot prevent the receipt's durable save or acknowledgement. No product IDs, purchase buttons or contracts change.

Validation: eleven Lune suites, StyLua, Selene and both Rojo builds pass. Regression cases cover exact category/SKU/amount/balance, receipt replay and rejoin, concurrent callbacks, save timeout/retry, rejected mutations and analytics failure isolation.

Claude A: boot with empty IDs and verify no regressions. With the existing injected-ID/mock-profile receipt harness, grant once and replay; the wrapper's accepted count should increase only for the first committed grant. Human: after real products and publication, check an IAP Cash source in the Creator Hub economy dashboard. Roblox does not accept engine analytics in Studio.

Analytics follows committed in-memory mutations, like job payouts. It is not a durable financial ledger: a server crash before the profile saves can leave an event for a mutation that is later retried, and dropped/outage events are not retried. Receipt and reward durability remain controlled by ProfileStore and the receipt ledger.

Reference: https://create.roblox.com/docs/production/analytics/economy-events.
