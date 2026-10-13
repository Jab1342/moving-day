--!strict
local Config = if script then require(script.Parent.Parent.Config) else require("../Config")
local ReceiptRules = {}
function ReceiptRules.validId(id)
	return type(id) == "string" and #id > 0 and #id <= 128
end
-- Mutates only a DataService draft. The receipt and reward commit in one profile save.
function ReceiptRules.cash(profile, purchaseId, sku)
	if not ReceiptRules.validId(purchaseId) then
		return false, "InvalidReceipt"
	end
	if profile.purchases[purchaseId] then
		return true, "AlreadyGranted"
	end
	local amount = Config.CashPackAmounts[sku]
	if not amount then
		return false, "UnsupportedProduct"
	end
	if profile.cash + amount > Config.MaxProfileValue then
		return false, "BalanceLimit"
	end
	profile.purchases[purchaseId] = true
	profile.cash += amount
	return true, nil
end
return ReceiptRules
