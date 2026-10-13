--!strict
-- HQ interactions: stepping on a crew pad joins that crew (CrewBoard panel shows members,
-- auto-start countdown, Start for the leader, Leave), and the shop counter opens upgrades.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(24, 28, 36)
local INK = Color3.fromRGB(255, 255, 255)
local GOOD = Color3.fromRGB(90, 200, 110)
local MUTED = Color3.fromRGB(170, 175, 185)
local PAD_RADIUS = 6

local CrewShopController = {}

local crewAction: RemoteFunction? = nil
local shopBuy: RemoteFunction? = nil
local crewState: any = nil
local profile: any = nil
local upgradeDefs: { [string]: any } = {}
local board: Frame
local membersLabel: TextLabel
local countdownLabel: TextLabel
local startButton: TextButton
local shopGui: ScreenGui? = nil
local joinPending = false

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function text(parent: Instance, s: string, size: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -16, 0, size + 8)
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color or INK
	l.TextWrapped = true
	l.Text = s
	l.Parent = parent
	return l
end

local function button(parent: Instance, s: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -16, 0, 44)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextSize = 18
	b.TextColor3 = INK
	b.Text = s
	corner(b, 10)
	b.Parent = parent
	return b
end

local function buildBoard()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CrewBoard"
	gui.ResetOnSpawn = false
	board = Instance.new("Frame")
	board.AnchorPoint = Vector2.new(0, 0.5)
	board.Position = UDim2.new(0, 12, 0.45, 0)
	board.Size = UDim2.fromOffset(240, 0)
	board.AutomaticSize = Enum.AutomaticSize.Y
	board.BackgroundColor3 = PANEL
	board.BackgroundTransparency = 0.15
	board.Visible = false
	corner(board, 14)
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = board
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = board
	text(board, "Your crew", 20).LayoutOrder = 1
	membersLabel = text(board, "", 16, MUTED)
	membersLabel.LayoutOrder = 2
	membersLabel.AutomaticSize = Enum.AutomaticSize.Y
	countdownLabel = text(board, "", 16, GOOD)
	countdownLabel.LayoutOrder = 3
	startButton = button(board, "Start job", GOOD)
	startButton.LayoutOrder = 4
	local leave = button(board, "Leave crew", Color3.fromRGB(90, 90, 100))
	leave.LayoutOrder = 5
	startButton.Activated:Connect(function()
		if crewAction then
			crewAction:InvokeServer("Start")
		end
	end)
	leave.Activated:Connect(function()
		if crewAction then
			crewAction:InvokeServer("Leave")
		end
	end)
	board.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function refreshBoard()
	local inCrew = crewState and crewState.crewId ~= nil and not crewState.jobId
	board.Visible = inCrew == true
	if not inCrew then
		return
	end
	local names = {}
	for _, userId in crewState.memberUserIds do
		local p = Players:GetPlayerByUserId(userId)
		local name = if p then p.DisplayName else tostring(userId)
		table.insert(names, if userId == crewState.leaderUserId then name .. " (leader)" else name)
	end
	membersLabel.Text = table.concat(names, "\n")
	startButton.Visible = crewState.leaderUserId == player.UserId
end

local function padUnderPlayer(): number?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hq = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("HQ")
	local pads = hq and hq:FindFirstChild("CrewPads")
	if not root or not pads then
		return nil
	end
	for _, pad in pads:GetChildren() do
		if pad:IsA("BasePart") then
			local flat =
				Vector3.new(pad.Position.X - root.Position.X, 0, pad.Position.Z - root.Position.Z)
			if flat.Magnitude < PAD_RADIUS and math.abs(pad.Position.Y - root.Position.Y) < 6 then
				return pad:GetAttribute("PadId") :: number?
			end
		end
	end
	return nil
end

local function tick()
	if crewState and crewState.autoStartsAt then
		local left = math.max(0, math.ceil(crewState.autoStartsAt - Workspace:GetServerTimeNow()))
		countdownLabel.Text = `Starting in {left}s`
	elseif countdownLabel then
		countdownLabel.Text = "Waiting for crew"
	end
	local padId = padUnderPlayer()
	local inCrew = crewState and crewState.crewId ~= nil
	if padId and not inCrew and not joinPending and crewAction then
		joinPending = true
		task.spawn(function()
			pcall(function()
				(crewAction :: RemoteFunction):InvokeServer("Join", padId)
			end)
			task.wait(1)
			joinPending = false
		end)
	end
