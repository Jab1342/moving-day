--!nonstrict
-- Codex-owned integration, informed by ClaudeA's reviewed pad/crew proposal.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Rate = require(Shared.Logic.RateLimit)
local CrewService = {}
CrewService.__index = CrewService
local function now()
	return workspace:GetServerTimeNow()
end
local function padPart(padId)
	local map = workspace:FindFirstChild("Map")
	local hq = map and map:FindFirstChild("HQ")
	local pads = hq and hq:FindFirstChild("CrewPads")
	local pad = pads and pads:FindFirstChild("CrewPad_" .. padId)
	return if pad and pad:IsA("BasePart") then pad else nil
end
local function rootOf(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return if hum and hum.Health > 0 and root and root:IsA("BasePart") then root else nil
end
local function partyId(player)
	local ok, value = pcall(function()
		return player.PartyId
	end)
	return if ok and type(value) == "string" then value else ""
end
function CrewService.new(remotes)
	return setmetatable(
		{ remotes = remotes, crews = {}, byPlayer = {}, buckets = {}, elapsed = 0 },
		CrewService
	)
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
		leaderUserId = ids[1],
		memberUserIds = ids,
		autoStartsAt = crew.autoStartsAt,
		jobId = crew.jobId,
	}
end
function CrewService:Push(crew)
	local state = self:StateFor(crew)
	for _, p in crew.members do
		if p.Parent == Players then
			self.remotes.Crew.State:FireClient(p, state)
		end
	end
end
function CrewService:Retime(crew)
	if crew.jobId or crew.starting then
		crew.autoStartsAt = nil
	elseif #crew.members == 1 then
		crew.autoStartsAt = now() + Config.CrewSoloStartSeconds
	elseif #crew.members > 1 and (not crew.autoStartsAt or crew.solo) then
		crew.autoStartsAt = now() + Config.CrewAutoStartSeconds
	end
	crew.solo = #crew.members == 1
end
function CrewService:Add(crew, player)
	if self.byPlayer[player] or #crew.members >= Config.MaxCrewSize or player.Parent ~= Players then
		return false
	end
	if self.canJoin and not self.canJoin(player) then
		return false
	end
	table.insert(crew.members, player)
	self.byPlayer[player] = crew
	player:SetAttribute("CrewId", crew.id)
	return true
