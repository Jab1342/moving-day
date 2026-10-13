--!strict
local JobRules = {}
function JobRules.phase(current, manifest, atDestination)
	local total, finished, loaded, delivered = 0, 0, 0, 0
	for _, state in manifest do
		total += 1
		if state == "Delivered" or state == "Broken" then
			finished += 1
		end
		if state == "InTruck" or state == "Delivered" or state == "Broken" then
			loaded += 1
		end
		if state == "Delivered" then
			delivered += 1
		end
	end
	if total > 0 and finished == total then
		return "Payout"
	end
	if current == "Payout" then
		return current
	end
	if atDestination or delivered > 0 or current == "Unloading" then
		return "Unloading"
	end
	if total > 0 and loaded == total then
		return "Driving"
	end
	return current
end
function JobRules.deliverable(state, inTruck, inside)
	return inside and not inTruck and (state == "Idle" or state == "Carried")
end
return JobRules
