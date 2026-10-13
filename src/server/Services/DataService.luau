--!nonstrict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Schema = require(Shared.Logic.ProfileSchema)
local RateLimit = require(Shared.Logic.RateLimit)
local DataService = {}
DataService.__index = DataService

function DataService.new(remotes, library)
	local store = library.New(Config.ProfileStoreName, Schema.new())
	local mock = RunService:IsStudio() and Config.ProfileStudioMock
	if mock then
		store = store.Mock
	end
	return setmetatable({
		remotes = remotes,
		library = library,
		store = store,
		mock = mock,
		profiles = {},
		loading = {},
		ending = {},
		settingsBuckets = {},
		closing = false,
	}, DataService)
end

function DataService:Get(player)
	local profile = self.profiles[player]
	if profile and profile:IsActive() then
		return profile.Data
	end
	return nil
end

function DataService:Publish(player)
	local data = self:Get(player)
	if not data or player.Parent ~= Players then
		return
	end
	player:SetAttribute("Level", data.level)
	player:SetAttribute("Assist", data.settings.assist)
	self.remotes.Data.Profile:FireClient(player, Schema.public(data))
	if self.onProfilePublished then
		self.onProfilePublished(player)
	end
end

-- Server-only atomic application mutation. A callback must not yield, perform side
-- effects, or grant products. Rejected mutations cannot partially change the profile.
function DataService:Update(player, transform)
	local profile = self.profiles[player]
	if not profile or not profile:IsActive() or self.closing then
		return false, "NotReady"
	end
	local draft = Schema.copy(profile.Data)
	local thread = coroutine.create(function()
		return transform(draft)
	end)
	local ran, accepted, reason = coroutine.resume(thread)
	if coroutine.status(thread) ~= "dead" then
		coroutine.close(thread)
		return false, "YieldNotAllowed"
	end
	if not ran then
		return false, "MutationFailed"
	end
	if accepted == false then
		return false, reason or "Rejected"
	end
	local validated, problem = Schema.prepare(draft)
	if not validated then
		return false, problem
	end
	if self.profiles[player] ~= profile or not profile:IsActive() then
		return false, "SessionEnded"
	end
	profile.Data = validated
	self:Publish(player)
	return true
end

function DataService:Load(player)
	if self.loading[player] or self.profiles[player] or self.closing then
		return
	end
	self.loading[player] = true
	self.ending[player] = nil
	local ok, profile = pcall(function()
		return self.store:StartSessionAsync("u_" .. player.UserId, {
			Cancel = function()
				return self.closing or player.Parent ~= Players or self.ending[player] == true
			end,
		})
	end)
	self.loading[player] = nil
	if not ok or not profile then
		self.ending[player] = nil
		if player.Parent == Players and not self.closing then
			player:Kick("Your save could not load. Please rejoin.")
		end
		return
	end
	if player.Parent ~= Players or self.closing or self.ending[player] then
		profile:EndSession()
		self.ending[player] = nil
		return
	end
	-- ProfileStore can simulate saves without API access. Never present that as a
	-- persistent live profile; Studio mocks are an explicit developer-only choice.
	if not self.mock and self.library.DataStoreState ~= "Access" then
		profile:EndSession()
		player:Kick("Saving is unavailable. Please try again shortly.")
		return
	end
	local data, problem = Schema.prepare(profile.Data)
	if not data then
		profile:EndSession()
		warn("[MovingDay] Profile validation failed: " .. problem)
		player:Kick("Your save needs attention. Please try again later.")
		return
	end
	if player.UserId > 0 then
		profile:AddUserId(player.UserId)
	end
	profile.Data = data
	profile.OnSessionEnd:Connect(function()
		local owned = self.profiles[player] == profile
		if owned then
			self.profiles[player] = nil
		end
		if owned and player.Parent == Players and not self.ending[player] and not self.closing then
			player:Kick("Your save session ended. Please rejoin.")
		end
	end)
	if not profile:IsActive() then
		player:Kick("Your save session ended. Please rejoin.")
		return
	end
	self.profiles[player] = profile
	self:Publish(player)
	-- Existing contracts have no client-ready handshake. Repeat after client startup.
	task.delay(Config.ProfileInitialResendSeconds, function()
		if self.profiles[player] == profile then
			self:Publish(player)
		end
	end)
end

-- The sole permitted receipt yield: wait for durable profile receipt + reward.
-- Never treat Save() returning (it schedules a save) as confirmation.
function DataService:SaveReceipt(player, purchaseId)
	local profile = self.profiles[player]
	if not profile or not profile.Data.purchases[purchaseId] then
		return false
	end
	local function saved()
		local snapshot = profile.LastSavedData
		return snapshot ~= nil
			and snapshot.purchases ~= nil
			and snapshot.purchases[purchaseId] == true
	end
	if saved() then
		return true
	end
	if not profile:IsActive() then
		return false
	end
	local ok = pcall(function()
		profile:Save()
	end)
	if not ok then
		return false
	end
	local deadline = os.clock() + Config.ReceiptSaveTimeoutSeconds
	repeat
		if saved() then
			return true
		end
		if self.profiles[player] ~= profile or not profile:IsActive() or os.clock() >= deadline then
			return false
		end
		task.wait(Config.ReceiptSavePollSeconds)
	until false
end

function DataService:Release(player)
	self.ending[player] = true
	local profile = self.profiles[player]
	self.profiles[player] = nil
	self.settingsBuckets[player] = nil
	if profile then
		profile:EndSession()
	end
	if not self.loading[player] then
		self.ending[player] = nil
	end
end

function DataService:SetSetting(player, key, value)
	local allowed, bucket = RateLimit.consume(
		self.settingsBuckets[player],
		os.clock(),
		Config.RemotePerSecond,
		Config.RemoteBurst
	)
	self.settingsBuckets[player] = bucket
	if not allowed then
		return
	end
	if key ~= "assist" or type(value) ~= "boolean" then
		return
	end
	self:Update(player, function(data)
		data.settings.assist = value
	end)
end

function DataService:Start()
	self.remotes.Settings.Set.OnServerEvent:Connect(function(player, key, value)
		self:SetSetting(player, key, value)
	end)
	local function added(player)
		player.CharacterAdded:Connect(function()
			task.delay(Config.ProfileInitialResendSeconds, function()
				self:Publish(player)
			end)
		end)
		task.spawn(function()
			self:Load(player)
		end)
	end
	Players.PlayerAdded:Connect(added)
	Players.PlayerRemoving:Connect(function(player)
		self:Release(player)
	end)
	for _, player in Players:GetPlayers() do
		added(player)
	end
	game:BindToClose(function()
		self.closing = true
		for player in self.profiles do
			self:Release(player)
		end
	end)
	if self.mock then
		warn("[MovingDay] Studio profile mock enabled; saves will not survive Studio restart")
	end
end

return DataService
