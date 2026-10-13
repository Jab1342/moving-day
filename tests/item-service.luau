-- Behavior tests with fake services and real Vector3/CFrame math. Engine physics still
-- requires the Studio gate; these exercise authoritative mutations and handoff ordering.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local V = roblox.Vector3
local CF = roblox.CFrame
local config = require("../src/shared/Config")
local carry = require("../src/shared/Contracts/Carry")
local defs = require("../src/shared/ItemDefs")
local events = {}
local ownerSet = false
local function object(class)
	local values = { ClassName = class, children = {}, attributes = {} }
	local proxy
	local methods = {}
	function methods:IsA(expected)
		return expected == class or expected == "BasePart" and class == "Part"
	end
	function methods:FindFirstChild(name)
		return values.children[name]
	end
	function methods:GetAttribute(name)
		return values.attributes[name]
	end
	function methods:SetAttribute(name, value)
		values.attributes[name] = value
	end
	function methods:GetDescendants()
		local out = {}
		for _, child in values.children do
			table.insert(out, child)
		end
		return out
	end
	function methods:CanSetNetworkOwnership()
		return not values.Anchored
	end
	function methods:SetNetworkOwner(player)
		ownerSet = true
		values.owner = player
		values.automatic = false
		table.insert(events, "owner")
	end
	function methods:SetNetworkOwnershipAuto()
		ownerSet = true
		values.owner = nil
		values.automatic = true
		table.insert(events, "auto")
	end
	function methods:GetPivot()
		return CF.new(self.children.Root.Position)
	end
	function methods:PivotTo(cf)
		self.children.Root.Position = cf.Position
		self.children.Root.CFrame = cf
	end
	function methods:Destroy()
		values.Parent = nil
	end
	proxy = setmetatable({}, {
		__index = function(_, key)
			return methods[key] or values[key]
		end,
		__newindex = function(_, key, value)
			if key == "Enabled" and value == true then
				assert(ownerSet, "Constraint enabled before ownership")
				table.insert(events, "enable")
			end
			values[key] = value
			if key == "Parent" and value then
				value.children[values.Name] = proxy
			end
		end,
	})
	return proxy
end
local function player(id, crew)
	local root = object("Part")
	root.Position = V.zero
	local humanoid = { Health = 100 }
	local char = {
		FindFirstChild = function()
			return root
		end,
		FindFirstChildOfClass = function()
			return humanoid
		end,
	}
	local p = { UserId = id, Character = char, crew = crew }
	function p:GetAttribute(name)
		return if name == "CrewId" then self.crew else nil
	end
	return p
end
local p1, p2, p3 = player(101, "A"), player(102, "A"), player(103, "B")
local players = { p1, p2, p3 }
local playerService = {}
function playerService:GetPlayers()
	return players
end
function playerService:GetPlayerByUserId(id)
	for _, p in players do
		if p.UserId == id then
			return p
		end
	end
	return nil
end
local shared = {
	Config = config,
	ItemDefs = defs,
	Contracts = { Carry = carry },
	Logic = {
		CarryRules = require("../src/shared/Logic/CarryRules"),
		RateLimit = require("../src/shared/Logic/RateLimit"),
	},
}
local services = {
	Players = playerService,
	HttpService = {},
	ReplicatedStorage = {
		WaitForChild = function()
			return shared
		end,
	},
}
local relay
local environment = {
	game = {
		GetService = function(_, name)
			return services[name]
		end,
	},
	require = function(value)
		return value
	end,
	Instance = { new = object },
	Enum = roblox.Enum,
	Vector3 = V,
	task = {
		wait = function(seconds)
			coroutine.yield(seconds)
		end,
	},
}
local Item =
	luau.load(fs.readFile("src/server/Services/ItemService.luau"), { environment = environment })()
local remotes = {
	Carry = {
		SecondGripRelay = {
			FireClient = function(_, to, uid, id, pos)
				relay = { to = to, uid = uid, id = id, pos = pos }
			end,
		},
	},
}
local items = Item.new({}, remotes)
local model = object("Model")
model.Name = "test"
model.Parent = object("Folder")
local root = object("Part")
root.Name = "Root"
root.Anchored = false
root.Position = V.new(0, 0, 2)
root.CFrame = CF.new(root.Position)
root.AssemblyLinearVelocity = V.zero
root.Parent = model
for _, name in { "Grip1", "Grip2" } do
	local grip = object("Attachment")
	grip.Name = name
	grip.WorldPosition = root.Position
	grip.Parent = root
