--!strict
local Rules = {}
Rules.passes = table.freeze({ "VIPForeman", "DoublePay", "HornRadio" })
Rules.products = table.freeze({ "InsuranceClaim", "CrewBoost", "Cash500", "Cash1800", "Cash5500" })
function Rules.idFor(ids, sku)
	local kind = if table.find(Rules.passes, sku)
		then "Passes"
		elseif table.find(Rules.products, sku) then "Products"
		else nil
	if not kind then
		return nil
	end
	local group = ids[kind] or {}
	local id = group[sku]
	if type(id) ~= "number" or id <= 0 or id >= math.huge or id % 1 ~= 0 then
		return nil
	end
	for other, value in group do
		if other ~= sku and value == id then
			return nil
		end
	end
	return id, kind
end
function Rules.implemented(sku)
	-- VIP cosmetics, HornRadio content, Insurance and CrewBoost context remain gated.
	return sku == "DoublePay" or sku == "Cash500" or sku == "Cash1800" or sku == "Cash5500"
end
return Rules
