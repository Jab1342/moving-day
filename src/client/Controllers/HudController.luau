--!strict
-- HUD (job timer, items delivered, cash), the hover tag on the nearest item, and the
-- itemised payout screen. Shows server state only; never decides anything.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Gate = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Gate"))

local INK = Color3.fromRGB(255, 255, 255)
local PANEL = Color3.fromRGB(24, 28, 36)
local GOOD = Color3.fromRGB(90, 200, 110)
local BAD = Color3.fromRGB(235, 80, 70)
local GOLD = Color3.fromRGB(255, 200, 60)
local TAG_RANGE = 10
local INSURANCE_MIN_LOSS = 100

local HudController = {}

local itemDefs: { [string]: any } = {}
local productIds: any = nil
local jobState: any = nil
local hud: ScreenGui
local timerLabel: TextLabel
local itemsLabel: TextLabel
local cashLabel: TextLabel
local payoutGui: ScreenGui
local tag: BillboardGui

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function label(parent: Instance, text: string, size: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = color or INK
	l.Size = UDim2.new(1, 0, 0, size + 6)
	l.Parent = parent
	return l
end

local function money(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return (if n < 0 then "-$" else "$") .. out
end

local function playerName(userId: number?): string
	if not userId then
		return "nobody"
	end
	local p = Players:GetPlayerByUserId(userId)
	return if p then p.DisplayName else "a former crewmate"
end

local function buildHud()
	hud = Instance.new("ScreenGui")
	hud.Name = "Hud"
	hud.ResetOnSpawn = false
	hud.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Job panel: top centre, hidden when no job.
	local job = Instance.new("Frame")
	job.Name = "Job"
	job.AnchorPoint = Vector2.new(0.5, 0)
	job.Position = UDim2.new(0.5, 0, 0, 8)
	job.Size = UDim2.fromOffset(220, 64)
	job.BackgroundColor3 = PANEL
	job.BackgroundTransparency = 0.25
	job.Visible = false
	corner(job, 12)
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Parent = job
	timerLabel = label(job, "0:00", 26)
	itemsLabel = label(job, "Items 0 / 0", 16)
	job.Parent = hud

	-- Cash: top right, below the Roblox top bar.
	cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "Cash"
	cashLabel.AnchorPoint = Vector2.new(1, 0)
	cashLabel.Position = UDim2.new(1, -12, 0, 8)
	cashLabel.Size = UDim2.fromOffset(150, 40)
	cashLabel.BackgroundColor3 = PANEL
	cashLabel.BackgroundTransparency = 0.25
	cashLabel.Font = Enum.Font.GothamBold
	cashLabel.TextSize = 22
	cashLabel.TextColor3 = GOOD
	cashLabel.Text = "$0"
	corner(cashLabel, 12)
	cashLabel.Parent = hud

	local scale = Instance.new("UIScale")
	scale.Parent = hud
	local function rescale()
		local cam = Workspace.CurrentCamera
		local short = cam and math.min(cam.ViewportSize.X, cam.ViewportSize.Y) or 720
		scale.Scale = math.clamp(short / 720, 0.75, 1.25)
	end
	rescale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	Gate.bind(hud) -- nothing on screen before a new player's first grab
	hud.Parent = player:WaitForChild("PlayerGui")
end

local function buildTag()
	tag = Instance.new("BillboardGui")
	tag.Name = "MD_ItemTag"
	tag.Size = UDim2.fromOffset(160, 54)
	tag.StudsOffset = Vector3.new(0, 2.5, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = TAG_RANGE + 6
	tag.Enabled = false
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = PANEL
	frame.BackgroundTransparency = 0.2
	corner(frame, 10)
	frame.Parent = tag
	local name = label(frame, "", 16)
	name.Name = "Name"
	name.Position = UDim2.fromOffset(0, 4)
	local value = label(frame, "", 14, GOLD)
	value.Name = "Value"
	value.Position = UDim2.fromOffset(0, 22)
	local bar = Instance.new("Frame")
	bar.Name = "HpBack"
	bar.Position = UDim2.new(0, 10, 1, -12)
	bar.Size = UDim2.new(1, -20, 0, 6)
	bar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	corner(bar, 3)
	bar.Parent = frame
	local fill = Instance.new("Frame")
	fill.Name = "Hp"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = GOOD
	corner(fill, 3)
	fill.Parent = bar
	tag.Parent = player:WaitForChild("PlayerGui")
end

local function nearestItem(): Model?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char :: Instance }
	local best, bestD = nil, math.huge
	for _, part in Workspace:GetPartBoundsInRadius(root.Position, TAG_RANGE, params) do
		local m = part:FindFirstAncestorWhichIsA("Model")
		if m and m:GetAttribute("ItemUid") and m.PrimaryPart then
			local d = (m.PrimaryPart.Position - root.Position).Magnitude
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end

local function updateTag()
	local m = nearestItem()
	if not m or m:GetAttribute("State") == "Broken" then
		tag.Enabled = false
		return
	end
	local def = itemDefs[m:GetAttribute("ItemId") :: string]
	local hp = (m:GetAttribute("HP") or 100) :: number
	local frame = tag:FindFirstChildOfClass("Frame") :: Frame
	(frame:FindFirstChild("Name") :: TextLabel).Text = if def then def.displayName else "Item"
	local worth = if def then def.value * hp / 100 else 0
	(frame:FindFirstChild("Value") :: TextLabel).Text = money(worth)
		.. (if m:GetAttribute("Carry") == "Two" then "  |  2 people" else "")
	local fill = (frame:FindFirstChild("HpBack") :: Frame):FindFirstChild("Hp") :: Frame
	fill.Size = UDim2.fromScale(math.clamp(hp / 100, 0, 1), 1)
	fill.BackgroundColor3 = if hp > 60 then GOOD elseif hp > 25 then GOLD else BAD
	tag.Adornee = m.PrimaryPart
	tag.Enabled = true
end

local function updateTimer()
	local job = hud:FindFirstChild("Job") :: Frame
	if not jobState or jobState.phase == "Payout" then
		job.Visible = false
		return
	end
	job.Visible = true
	local left = jobState.softEndsAt - Workspace:GetServerTimeNow()
	local over = left < 0
	local secs = math.floor(math.abs(left))
	timerLabel.Text = (if over then "+" else "") .. string.format("%d:%02d", secs // 60, secs % 60)
	timerLabel.TextColor3 = if over then BAD elseif left < 60 then GOLD else INK
	local total, done = 0, 0
	for _, state in jobState.manifest do
		total += 1
		if state == "Delivered" then
			done += 1
		end
	end
	itemsLabel.Text = `Items {done} / {total}`
end

local function closePayout()
	if payoutGui then
		payoutGui:Destroy()
	end
end

local function showPayout(report: any)
	closePayout()
	payoutGui = Instance.new("ScreenGui")
	payoutGui.Name = "PayoutScreen"
	payoutGui.ResetOnSpawn = false
	payoutGui.DisplayOrder = 10

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.86)
	panel.BackgroundColor3 = PANEL
	corner(panel, 16)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 640)
	limit.Parent = panel
	panel.Parent = payoutGui

	local title = label(panel, `Job complete: {report.stars} / 5 stars`, 26, GOLD)
	title.Position = UDim2.fromOffset(0, 14)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromOffset(16, 56)
	scroll.Size = UDim2.new(1, -32, 1, -220)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	local rows = Instance.new("UIListLayout")
	rows.Padding = UDim.new(0, 4)
	rows.Parent = scroll
	scroll.Parent = panel

	local lost = 0
	-- breaks first: the blame list is the funny part
	local lines = table.clone(report.lines)
	table.sort(lines, function(a, b)
		return a.valueLost > b.valueLost
	end)
	for _, line in lines do
		local def = itemDefs[line.itemId]
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 24)
		row.Font = Enum.Font.Gotham
		row.TextSize = 16
		row.TextXAlignment = Enum.TextXAlignment.Left
		local name = if def then def.displayName else line.itemId
		if line.valueLost > 0 then
			lost += line.valueLost
			row.TextColor3 = BAD
			local verb = if line.valueKept > 0 then "damaged" else "broken"
			local who = line.blameUserId
			row.Text = if who and who ~= 0
				then `{name}: {verb} by {playerName(who)} (-{money(line.valueLost)})`
				else `{name}: {verb} in transit (-{money(line.valueLost)})`
		else
			row.TextColor3 = INK
			row.Text = `{name}: {money(line.valueKept)} delivered safe`
		end
		row.Parent = scroll
	end

	local myShare = report.shares and report.shares[tostring(player.UserId)] or report.perPlayer
	local totals = label(
		panel,
		`Job fee {money(report.jobFee)}   Time bonus {money(report.timeBonus)}   Lost {money(lost)}`,
		15
	)
	totals.Position = UDim2.new(0, 0, 1, -156)
	local share = label(panel, `You earned {money(myShare)}  +{report.xpEach} XP`, 24, GOOD)
	share.Position = UDim2.new(0, 0, 1, -128)
	-- "one more job": tease what's next right on the payout screen
	if report.nextJob then
		local tierName = ({
			Starter = "Starter apartment",
			Family = "Family home",
			Big = "Big house",
		})[report.nextJob.tier] or tostring(report.nextJob.tier)
		local nextLine = label(panel, `Next up: {tierName} on lot {report.nextJob.lotId}`, 16, GOLD)
		nextLine.Position = UDim2.new(0, 0, 1, -98)
	end

	local function button(text: string, color: Color3, x: number): TextButton
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(x, 0, 1, -18)
		b.Size = UDim2.fromOffset(220, 52)
		b.BackgroundColor3 = color
		b.Text = text
		b.TextColor3 = INK
		b.Font = Enum.Font.GothamBold
		b.TextSize = 18
		corner(b, 12)
		b.Parent = panel
		return b
	end

	local insuranceId = productIds and productIds.Products and productIds.Products.InsuranceClaim
	if lost >= INSURANCE_MIN_LOSS and insuranceId then
		local insure = button(`Claim insurance ({money(lost)})`, Color3.fromRGB(60, 110, 220), 0.27)
		insure.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(player, insuranceId)
		end)
		button("Next job", GOOD, 0.73).Activated:Connect(closePayout)
	else
		button("Next job", GOOD, 0.5).Activated:Connect(closePayout)
	end

	payoutGui.Parent = player:WaitForChild("PlayerGui")
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local cash = assets
		and assets:FindFirstChild("Sounds")
		and assets.Sounds:FindFirstChild("SFX_Cash")
	if cash and cash:IsA("Sound") then
		local s = cash:Clone()
		s.Parent = payoutGui
		s:Play()
	end
end

local function requireShared(name: string): any
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local module = shared:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			return result
		end
	end
	return nil
end

function HudController.Start()
	itemDefs = requireShared("ItemDefs") or {}
	productIds = requireShared("ProductIds")
	buildHud()
	buildTag()

	local remotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
	local job = remotes:WaitForChild("Job");
	(job:WaitForChild("State") :: RemoteEvent).OnClientEvent:Connect(function(state)
		jobState = state
		-- a new job means the last payout screen is stale
		if state and state.phase ~= "Payout" then
			closePayout()
		end
	end);
	(job:WaitForChild("Payout") :: RemoteEvent).OnClientEvent:Connect(showPayout)
	local data = remotes:WaitForChild("Data");
	(data:WaitForChild("Profile") :: RemoteEvent).OnClientEvent:Connect(function(profile)
		cashLabel.Text = money(profile.cash)
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.15 then
			return
		end
		acc = 0
		updateTimer()
		updateTag()
	end)
end

return HudController
