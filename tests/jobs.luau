local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local V, CF = rb.Vector3, rb.CFrame
local Config = require("../src/shared/Config")
local Schema = require("../src/shared/Logic/ProfileSchema")
local JobGen = require("../src/shared/Logic/JobGen")
local Rules = require("../src/shared/Logic/JobRules")
local Payout = require("../src/shared/Logic/Payout")
local Defs = require("../src/shared/ItemDefs")
assert(Rules.phase("Loading", { a = "Idle" }, false) == "Loading", "Wait for pickup")
assert(Rules.phase("Loading", { a = "InTruck", b = "Broken" }, false) == "Driving", "Load complete")
assert(Rules.phase("Driving", { a = "InTruck" }, true) == "Unloading", "Arrive at destination")
assert(Rules.phase("Loading", { a = "Broken" }, false) == "Payout", "All broken still completes")
assert(not Rules.deliverable("InTruck", true, true), "Must unload cargo")
assert(Rules.deliverable("Carried", false, true), "Carrying inside counts")
assert(not Rules.deliverable("Delivered", false, true), "No repeated delivery")

local stamp, serial, messages, cleared = 1000, 0, {}, 0
local function folder(children)
	local result = table.clone(children)
	function result:FindFirstChild(key)
		return children[key]
	end
	return result
end
local function part(position, size)
	return {
		CFrame = CF.new(position),
		Position = position,
		Size = size or V.new(2, 2, 2),
		IsA = function(_, kind)
			return kind == "BasePart"
		end,
	}
end
local zone = part(V.new(1000, 10, 0), V.new(72, 20, 72))
local pickup = folder({
	Pad = folder({
		HouseOrigin = { WorldCFrame = CF.identity },
		TruckSpot = { WorldCFrame = CF.new(20, 3, 0) },
	}),
})
local destination = folder({
	Pad = folder({ HouseOrigin = { WorldCFrame = CF.new(1000, 0, 0) } }),
	DeliveryZone = zone,
})
local counter = part(V.new(200, 2, 0))
local map = folder({
	Lots = folder({ PickupLot_1 = pickup, DestinationLot_1 = destination }),
	HQ = folder({
		Garage = folder({ ShopCounter = counter }),
		TruckDocks = folder({
			TruckDock_1 = folder({ Spawn = { WorldCFrame = CF.new(200, 3, 0) } }),
		}),
	}),
})
local world = folder({ Map = map })
function world:GetServerTimeNow()
	return stamp
end
local Players = { PlayerRemoving = { Connect = function() end } }
local player = {
	UserId = 42,
	Parent = Players,
	attributes = {},
	Character = {
		PivotTo = function(self, cf)
			self.position = cf.Position
		end,
		FindFirstChild = function()
			return {}
		end,
	},
}
function player:GetAttribute(key)
	return self.attributes[key]
end
function Players:GetPlayers()
	return { player }
end
local data = { saved = Schema.new(), updates = 0 }
function data:Get()
	return self.saved
end
function data:Update(_, callback)
	local draft = Schema.copy(self.saved)
	local ok, reason = callback(draft)
	if ok == false then
		return false, reason
	end
	local checked = Schema.prepare(draft)
	assert(checked, "Awards preserve valid save")
	self.saved = checked
	self.updates += 1
	return true
end
local remotes = { Job = {} }
for _, name in { "State", "Payout" } do
	remotes.Job[name] = {
		FireClient = function(_, who, payload)
			table.insert(messages, { name = name, who = who, payload = payload })
		end,
	}
end
local crew = { id = "crew-test", padId = 1, members = { player } }
local crews = { crews = { [1] = crew } }
function crews:CrewOf()
	return crew
end
function crews:OnStart(fn)
	self.onStart = fn
end
function crews:Disband(c)
	c.members = {}
	self.crews[c.padId] = nil
	if self.onEmpty then
		self.onEmpty(c)
	end
