--!nonstrict
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local CargoRules = require(Shared.Logic.CargoRules)
local UpgradeRules = require(Shared.Logic.TruckUpgradeRules)
local TruckService = {}
TruckService.__index = TruckService

local function inside(bed, position)
	local p = bed.CFrame:PointToObjectSpace(position)
	return math.abs(p.X) <= bed.Size.X / 2
		and math.abs(p.Z) <= bed.Size.Z / 2
		and p.Y >= bed.Size.Y / 2
		and p.Y <= bed.Size.Y / 2 + Config.BedCargoHeight
end

function TruckService.new(folder, items)
	return setmetatable({ folder = folder, items = items, trucks = {} }, TruckService)
end

function TruckService:CanUseUpgrade(id)
	local templates = ServerStorage:FindFirstChild("Trucks")
	local pickup = templates and templates:FindFirstChild("TRK_Pickup")
	local box = templates and templates:FindFirstChild("TRK_Box")
	local function valid(model)
		local seat = model and model:FindFirstChild("DriverSeat", true)
		local bed = model and model:FindFirstChild("BedFloor", true)
		return model
			and model:IsA("Model")
			and model.PrimaryPart
			and seat
			and seat:IsA("VehicleSeat")
			and bed
			and bed:IsA("BasePart")
	end
	if id == "BoxTruck" then
		return valid(box) == true
	elseif id == "LoadingRamp" then
		local folder = ServerStorage:FindFirstChild("Upgrades")
		local ramp = folder and folder:FindFirstChild("LoadingRamp")
		local mount = pickup
			and pickup.PrimaryPart
			and pickup.PrimaryPart:FindFirstChild("RampMount")
		local boxMount = box and box.PrimaryPart and box.PrimaryPart:FindFirstChild("RampMount")
		return valid(pickup) == true
			and valid(box) == true
			and ramp ~= nil
			and ramp:IsA("Model")
			and ramp.PrimaryPart ~= nil
			and mount ~= nil
			and mount:IsA("Attachment")
			and boxMount ~= nil
			and boxMount:IsA("Attachment")
	elseif id == "SoftSuspension" then
		return valid(pickup) == true
			and valid(box) == true
			and pickup:FindFirstChildWhichIsA("SpringConstraint", true) ~= nil
			and box:FindFirstChildWhichIsA("SpringConstraint", true) ~= nil
	end
	return false
end

function TruckService:BreakRamp(truck)
	if not truck.ramp or truck.rampLoose then
		return
	end
	truck.rampLoose = true
	truck.model:SetAttribute("RampLoose", true)
	if truck.rampWeld then
		truck.rampWeld:Destroy()
		truck.rampWeld = nil
	end
	for part, collision in truck.rampCollisions do
		if part.Parent then
			part.CanCollide = collision
		end
	end
	if truck.tailgate then
		truck.tailgate.CanCollide = truck.tailgateCollision
	end
	if truck.rampRoot.Parent and truck.rampRoot:CanSetNetworkOwnership() then
		truck.rampRoot:SetNetworkOwner(nil)
	end
end

function TruckService:RampPitch(truck, mount)
	local filter = { self.folder }
	if self.items.folder then
		table.insert(filter, self.items.folder)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter
	params.IgnoreWater = true
	local angle = 0
	for _ = 1, 2 do
		local foot = (mount * CFrame.Angles(angle, 0, 0)):PointToWorldSpace(truck.rampFoot)
		local hit = workspace:Raycast(
			foot + Vector3.new(0, Config.RampProbeHeight, 0),
			Vector3.new(0, -Config.RampProbeDepth, 0),
			params
		)
		if not hit or hit.Normal.Y < Config.RampMinGroundNormalY then
			return nil
		end
		angle = UpgradeRules.rampPitch(
			truck.rampFoot.Y,
			truck.rampFoot.Z,
			mount.UpVector.Y,
			-mount.LookVector.Y,
			mount.Position.Y - hit.Position.Y
		)
		if not angle then
			return nil
		end
	end
	return angle
end

function TruckService:UpdateRamp(truck, force)
	if not truck.ramp or truck.rampLoose then
		return
	end
	if not truck.ramp.Parent or not truck.rampRoot.Parent then
		self:BreakRamp(truck)
		return
	end
	local stow = truck.seat.Occupant ~= nil
		or truck.bed.AssemblyLinearVelocity.Magnitude > Config.RampDeployMaxSpeed
	local now = os.clock()
	if not force and truck.rampRequestedStow == stow and (stow or now < truck.rampNextUpdate) then
		return
	end
	truck.rampRequestedStow = stow
	truck.rampNextUpdate = now + Config.RampGroundRefreshSeconds
	local mount = truck.rampMount.WorldCFrame
	local angle = if stow then nil else self:RampPitch(truck, mount)
	truck.rampStowed = stow or angle == nil
	-- Detach the hinge before moving its model, so PivotTo cannot move the truck assembly.
	if truck.rampWeld then
		truck.rampWeld:Destroy()
		truck.rampWeld = nil
	end
	for part in truck.rampCollisions do
		part.CanCollide = false
	end
	truck.ramp:PivotTo(
		mount
			* CFrame.Angles(
				if truck.rampStowed then math.rad(Config.RampStowPitchDegrees) else angle,
				0,
				0
			)
	)
	local weld = Instance.new("WeldConstraint")
	weld.Name, weld.Part0, weld.Part1 = "LoadingRampWeld", truck.root, truck.rampRoot
	weld.Parent = truck.rampRoot
	truck.rampWeld = weld
	for part, collision in truck.rampCollisions do
		part.CanCollide = collision and not truck.rampStowed
	end
	if truck.tailgate then
		truck.tailgate.CanCollide = if truck.rampStowed then truck.tailgateCollision else false
	end
