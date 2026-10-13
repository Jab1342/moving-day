local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Config = require("../src/shared/Config")
local Schema = require("../src/shared/Logic/ProfileSchema")
local Rules = require("../src/shared/Logic/ReceiptRules")
local RateLimit = require("../src/shared/Logic/RateLimit")

local draft = Schema.new()
assert(
	Rules.cash(draft, "one", "Cash500") and draft.cash == 500 and draft.purchases.one,
	"Small cash pack recorded"
)
assert(Rules.cash(draft, "one", "Cash500") and draft.cash == 500, "Retry does not duplicate cash")
assert(Rules.cash(draft, "two", "Cash1800") and draft.cash == 2300, "Medium cash pack amount")
assert(Rules.cash(draft, "three", "Cash5500") and draft.cash == 7800, "Large cash pack amount")
for _, invalid in { false, 1, "", string.rep("x", 129) } do
	assert(not Rules.cash(draft, invalid, "Cash500"), "Invalid receipt rejected")
end
assert(
	not Rules.cash(draft, "unknown", "Insurance") and not draft.purchases.unknown,
	"Unsupported effect not consumed"
)
draft.cash = Config.MaxProfileValue - 499
assert(
	not Rules.cash(draft, "capped", "Cash500") and not draft.purchases.capped,
	"Cap cannot consume receipt"
)

local player = { UserId = 123, SetAttribute = function() end }
local Players = {}
player.Parent = Players
function Players:GetPlayerByUserId(id)
	return if id == player.UserId then player else nil
end
local Shared = {
	Config = "Config",
	ProductIds = "ProductIds",
	Logic = { ReceiptRules = "Rules", ProfileSchema = "Schema", RateLimit = "RateLimit" },
}
local marketplace = {}
local fakeGame = {}
function fakeGame:GetService(name)
	return ({
		Players = Players,
		MarketplaceService = marketplace,
		RunService = {
			IsStudio = function()
				return false
			end,
		},
		ReplicatedStorage = {
			WaitForChild = function()
				return Shared
			end,
		},
	})[name]
end
local stamp, onWait = 0, nil
local environment = {
	game = fakeGame,
	Enum = {
		ProductPurchaseDecision = { NotProcessedYet = "pending", PurchaseGranted = "granted" },
	},
	require = function(name)
		return ({
			Config = Config,
			ProductIds = { Products = {} },
			Rules = Rules,
			Schema = Schema,
			RateLimit = RateLimit,
		})[name]
	end,
	os = {
		clock = function()
			return stamp
		end,
	},
	task = {
		wait = function(seconds)
			stamp += seconds
			if onWait then
				onWait()
			end
		end,
	},
}
local Data =
	luau.load(fs.readFile("src/server/Services/DataService.luau"), { environment = environment })()
local Monetization = luau.load(
	fs.readFile("src/server/Services/MonetizationService.luau"),
	{ environment = environment }
)()
local data = Data.new({ Data = { Profile = { FireClient = function() end } } }, {
	New = function()
		return {}
	end,
})
local profile, saveMode, saveCalls
local economyEvents = {}
local function reset(saved)
	stamp, onWait, saveCalls, saveMode = 0, nil, 0, "immediate"
	economyEvents = {}
	profile = {
		Data = Schema.copy(saved or Schema.new()),
		LastSavedData = Schema.copy(saved or Schema.new()),
		active = true,
	}
	function profile:IsActive()
		return self.active
	end
	function profile:Save()
		saveCalls += 1
		if saveMode == "throw" then
			error("simulated save failure")
		end
		if saveMode == "immediate" then
			self.LastSavedData = Schema.copy(self.Data)
		end
	end
	data.profiles[player] = profile
end
local ids = { Products = { Cash500 = 101, Cash1800 = 102, Cash5500 = 103 } }
local service = Monetization.new(data, ids, marketplace)
service.analytics = {
	Economy = function(_, recipient, amount, balance, sku, transactionType)
		assert(
			recipient == player and profile.Data.cash == balance,
			"Analytics sees committed balance"
		)
		assert(next(profile.Data.purchases) ~= nil, "Receipt ledger precedes economy event")
		assert(
			amount == Config.CashPackAmounts[sku] and transactionType == "IAP",
			"Exact purchased amount/category"
		)
		table.insert(economyEvents, { amount = amount, balance = balance, sku = sku })
	end,
}
service:Start()
local function receipt(id, product)
	return { PurchaseId = id, ProductId = product or 101, PlayerId = 123 }
