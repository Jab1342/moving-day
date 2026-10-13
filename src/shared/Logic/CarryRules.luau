--!strict
local CarryRules = {}

function CarryRules.canGrab(item, userId, grip, crewId, distance, alreadyHolding, config)
	if grip ~= 1 and grip ~= 2 then
		return false, "InvalidGrip"
	end
	if type(crewId) ~= "string" or crewId == "" or crewId ~= item.crewId then
		return false, "WrongCrew"
	end
	if item.state == "Broken" or item.state == "Delivered" then
		return false, "Unavailable"
	end
	if
		type(distance) ~= "number"
		or distance ~= distance
		or distance > config.GrabRange
		or distance < 0
	then
		return false, "OutOfRange"
	end
	if alreadyHolding or item.a == userId or item.b == userId then
		return false, "AlreadyCarrying"
	end
	if grip == 1 and item.a ~= 0 then
		return false, "GripTaken"
	end
	if grip == 2 and (item.carry ~= "Two" or item.a == 0 or item.b ~= 0) then
		return false, "GripUnavailable"
	end
	return true, nil
end

function CarryRules.drop(a, b, userId)
	if a == userId then
		return b, 0
	end
	if b == userId then
		return a, 0
	end
	return a, b
end

return CarryRules