end

function TruckService:InstallUpgrades(truck, options)
	truck.model:SetAttribute("MD_MaxSpeed", options.maxSpeed)
	truck.model:SetAttribute("MD_MaxSteerAngle", options.maxSteer)
	truck.model:SetAttribute("MD_HighSpeedSteerAngle", options.highSpeedSteer)
	truck.model:SetAttribute("RampLoose", false)
	truck.cargoScale = options.cargoScale
	for _, instance in truck.model:GetDescendants() do
		if instance:IsA("SpringConstraint") then
			instance.Stiffness *= options.stiffnessScale
			instance.Damping *= options.dampingScale
		end
	end
	if not options.ramp then
		return
	end
	local folder = ServerStorage:FindFirstChild("Upgrades")
	local template = folder and folder:FindFirstChild("LoadingRamp")
	local mount = truck.root:FindFirstChild("RampMount")
	assert(
		template and template.PrimaryPart and mount and mount:IsA("Attachment"),
		"Missing loading ramp geometry"
	)
	local ramp = template:Clone()
	ramp.Name = "LoadingRamp"
	truck.ramp, truck.rampRoot, truck.rampMount = ramp, ramp.PrimaryPart, mount
	truck.rampCollisions = {}
	for _, part in ramp:GetDescendants() do
		if part:IsA("BasePart") then
			truck.rampCollisions[part] = part.CanCollide
			part.Anchored = false
		end
	end
	truck.rampFoot = ramp:GetPivot():PointToObjectSpace(
		truck.rampRoot.CFrame:PointToWorldSpace(
			Vector3.new(0, -truck.rampRoot.Size.Y / 2, truck.rampRoot.Size.Z / 2)
		)
	)
	truck.tailgate = truck.model:FindFirstChild("Tailgate", true)
	truck.tailgateCollision = truck.tailgate and truck.tailgate.CanCollide
	ramp.Parent = truck.model
	self:UpdateRamp(truck, true)
end

function TruckService:Ownership(truck, player)
	local roots = {}
	for _, part in truck.model:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored then
			roots[part.AssemblyRootPart or part] = true
		end
	end
	for root in roots do
		if root:CanSetNetworkOwnership() then
			if player then
				root:SetNetworkOwner(player)
			else
				root:SetNetworkOwnershipAuto()
			end
		end
	end
	for _, rec in self.items.records do
		if rec.truck == truck then
			self.items:SetOwner(rec, player, false)
		end
	end
end

function TruckService:UpdateDriver(truck)
	local humanoid = truck.seat.Occupant
	local player = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
	if player and player:GetAttribute("CrewId") ~= truck.crewId then
		humanoid.Sit = false
		player = nil
	end
	truck.driverId = if player then player.UserId else 0
	truck.model:SetAttribute("DriverUserId", truck.driverId)
	self:UpdateRamp(truck)
	self:Ownership(truck, player)
end

function TruckService:Spawn(crewId, cframe, upgrades)
	if self.trucks[crewId] then
		return nil, "TruckExists"
	end
	local templates = ServerStorage:FindFirstChild("Trucks")
	local options = UpgradeRules.options(upgrades)
	local template = templates and templates:FindFirstChild(options.template)
	if not template then
		return nil, "MissingTruckTemplate"
	end
	local model = template:Clone()
	local root = model.PrimaryPart
	local seat = model:FindFirstChild("DriverSeat", true)
	local bed = model:FindFirstChild("BedFloor", true)
	if
		not root
		or not seat
		or not seat:IsA("VehicleSeat")
		or not bed
		or not bed:IsA("BasePart")
	then
		model:Destroy()
		return nil, "InvalidTruckTemplate"
	end
	model:SetAttribute("CrewId", crewId)
	model:SetAttribute("DriverUserId", 0)
	model:PivotTo(cframe)
	model.Parent = self.folder
	CollectionService:AddTag(bed, "TruckBed")
	local props = bed.CurrentPhysicalProperties
	bed.CustomPhysicalProperties = PhysicalProperties.new(
		props.Density,
		Config.BedFriction,
		props.Elasticity,
		props.FrictionWeight,
		props.ElasticityWeight
	)
	local truck = {
		model = model,
		root = root,
		seat = seat,
		bed = bed,
		crewId = crewId,
		driverId = 0,
		pendingStraps = 0,
		previousVelocity = bed.AssemblyLinearVelocity,
		strapSlots = Config.BaseStrapSlots,
	}
	self.trucks[crewId] = truck
	local installed, problem = pcall(function()
		self:InstallUpgrades(truck, options)
	end)
	if not installed then
		self.trucks[crewId] = nil
		model:Destroy()
		return nil, "UpgradeGeometryUnavailable: " .. tostring(problem)
	end
	truck.occupantConnection = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		self:UpdateDriver(truck)
	end)
	self:UpdateDriver(truck)
	return truck
