--!strict
-- Builds a house from a JobGen HouseLayout on a lot: clones ServerStorage.RoomTemplates onto
-- a 24-stud grid around the lot's Pad.HouseOrigin, opens doorways between neighbouring
-- rooms (and one front door facing the street), and returns every item socket's world
-- CFrame so JobService can spawn furniture resting on the floor.
--
-- Grid convention: gridX -> house-local +X, gridZ -> house-local +Z, floor f -> y = 11 * f.
-- House-local -Z is the street (HouseOrigin's LookVector). Rooms turn by quarterTurns * 90 deg.

local ServerStorage = game:GetService("ServerStorage")

local CELL = 24
local LEVEL = 11

local HouseBuilder = {}

export type Sockets = { [string]: CFrame } -- "roomIndex:socketName" -> world CFrame (floor top)

local function cellKey(x: number, z: number, floor: number): string
	return `{x}:{z}:{floor}`
end

local function templates(): Folder
	local folder = ServerStorage:FindFirstChild("RoomTemplates")
	assert(folder and folder:IsA("Folder"), "ServerStorage.RoomTemplates missing")
	return folder
end

-- House-local CFrame for the centre of a grid cell, after centring the layout on the lot.
local function cellFrame(x: number, z: number, floor: number, centre: Vector3): CFrame
	return CFrame.new((x - centre.X) * CELL, floor * LEVEL, (z - centre.Z) * CELL)
end

function HouseBuilder.Build(layout: any, lot: Model, parent: Instance): (Model, Sockets)
	local pad = lot:FindFirstChild("Pad") :: BasePart?
	local origin = pad and pad:FindFirstChild("HouseOrigin") :: Attachment?
	assert(origin, "Lot has no Pad.HouseOrigin")
	local base = origin.WorldCFrame

	-- occupancy and layout centre
	local occupied: { [string]: boolean } = {}
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, room in layout.rooms do
		local def = templates():FindFirstChild(room.template) :: Model?
		local floors = def and def:GetAttribute("Floors") or 1
		for f = room.floor, room.floor + floors - 1 do
			occupied[cellKey(room.gridX, room.gridZ, f)] = true
		end
		minX, maxX = math.min(minX, room.gridX), math.max(maxX, room.gridX)
		minZ, maxZ = math.min(minZ, room.gridZ), math.max(maxZ, room.gridZ)
	end
	local centre = Vector3.new((minX + maxX) / 2, 0, (minZ + maxZ) / 2)

	local house = Instance.new("Model")
	house.Name = "House_" .. tostring(layout.seed)
	local sockets: Sockets = {}
	local frontCandidates = {}

	for index, room in layout.rooms do
		local template = templates():FindFirstChild(room.template) :: Model?
		assert(template, "Unknown room template " .. tostring(room.template))
		local clone = template:Clone()
		local localFrame = cellFrame(room.gridX, room.gridZ, room.floor, centre)
			* CFrame.Angles(0, math.rad(90 * room.quarterTurns), 0)
		clone:PivotTo(base * localFrame)
		clone.Name = `{index}_{room.template}`
		clone:SetAttribute("RoomIndex", index)

		-- doorways: a plug opens when the cell it faces is part of the house on that level
		for _, plug in clone:GetChildren() do
			if plug:IsA("BasePart") and string.sub(plug.Name, 1, 5) == "Plug_" then
				local upper = string.sub(plug.Name, -3) == "_Up"
				local level = room.floor + (if upper then 1 else 0)
				local offset = base:PointToObjectSpace(plug.Position)
					- cellFrame(room.gridX, room.gridZ, 0, centre).Position
				local dx = if math.abs(offset.X) > CELL / 4 then math.sign(offset.X) else 0
				local dz = if math.abs(offset.Z) > CELL / 4 then math.sign(offset.Z) else 0
				if occupied[cellKey(room.gridX + dx, room.gridZ + dz, level)] then
					plug:Destroy()
				elseif level == 0 and dz == -1 then
					table.insert(frontCandidates, { plug = plug, x = room.gridX, z = room.gridZ })
				end
			end
		end

		-- sockets
		local floorPart = clone:FindFirstChild("Floor")
		if floorPart then
			for _, a in floorPart:GetChildren() do
				if a:IsA("Attachment") and string.sub(a.Name, 1, 5) == "Item_" then
					sockets[`{index}:{a.Name}`] = a.WorldCFrame
				end
			end
		end
		clone.Parent = house
	end

	-- front door: street-facing ground doorway closest to the street, then closest to centre
	table.sort(frontCandidates, function(a, b)
		if a.z ~= b.z then
			return a.z < b.z
		end
		return math.abs(a.x - centre.X) < math.abs(b.x - centre.X)
	end)
	local front = frontCandidates[1]
	if front then
		-- where the crew walks in: bottom centre of the front doorway
		house:SetAttribute(
			"FrontDoor",
			front.plug.Position - Vector3.new(0, front.plug.Size.Y / 2, 0)
		)
		front.plug:Destroy()
	end

	house.Parent = parent
	return house, sockets
end

function HouseBuilder.Clear(house: Model?)
	if house then
		house:Destroy()
	end
end

return HouseBuilder
