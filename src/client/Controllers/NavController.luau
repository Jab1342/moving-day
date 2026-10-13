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

local COLOR = Color3.fromRGB(255, 200, 60)
local HEIGHT = 40
local HOVER = 12 -- chevron/label height above the target

local NavController = {}

local beacon: Model? = nil
local target: Vector3? = nil

local function buildFallback(): Model
	local model = Instance.new("Model")
	model.Name = "PRP_Beacon"
	local column = Instance.new("Part")
	column.Name = "Base"
	column.Shape = Enum.PartType.Cylinder
	column.Size = Vector3.new(HEIGHT, 3, 3)
	column.CFrame = CFrame.new(0, HEIGHT / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	column.Material = Enum.Material.Neon
	column.Color = COLOR
	column.Transparency = 0.55
	column.Parent = model
	model.PrimaryPart = column
	local tag = Instance.new("BillboardGui")
	tag.Name = "Label"
	tag.Size = UDim2.fromOffset(160, 64)
	tag.StudsOffsetWorldSpace = Vector3.new(0, HOVER - HEIGHT / 2, 0)
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
	tag.Parent = column
	model.WorldPivot = CFrame.new() -- pivot at the column's foot, upright
	return model
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
			show(
				Vector3.new(zone.Position.X, zone.Position.Y - zone.Size.Y / 2, zone.Position.Z),
				"Unload here"
			)
			return
		end
	end
	local pad = lot:FindFirstChild("Pad")
	local spot = pad and pad:FindFirstChild("TruckSpot")
	if spot and spot:IsA("Attachment") then
		show(spot.WorldPosition - Vector3.new(0, 2.7, 0), "Park here")
	end
end

function NavController.Start()
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
	-- gentle bob so it reads as a marker, not scenery
	RunService.RenderStepped:Connect(function()
		if beacon and target then
			beacon:PivotTo(CFrame.new(target + Vector3.new(0, math.sin(os.clock() * 2) * 0.6, 0)))
		end
	end)
end

return NavController
