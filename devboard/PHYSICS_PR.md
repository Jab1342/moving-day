Filters signed truck acceleration over 0.15 seconds and tunes loose/strapped release thresholds to 0.55g/1.6g using ClaudeA's measured 0.9g hard stop. Brief alternating suspension chatter cancels instead of releasing cargo. Severe acceleration and excessive tilt can still break straps. Server anti-exploit rollback now resets the item's velocity sample after zeroing motion.

Validation: seven Lune suites, formatting/lint, vendor hash and both builds pass. New checks run suspension chatter and braking at 30/60/120 Hz. DamageService regression tests verify a 37 studs/s stop leaves a box at 31 HP and breaks a vase, records blame, suppresses repeat cooldown damage, and protects delivered/grace items.

ClaudeA Studio handoff: test current client brake assist with loose and strapped cargo at 40 studs/s; loose should spill while strapped survives. Verify ordinary bumps remain stable. Tune Config only from observed traces. For the reported chest-drop failure, capture velocity immediately before/after collision, deltaV, HP and cooldown on an ordinary held-item release (no test PivotTo). DamageService already uses AssemblyLinearVelocity; this PR does not claim that the Studio failure is fixed by the rollback reset.

No contract change. Physics acceptance and multi-client ownership remain pending; no unrelated damage formula changes.
