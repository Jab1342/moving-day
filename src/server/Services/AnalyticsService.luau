--!nonstrict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local EngineAnalytics = game:GetService("AnalyticsService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local AnalyticsService = {}
AnalyticsService.__index = AnalyticsService
local steps = {
	"Spawned",
	"First grab",
	"First item loaded",
	"First drive",
	"First item delivered",
	"First payout",
	"First upgrade bought",
	"Second job started",
}
local customEvents = {
	JobCompleted = true,
	ItemBroken = true,
	PingUsed = true,
	InsuranceOffered = true,
	InsuranceBought = true,
}
function AnalyticsService.new(engine, studio)
	return setmetatable({
		engine = engine or EngineAnalytics,
		studio = if studio == nil then RunService:IsStudio() else studio,
		seen = {},
		queued = 0,
		failures = 0,
		dropped = 0,
		accepted = 0,
	}, AnalyticsService)
end
function AnalyticsService:Emit(method, player, ...)
	if player.Parent ~= Players then
		return false
	end
	if self.queued >= Config.AnalyticsQueueLimit then
		self.dropped += 1
		return false
	end
	self.accepted += 1
	if self.studio then
		return true
	end -- Roblox accepts analytics only in published servers.
	local args = table.pack(...)
	self.queued += 1
	task.defer(function()
		local ok = pcall(function()
			self.engine[method](self.engine, player, table.unpack(args, 1, args.n))
		end)
		self.queued -= 1
		if not ok then
			self.failures += 1
		end
	end)
	return true
end
function AnalyticsService:Funnel(player, step)
	if type(step) ~= "number" or not steps[step] then
		return false
	end
	local seen = self.seen[player] or {}
	if seen[step] then
		return false
	end
	if not self:Emit("LogOnboardingFunnelStepEvent", player, step, steps[step]) then
		return false
	end
	seen[step] = true
	self.seen[player] = seen
	return true
end
function AnalyticsService:Economy(player, amount, balance, sku)
	if
		type(amount) ~= "number"
		or amount == 0
		or amount ~= amount
		or math.abs(amount) == math.huge
		or type(balance) ~= "number"
		or balance < 0
		or balance ~= balance
		or balance == math.huge
	then
		return false
	end
	local flow = if amount > 0
		then Enum.AnalyticsEconomyFlowType.Source
		else Enum.AnalyticsEconomyFlowType.Sink
	return self:Emit(
		"LogEconomyEvent",
		player,
		flow,
		"Cash",
		math.abs(amount),
		balance,
		"Gameplay",
		sku
	)
end
function AnalyticsService:Custom(player, event, value, fields)
	if
		not customEvents[event]
		or type(value) ~= "number"
		or value ~= value
		or math.abs(value) == math.huge
	then
		return false
	end
	return self:Emit("LogCustomEvent", player, event, value, fields)
end
function AnalyticsService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:Funnel(player, 1)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.seen[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		self:Funnel(player, 1)
	end
end
return AnalyticsService