end
function CrewService:Join(player, padId, firstSession)
	if type(padId) ~= "number" or padId % 1 ~= 0 or padId < 1 or padId > Config.MaxCrews then
		return false, "BadPad"
	end
	if self.byPlayer[player] then
		return false, "AlreadyInCrew"
	end
	local root, pad = rootOf(player), padPart(padId)
	if not root or not pad then
		return false, "NoPad"
	end
	if
		not firstSession and not ((root.Position - pad.Position).Magnitude <= Config.CrewPadRange)
	then
		return false, "OutOfRange"
	end
	local crew = self.crews[padId]
	if crew and (crew.jobId or crew.starting) then
		return false, "OnJob"
	end
	local fresh = crew == nil
	if fresh then
		crew = { id = HttpService:GenerateGUID(false), padId = padId, members = {} }
	end
	if not self:Add(crew, player) then
		return false, "FullOrNotReady"
	end
	self.crews[padId] = crew -- retained through the job: at most four crews can exist
	local party = partyId(player)
	if party ~= "" then
		for _, other in Players:GetPlayers() do
			if other ~= player and partyId(other) == party and rootOf(other) then
				if self:Add(crew, other) then
					other.Character:PivotTo(
						pad.CFrame
							* CFrame.new(
								(#crew.members - 1) * Config.CrewPadMemberSpacing,
								Config.CrewPadSpawnHeight,
								0
							)
					)
				end
			end
		end
	end
	self:Retime(crew)
	self:Push(crew)
	return true
end
function CrewService:Remove(player)
	local crew = self.byPlayer[player]
	if not crew then
		return
	end
	if self.onMemberRemoved then
		self.onMemberRemoved(player, crew)
	end
	local index = table.find(crew.members, player)
	if index then
		table.remove(crew.members, index)
	end
	self.byPlayer[player] = nil
	if player.Parent == Players then
		player:SetAttribute("CrewId", nil)
		self.remotes.Crew.State:FireClient(player, self:StateFor(nil))
	end
	if #crew.members == 0 then
		if self.onEmpty then
			self.onEmpty(crew)
		end
		if self.crews[crew.padId] == crew then
			self.crews[crew.padId] = nil
		end
	else
		self:Retime(crew)
		self:Push(crew)
	end
end
function CrewService:Launch(crew)
	if crew.jobId or crew.starting then
		return false, "OnJob"
	end
	if #crew.members == 0 then
		return false, "EmptyCrew"
	end
	if not self.onStart then
		crew.autoStartsAt = now() + Config.CrewLaunchRetrySeconds
		return false, "NotReady"
	end
	crew.starting = true
	crew.autoStartsAt = nil
	self:Push(crew)
	local ok, jobId = pcall(self.onStart, crew)
	crew.starting = nil
	if self.crews[crew.padId] ~= crew or #crew.members == 0 then
		return false, "CrewEnded"
	end
	if not ok or type(jobId) ~= "string" or jobId == "" then
		crew.autoStartsAt = now() + Config.CrewLaunchRetrySeconds
		self:Push(crew)
		return false, "JobUnavailable"
	end
	crew.jobId = jobId
	self:Push(crew)
	return true
end
function CrewService:OnStart(callback)
	self.onStart = callback
end
function CrewService:SetJob(crew, jobId)
	crew.jobId = jobId
	self:Push(crew)
end
function CrewService:Disband(crew)
	for _, p in table.clone(crew.members) do
		self:Remove(p)
	end
end
function CrewService:CrewOf(player)
	return self.byPlayer[player]
end
function CrewService:Action(player, action, arg)
	local allowed, bucket =
		Rate.consume(self.buckets[player], os.clock(), Config.RemotePerSecond, Config.RemoteBurst)
	self.buckets[player] = bucket
	if not allowed then
		return false, "RateLimited"
	end
	if action == "Join" then
		return self:Join(player, arg)
	end
	local crew = self.byPlayer[player]
	if not crew then
		return false, "NotInCrew"
	end
	if crew.starting then
		return false, "Starting"
	end
	if action == "Leave" then
		if crew.jobId then
			return false, "OnJob"
		end
		self:Remove(player)
		return true
	end
	if crew.members[1] ~= player then
		return false, "NotLeader"
	end
	if action == "Start" then
		return self:Launch(crew)
	end
	if action == "Kick" then
		local target = if type(arg) == "number" and arg % 1 == 0
			then Players:GetPlayerByUserId(arg)
			else nil
		if not target or target == player or self.byPlayer[target] ~= crew then
			return false, "BadTarget"
		end
		self:Remove(target)
		return true
	end
	return false, "BadAction"
end
function CrewService:Step(dt)
	self.elapsed += dt
	if self.elapsed < Config.CrewPollSeconds then
		return
	end
	self.elapsed = 0
	for player, crew in self.byPlayer do
		if not crew.jobId and not crew.starting then
			local root, pad = rootOf(player), padPart(crew.padId)
			if
				root
				and pad
				and not ((root.Position - pad.Position).Magnitude <= Config.CrewPadExitRange)
			then
				self:Remove(player)
			end
		end
	end
	for _, crew in self.crews do
		if
			not crew.jobId
			and not crew.starting
			and crew.autoStartsAt
			and now() >= crew.autoStartsAt
		then
			self:Launch(crew)
		end
	end
end
function CrewService:Bind()
	self.remotes.Crew.Action.OnServerInvoke = function(p, action, arg)
		return self:Action(p, action, arg)
	end
	Players.PlayerRemoving:Connect(function(player)
		self.buckets[player] = nil
		self:Remove(player)
	end)
end
return CrewService
