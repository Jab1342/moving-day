--!strict
local Config = if script then require(script.Parent.Parent.Config) else require("../Config")
local Rules = {}
function Rules.options(upgrades)
	upgrades = upgrades or {}
	local box = (upgrades.BoxTruck or 0) >= 1
	local soft = (upgrades.SoftSuspension or 0) >= 1
	return {
		template = if box then "TRK_Box" else "TRK_Pickup",
		ramp = (upgrades.LoadingRamp or 0) >= 1,
		maxSpeed = if soft then Config.SoftSuspensionMaxSpeed else Config.Truck.MaxSpeed,
		maxSteer = if box then Config.BoxTruckMaxSteerAngle else Config.Truck.MaxSteerAngle,
		highSpeedSteer = if box
			then Config.BoxTruckHighSpeedSteerAngle
			else Config.Truck.HighSpeedSteerAngle,
		stiffnessScale = if soft then Config.SoftSuspensionStiffnessScale else 1,
		dampingScale = if soft then Config.SoftSuspensionDampingScale else 1,
		cargoScale = if soft then Config.SoftSuspensionCargoScale else 1,
	}
end

-- Match the foot's world height while rotating around the truck-local X hinge.
-- upY/backY account for the parked truck's pitch. Unreachable ground leaves it stowed.
function Rules.rampPitch(footY, footZ, upY, backY, height)
	for _, n in { footY, footZ, upY, backY, height } do
		if type(n) ~= "number" or n ~= n or math.abs(n) == math.huge then
			return nil
		end
	end
	if height <= 0 or footZ <= 0 then
		return nil
	end
	local function errorAt(angle)
		local y = footY * math.cos(angle) - footZ * math.sin(angle)
		local z = footY * math.sin(angle) + footZ * math.cos(angle)
		return upY * y + backY * z + height
	end
	local low, high = math.rad(Config.RampMinPitchDegrees), math.rad(Config.RampMaxPitchDegrees)
	if errorAt(low) < 0 or errorAt(high) > 0 then
		return nil
	end
	for _ = 1, 20 do
		local middle = (low + high) / 2
		if errorAt(middle) > 0 then
			low = middle
		else
			high = middle
		end
	end
	return (low + high) / 2
end
return Rules
