local Config = require("../src/shared/Config")
local Damage = require("../src/shared/Logic/DamageModel")
local Carry = require("../src/shared/Logic/CarryRules")
local Rate = require("../src/shared/Logic/RateLimit")
local Cargo = require("../src/shared/Logic/CargoRules")
local def = { fragility = 1 }
local mods = { protection = 0, assist = false }
assert(Damage.impactDamage(14, def, mods) == 0, "No damage below threshold")
assert(Damage.impactDamage(24, def, mods) == 25, "Impact scale")
assert(Damage.impactDamage(24, { fragility = 2 }, mods) == 50, "Fragility scale")
assert(Damage.impactDamage(999, def, mods) == Damage.impactDamage(120, def, mods), "DeltaV clamped")
assert(
	Damage.impactDamage(24, def, { protection = 1, assist = true }) == 12.5,
	"Combined protection capped at 50%"
)
assert(Damage.impactDamage(0 / 0, def, mods) == 0, "NaN cannot cause damage")
local item = { a = 0, b = 0, crewId = "A", state = "Idle", carry = "Two", strapped = false }
assert(not Carry.canGrab(item, 1, 1, "B", 1, false, Config), "Cross-crew denied")
assert(not Carry.canGrab(item, 1, 2, "A", 1, false, Config), "No orphan second grip")
assert(not Carry.canGrab(item, 1, 1, "A", 0 / 0, false, Config), "NaN range denied")
assert(Carry.canGrab(item, 1, 1, "A", 8, false, Config), "Boundary grab allowed")
item.a = 1
assert(Carry.canGrab(item, 2, 2, "A", 2, false, Config), "Second carrier allowed")
assert(not Carry.canGrab(item, 1, 2, "A", 2, false, Config), "Cannot own both grips")
local a, b = Carry.drop(1, 2, 1)
assert(a == 2 and b == 0, "Lead handover")
a, b = Carry.drop(1, 2, 3)
assert(a == 1 and b == 2, "Noncarrier cannot drop")
local bucket
local allowed
for _ = 1, 4 do
	allowed, bucket = Rate.consume(bucket, 0, 2, 4)
	assert(allowed, "Burst tokens")
end
allowed, bucket = Rate.consume(bucket, 0, 2, 4)
assert(not allowed, "Burst exhausted")
allowed, bucket = Rate.consume(bucket, 0.5, 2, 4)
assert(allowed, "Token refill")
local g = Cargo.accelerationG(57, 0.1, 196.2)
assert(g > 2.9 and g < 3, "Acceleration uses dt")
assert(Cargo.shouldBreak(g, 0, false, Config), "Hard stop breaks loose weld")
assert(Cargo.shouldBreak(g, 0, true, Config), "Extreme collision can break straps")
for _, hz in { 30, 60, 120 } do
	local smooth = 0
	for _ = 1, math.floor(hz * 0.4) do
		smooth = Cargo.smooth(smooth, 0.45, 1 / hz, Config.BedAccelerationFilterSeconds)
	end
	assert(Cargo.shouldBreak(smooth, 0, false, Config), "Measured hard stop spills loose cargo")
	assert(not Cargo.shouldBreak(smooth, 0, true, Config), "Measured hard stop preserves straps")
	local launch = 0
	for _ = 1, hz do
		launch = Cargo.smooth(launch, 0.3, 1 / hz, Config.BedAccelerationFilterSeconds)
		assert(
			not Cargo.shouldBreak(launch, 0, false, Config),
			"Controlled acceleration preserves loose cargo"
		)
	end
	local chatter = 0
	for frame = 1, hz do
		chatter = Cargo.smooth(
			chatter,
			if frame % 2 == 0 then 1.2 else -1.2,
			1 / hz,
			Config.BedAccelerationFilterSeconds
		)
		assert(
			not Cargo.shouldBreak(math.abs(chatter), 0, false, Config),
			"Alternating suspension noise does not spill cargo"
		)
	end
end
assert(Cargo.shouldBreak(0, 36, true, Config), "Tilt breaks both")
print("PASS: damage, carry authorization/handover, rate limits, cargo acceleration")
