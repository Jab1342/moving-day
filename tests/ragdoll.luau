local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local V, CF = rb.Vector3, rb.CFrame
local Config = require("../src/shared/Config")
local DamageModel = require("../src/shared/Logic/DamageModel")
local Defs = require("../src/shared/ItemDefs")
local stamp, queries, overlapHits, castHit = 10, 0, {}, nil
local Players = {}
local function player(id, crewId)
	local humanoid = { Health = 100, Sit = false }
	local root = {
		AssemblyLinearVelocity = V.zero,
		IsA = function(_, kind)
			return kind == "BasePart"
		end,
	}
	local character = {
		FindFirstChildOfClass = function()
			return humanoid
		end,
		FindFirstChild = function()
			return root
		end,
	}
	local limb = {
		IsDescendantOf = function(_, other)
			return other == character
		end,
	}
	return {
		UserId = id,
		Parent = Players,
		Character = character,
		humanoid = humanoid,
		root = root,
		limb = limb,
		GetAttribute = function(_, key)
			return if key == "CrewId" then crewId else false
		end,
	}
end
local a, b, c = player(1, "A"), player(2, "B"), player(3, "A")
function Players:GetPlayers()
	return { a, b, c }
end
function Players:GetPlayerByUserId(id)
	return if id == 1 then a else nil
end
local world = {}
local function checkFilter(params)
	queries += 1
	assert(
		params.FilterType == "Include" and params.RespectCanCollide == false,
		"Only explicit eligible character query targets"
	)
	assert(
		not table.find(params.FilterDescendantsInstances, b.Character),
		"Another crew is never queried by crew A cargo"
	)
end
function world:GetPartBoundsInBox(_, _, params)
	checkFilter(params)
	assert(params.MaxParts == Config.RagdollQueryMaxParts, "Overlap output is bounded")
	return table.clone(overlapHits)
end
function world:Blockcast(_, _, sweep, params)
	checkFilter(params)
	assert(sweep.Magnitude <= Config.RagdollMaxSweepStuds, "Cast length is bounded")
	return if castHit then { Instance = castHit } else nil
