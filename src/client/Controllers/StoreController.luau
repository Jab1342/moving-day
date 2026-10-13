--!strict
-- Store: passes and cash packs from Monetization.State (PR23 contract). The client only
-- sends a SKU; the server validates and opens the Roblox prompt. A SKU is listed only when
-- the server says it's available, prices come from Roblox product info (regional), and
-- nothing shows before the first grab. Until the server side exists this stays hidden.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Gate = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Gate"))
local Scale = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Scale"))

local PANEL = Color3.fromRGB(24, 28, 36)
local INK = Color3.fromRGB(255, 255, 255)
local MUTED = Color3.fromRGB(170, 175, 185)
local BUY = Color3.fromRGB(90, 200, 110)
local OFF = Color3.fromRGB(90, 90, 100)

-- Display order and copy. InsuranceClaim is offered on the payout screen, not here.
local CATALOG: { { sku: string, pass: boolean, name: string, detail: string } } = {
	{ sku = "DoublePay", pass = true, name = "Double Pay", detail = "Double cash from every job." },
	{
		sku = "VIPForeman",
		pass = true,
		name = "VIP Foreman",
		detail = "+10% on your time bonus.",
	},
	{
		sku = "HornRadio",
		pass = true,
		name = "Horn & Radio",
		detail = "Pick your truck horn sound.",
	},
	{
		sku = "CrewBoost",
		pass = false,
		name = "Crew Boost",
		detail = "Boost pay for your whole crew.",
	},
	{ sku = "Cash500", pass = false, name = "$500", detail = "Cash for upgrades." },
	{ sku = "Cash1800", pass = false, name = "$1,800", detail = "Cash for upgrades." },
	{ sku = "Cash5500", pass = false, name = "$5,500", detail = "Cash for upgrades." },
}

type State = { ready: boolean, passes: { [string]: boolean }, available: { [string]: boolean } }

local StoreController = {}

local state: State = { ready = false, passes = {}, available = {} }
local prices: { [string]: string } = {}
local productIds: any = nil

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function idFor(entry): number?
	if not productIds then
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local module = shared and shared:FindFirstChild("ProductIds")
		local ok, ids = false, nil
		if module and module:IsA("ModuleScript") then
			ok, ids = pcall(require, module)
		end
		productIds = if ok and type(ids) == "table" then ids else {}
	end
	local group = productIds[if entry.pass then "Passes" else "Products"]
	local id = type(group) == "table" and group[entry.sku]
	return if type(id) == "number" then id else nil
end

-- Robux price label from Roblox (regional pricing), fetched once per SKU in the background.
local function priceFor(entry, onReady: () -> ()): string
	local cached = prices[entry.sku]
	if cached then
		return cached
	end
	prices[entry.sku] = "..."
	local id = idFor(entry)
	if id then
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(
					id,
					if entry.pass then Enum.InfoType.GamePass else Enum.InfoType.Product
				)
			end)
			local robux = ok and type(info) == "table" and info.PriceInRobux
			prices[entry.sku] = if type(robux) == "number" then `R$ {robux}` else "Buy"
			onReady()
		end)
	else
		prices[entry.sku] = "Buy"
	end
	return prices[entry.sku]
end

function StoreController.Start()
	local remotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
	-- the Monetization remotes only exist once the server side is installed
	local folder = remotes:WaitForChild("Monetization", 60)
	if not folder then
		return
	end
	local stateRemote = folder:WaitForChild("State", 10) :: RemoteEvent?
	local request = folder:WaitForChild("RequestPurchase", 10) :: RemoteFunction?
	if not stateRemote or not request then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "Store"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6

	local open = Instance.new("TextButton")
	open.Name = "Open"
	open.AnchorPoint = Vector2.new(1, 0)
	open.Position = UDim2.new(1, -274, 0, 8) -- left of the Settings button
	open.Size = UDim2.fromOffset(96, 40)
	open.BackgroundColor3 = Color3.fromRGB(240, 170, 40)
	open.Font = Enum.Font.GothamBold
	open.TextSize = 16
	open.TextColor3 = Color3.fromRGB(30, 30, 30)
	open.Text = "Store"
	open.Visible = false
	corner(open, 12)
	open.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 0)
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
	title.Text = "Store"
	title.LayoutOrder = 0
	title.Parent = panel

	local rows = Instance.new("Frame")
	rows.BackgroundTransparency = 1
	rows.Size = UDim2.fromScale(1, 0)
	rows.AutomaticSize = Enum.AutomaticSize.Y
	rows.LayoutOrder = 1
	rows.Parent = panel
	local rowList = Instance.new("UIListLayout")
	rowList.Padding = UDim.new(0, 6)
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Parent = rows

	local note = Instance.new("TextLabel")
	note.BackgroundTransparency = 1
	note.Size = UDim2.new(1, 0, 0, 20)
	note.Font = Enum.Font.Gotham
	note.TextSize = 14
	note.TextColor3 = MUTED
	note.Text = ""
	note.LayoutOrder = 2
	note.Parent = panel

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

	local busy = false
	local render: () -> ()

	local function row(entry, order: number)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 56)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = order
		frame.Parent = rows
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(4, 4)
		name.Size = UDim2.new(1, -120, 0, 24)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 18
		name.TextColor3 = INK
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = entry.name
		name.Parent = frame
		local detail = Instance.new("TextLabel")
		detail.BackgroundTransparency = 1
		detail.Position = UDim2.fromOffset(4, 28)
		detail.Size = UDim2.new(1, -120, 0, 22)
		detail.Font = Enum.Font.Gotham
		detail.TextSize = 14
		detail.TextColor3 = MUTED
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.Text = entry.detail
		detail.Parent = frame
		local buy = Instance.new("TextButton")
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -4, 0.5, 0)
		buy.Size = UDim2.fromOffset(104, 44)
		buy.Font = Enum.Font.GothamBold
		buy.TextSize = 16
		buy.TextColor3 = INK
		corner(buy, 10)
		buy.Parent = frame
		local owned = entry.pass and state.passes[entry.sku] == true
		if owned then
			buy.Text = "Owned"
			buy.BackgroundColor3 = OFF
			buy.AutoButtonColor = false
			return
		end
		buy.Text = priceFor(entry, function()
			render()
		end)
		buy.BackgroundColor3 = BUY
		buy.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			note.Text = ""
			local ok, accepted, reason = pcall(function()
				return (request :: RemoteFunction):InvokeServer(entry.sku)
			end)
			busy = false
			if not ok or not accepted then
				note.Text = if reason == "NotReady"
					then "Not available yet, try again soon."
					else "Couldn't open the purchase. Try again."
			end
		end)
	end

	render = function()
		for _, child in rows:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local anyListed = false
		for i, entry in CATALOG do
			if state.ready and state.available[entry.sku] then
				anyListed = true
				row(entry, i)
			end
		end
		open.Visible = anyListed
		if not anyListed then
			panel.Visible = false
		end
	end

	(stateRemote :: RemoteEvent).OnClientEvent:Connect(function(s)
		if type(s) ~= "table" then
			return
		end
		state = {
			ready = s.ready == true,
			passes = if type(s.passes) == "table" then s.passes else {},
			available = if type(s.available) == "table" then s.available else {},
		}
		render()
	end)
	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
		note.Text = ""
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	render()
	Scale.attach(gui)
	Gate.bind(gui)
	gui.Parent = player:WaitForChild("PlayerGui")
end

return StoreController
