--!strict
local Config = if script then require(script.Parent.Parent.Config) else require("../Config")
local Economy = if script then require(script.Parent.Economy) else require("./Economy")
local UpgradeDefs = if script
	then require(script.Parent.Parent.UpgradeDefs)
	else require("../UpgradeDefs")
local ProfileSchema = {}

local template = {
	version = Config.ProfileVersion,
	cash = 0,
	xp = 0,
	level = 1,
	upgrades = {},
	cosmetics = {},
	catalog = {},
	stats = { jobs = 0, delivered = 0, broken = 0, moneyLost = 0 },
	streak = { lastDay = 0, count = 0 },
	settings = { assist = false },
	firstJobDone = false,
	purchases = {},
}

function ProfileSchema.copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[key] = ProfileSchema.copy(child)
	end
	return result
end

function ProfileSchema.new()
	return ProfileSchema.copy(template)
end

local function fill(data, defaults)
	for key, value in defaults do
		if data[key] == nil then
			data[key] = ProfileSchema.copy(value)
		elseif type(value) == "table" and type(data[key]) == "table" then
			fill(data[key], value)
		end
	end
end

local function integer(value)
	return type(value) == "number"
		and value >= 0
		and value <= Config.MaxProfileValue
		and value % 1 == 0
end

local function boolMap(map)
	if type(map) ~= "table" then
		return false
	end
	for key, value in map do
		if type(key) ~= "string" or type(value) ~= "boolean" then
			return false
		end
	end
	return true
end

-- Add missing v1 defaults, but never reset an invalid or future profile to zero.
function ProfileSchema.prepare(source)
	if type(source) ~= "table" then
		return nil, "InvalidProfile"
	end
	if source.version ~= nil and source.version ~= Config.ProfileVersion then
		return nil, "UnsupportedVersion"
	end
	local data = ProfileSchema.copy(source)
	fill(data, template)
	if not integer(data.cash) or not integer(data.xp) then
		return nil, "InvalidBalance"
	end
	if type(data.upgrades) ~= "table" then
		return nil, "InvalidUpgrades"
	end
	for id, tier in data.upgrades do
		local def = UpgradeDefs[id]
		if not def or not integer(tier) or tier > #def.prices then
			return nil, "InvalidUpgrades"
		end
	end
	for _, name in { "cosmetics", "catalog", "purchases" } do
		if not boolMap(data[name]) then
			return nil, "InvalidFlags"
		end
	end
	if type(data.stats) ~= "table" or type(data.streak) ~= "table" then
		return nil, "InvalidStats"
	end
	for _, key in { "jobs", "delivered", "broken", "moneyLost" } do
		if not integer(data.stats[key]) then
			return nil, "InvalidStats"
		end
	end
	if not integer(data.streak.lastDay) or not integer(data.streak.count) then
		return nil, "InvalidStreak"
	end
	if
		type(data.settings) ~= "table"
		or type(data.settings.assist) ~= "boolean"
		or type(data.firstJobDone) ~= "boolean"
	then
		return nil, "InvalidSettings"
	end
	data.level = Economy.levelForXp(data.xp)
	return data
end

function ProfileSchema.public(data)
	return {
		cash = data.cash,
		xp = data.xp,
		level = data.level,
		upgrades = ProfileSchema.copy(data.upgrades),
		cosmetics = ProfileSchema.copy(data.cosmetics),
		settings = { assist = data.settings.assist },
		firstJobDone = data.firstJobDone,
	}
end

return ProfileSchema
