local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local Config = require("../src/shared/Config")
local Cargo = require("../src/shared/Logic/CargoRules")
local V, CF = rb.Vector3, rb.CFrame
local clock = 10
local driver = {
	UserId = 123,
	GetAttribute = function()
		return "crew"
	end,
}
local shared = {
	Config = Config,
	Logic = {
		CargoRules = Cargo,
		TruckUpgradeRules = require("../src/shared/Logic/TruckUpgradeRules"),
	},
}
local Service = luau.load(fs.readFile("src/server/Services/TruckService.luau"), {
	environment = {
		game = {
			GetService = function(_, name)
				if name == "Players" then
					return {
						GetPlayerByUserId = function()
							return driver
						end,
						GetPlayerFromCharacter = function(_, character)
							return character.player
						end,
					}
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
		workspace = { Gravity = 196.2 },
		Vector3 = V,
		os = {
			clock = function()
				return clock
			end,
		},
		Instance = {
			new = function()
				return {
					Destroy = function(self)
						self.destroyed = true
					end,
				}
			end,
		},
	},
})()
local function scenario()
	local items = { records = {} }
	function items:SetState(rec, state)
		rec.state = state
	end
	function items:SetOwner(rec, player, automatic)
		rec.owner, rec.automatic = player, automatic
	end
	function items:Grace(rec, seconds)
		rec.grace = seconds
	end
	function items:Fire() end
	local service = Service.new({}, items)
	local bed =
		{ CFrame = CF.identity, Size = V.new(8, 1, 10), AssemblyLinearVelocity = V.new(40, 0, 0) }
	function bed:GetVelocityAtPosition()
		return self.AssemblyLinearVelocity
	end
	local truck = {
		model = {
			Parent = true,
			GetDescendants = function()
				return {}
			end,
		},
		bed = bed,
		crewId = "crew",
		driverId = 123,
		previousVelocity = bed.AssemblyLinearVelocity,
	}
	service.trucks.crew = truck
	for _, strapped in { false, true } do
		local attributes = { Strapped = strapped }
		local model = {
			GetAttribute = function(_, key)
				return attributes[key]
			end,
			SetAttribute = function(_, key, value)
				attributes[key] = value
			end,
		}
		local rec = {
			a = 0,
			state = "InTruck",
			crewId = "crew",
			truck = truck,
			model = model,
			root = {
				Position = V.new(0, 1.5, 0),
				AssemblyLinearVelocity = bed.AssemblyLinearVelocity,
			},
			settledFor = 0,
			weld = {
				Destroy = function(self)
					self.destroyed = true
				end,
			},
		}
		items.records[if strapped then "strapped" else "loose"] = rec
	end
	return service, truck, items.records
end
for _, hz in { 30, 60, 120 } do
	local service, truck, records = scenario()
	local oldLoose, oldStrap = records.loose.weld, records.strapped.weld
	local speed = 40
	while speed > 0 do
		clock += 1 / hz
		speed = math.max(0, speed - 0.5 * 196.2 / hz)
		truck.bed.AssemblyLinearVelocity = V.new(speed, 0, 0)
		service:Step(1 / hz)
	end
	assert(
		oldLoose.destroyed and records.loose.weld == nil,
		"Actual TruckService unwelds loose cargo during a 40 stud/s 0.5g stop"
	)
	assert(
		not oldStrap.destroyed and records.strapped.weld == oldStrap,
		"Same stop keeps strapped weld"
	)
	assert(
		records.loose.owner == driver and records.loose.automatic == false,
		"Unwelded cargo inside bed retains designated driver ownership"
	)
	records.loose.root.Position = V.new(20, 2, 0)
	service:Step(1 / hz)
	assert(
		records.loose.state == "Idle"
			and records.loose.truck == nil
			and records.loose.owner == nil
			and records.loose.automatic == false,
		"Cargo outside bed releases to explicit server ownership"
	)
	assert(
		records.loose.grace == Config.DropGraceSeconds,
		"Spill does not mask ground impact with grab grace"
	)
end
local service, truck, records = scenario()
truck.bed.CFrame = CF.Angles(0, 0, math.rad(40))
service:Step(1 / 60)
assert(
	records.loose.weld == nil and records.strapped.weld == nil,
	"Severe tilt releases both welds"
)
-- Reproduce the ownership transition behind the parked-ramp Studio failure.
local function assembly(anchored, canOwn)
	return {
		Anchored = anchored,
		calls = 0,
		IsA = function(_, kind)
			return kind == "BasePart"
		end,
		CanSetNetworkOwnership = function()
			return canOwn
		end,
		SetNetworkOwner = function(self, owner)
			self.owner, self.calls = owner, self.calls + 1
		end,
		SetNetworkOwnershipAuto = function()
			error("A parked truck cannot go back to automatic ownership")
		end,
	}
end
service, truck, records = scenario()
local chassis, wheel, decoration, constrainedToAnchor =
	assembly(false, true), assembly(false, true), assembly(true, true), assembly(false, false)
local sharedRootPart = assembly(false, true)
sharedRootPart.AssemblyRootPart = chassis
truck.model.GetDescendants = function()
	return { chassis, sharedRootPart, wheel, decoration, constrainedToAnchor }
end
local driverAttribute
truck.model.SetAttribute = function(_, key, value)
	assert(key == "DriverUserId", "Only the driver attribute changes")
	driverAttribute = value
end
truck.seat = { Occupant = { Parent = { player = driver } } }
service:UpdateDriver(truck)
assert(chassis.owner == driver and wheel.owner == driver, "Driver owns every vehicle assembly")
assert(chassis.calls == 1 and sharedRootPart.calls == 0, "Welded roots assigned only once")
assert(decoration.calls == 0 and constrainedToAnchor.calls == 0, "Skip anchored mechanisms")
assert(driverAttribute == driver.UserId and records.loose.owner == driver, "Driver and cargo agree")
truck.seat.Occupant = nil
service:UpdateDriver(truck)
assert(chassis.owner == nil and wheel.owner == nil, "Exit assigns parked vehicle to server")
assert(chassis.calls == 2 and wheel.calls == 2, "Exit explicitly disables automatic ownership")
assert(
	records.loose.owner == nil and records.loose.automatic == false,
	"Parked cargo also stays server-owned"
)
assert(driverAttribute == 0 and truck.driverId == 0, "No parked driver attribute")
truck.seat.Occupant = {
	Parent = { player = {
		GetAttribute = function()
			return "other-crew"
		end,
	} },
	Sit = true,
}
service:UpdateDriver(truck)
assert(
	not truck.seat.Occupant.Sit and chassis.owner == nil,
	"Foreign crew cannot take vehicle ownership"
)
print(
	"PASS TruckService: loose/strapped weld decisions at 30/60/120Hz, explicit ownership and short spill grace; physical sliding still requires Studio"
)
