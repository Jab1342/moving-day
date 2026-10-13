--!nonstrict
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local JobGen = require(Shared.Logic.JobGen)
local Rules = require(Shared.Logic.JobRules)
local HouseBuilder = require(script.Parent.HouseBuilder)
local JobService = {}
JobService.__index = JobService
local function now()
	return workspace:GetServerTimeNow()
end
local function inside(part, position)
	local p = part.CFrame:PointToObjectSpace(position)
	return math.abs(p.X) <= part.Size.X / 2
		and math.abs(p.Y) <= part.Size.Y / 2
		and math.abs(p.Z) <= part.Size.Z / 2
end
function JobService.new(crews, items, trucks, payouts, data, remotes, folder)
	return setmetatable({
		crews = crews,
		items = items,
		trucks = trucks,
		payouts = payouts,
		data = data,
		remotes = remotes,
		folder = folder,
		jobs = {},
		retryAt = {},
		elapsed = 0,
	}, JobService)
end
function JobService:Tier(crew)
	local level, first = math.huge, false
	for _, player in crew.members do
		local data = self.data:Get(player)
		if not data then
			return nil
		end
		level = math.min(level, data.level)
		first = first or not data.firstJobDone
	end
	if first then
		return "Starter", true
	end
	return if level >= Config.UnlockLevel.Big
		then "Big"
		elseif level >= Config.UnlockLevel.Family then "Family"
		else "Starter",
		false
end
function JobService:Push(job)
	local state = {
		jobId = job.id,
		crewId = job.crew.id,
		tier = job.tier,
		lotId = job.crew.padId,
		phase = job.phase,
		startedAt = job.startedAt,
		softEndsAt = job.startedAt + Config.SoftTimer[job.tier],
		manifest = table.clone(job.manifest),
	}
	for _, player in job.crew.members do
		if player.Parent == Players then
			self.remotes.Job.State:FireClient(player, state)
		end
	end
end
function JobService:StartJob(crew)
	if self.jobs[crew.id] then
		return self.jobs[crew.id].id
	end
	local tier, first = self:Tier(crew)
	if not tier then
		return nil
	end
	local map = workspace:FindFirstChild("Map")
	local lots = map and map:FindFirstChild("Lots")
	local pickup = lots and lots:FindFirstChild("PickupLot_" .. crew.padId)
	local destination = lots and lots:FindFirstChild("DestinationLot_" .. crew.padId)
	local zone = destination and destination:FindFirstChild("DeliveryZone")
	local hq = map and map:FindFirstChild("HQ")
	local docks = hq and hq:FindFirstChild("TruckDocks")
	local dock = docks and docks:FindFirstChild("TruckDock_" .. crew.padId)
	local truckSpawn = if first
		then pickup and pickup:FindFirstChild("Pad") and pickup.Pad:FindFirstChild("TruckSpot")
		else dock and dock:FindFirstChild("Spawn")
	if not pickup or not destination or not zone or not zone:IsA("BasePart") or not truckSpawn then
		return nil
	end
	local job = {
		id = HttpService:GenerateGUID(false),
		crew = crew,
		tier = tier,
		phase = "Loading",
		startedAt = now(),
		zone = zone,
		manifest = {},
		snapshots = {},
		order = {},
		assist = false,
	}
	for _, player in crew.members do
		job.assist = job.assist or player:GetAttribute("Assist") == true
	end
	self.jobs[crew.id] = job
	local ok, problem = pcall(function()
		local seed = (os.time() + crew.padId) % 2147483647
		local layout = JobGen.generate(seed, tier)
		local house, sockets = HouseBuilder.Build(layout, pickup, self.folder)
		job.house = house
		job.destinationHouse = HouseBuilder.Build(layout, destination, self.folder)
		local truck, why = self.trucks:Spawn(crew.id, truckSpawn.WorldCFrame)
		assert(truck, why or "TruckUnavailable")
		job.truck = truck
		for _, item in layout.items do
			local rec, errorReason = self.items:Spawn(
				item.itemId,
				crew.id,
				sockets[`{item.roomIndex}:{item.socketName}`]
			)
			assert(rec, errorReason or "ItemUnavailable")
			table.insert(job.order, rec.uid)
			job.manifest[rec.uid] = "Idle"
			job.snapshots[rec.uid] =
				{ def = rec.def, hp = Config.ItemMaxHP, state = "Idle", blame = 0 }
		end
		if first then
			local origin = pickup.Pad.HouseOrigin.WorldCFrame
			local front = house:GetAttribute("FrontDoor") or origin.Position
			for index, player in crew.members do
				if player.Character then
					local target = front
						+ origin.LookVector * Config.JobArrivalDoorOffset
						+ Vector3.new(
							(index - 1) * Config.JobArrivalSpacing,
							Config.JobArrivalHeight,
							0
						)
					player.Character:PivotTo(CFrame.new(target, target - origin.LookVector))
				end
			end
		end
	end)
	if not ok then
		warn("[MovingDay] Job setup failed: " .. tostring(problem))
		self:Cleanup(job, false, true)
		return nil
	end
	self:Push(job)
	return job.id