end
local shared = { Config = Config, Logic = { DamageModel = DamageModel } }
local Service = luau.load(fs.readFile("src/server/Services/DamageService.luau"), {
	environment = {
		game = {
			GetService = function(_, name)
				return if name == "Players"
					then Players
					else {
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
		os = {
			clock = function()
				return stamp
			end,
		},
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		OverlapParams = {
			new = function()
				return {}
			end,
		},
		Enum = { RaycastFilterType = { Include = "Include" } },
	},
})()
local function scenario()
	stamp, queries, overlapHits, castHit = 10, 0, {}, nil
	a.Parent, a.humanoid.Health, a.humanoid.Sit, a.root.AssemblyLinearVelocity =
		Players, 100, false, V.zero
	c.humanoid.Health, c.humanoid.Sit, c.root.AssemblyLinearVelocity = 100, false, V.zero
	local fired, attributes = {}, { HP = 100, BlameUserId = 0 }
	local root = {
		CFrame = CF.identity,
		Size = V.new(2, 2, 2),
		AssemblyLinearVelocity = V.new(50, 0, 0),
		Anchored = false,
		CanCollide = true,
	}
	local model = {
		GetAttribute = function(_, key)
			return attributes[key]
		end,
		SetAttribute = function(_, key, value)
			attributes[key] = value
		end,
		GetPivot = function()
			return root.CFrame
		end,
	}
	local rec = {
		uid = "cargo",
		root = root,
		model = model,
		state = "Idle",
		crewId = "A",
		a = 0,
		b = 0,
		graceUntil = 0,
		lastDamageAt = -100,
		lastCarrier = 1,
		def = Defs.box,
	}
	local items = {
		records = { cargo = rec },
		remotes = {
			Fx = {
				Ragdoll = {
					FireClient = function(_, who, duration, impulse)
						assert(
							duration == Config.RagdollSeconds
								and impulse.Magnitude <= Config.RagdollMaxKnockback + 0.00001,
							"Bounded two-second ragdoll"
						)
						assert(
							math.abs(impulse.Y) <= Config.RagdollMaxVerticalKnockback,
							"Vertical knockback cannot launch player"
						)
						table.insert(fired, { player = who, impulse = impulse })
					end,
				},
			},
		},
	}
	function items:Fire() end
	function items:Remove(item)
		self.records[item.uid] = nil
	end
	return Service.new(items), rec, fired
end
local service, rec, fired = scenario()
service:Step() -- First sample has no actual contact.
assert(#fired == 0, "Speed without geometric contact is not a hit")
local beforeQueries = queries
stamp += Config.RagdollPollSeconds / 2
service:Step()
assert(queries == beforeQueries, "World queries are throttled below Heartbeat rate")
stamp += Config.RagdollPollSeconds
rec.root.CFrame = CF.new(5, 0, 0)
rec.root.AssemblyLinearVelocity = V.zero
castHit = a.limb
service:Step()
assert(
	#fired == 1 and fired[1].player == a and a.humanoid.Health == 100,
	"Swept incoming item stuns its crew without health damage"
)
assert(fired[1].impulse.X == 10, "Knockback is capped velocity delta, not item mass force")

local function probe(testedService, record)
	local context = testedService:PlayerHitContext(stamp)
	assert(context ~= nil, "Fixture has eligible poll context")
	testedService:CheckPlayerHits(record, stamp, context)
end
for _, state in { "Carried", "Delivered", "Broken" } do
	service, rec, fired = scenario()
	rec.state = state
	overlapHits = { a.limb }
	probe(service, rec)
	assert(#fired == 0 and queries == 0, "Carried or finished items cannot ragdoll characters")
end
for _, condition in { "carrier", "weld", "anchored", "noncolliding", "grace", "slow", "nonfinite" } do
	service, rec, fired = scenario()
	if condition == "carrier" then
		rec.a = 1
	elseif condition == "weld" then
		rec.weld = {}
	elseif condition == "anchored" then
		rec.root.Anchored = true
	elseif condition == "noncolliding" then
		rec.root.CanCollide = false
	elseif condition == "grace" then
		rec.graceUntil = stamp + 1
	elseif condition == "slow" then
		rec.root.AssemblyLinearVelocity = V.new(Config.RagdollHitSpeed, 0, 0)
	else
		rec.root.AssemblyLinearVelocity = V.new(math.huge, 0, 0)
	end
	overlapHits = { a.limb }
	probe(service, rec)
	assert(
		#fired == 0 and queries == 0,
		"Ineligible source causes no spatial query or stun: " .. condition
	)
end
service, rec, fired = scenario()
rec.root.CFrame = CF.new(0, 0, 0, math.huge, 0, 0, 0, 1, 0, 0, 0, 1)
overlapHits = { a.limb }
probe(service, rec)
assert(#fired == 0 and queries == 0, "Invalid rotation cannot reach spatial APIs")
service, rec, fired = scenario()
overlapHits = { a.limb, a.limb, b.limb, c.limb }
probe(service, rec)
assert(
	#fired == 2 and fired[1].player == a and fired[2].player == c,
	"Deduplicate limbs and isolate crews even if query returns foreign parts"
)
stamp += Config.RagdollPollSeconds + 0.01
probe(service, rec)
assert(#fired == 2, "Per-player cooldown suppresses repeated hits from any item")
stamp += Config.RagdollCooldownSeconds
rec.ragdollSample = nil
probe(service, rec)
assert(#fired == 4, "Cooldown expires")
service, rec, fired = scenario()
a.humanoid.Sit = true
c.humanoid.Health = 0
overlapHits = { a.limb, c.limb }
probe(service, rec)
assert(#fired == 0 and queries == 0, "Seated and dead characters excluded before queries")
service, rec, fired = scenario()
a.root.AssemblyLinearVelocity = rec.root.AssemblyLinearVelocity
overlapHits = { a.limb }
probe(service, rec)
assert(#fired == 0, "No ragdoll from shared platform motion without relative impact speed")
for _, condition in { "teleport", "stale" } do
	service, rec, fired = scenario()
	probe(service, rec)
	queries = 0
	stamp += if condition == "stale"
		then Config.RagdollMaxSampleSeconds + 0.01
		else Config.RagdollPollSeconds + 0.01
	rec.root.CFrame =
		CF.new(if condition == "teleport" then Config.RagdollMaxSweepStuds + 1 else 1, 0, 0)
	overlapHits = { a.limb }
	probe(service, rec)
	assert(
		#fired == 0 and queries == 0,
		"Discontinuity cannot invent a swept impact: " .. condition
	)
end
service, rec, fired = scenario()
rec.root.AssemblyLinearVelocity = V.new(100, 100, 100)
overlapHits = { a.limb }
probe(service, rec)
assert(#fired == 1, "High-speed collision still uses bounded knockback")
a.Parent = nil
stamp += Config.RagdollPollSeconds + 0.01
service:PlayerHitContext(stamp)
assert(service.ragdollTimes[a] == nil, "Departed player cooldown released")
service.items.records = {}
assert(service:PlayerHitContext(stamp + 1) == nil, "No active items means no query context")
print(
	"PASS item ragdoll: swept/overlap contact, same-crew isolation, incoming relative speed, grace/state/seat gates, query throttling, cooldown, discontinuity rejection and bounded knockback without HP damage"
)
