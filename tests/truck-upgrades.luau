local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local V, CF = rb.Vector3, rb.CFrame
local Config = require("../src/shared/Config")
local Rules = require("../src/shared/Logic/TruckUpgradeRules")
local Cargo = require("../src/shared/Logic/CargoRules")
local base = Rules.options()
assert(
	base.template == "TRK_Pickup" and not base.ramp and base.cargoScale == 1,
	"Default pickup setup"
)
local purchased = { BoxTruck = 1, LoadingRamp = 1, SoftSuspension = 1 }
local upgraded = Rules.options(purchased)
assert(
	upgraded.template == "TRK_Box" and upgraded.ramp and purchased.SoftSuspension == 1,
	"Combined upgrades preserve input"
)
assert(
	upgraded.maxSpeed < base.maxSpeed and upgraded.maxSteer < base.maxSteer,
	"Speed and steering tradeoffs"
)
assert(
	upgraded.stiffnessScale < 1 and upgraded.dampingScale > 1 and upgraded.cargoScale < 1,
	"Softer springs and reduced cargo acceleration"
)
for _, height in { 2, 2.5, 3.2, 5 } do
	for _, pitch in { -0.1, 0, 0.1 } do
		local upY, backY = math.cos(pitch), -math.sin(pitch)
		local angle = Rules.rampPitch(-3.2, 6, upY, backY, height)
		assert(angle, "Ground within hinge reach")
		local y = -3.2 * math.cos(angle) - 6 * math.sin(angle)
		local z = -3.2 * math.sin(angle) + 6 * math.cos(angle)
		assert(math.abs(upY * y + backY * z + height) < 0.00001, "Ramp foot meets ground")
	end
end
assert(math.abs(Rules.rampPitch(-3.2, 6, 1, 0, 3.2)) < 0.00001, "Design height needs no pitch")
assert(not Rules.rampPitch(-3.2, 6, 1, 0, 100), "Unreachable ground")
assert(not Rules.rampPitch(-3.2, 6, 1, 0, 0), "Ground above hinge")
assert(not Rules.rampPitch(-3.2, 0, 1, 0, 3), "Invalid foot")
assert(not Rules.rampPitch(-3.2, 6, 1, 0, 0 / 0), "NaN rejected")
assert(not Rules.rampPitch(-3.2, 6, 1, 0, math.huge), "Infinity rejected")

local function node(kind, children)
	local object = { children = children or {}, Parent = true, attributes = {} }
	function object:IsA(class)
		return class == kind or (class == "BasePart" and kind == "Part")
	end
	function object:FindFirstChild(name)
		return self.children[name]
	end
	function object:GetDescendants()
		local out = {}
		for _, child in self.children do
			table.insert(out, child)
			for _, descendant in child:GetDescendants() do
				table.insert(out, descendant)
			end
		end
		return out
	end
	function object:FindFirstChildWhichIsA(class)
		for _, child in self:GetDescendants() do
			if child:IsA(class) then
				return child
			end
		end
		return nil
	end
	function object:SetAttribute(key, value)
		self.attributes[key] = value
	end
	return object
end
local function template()
	local mount = node("Attachment")
	mount.WorldCFrame = CF.new(0, 2.5, 0)
	local root = node("Part", { RampMount = mount })
	local spring = node("SpringConstraint")
	spring.Stiffness, spring.Damping = 100, 20
	local seat, bed, tailgate = node("VehicleSeat"), node("Part"), node("Part")
	bed.AssemblyLinearVelocity = V.zero
	tailgate.CanCollide = true
	local model = node(
		"Model",
		{ Chassis = root, DriverSeat = seat, BedFloor = bed, Spring = spring, Tailgate = tailgate }
	)
	model.PrimaryPart = root
	return model
