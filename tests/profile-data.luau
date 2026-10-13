local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Schema = require("../src/shared/Logic/ProfileSchema")
local Config = require("../src/shared/Config")
local testConfig = table.clone(Config)
local RateLimit = require("../src/shared/Logic/RateLimit")

local initial = Schema.new()
local other = Schema.new()
initial.cash = 51
initial.upgrades.Dolly = 1
assert(other.cash == 0 and next(other.upgrades) == nil, "New profile tables are isolated")
local prepared = Schema.prepare({
	cash = 800,
	xp = 400,
	upgrades = { Straps = 2 },
	purchases = { receipt = true },
})
assert(
	prepared and prepared.level == 3 and prepared.cash == 800,
	"Reconcile without losing balances"
)
assert(
	prepared.purchases.receipt and prepared.settings.assist == false,
	"Preserve receipts and default settings"
)
local public = Schema.public(prepared)
assert(
	public.purchases == nil and public.stats == nil and public.catalog == nil,
	"Public profile allowlist"
)
public.upgrades.Straps = 0
assert(prepared.upgrades.Straps == 2, "Public snapshots cannot mutate saves")
for _, bad in
	{
		{ cash = -1 },
		{ cash = math.huge },
		{ xp = 0 / 0 },
		{ version = 2 },
		{ upgrades = { Dolly = 99 } },
		{ settings = { assist = 1 } },
		{ stats = "bad" },
		{ purchases = { receipt = "yes" } },
	}
do
	assert(Schema.prepare(bad) == nil, "Invalid profile rejected, not reset")
end

local function signal()
	local s = { listeners = {} }
	function s:Connect(fn)
		table.insert(self.listeners, fn)
	end
	function s:Fire(...)
		for _, fn in self.listeners do
			fn(...)
		end
	end
	return s
end
local Players = { PlayerAdded = signal(), PlayerRemoving = signal() }
function Players:GetPlayers()
	return {}
end
local studio = true
local RunService = {
	IsStudio = function()
		return studio
	end,
}
local shared = { Config = "Config", Logic = { ProfileSchema = "Schema", RateLimit = "RateLimit" } }
local sent, delayed = {}, {}
local remotes = {
	Data = {
		Profile = {
			FireClient = function(_, p, data)
				table.insert(sent, { p, data })
			end,
		},
	},
	Settings = { Set = { OnServerEvent = signal() } },
}
local close
local fixtureName, fixtureReads = nil, 0
local fakeGame = {}
function fakeGame:GetService(name)
	if name == "Players" then
		return Players
	end
	if name == "RunService" then
		return RunService
	end
	if name == "ServerStorage" then
		return {
			GetAttribute = function(_, key)
				assert(key == "MD_ProfileFixture", "Only Studio fixture selector is read")
				fixtureReads += 1
				return fixtureName
			end,
		}
	end
	return {
		WaitForChild = function()
			return shared
		end,
	}
end
function fakeGame:BindToClose(fn)
	close = fn
end
local module = luau.load(fs.readFile("src/server/Services/DataService.luau"), {
	environment = {
		game = fakeGame,
		require = function(name)
			return ({ Config = testConfig, Schema = Schema, RateLimit = RateLimit })[name]
		end,
		task = {
			delay = function(_, fn)
				table.insert(delayed, fn)
			end,
			spawn = function(fn)
				fn()
			end,
		},
		warn = function() end,
	},
})()
local function player(id)
	local p = {
		UserId = id,
		Parent = Players,
		attributes = {},
		CharacterAdded = signal(),
		kicked = false,
	}
	function p:SetAttribute(key, value)
		self.attributes[key] = value
	end
	function p:Kick()
		self.kicked = true
	end
	return p
end
local function profile(data)
	local p = { Data = data or Schema.new(), active = true, OnSessionEnd = signal() }
	function p:IsActive()
		return self.active
	end
	function p:AddUserId(id)
		self.userId = id
	end
	function p:EndSession()
		self.active = false
		self.OnSessionEnd:Fire()
	end
	return p
end
local nextProfile, onLoad, loadedKey
local store = {}
function store:StartSessionAsync(key, options)
	loadedKey = key
	if onLoad then
		onLoad(options)
	end
	return nextProfile
end
store.Mock = store
local library = {
	DataStoreState = "Access",
	New = function(name)
		assert(name == "Profiles_v1", "Stable save store")
		return store
	end,
}
local data = module.new(remotes, library)
local profileNotifications = 0
data.onProfilePublished = function(who)
	assert(data:Get(who) ~= nil, "Dependent state publication sees loaded profile")
	profileNotifications += 1
