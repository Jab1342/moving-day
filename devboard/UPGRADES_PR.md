Wires Shop.Buy to server-side HQ proximity, supported-upgrade, price and tier checks, then commits the debit and unlock in one validated DataService mutation. Straps increase capacity by two slots per tier using the highest tier among current crew members. MovingBlankets unlocks wrapping at the configured per-use price.

Wrapping waits three seconds, then revalidates the carrier, crew, item, range and available cash before charging once and setting Wrapped. Dropping cancels pending wrapping without a debit. Strap now returns success after the two-second operation has actually completed; moving away, changing crew or unloading returns Cancelled and frees the reserved slot.

Validation: all six Lune suites, StyLua/Selene, pinned-vendor hash and both Rojo builds pass. New checks cover tier order and replay rejection, exact cash debits, server HQ proximity, job-state hook, current crew capacity, blanket cancellation and failed debits. Existing carry handover and strap reservation tests remain covered.

Dependency: stacked on PR #8 (codex/profile-data); merge that first and retarget this PR to main. No contract change.

Studio handoff for ClaudeA: integrate both branches, seed cash only in the Studio mock profile, buy Straps/MovingBlankets near Garage.ShopCounter, then verify extra slots and wrapped damage protection. Start wrap then drop before three seconds: it must cancel with no debit. Strapping feedback should now wait until the attribute is set. Published saving and multiplayer tests are still pending.

Stubs: Dolly speed tiers, LoadingRamp, BoxTruck and SoftSuspension return NotReady without charging until their physical effects are implemented. JobService must supply UpgradeService.isInJob when real jobs replace the Studio fixture; current fixture has no job membership. No real cash source or payout grant is introduced here.
