--!nonstrict
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ProductIds = require(Shared.ProductIds)
local Config = require(Shared.Config)
local Rules = require(Shared.Logic.ReceiptRules)
local Purchases = require(Shared.Logic.PurchaseRules)
local RateLimit = require(Shared.Logic.RateLimit)
local MonetizationService = {}
MonetizationService.__index = MonetizationService
function MonetizationService.new(data, ids, marketplace, remotes)
	return setmetatable({
		data = data,
		ids = ids or ProductIds,
		marketplace = marketplace or MarketplaceService,
		inFlight = {},
		remotes = remotes,
		states = {},
		firstGrab = {},
		pending = {},
		promptedJobs = {},
		buckets = {},
	}, MonetizationService)
end
function MonetizationService:Publish(player, force)
	if not self.remotes or player.Parent ~= Players then
		return
	end
	local state = self.states[player]
	local ready = state ~= nil and state.ready == true and self.data:Get(player) ~= nil
	if not force and state and state.publishedReady == ready then
		return
	end
	local passes, available = {}, {}
	for _, sku in Purchases.passes do
		passes[sku] = state ~= nil and state.passes[sku] == true
	end
	for _, list in { Purchases.passes, Purchases.products } do
		for _, sku in list do
			available[sku] = ready
				and Purchases.implemented(sku)
				and Purchases.idFor(self.ids, sku) ~= nil
		end
	end
	self.remotes.Monetization.State:FireClient(
		player,
		{ ready = ready, passes = passes, available = available }
	)
	if state then
		state.publishedReady = ready
	end
end
function MonetizationService:Refresh(player, force)
	if player.Parent ~= Players then
		return
	end
	local state = self.states[player]
	if not state then
		state = { passes = {}, ready = false, nextCheck = 0 }
		self.states[player] = state
	end
	if state.loading then
		if force then
			state.refreshAgain = true
		end
		return
	end
	if not force and os.clock() < state.nextCheck then
		return
	end
	state.loading, state.ready = true, false
	self:Publish(player, true)
	task.spawn(function()
		local ready, verified = true, {}
		for _, sku in Purchases.passes do
			local id = Purchases.idFor(self.ids, sku)
			if id then
				local ok, owned = pcall(function()
					return self.marketplace:UserOwnsGamePassAsync(player.UserId, id)
				end)
				if not ok or type(owned) ~= "boolean" then
					ready = false
				else
					verified[sku] = owned
				end
			elseif (self.ids.Passes or {})[sku] ~= nil then
				ready = false -- Configured but invalid/ambiguous IDs are not confirmed unowned.
			else
				verified[sku] = false
			end
		end
		if self.states[player] ~= state or player.Parent ~= Players then
			return
		end
		if state.refreshAgain then
			state.loading, state.refreshAgain = false, false
			self:Refresh(player, true)
			return
		end
		state.loading, state.ready = false, ready
		if ready then
			state.passes = verified
		end
		state.nextCheck = os.clock()
			+ (if ready then Config.PassOwnershipCacheSeconds else Config.PassOwnershipRetrySeconds)
		self:Publish(player, true)
		if not ready then
			task.delay(Config.PassOwnershipRetrySeconds, function()
				if self.states[player] == state then
					self:Refresh(player, false)
				end
			end)
		end
	end)
end
function MonetizationService:GetPasses(player)
	local state = self.states[player]
	if not state or not state.ready or os.clock() >= state.nextCheck then
		self:Refresh(player, false)
		return nil
	end
	return table.clone(state.passes)
end
function MonetizationService:NotifyGrab(player)
	self.firstGrab[player] = true
	self:Publish(player, true)
