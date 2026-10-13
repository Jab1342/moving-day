--!strict
-- First-session hints: one short banner at a time, in the world's order of play
-- (grab -> load -> strap -> drive -> unload). Wording follows the player's input device.
-- Stops for good once the profile says the first job is done.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Scale = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Scale"))

local OnboardingController = {}

type Step = { id: string, text: { mouse: string, touch: string, pad: string }, done: () -> boolean }

local finished = false
local profileDone = false
local jobPhase: string? = nil
local stepIndex = 1
local banner: TextLabel
local highlight: Highlight
local worldTip: BillboardGui -- the first hint lives in the world, not on screen
local cameraAimed = false
local CAMERA_BACK = 12 -- studs behind the player when the first-session camera swings round
local CAMERA_UP = 6

local REGRAB_TEXT = {
	mouse = "Grab furniture and drag it to the truck",
	touch = "Grab furniture and drag it to the truck",
	pad = "Walk up to furniture and press X to grab it",
}

local function device(): "mouse" | "touch" | "pad"
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "touch"
	elseif string.find(last.Name, "Gamepad") then
		return "pad"
	end
	return "mouse"
end

local function myItems(): { Model }
	local list = {}
	local crew = player:GetAttribute("CrewId")
	local runtime = Workspace:FindFirstChild("MovingDayRuntime")
	local folder = runtime and runtime:FindFirstChild("Items")
	if not folder then
		return list
	end
	for _, m in folder:GetChildren() do
		if
			m:IsA("Model")
			and m:GetAttribute("ItemUid")
			and (crew == nil or m:GetAttribute("CrewId") == crew)
		then
			table.insert(list, m)
		end
	end
	return list
end

local function myTruck(): Model?
	local crew = player:GetAttribute("CrewId")
	local runtime = Workspace:FindFirstChild("MovingDayRuntime")
	local folder = runtime and runtime:FindFirstChild("Trucks")
	if not folder then
		return nil
	end
	for _, m in folder:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("CrewId") == crew then
			return m
		end
	end
	return nil
end

local function anyItem(predicate: (Model) -> boolean): boolean
	for _, m in myItems() do
		if predicate(m) then
			return true
		end
	end
	return false
end

local function seated(): boolean
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.SeatPart ~= nil and humanoid.SeatPart:IsA("VehicleSeat")
end

local STEPS: { Step } = {
	{
		id = "grab",
		text = {
			mouse = "Click and hold furniture to drag it",
			touch = "Touch and hold furniture to drag it",
			pad = "Walk up to furniture and press X to grab it",
		},
		done = function()
			return anyItem(function(m)
				return m:GetAttribute("CarrierA") == player.UserId
					or m:GetAttribute("CarrierB") == player.UserId
			end)
		end,
	},
	{
		id = "load",
		text = {
			mouse = "Drag it over the truck bed and let go",
			touch = "Drag it over the truck bed and let go",
			pad = "Carry it to the truck bed and press X to drop it",
		},
		done = function()
			return anyItem(function(m)
				return m:GetAttribute("State") == "InTruck"
			end)
		end,
	},
	{
		id = "strap",
		text = {
			mouse = "Press F near the truck to strap cargo down",
			touch = "Tap Strap near the truck to strap cargo down",
			pad = "Press B near the truck to strap cargo down",
		},
		done = function()
			return anyItem(function(m)
				return m:GetAttribute("Strapped") == true
			end)
		end,
	},
	{
		id = "drive",
		text = {
			mouse = "Load the rest, then hop in the driver's seat",
			touch = "Load the rest, then hop in the driver's seat",
			pad = "Load the rest, then hop in the driver's seat",
		},
		done = seated,
	},
	{
		id = "deliver",
		text = {
			mouse = "Drive to the new house. Brake gently!",
			touch = "Drive to the new house. Brake gently!",
			pad = "Drive to the new house. Brake gently!",
		},
		done = function()
			return jobPhase == "Unloading" or jobPhase == "Payout"
		end,
	},
	{
		id = "unload",
		text = {
			mouse = "Unload everything into the new house",
			touch = "Unload everything into the new house",
			pad = "Unload everything into the new house",
		},
		done = function()
			return jobPhase == "Payout"
		end,
	},
}

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Onboarding"
	gui.ResetOnSpawn = false
	banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 82)
	banner.Size = UDim2.fromOffset(460, 44)
	banner.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	banner.TextColor3 = Color3.fromRGB(30, 30, 30)
	banner.Font = Enum.Font.GothamBold
	banner.TextSize = 20
	banner.TextWrapped = true
	banner.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = banner
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(460, 64)
	limit.Parent = banner
	banner.Parent = gui
	Scale.attach(gui)
	gui.Parent = player:WaitForChild("PlayerGui")

	highlight = Instance.new("Highlight")
	highlight.Name = "MD_OnboardingHighlight"
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 200, 60)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = gui

	worldTip = Instance.new("BillboardGui")
	worldTip.Name = "MD_GrabTip"
	worldTip.ResetOnSpawn = false -- parented straight to PlayerGui; must survive respawns
	worldTip.Size = UDim2.fromOffset(260, 48)
	worldTip.StudsOffset = Vector3.new(0, 3.2, 0)
	worldTip.AlwaysOnTop = true
	worldTip.MaxDistance = 80
	worldTip.Enabled = false
	local tipLabel = Instance.new("TextLabel")
	tipLabel.Name = "Text"
	tipLabel.Size = UDim2.fromScale(1, 1)
	tipLabel.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	tipLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
	tipLabel.Font = Enum.Font.GothamBold
	tipLabel.TextScaled = true
	local tipCorner = Instance.new("UICorner")
	tipCorner.CornerRadius = UDim.new(0, 12)
	tipCorner.Parent = tipLabel
	local tipPad = Instance.new("UIPadding")
	tipPad.PaddingLeft = UDim.new(0, 8)
	tipPad.PaddingRight = UDim.new(0, 8)
	tipPad.Parent = tipLabel
	tipLabel.Parent = worldTip
	worldTip.Parent = player:WaitForChild("PlayerGui")
