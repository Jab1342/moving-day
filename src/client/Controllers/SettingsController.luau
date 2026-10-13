--!strict
-- Settings: a gear button beside the cash box opens a small panel. Assist mode is saved on
-- the server (Settings.Set "assist"); hiding the first-session hints is local to this device.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Gate = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Gate"))
local Scale = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Scale"))

local PANEL = Color3.fromRGB(24, 28, 36)
local INK = Color3.fromRGB(255, 255, 255)
local MUTED = Color3.fromRGB(170, 175, 185)
local ON = Color3.fromRGB(90, 200, 110)
local OFF = Color3.fromRGB(90, 90, 100)

local SettingsController = {}

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function toggleRow(
	parent: Instance,
	title: string,
	detail: string,
	order: number
): (TextButton, TextLabel)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 64)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = parent
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(4, 4)
	name.Size = UDim2.new(1, -96, 0, 24)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 18
	name.TextColor3 = INK
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = title
	name.Parent = row
	local info = Instance.new("TextLabel")
	info.BackgroundTransparency = 1
	info.Position = UDim2.fromOffset(4, 28)
	info.Size = UDim2.new(1, -96, 0, 32)
	info.Font = Enum.Font.Gotham
	info.TextSize = 14
	info.TextColor3 = MUTED
	info.TextWrapped = true
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.TextYAlignment = Enum.TextYAlignment.Top
	info.Text = detail
	info.Parent = row
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -4, 0.5, 0)
	button.Size = UDim2.fromOffset(80, 44)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.TextColor3 = INK
	corner(button, 10)
	button.Parent = row
	return button, info
end

local function paint(button: TextButton, on: boolean)
	button.Text = if on then "On" else "Off"
	button.BackgroundColor3 = if on then ON else OFF
end

function SettingsController.Start()
	local remotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
	local setRemote = remotes:WaitForChild("Settings"):WaitForChild("Set") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "Settings"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6

	local gear = Instance.new("TextButton")
	gear.Name = "Open"
	gear.AnchorPoint = Vector2.new(1, 0)
	gear.Position = UDim2.new(1, -170, 0, 8) -- just left of the cash box
	gear.Size = UDim2.fromOffset(96, 40)
	gear.BackgroundColor3 = PANEL
	gear.BackgroundTransparency = 0.25
	gear.Font = Enum.Font.GothamBold
	gear.TextSize = 16
	gear.TextColor3 = INK
	gear.Text = "Settings"
	corner(gear, 12)
	gear.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(380, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = PANEL
	panel.Visible = false
	corner(panel, 16)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 30)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = INK
	title.Text = "Settings"
	title.LayoutOrder = 0
	title.Parent = panel

	local assistButton =
		toggleRow(panel, "Assist mode", "Items are 50% sturdier. Jobs pay 20% less.", 1)
	local hintsButton =
		toggleRow(panel, "Tutorial hints", "Show the yellow tips for your first job.", 2)

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(1, 0, 0, 44)
	close.BackgroundColor3 = OFF
	close.Font = Enum.Font.GothamBold
	close.TextSize = 18
	close.TextColor3 = INK
	close.Text = "Close"
	close.LayoutOrder = 3
	corner(close, 10)
	close.Parent = panel

	local function refresh()
		paint(assistButton, player:GetAttribute("Assist") == true)
		paint(hintsButton, player:GetAttribute("MD_HideHints") ~= true)
	end
	refresh()
	player:GetAttributeChangedSignal("Assist"):Connect(refresh)

	gear.Activated:Connect(function()
		panel.Visible = not panel.Visible
		refresh()
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	assistButton.Activated:Connect(function()
		setRemote:FireServer("assist", player:GetAttribute("Assist") ~= true)
	end)
	hintsButton.Activated:Connect(function()
		-- local-only preference; OnboardingController reads this attribute
		player:SetAttribute("MD_HideHints", player:GetAttribute("MD_HideHints") ~= true)
		refresh()
	end)

	Scale.attach(gui)
	Gate.bind(gui)
	gui.Parent = player:WaitForChild("PlayerGui")
end

return SettingsController
