--!strict
-- The homeowner waits beside the SOLD sign at your destination: idle while you load, waving
-- once your truck is close, cheering at payout, then gone. Purely local and cosmetic: a clone
-- of Assets.Props.NPC_Homeowner under the camera, animations from AssetIds when registered.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local WAVE_RANGE = 90 -- studs between your truck and the TruckSpot before they start waving
local CHEER_LINGER = 4 -- seconds the homeowner stays after the payout cheer
local SIDE_OFFSET = 3.5 -- studs beside the yard sign

local HomeownerController = {}

local npc: Model? = nil
local lot: Instance? = nil
local waveTrack: AnimationTrack? = nil
local acc = 0

local function assetId(name: string): string?
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = shared and shared:FindFirstChild("AssetIds")
	if module and module:IsA("ModuleScript") then
		local ok, ids = pcall(require, module)
		if ok and type(ids) == "table" and type(ids[name]) == "string" then
			return ids[name]
		end
	end
	return nil
end

local function loadTrack(name: string, looped: boolean): AnimationTrack?
	local humanoid = npc and npc:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local id = assetId(name)
	if not animator or not id then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if not ok or not track then
		return nil
	end
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = looped
	return track
end

local function despawn()
	waveTrack = nil
	lot = nil
	if npc then
		npc:Destroy()
		npc = nil
	end
end

local function spawnAt(destination: Instance)
	if npc and lot == destination then
		return
	end
	despawn()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("Props")
	local template = props and props:FindFirstChild("NPC_Homeowner")
	local sign = destination:FindFirstChild("PRP_YardSign")
	if not template or not template:IsA("Model") or not sign or not sign:IsA("Model") then
		return
	end
	local signPivot = sign:GetPivot()
	local feet = signPivot.Position + signPivot.RightVector * SIDE_OFFSET
	local facing = Vector3.new(signPivot.LookVector.X, 0, signPivot.LookVector.Z)
	local model = template:Clone()
	model:PivotTo(CFrame.lookAt(feet, feet + facing))
	model.Parent = Workspace.CurrentCamera -- local only
	npc = model
	lot = destination
end

local function myTruckDistance(): number?
	local crew = player:GetAttribute("CrewId")
	local runtime = Workspace:FindFirstChild("MovingDayRuntime")
	local trucks = runtime and runtime:FindFirstChild("Trucks")
	local pad = lot and lot:FindFirstChild("Pad")
	local spot = pad and pad:FindFirstChild("TruckSpot")
	if not trucks or not spot or not spot:IsA("Attachment") then
		return nil
	end
	for _, truck in trucks:GetChildren() do
		if truck:IsA("Model") and truck:GetAttribute("CrewId") == crew then
			return (truck:GetPivot().Position - spot.WorldPosition).Magnitude
		end
	end
	return nil
end

local function onState(state: any)
	if type(state) ~= "table" or player:GetAttribute("CrewId") ~= state.crewId then
		return
	end
	local lots = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Lots")
	local destination = lots and lots:FindFirstChild(`DestinationLot_{state.lotId}`)
	if not destination then
		despawn()
		return
	end
	if state.phase ~= "Payout" then
		spawnAt(destination)
	end
end

local function onPayout()
	if not npc then
		return
	end
	if waveTrack then
		waveTrack:Stop(0.2)
		waveTrack = nil
	end
	local cheer = loadTrack("ANIM_HomeownerCheer", false)
	if cheer then
		cheer:Play(0.1)
	end
	local leaving = npc
	task.delay(CHEER_LINGER, function()
		if npc == leaving then
			despawn()
		end
	end)
end

function HomeownerController.Start()
	local job = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Job")
	local stateRemote = job:WaitForChild("State") :: RemoteEvent
	local payoutRemote = job:WaitForChild("Payout") :: RemoteEvent
	stateRemote.OnClientEvent:Connect(onState)
	payoutRemote.OnClientEvent:Connect(onPayout)
	player:GetAttributeChangedSignal("CrewId"):Connect(function()
		if player:GetAttribute("CrewId") == nil then
			task.delay(CHEER_LINGER, function()
				if player:GetAttribute("CrewId") == nil then
					despawn()
				end
			end)
		end
	end)
	-- wave while your truck is pulling up
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 or not npc then
			return
		end
		acc = 0
		local distance = myTruckDistance()
		local near = distance ~= nil and distance < WAVE_RANGE
		if near and not waveTrack then
			waveTrack = loadTrack("ANIM_HomeownerWave", true)
			if waveTrack then
				waveTrack:Play(0.2)
			end
		elseif not near and waveTrack then
			waveTrack:Stop(0.3)
			waveTrack = nil
		end
	end)
end

return HomeownerController
