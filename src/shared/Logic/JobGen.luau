--!strict
local Config = if script then require(script.Parent.Parent.Config) else require("../Config")
local RoomDefs = if script then require(script.Parent.Parent.RoomDefs) else require("../RoomDefs")
local ItemDefs = if script then require(script.Parent.Parent.ItemDefs) else require("../ItemDefs")
local JobGen = {}
local DoorRules = if script then require(script.Parent.DoorRules) else require("./DoorRules")
local directions = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }

local function cellKey(x, z, floor)
	return `{x}:{z}:{floor}`
end

function JobGen.generate(seed: number, tier: string)
	assert(seed % 1 == 0 and math.abs(seed) <= 2147483647, "Seed must be a signed 32-bit integer")
	local counts = Config.RoomCount[tier]
	assert(counts ~= nil, "Unknown job tier")
	-- Park-Miller arithmetic is exact below 2^53, independent of Roblox Random APIs.
	local state = seed % 2147483646 + 1
	local function pick(count)
		assert(count > 0, "Empty generation pool")
		state = state * 16807 % 2147483647
		return 1 + state % count
	end
	local ordinary, stairs = {}, {}
	for name, def in RoomDefs do
		table.insert(if def.floors == 2 then stairs else ordinary, name)
	end
	table.sort(ordinary)
	table.sort(stairs)
	local count = counts[1] + pick(counts[2] - counts[1] + 1) - 1
	local rooms, occupied = {}, {}
	local function place(template, x, z, floor)
		local def = RoomDefs[template]
		for f = floor, floor + def.floors - 1 do
			assert(not occupied[cellKey(x, z, f)], "Overlapping room")
			occupied[cellKey(x, z, f)] = true
		end
		local room =
			{ template = template, gridX = x, gridZ = z, floor = floor, quarterTurns = pick(4) - 1 }
		-- A narrow footprint can expose only the stair room to the street.
		-- Orient its ramp side away from the street before attaching other rooms.
		if not DoorRules.canExit(room, 0, -1, floor) then
			room.quarterTurns = (room.quarterTurns + 1) % 4
		end
		table.insert(rooms, room)
	end
	if tier == "Starter" then
		place(ordinary[pick(#ordinary)], 0, 0, 0)
	else
		place(stairs[pick(#stairs)], 0, 0, 0)
	end
	-- Build a connected ground footprint first; upstairs rooms must sit on it.
	local groundRooms = math.ceil((count - 1) / 2)
	while #rooms < count do
		local desiredFloor = if tier == "Starter" or #rooms <= groundRooms then 0 else 1
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, room in rooms do
			minX, maxX = math.min(minX, room.gridX), math.max(maxX, room.gridX)
			minZ, maxZ = math.min(minZ, room.gridZ), math.max(maxZ, room.gridZ)
		end
		local frontier, seen = {}, {}
		for _, room in rooms do
			for floor = room.floor, room.floor + RoomDefs[room.template].floors - 1 do
				for _, d in directions do
					local x, z = room.gridX + d[1], room.gridZ + d[2]
					local key = cellKey(x, z, floor)
					if
						floor == desiredFloor
						and DoorRules.canExit(room, d[1], d[2], floor)
						and not occupied[key]
						and not seen[key]
						and (floor == 0 or occupied[cellKey(x, z, 0)])
						and math.max(maxX, x) - math.min(minX, x) < Config.RoomGridWidth
						and math.max(maxZ, z) - math.min(minZ, z) < Config.RoomGridWidth
					then
						seen[key] = true
						table.insert(frontier, { x, z, floor })
					end
				end
			end
		end
		local c = frontier[pick(#frontier)]
		place(ordinary[pick(#ordinary)], c[1], c[2], c[3])
	end
	-- Some authored rooms (bathrooms/hallways) cannot hold large furniture.
	-- Replace the lowest-capacity ordinary room until the whole manifest fits.
	-- Footprints/doors stay identical, so this preserves the connected layout.
	local richest = ordinary[1]
	local function score(def)
		return #def.small * (if tier == "Starter" then Config.ItemCount.Starter else 1) + #def.large
	end
	for _, name in ordinary do
		local a, b = RoomDefs[name], RoomDefs[richest]
		if score(a) > score(b) then
			richest = name
		end
	end
	for _ = 1, #rooms + 1 do
		local capacity, largeCount, poorest, lowest = 0, 0, nil, math.huge
		for index, room in rooms do
			local def = RoomDefs[room.template]
			local size = #def.small + #def.large
			capacity += size
			largeCount += #def.large
			if def.floors == 1 and score(def) < lowest then
				poorest, lowest = index, score(def)
			end
		end
		if
			capacity >= Config.ItemCount[tier]
			and largeCount > 0
			and (tier ~= "Starter" or capacity - largeCount >= Config.ItemCount.Starter - 1)
		then
			break
		end
		assert(
			poorest and rooms[poorest].template ~= richest,
			"Room catalogue cannot fit tier manifest"
		)
		rooms[poorest].template = richest
	end
	local small, large = {}, {}
	for roomIndex, room in rooms do
		for _, size in { "small", "large" } do
			for _, socketName in RoomDefs[room.template][size] do
				table.insert(
					if size == "small" then small else large,
					{ roomIndex = roomIndex, socketName = socketName }
				)
			end
		end
	end
	local items = {}
	local function assign(itemId)
		local sockets = if ItemDefs[itemId].carry == "Two" then large else small
		assert(#sockets > 0, "Room catalogue has insufficient matching sockets")
		local socket = table.remove(sockets, pick(#sockets))
		socket.itemId = itemId
		table.insert(items, socket)
	end
	if tier == "Starter" then
		assign("couch")
	end
	if tier == "Big" then
		assign(if pick(2) == 1 then "piano" else "aquarium")
	end
	while #items < Config.ItemCount[tier] do
		local pool = {}
		for _, id in Config.JobItemPool[tier] do
			if
				(ItemDefs[id].carry == "Two" and #large > 0)
				or (ItemDefs[id].carry == "One" and #small > 0)
			then
				table.insert(pool, id)
			end
		end
		assign(pool[pick(#pool)])
	end
	return { seed = seed, tier = tier, rooms = rooms, items = items }
end

return JobGen
