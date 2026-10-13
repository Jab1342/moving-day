local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Config = require("../src/shared/Config")
local Purchases = require("../src/shared/Logic/PurchaseRules")
local Benefits = require("../src/shared/Logic/PassBenefits")
local Payout = require("../src/shared/Logic/Payout")
local ReceiptRules = require("../src/shared/Logic/ReceiptRules")
local RateLimit = require("../src/shared/Logic/RateLimit")
assert(
	not Purchases.idFor({ Passes = { DoublePay = 1, VIPForeman = 1 } }, "DoublePay"),
	"Ambiguous pass IDs unavailable"
)
for _, invalid in { 0, -1, math.huge, 0 / 0, 1.5, "123" } do
	assert(
		not Purchases.idFor({ Products = { Cash500 = invalid } }, "Cash500"),
		"Invalid configured ID unavailable"
	)
end
assert(not Purchases.idFor({}, "Unknown"), "Unknown SKU has no ID")
assert(
	not Purchases.implemented("VIPForeman") and not Purchases.implemented("CrewBoost"),
	"Incomplete effects stay unavailable"
)
for count = 1, 4 do
	for _, assist in { false, true } do
		for _, elapsed in { 0, 175, 1000 } do
			local recipients, owned = {}, {}
			for n = 1, count do
				recipients[n] = n
				owned[tostring(n)] = { DoublePay = n % 2 == 1, VIPForeman = true }
			end
			local base = Payout.compute({
				jobId = "j",
				tier = "Starter",
				elapsedSeconds = elapsed,
				assist = assist,
				lines = { { itemUid = "p", itemId = "piano", valueKept = 600, valueLost = 0 } },
				memberUserIds = recipients,
				nextJob = { tier = "Starter", lotId = 1 },
			}, count)
			local report = Benefits.apply(base, recipients, owned, assist)
			local total = 0
			for _, id in recipients do
				local key = tostring(id)
				assert(report.shares[key] >= base.shares[key], "Benefits never lower base shares")
				assert(
					report.shares[key] - report.bonuses[key] == base.shares[key],
					"Bonus line reconciles with base"
				)
				if elapsed >= Config.SoftTimer.Starter then
					assert(
						report.shares[key] == base.shares[key] * (if id % 2 == 1 then 2 else 1),
						"No VIP tip after timer"
					)
				end
				total += report.shares[key]
			end
			assert(
				total == report.total and report.perPlayer == math.floor(total / count),
				"Personal shares sum to published total"
			)
			assert(
				report.xpEach == base.xpEach and report.stars == base.stars and base.bonuses == nil,
				"Passes only modify copied cash output"
			)
			assert(
				not pcall(Benefits.apply, report, recipients, owned, assist),
				"Cannot double-apply bonuses"
			)
		end
	end
end
local base = {
	jobFee = 150,
	timeBonus = 150,
	total = 900,
	perPlayer = 900,
	shares = { ["1"] = 900 },
	lines = { { valueKept = 600 } },
	xpEach = 12,
	stars = 5,
}
local both = Benefits.apply(base, { 1 }, { ["1"] = { VIPForeman = true, DoublePay = true } }, false)
assert(
	both.shares["1"] == 1830 and both.bonuses["1"] == 930,
	"Ten-percent tip is added before double cash"
)
local fee = { jobFee = 150, timeBonus = 0, total = 150, shares = { ["1"] = 150 }, lines = {} }
assert(
	Benefits.apply(fee, { 1 }, { ["1"] = { VIPForeman = true, DoublePay = true } }, true).total
		== 300,
	"All-broken fee is doubled without invented tip"
)

local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			table.insert(callbacks, fn)
		end,
		Fire = function(_, ...)
			for _, fn in callbacks do
				fn(...)
			end
		end,
	}
end
local Players = { PlayerAdded = signal(), PlayerRemoving = signal() }
local player = { UserId = 123, Parent = Players }
function Players:GetPlayers()
	return { player }
end
function Players:GetPlayerByUserId(id)
	return if id == 123 then player else nil
end
local profile = { cash = 0, firstJobDone = false }
local data = {
	Get = function()
		return profile
	end,
}
local ids = {
	Passes = { DoublePay = 101, VIPForeman = 102, HornRadio = 103 },
	Products = { Cash500 = 201, Cash1800 = 202, CrewBoost = 203 },
}
local owned, fail, promptFail, whilePrompt = {}, false, false, nil
local prompts, published, tasks, delayed = {}, {}, {}, {}
local deferred, stamp, job = false, 10, { id = "job1" }
local marketplace =
	{ PromptGamePassPurchaseFinished = signal(), PromptProductPurchaseFinished = signal() }
