--!nonstrict
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Defs = require(Shared.ItemDefs)
local Carry = require(Shared.Contracts.Carry)
local Rules = require(Shared.Logic.CarryRules)
local Rate = require(Shared.Logic.RateLimit)
local ItemService = {}
ItemService.__index = ItemService

local function character(player)
	local char = player and player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
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

function ItemService.new(folder, remotes)
	return setmetatable({
		folder = folder,
		remotes = remotes,
		records = {},
		holding = {},
		buckets = {},
		strikes = {},
		connections = {},
		nextStrap = 0,
	}, ItemService)
end

function ItemService:Allowed(player, action, highRate)
	local buckets = self.buckets[player] or {}
	self.buckets[player] = buckets
	local ok, nextBucket = Rate.consume(
		buckets[action],
		os.clock(),
		if highRate then Config.SecondGripHz else Config.RemotePerSecond,
		if highRate then Config.SecondGripBurst else Config.RemoteBurst
	)
	buckets[action] = nextBucket
	return ok
end

function ItemService:Fire(rec, kind, info)
	if self.analytics then
		local actor = Players:GetPlayerByUserId(
			if kind == "Broken" and rec.truck then rec.truck.driverId else rec.lastCarrier
		)
		if actor then
			if kind == "Loaded" then
				self.analytics:Funnel(actor, 3)
			elseif kind == "Delivered" then
				self.analytics:Funnel(actor, 5)
			elseif kind == "Broken" then
				self.analytics:Custom(
					actor,
					"ItemBroken",
					1,
					{ [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = rec.def.id }
				)
			end
		end
	end
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("CrewId") == rec.crewId then
			self.remotes.Job.ItemEvent:FireClient(
				player,
				rec.uid,
				kind,
				rec.model:GetAttribute("HP") or 0,
				info
			)
		end
	end
end

function ItemService:SetState(rec, state)
	rec.state = state
	rec.model:SetAttribute("State", state)
end

function ItemService:Grace(rec)
	rec.graceUntil = os.clock() + Config.GrabGraceSeconds
	rec.previousVelocity = rec.root.AssemblyLinearVelocity
end

function ItemService:SetOwner(rec, player, automatic)
	if rec.root.Anchored or not rec.root:CanSetNetworkOwnership() then
		return false
	end
	if automatic then
		rec.root:SetNetworkOwnershipAuto()
	else
		rec.root:SetNetworkOwner(player)
	end
	return true
end

function ItemService:Spawn(itemId, crewId, cframe)
	local def = Defs[itemId]
	assert(
		def and type(crewId) == "string" and crewId ~= "",
		"Valid item definition and crew required"
	)
	local assets = Shared.Parent:FindFirstChild("Assets")
	local furniture = assets and assets:FindFirstChild("Furniture")
	local template = furniture and furniture:FindFirstChild(def.model)
	if not template or not template:IsA("Model") then
		return nil, "MissingTemplate"
	end
	local model = template:Clone()
	local root = model:FindFirstChild(Carry.Root) or model.PrimaryPart
	if not root or not root:IsA("BasePart") then
		model:Destroy()
		return nil, "MissingRoot"
	end
	model.PrimaryPart = root
	local uid = HttpService:GenerateGUID(false)
	local rec = {
		uid = uid,
		model = model,
		root = root,
		def = def,
		crewId = crewId,
		a = 0,
		b = 0,
		state = "Idle",
		lastCarrier = 0,
		settledFor = 0,
		lastDamageAt = -math.huge,
	}
	model.Name = uid
	for name, value in
		{
			ItemId = itemId,
			ItemUid = uid,
			CrewId = crewId,
			State = "Idle",
			CarrierA = 0,
			CarrierB = 0,
			Strapped = false,
			Wrapped = false,
			Dolly = false,
			Carry = def.carry,
		}
	do
		model:SetAttribute(name, value)
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CollisionGroup = "Furniture"
			part.CanTouch = false
		end
	end
	model:PivotTo(cframe)
	model.Parent = self.folder
	self.records[uid] = rec
	self:SetOwner(rec, nil, false)
	self:Grace(rec)
	rec.lastPivot = model:GetPivot()
	if self.damage then
		self.damage:Initialize(rec)
	end
	return rec
end

function ItemService:Rig(rec)
	local root = rec.root
	local attachment = root:FindFirstChild(Carry.Attachment)
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = Carry.Attachment
		attachment.Parent = root
	end
	local position = root:FindFirstChild(Carry.AlignPosition)
	if not position then
		position = Instance.new("AlignPosition")
		position.Enabled = false
		position.Name = Carry.AlignPosition
		position.Parent = root
	end
	local orientation = root:FindFirstChild(Carry.AlignOrientation)
	if not orientation then
		orientation = Instance.new("AlignOrientation")
		orientation.Enabled = false
		orientation.Name = Carry.AlignOrientation
		orientation.Parent = root
	end
	position.Enabled = false
	orientation.Enabled = false
	position.Mode = Enum.PositionAlignmentMode.OneAttachment
	position.Attachment0 = attachment
	position.ApplyAtCenterOfMass = true
	position.MaxForce = Config.CarryMaxForce
	position.MaxVelocity = Config.MaxCarrySpeed
	position.Responsiveness = Config.CarryResponsiveness
	position.RigidityEnabled = false
	position.Position = root.Position
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.Attachment0 = attachment
	orientation.MaxTorque = Config.CarryMaxTorque
	orientation.MaxAngularVelocity = Config.CarryMaxAngularVelocity
	orientation.Responsiveness = Config.CarryResponsiveness
	orientation.RigidityEnabled = false
	orientation.CFrame = root.CFrame.Rotation
	return position, orientation
end

function ItemService:ApplyCarriers(rec)
	local position, orientation = self:Rig(rec)
	local lead = Players:GetPlayerByUserId(rec.a)
	if rec.a ~= 0 and not character(lead) then
		return false
	end
	if not self:SetOwner(rec, lead, rec.a == 0) then
		return false
	end
	for _, part in rec.model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = if rec.a ~= 0 then "Carried" else "Furniture"
		end
	end
	rec.model:SetAttribute("CarrierA", rec.a)
	rec.model:SetAttribute("CarrierB", rec.b)
	local crewCount = 0
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("CrewId") == rec.crewId then
			crewCount += 1
		end
	end
	local owner = Players:GetPlayerByUserId(rec.a)
	local purchasedDolly = owner and self.upgrades and self.upgrades:DollyTier(owner) > 0
	rec.model:SetAttribute(
		"Dolly",
		rec.def.carry == "Two"
			and rec.a ~= 0
			and rec.b == 0
			and (crewCount == 1 or purchasedDolly == true)
	)
	self:SetState(rec, if rec.a ~= 0 then "Carried" else "Idle")
	position.Enabled = rec.a ~= 0
	orientation.Enabled = rec.a ~= 0
	self:Grace(rec)
	return true
end

function ItemService:Grab(player, uid, grip)
	local strikes = self.strikes[player.UserId]
	if
		strikes
		and strikes.count >= Config.StrikeLimit
		and os.clock() - strikes.at <= Config.StrikeWindowSeconds
	then
		return false, "CarrySuspended"
	end
	if not self:Allowed(player, "Grab") then
		return false, "RateLimited"
	end
	if type(uid) ~= "string" then
		return false, "InvalidItem"
	end
	local rec = self.records[uid]
	local hrp = character(player)
	if not rec or not hrp or not rec.model.Parent then
		return false, "Unavailable"
	end
	local target = rec.root:FindFirstChild(if grip == 2 then "Grip2" else "Grip1")
	local distance = ((if target and target:IsA("Attachment")
		then target.WorldPosition
		else rec.root.Position) - hrp.Position).Magnitude
	local ok, reason = Rules.canGrab(
		{
			a = rec.a,
			b = rec.b,
			state = rec.state,
			crewId = rec.crewId,
			carry = rec.def.carry,
			strapped = rec.model:GetAttribute("Strapped"),
		},
		player.UserId,
		grip,
		player:GetAttribute("CrewId"),
		distance,
		self.holding[player.UserId] ~= nil,
		Config
	)
	if not ok then
		return false, reason
	end
	if not rec.root:CanSetNetworkOwnership() then
		return false, "Anchored"
	end
	if rec.truck then
		self.trucks:Release(rec)
	end
	if grip == 1 then
		rec.a = player.UserId
	else
		rec.b = player.UserId
	end
	self.holding[player.UserId] = uid
	rec.lastCarrier = player.UserId
	if not self:ApplyCarriers(rec) then
		self.holding[player.UserId] = nil
		if grip == 1 then
			rec.a = 0
		else
			rec.b = 0
		end
		return false, "OwnershipUnavailable"
	end
	rec.lastPivot = rec.model:GetPivot()
	if self.analytics then
		self.analytics:Funnel(player, 2)
	end
	return true, nil
end

function ItemService:DropUser(userId)
	local uid = self.holding[userId]
	local rec = uid and self.records[uid]
	self.holding[userId] = nil
	if not rec then
		return
	end
	rec.a, rec.b = Rules.drop(rec.a, rec.b, userId)
	rec.pendingWrap = nil
	if rec.a ~= 0 and not character(Players:GetPlayerByUserId(rec.a)) then
		self.holding[rec.a] = nil
		rec.a = 0
	end
	self:ApplyCarriers(rec)
end

function ItemService:Relay(player, uid, handPos)
	if
		not self:Allowed(player, "SecondGrip", true)
		or type(uid) ~= "string"
		or not finiteVector(handPos)
	then
		return
	end
	local rec = self.records[uid]
	local hrp = character(player)
	if not rec or rec.b ~= player.UserId or not hrp then
		return
	end
	if (handPos - hrp.Position).Magnitude > Config.HandPositionTolerance then
		return
	end
	local grip = rec.root:FindFirstChild("Grip2")
	if
		not grip
		or not grip:IsA("Attachment")
		or (hrp.Position - grip.WorldPosition).Magnitude > Config.SecondGripDropRange
	then
		self:DropUser(player.UserId)
		return
	end
	local lead = Players:GetPlayerByUserId(rec.a)
	if lead then
		self.remotes.Carry.SecondGripRelay:FireClient(lead, uid, player.UserId, handPos)
	end
end

function ItemService:Wrap(player, rec)
	if not self.upgrades then
		return false, "NotReady"
	end
	if rec.state ~= "Carried" or (rec.a ~= player.UserId and rec.b ~= player.UserId) then
		return false, "NotCarrier"
	end
	if rec.model:GetAttribute("Wrapped") or rec.pendingWrap then
		return false, "AlreadyWrapped"
	end
	local token = {}
	rec.pendingWrap = token
	task.wait(Config.WrapSeconds)
	local current = character(player)
	local valid = self.records[rec.uid] == rec
		and rec.pendingWrap == token
		and rec.state == "Carried"
		and (rec.a == player.UserId or rec.b == player.UserId)
		and current
		and player:GetAttribute("CrewId") == rec.crewId
		and (rec.root.Position - current.Position).Magnitude <= Config.GrabRange
	if rec.pendingWrap == token then
		rec.pendingWrap = nil
	end
	if not valid then
		return false, "Cancelled"
	end
	local paid, reason = self.upgrades:PayWrap(player)
	if not paid then
		return false, reason
	end
	rec.model:SetAttribute("Wrapped", true)
	return true
end

function ItemService:Strap(player, uid, action)
	if not self:Allowed(player, "Strap") then
		return false, "RateLimited"
	end
	if type(uid) ~= "string" then
		return false, "InvalidItem"
	end
	local rec = self.records[uid]
	local hrp = character(player)
	if not rec or not hrp or rec.crewId ~= player:GetAttribute("CrewId") then
		return false, "WrongCrew"
	end
	if (rec.root.Position - hrp.Position).Magnitude > Config.GrabRange then
		return false, "OutOfRange"
	end
	if action == "Wrap" then
		return self:Wrap(player, rec)
	end
	if action ~= "Strap" or not rec.truck or rec.state ~= "InTruck" then
		return false, "NotInTruck"
	end
	if rec.model:GetAttribute("Strapped") or rec.pendingStrap then
		return false, "AlreadyStrapped"
	end
	local truck = rec.truck
	if not self.trucks:ReserveStrap(truck) then
		return false, "NoSlots"
	end
	local token = {}
	rec.pendingStrap = token
	task.wait(Config.StrapSeconds)
	truck.pendingStraps -= 1
	if rec.pendingStrap ~= token then
		return false, "Cancelled"
	end
	rec.pendingStrap = nil
	local current = character(player)
	if
		self.records[uid] == rec
		and rec.truck == truck
		and rec.state == "InTruck"
		and current
		and player:GetAttribute("CrewId") == rec.crewId
		and (rec.root.Position - current.Position).Magnitude <= Config.GrabRange
	then
		rec.model:SetAttribute("Strapped", true)
		return true
	end
	return false, "Cancelled"
end

function ItemService:Remove(rec, broken)
	if self.onRemoved then
		self.onRemoved(rec, broken)
	end
	if rec.truck then
		self.trucks:Release(rec)
	end
	for _, userId in { rec.a, rec.b } do
		if userId ~= 0 then
			self.holding[userId] = nil
		end
	end
	if broken then
		self:SetState(rec, "Broken")
	end
	self.records[rec.uid] = nil
	rec.model:Destroy()
end

function ItemService:Step(dt)
	for _, rec in self.records do
		if not rec.model.Parent or not rec.root.Parent then
			-- FallenPartsDestroyHeight can remove the root but leave its Model behind.
			-- Lost undelivered cargo is a completed loss, never an endless manifest entry.
			self:Remove(rec, rec.state ~= "Delivered")
			continue
		end
		if rec.a == 0 then
			continue
		end
		local player = Players:GetPlayerByUserId(rec.a)
		local hrp = character(player)
		if not hrp or player:GetAttribute("CrewId") ~= rec.crewId then
			self:DropUser(rec.a)
			continue
		end
		local speed = rec.root.AssemblyLinearVelocity
		local previous = rec.lastPivot.Position
		local valid = finiteVector(speed)
			and speed.Magnitude <= Config.MaxCarrySpeed
			and (rec.root.Position - hrp.Position).Magnitude <= Config.MaxCarryDistance
			and (rec.model:GetPivot().Position - previous).Magnitude
				<= Config.MaxCarrySpeed * dt + Config.CarryDisplacementSlack
		if not valid then
			local offender = rec.a
			self:DropUser(offender)
			if rec.a ~= 0 then
				self:DropUser(rec.a)
			end
			self:SetOwner(rec, nil, false)
			rec.model:PivotTo(rec.lastPivot)
			rec.root.AssemblyLinearVelocity = Vector3.zero
			rec.root.AssemblyAngularVelocity = Vector3.zero
			local strike = self.strikes[offender]
			if not strike or os.clock() - strike.at > Config.StrikeWindowSeconds then
				strike = { at = os.clock(), count = 0 }
				self.strikes[offender] = strike
			end
			strike.count += 1
			-- STUB(Codex): fail-closed carry suspension until CrewService supplies removal.
			if strike.count >= Config.StrikeLimit and self.onCrewRemove then
				self.onCrewRemove(player)
			end
		else
			rec.lastPivot = rec.model:GetPivot()
		end
		if rec.b ~= 0 then
			local second = Players:GetPlayerByUserId(rec.b)
			local secondRoot = character(second)
			local grip = rec.root:FindFirstChild("Grip2")
			if
				not secondRoot
				or second:GetAttribute("CrewId") ~= rec.crewId
				or not grip
				or (secondRoot.Position - grip.WorldPosition).Magnitude
					> Config.SecondGripDropRange
			then
				self:DropUser(rec.b)
			end
		end
	end
end

function ItemService:Start()
	self.remotes.Carry.RequestGrab.OnServerInvoke = function(player, uid, grip)
		return self:Grab(player, uid, grip)
	end
	self.remotes.Carry.RequestStrap.OnServerInvoke = function(player, uid, action)
		return self:Strap(player, uid, action)
	end
	table.insert(
		self.connections,
		self.remotes.Carry.RequestDrop.OnServerEvent:Connect(function(player, uid)
			if
				self:Allowed(player, "Drop")
				and type(uid) == "string"
				and self.holding[player.UserId] == uid
			then
				self:DropUser(player.UserId)
			end
		end)
	)
	table.insert(
		self.connections,
		self.remotes.Carry.SecondGrip.OnServerEvent:Connect(function(player, uid, position)
			self:Relay(player, uid, position)
		end)
	)
	table.insert(
		self.connections,
		Players.PlayerRemoving:Connect(function(player)
			self:DropUser(player.UserId)
			self.buckets[player] = nil
			self.strikes[player.UserId] = nil
		end)
	)
end

return ItemService