end
local pickup, box = template(), template()
local rampRoot = node("Part")
rampRoot.CanCollide, rampRoot.Anchored = true, true
rampRoot.Size, rampRoot.CFrame = V.new(5, 3.2, 6), CF.new(0, -1.6, 3)
function rampRoot:CanSetNetworkOwnership()
	return true
end
function rampRoot:SetNetworkOwner(player)
	self.owner, self.ownerCalls = player, (self.ownerCalls or 0) + 1
end
local rails = node("Part")
rails.CanCollide = false
local ramp = node("Model", { Ramp = rampRoot, Rails = rails })
ramp.PrimaryPart = rampRoot
function ramp:GetPivot()
	return CF.identity
end
function ramp:Clone()
	return self
end
local lastWeld, pivotCalls = nil, 0
function ramp:PivotTo(cf)
	assert(
		not lastWeld or lastWeld.destroyed,
		"Detach before moving ramp; never move the truck assembly"
	)
	assert(not rampRoot.CanCollide and not rails.CanCollide, "Disable collision during pivot")
	self.pivot = cf
	pivotCalls += 1
end
local templates = node("Folder", { TRK_Pickup = pickup, TRK_Box = box })
local upgradeTemplates = node("Folder", { LoadingRamp = ramp })
local storage = node("Folder", { Trucks = templates, Upgrades = upgradeTemplates })
local shared = { Config = Config, Logic = { CargoRules = Cargo, TruckUpgradeRules = Rules } }
local world = { Gravity = 196.2 }
local ground, normal, raycasts = 0, V.yAxis, 0
local character, truckFolder, itemFolder = {}, {}, {}
function world:Raycast(_, _, params)
	raycasts += 1
	assert(
		params.IgnoreWater and params.FilterDescendantsInstances[1] == truckFolder,
		"Exclude truck from ground probe"
	)
	assert(
		params.FilterDescendantsInstances[2] == itemFolder
			and params.FilterDescendantsInstances[3] == character,
		"Exclude cargo and characters from ground probe"
	)
	return if ground then { Position = V.new(0, ground, 0), Normal = normal } else nil
