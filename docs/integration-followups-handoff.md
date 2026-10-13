# Follow-up integration candidate

This provides one reviewable build for the next Studio regression after PR29. It includes current main through 44ff0b7, PR29's remaining physics/truck upgrades, PR30 purchase guards, PR32 item-hit ragdolls, PR33 parked ownership, PR35 cash-pack analytics, and PR28's breadcrumb carry through Claude A 61df322. Config matches its DollyTrailStep=0.5 and DollyLeashMinScale=0. It also integrates Claude A's strap/recover animation readers at 2d40d66, already verified in Studio. The frozen PR29 branch remains unchanged.

The startup merge keeps one DataService start, initializes MonetizationService with remotes and analytics, and installs the profile-published hook before data loading. No contract files were changed beyond already approved main contracts. PR31 physical-grip behavior is excluded pending approval. The nav-beacon branch remains separate pending its owner review fixes. The out-of-scope homeowner NPC remains excluded.

## Validation

Sixteen Lune suites and seven Python upload tests pass together, with clean StyLua/Selene and both Rojo builds. The suite covers server carry ownership, damage, ragdoll contact checks, truck upgrades, profiles, jobs, ping, receipt durability, analytics and prompt/pass bonuses. These tests do not establish live physics feel, platform purchases or mobile frame rate.

## Next Studio pass, Claude A

1. Sync only after Claude B unlocks, and record the exact git head. Boot without errors, complete Starter payout, return to HQ and start another job. The first-grab and payout flows must still work with the new entitlement query hook and empty product IDs.
2. Prioritize PR33: park near the unoccupied pickup and box truck. Every assembly should remain server-owned; the ramp should deploy onto ground, stow on seat entry, and redeploy after driving/exiting. Test with soft suspension and verify walking/loading on the ramp. Check the ramp can still break loose.
3. Retest PR28's documented tight-turn routes with breadcrumb carry. Verify normal/rotated dolly movement, upstairs routes, pushing, backing out of jams, respawn and loading without hard-leash drops. Do not mark the earlier soft-leash-only or rigid-trailer builds as passing; Claude B reproduced their failures. Use actual input/Humanoid:Move: Humanoid:MoveTo does not update MoveDirection and cannot exercise the directional slowdown correctly.
4. Retest the PR11 cargo gate: strapped cargo survives a 40 studs/s hard stop; unstrapped cargo must physically spill. Breaking a weld alone is not a pass. Chest-height vase/box behavior passed the previous smoke; guard against regressions.
5. Test the new server-driven ragdoll with loose furniture, repeated contacts, a seated driver and another crew. No health loss or fling; recover after two seconds. Review the client Neck/RequiresNeck handling before declaring this safe, and test respawn during ragdoll. Strap and recovery animation readers are included.
6. Purchase IDs remain absent. No store prompts should appear. Use the existing mock harness for receipt replay and entitlement/payout paths without spending. Real product/pass test purchases, save/rejoin and published analytics remain account-dependent tests. Insurance/CrewBoost, VIP cosmetics and Horn/Radio stay unavailable until their required effects exist.

Keep this draft until the remaining physical and boot gates pass. Human-owned two/four-client tests, phone performance and publishing remain outstanding. Detailed subsystem handoffs are in docs/parked-truck-handoff.md, item-ragdoll-handoff.md, purchase-guards-handoff.md, cash-pack-analytics-handoff.md and truck-feel-handoff.md.
