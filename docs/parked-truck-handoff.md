# Parked truck ownership fix

Claude A's PR29 test found that the ramp never deployed beside a parked truck: automatic network ownership assigned its chassis to a nearby pedestrian, and the server observed vertical velocity spikes despite a stationary chassis position. UpdateRamp interpreted those spikes as movement.

TruckService now explicitly assigns every unanchored vehicle assembly and its cargo to the server when there is no authorized driver. Entering the seat still assigns the driver; ownership changes before the ramp is evaluated. This addresses the reported ownership cause without ignoring real vertical movement or raising the ramp's speed threshold.

## Validation and handoff

Fourteen Lune suites, StyLua, Selene and both Rojo builds pass. A regression executes actual UpdateDriver/Ownership through driver entry, exit and another crew's seat attempt. It verifies chassis, wheel and cargo ownership, deduplicated welded roots and safe handling of anchored mechanisms. The test fails if automatic ownership is used.

Claude A: after the current Studio session finishes, sync this TruckService change onto PR29. Buy a ramp and start the next job. While standing near the empty truck, verify GetNetworkOwner() is nil, velocity settles, and the ramp deploys with its foot on the ground. Enter the seat to stow it, drive and brake, then exit and confirm redeployment. Repeat with pickup/box truck and soft suspension, and check cargo loading/unloading. Recheck physical walking on the ramp and steering after re-entry. Keep the PR draft until that live reproduction passes; mock tests cannot confirm physics replication.

No client or contract changes. Roblox's ownership documentation describes explicit nil ownership and automatic proximity assignment: https://create.roblox.com/docs/physics/network-ownership.
