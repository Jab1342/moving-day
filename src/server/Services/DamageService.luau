--!nonstrict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local DamageModel = require(Shared.Logic.DamageModel)
local DamageService = {}
DamageService.__index = DamageService

function DamageService.new(items)
	return setmetatable({ items = items, ragdollTimes = {}, nextRagdollPoll = 0 }, DamageService)
end

local function finiteVector(value)
	return typeof(value) == "Vector3"
		and value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and math.abs(value.X) < math.huge
		and math.abs(value.Y) < math.huge
		and math.abs(value.Z) < math.huge
end

local function finitePose(value)
	return finiteVector(value.Position)
		and finiteVector(value.RightVector)
		and finiteVector(value.UpVector)
		and finiteVector(value.LookVector)
end

function DamageService:PlayerHitContext(now)
	local fx = self.items.remotes and self.items.remotes.Fx
	if
		not fx
		or not fx.Ragdoll
		or next(self.items.records) == nil
		or now < self.nextRagdollPoll
	then
		return nil
	end
	self.nextRagdollPoll = now + Config.RagdollPollSeconds
	local crews = {}
	for player in self.ragdollTimes do
		if player.Parent ~= Players then
			self.ragdollTimes[player] = nil
		end
	end
	for _, player in Players:GetPlayers() do
		local crewId = player:GetAttribute("CrewId")
		local char = player.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if
			type(crewId) ~= "string"
			or crewId == ""
			or not humanoid
			or humanoid.Health <= 0
			or humanoid.Sit
			or not root
			or not root:IsA("BasePart")
			or now < (self.ragdollTimes[player] or 0)
		then
			continue
		end
		local crew = crews[crewId]
		if not crew then
			crew = { characters = {}, targets = {} }
			crews[crewId] = crew
		end
		table.insert(crew.characters, char)
		table.insert(crew.targets, { player = player, character = char, root = root })
	end
	for _, crew in crews do
		local cast, overlap = RaycastParams.new(), OverlapParams.new()
		cast.FilterType, overlap.FilterType =
			Enum.RaycastFilterType.Include, Enum.RaycastFilterType.Include
		cast.FilterDescendantsInstances, overlap.FilterDescendantsInstances =
			crew.characters, crew.characters
		cast.RespectCanCollide, overlap.RespectCanCollide = false, false
		overlap.MaxParts = Config.RagdollQueryMaxParts
		crew.cast, crew.overlap = cast, overlap
	end
	return crews
end

function DamageService:CheckPlayerHits(rec, now, crews)
	local root = rec.root
	local previous = rec.ragdollSample
	local velocity, cf = root.AssemblyLinearVelocity, root.CFrame
	rec.ragdollSample = { velocity = velocity, cf = cf, at = now }
	local crew = crews[rec.crewId]
	if
		not crew
		or rec.a ~= 0
		or rec.weld
		or root.Anchored
		or not root.CanCollide
		or (rec.state ~= "Idle" and rec.state ~= "InTruck")
		or now < rec.graceUntil
		or not finiteVector(velocity)
		or not finitePose(cf)
	then
		return
	end
	local sweep = if previous then cf.Position - previous.cf.Position else Vector3.zero
	if
		previous
		and (
			not finiteVector(previous.velocity)
			or not finitePose(previous.cf)
			or not finiteVector(sweep)
			or sweep.Magnitude > Config.RagdollMaxSweepStuds
			or now - previous.at > Config.RagdollMaxSampleSeconds
		)
	then
		return
	end
	local incoming = if previous and previous.velocity.Magnitude > velocity.Magnitude
		then previous.velocity
		else velocity
	if incoming.Magnitude <= Config.RagdollHitSpeed then
		return
	end
	local hits = workspace:GetPartBoundsInBox(cf, root.Size, crew.overlap)
	if previous and sweep.Magnitude > 0 then
		local hit = workspace:Blockcast(previous.cf, root.Size, sweep, crew.cast)
		if hit then
			table.insert(hits, hit.Instance)
		end
	end
	for _, target in crew.targets do
		local player = target.player
		if now < (self.ragdollTimes[player] or 0) then
			continue
		end
		local contact = false
		for _, part in hits do
			if part:IsDescendantOf(target.character) then
				contact = true
				break
			end
		end
		local relative = incoming - target.root.AssemblyLinearVelocity
		if
			not contact
			or not finiteVector(relative)
			or relative.Magnitude <= Config.RagdollHitSpeed
		then
			continue
		end
		-- Contract impulse is a velocity delta; the client applies mass scaling. Never change HP.
		local impulse = relative.Unit
			* math.min(
				Config.RagdollMaxKnockback,
				relative.Magnitude * Config.RagdollKnockbackScale
			)
		impulse = Vector3.new(
			impulse.X,
			math.clamp(
				impulse.Y,
				-Config.RagdollMaxVerticalKnockback,
				Config.RagdollMaxVerticalKnockback
			),
			impulse.Z
		)
		self.ragdollTimes[player] = now + Config.RagdollCooldownSeconds
		self.items.remotes.Fx.Ragdoll:FireClient(player, Config.RagdollSeconds, impulse)
	end
