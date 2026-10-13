--!nonstrict
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local CargoRules = require(Shared.Logic.CargoRules)
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
	self:Ownership(truck, player)
end

function TruckService:Spawn(crewId, cframe)
	if self.trucks[crewId] then
		return nil, "TruckExists"
	end
	local templates = ServerStorage:FindFirstChild("Trucks")
	local template = templates and templates:FindFirstChild("TRK_Pickup")
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
	self.items:SetOwner(rec, nil, true)
	self.items:Grace(rec)
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
		truck.acceleration = CargoRules.accelerationG(
			(velocity - truck.previousVelocity).Magnitude,
			dt,
			workspace.Gravity
		)
		truck.previousVelocity = velocity
		truck.tilt =
			math.deg(math.acos(math.clamp(truck.bed.CFrame.UpVector:Dot(Vector3.yAxis), -1, 1)))
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
			truck.acceleration or 0,
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
