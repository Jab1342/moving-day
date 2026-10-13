--!strict
local CargoRules = {}

function CargoRules.accelerationG(deltaSpeed, dt, gravity)
	if dt <= 0 or gravity <= 0 or deltaSpeed ~= deltaSpeed then
		return 0
	end
	return math.max(0, deltaSpeed) / (dt * gravity)
end

function CargoRules.shouldBreak(accelerationG, tiltDegrees, strapped, config)
	local threshold = if strapped then config.StrappedBreakG else config.BedBreakG
	return accelerationG > threshold or tiltDegrees > config.BedBreakTiltDegrees
end

-- Exponential smoothing is stable across frame rates; signed vectors cancel chatter.
function CargoRules.smooth(previous, current, dt, seconds)
	if dt <= 0 then
		return previous
	end
	local alpha = if seconds <= 0 then 1 else 1 - math.exp(-dt / seconds)
	return previous + (current - previous) * alpha
end

return CargoRules
