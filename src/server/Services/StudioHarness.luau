--!nonstrict
-- STUB(Codex): isolated carry/truck fixture until CrewService/JobService exist.
-- No cash, persistence, rewards or products. Never runs outside Studio.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local StudioHarness = {}

function StudioHarness.Start(items, trucks)
	if not RunService:IsStudio() or not Config.StudioHarnessEnabled then
		return
	end
	if game:GetService("ServerScriptService"):FindFirstChild("_DevItemStub") then
		warn(
			"[MovingDay] Remove _DevItemStub before testing authoritative services; harness skipped"
		)
		return
	end
	local map = workspace:WaitForChild("Map", Config.StudioHarnessReadyTimeout)
	local hq = map and map:FindFirstChild("HQ")
	local docks = hq and hq:FindFirstChild("TruckDocks")
	if not docks then
		warn("[MovingDay] Studio harness needs HQ.TruckDocks")
		return
	end
	local crews = {}
	local playerCrews = {}
	local function join(player)
		local crew
		for _, candidate in crews do
			if candidate.count < Config.MaxCrewSize then
				crew = candidate
				break
			end
		end
		if not crew then
			local index = #crews + 1
			if index > Config.MaxCrews then
				return
			end
			local dock = docks:FindFirstChild("TruckDock_" .. index)
			local spawnPoint = dock and dock:FindFirstChild("Spawn")
			if not spawnPoint or not spawnPoint:IsA("Attachment") then
				warn("[MovingDay] Missing truck dock Spawn")
				return
			end
			local id = Config.StudioHarnessCrewId .. "-" .. index
			local truck, reason = trucks:Spawn(id, spawnPoint.WorldCFrame)
			if not truck then
				warn("[MovingDay] Truck fixture unavailable: " .. reason)
				return
			end
			crew = { id = id, count = 0, spawn = spawnPoint.WorldCFrame }
			table.insert(crews, crew)
			for i, itemId in Config.StudioHarnessItemIds do
				local _, errorReason = items:Spawn(
					itemId,
					id,
					crew.spawn
						* CFrame.new(
							Config.StudioHarnessSpawnOffset,
							Config.StudioHarnessSpawnHeight,
							(i - 1) * Config.StudioHarnessItemSpacing
						)
				)
				if errorReason then
					warn("[MovingDay] Item fixture unavailable: " .. itemId .. " " .. errorReason)
				end
			end
		end
		crew.count += 1
		playerCrews[player] = crew
		-- STUB(Codex): CrewService normally writes this attribute.
		player:SetAttribute("CrewId", crew.id)
		local function spawnCharacter(char)
			local root = char:WaitForChild("HumanoidRootPart", Config.StudioHarnessReadyTimeout)
			if root then
				task.delay(Config.StudioHarnessCharacterDelay, function()
					if player.Character == char and char.Parent then
						char:PivotTo(
							crew.spawn
								* CFrame.new(
									Config.StudioHarnessSpawnOffset,
									Config.StudioHarnessCharacterHeight,
									-Config.StudioHarnessItemSpacing
								)
						)
					end
				end)
			end
		end
		player.CharacterAdded:Connect(spawnCharacter)
		if player.Character then
			task.spawn(spawnCharacter, player.Character)
		end
	end
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(function(player)
		local crew = playerCrews[player]
		if crew then
			crew.count -= 1
			playerCrews[player] = nil
		end
	end)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	warn("[MovingDay] Studio carry/truck fixture enabled; no save or job rewards")
end

return StudioHarness
