--!strict
-- Authored room metadata confirmed by ClaudeA board 1791849793.
-- All rooms occupy one 24x24 cell; stairs reserve the same cell on both floors.
local counts = {
	Bathroom_A = { 2, 0 },
	Bathroom_B = { 2, 0 },
	Bedroom_A = { 2, 2 },
	Bedroom_B = { 2, 1 },
	Hallway_A = { 2, 0 },
	Hallway_B = { 1, 0 },
	Kitchen_A = { 3, 1 },
	Kitchen_B = { 2, 1 },
	LivingRoom_A = { 2, 3 },
	LivingRoom_B = { 2, 2 },
	Stairs_A = { 2, 0 },
	Stairs_B = { 2, 0 },
}
local rooms = {}
for name, sizes in counts do
	local def =
		{ floors = if string.sub(name, 1, 6) == "Stairs" then 2 else 1, small = {}, large = {} }
	for index = 1, sizes[1] do
		table.insert(def.small, "Item_Small_" .. index)
	end
	for index = 1, sizes[2] do
		table.insert(def.large, "Item_Large_" .. index)
	end
	rooms[name] = def
end
return rooms