end
local builder = {}
function builder.Build(layout, lot)
	local sockets = {}
	for _, socket in layout.items do
		sockets[`{socket.roomIndex}:{socket.socketName}`] = CF.new(socket.roomIndex, 0, 0)
	end
	return {
		GetAttribute = function()
			return lot.Pad.HouseOrigin.WorldCFrame.Position
		end,
	},
		sockets
end
function builder.Clear(house)
	if house then
		cleared += 1
	end
end
local shared = {
	Config = Config,
	Logic = {
		JobGen = JobGen,
		JobRules = Rules,
		Payout = Payout,
		PassBenefits = require("../src/shared/Logic/PassBenefits"),
	},
}
local gameMock = {
	GetService = function(_, name)
		if name == "Players" then
			return Players
		end
		if name == "HttpService" then
			return {
				GenerateGUID = function()
					serial += 1
					return "job-" .. serial
				end,
			}
		end
		return {
			WaitForChild = function()
				return shared
			end,
		}
	end,
}
local env = {
	game = gameMock,
	workspace = world,
	script = { Parent = { HouseBuilder = builder } },
	CFrame = CF,
	Vector3 = V,
	Enum = rb.Enum,
	require = function(value)
		return value
	end,
	warn = function() end,
}
local PayoutService =
	luau.load(fs.readFile("src/server/Services/PayoutService.luau"), { environment = env })()
local JobService =
	luau.load(fs.readFile("src/server/Services/JobService.luau"), { environment = env })()
local items = { records = {}, spawned = 0 }
local failSpawn
function items:Spawn(id, crewId, cf)
	self.spawned += 1
	if failSpawn and self.spawned == failSpawn then
		return nil, "MissingTemplate"
	end
	local uid = "item-" .. self.spawned
	local root = part(cf.Position)
	local attrs = { HP = 100, BlameUserId = 0 }
	local model = {
		Parent = true,
		GetAttribute = function(_, key)
			return attrs[key]
		end,
		SetAttribute = function(_, key, value)
			attrs[key] = value
		end,
		GetDescendants = function()
			return { root }
		end,
	}
	local rec = {
		uid = uid,
		crewId = crewId,
		def = Defs[id],
		root = root,
		model = model,
		state = "Idle",
		a = 0,
		b = 0,
	}
	self.records[uid] = rec
	return rec
end
function items:DropUser(id)
	for _, rec in self.records do
		if rec.a == id or rec.b == id then
			rec.a, rec.b, rec.state = 0, 0, "Idle"
		end
	end
end
function items:SetState(rec, state)
	rec.state = state
end
function items:SetOwner()
	return true
end
function items:Fire() end
function items:Remove(rec, broken)
	if self.onRemoved then
		self.onRemoved(rec, broken)
	end
	self.records[rec.uid] = nil
end
local trucks = { trucks = {} }
function trucks:Spawn(crewId, cf, upgrades)
	self.spawnedUpgrades = upgrades
	local truck = { root = part(cf.Position) }
	self.trucks[crewId] = truck
	return truck
end
function trucks:Remove(crewId)
	self.trucks[crewId] = nil
end
local payouts = PayoutService.new(data, remotes)
local payoutAnalytics = { sources = 0, steps = 0, completions = 0 }
function payoutAnalytics:Funnel(_, step)
	assert(step == 6, "Payout emits only first payout funnel hook")
	self.steps += 1
end
function payoutAnalytics:Economy(_, amount, endingBalance)
	assert(amount > 0 and endingBalance == data.saved.cash, "Only committed cash is reported")
	self.sources += 1
end
function payoutAnalytics:Custom(_, event)
	assert(event == "JobCompleted", "Completion custom event")
	self.completions += 1
