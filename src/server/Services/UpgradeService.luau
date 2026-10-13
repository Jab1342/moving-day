--!nonstrict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.Logic.UpgradeRules)
local RateLimit = require(Shared.Logic.RateLimit)
local UpgradeService = {}
UpgradeService.__index = UpgradeService
function UpgradeService.new(data, remotes)
	return setmetatable({ data = data, remotes = remotes, buckets = {} }, UpgradeService)
end
function UpgradeService:AtShop(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local map = workspace:FindFirstChild("Map")
	local hq = map and map:FindFirstChild("HQ")
	local garage = hq and hq:FindFirstChild("Garage")
	local shop = garage and garage:FindFirstChild("ShopCounter")
	if not root or not humanoid or humanoid.Health <= 0 or not shop or not shop:IsA("BasePart") then
		return false
	end
	return (root.Position - shop.Position).Magnitude <= Config.ShopRange
end
function UpgradeService:Buy(player, id, tier)
	local allowed, bucket = RateLimit.consume(
		self.buckets[player],
		os.clock(),
		Config.RemotePerSecond,
		Config.RemoteBurst
	)
	self.buckets[player] = bucket
	if not allowed then
		return false, "RateLimited"
	end
	if not self:AtShop(player) then
		return false, "NotAtHQ"
	end
	-- Bootstrap supplies live crew/job membership.
	if self.isInJob and self.isInJob(player) then
		return false, "InJob"
	end
	-- Do not charge for upgrades whose physical effects are not implemented yet.
	if id ~= "Straps" and id ~= "MovingBlankets" then
		if not self.isReady or not self.isReady(id) then
			return false, "NotReady"
		end
	end
	return self.data:Update(player, function(profile)
		local ok, reason, price = Rules.purchase(profile, id, tier)
		if not ok then
			return false, reason
		end
		profile.cash -= price
		profile.upgrades[id] = tier
	end)
end
function UpgradeService:PayWrap(player)
	return self.data:Update(player, function(profile)
		local ok, reason, price = Rules.wrap(profile)
		if not ok then
			return false, reason
		end
		profile.cash -= price
	end)
end
function UpgradeService:StrapSlots(crewId)
	-- Crew benefits from the highest currently-present member tier, never summed.
	local tier = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("CrewId") == crewId then
			local data = self.data:Get(player)
			if data then
				tier = math.max(tier, data.upgrades.Straps or 0)
			end
		end
	end
	return Rules.strapSlots(tier)
end
function UpgradeService:Start()
	self.remotes.Shop.Buy.OnServerInvoke = function(player, id, tier)
		return self:Buy(player, id, tier)
	end
	Players.PlayerRemoving:Connect(function(player)
		self.buckets[player] = nil
	end)
end
return UpgradeService