function marketplace:UserOwnsGamePassAsync(_, id)
	if fail then
		error("simulated ownership API failure")
	end
	return owned[id] == true
end
function marketplace:PromptGamePassPurchase(_, id)
	if promptFail then
		error("simulated prompt failure")
	end
	table.insert(prompts, { kind = "Passes", id = id })
	if whilePrompt then
		whilePrompt()
	end
end
function marketplace:PromptProductPurchase(_, id)
	if promptFail then
		error("simulated prompt failure")
	end
	table.insert(prompts, { kind = "Products", id = id })
	if whilePrompt then
		whilePrompt()
	end
end
local remotes = {
	Monetization = {
		RequestPurchase = {},
		State = {
			FireClient = function(_, _, state)
				table.insert(published, state)
			end,
		},
	},
}
local shared = {
	Config = Config,
	ProductIds = ids,
	Logic = {
		ReceiptRules = ReceiptRules,
		PurchaseRules = Purchases,
		RateLimit = RateLimit,
		PassBenefits = Benefits,
		Payout = Payout,
	},
}
local gameMock = {
	GetService = function(_, name)
		if name == "Players" then
			return Players
		end
		if name == "MarketplaceService" then
			return marketplace
		end
		return {
			WaitForChild = function()
				return shared
			end,
		}
	end,
}
local env = {
	game = gameMock,
	require = function(value)
		return value
	end,
	os = {
		clock = function()
			return stamp
		end,
	},
	task = {
		spawn = function(fn)
			if deferred then
				table.insert(tasks, fn)
			else
				fn()
			end
		end,
		delay = function(_, fn)
			table.insert(delayed, fn)
		end,
	},
	workspace = {
		GetServerTimeNow = function()
			return stamp
		end,
	},
}
local Service =
	luau.load(fs.readFile("src/server/Services/MonetizationService.luau"), { environment = env })()
local service = Service.new(data, ids, marketplace, remotes)
service.jobForPlayer = function()
	return job
