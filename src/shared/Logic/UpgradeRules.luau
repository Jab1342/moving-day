--!strict
local Config = if script then require(script.Parent.Parent.Config) else require("../Config")
local UpgradeDefs = if script
	then require(script.Parent.Parent.UpgradeDefs)
	else require("../UpgradeDefs")
local UpgradeRules = {}
function UpgradeRules.purchase(profile, id, tier)
	if type(id) ~= "string" or not UpgradeDefs[id] then
		return false, "UnknownUpgrade"
	end
	if type(tier) ~= "number" or tier % 1 ~= 0 or tier < 1 then
		return false, "InvalidTier"
	end
	local price = UpgradeDefs[id].prices[tier]
	if not price then
		return false, "InvalidTier"
	end
	if tier ~= (profile.upgrades[id] or 0) + 1 then
		return false, "TierOrder"
	end
	if profile.cash < price then
		return false, "NotEnoughCash"
	end
	return true, nil, price
end
function UpgradeRules.wrap(profile)
	if (profile.upgrades.MovingBlankets or 0) < 1 then
		return false, "UpgradeRequired"
	end
	if profile.cash < Config.BlanketUsePrice then
		return false, "NotEnoughCash"
	end
	return true, nil, Config.BlanketUsePrice
end
function UpgradeRules.strapSlots(tier)
	return Config.BaseStrapSlots
		+ math.clamp(tier, 0, #UpgradeDefs.Straps.prices) * Config.StrapSlotsPerTier
end
return UpgradeRules
