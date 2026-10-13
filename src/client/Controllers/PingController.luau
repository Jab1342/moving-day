--!strict
-- Ping wheel: hold G (D-pad up on gamepad, Ping button on touch) to open 8 pings, pick one
-- by pointing, release to send. Crew pings show above the sender's head for a few seconds.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Order and IDs follow Contracts/Enums.Ping.
local PINGS = {
	{ id = 1, label = "Lift!", color = Color3.fromRGB(70, 160, 255) },
	{ id = 2, label = "Drop!", color = Color3.fromRGB(255, 120, 60) },
	{ id = 3, label = "Stop!", color = Color3.fromRGB(235, 60, 60) },
	{ id = 4, label = "Go!", color = Color3.fromRGB(90, 200, 90) },
	{ id = 5, label = "Pivot left", color = Color3.fromRGB(170, 120, 230) },
	{ id = 6, label = "Pivot right", color = Color3.fromRGB(170, 120, 230) },
	{ id = 7, label = "Over here", color = Color3.fromRGB(255, 200, 40) },
	{ id = 8, label = "Nice!", color = Color3.fromRGB(80, 210, 200) },
}
local SHOW_SECONDS = 2.5
local WHEEL_RADIUS = 120

local PingController = {}

local gui: ScreenGui
local wheel: Frame
local buttons: { [number]: TextButton } = {}
local selected: number? = nil
local sendRemote: RemoteEvent? = nil

local function pingById(id: number)
	for _, p in PINGS do
		if p.id == id then
			return p
		end
	end
	return nil
end

local function highlight(id: number?)
	selected = id
	for pid, b in buttons do
		local stroke = b:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = if pid == id then 4 else 0
		end
	end
end

local function send(id: number)
	if not sendRemote then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	sendRemote:FireServer(id, root and root.Position or nil)
end

local function openWheel()
	wheel.Visible = true
	highlight(nil)
end

local function closeWheel(commit: boolean)
	wheel.Visible = false
	if commit and selected then
		send(selected)
	end
	highlight(nil)
end

-- Pick the slice the mouse (or right stick) points at from the wheel's centre.
local function updateSelection(dir: Vector2)
	if dir.Magnitude < 30 then
		highlight(nil)
		return
	end
	local angle = math.atan2(dir.Y, dir.X) -- screen space, 0 = right, clockwise positive
	local slice = math.floor(((angle + math.pi / 2) % (2 * math.pi)) / (2 * math.pi / #PINGS) + 0.5)
		% #PINGS
	highlight(PINGS[slice + 1].id)
end

local function buildWheel()
	gui = Instance.new("ScreenGui")
	gui.Name = "PingWheel"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	wheel = Instance.new("Frame")
	wheel.Name = "Wheel"
	wheel.AnchorPoint = Vector2.new(0.5, 0.5)
	wheel.Position = UDim2.fromScale(0.5, 0.5)
	wheel.Size = UDim2.fromOffset(WHEEL_RADIUS * 2 + 120, WHEEL_RADIUS * 2 + 120)
	wheel.BackgroundTransparency = 1
	wheel.Visible = false
	wheel.Parent = gui

	for i, p in PINGS do
		local angle = (i - 1) * (2 * math.pi / #PINGS) - math.pi / 2
		local b = Instance.new("TextButton")
		b.Name = "Ping" .. p.id
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position =
			UDim2.new(0.5, math.cos(angle) * WHEEL_RADIUS, 0.5, math.sin(angle) * WHEEL_RADIUS)
		b.Size = UDim2.fromOffset(104, 48)
		b.BackgroundColor3 = p.color
		b.Text = p.label
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 18
		b.AutoButtonColor = true
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = b
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 0
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = b
		-- touch and mouse: tapping a slice sends it directly
		b.Activated:Connect(function()
			highlight(p.id)
			closeWheel(true)
		end)
		b.Parent = wheel
		buttons[p.id] = b
	end
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function showOverHead(userId: number, id: number)
	local p = pingById(id)
	local who = Players:GetPlayerByUserId(userId)
	local head = who and who.Character and who.Character:FindFirstChild("Head")
	if not p or not head then
		return
	end
	local old = head:FindFirstChild("MD_Ping")
	if old then
		old:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "MD_Ping"
	bb.Size = UDim2.fromOffset(140, 44)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 200
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = p.color
	label.Text = p.label
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	label.Parent = bb
	bb.Parent = head
	task.delay(SHOW_SECONDS, function()
		if bb.Parent then
			bb:Destroy()
		end
	end)
end

local function onPingAction(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		if wheel.Visible then
			closeWheel(false) -- touch: second tap closes
		else
			openWheel()
		end
	elseif
		state == Enum.UserInputState.End
		and UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch
	then
		closeWheel(true)
	end
	return Enum.ContextActionResult.Sink
end

function PingController.Start()
	buildWheel()
	local remotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
	local pingFolder = remotes:WaitForChild("Ping")
	sendRemote = pingFolder:WaitForChild("Send") :: RemoteEvent
	local broadcast = pingFolder:WaitForChild("Broadcast") :: RemoteEvent
	broadcast.OnClientEvent:Connect(function(userId: number, id: number)
		showOverHead(userId, id)
	end)

	ContextActionService:BindAction(
		"MD_Ping",
		onPingAction,
		true,
		Enum.KeyCode.G,
		Enum.KeyCode.DPadUp
	)
	ContextActionService:SetTitle("MD_Ping", "Ping")

	UserInputService.InputChanged:Connect(function(input)
		if not wheel.Visible then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local centre = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
			updateSelection(Vector2.new(input.Position.X, input.Position.Y) - centre)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			updateSelection(Vector2.new(input.Position.X, -input.Position.Y) * 100)
		end
	end)
end

return PingController
