--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local definitions = require(shared.Contracts.Remotes)
if
	game:GetService("RunService"):IsStudio()
	and game:GetService("ServerScriptService"):FindFirstChild("_DevItemStub")
then
	warn("[MovingDay] Remove _DevItemStub before starting the server services")
	return
end

local function folder(parent: Instance, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("Folder"), name .. " must be a Folder")
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

local PhysicsService = game:GetService("PhysicsService")
for _, name in { "Players", "Furniture", "Carried", "Truck" } do
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end
PhysicsService:CollisionGroupSetCollidable("Carried", "Players", false)

local Players = game:GetService("Players")
local function configureCharacter(char)
	local function configurePart(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = "Players"
		end
	end
	for _, part in char:GetDescendants() do
		configurePart(part)
	end
	char.DescendantAdded:Connect(configurePart)
end
local function configurePlayer(player)
	player.CharacterAdded:Connect(configureCharacter)
	if player.Character then
		configureCharacter(player.Character)
	end
end
Players.PlayerAdded:Connect(configurePlayer)
for _, player in Players:GetPlayers() do
	configurePlayer(player)
end

local remotes = folder(shared, "Remotes")
for path, definition in definitions do
	local group, name = string.match(path, "^([^.]+)%.([^.]+)$")
	assert(group and name, "Invalid remote path: " .. path)
	local parent = folder(remotes, group)
	local remote = parent:FindFirstChild(name)
	if remote then
		assert(remote.ClassName == definition.className, "Remote class mismatch: " .. path)
	else
		remote = Instance.new(definition.className)
		remote.Name = name
		remote.Parent = parent
	end
	if remote:IsA("RemoteFunction") then
		-- STUB(Codex): fail closed until the owning service installs validation/handler.
		remote.OnServerInvoke = function()
			return false, "NotReady"
		end
	end
end

local services = script:WaitForChild("Services")
local runtime = folder(workspace, "MovingDayRuntime")
local items = require(services.ItemService).new(folder(runtime, "Items"), remotes)
local trucks = require(services.TruckService).new(folder(runtime, "Trucks"), items)
local damage = require(services.DamageService).new(items)
items.trucks = trucks
items.damage = damage
items:Start()
local crews = require(services.CrewService).new(remotes)
crews:Bind()
game:GetService("RunService").Heartbeat:Connect(function(dt)
	items:Step(dt)
	damage:Step()
	trucks:Step(dt)
	crews:Step()
end)
task.spawn(function()
	require(services.StudioHarness).Start(items, trucks)
end)
