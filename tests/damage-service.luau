local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local Config = require("../src/shared/Config")
local DamageModel = require("../src/shared/Logic/DamageModel")
local Defs = require("../src/shared/ItemDefs")
local V = rb.Vector3
local clock, removed, events = 1, {}, {}
local players = {
	GetPlayerByUserId = function()
		return nil
	end,
}
local shared = { Config = Config, Logic = { DamageModel = DamageModel } }
local DamageService = luau.load(fs.readFile("src/server/Services/DamageService.luau"), {
	environment = {
		game = {
			GetService = function(_, name)
				if name == "Players" then
					return players
				end
				return {
					WaitForChild = function()
						return shared
					end,
				}
			end,
		},
		require = function(module)
			return module
		end,
		os = {
			clock = function()
				return clock
			end,
		},
	},
})()
local items = { records = {} }
function items:Fire(rec, event, info)
	table.insert(events, { uid = rec.uid, event = event, info = info })
end
function items:Remove(rec)
	removed[rec.uid] = true
	self.records[rec.uid] = nil
end
local damage = DamageService.new(items)
local function item(uid, def)
	local attributes = {}
	local model = {
		SetAttribute = function(_, key, value)
			attributes[key] = value
		end,
		GetAttribute = function(_, key)
			return attributes[key]
		end,
		GetPivot = function()
			return rb.CFrame.identity
		end,
	}
	local rec = {
		uid = uid,
		model = model,
		def = def,
		lastCarrier = 12,
		root = { AssemblyLinearVelocity = V.zero },
		state = "Idle",
		graceUntil = 0,
		lastDamageAt = -100,
	}
	items.records[uid] = rec
	damage:Initialize(rec)
	return rec
end
local box = item("box", Defs.box)
local vase = item("vase", Defs.vase)
-- A measured 37 stud/s fall comes to rest, with no upward bounce.
box.root.AssemblyLinearVelocity = V.new(0, -37, 0)
vase.root.AssemblyLinearVelocity = V.new(0, -37, 0)
damage:Step()
assert(box.model:GetAttribute("HP") == 100, "First sample does not invent an impact")
box.root.AssemblyLinearVelocity = V.zero
vase.root.AssemblyLinearVelocity = V.zero
damage:Step()
assert(box.model:GetAttribute("HP") == 71.25 and not removed.box, "Box survives 37 stud/s stop")
local brokenEvent
for _, event in events do
	if event.uid == "vase" then
		brokenEvent = event
	end
end
assert(removed.vase and brokenEvent.event == "Broken", "Vase breaks on the same stop")
assert(brokenEvent.info.itemId == "vase", "Fracture payload carries catalogue identity")
-- ClaudeA's server-owned 4.7-stud drop produced a 50.1 stud/s landing delta.
local measuredBox, measuredVase = item("measuredBox", Defs.box), item("measuredVase", Defs.vase)
measuredBox.previousVelocity = V.new(0, -50.1, 0)
measuredVase.previousVelocity = V.new(0, -50.1, 0)
damage:Step()
assert(
	math.abs(measuredBox.model:GetAttribute("HP") - 54.875) < 0.001 and not removed.measuredBox,
	"Measured chest drop preserves cardboard box"
)
assert(removed.measuredVase, "Same measured chest drop breaks vase")
assert(box.model:GetAttribute("BlameUserId") == 12, "Last carrier gets blame")
local before = box.model:GetAttribute("HP")
box.root.AssemblyLinearVelocity = V.new(0, 80, 0)
damage:Step()
assert(box.model:GetAttribute("HP") == before, "Cooldown suppresses repeat collision")
clock += Config.DamageCooldownSeconds + 0.01
box.previousVelocity = V.zero
box.root.AssemblyLinearVelocity = V.zero
damage:Step()
assert(box.model:GetAttribute("HP") == before, "Reset velocity sample prevents correction damage")
local delivered = item("delivered", Defs.vase)
delivered.state = "Delivered"
delivered.previousVelocity = V.new(0, -80, 0)
damage:Step()
assert(delivered.model:GetAttribute("HP") == 100, "Delivered furniture cannot lose value")
local grace = item("grace", Defs.vase)
grace.graceUntil = clock + Config.GrabGraceSeconds
grace.previousVelocity = V.new(0, -80, 0)
damage:Step()
assert(grace.model:GetAttribute("HP") == 100, "Ownership/teleport grace ignores artificial impulse")
print(
	"PASS DamageService: sampled chest-speed impact, box/vase distinction, blame, cooldown, correction reset, grace and delivered protection"
)
local carried = item("carried", Defs.vase)
carried.state = "Carried"
carried.previousVelocity = V.new(24, 0, 0)
damage:Step()
assert(carried.model:GetAttribute("HP") == 100, "Careful carried doorway bump causes no damage")
clock += Config.DamageCooldownSeconds + 0.01
carried.previousVelocity = V.new(50, 0, 0)
damage:Step()
assert(removed.carried, "Fast carried crash still breaks fragile furniture")
local dropped = item("dropped", Defs.vase)
dropped.previousVelocity = V.new(24, 0, 0)
damage:Step()
assert(
	dropped.model:GetAttribute("HP") == 37.5,
	"Same speed after release retains normal damage threshold"
)
print(
	"PASS carried impact tuning: gentle doorway bumps spared, severe impacts and released drops still damage"
)

local cargo = item("cargo", Defs.vase)
cargo.state = "InTruck"
cargo.model:SetAttribute("Strapped", true)
cargo.truck = { driverId = 55, bed = { AssemblyLinearVelocity = V.new(60, 0, 0) } }
cargo.root.AssemblyLinearVelocity = V.new(60, 0, 0)
cargo.graceUntil = clock + 0.01
damage:Step()
clock += 0.02
cargo.truck.bed.AssemblyLinearVelocity = V.zero
cargo.root.AssemblyLinearVelocity = V.zero
damage:Step()
assert(
	cargo.model:GetAttribute("HP") == 100,
	"Shared braking motion is not an independent cargo impact"
)
cargo.root.AssemblyLinearVelocity = V.new(0, 24, 0)
damage:Step()
assert(cargo.model:GetAttribute("HP") == 37.5, "Straps do not make real relative impacts immune")

items.records = {}
events, removed = {}, {}
for index = 1, Config.MaxActiveAssemblies do
	item("batch-" .. index, Defs.vase)
end
local frames = 600
local started = os.clock()
for _ = 1, frames do
	clock += 1 / 60
	damage:Step()
end
local milliseconds = (os.clock() - started) * 1000 / frames
assert(#events == 0, "Stationary full-capacity batch emits no damage events")
for _, rec in items.records do
	rec.previousVelocity = V.new(0, -37, 0)
end
damage:Step()
assert(
	next(items.records) == nil and #events == Config.MaxActiveAssemblies,
	"Every broken record is processed once while removing the full batch"
)
print(
	string.format(
		"PASS damage batch: %d active items, 600 stationary frames, %.3f ms/Step in Lune mocks (not Studio/mobile profiling), then all simultaneous breaks",
		Config.MaxActiveAssemblies,
		milliseconds
	)
)
