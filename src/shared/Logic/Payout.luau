--!strict
local Config = if script then require(script.Parent.Parent.Config) else require("../Config")
local ItemDefs = if script then require(script.Parent.Parent.ItemDefs) else require("../ItemDefs")
local Payout = {}

local function nonnegative(value: number): boolean
	return type(value) == "number" and value == value and value >= 0 and value < math.huge
end

-- JobResult is assembled by the server after delivery; this never grants currency.
-- Fees are a guaranteed floor, including Assist/all-broken jobs. Crew scaling applies
-- to kept value and the declining time bonus. Pass/receipt grants are separate.
function Payout.compute(result, crewSize: number)
	assert(
		crewSize % 1 == 0 and crewSize >= 1 and crewSize <= Config.MaxCrewSize,
		"Invalid crew size"
	)
	assert(#result.memberUserIds == crewSize, "Recipient count must match crew size")
	assert(Config.JobFee[result.tier] ~= nil, "Unknown job tier")
	assert(nonnegative(result.elapsedSeconds), "Invalid elapsed time")
	assert(Config.JobFee[result.nextJob.tier] ~= nil, "Unknown next job tier")
	assert(
		result.nextJob.lotId % 1 == 0
			and result.nextJob.lotId >= 1
			and result.nextJob.lotId <= Config.MaxCrews,
		"Invalid next lot"
	)
	local recipients = {}
	for _, userId in result.memberUserIds do
		-- Studio test clients use negative IDs; zero and fractional IDs are invalid.
		assert(type(userId) == "number" and userId ~= 0 and userId % 1 == 0, "Invalid recipient")
		local key = tostring(userId)
		assert(not recipients[key], "Duplicate recipient")
		recipients[key] = true
	end
	local lines, seen = {}, {}
	local kept, original = 0, 0
	for _, line in result.lines do
		assert(
			type(line.itemUid) == "string" and line.itemUid ~= "" and not seen[line.itemUid],
			"Invalid item UID"
		)
		seen[line.itemUid] = true
		local def = ItemDefs[line.itemId]
		assert(def ~= nil, "Unknown payout item")
		assert(nonnegative(line.valueKept) and nonnegative(line.valueLost), "Invalid item value")
		assert(line.valueKept + line.valueLost <= def.value, "Item value exceeds catalogue")
		table.insert(lines, table.clone(line))
		kept += line.valueKept
		original += line.valueKept + line.valueLost
	end
	local jobFee = Config.JobFee[result.tier]
	local timeBonus = math.floor(
		kept
			* Config.TimeBonusMax
			* math.clamp(1 - result.elapsedSeconds / Config.SoftTimer[result.tier], 0, 1)
	)
	local crewScale = if crewSize == 1
		then Config.SoloPayoutScale
		else Config.CrewPayoutScale[crewSize]
	local assistScale = if result.assist then Config.AssistPayoutScale else 1
	local total =
		math.max(jobFee, math.floor((jobFee + (kept + timeBonus) * crewScale) * assistScale))
	local perPlayer = math.floor(total / crewSize)
	local remainder = total - perPlayer * crewSize
	local shares = {}
	for index, userId in result.memberUserIds do
		shares[tostring(userId)] = perPlayer + (if index <= remainder then 1 else 0)
	end
	local intactFraction = if original > 0 then kept / original else 0
	local stars = 1
	for index, band in Config.PayoutStarBands do
		if intactFraction >= band then
			stars = index
		end
	end
	return {
		jobId = result.jobId,
		lines = lines,
		jobFee = jobFee,
		timeBonus = timeBonus,
		total = total,
		perPlayer = perPlayer,
		shares = shares,
		xpEach = math.floor((Config.JobXp[result.tier] + kept * Config.XpPerKeptDollar) / crewSize),
		stars = stars,
		nextJob = table.clone(result.nextJob),
	}
end

return Payout
