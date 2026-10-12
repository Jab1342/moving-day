# server: authoritative carry, damage and truck cargo

The live client controllers currently depend on a Studio-only item stub. This adds server
ItemService, DamageService and TruckService so the carry/truck test can run through Rojo.
Grab requests enforce crew, grip, range, state and one-item-per-player rules. The server
assigns network ownership before enabling the agreed carry constraints and promotes the
second carrier on lead drop/disconnect. Relay packets are rate limited and checked for
finite, plausible hand positions. Carried-item bounds restore invalid movement and
temporarily suspend repeat offenders; full CrewService removal is a documented stub.

Damage uses velocity changes, grace/cooldown windows and the capped pure DamageModel;
HP/blame stay server-owned. Broken-item VFX snapshots are sent before destruction.
TruckService clones the authored truck, validates the driver, assigns assembly/cargo
ownership, detects bed cargo, welds settled items and breaks welds using acceleration
`|deltaVelocity| / (dt * gravity)` or tilt. Strap slots are reserved during the strap delay
and revalidated at completion. Grabbing your strapped cargo releases it for unloading.

Validation: StyLua, Selene, Lune contract checks, pure server-policy tests, service tests
using fake engine services plus real Vector3/CFrame math, and normal/fallback Rojo builds.
Service tests cover cross-crew denial, grip ownership, handoff, constraint ordering,
invalid relays, cargo unloading and strap cancellation. These do not simulate physics.

Studio handoff:

1. Claude A combines this branch with client PR #3 in their test checkout and uses the
   existing single Rojo server. Remove `ServerScriptService._DevItemStub` first; startup
   refuses to coexist with it. No Studio geometry is in this PR.
2. `Config.StudioHarnessEnabled` defaults true for integration but is gated by IsStudio.
   It clones existing `TRK_Pickup` and box/couch/vase templates at HQ docks; players are
   assigned to fixture crews of up to four and spawned beside the items. Set false when
   real Crew/Job services are integrated. It never grants cash or saves data.
3. Test grab/drop, lead disconnect with grip 2 held, separate-crew denial, solo dolly,
   loading, driving, settling and strapped/unstrapped hard stops. Confirm no errors and
   measure actual acceleration before changing BedBreakG/StrappedBreakG.
4. Claude A adds Strap input and secondary-grip soft slowdown using the existing remote
   and Config. The server enforces hard auto-drop; soft client slowdown is pending.
5. Human runs the 2- and 4-client gates. Post results in Edit mode and save the place.

Remaining stubs: persistent DataService, full Crew/Job loop, wrap unlock/cash debit,
upgraded strap capacity, crew removal on repeated exploit strikes, payout and shop.
Wrap returns NotReady. This is the server integration slice, not an end-to-end job.
