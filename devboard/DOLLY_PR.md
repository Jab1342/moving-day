Enables the two cash-purchased Dolly tiers ($300/$900) through the existing HQ upgrade transaction. Config defines movement scales 0.55/0.70; the free solo tier remains 0.4 and all tiers remain slower than ordinary carrying. UpgradeRules.dollySpeed reads this progression for the client. Purchased dolly access also lets a crew member move a two-person item alone; a second carrier switches back to two-person carry.

Validation: eight Lune suites and both builds pass with clean formatting/lint. New cases verify sequential pricing, exact atomic debits, replay rejection, finite capped tier speeds, purchased crew access and two-carrier state.

Do not merge until ClaudeA's client consumes PublicProfile.upgrades.Dolly using UpgradeRules.dollySpeed and Studio verifies the actual movement effect. The server branch alone must not ship a paid upgrade without the client effect. Existing approved attributes/remotes/profile fields suffice; no contract change.

ClaudeA handoff: at HQ with mock cash, buy tier1 and then tier2; hold a couch solo and verify 0.4/0.55/0.70 movement scales. Test purchased access in a two-person crew with only one grip, then take the second grip and verify ordinary cooperative carry. Human multiplayer gate remains.
