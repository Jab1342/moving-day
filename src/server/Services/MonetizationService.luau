--!nonstrict
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ProductIds = require(Shared.ProductIds)
local Config = require(Shared.Config)
local Rules = require(Shared.Logic.ReceiptRules)
local MonetizationService = {}
MonetizationService.__index = MonetizationService
function MonetizationService.new(data, ids, marketplace)
	return setmetatable({
		data = data,
		ids = ids or ProductIds,
		marketplace = marketplace or MarketplaceService,
		inFlight = {},
	}, MonetizationService)
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
end
return MonetizationService