end
local rec = {
	uid = "item",
	model = model,
	root = root,
	def = defs.couch,
	crewId = "A",
	a = 0,
	b = 0,
	state = "Idle",
	lastCarrier = 0,
	lastPivot = model:GetPivot(),
}
items.records.item = rec
assert(not items:Grab(p3, "item", 1), "Other crew denied")
assert(not items:Grab(p1, "item", 2), "Second grip cannot precede lead")
ownerSet = false
assert(items:Grab(p1, "item", 1), "Lead grab")
assert(
	rec.a == 101 and items.holding[101] == "item" and model:GetAttribute("State") == "Carried",
	"Server state set"
)
assert(root.owner == p1 and root.CollisionGroup == "Carried", "Ownership and collision")
assert(events[#events] == "enable", "Ownership before constraints")
assert(
	model:GetAttribute("Dolly") == false,
	"Unpaid crew member hauling alone has no purchased dolly"
)
items.upgrades = {
	DollyTier = function(_, candidate)
		return if candidate == p1 then 1 else 0
	end,
}
assert(
	items:ApplyCarriers(rec) and model:GetAttribute("Dolly"),
	"Purchased dolly works while alone on a grip in a crew"
)
assert(not items:Grab(p1, "item", 2), "No double grip")
ownerSet = false
assert(items:Grab(p2, "item", 2), "Second grab")
assert(not model:GetAttribute("Dolly"), "Two carriers switch away from dolly")
items.upgrades = nil
items:Relay(p3, "item", V.zero)
assert(relay == nil, "Noncarrier relay rejected")
items:Relay(p2, "item", V.new(0 / 0, 0, 0))
assert(relay == nil, "NaN relay rejected")
items:Relay(p2, "item", V.new(1, 0, 1))
assert(relay.to == p1 and relay.id == 102, "Grip relay only to lead")
ownerSet = false
items:DropUser(101)
assert(
	rec.a == 102 and rec.b == 0 and root.owner == p2,
	"Disconnect/drop promotes lead and ownership"
)
items:DropUser(102)
assert(
	rec.a == 0 and rec.b == 0 and model:GetAttribute("State") == "Idle",
	"Last drop clears state"
)
assert(root.children.CarryAlignPosition.Enabled == false, "Last drop disables constraint")
assert(
	root.owner == nil and root.automatic == false,
	"Released furniture is explicitly server-owned for authoritative landing samples"
)
assert(
	rec.graceUntil - os.clock() <= config.DropGraceSeconds,
	"Drop does not inherit the full grab grace window"
)
local released = false
items.trucks = {
	Release = function(_, r)
		released = true
		r.truck = nil
		r.model:SetAttribute("Strapped", false)
	end,
	ReserveStrap = function(_, truck)
		truck.pendingStraps += 1
		return true
	end,
}
rec.truck = { pendingStraps = 0 }
rec.state = "InTruck"
model:SetAttribute("Strapped", true)
assert(
	items:Grab(p1, "item", 1) and released and not model:GetAttribute("Strapped"),
	"Own strapped cargo can unload"
)
items:DropUser(101)
rec.state = "InTruck"
rec.truck = { pendingStraps = 0 }
local strap = coroutine.create(function()
	return items:Strap(p1, "item", "Strap")
end)
local ran, seconds = coroutine.resume(strap)
assert(
	ran and seconds == config.StrapSeconds and coroutine.status(strap) == "suspended",
	"Wait for strap completion before success"
)
assert(rec.truck.pendingStraps == 1, "Reservation persists during delay")
assert(not items:Strap(p1, "item", "Strap"), "Cannot double-reserve")
p1.crew = "B"
local resumed, completed, reason = coroutine.resume(strap)
assert(resumed and not completed and reason == "Cancelled", "Cancelled strap returns failure")
assert(
	not model:GetAttribute("Strapped") and rec.truck.pendingStraps == 0,
	"Crew change cancels strap and refunds reservation"
)
p1.crew = "A"
strap = coroutine.create(function()
	return items:Strap(p1, "item", "Strap")
end)
assert(coroutine.resume(strap), "Start strap again")
resumed, completed = coroutine.resume(strap)
assert(
	resumed and completed and model:GetAttribute("Strapped"),
	"Strap success waits for actual attribute"
)
local charges = 0
items.upgrades = {
	PayWrap = function()
		charges += 1
		return true
	end,
}
rec.state, rec.a, rec.b = "Carried", p1.UserId, 0
rec.truck = nil
model:SetAttribute("Wrapped", false)
local wrapping = coroutine.create(function()
	return items:Wrap(p1, rec)
end)
assert(coroutine.resume(wrapping), "Start wrap")
assert(charges == 0 and not model:GetAttribute("Wrapped"), "Do not charge before wrap finishes")
assert(not items:Wrap(p1, rec), "Only one pending wrap")
items.holding[p1.UserId] = rec.uid
items:DropUser(p1.UserId)
resumed, completed = coroutine.resume(wrapping)
assert(resumed and not completed and charges == 0, "Drop cancels without charging")
rec.state, rec.a = "Carried", p1.UserId
wrapping = coroutine.create(function()
	return items:Wrap(p1, rec)
end)
assert(coroutine.resume(wrapping), "Retry wrap")
resumed, completed = coroutine.resume(wrapping)
assert(
	resumed and completed and charges == 1 and model:GetAttribute("Wrapped"),
	"Successful wrap charges once"
)
assert(not items:Wrap(p1, rec) and charges == 1, "Cannot pay twice for same wrapping")
model:SetAttribute("Wrapped", false)
items.upgrades.PayWrap = function()
	return false, "NotEnoughCash"
end
wrapping = coroutine.create(function()
	return items:Wrap(p1, rec)
end)
assert(coroutine.resume(wrapping), "Start unfunded wrap")
resumed, completed = coroutine.resume(wrapping)
assert(
	resumed and not completed and not model:GetAttribute("Wrapped"),
	"No free blanket on failed debit"
)
print(
	"PASS: server ownership/handover; strap completion/cancellation; wrap cancellation, single charge and rejected debit"
)
