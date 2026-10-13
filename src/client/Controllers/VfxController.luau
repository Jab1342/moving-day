--!strict
-- Break and impact effects, plus ragdoll on Fx.Ragdoll. Everything here is local to this
-- client: fracture pieces never replicate and are cleaned up after a few seconds.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local PIECE_LIFETIME = 6
local BURST_SPEED = 14

local VfxController = {}

local itemDefs: { [string]: any } = {}
local fxFolder: Folder

local function lifetime(): number
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local config = shared and shared:FindFirstChild("Config")
	if config and config:IsA("ModuleScript") then
		local ok, c = pcall(require, config)
		if ok and type(c) == "table" and type(c.FractureLifetimeSeconds) == "number" then
			return c.FractureLifetimeSeconds
		end
	end
	return PIECE_LIFETIME
end

local function burst(part: BasePart, origin: Vector3, velocity: Vector3)
	local away = part.Position - origin
	local dir = if away.Magnitude > 0.01 then away.Unit else Vector3.yAxis
	part.AssemblyLinearVelocity = velocity * 0.5 + (dir + Vector3.yAxis * 0.6) * BURST_SPEED
	part.AssemblyAngularVelocity = Vector3.new(
		math.random() - 0.5,
		math.random() - 0.5,
		math.random() - 0.5
	) * 12
end

-- Authored fracture set when Claude B has made one, otherwise a quick procedural split.
local function spawnPieces(itemId: string, cframe: CFrame, velocity: Vector3)
	local def = itemDefs[itemId]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local fractured = assets and def and assets:FindFirstChild("Fractured")
	local authored = fractured and fractured:FindFirstChild(def.fractured)
	local life = lifetime()
	if authored then
		local clone = authored:Clone()
		clone:PivotTo(cframe)
		for _, p in clone:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = false
				p.CanTouch = false
				p.CollisionGroup = "Furniture"
			end
		end
		clone.Parent = fxFolder
		for _, p in clone:GetDescendants() do
			if p:IsA("BasePart") then
				burst(p, cframe.Position, velocity)
			end
		end
		Debris:AddItem(clone, life)
		return
	end
	local template = assets
		and def
		and assets:FindFirstChild("Furniture")
		and assets.Furniture:FindFirstChild(def.model)
	local size = if template and template:IsA("Model")
		then template:GetExtentsSize()
		else Vector3.new(2, 2, 2)
	local color = Color3.fromRGB(180, 160, 140)
	if template and template:IsA("Model") and template.PrimaryPart then
		color = template.PrimaryPart.Color
	end
	local half = size / 2
	for ix = 0, 1 do
		for iz = 0, 1 do
			for iy = 0, (if size.Y > 3 then 1 else 0) do
				local chunkSize = Vector3.new(
					size.X / 2,
					size.Y / (if size.Y > 3 then 2 else 1),
					size.Z / 2
				) * (0.75 + math.random() * 0.2)
				local offset = Vector3.new(
					-half.X / 2 + ix * half.X,
					chunkSize.Y / 2 + iy * chunkSize.Y,
					-half.Z / 2 + iz * half.Z
				)
				local p = Instance.new("Part")
				p.Size = chunkSize
				p.CFrame = cframe * CFrame.new(offset)
				p.Color = color
				p.Material = Enum.Material.SmoothPlastic
				p.CanTouch = false
				p.CollisionGroup = "Furniture"
				p.Parent = fxFolder
				burst(p, cframe.Position, velocity)
				Debris:AddItem(p, life)
			end
		end
	end
end

local function dustPuff(position: Vector3, strong: boolean)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(220, 210, 195))
	emitter.Size = NumberSequence.new(if strong then 2.5 else 1.2, 0)
	emitter.Transparency = NumberSequence.new(0.3, 1)
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(4, 9)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Enabled = false
	emitter.Parent = anchor
	anchor.Parent = fxFolder
	emitter:Emit(if strong then 30 else 10)
	Debris:AddItem(anchor, 1.5)
end

-- Which sound an item makes when it breaks / takes a knock (names in Assets.Sounds).
local BREAK_SOUND = {
	piano = "SFX_PianoCrash",
	aquarium = "SFX_Splash",
	vase = "SFX_Shatter",
	mirror = "SFX_Shatter",
	tv = "SFX_Shatter",
	lamp = "SFX_Shatter",
	microwave = "SFX_Clunk",
	fridge = "SFX_Clunk",
}
local KNOCK_SOUND = { piano = "SFX_PianoCrash", box = "SFX_Thud", mattress = "SFX_Thud" }

