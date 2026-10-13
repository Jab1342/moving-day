local Config = require("../src/shared/Config")
local ItemDefs = require("../src/shared/ItemDefs")
local UpgradeDefs = require("../src/shared/UpgradeDefs")
local RoomDefs = require("../src/shared/RoomDefs")
local Economy = require("../src/shared/Logic/Economy")
local Payout = require("../src/shared/Logic/Payout")
local JobGen = require("../src/shared/Logic/JobGen")

local function rejects(callback)
	assert(not pcall(callback), "Malformed input must fail closed")
end

local previous = 1
for xp = 0, 100000 do
	local level = Economy.levelForXp(xp)
	assert(level >= previous, "Level curve must be monotonic")
	previous = level
end
for level = 2, 100 do
	local threshold = Config.LevelXpBase * (level - 1) ^ 2
	assert(Economy.levelForXp(threshold - 1) == level - 1, "Level below threshold")
	assert(Economy.levelForXp(threshold) == level, "Level at threshold")
end
assert(Economy.levelForXp(-10) == 1, "Negative XP floors to level one")
rejects(function()
	Economy.levelForXp(0 / 0)
end)
rejects(function()
	Economy.levelForXp(math.huge)
end)
for id, def in UpgradeDefs do
	for tier, price in def.prices do
		assert(
			Economy.upgradePrice(id, tier) == price and price > 0,
			"Every tier matches catalogue"
		)
	end
	rejects(function()
		Economy.upgradePrice(id, #def.prices + 1)
	end)
end
rejects(function()
	Economy.upgradePrice("Unknown", 1)
end)
rejects(function()
	Economy.upgradePrice("Dolly", 0)
end)
rejects(function()
	Economy.upgradePrice("Dolly", 1.5)
end)

local function result(kept, elapsed, assist, crewSize)
	local users = {}
	for index = 1, crewSize do
		table.insert(users, index * 11)
	end
	return {
		jobId = "job-test",
		tier = "Starter",
		elapsedSeconds = elapsed,
		assist = assist,
		lines = {
			{
				itemUid = "couch-1",
				itemId = "couch",
				valueKept = kept,
				valueLost = 200 - kept,
				blameUserId = 11,
			},
		},
		memberUserIds = users,
		nextJob = { tier = "Family", lotId = 2 },
	}
end
for crewSize = 1, 4 do
	for kept = 0, 200 do
		for _, assist in { false, true } do
			local input = result(kept, 120, assist, crewSize)
			local report = Payout.compute(input, crewSize)
			local sum, low, high = 0, math.huge, 0
			for _, userId in input.memberUserIds do
				local share = report.shares[tostring(userId)]
				assert(share % 1 == 0, "Whole dollar share")
				sum += share
				low, high = math.min(low, share), math.max(high, share)
			end
			assert(sum == report.total and high - low <= 1, "Shares must conserve whole dollars")
			assert(report.total >= Config.JobFee.Starter, "Guaranteed fee even with Assist")
			assert(report.perPlayer == low, "Display perPlayer is floor share")
			if kept == 0 then
				assert(
					report.total == Config.JobFee.Starter and report.stars == 1,
					"All broken pays fee and one star"
				)
			end
			assert(report.lines[1].blameUserId == 11, "Preserve server blame")
			report.lines[1].valueKept = -1
			report.nextJob.lotId = 4
			assert(
				input.lines[1].valueKept == kept and input.nextJob.lotId == 2,
				"Do not mutate inputs"
			)
		end
	end
end
local early = Payout.compute(result(200, 0, false, 1), 1)
local late = Payout.compute(result(200, 3600, false, 1), 1)
assert(early.total == 400 and early.timeBonus == 50, "Full time bonus at start")
assert(late.total == 350 and late.timeBonus == 0, "Overtime removes only bonus")
assert(Payout.compute(result(200, 0, true, 1), 1).total == 320, "Assist discount")
local previousBonus = math.huge
for elapsed = 0, 400 do
	local report = Payout.compute(result(200, elapsed, false, 1), 1)
	assert(report.timeBonus <= previousBonus, "Time bonus declines monotonically")
	previousBonus = report.timeBonus
end
for stars, band in Config.PayoutStarBands do
	assert(
		Payout.compute(result(200 * band, 0, false, 1), 1).stars == stars,
		"Star band inclusive threshold"
	)
	if stars > 1 then
		assert(
			Payout.compute(result(200 * band - 0.001, 0, false, 1), 1).stars == stars - 1,
			"Below star threshold"
		)
	end
end
local uneven = Payout.compute(result(1, 360, false, 4), 4)
assert(
	uneven.shares["11"] == 38
		and uneven.shares["22"] == 38
		and uneven.shares["33"] == 38
		and uneven.shares["44"] == 37,
	"Remainder goes to earliest joined members"
)
rejects(function()
	Payout.compute(result(1, 0, false, 1), 0)
end)
rejects(function()
	Payout.compute(result(1, 0, false, 1), 2)
end)
rejects(function()
	Payout.compute(result(201, 0, false, 1), 1)
end)
rejects(function()
	Payout.compute(result(0 / 0, 0, false, 1), 1)
end)
local bad = result(1, 0, false, 2)
bad.memberUserIds[2] = bad.memberUserIds[1]
rejects(function()
	Payout.compute(bad, 2)
end)
bad = result(1, 0, false, 1)
table.insert(bad.lines, table.clone(bad.lines[1]))
rejects(function()
	Payout.compute(bad, 1)
end)

local function equal(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not equal(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end
local function cell(x, z, floor)
	return `{x}:{z}:{floor}`
end
local variants = {}
for seed = 1, 1000 do
	for _, tier in { "Starter", "Family", "Big" } do
		local layout = JobGen.generate(seed, tier)
		assert(equal(layout, JobGen.generate(seed, tier)), "Same seed must produce same layout")
		assert(layout.seed == seed and layout.tier == tier, "Preserve layout identity")
		assert(#layout.items == Config.ItemCount[tier], "Tier manifest size")
		assert(
			#layout.rooms >= Config.RoomCount[tier][1]
				and #layout.rooms <= Config.RoomCount[tier][2],
			"Tier room count bounds"
		)
		local occupied, stairs, cells = {}, 0, {}
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for roomIndex, room in layout.rooms do
			minX, maxX = math.min(minX, room.gridX), math.max(maxX, room.gridX)
			minZ, maxZ = math.min(minZ, room.gridZ), math.max(maxZ, room.gridZ)
			local def = RoomDefs[room.template]
			assert(
				def
					and room.quarterTurns % 1 == 0
					and room.quarterTurns >= 0
					and room.quarterTurns < 4,
				"Known template with cardinal rotation"
			)
			if def.floors == 2 then
				stairs += 1
			end
			for floor = room.floor, room.floor + def.floors - 1 do
				local key = cell(room.gridX, room.gridZ, floor)
				assert(
					not occupied[key],
					"Room bounding cells must not overlap, including stairs upper floor"
				)
				occupied[key] = roomIndex
				table.insert(cells, { room.gridX, room.gridZ, floor })
			end
		end
		assert(stairs == (if tier == "Starter" then 0 else 1), "Tier staircase requirement")
		assert(
			maxX - minX < Config.RoomGridWidth and maxZ - minZ < Config.RoomGridWidth,
			"House fits authored lot/delivery footprint"
		)
		for _, c in cells do
			assert(
				c[3] == 0 or occupied[cell(c[1], c[2], 0)],
				"Upper rooms need a ground footprint"
			)
		end
		local reached = {}
		local queue = { cells[1] }
		reached[cell(unpack(cells[1]))] = true
		local cursor = 1
		while cursor <= #queue do
			local c = queue[cursor]
			cursor += 1
			for _, d in
				{ { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }
			do
				local nextCell = { c[1] + d[1], c[2] + d[2], c[3] + d[3] }
				local key = cell(unpack(nextCell))
				local originRoom, nextRoom = occupied[cell(unpack(c))], occupied[key]
				local verticalAllowed = d[3] == 0
					or (
						nextRoom == originRoom
						and RoomDefs[layout.rooms[originRoom].template].floors == 2
					)
				if nextRoom and not reached[key] and verticalAllowed then
					reached[key] = true
					table.insert(queue, nextCell)
				end
			end
		end
		assert(#queue == #cells, "Every room must be reachable through doors/stairs")
		local used, couch, hero = {}, false, false
		for _, item in layout.items do
			local room = layout.rooms[item.roomIndex]
			local size = if ItemDefs[item.itemId].carry == "Two" then "large" else "small"
			assert(
				table.find(RoomDefs[room.template][size], item.socketName),
				"Manifest needs matching socket"
			)
			local key = `{item.roomIndex}:{item.socketName}`
			assert(not used[key], "One item per socket")
			used[key] = true
			couch = couch or item.itemId == "couch"
			hero = hero or item.itemId == "piano" or item.itemId == "aquarium"
		end
		assert(tier ~= "Starter" or couch, "Starter always has couch")
		assert(tier ~= "Big" or hero, "Big always has piano or aquarium")
		variants[layout.rooms[1].template] = true
	end
end
assert(
	equal(JobGen.generate(-123, "Starter"), JobGen.generate(-123, "Starter")),
	"Negative seeds deterministic"
)
assert(
	not equal(JobGen.generate(1, "Big"), JobGen.generate(2, "Big")),
	"Different seeds vary layouts"
)
rejects(function()
	JobGen.generate(0 / 0, "Starter")
end)
rejects(function()
	JobGen.generate(1, "Unknown")
end)
print(
	"PASS Economy thresholds/prices; Payout floors/shares/stars; JobGen 1000 seeds x 3 tiers, socket/overlap/reachability/determinism"
)