end
local clock = 10
local Service = luau.load(fs.readFile("src/server/Services/TruckService.luau"), {
	environment = {
		game = {
			GetService = function(_, name)
				if name == "ServerStorage" then
					return storage
				end
				if name == "Players" then
					return {
						GetPlayers = function()
							return { { Character = character } }
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
		require = function(value)
			return value
		end,
		workspace = world,
		Vector3 = V,
		CFrame = CF,
		os = {
			clock = function()
				return clock
			end,
		},
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		Enum = { RaycastFilterType = { Exclude = "Exclude" } },
		Instance = {
			new = function(kind)
				assert(kind == "WeldConstraint", "Only a ramp weld is created")
				local weld = {
					Destroy = function(self)
						self.destroyed = true
					end,
				}
				lastWeld = weld
				return weld
			end,
		},
	},
})()
local service = Service.new(truckFolder, { folder = itemFolder, records = {} })
assert(
	service:CanUseUpgrade("BoxTruck")
		and service:CanUseUpgrade("LoadingRamp")
		and service:CanUseUpgrade("SoftSuspension"),
	"Complete templates permit all truck upgrades"
)
assert(
	not service:CanUseUpgrade("Dolly") and not service:CanUseUpgrade("Unknown"),
	"No unrelated purchases"
)
box.children.DriverSeat = node("Part")
assert(not service:CanUseUpgrade("BoxTruck"), "Invalid seat cannot unlock truck purchases")
box.children.DriverSeat = node("VehicleSeat")
local mount = box.PrimaryPart.children.RampMount
local invalidTemplate = node("Folder")
setmetatable(invalidTemplate, {
	__index = function(_, key)
		if key == "PrimaryPart" then
			error("PrimaryPart is not valid on a Folder")
		end
		return nil
	end,
})
templates.children.TRK_Pickup = invalidTemplate
assert(
	not service:CanUseUpgrade("LoadingRamp"),
	"Wrong-class pickup rejects without property errors"
)
templates.children.TRK_Pickup = pickup
box.PrimaryPart.children.RampMount = nil
assert(not service:CanUseUpgrade("LoadingRamp"), "Ramp must work with both truck variants")
box.PrimaryPart.children.RampMount = mount
local spring = box.children.Spring
box.children.Spring = nil
assert(not service:CanUseUpgrade("SoftSuspension"), "Suspension must work with both variants")
box.children.Spring = spring
local truck = {
	model = box,
	root = box.PrimaryPart,
	seat = box.children.DriverSeat,
	bed = box.children.BedFloor,
}
service:InstallUpgrades(truck, upgraded)
assert(
	box.attributes.MD_MaxSpeed == upgraded.maxSpeed
		and box.attributes.MD_MaxSteerAngle == upgraded.maxSteer,
	"Server publishes approved client tuning attributes"
)
assert(
	box.attributes.MD_HighSpeedSteerAngle == upgraded.highSpeedSteer
		and box.attributes.RampLoose == false,
	"Initial ramp and steering state"
)
assert(
	spring.Stiffness == 60 and spring.Damping == 25 and truck.cargoScale == upgraded.cargoScale,
	"Actual spring and cargo tuning"
)
assert(
	not truck.rampStowed and rampRoot.CanCollide and not rails.CanCollide and not rampRoot.Anchored,
	"Deployed ramp is physical; decorative rails stay noncolliding"
)
assert(
	not truck.tailgate.CanCollide
		and truck.rampWeld.Part0 == truck.root
		and truck.rampWeld.Part1 == rampRoot,
	"Weld and tailgate permit loading"
)
assert(
	math.abs(ramp.pivot:PointToWorldSpace(truck.rampFoot).Y) < 0.00001,
	"Actual service fits 3.2-stud wedge to 2.5-stud ride height"
)
local count = pivotCalls
service:UpdateRamp(truck)
assert(pivotCalls == count, "Parked raycasts are throttled")
truck.seat.Occupant = {}
service:UpdateRamp(truck)
assert(
	truck.rampStowed and not rampRoot.CanCollide and truck.tailgate.CanCollide,
	"Seat entry stows ramp immediately"
)
truck.seat.Occupant = nil
truck.bed.AssemblyLinearVelocity = V.new(3, 0, 0)
service:UpdateRamp(truck)
assert(truck.rampStowed, "Unoccupied moving truck keeps ramp stowed")
truck.bed.AssemblyLinearVelocity = V.zero
service:UpdateRamp(truck)
assert(not truck.rampStowed, "Exit at rest redeploys ramp")
ground = nil
clock += Config.RampGroundRefreshSeconds
service:UpdateRamp(truck)
assert(truck.rampStowed and not rampRoot.CanCollide, "No ground leaves ramp safely stowed")
ground, normal = 0, V.xAxis
service:UpdateRamp(truck, true)
assert(truck.rampStowed, "Vertical hit is not loading ground")
normal = V.yAxis
service:UpdateRamp(truck, true)
service:BreakRamp(truck)
assert(
	truck.rampLoose and box.attributes.RampLoose and lastWeld.destroyed and not truck.rampWeld,
	"Impact releases ramp weld"
)
assert(
	rampRoot.CanCollide
		and not rails.CanCollide
		and truck.tailgate.CanCollide
		and rampRoot.ownerCalls == 1,
	"Loose ramp restores collision and server ownership"
)
count = pivotCalls
service:UpdateRamp(truck, true)
service:BreakRamp(truck)
assert(
	pivotCalls == count and rampRoot.ownerCalls == 1,
	"Detached ramp never teleports or reattaches until next spawn"
)
assert(raycasts > 0, "Service exercised real raycast path with controlled ground")
print(
	"PASS truck upgrade selection/tradeoffs, geometry purchase guards, ground fitting, stow/deploy and one-time ramp release; physical feel still requires Studio"
)
