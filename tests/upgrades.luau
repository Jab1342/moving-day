local Rules = require("../src/shared/Logic/UpgradeRules")
local Schema = require("../src/shared/Logic/ProfileSchema")
local Config = require("../src/shared/Config")
local RateLimit = require("../src/shared/Logic/RateLimit")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local V = require("@lune/roblox").Vector3
local p = Schema.new()
p.cash = 1000
local ok, reason, price = Rules.purchase(p, "Straps", 1)
assert(ok and price == 250 and p.cash == 1000, "Pure price validation leaves profile unchanged")
assert(not Rules.purchase(p, "Straps", 2), "Cannot skip prerequisite tier")
assert(not Rules.purchase(p, "Straps", 0 / 0), "Reject NaN tier")
assert(not Rules.purchase(p, "Straps", 1.5), "Reject fractional tier")
assert(not Rules.purchase(p, "Unknown", 1), "Reject unknown upgrade")
p.cash = 249
assert(not Rules.purchase(p, "Straps", 1), "Require full price")
assert(not Rules.wrap(p), "Require blanket unlock")
p.upgrades.MovingBlankets = 1
p.cash = 9
assert(not Rules.wrap(p), "Require per-use blanket cash")
p.cash = 10
ok, reason, price = Rules.wrap(p)
assert(ok and price == 10, "Blanket use price")
assert(Rules.strapSlots(0) == 2 and Rules.strapSlots(3) == 8, "Strap tiers add two slots")
assert(
	Rules.dollySpeed(0) == 0.4 and Rules.dollySpeed(1) == 0.55 and Rules.dollySpeed(2) == 0.70,
	"Configured dolly progression"
)
assert(
	Rules.dollySpeed(0 / 0) == Config.DollySpeedScale,
	"Invalid tier cannot produce invalid speed"
)
assert(Rules.dollySpeed(999) < 1, "Even maximum dolly retains speed tradeoff")

local function signal()
	return { Connect = function() end }
end
local crewPlayers = {}
local Players = {
	PlayerRemoving = signal(),
	GetPlayers = function()
		return crewPlayers
	end,
}
local shared = { Config = Config, Logic = { UpgradeRules = Rules, RateLimit = RateLimit } }
local counter = {
	Position = V.zero,
	IsA = function()
		return true
	end,
}
local garage = {
	FindFirstChild = function()
		return counter
	end,
}
local hq = {
	FindFirstChild = function()
		return garage
	end,
}
local map = {
	FindFirstChild = function()
		return hq
	end,
}
local module = luau.load(fs.readFile("src/server/Services/UpgradeService.luau"), {
	environment = {
		game = {
			GetService = function(_, name)
				return if name == "Players"
					then Players
					else {
						WaitForChild = function()
							return shared
						end,
					}
			end,
		},
		workspace = {
			FindFirstChild = function()
				return map
			end,
		},
		require = function(value)
			return value
		end,
	},
})()
local root = { Position = V.zero }
local player = {
	Character = {
		FindFirstChild = function()
			return root
		end,
		FindFirstChildOfClass = function()
			return { Health = 100 }
		end,
	},
	GetAttribute = function()
		return "A"
	end,
}
local data = { profile = Schema.new() }
data.profile.cash = 1000
function data:Get()
	return self.profile
end
function data:Update(_, callback)
	local draft = Schema.copy(self.profile)
	local accepted, why = callback(draft)
	if accepted == false then
		return false, why
	end
	local validated = Schema.prepare(draft)
	assert(validated, "Transactions leave valid profile")
	self.profile = validated
	return true
end
local remotes = { Shop = { Buy = {} } }
local service = module.new(data, remotes)
service:Start()
root.Position = V.new(Config.ShopRange + 1, 0, 0)
ok, reason = service:Buy(player, "Straps", 1)
assert(
	not ok and reason == "NotAtHQ" and data.profile.cash == 1000,
	"Server rejects remote shopping"
)
root.Position = V.zero
assert(
	remotes.Shop.Buy.OnServerInvoke(player, "Straps", 1),
	"Shop remote binds authoritative transaction"
)
assert(
	data.profile.cash == 750 and data.profile.upgrades.Straps == 1,
	"Debit and tier commit together"
)
assert(
	not service:Buy(player, "Straps", 1) and data.profile.cash == 750,
	"Replay cannot charge twice"
)
assert(service:Buy(player, "MovingBlankets", 1), "Blanket unlock purchase")
assert(service:PayWrap(player) and data.profile.cash == 340, "Blanket use debits separately")
service.isInJob = function()
	return true
end
ok, reason = service:Buy(player, "Straps", 2)
assert(not ok and reason == "InJob", "Active job hook denies purchase")
service.isInJob = nil
assert(
	not service:Buy(player, "BoxTruck", 1) and data.profile.cash == 340,
	"Do not sell unimplemented effects"
)
crewPlayers = { player }
data.profile.cash = 5000
service.buckets = {}
service.isReady = function()
	return false
end
ok, reason = service:Buy(player, "LoadingRamp", 1)
assert(
	not ok and reason == "NotReady" and data.profile.cash == 5000,
	"Missing geometry cannot charge"
)
service.isReady = function(id)
	return id == "LoadingRamp" or id == "BoxTruck" or id == "SoftSuspension"
end
for _, id in { "LoadingRamp", "BoxTruck", "SoftSuspension" } do
	assert(service:Buy(player, id, 1), "Ready truck upgrade purchase")
	assert(data.profile.upgrades[id] == 1, "Truck upgrade persists")
end
assert(data.profile.cash == 1000, "Truck upgrade prices debit exactly once")
assert(
	not service:Buy(player, "LoadingRamp", 1) and data.profile.cash == 1000,
	"Repeat truck purchase cannot debit"
)
assert(
	not service:Buy(player, "Unknown", 1) and data.profile.cash == 1000,
	"Unimplemented effect remains unavailable"
)
assert(
	service:StrapSlots("A") == 4 and service:StrapSlots("B") == 2,
	"Capacity derives from current own crew only"
)
print(
	"PASS: upgrade prices/prerequisites, server HQ gate, atomic debit/replay rejection, blanket use and crew strap capacity"
)
service.buckets = {}
data.profile.cash = 1200
assert(service:Buy(player, "Dolly", 1), "Dolly first tier available at HQ")
assert(service:DollyTier(player) == 1 and data.profile.cash == 900, "Dolly tier and debit atomic")
assert(service:Buy(player, "Dolly", 2), "Dolly second tier available sequentially")
assert(
	service:DollyTier(player) == 2 and data.profile.cash == 0,
	"Dolly second tier charges exact cost"
)
assert(not service:Buy(player, "Dolly", 2) and data.profile.cash == 0, "Dolly replay rejected")