end
reset()
assert(
	marketplace.ProcessReceipt(receipt("first")) == "granted",
	"Callback installed and grants cash"
)
assert(
	profile.Data.cash == 500 and profile.LastSavedData.purchases.first and saveCalls == 1,
	"Reward and receipt persisted"
)
assert(
	service:ProcessReceipt(receipt("first")) == "granted"
		and profile.Data.cash == 500
		and saveCalls == 1,
	"Durable replay grants once without saving again"
)
local persisted = Schema.copy(profile.LastSavedData)
assert(
	#economyEvents == 1 and economyEvents[1].amount == 500,
	"One source event across receipt replay"
)
reset(persisted)
assert(
	service:ProcessReceipt(receipt("first", 999)) == "granted" and saveCalls == 0,
	"Durable replay survives rejoin and retired IDs"
)
assert(
	service:ProcessReceipt(receipt("unsupported", 999)) == "pending"
		and not profile.Data.purchases.unsupported,
	"Unknown ID remains pending"
)
assert(
	Monetization.new(data):ProcessReceipt(receipt("unset")) == "pending",
	"Missing product IDs fail closed"
)
assert(
	Monetization.new(data, { Products = { Cash500 = 101, Cash1800 = 101 } })
		:ProcessReceipt(receipt("collision")) == "pending",
	"Ambiguous IDs cannot choose a reward"
)
assert(
	Monetization.new(data, { Products = { Cash500 = 101, InsuranceClaim = 101 } })
		:ProcessReceipt(receipt("effectcollision")) == "pending",
	"Unsupported effect sharing a cash ID must not silently grant cash"
)
for _, malformed in
	{
		false,
		{},
		{ PurchaseId = "x", PlayerId = 123, ProductId = math.huge },
		{ PurchaseId = "x", PlayerId = 0 / 0, ProductId = 101 },
	}
do
	assert(service:ProcessReceipt(malformed) == "pending", "Malformed receipt rejected")
end
local absent = receipt("absent")
absent.PlayerId = 456
assert(service:ProcessReceipt(absent) == "pending", "Offline player deferred")
data.profiles[player] = nil
assert(service:ProcessReceipt(receipt("loading")) == "pending", "No yield waiting for profile")
assert(
	#economyEvents == 0,
	"Rejoin replay, malformed and unrecognized receipts cannot emit a purchase"
)

reset()
saveMode = "delayed"
onWait = function()
	assert(
		profile.Data.cash == 500 and profile.Data.purchases.concurrent,
		"Ledger and reward precede save"
	)
	assert(
		service:ProcessReceipt(receipt("concurrent")) == "pending",
		"Concurrent callback cannot reenter grant"
	)
	assert(not profile.LastSavedData.purchases.concurrent, "Save returning is not durability proof")
	profile.LastSavedData = Schema.copy(profile.Data)
end
assert(
	service:ProcessReceipt(receipt("concurrent")) == "granted"
		and stamp > 0
		and profile.Data.cash == 500,
	"Concurrent replay waits for original save without duplicate grant"
)
assert(#economyEvents == 1, "Concurrent receipt only logs one committed grant")

reset()
saveMode = "delayed"
assert(
	service:ProcessReceipt(receipt("timeout")) == "pending"
		and stamp >= Config.ReceiptSaveTimeoutSeconds,
	"Save wait is bounded"
)
assert(
	profile.Data.cash == 500 and not profile.LastSavedData.purchases.timeout,
	"Unconfirmed save never acknowledged"
)
saveMode = "immediate"
assert(
	service:ProcessReceipt(receipt("timeout")) == "granted" and profile.Data.cash == 500,
	"Retry persists reward without duplicating it"
)
assert(#economyEvents == 1, "Save timeout and retry do not duplicate the source event")

reset()
saveMode = "throw"
assert(
	service:ProcessReceipt(receipt("failure")) == "pending" and not service.inFlight.failure,
	"Thrown save releases receipt lock"
)
local beforeCrash = Schema.copy(profile.LastSavedData)
assert(
	not beforeCrash.purchases.failure and beforeCrash.cash == 0,
	"Unsuccessful save cannot mutate durable state"
)
reset(beforeCrash)
assert(
	service:ProcessReceipt(receipt("failure")) == "granted" and profile.Data.cash == 500,
	"Crash before save retries against old durable state"
)

reset()
saveMode = "delayed"
onWait = function()
	profile.active = false
end
assert(
	service:ProcessReceipt(receipt("lost")) == "pending",
	"Session loss before durability defers acknowledgement"
)
reset()
saveMode = "delayed"
onWait = function()
	data.profiles[player] = nil
end
assert(
	service:ProcessReceipt(receipt("departed")) == "pending",
	"Removed session cannot keep waiting"
)
reset()
saveMode = "delayed"
onWait = function()
	profile.LastSavedData = Schema.copy(profile.Data)
	profile.active = false
	data.profiles[player] = nil
end
assert(
	service:ProcessReceipt(receipt("finalsave")) == "granted",
	"Confirmed final save is durable even after release"
)
reset()
profile.Data.cash = Config.MaxProfileValue
assert(
	service:ProcessReceipt(receipt("cap")) == "pending"
		and not profile.Data.purchases.cap
		and saveCalls == 0,
	"Cash cap defers receipt without a partial save"
)
data.closing = true
assert(
	service:ProcessReceipt(receipt("closing")) == "pending" and not profile.Data.purchases.closing,
	"Shutdown cannot start a new grant"
)
assert(#economyEvents == 0, "Failed cap and shutdown mutations cannot emit")
data.closing = false
reset()
service.analytics.Economy = function()
	error("Simulated analytics failure")
end
assert(
	service:ProcessReceipt(receipt("analyticsoutage")) == "granted",
	"Analytics failure cannot block receipt save"
)
assert(profile.LastSavedData.cash == 500, "Receipt reward remains durable during analytics outage")
print(
	"PASS receipts: atomic ledger, replay/rejoin, concurrency, delayed durability, timeout, failure/crash, session loss, unknown IDs and balance cap"
)
