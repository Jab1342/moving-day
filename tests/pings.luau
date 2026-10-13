local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local Config = require("../src/shared/Config")
local Rules = require("../src/shared/Logic/PingRules")
local Rate = require("../src/shared/Logic/RateLimit")
for id = 1, 8 do
	assert(Rules.valid(id, "crew", nil, 120), "Every contracted ping accepted")
end
for _, id in { 0, 9, -1, 1.5, 0 / 0, math.huge, "1", {} } do
	assert(not Rules.valid(id, "crew", nil, 120), "Invalid ping rejected")
end
assert(not Rules.valid(1, "", nil, 120), "No crew means no broadcast")
assert(not Rules.valid(1, "crew", 0 / 0, 120), "NaN position rejected")
assert(not Rules.valid(1, "crew", math.huge, 120), "Infinite position rejected")
assert(not Rules.valid(1, "crew", 121, 120), "Remote position rejected")
local clock, roster, messages = 0, {}, {}
local Players = { PlayerRemoving = { Connect = function() end } }
function Players:GetPlayers()
	return roster
end
local function player(id, crew)
	local p = {
		UserId = id,
		Parent = Players,
		crew = crew,
		Character = {
			FindFirstChildOfClass = function()
				return { Health = 100 }
			end,
			FindFirstChild = function()
				return {
					Position = rb.Vector3.zero,
					IsA = function()
						return true
					end,
				}
			end,
		},
	}
	function p:GetAttribute()
		return self.crew
	end
	table.insert(roster, p)
	return p
end
local a, b, stranger = player(1, "A"), player(2, "A"), player(3, "B")
local shared = { Config = Config, Logic = { RateLimit = Rate, PingRules = Rules } }
local Service = luau.load(fs.readFile("src/server/Services/AntiExploitService.luau"), {
	environment = {
		game = {
			GetService = function(_, name)
				if name == "Players" then
					return Players
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
		os = {
			clock = function()
				return clock
			end,
		},
		typeof = function(value)
			return if type(value) == "userdata" then "Vector3" else type(value)
		end,
	},
})()
local service = Service.new({
	Ping = {
		Broadcast = {
			FireClient = function(_, to, sender, id)
				table.insert(messages, { to = to, sender = sender, id = id })
			end,
		},
	},
})
assert(service:Ping(a, 1, nil), "Crew ping relays")
assert(#messages == 2 and messages[1].to == a and messages[2].to == b, "Only own crew receives")
assert(messages[1].sender == a.UserId, "Sender identity comes from server")
assert(service:Ping(a, 2, nil) and not service:Ping(a, 3, nil), "Two-token burst capped")
clock = 0.5
assert(service:Ping(a, 3, nil), "Token refills at two per second")
clock = 1
assert(not service:Ping(a, 1, "fake position"), "Malformed Vector3 rejected")
clock = 1.5
assert(not service:Ping(a, 1, rb.Vector3.new(500, 0, 0)), "Far position rejected by service")
clock = 2
assert(service:Ping(a, 1, rb.Vector3.new(5, 0, 0)), "Nearby Vector3 accepted")
stranger.crew = nil
assert(not service:Ping(stranger, 1, nil), "Unassigned player cannot relay")
print(
	"PASS pings: enum and position validation, server sender identity, crew isolation and rate limits"
)