end

function DamageService:Initialize(rec)
	rec.model:SetAttribute("HP", Config.ItemMaxHP)
	rec.model:SetAttribute("BlameUserId", 0)
end

function DamageService:Step()
	local now = os.clock()
	local crews = self:PlayerHitContext(now)
	for _, rec in self.items.records do
		if crews then
			self:CheckPlayerHits(rec, now, crews)
		end
		local velocity = rec.root.AssemblyLinearVelocity
		local previous = rec.previousVelocity or velocity
		rec.previousVelocity = velocity
		local truck = if rec.state == "InTruck" then rec.truck else nil
		local delta = velocity - previous
		if truck then
			local bedVelocity = truck.bed.AssemblyLinearVelocity
			if rec.damageTruck == truck and rec.previousBedVelocity then
				-- Common assembly acceleration is truck motion, not a cargo impact.
				-- Relative jolts still damage loose OR strapped furniture normally.
				delta -= bedVelocity - rec.previousBedVelocity
			end
			rec.previousBedVelocity = bedVelocity
		else
			rec.previousBedVelocity = nil
		end
		rec.damageTruck = truck
		if
			rec.state == "Delivered"
			or now < rec.graceUntil
			or now - rec.lastDamageAt < Config.DamageCooldownSeconds
		then
			continue
		end
		local deltaV = delta.Magnitude
		if rec.state == "Carried" then
			-- Ignore careful doorway bumps. Released/cargo items retain drop/crash tuning.
			deltaV = math.max(
				0,
				math.min(deltaV, Config.MaxDeltaVAccepted)
					- math.max(0, Config.CarriedDamageThreshold - Config.DamageThreshold)
			)
		end
		local blame = if rec.truck then rec.truck.driverId else rec.lastCarrier
		local player = Players:GetPlayerByUserId(blame)
		local damage = DamageModel.impactDamage(deltaV, rec.def, {
			protection = if rec.model:GetAttribute("Wrapped") then Config.BlanketProtection else 0,
			assist = player ~= nil and player:GetAttribute("Assist") == true,
		})
		if damage <= 0 then
			continue
		end
		rec.lastDamageAt = now
		local hp = math.max(0, rec.model:GetAttribute("HP") - damage)
		rec.model:SetAttribute("HP", hp)
		rec.model:SetAttribute("BlameUserId", blame)
		local info = { itemId = rec.def.id, cframe = rec.model:GetPivot(), velocity = velocity }
		self.items:Fire(rec, if hp == 0 then "Broken" else "Damaged", info)
		if hp == 0 then
			self.items:Remove(rec, true)
		end
	end
end

return DamageService
