--!strict
local Config = if script then require(script.Parent.Parent.Config) else require("../Config")
local UpgradeDefs = if script
	then require(script.Parent.Parent.UpgradeDefs)
	else require("../UpgradeDefs")
local Economy = {}

function Economy.levelForXp(xp: number): number
	assert(xp == xp and math.abs(xp) < math.huge, "XP must be finite")
	return 1 + math.floor(math.sqrt(math.max(0, xp) / Config.LevelXpBase))
end

function Economy.upgradePrice(upgradeId: string, tier: number): number
	local def = UpgradeDefs[upgradeId]
	assert(def ~= nil, "Unknown upgrade")
	assert(tier == tier and tier % 1 == 0 and tier >= 1, "Invalid upgrade tier")
	local price = def.prices[tier]
	assert(price ~= nil, "Unknown upgrade tier")
	return price
end

return Economy