end
service:Start()
assert(
	type(marketplace.ProcessReceipt) == "function" and service.states[player].ready,
	"Start binds receipt owner and verifies entitlements"
)
local state = published[#published]
assert(
	state.ready
		and state.available.DoublePay
		and state.available.Cash500
		and not state.available.VIPForeman
		and not state.available.CrewBoost,
	"State only offers implemented configured effects"
)
local function request(sku, jobId)
	service.buckets = {}
	return remotes.Monetization.RequestPurchase.OnServerInvoke(player, sku, jobId)
end
local ok, reason = request("Cash500")
assert(not ok and reason == "FirstGrabRequired" and #prompts == 0, "No purchase before first grab")
service:NotifyGrab(player)
assert(not request(201) and not request("InsuranceClaim"), "No raw IDs or unavailable insurance")
ok, reason = request("Cash500", "another-job")
assert(not ok and reason == "InvalidJob", "Caller cannot choose stale or foreign job context")
whilePrompt = function()
	local accepted, why = request("Cash1800")
	assert(not accepted and why == "PromptPending", "Reserve prompt before platform call can yield")
end
assert(
	request("Cash500") and #prompts == 1 and prompts[1].id == 201,
	"Validated product prompts configured ID"
)
whilePrompt = nil
marketplace.PromptProductPurchaseFinished:Fire(123, 202, true)
assert(service.pending[player] ~= nil, "Unrelated completion cannot clear pending prompt")
marketplace.PromptProductPurchaseFinished:Fire(123, 201, true)
assert(
	not service.pending[player] and profile.cash == 0,
	"Prompt success never grants product cash"
)
ok, reason = request("Cash1800")
assert(not ok and reason == "JobPromptLimit", "Only one prompt per job")
job = nil
assert(request("Cash1800"), "HQ permits a later deliberate prompt")
marketplace.PromptProductPurchaseFinished:Fire(123, 202, false)
job = { id = "job1" }
ok, reason = request("Cash500")
assert(
	not ok and reason == "JobPromptLimit",
	"Leaving and returning cannot reset a job prompt budget"
)
job = { id = "job2" }
assert(request("DoublePay"), "Next job has a fresh prompt budget")
marketplace.PromptGamePassPurchaseFinished:Fire(player, 101, true)
assert(not service:GetPasses(player).DoublePay, "Platform completion flag is not ownership proof")
owned[101] = true
marketplace.PromptGamePassPurchaseFinished:Fire(player, 101, false)
assert(service:GetPasses(player).DoublePay, "Verified server ownership controls benefit")
ok, reason = request("DoublePay")
assert(not ok and reason == "AlreadyOwned", "Already-owned pass cannot be prompted again")
fail = true
service:Refresh(player, true)
assert(
	not service.states[player].ready and not service:GetPasses(player),
	"API error is unknown, never confirmed unowned"
)
assert(
	not published[#published].ready and not published[#published].available.Cash500 and #delayed > 0,
	"Failure hides offers and schedules retry"
)
fail = false
stamp += Config.PassOwnershipRetrySeconds
table.remove(delayed, 1)()
assert(service:GetPasses(player).DoublePay, "Retry restores verified ownership")
deferred = true
service:Refresh(player, true)
service:Refresh(player, true)
table.remove(tasks, 1)()
assert(
	not service.states[player].ready and #tasks == 1,
	"Purchase invalidation during a check requires a fresh query"
)
table.remove(tasks, 1)()
assert(service.states[player].ready, "Fresh in-flight recheck completes")
deferred = false
job = { id = "job3" }
promptFail = true
ok, reason = request("Cash500")
assert(
	not ok and reason == "PromptUnavailable" and not service.pending[player],
	"Prompt failure grants nothing and releases busy state"
)
promptFail = false
ok, reason = request("Cash500")
assert(
	not ok and reason == "JobPromptLimit",
	"Unknown prompt outcome conservatively consumes job budget"
)
service.buckets = {}
service:RequestPurchase(player, "Unknown")
service:RequestPurchase(player, "Unknown")
ok, reason = service:RequestPurchase(player, "Unknown")
assert(not ok and reason == "RateLimited", "Rejected spam is rate limited too")
deferred = true
service:Refresh(player, true)
local oldCount = #published
Players.PlayerRemoving:Fire(player)
player.Parent = nil
table.remove(tasks, 1)()
assert(
	not service.states[player] and #published == oldCount and not service.promptedJobs[player],
	"Departed player cannot receive stale ownership result"
)

-- Exercise the real payout service: wait for all entitlements and snapshot benefits once.
player.Parent = Players
profile = {
	cash = 0,
	firstJobDone = true,
	xp = 0,
	stats = { jobs = 0, delivered = 0, broken = 0, moneyLost = 0 },
	catalog = {},
}
function data:Update(_, fn)
	fn(profile)
	return true
end
local reports = {}
local payoutRemotes = {
	Job = {
		Payout = {
			FireClient = function(_, _, report)
				table.insert(reports, report)
			end,
		},
	},
}
local PayoutService =
	luau.load(fs.readFile("src/server/Services/PayoutService.luau"), { environment = env })()
local payout = PayoutService.new(data, payoutRemotes)
local ready = false
payout.passesForPlayer = function()
	return if ready then { DoublePay = true } else nil
end
local completed = {
	id = "done",
	crew = { members = { player }, padId = 1 },
	order = { "box" },
	snapshots = {
		box = {
			state = "Delivered",
			def = require("../src/shared/ItemDefs").box,
			hp = 100,
			blame = 0,
		},
	},
	tier = "Starter",
	assist = false,
	startedAt = 0,
	completedAt = 10,
	returnAt = 15,
}
assert(
	not payout:Award(completed) and profile.cash == 0 and not completed.report,
	"No award while pass ownership is unresolved"
)
stamp = 100
ready = true
local report = payout:Award(completed)
assert(
	report.total == 348
		and profile.cash == 348
		and report.timeBonus == 4
		and completed.returnAt == 100 + Config.PayoutDisplaySeconds,
	"Delayed payout applies verified bonus and leaves display time"
)
payout.passesForPlayer = function()
	return {}
end
payout:Award(completed)
assert(
	profile.cash == 348 and #reports == 1,
	"Snapshot and award cannot duplicate or lose purchased bonus on retry"
)
print(
	"PASS purchases: configured effects, authoritative ownership/retry, first-grab and job limits, concurrent prompt guards, completion vs receipt separation, personal payout bonuses and delayed award"
)
