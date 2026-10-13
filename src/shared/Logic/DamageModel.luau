--!strict
local Config = if script then require(script.Parent.Parent.Config) else require("../Config")
local DamageModel = {}

function DamageModel.impactDamage(deltaV, def, mods)
	if type(deltaV) ~= "number" or deltaV ~= deltaV then
		return 0
	end
	local fragility = def.fragility
	if
		type(fragility) ~= "number"
		or fragility ~= fragility
		or fragility < 0
		or fragility == math.huge
	then
		return 0
	end
	local protection = mods.protection
	if type(protection) ~= "number" or protection ~= protection then
		protection = 0
	end
	protection = math.clamp(protection, 0, Config.MaxProtection)
	if mods.assist then
		protection = math.min(Config.MaxProtection, 1 - (1 - protection) * Config.AssistDamageScale)
	end
	return math.max(0, math.clamp(deltaV, 0, Config.MaxDeltaVAccepted) - Config.DamageThreshold)
		* Config.DamagePerStudPerSec
		* fragility
		* (1 - protection)
end

return DamageModel
