local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Config = require("../src/shared/Config")
local pending, calls = {}, {}
local Players = {}
local player = { Parent = Players }
local engine = {}
for _, method in { "LogOnboardingFunnelStepEvent", "LogEconomyEvent", "LogCustomEvent" } do
	engine[method] = function(_, ...)
		table.insert(calls, { method = method, args = table.pack(...) })
	end
end
local shared = { Config = Config }
local Service = luau.load(fs.readFile("src/server/Services/AnalyticsService.luau"), {
	environment = {
		game = {
			GetService = function(_, name)
				if name == "Players" then
					return Players
				end
				if name == "AnalyticsService" then
					return engine
				end
				if name == "RunService" then
					return {
						IsStudio = function()
							return true
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
		task = {
			defer = function(callback)
				table.insert(pending, callback)
			end,
		},
		Enum = { AnalyticsEconomyFlowType = { Source = "Source", Sink = "Sink" } },
	},
})()
local service = Service.new(engine, false)
local function flush()
	local batch = pending
	pending = {}
	for _, callback in batch do
		callback()
	end
end
assert(service:Funnel(player, 1), "First step queues")
assert(not service:Funnel(player, 1), "Step emitted once per session")
assert(not service:Funnel(player, 9), "Unknown step rejected")
assert(#calls == 0, "Engine analytics never runs in gameplay call")
flush()
assert(#calls == 1 and calls[1].args[2] == 1 and calls[1].args[3] == "Spawned", "Funnel arguments")
assert(service:Economy(player, 150, 350, "JobPayout"), "Committed source")
assert(service:Economy(player, -250, 100, "Straps:1"), "Committed sink")
assert(not service:Economy(player, 0 / 0, 100, "Invalid"), "Invalid amounts refused")
assert(not service:Economy(player, 10, -1, "Invalid"), "Invalid balances refused")
assert(service:Custom(player, "ItemBroken", 1, { CustomField01 = "vase" }), "Whitelisted custom")
assert(not service:Custom(player, "Unknown", 1), "Unknown events refused")
flush()
assert(
	calls[2].args[2] == "Source" and calls[2].args[4] == 150 and calls[2].args[5] == 350,
	"Source amount/balance order"
)
assert(calls[3].args[2] == "Sink" and calls[3].args[4] == 250, "Sink amount remains positive")
engine.LogCustomEvent = function()
	error("Analytics unavailable")
end
assert(service:Custom(player, "PingUsed", 1), "Queue during API outage")
flush()
assert(service.failures == 1 and service.queued == 0, "API failure isolated and queue released")
for _ = 1, Config.AnalyticsQueueLimit do
	service:Custom(player, "PingUsed", 1)
end
assert(
	not service:Custom(player, "PingUsed", 1) and service.dropped == 1,
	"Bounded queue under spam"
)
flush()
local studio = Service.new(engine, true)
assert(
	studio:Funnel(player, 2) and studio.accepted == 1 and #pending == 0,
	"Studio records counters without unsupported API call"
)
player.Parent = nil
assert(not service:Funnel(player, 3), "Departed player does not queue")
print(
	"PASS analytics: funnel deduplication, API arguments, committed economy direction, Studio suppression, failure isolation and queue bounds"
)