end

local function nearestFreeItem(): Model?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, m in myItems() do
		if m:GetAttribute("State") == "Idle" and m.PrimaryPart then
			local d = (m.PrimaryPart.Position - root.Position).Magnitude
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end

-- First session only, once: new players spawn at the front door facing the street, with all
-- the furniture behind them. Swing the camera round to look at the nearest item.
local function aimCameraAt(item: Model)
	cameraAimed = true
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = Workspace.CurrentCamera
	if not root or not camera or not item.PrimaryPart then
		return
	end
	local itemPos = item.PrimaryPart.Position
	local flat = Vector3.new(itemPos.X - root.Position.X, 0, itemPos.Z - root.Position.Z)
	if flat.Magnitude < 1 then
		return
	end
	local eye = root.Position - flat.Unit * CAMERA_BACK + Vector3.new(0, CAMERA_UP, 0)
	camera.CFrame = CFrame.lookAt(eye, itemPos)
end

local function update()
	if finished or profileDone or player:GetAttribute("MD_HideHints") == true then
		banner.Visible = false
		highlight.Enabled = false
		worldTip.Enabled = false
		return
	end
	while stepIndex <= #STEPS and STEPS[stepIndex].done() do
		stepIndex += 1
	end
	if stepIndex > #STEPS then
		finished = true
		banner.Visible = false
		highlight.Enabled = false
		worldTip.Enabled = false
		return
	end
	local step = STEPS[stepIndex]
	-- "Load" while holding nothing (a grab that was let go early): point back at furniture
	-- instead of telling an empty-handed player to drag something to the truck.
	local regrab = step.id == "load"
		and not anyItem(function(m)
			return m:GetAttribute("CarrierA") == player.UserId
				or m:GetAttribute("CarrierB") == player.UserId
		end)
	local text = if regrab then REGRAB_TEXT[device()] else step.text[device()]
	-- before the first grab nothing goes on screen: the tip floats above the furniture
	local inWorld = step.id == "grab" or regrab
	banner.Text = text
	banner.Visible = not inWorld
	-- point at what the step is about
	local target: Instance? = nil
	if inWorld then
		target = nearestFreeItem()
	elseif step.id == "load" or step.id == "strap" or step.id == "drive" then
		target = myTruck()
	end
	if step.id == "grab" and not cameraAimed and target and target:IsA("Model") then
		aimCameraAt(target)
	end
	highlight.Adornee = target
	highlight.Enabled = target ~= nil
	local tipRoot = if inWorld and target and target:IsA("Model") then target.PrimaryPart else nil
	worldTip.Adornee = tipRoot
	worldTip.Enabled = tipRoot ~= nil
	if tipRoot then
		(worldTip:FindFirstChild("Text") :: TextLabel).Text = text
	end
end

function OnboardingController.Start()
	build()
	local remotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes");
	(remotes:WaitForChild("Data"):WaitForChild("Profile") :: RemoteEvent).OnClientEvent:Connect(
		function(profile)
			profileDone = profile.firstJobDone == true
		end
	);
	(remotes:WaitForChild("Job"):WaitForChild("State") :: RemoteEvent).OnClientEvent:Connect(
		function(state)
			jobPhase = state and state.phase or nil
		end
	);
	(remotes:WaitForChild("Job"):WaitForChild("Payout") :: RemoteEvent).OnClientEvent:Connect(
		function()
			jobPhase = "Payout"
		end
	)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.3 then
			acc = 0
			update()
		end
	end)
end

return OnboardingController
