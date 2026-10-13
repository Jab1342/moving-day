# Verified purchase requests and personal pass benefits

Implements approved contract PR23 on top of the combined Studio branch PR29. Missing ProductIds still make every offer unavailable. This PR creates no products or passes and initiates no real purchases.

MonetizationService verifies configured pass ownership through server UserOwnsGamePassAsync, caches confirmed results, retries failures and invalidates in-flight checks after purchase completion. Errors publish ready=false and defer payouts instead of silently treating an owned benefit as absent. Profile startup resends also resend purchase state so a late client listener can recover. Player departure clears pending work.

RequestPurchase accepts named, implemented SKUs only. It validates a loaded profile, first grab (or completed prior onboarding), verified ownership, rate limits, no outstanding prompt and at most one prompt per job. The budget survives leaving and returning to that job. It reserves before invoking a platform prompt; prompt completion never grants cash or proves pass ownership. ProcessReceipt remains the sole product-grant path, with the existing durability ledger.

DoublePay and the three cash packs have implemented handlers; IDs are still empty. VIPForeman purchase availability remains false until its hat/tag content exists, but an already-owned configured pass receives the approved tip benefit. HornRadio, InsuranceClaim and CrewBoost remain unavailable. Insurance/CrewBoost still need approved durable context, not ad-hoc receipt-ledger fields.

Payouts preserve base shares and XP, add optional personal bonus lines, allocate actual integer time-bonus cash in join order, add VIP's 10% tip and then apply DoublePay. All bonuses are included in shares and total. Completion time is captured before waiting for ownership, so a slow API cannot reduce the earned time bonus; the payout screen retains its full display window after payment. Repeated award ticks neither recalculate nor duplicate the grant.

Validation: fifteen Lune suites, seven offline Python uploader tests, StyLua, Selene and both Rojo builds pass. New tests cover 1–4 recipients/Assist/time expiry, invalid and duplicate IDs, API failures/retry/departure, in-flight invalidation, first-grab/rate/job limits, reentrant prompts, unrelated completion events, no cash from a prompt callback, delayed payout and award replay. Existing durable receipt tests still pass. These are controlled mocks, not proof of real purchases.

Claude A: review and smoke the branch with PR23 Store UI; ensure no store appears with empty IDs, state resends reach a late listener, no purchase UI before first grab, personal bonus display uses report.bonuses[myUserIdString], and repeated button clicks do not create overlapping prompts. Use injected test IDs/API mocks only in disposable tests; never commit dummy IDs. Human owns real platform purchases and saved-rejoin acceptance once products exist. Keep draft until server boot/state/bonus-display smoke passes.

References: [Roblox MarketplaceService](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService), [passes](https://create.roblox.com/docs/production/monetization/passes), [developer products](https://create.roblox.com/docs/production/monetization/developer-products). Prompt results and durable receipt grants are separate responsibilities.