end
function MonetizationService:RequestPurchase(player, sku, jobId)
	local allowed, bucket = RateLimit.consume(
		self.buckets[player],
		os.clock(),
		Config.PurchaseRequestsPerSecond,
		Config.PurchaseRequestBurst
	)
	self.buckets[player] = bucket
	if not allowed then
		return false, "RateLimited"
	end
	local profile = self.data:Get(player)
	if player.Parent ~= Players or not profile then
		return false, "NotReady"
	end
	if type(sku) ~= "string" or not Purchases.implemented(sku) then
		return false, "NotReady"
	end
	local id, kind = Purchases.idFor(self.ids, sku)
	if not id then
		return false, "NotReady"
	end
	local passes = self:GetPasses(player)
	if not passes then
		return false, "NotReady"
	end
	if not self.firstGrab[player] and not profile.firstJobDone then
		return false, "FirstGrabRequired"
	end
	-- Insurance is still unavailable; current SKUs never accept caller-selected job context.
	if jobId ~= nil then
		return false, "InvalidJob"
	end
	if kind == "Passes" and passes[sku] then
		return false, "AlreadyOwned"
	end
	if self.pending[player] then
		return false, "PromptPending"
	end
	local job = self.jobForPlayer and self.jobForPlayer(player)
	local used = self.promptedJobs[player] or {}
	if job and used[job.id] then
		return false, "JobPromptLimit"
	end
	self.promptedJobs[player] = used
	if job then
		used[job.id] = true
	end
	local pending = { id = id, kind = kind }
	self.pending[player] = pending -- Reserve before a platform call can yield.
	local ok = pcall(function()
		if kind == "Passes" then
			self.marketplace:PromptGamePassPurchase(player, id)
		else
			self.marketplace:PromptProductPurchase(player, id)
		end
	end)
	if not ok then
		if self.pending[player] == pending then
			self.pending[player] = nil
		end
		return false, "PromptUnavailable"
	end
	return true
end
function MonetizationService:FinishPrompt(player, id, kind)
	local pending = self.pending[player]
	if pending and pending.id == id and pending.kind == kind then
		self.pending[player] = nil
	end
	-- Prompt completion is never a product grant or proof of pass ownership.
	if kind == "Passes" then
		self:Refresh(player, true)
	end
end
function MonetizationService:CashSku(productId)
	local found
	local matched = false
	for sku, id in self.ids.Products do
		if type(id) == "number" and id > 0 and id % 1 == 0 and id == productId then
			if matched then
				return nil
			end -- Fail closed on conflicting product configuration.
			matched = true
			found = if Config.CashPackAmounts[sku] then sku else nil
		end
	end
	return found
end
function MonetizationService:ProcessReceipt(receipt)
	local pending = Enum.ProductPurchaseDecision.NotProcessedYet
	local granted = Enum.ProductPurchaseDecision.PurchaseGranted
	if
		type(receipt) ~= "table"
		or not Rules.validId(receipt.PurchaseId)
		or type(receipt.PlayerId) ~= "number"
		or receipt.PlayerId % 1 ~= 0
		or type(receipt.ProductId) ~= "number"
		or receipt.ProductId <= 0
		or receipt.ProductId % 1 ~= 0
	then
		return pending
	end
	local id = receipt.PurchaseId
	if self.inFlight[id] then
		return pending
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and self.data:Get(player)
	if not player or not profile then
		return pending
	end -- Do not yield waiting for a join.
	self.inFlight[id] = true
	local success, decision = pcall(function()
		if not profile.purchases[id] then
			local sku = self:CashSku(receipt.ProductId)
			-- STUB(Codex): Insurance/CrewBoost require approved persisted purchase context.
			if not sku then
				return pending
			end
			local updated = self.data:Update(player, function(draft)
				return Rules.cash(draft, id, sku)
			end)
			if not updated then
				return pending
			end
			-- Log only the newly committed profile mutation, never a replay/save retry.
			-- Economy only enqueues; engine API calls run outside ProcessReceipt.
			if self.analytics then
				local committed = self.data:Get(player)
				if committed then
					pcall(function()
						self.analytics:Economy(
							player,
							Config.CashPackAmounts[sku],
							committed.cash,
							sku,
							"IAP"
						)
					end)
				end
			end
		end
		if not self.data:SaveReceipt(player, id) then
			return pending
		end
		return granted
	end)
	self.inFlight[id] = nil
	return if success then decision else pending
end
function MonetizationService:Start()
	self.marketplace.ProcessReceipt = function(receipt)
		return self:ProcessReceipt(receipt)
	end
	if not self.remotes then
		return
	end
	self.remotes.Monetization.RequestPurchase.OnServerInvoke = function(player, sku, jobId)
		return self:RequestPurchase(player, sku, jobId)
	end
	self.marketplace.PromptGamePassPurchaseFinished:Connect(function(player, id)
		self:FinishPrompt(player, id, "Passes")
	end)
	self.marketplace.PromptProductPurchaseFinished:Connect(function(userId, id)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			self:FinishPrompt(player, id, "Products")
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		self:Refresh(player, true)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.states[player], self.firstGrab[player], self.pending[player] = nil, nil, nil
		self.promptedJobs[player], self.buckets[player] = nil, nil
	end)
	for _, player in Players:GetPlayers() do
		self:Refresh(player, true)
	end
end
return MonetizationService
