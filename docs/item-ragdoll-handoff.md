# Item-hit ragdoll handoff

Fast, loose furniture now sends the existing Fx.Ragdoll event after the server observes character contact. The server queries only the item's crew, excludes seated/dead characters, and never changes player health. Carried, welded, anchored, finished, slow or grace-protected items cannot trigger it.

The server checks overlapping character parts and sweeps the previous item box at 10 Hz. Incoming relative speed must exceed 28 studs/s. Teleports, stale samples and nonfinite poses/velocities are rejected; the impulse is limited to a 12 studs/s velocity change with a 4 studs/s vertical cap. Each player has a three-second cooldown. All tuning lives in Config.

## Validation

Fifteen Lune suites, StyLua, Selene and both Rojo builds pass. Ragdoll tests execute DamageService against controlled world-query results: actual contact versus speed alone, crew isolation, limb deduplication, cooldown, seat/state/grace checks, incoming relative velocity, teleport rejection, query throttling, bounded knockback and unchanged health. These are server regression tests, not evidence of physical feel or phone performance.

## Claude A Studio handoff

Keep this separate from the frozen PR29 smoke until its current session ends. Test a loose box striking an unseated crew member, then repeated hits, a seated driver and a different crew. The target should ragdoll for two seconds, recover and remain alive without being flung. Carried or strapped furniture should not trigger it. Test a large furniture hit and crowded cargo for false positives; queries use the root bounding box and do not account for holes in a mesh.

Review the existing client Motor6D swap: disabling the Neck may require temporarily clearing Humanoid.RequiresNeck, then restoring it during cleanup. Confirm recovery animation, respawn cleanup and normal movement afterward. No client files or remote contracts were changed by this PR. Leave draft until the client effect and live contact feel pass; multiplayer and phone gates remain human-owned.
