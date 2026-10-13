--!strict
local Config = if script then require(script.Parent.Parent.Config) else require("../Config")
local Benefits = {}
function Benefits.apply(base, recipients, passes, assist)
	assert(base.bonuses == nil, "Pass benefits must be applied once to a base payout")
	local count = #recipients
	assert(count >= 1 and count <= Config.MaxCrewSize, "Invalid recipients")
	local kept = 0
	for _, line in base.lines do
		kept += line.valueKept
	end
	local scale = if count == 1 then Config.SoloPayoutScale else Config.CrewPayoutScale[count]
	local withoutTip = math.max(
		base.jobFee,
		math.floor((base.jobFee + kept * scale) * (if assist then Config.AssistPayoutScale else 1))
	)
	local tips = math.max(0, base.total - withoutTip)
	local tipEach, tipRemainder = math.floor(tips / count), tips % count
	local report = table.clone(base)
	report.shares, report.bonuses, report.total = {}, {}, 0
	for index, userId in recipients do
		local key = tostring(userId)
		assert(
			base.shares[key] ~= nil and report.shares[key] == nil,
			"Invalid or duplicate recipient"
		)
		local owns = passes[key] or {}
		local tip = tipEach + (if index <= tipRemainder then 1 else 0)
		local vip = if owns.VIPForeman == true then math.floor(tip * Config.VIPTipBonusScale) else 0
		local multiplier = if owns.DoublePay == true then Config.DoublePayMultiplier else 1
		local share = math.floor((base.shares[key] + vip) * multiplier)
		report.shares[key] = share
		report.bonuses[key] = share - base.shares[key]
		report.total += share
	end
	report.perPlayer = math.floor(report.total / count)
	return report
end
return Benefits