end
local p = player(123)
nextProfile = profile()
data:Load(p)
assert(loadedKey == "u_123" and nextProfile.userId == 123, "Stable key and user association")
assert(data:Get(p) and p.attributes.Level == 1 and not p.kicked, "Profile ready after load")
assert(#sent == 1 and #delayed == 1, "Initial snapshot plus startup resend")
assert(profileNotifications == 1, "Loaded profile republishes dependent purchase state")
assert(
	data:Update(p, function(draft)
		draft.cash = 450
		draft.xp = 900
	end),
	"Valid transaction accepted"
)
assert(
	data:Get(p).cash == 450 and data:Get(p).level == 4,
	"Cash and derived level committed together"
)
local ok, reason = data:Update(p, function(draft)
	draft.cash = -100
end)
assert(
	not ok and reason == "InvalidBalance" and data:Get(p).cash == 450,
	"Invalid mutation rolls back"
)
ok = data:Update(p, function(draft)
	draft.cash = 0
	error("oops")
end)
assert(not ok and data:Get(p).cash == 450, "Thrown mutation rolls back")
ok, reason = data:Update(p, function(draft)
	draft.cash = 0
	coroutine.yield()
end)
assert(
	not ok and reason == "YieldNotAllowed" and data:Get(p).cash == 450,
	"Yielding mutation rejected atomically"
)
data:SetSetting(p, "cash", 999)
data:SetSetting(p, "assist", "yes")
assert(not data:Get(p).settings.assist and data:Get(p).cash == 450, "Settings whitelist and types")
data:SetSetting(p, "assist", true)
assert(data:Get(p).settings.assist and p.attributes.Assist, "Valid Assist publishes attribute")
local count = #sent
for _ = 1, 100 do
	data:SetSetting(p, "assist", false)
end
assert(#sent - count <= Config.RemoteBurst, "Settings remote rate limited")
local savedProfile = nextProfile
data:Release(p)
assert(
	data:Get(p) == nil and not savedProfile.active and not p.kicked,
	"Intentional release ends session without kick"
)
assert(not data:Update(p, function() end), "Closed session cannot mutate")
for _, fn in delayed do
	fn()
end
assert(
	profileNotifications == #sent,
	"Profile changes and startup resend both refresh dependent state"
)
local p2 = player(456)
nextProfile = profile()
data:Load(p2)
nextProfile:EndSession()
assert(p2.kicked and data:Get(p2) == nil, "Unexpected session loss stops gameplay")
local departed = player(789)
nextProfile = profile()
onLoad = function(options)
	departed.Parent = nil
	assert(options.Cancel(), "Load cancels after departure")
end
data:Load(departed)
assert(not nextProfile.active and data:Get(departed) == nil, "Late session is released")
onLoad = nil
local future = player(100)
nextProfile = profile({ version = 2, cash = 777 })
data:Load(future)
assert(
	future.kicked and nextProfile.Data.cash == 777 and nextProfile.Data.version == 2,
	"Future save preserved on rejection"
)
studio = false
library.DataStoreState = "NoAccess"
local live = module.new(remotes, library)
local unavailable = player(200)
nextProfile = profile()
live:Load(unavailable)
assert(
	unavailable.kicked and live:Get(unavailable) == nil,
	"Never silently simulate live persistence"
)
studio = true
local shutdown = module.new(remotes, library)
shutdown:Start()
local last = player(300)
nextProfile = profile()
shutdown:Load(last)
close()
assert(
	shutdown.closing and not nextProfile.active and not last.kicked,
	"Shutdown releases active profiles"
)
fixtureName = "UpgradeShop"
library.DataStoreState = "Access"
local fixtureData = module.new(remotes, library)
local tester = player(401)
nextProfile = profile()
fixtureData:Load(tester)
assert(
	fixtureData:Get(tester).cash == Config.StudioFixtureCash and tester.attributes.Level == 6,
	"Opt-in fresh mock receives test funds and derived level"
)
assert(
	fixtureData:Get(tester).firstJobDone and next(fixtureData:Get(tester).upgrades) == nil,
	"Fixture starts at HQ without pre-granting paid upgrades"
)
local returning = player(402)
nextProfile = profile({ cash = 77, xp = 100, upgrades = { Dolly = 1 } })
fixtureData:Load(returning)
assert(
	fixtureData:Get(returning).cash == 77
		and fixtureData:Get(returning).xp == 100
		and not fixtureData:Get(returning).firstJobDone,
	"Existing mock progress remains unchanged"
)
local paid = player(403)
nextProfile = profile({ purchases = { oldReceipt = true } })
fixtureData:Load(paid)
assert(
	fixtureData:Get(paid).cash == 0 and fixtureData:Get(paid).purchases.oldReceipt,
	"Receipt history excludes fixture seeding"
)
fixtureName = "Unknown"
local unknownFixture = module.new(remotes, library)
local unknownTester = player(404)
nextProfile = profile()
unknownFixture:Load(unknownTester)
assert(
	unknownFixture:Get(unknownTester).cash == 0
		and not unknownFixture:Get(unknownTester).firstJobDone,
	"Unknown fixture names leave normal onboarding intact"
)
fixtureName = "UpgradeShop"
studio = false
local readsBeforeLive = fixtureReads
local liveFixture = module.new(remotes, library)
local liveTester = player(405)
nextProfile = profile()
liveFixture:Load(liveTester)
assert(
	fixtureReads == readsBeforeLive
		and liveFixture:Get(liveTester).cash == 0
		and not liveFixture:Get(liveTester).firstJobDone,
	"Live server never reads or grants a saved Studio fixture"
)
studio = true
testConfig.ProfileStudioMock = false
local realStudioData = module.new(remotes, library)
local realStudioTester = player(406)
nextProfile = profile()
realStudioData:Load(realStudioTester)
assert(
	fixtureReads == readsBeforeLive and realStudioData:Get(realStudioTester).cash == 0,
	"Studio using real persistence also ignores fixture"
)
testConfig.ProfileStudioMock = true
testConfig.StudioFixtureCash = -1
local invalidFixture = module.new(remotes, library)
local invalidTester = player(407)
nextProfile = profile()
invalidFixture:Load(invalidTester)
assert(
	invalidTester.kicked and nextProfile.Data.cash == 0,
	"Invalid fixture tuning is rejected without mutating a profile"
)
print(
	"PASS Studio profile fixture: opt-in pristine mocks only, real Shop buys, no live or existing-save grants"
)
print(
	"PASS ProfileSchema reconciliation/privacy; DataService load/cancel/release/session loss, atomic rollback, settings rate limit and live-access guard"
)