end
payouts.analytics = payoutAnalytics
local jobs = JobService.new(crews, items, trucks, payouts, data, remotes, {})
jobs:Bind()
local id = jobs:StartJob(crew)
assert(trucks.spawnedUpgrades == data.saved.upgrades, "Truck receives the leader's saved upgrades")
assert(id and jobs.jobs[crew.id], "Start first-session job")
local job = jobs.jobs[crew.id]
assert(#job.order == 6 and player.Character.position, "Starter manifest and direct arrival")
assert(job.destinationHouse, "Destination has a house")
for _, rec in items.records do
	rec.state = "InTruck"
	rec.truck = job.truck
end
jobs:Step(Config.JobPollSeconds)
assert(job.phase == "Driving", "All items loaded begins drive")
job.truck.root.Position = zone.Position
for _, rec in items.records do
	rec.root.Position = zone.Position
end
jobs:Step(Config.JobPollSeconds)
assert(
	job.phase == "Unloading" and data.saved.cash == 0,
	"Driving loaded truck through zone is not delivery"
)
for _, rec in items.records do
	rec.state = "Idle"
	rec.truck = nil
end
jobs:Step(Config.JobPollSeconds)
assert(
	job.phase == "Payout" and data.saved.cash > Config.JobFee.Starter,
	"Unloaded items pay kept value"
)
assert(
	data.saved.firstJobDone and data.saved.stats.jobs == 1 and data.saved.stats.delivered == 6,
	"First job and stats saved"
)
local balance = data.saved.cash
for _ = 1, 5 do
	jobs:Step(Config.JobPollSeconds)
end
assert(
	data.saved.cash == balance and data.updates == 1,
	"Repeated payout ticks cannot duplicate awards"
)
assert(
	payoutAnalytics.sources == 1 and payoutAnalytics.steps == 1 and payoutAnalytics.completions == 1,
	"Payout retries do not duplicate analytics"
)
stamp += Config.PayoutDisplaySeconds
jobs:Step(Config.JobPollSeconds)
assert(
	next(jobs.jobs) == nil
		and next(items.records) == nil
		and next(trucks.trucks) == nil
		and cleared == 2,
	"Completion clears both houses/cargo/truck"
)
assert(
	#crew.members == 0 and player.Character.position.X == counter.Position.X,
	"Crew returns to HQ and disbands"
)
crew.members, crews.crews[1] = { player }, crew
assert(jobs:StartJob(crew), "Returning crew starts next job")
job = jobs.jobs[crew.id]
for index, uid in job.order do
	local rec = items.records[uid]
	if index == 1 then
		rec.lastCarrier = 99
	elseif index == 2 then
		rec.lastCarrier, rec.truck = 99, { driverId = 55 }
	elseif index == 3 then
		rec.model:SetAttribute("BlameUserId", 77)
		rec.lastCarrier = 99
	elseif index == 4 then
		rec.lastCarrier = -12
	end
	items:Remove(rec, true)
end
assert(job.snapshots[job.order[1]].blame == 99, "Zero sentinel falls back to last carrier")
assert(job.snapshots[job.order[2]].blame == 55, "Lost truck cargo falls back to driver")
assert(job.snapshots[job.order[3]].blame == 77, "Explicit impact blame is preserved")
assert(job.snapshots[job.order[4]].blame == -12, "Studio player identities remain valid")
assert(
	job.snapshots[job.order[5]].blame == 0 and job.snapshots[job.order[5]].hp == 0,
	"Unassigned loss has zero value and unknown blame"
)
jobs:Step(Config.JobPollSeconds)
assert(
	job.phase == "Payout" and data.saved.cash == balance + Config.JobFee.Starter,
	"All broken pays job fee"
)
jobs:Cleanup(job, false, true)
failSpawn = items.spawned + 3
assert(jobs:StartJob(crew) == nil, "Missing furniture fails setup")
assert(
	next(jobs.jobs) == nil
		and next(items.records) == nil
		and next(trucks.trucks) == nil
		and #crew.members == 1,
	"Failed setup rolls back resources but retains crew for retry"
)
assert(messages[#messages].payload, "Contract messages emitted")
print(
	"PASS JobRules and job lifecycle: first-session spawn, manifest/phases, unload-only delivery, payout once, all-broken fee, HQ cleanup and failed-start rollback"
)