end

function TruckService:ReserveStrap(truck)
	local used = truck.pendingStraps
	for _, rec in self.items.records do
		if rec.truck == truck and rec.model:GetAttribute("Strapped") then
			used += 1
		end
	end
	local slots = if self.strapSlotsForCrew
		then self.strapSlotsForCrew(truck.crewId)
		else truck.strapSlots
	if used >= slots then
		return false
	end
	truck.pendingStraps += 1
	return true
end

function TruckService:Unweld(rec)
	local hadWeld = rec.weld ~= nil
	if rec.weld then
		rec.weld:Destroy()
		rec.weld = nil
	end
	rec.settledFor = 0
	rec.reweldAfter = os.clock() + Config.BedReweldDelaySeconds
	local player = rec.truck and Players:GetPlayerByUserId(rec.truck.driverId)
	if hadWeld then
		self.items:SetOwner(rec, player, false)
	end
end

function TruckService:Release(rec)
	self:Unweld(rec)
	rec.truck = nil
	rec.pendingStrap = nil
	rec.model:SetAttribute("Strapped", false)
	self.items:SetState(rec, "Idle")
	self.items:SetOwner(rec, nil, false)
	self.items:Grace(rec, Config.DropGraceSeconds)
end

function TruckService:Step(dt)
	for crewId, truck in self.trucks do
		if not truck.model.Parent then
			self:Remove(crewId)
			continue
		end
		local driver = Players:GetPlayerByUserId(truck.driverId)
		if driver and driver:GetAttribute("CrewId") ~= crewId then
			self:UpdateDriver(truck)
		end
		local velocity = truck.bed.AssemblyLinearVelocity
		if driver and self.analytics and velocity.Magnitude >= Config.AnalyticsDriveMinSpeed then
			self.analytics:Funnel(driver, 4)
		end
		local acceleration = if dt > 0
			then (velocity - truck.previousVelocity) / dt
			else Vector3.zero
		truck.filteredAcceleration = CargoRules.smooth(
			truck.filteredAcceleration or Vector3.zero,
			acceleration,
			dt,
			Config.BedAccelerationFilterSeconds
		)
		truck.acceleration =
			CargoRules.accelerationG(truck.filteredAcceleration.Magnitude, 1, workspace.Gravity)
		truck.previousVelocity = velocity
		truck.tilt =
			math.deg(math.acos(math.clamp(truck.bed.CFrame.UpVector:Dot(Vector3.yAxis), -1, 1)))
		if truck.ramp and truck.acceleration > Config.RampLooseG then
			self:BreakRamp(truck)
		else
			self:UpdateRamp(truck)
		end
	end
	for _, rec in self.items.records do
		if rec.a ~= 0 or rec.state == "Broken" or rec.state == "Delivered" then
			continue
		end
		local truck = rec.truck or self.trucks[rec.crewId]
		if not truck then
			continue
		end
		if not inside(truck.bed, rec.root.Position) then
			if rec.truck then
				self:Release(rec)
			end
			continue
		end
		if not rec.truck then
			rec.truck = truck
			self.items:SetState(rec, "InTruck")
			self.items:SetOwner(rec, Players:GetPlayerByUserId(truck.driverId), false)
			self.items:Grace(rec)
			self.items:Fire(rec, "Loaded")
		end
		local breaks = CargoRules.shouldBreak(
			(truck.acceleration or 0) * (truck.cargoScale or 1),
			truck.tilt or 0,
			rec.model:GetAttribute("Strapped"),
			Config
		)
		if breaks then
			self:Unweld(rec)
		elseif not rec.weld and os.clock() >= (rec.reweldAfter or 0) then
			local relative = rec.root.AssemblyLinearVelocity
				- truck.bed:GetVelocityAtPosition(rec.root.Position)
			rec.settledFor = if relative.Magnitude <= Config.BedRelativeSpeedThreshold
				then rec.settledFor + dt
				else 0
			if rec.settledFor >= Config.BedSettleSeconds then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "CargoBedWeld"
				weld.Part0 = truck.bed
				weld.Part1 = rec.root
				weld.Parent = rec.root
				rec.weld = weld
				self:Ownership(truck, Players:GetPlayerByUserId(truck.driverId))
			end
		end
	end
end

function TruckService:Remove(crewId)
	local truck = self.trucks[crewId]
	if not truck then
		return
	end
	for _, rec in self.items.records do
		if rec.truck == truck then
			self:Release(rec)
		end
	end
	truck.occupantConnection:Disconnect()
	self.trucks[crewId] = nil
	truck.model:Destroy()
end

return TruckService
