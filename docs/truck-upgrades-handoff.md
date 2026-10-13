# Truck upgrade implementation — Studio gate pending

Requires approved contract PR20 and physics PR11. This draft implements the crew leader's saved LoadingRamp, BoxTruck and SoftSuspension upgrades on the next job's truck. Geometry validation rejects unavailable upgrades before charging cash. Dolly remains a separate draft (PR17).

Ramp: clone the Studio template, unanchor its authored assembly and align its high-end pivot at Chassis.RampMount. Probe ground while parked, excluding trucks, items and characters; solve hinge pitch for both 3.2- and 2.5-stud ride heights. A seated driver or motion above 2 studs/s stows the ramp with collision off. Exiting at rest redeploys it; missing/steep ground leaves it stowed. Detach before each PivotTo so it cannot reposition the truck assembly. Restore tailgate collision while stowed or lost. Acceleration above Config.RampLooseG breaks the weld once; the loose ramp stays physical until job cleanup, with replacement on next spawn.

Box truck: select TRK_Box; publish steering limits 26/9 through the approved MD attributes. Bed size and higher center of mass are authored Studio geometry, not recreated by the server. Soft suspension multiplies springs by 0.6 stiffness/1.25 damping and cargo acceleration by 0.7, with top speed reduced from 60 to 52. Damage and protection remain unchanged. All tuning is in Config.

Validation: eleven Lune suites, four offline audio-uploader tests, StyLua, Selene and both Rojo builds pass. New tests exercise actual TruckService with controlled geometry/raycast mocks, invalid templates, collision transitions, ground fit, detach-before-pivot and one-time release. Job tests verify leader upgrade forwarding; upgrade tests verify exact cash debit and unavailable/repeated purchase rejection. Mocks do not establish Roblox physics or client feel.

Claude A gate before merge: sync this branch after PR11's pending drop/spill test. In a disposable mock profile at HQ, buy each upgrade, start the next job and verify:

1. Ramp loads a couch on pickup and box, its foot meets current ground, tailgate does not obstruct, and it never drags during driving. Enter/exit repeatedly and park on a slope/curb; confirm no truck teleport or jitter from ground refresh. Severe bump releases it once, without flinging players; next job restores it.
2. Box truck has twice pickup bed capacity and visibly slower turning/top-heavy behavior; combined ramp fits its mount.
3. Suspension reduces bounce, reaches the lower speed limit, and still permits impact damage and severe cargo loss. Compare baseline and upgraded versions on the same route.
4. Missing ramp/mount/spring/template rejects the relevant purchase without cash loss. Purchased tiers survive the human-owned rejoin test.

Keep this PR draft until each physical effect and tradeoff passes; purchasing these upgrades becomes available when this server implementation is deployed, so do not merge before that gate. No Studio content, client files, contract files, paid product IDs or publishing actions are changed here.
