--!strict
-- Authored ramp-side plugs are obstructed on both floors (ClaudeB QA 1791858283).
-- Cardinal vectors are house-local, after the room's positive-Y quarter rotation.
local DoorRules = {}
function DoorRules.canExit(room, dx, dz, floor)
	if floor < room.floor or floor > room.floor + 1 then
		return true
	end
	local blockedX = if room.template == "Stairs_A"
		then -1
		elseif room.template == "Stairs_B" then 1
		else 0
	if blockedX == 0 then
		return true
	end
	local blockedZ = 0
	for _ = 1, room.quarterTurns do
		blockedX, blockedZ = blockedZ, -blockedX
	end
	return dx ~= blockedX or dz ~= blockedZ
end
function DoorRules.connected(a, b, floor)
	local dx, dz = b.gridX - a.gridX, b.gridZ - a.gridZ
	return math.abs(dx) + math.abs(dz) == 1
		and DoorRules.canExit(a, dx, dz, floor)
		and DoorRules.canExit(b, -dx, -dz, floor)
end
return DoorRules
