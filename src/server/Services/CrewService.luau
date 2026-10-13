--!nonstrict
-- Crews form on the four HQ crew pads. Standing on a pad (Crew.Action "Join", padId) puts
-- you and any Roblox party members in the server on that crew; the first member leads.
-- Solo crews start after a short beat; a second member starts the CrewAutoStartSeconds timer;
-- the leader can Start early or Kick. The job layer listens via OnStart(callback).

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local SOLO_START_SECONDS = 5
local PAD_RANGE = 12

local CrewService = {}
CrewService.__index = CrewService

function CrewService.new(remotes: Folder)
	local self = setmetatable({}, CrewService)
	self.remotes = remotes
	self.crews = {} -- padId -> crew
	self.byPlayer = {} -- Player -> crew
	self.startCallbacks = {}
	return self
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function padPart(padId: number): BasePart?
	local map = workspace:FindFirstChild("Map")
	local hq = map and map:FindFirstChild("HQ")
	local pads = hq and hq:FindFirstChild("CrewPads")
	local pad = pads and pads:FindFirstChild("CrewPad_" .. padId)
	return if pad and pad:IsA("BasePart") then pad else nil
end

function CrewService:StateFor(crew)
	if not crew then
		return { memberUserIds = {} }
	end
	local ids = {}
	for _, p in crew.members do
		table.insert(ids, p.UserId)
	end
	return {
		crewId = crew.id,
		padId = crew.padId,
		leaderUserId = crew.members[1] and crew.members[1].UserId or nil,
		memberUserIds = ids,
		autoStartsAt = crew.autoStartsAt,
		jobId = crew.jobId,
	}
end

function CrewService:Push(crew)
	local event = self.remotes.Crew.State
	local state = self:StateFor(crew)
	for _, p in crew.members do
		event:FireClient(p, state)
	end
end

function CrewService:Retime(crew)
	if crew.jobId then
		crew.autoStartsAt = nil
	elseif #crew.members == 1 then
		crew.autoStartsAt = now() + SOLO_START_SECONDS
	elseif #crew.members > 1 then
		-- the timer starts when the second member arrives and isn't reset by later joins
		if not crew.autoStartsAt or crew.solo then
			crew.autoStartsAt = now() + Config.CrewAutoStartSeconds
		end
	end
	crew.solo = #crew.members == 1
end

function CrewService:Add(crew, player: Player): boolean
	if self.byPlayer[player] or #crew.members >= Config.MaxCrewSize then
		return false
	end
	table.insert(crew.members, player)
	self.byPlayer[player] = crew
	player:SetAttribute("CrewId", crew.id)
	return true
end

function CrewService:Join(player: Player, padId: any): (boolean, string?)
	if type(padId) ~= "number" or padId % 1 ~= 0 or padId < 1 or padId > Config.MaxCrews then
		return false, "BadPad"
	end
	if self.byPlayer[player] then
		return false, "AlreadyInCrew"
	end
	local pad = padPart(padId)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not pad or not root then
		return false, "NoPad"
	end
	local flat = Vector3.new(pad.Position.X - root.Position.X, 0, pad.Position.Z - root.Position.Z)
	if flat.Magnitude > PAD_RANGE then
		return false, "OutOfRange"
	end
	local crew = self.crews[padId]
	if crew and crew.jobId then
		return false, "OnJob"
	end
	if not crew then
		crew = { id = "crew-" .. padId .. "-" .. math.floor(now()), padId = padId, members = {} }
		self.crews[padId] = crew
	end
	if not self:Add(crew, player) then
		return false, "Full"
	end
	-- bring the player's Roblox party along
	if player.PartyId ~= "" then
		for _, other in Players:GetPlayers() do
			if other ~= player and other.PartyId == player.PartyId and not self.byPlayer[other] then
				self:Add(crew, other)
			end
		end
	end
	self:Retime(crew)
	self:Push(crew)
	return true, nil
end

function CrewService:Remove(player: Player)
	local crew = self.byPlayer[player]
	if not crew then
		return
	end
	local index = table.find(crew.members, player)
	if index then
		table.remove(crew.members, index)
	end
	self.byPlayer[player] = nil
	if player.Parent then
		player:SetAttribute("CrewId", nil)
		self.remotes.Crew.State:FireClient(player, self:StateFor(nil))
	end
	if #crew.members == 0 then
		if self.crews[crew.padId] == crew then
			self.crews[crew.padId] = nil
		end
		return
	end
	self:Retime(crew)
	self:Push(crew)
end

function CrewService:Launch(crew)
	if crew.jobId or #crew.members == 0 then
		return
	end
	crew.autoStartsAt = nil
	crew.jobId = "pending"
	-- the pad frees up for the next crew while this one is out on the job
	if self.crews[crew.padId] == crew then
		self.crews[crew.padId] = nil
	end
	self:Push(crew)
	for _, callback in self.startCallbacks do
		task.spawn(callback, crew)
	end
end

-- Job layer API ------------------------------------------------------------------------

function CrewService:OnStart(callback)
	table.insert(self.startCallbacks, callback)
end

function CrewService:SetJob(crew, jobId: string?)
	crew.jobId = jobId
	self:Push(crew)
end

-- Job over: the crew disbands back at HQ so players can regroup on any pad.
function CrewService:Disband(crew)
	for _, p in table.clone(crew.members) do
		self.byPlayer[p] = nil
		if p.Parent then
			p:SetAttribute("CrewId", nil)
			self.remotes.Crew.State:FireClient(p, self:StateFor(nil))
		end
	end
	crew.members = {}
end

function CrewService:CrewOf(player: Player)
	return self.byPlayer[player]
end

----------------------------------------------------------------------------------------

function CrewService:Action(player: Player, action: any, arg: any): (boolean, string?)
	if action == "Join" then
		return self:Join(player, arg)
	end
	local crew = self.byPlayer[player]
	if not crew then
		return false, "NotInCrew"
	end
	if action == "Leave" then
		if crew.jobId then
			return false, "OnJob"
		end
		self:Remove(player)
		return true, nil
	end
	if crew.members[1] ~= player then
		return false, "NotLeader"
	end
	if action == "Start" then
		self:Launch(crew)
		return true, nil
	elseif action == "Kick" then
		local target = if type(arg) == "number" then Players:GetPlayerByUserId(arg) else nil
		if not target or target == player or self.byPlayer[target] ~= crew then
			return false, "BadTarget"
		end
		self:Remove(target)
		return true, nil
	end
	return false, "BadAction"
end

function CrewService:Step()
	local t = now()
	for _, crew in self.crews do
		if not crew.jobId and crew.autoStartsAt and t >= crew.autoStartsAt then
			self:Launch(crew)
		end
	end
	-- walking off your pad before the start leaves the crew
	for player, crew in self.byPlayer do
		if not crew.jobId then
			local pad = padPart(crew.padId)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if pad and root then
				local flat = Vector3.new(
					pad.Position.X - root.Position.X,
					0,
					pad.Position.Z - root.Position.Z
				)
				if flat.Magnitude > PAD_RANGE * 1.5 then
					self:Remove(player)
				end
			end
		end
	end
end

-- Wire the Crew.Action remote and player cleanup. Call once, then Step() every Heartbeat.
function CrewService:Bind()
	local action = self.remotes.Crew.Action
	action.OnServerInvoke = function(player, a, arg)
		return self:Action(player, a, arg)
	end
	Players.PlayerRemoving:Connect(function(player)
		self:Remove(player)
	end)
end

return CrewService
