--!strict
local Enums = if script
	then require(script.Parent.Parent.Contracts.Enums)
	else require("../Contracts/Enums")
local validIds = {}
for _, id in Enums.Ping do
	validIds[id] = true
end
local PingRules = {}
function PingRules.valid(id, crewId, distance, maxDistance)
	return type(id) == "number"
		and validIds[id] == true
		and type(crewId) == "string"
		and crewId ~= ""
		and (
			distance == nil
			or (type(distance) == "number" and distance >= 0 and distance <= maxDistance)
		)
end
return PingRules
