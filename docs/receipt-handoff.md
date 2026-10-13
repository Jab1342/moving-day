# Receipt foundation

`MonetizationService` is the sole `MarketplaceService.ProcessReceipt` owner. Cash packs use `ProductIds.Products.Cash500`, `Cash1800`, and `Cash5500`, with amounts in Config. IDs are intentionally absent until actual products exist. Unknown or ambiguous IDs return `NotProcessedYet` without consuming a receipt.

The server records the purchase ID and cash in one atomic profile draft, then requests a ProfileStore save. `PurchaseGranted` is returned only after `LastSavedData.purchases[purchaseId]` confirms the durable save. A save request returning is insufficient. Concurrent callbacks for the same receipt defer; a retry after timeout saves the existing reward without adding it again. A crash before persistence restores neither reward nor receipt, so the next server can retry. Receipt IDs are retained permanently and excluded from the public profile.

The only yielding operation inside receipt processing is the bounded profile-save wait. No player-load wait, product lookup, prompt callback grant, or purchase-triggered network request occurs there. ProfileStore session locking supplies cross-server ownership. Cash at the configured balance limit defers rather than consuming a purchase without its reward.

Validation: `tools/check.ps1` includes receipt tests using the real DataService and MonetizationService with simulated ProfileStore save completion. They exercise repeated callbacks, persisted rejoin, concurrent callbacks during save, delayed save confirmation, timeout/retry, thrown saves, crash before save, session loss, final release save, missing/duplicate IDs, malformed receipts, shutdown and balance limits.

Studio handoff: boot with current empty ProductIds and confirm no errors. Use a test-only harness with injected product IDs and a mock profile to replay one receipt twice; cash must rise once. Confirm unknown IDs defer. Real Studio test purchases and real persistence/rejoin remain pending product/account setup and must not be claimed from mock tests. Never enable a purchase button for an absent ID.

Stubbed: Crew Boost and Insurance Claim need an approved persistent purchase-context contract before they can be granted. Pass entitlements and purchase UI are separate work. This PR creates no products or prompts and changes no contract files.

References: [ProfileStore receipt durability guidance](https://madstudioroblox.github.io/ProfileStore/devproducts/) and [Roblox ProcessReceipt](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#ProcessReceipt).
