local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local V, CF = roblox.Vector3, roblox.CFrame
local Config = require("../src/shared/Config")
local Rate = require("../src/shared/Logic/RateLimit")
local roster, stamp, guid, events = {}, 0, 0, {}
local function signal()
	return { Connect = function() end }
end
local Players = { PlayerRemoving = signal() }
function Players:GetPlayers()
	return roster
end
function Players:GetPlayerByUserId(id)
	for _, p in roster do
		if p.UserId == id then
			return p
		end
	end
	return nil
end
local pads = {}
for i = 1, 4 do
	pads["CrewPad_" .. i] = {
		Position = V.new(i * 30, 0, 0),
		CFrame = CF.new(i * 30, 0, 0),
		IsA = function()
			return true
		end,
	}
end
local function folder(children)
	return {
		FindFirstChild = function(_, key)
			return children[key]
		end,
	}
end
local map = folder({ HQ = folder({ CrewPads = folder(pads) }) })
local world = folder({ Map = map })
function world:GetServerTimeNow()
	return stamp
end
local shared = { Config = Config, Logic = { RateLimit = Rate } }
local module = luau.load(fs.readFile("src/server/Services/CrewService.luau"), {
	environment = {
		game = {
			GetService = function(_, name)
				if name == "Players" then
					return Players
				end
				if name == "HttpService" then
					return {
						GenerateGUID = function()
							guid += 1
							return "crew-" .. guid
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
		workspace = world,
		CFrame = CF,
		require = function(value)
			return value
		end,
	},
})()
local function player(id, pad, party)
	local root = {
		Position = pads["CrewPad_" .. pad].Position + V.new(0, 3, 0),
		CFrame = CF.new(pads["CrewPad_" .. pad].Position + V.new(0, 3, 0)),
		IsA = function()
			return true
		end,
	}
	local char = {
		FindFirstChild = function()
			return root
		end,
		FindFirstChildOfClass = function()
			return { Health = 100 }
		end,
	}
	function char:PivotTo(cf)
		root.Position = cf.Position
		root.CFrame = cf
	end
	local p = {
		UserId = id,
		Parent = Players,
		PartyId = party or "",
		Character = char,
		root = root,
		attributes = {},
	}
	function p:SetAttribute(key, value)
		self.attributes[key] = value
	end
	table.insert(roster, p)
	return p
end
local remotes = {
	Crew = {
		Action = {},
		State = {
			FireClient = function(_, p, state)
				table.insert(events, { p, state })
			end,
		},
	},
}
local crews = module.new(remotes)
crews:Bind()
local a, b, c, d, e = player(1, 1), player(2, 1), player(3, 1), player(4, 1), player(5, 1)
assert(not crews:Join(a, 0 / 0), "NaN pad rejected")
a.root.Position = V.new(30, 100, 0)
assert(not crews:Join(a, 1), "Vertical range checked")
a.root.Position = V.new(30, 3, 0)
crews.canJoin = function()
	return false
end
assert(not crews:Join(a, 1) and next(crews.crews) == nil, "Unready profiles cannot reserve pads")
crews.canJoin = nil
assert(crews:Join(a, 1), "Lead joins")
assert(
	events[#events][1] == a and events[#events][2].memberUserIds[1] == a.UserId,
	"Approved CrewState pushed to member"
)
local crew = crews:CrewOf(a)
assert(crew.autoStartsAt == stamp, "Solo starts instantly on next poll")
assert(not crews:Launch(crew) and crew.jobId == nil, "Missing job hook must not trap pending crew")
assert(crews:Join(b, 1), "Second member joins")
local starts = crew.autoStartsAt
assert(starts == stamp + Config.CrewAutoStartSeconds, "Second member starts countdown")
stamp += 2
assert(crews:Join(c, 1) and crews:Join(d, 1), "Four member crew")
assert(crew.autoStartsAt == starts, "Later joins do not reset countdown")
assert(not crews:Join(e, 1), "Crew capacity enforced")
assert(not crews:Action(b, "Start"), "Only leader can launch")
crews:OnStart(function()
	error("Missing geometry")
end)
assert(not crews:Launch(crew) and not crew.jobId and not crew.starting, "Launch failures recover")
crews:OnStart(function(active)
	return "job-" .. active.id
end)
assert(crews:Action(a, "Start"), "Leader launches")
assert(crews.crews[1] == crew and not crews:Join(e, 1), "Active job retains its pad and lot slot")
assert(not crews:Action(b, "Leave"), "Do not abandon active membership through Leave")
assert(not crews:Action(b, "Kick", a.UserId), "Nonleader cannot kick")
local dropped = {}
crews.onMemberRemoved = function(p)
	table.insert(dropped, p.UserId)
end
assert(crews:Action(a, "Kick", b.UserId), "Leader can remove member during job")
assert(
	crews:CrewOf(b) == nil and b.attributes.CrewId == nil and dropped[1] == b.UserId,
	"Remove cleans ownership hook and attributes"
)
crews:Remove(a)
assert(crews:StateFor(crew).leaderUserId == c.UserId, "Lead departure promotes earliest joined")
for pad = 2, 4 do
	local p = player(10 + pad, pad)
	assert(crews:Join(p, pad), "Additional pad")
	assert(crews:Launch(crews:CrewOf(p)), "Additional job")
end
local count = 0
for _ in crews.crews do
	count += 1
end
assert(count == 4 and not crews:Join(e, 1), "Four active crews maximum")
crews:Disband(crew)
assert(not crews.crews[1] and not crews:CrewOf(c) and not crews:CrewOf(d), "Completion frees slot")
assert(crews:Join(e, 1) and crews:CrewOf(e).id ~= crew.id, "Reused pad gets unique crew identity")
local joined = crews:CrewOf(e)
e.root.Position = V.new(300, 0, 0)
crews:Step(Config.CrewPollSeconds)
assert(not crews:CrewOf(e) and not joined.jobId, "Walking away checked before autostart")
roster = {}
local leader, party = player(101, 1, "party"), player(102, 4, "party")
local grouped = module.new(remotes)
assert(grouped:Join(leader, 1), "Party leader joins")
assert(grouped:CrewOf(party) == grouped:CrewOf(leader), "Party automatically shares crew")
grouped:Step(Config.CrewPollSeconds)
assert(grouped:CrewOf(party) ~= nil, "Remote party member moved to pad, not immediately removed")
local activeParty = grouped:CrewOf(leader)
grouped:OnStart(function()
	return "party-job"
end)
assert(grouped:Launch(activeParty), "Party begins job")
local late = player(103, 4, "party")
assert(not grouped:JoinParty(late, activeParty), "Active party requires job service approval")
grouped.canJoinActive = function()
	return true
end
local joinedLate
grouped.onMemberAdded = function(p)
	joinedLate = p
end
assert(grouped:JoinParty(late, activeParty), "Late profile joins its active party")
assert(
	grouped:CrewOf(late) == activeParty and joinedLate == late,
	"Late join pushes job state hook"
)
assert(
	(late.root.Position - leader.root.Position).Magnitude < 10,
	"Late party arrives beside leader"
)
assert(grouped:Action(leader, "Kick", late.UserId), "Leader can remove late party member")
assert(grouped:PartyCrew(late) == nil, "Kicked party member cannot auto-rejoin same crew")
roster = {}
local walker = player(200, 2)
local walking = module.new(remotes)
walking.canAutoJoin = function()
	return true
end
walking:OnStart(function()
	return "walk-job"
end)
walking:Step(Config.CrewPollSeconds)
assert(walking:CrewOf(walker).jobId == "walk-job", "Step onto pad creates and starts solo crew")
walking:Remove(walker)
walking:Step(Config.CrewPollSeconds)
assert(walking:CrewOf(walker) == nil, "Removal does not immediately rejoin from the same pad")
walker.root.Position = V.new(999, 0, 0)
walking:Step(Config.CrewPollSeconds)
walker.root.Position = pads.CrewPad_2.Position
walking:Step(Config.CrewPollSeconds)
assert(walking:CrewOf(walker), "Exiting and re-entering enables pad again")
local successes = 0
for _ = 1, 100 do
	if grouped:Action(leader, "BadAction") then
		successes += 1
	end
end
local _, reason = grouped:Action(leader, "Start")
assert(successes == 0 and reason == "RateLimited", "All remote actions rate limited")
print(
	"PASS CrewService: profile/pad/capacity gates, party grouping, timers, authority, launch failure recovery, stable four-job slots and cleanup"
)
