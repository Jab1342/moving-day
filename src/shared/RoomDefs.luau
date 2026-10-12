--!strict
-- Schema from ClaudeA board 1791847199; pure metadata, no place geometry.
-- STUB(ClaudeA): confirm per-template socket counts against authored templates.
-- JobGen is not wired into runtime until this catalogue is confirmed.
local rooms = {}
for _, roomType in { "Kitchen", "Bedroom", "Bathroom", "LivingRoom", "Hallway", "Stairs" } do
	for _, variant in { "A", "B" } do
		local isStairs = roomType == "Stairs"
		rooms[roomType .. "_" .. variant] = {
			floors = if isStairs then 2 else 1,
			small = if isStairs then {} else { "Item_Small_1", "Item_Small_2", "Item_Small_3" },
			large = if isStairs then {} else { "Item_Large_1", "Item_Large_2" },
		}
	end
end
return rooms