local function playAt(soundName: string, position: Vector3, volumeScale: number)
	local sounds = ReplicatedStorage:FindFirstChild("Assets")
	local template = sounds
		and sounds:FindFirstChild("Sounds")
		and sounds.Sounds:FindFirstChild(soundName)
	if not template or not template:IsA("Sound") then
		return
	end
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = Workspace.Terrain
	local s = template:Clone()
	s.Volume *= volumeScale
	s.PlaybackSpeed = 0.9 + math.random() * 0.2
	s.Parent = anchor
	s:Play()
	Debris:AddItem(anchor, 6)
end

local function onItemEvent(_itemUid: string, kind: string, _hp: number, info: any)
	if type(info) ~= "table" or typeof(info.cframe) ~= "CFrame" then
		return
	end
	local velocity = if typeof(info.velocity) == "Vector3" then info.velocity else Vector3.zero
	if kind == "Broken" then
		spawnPieces(info.itemId, info.cframe, velocity)
		dustPuff(info.cframe.Position, true)
		playAt(BREAK_SOUND[info.itemId] or "SFX_Clunk", info.cframe.Position, 1)
	elseif kind == "Damaged" then
		dustPuff(info.cframe.Position, false)
		playAt(KNOCK_SOUND[info.itemId] or "SFX_Thud", info.cframe.Position, 0.6)
	end
end

-- ANIM_Recover (1.2 s one-shot) once the joints are back, so getting up reads as a stand-up
-- instead of a snap to idle. Skipped until the id is registered in AssetIds.
local function playRecover(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	local module = ReplicatedStorage:FindFirstChild("Shared")
		and ReplicatedStorage.Shared:FindFirstChild("AssetIds")
	local ok, ids = false, nil
	if module and module:IsA("ModuleScript") then
		ok, ids = pcall(require, module)
	end
	local id = ok and type(ids) == "table" and ids.ANIM_Recover
	if not animator or type(id) ~= "string" then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local loaded, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if loaded and track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = false
		track:Play(0.1)
	end
end

-- Swap the local character's Motor6Ds for ball sockets for `duration`, then restore.
local function ragdoll(duration: number, impulse: Vector3)
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not humanoid or not root or humanoid:GetAttribute("MD_Ragdolled") then
		return
	end
	humanoid:SetAttribute("MD_Ragdolled", true)
	local saved = {}
	for _, motor in char:GetDescendants() do
		if motor:IsA("Motor6D") and motor.Name ~= "RootJoint" and motor.Name ~= "Root" then
			local a0 = Instance.new("Attachment")
			a0.CFrame = motor.C0
			a0.Parent = motor.Part0
			local a1 = Instance.new("Attachment")
			a1.CFrame = motor.C1
			a1.Parent = motor.Part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true
			socket.Parent = motor.Parent
			motor.Enabled = false
			table.insert(saved, { motor = motor, a0 = a0, a1 = a1, socket = socket })
		end
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	root:ApplyImpulse(impulse * root.AssemblyMass)
	task.delay(duration, function()
		for _, s in saved do
			s.socket:Destroy()
			s.a0:Destroy()
			s.a1:Destroy()
			if s.motor.Parent then
				s.motor.Enabled = true
			end
		end
		if humanoid.Parent then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			humanoid:SetAttribute("MD_Ragdolled", nil)
			playRecover(humanoid)
		end
	end)
end

function VfxController.Start()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "MD_LocalFx"
	fxFolder.Parent = Workspace

	local shared = ReplicatedStorage:WaitForChild("Shared")
	local ok, defs = pcall(require, shared:WaitForChild("ItemDefs"))
	itemDefs = if ok then defs else {}
	local remotes = shared:WaitForChild("Remotes");
	(remotes:WaitForChild("Job"):WaitForChild("ItemEvent") :: RemoteEvent).OnClientEvent:Connect(
		onItemEvent
	);
	(remotes:WaitForChild("Fx"):WaitForChild("Ragdoll") :: RemoteEvent).OnClientEvent:Connect(
		ragdoll
	)
end

return VfxController