end

local function closeShop()
	if shopGui then
		shopGui:Destroy()
		shopGui = nil
	end
end

local function openShop()
	closeShop()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.8)
	panel.BackgroundColor3 = PANEL
	corner(panel, 16)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, 560)
	limit.Parent = panel
	panel.Parent = gui

	local title = text(panel, "Upgrades", 24)
	title.Position = UDim2.fromOffset(8, 10)
	local cash = text(panel, if profile then `Cash: ${profile.cash}` else "", 16, GOOD)
	cash.Position = UDim2.fromOffset(8, 40)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromOffset(12, 72)
	scroll.Size = UDim2.new(1, -24, 1, -140)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.Parent = scroll
	scroll.Parent = panel

	local ids = {}
	for id in upgradeDefs do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local def = upgradeDefs[id]
		local owned = profile and profile.upgrades and profile.upgrades[id] or 0
		local nextTier = owned + 1
		local price = def.prices[nextTier]
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 78)
		row.BackgroundColor3 = Color3.fromRGB(36, 42, 54)
		corner(row, 10)
		row.Parent = scroll
		local name = text(row, `{def.displayName}  (tier {owned}/{#def.prices})`, 17)
		name.Position = UDim2.fromOffset(10, 6)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local trade = text(row, "Trade-off: " .. def.tradeoff, 14, MUTED)
		trade.Position = UDim2.fromOffset(10, 32)
		trade.TextXAlignment = Enum.TextXAlignment.Left
		trade.Size = UDim2.new(1, -150, 0, 36)
		local buy = Instance.new("TextButton")
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -10, 0.5, 0)
		buy.Size = UDim2.fromOffset(120, 44)
		buy.Font = Enum.Font.GothamBold
		buy.TextSize = 16
		buy.TextColor3 = INK
		corner(buy, 10)
		if price then
			buy.Text = `Buy ${price}`
			buy.BackgroundColor3 = GOOD
			buy.Activated:Connect(function()
				if not shopBuy then
					return
				end
				local ok, reason = shopBuy:InvokeServer(id, nextTier)
				buy.Text = if ok then "Bought!" else (reason or "Can't buy")
				task.delay(1, function()
					if gui.Parent then
						openShop()
					end
				end)
			end)
		else
			buy.Text = "Maxed"
			buy.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
			buy.AutoButtonColor = false
		end
		buy.Parent = row
	end

	local close = button(panel, "Close", Color3.fromRGB(90, 90, 100))
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.new(0.5, 0, 1, -12)
	close.Size = UDim2.fromOffset(200, 44)
	close.Activated:Connect(closeShop)
	gui.Parent = player:WaitForChild("PlayerGui")
	shopGui = gui
end

local function addShopPrompt()
	local hq = Workspace:WaitForChild("Map"):WaitForChild("HQ")
	local counter = hq:WaitForChild("Garage"):WaitForChild("ShopCounter") :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MD_ShopPrompt"
	prompt.ActionText = "Upgrades"
	prompt.ObjectText = "Shop"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	ProximityPromptService.PromptTriggered:Connect(function(p)
		if p == prompt then
			openShop()
		end
	end)
end

function CrewShopController.Start()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local ok, defs = pcall(require, shared:WaitForChild("UpgradeDefs"))
	upgradeDefs = if ok then defs else {}
	local remotes = shared:WaitForChild("Remotes")
	crewAction = remotes:WaitForChild("Crew"):WaitForChild("Action") :: RemoteFunction
	shopBuy = remotes:WaitForChild("Shop"):WaitForChild("Buy") :: RemoteFunction
	(remotes:WaitForChild("Crew"):WaitForChild("State") :: RemoteEvent).OnClientEvent:Connect(
		function(state)
			crewState = state
			refreshBoard()
		end
	);
	(remotes:WaitForChild("Data"):WaitForChild("Profile") :: RemoteEvent).OnClientEvent:Connect(
		function(p)
			profile = p
		end
	)

	buildBoard()
	task.spawn(addShopPrompt)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			tick()
		end
	end)
end

return CrewShopController