end
function JobService:Removed(rec, broken)
	local job = self.jobs[rec.crewId]
	if not job or job.closed or not job.snapshots[rec.uid] then
		return
	end
	local snap = job.snapshots[rec.uid]
	snap.state = if rec.state == "Delivered" then "Delivered" else "Broken"
	snap.hp = if broken then 0 else rec.model:GetAttribute("HP") or 0
	snap.blame = rec.model:GetAttribute("BlameUserId") or rec.lastCarrier or 0
	job.manifest[rec.uid] = snap.state
	job.dirty = true
end
function JobService:Cleanup(job, returnHQ, preserveCrew)
	if job.closed then
		return
	end
	job.closed = true
	self.jobs[job.crew.id] = nil
	for _, player in job.crew.members do
		self.items:DropUser(player.UserId)
	end
	for _, uid in job.order do
		local rec = self.items.records[uid]
		if rec then
			self.items:Remove(rec, false)
		end
	end
	self.trucks:Remove(job.crew.id)
	HouseBuilder.Clear(job.house)
	HouseBuilder.Clear(job.destinationHouse)
	if returnHQ then
		local map = workspace:FindFirstChild("Map")
		local hq = map and map:FindFirstChild("HQ")
		local garage = hq and hq:FindFirstChild("Garage")
		local counter = garage and garage:FindFirstChild("ShopCounter")
		if counter then
			for index, player in job.crew.members do
				if player.Character then
					player.Character:PivotTo(
						counter.CFrame
							* CFrame.new(
								(index - 1) * Config.JobArrivalSpacing,
								Config.JobArrivalHeight,
								Config.HQReturnOffset
							)
					)
				end
			end
		end
	end
	if not preserveCrew then
		self.crews:Disband(job.crew)
	end
end
function JobService:Step(dt)
	self.elapsed += dt
	if self.elapsed < Config.JobPollSeconds then
		return
	end
	self.elapsed = 0
	for _, player in Players:GetPlayers() do
		local profile = self.data:Get(player)
		local char = player.Character
		if
			profile
			and not profile.firstJobDone
			and char
			and char:FindFirstChild("HumanoidRootPart")
			and not self.crews:CrewOf(player)
			and now() >= (self.retryAt[player] or 0)
		then
			self.retryAt[player] = now() + Config.CrewLaunchRetrySeconds
			for padId = 1, Config.MaxCrews do
				if not self.crews.crews[padId] then
					if self.crews:Join(player, padId, true) then
						self.crews:Launch(self.crews:CrewOf(player))
					end
					break
				end
			end
		end
	end
	for _, job in self.jobs do
		if job.phase == "Payout" then
			self.payouts:Award(job)
			local pendingGrant = job.report == nil
			for _, player in job.crew.members do
				if
					job.report
					and job.report.shares[tostring(player.UserId)]
					and self.data:Get(player)
					and not job.awarded[player.UserId]
				then
					pendingGrant = true
				end
			end
			if not pendingGrant and now() >= job.returnAt then
				self:Cleanup(job, true, false)
			end
			continue
		end
		local changed = job.dirty == true
		job.dirty = false
		for _, player in job.crew.members do
			job.assist = job.assist or player:GetAttribute("Assist") == true
		end
		for _, uid in job.order do
			local rec, snap = self.items.records[uid], job.snapshots[uid]
			if rec then
				if
					Rules.deliverable(
						rec.state,
						rec.truck ~= nil,
						inside(job.zone, rec.root.Position)
					)
				then
					for _, id in { rec.a, rec.b } do
						if id ~= 0 then
							self.items:DropUser(id)
						end
					end
					self.items:SetState(rec, "Delivered")
					self.items:SetOwner(rec, nil, false)
					for _, part in rec.model:GetDescendants() do
						if part:IsA("BasePart") then
							part.Anchored = true
						end
					end
					self.items:Fire(rec, "Delivered")
				end
				snap.state, snap.hp = rec.state, rec.model:GetAttribute("HP") or 0
				snap.blame = rec.model:GetAttribute("BlameUserId") or 0
			end
			if job.manifest[uid] ~= snap.state then
				changed = true
				job.manifest[uid] = snap.state
			end
		end
		local phase =
			Rules.phase(job.phase, job.manifest, inside(job.zone, job.truck.root.Position))
		if phase ~= job.phase then
			job.phase = phase
			changed = true
			if phase == "Payout" then
				job.returnAt = now() + Config.PayoutDisplaySeconds
				self.payouts:Award(job)
			end
		end
		if changed then
			self:Push(job)
		end
	end
end
function JobService:Bind()
	self.crews.canJoin = function(player)
		return self.data:Get(player) ~= nil
	end
	self.crews:OnStart(function(crew)
		return self:StartJob(crew)
	end)
	self.crews.onMemberRemoved = function(player)
		self.items:DropUser(player.UserId)
	end
	self.crews.onEmpty = function(crew)
		local job = self.jobs[crew.id]
		if job then
			self:Cleanup(job, false, false)
		end
	end
	self.items.onRemoved = function(rec, broken)
		self:Removed(rec, broken)
	end
	Players.PlayerRemoving:Connect(function(player)
		self.retryAt[player] = nil
	end)
end
return JobService
