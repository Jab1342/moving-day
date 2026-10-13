--!strict
-- Where to go next: a tall local-only beacon in the world, never a screen element.
-- Loading/Driving: over the destination lot's TruckSpot (park here). Unloading: over the
-- destination house (carry everything in). Hidden at payout and outside a job.
-- Uses Assets.Props.PRP_Beacon when it exists, otherwise a simple neon column.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Gate = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Gate"))

local COLOR = Color3.fromRGB(255, 200, 60)

-- Config.Nav<Key> overrides any of these.
local DEFAULTS = {
	BeaconHeight = 40, -- fallback column height
	LabelHeight = 17, -- just above PRP_Beacon's chevron tip (12)
	Spin = 0.8, -- rad/s; a slow turn reads as a marker at distance
	BobSpeed = 2, -- rad/s
	BobAmplitude = 0.6, -- studs
	ParkYOffset = 2.7, -- TruckSpot attachment height above the pad
}
local tuning = table.clone(DEFAULTS)

local NavController = {}

local beacon: Model? = nil
local target: Vector3? = nil

local function loadTuning()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local configModule = shared and shared:FindFirstChild("Config")
	if configModule and configModule:IsA("ModuleScript") then
		local ok, config = pcall(require, configModule)
		if ok and type(config) == "table" then
			for key in DEFAULTS do
				if type(config["Nav" .. key]) == "number" then
					tuning[key] = config["Nav" .. key]
				end
			end
		end
	end
end

local function buildFallback(): Model
	local model = Instance.new("Model")
	model.Name = "PRP_Beacon"
	local column = Instance.new("Part")
	column.Name = "Base"
	column.Shape = Enum.PartType.Cylinder
	column.Size = Vector3.new(tuning.BeaconHeight, 3, 3)
	column.CFrame = CFrame.new(0, tuning.BeaconHeight / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	column.Material = Enum.Material.Neon
	column.Color = COLOR
	column.Transparency = 0.55
	-- the model pivot is the column's foot, upright (WorldPivot is ignored with a PrimaryPart)
	column.PivotOffset = column.CFrame:Inverse()
	column.Parent = model
	model.PrimaryPart = column
	return model
end

-- "Park here" / "Unload here" floating LabelHeight studs above the beacon's foot. It is text
-- in the player's view, so it waits for the first grab like other UI (Gate).
local function addLabel(model: Model)
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not primary then
		return
	end
	model:PivotTo(CFrame.new())
	local tag = Instance.new("BillboardGui")
	tag.Name = "Label"
	tag.Size = UDim2.fromOffset(170, 56)
	tag.StudsOffsetWorldSpace = Vector3.new(0, tuning.LabelHeight - primary.Position.Y, 0)
	tag.Enabled = Gate.open()
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = COLOR
	text.TextStrokeTransparency = 0.3
	text.Parent = tag
	tag.Parent = primary
end

local function ensureBeacon(): Model
	if beacon and beacon.Parent then
		return beacon
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("Props")
	local template = props and props:FindFirstChild("PRP_Beacon")
	local model = if template and template:IsA("Model") then template:Clone() else buildFallback()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	if not model:FindFirstChild("Text", true) then
		addLabel(model)
	end
	model.Parent = Workspace.CurrentCamera -- local only
	beacon = model
	return model
end

local function hide()
	target = nil
	if beacon then
		beacon:Destroy()
		beacon = nil
	end
end

local function show(position: Vector3, label: string)
	local model = ensureBeacon()
	target = position
	model:PivotTo(CFrame.new(position))
	local text = model:FindFirstChild("Text", true)
	if text and text:IsA("TextLabel") then
		text.Text = label
	end
end

-- The beacon over the destination stands on the house's roof, so a two-floor house doesn't
-- swallow the chevron; the zone floor when no house is found in it.
local function houseTopY(zone: BasePart): number
	local floorY = zone.Position.Y - zone.Size.Y / 2
	local runtime = Workspace:FindFirstChild("MovingDayRuntime")
	local houses = runtime and runtime:FindFirstChild("Houses")
	if not houses then
		return floorY
	end
	for _, house in houses:GetChildren() do
		if house:IsA("Model") then
			local cf, size = house:GetBoundingBox()
			local p = zone.CFrame:PointToObjectSpace(cf.Position)
			if math.abs(p.X) <= zone.Size.X / 2 and math.abs(p.Z) <= zone.Size.Z / 2 then
				return cf.Y + size.Y / 2
			end
		end
	end
	return floorY
end

local function onState(state: any)
	if type(state) ~= "table" or player:GetAttribute("CrewId") ~= state.crewId then
		return
	end
	local lots = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Lots")
	local lot = lots and lots:FindFirstChild(`DestinationLot_{state.lotId}`)
	if not lot or state.phase == "Payout" then
		hide()
		return
	end
	if state.phase == "Unloading" then
		local zone = lot:FindFirstChild("DeliveryZone")
		if zone and zone:IsA("BasePart") then
			show(Vector3.new(zone.Position.X, houseTopY(zone), zone.Position.Z), "Unload here")
			return
		end
	end
	local pad = lot:FindFirstChild("Pad")
	local spot = pad and pad:FindFirstChild("TruckSpot")
	if spot and spot:IsA("Attachment") then
		show(spot.WorldPosition - Vector3.new(0, tuning.ParkYOffset, 0), "Park here")
	end
end

function NavController.Start()
	loadTuning()
	Gate.whenOpen(function()
		local label = beacon and beacon:FindFirstChild("Label", true)
		if label and label:IsA("BillboardGui") then
			label.Enabled = true
		end
	end)
	local remotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
	local job = remotes:WaitForChild("Job")
	local stateRemote = job:WaitForChild("State") :: RemoteEvent
	local payoutRemote = job:WaitForChild("Payout") :: RemoteEvent
	stateRemote.OnClientEvent:Connect(onState)
	payoutRemote.OnClientEvent:Connect(hide)
	player:GetAttributeChangedSignal("CrewId"):Connect(function()
		if player:GetAttribute("CrewId") == nil then
			hide()
		end
	end)
	-- gentle bob and spin so it reads as a marker, not scenery
	RunService.RenderStepped:Connect(function()
		if beacon and target then
			local t = os.clock()
			beacon:PivotTo(
				CFrame.new(
					target + Vector3.new(0, math.sin(t * tuning.BobSpeed) * tuning.BobAmplitude, 0)
				) * CFrame.Angles(0, t * tuning.Spin, 0)
			)
		end
	end)
end

return NavController
