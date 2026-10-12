--!strict
return table.freeze({
	ItemState = table.freeze({
		Idle = "Idle",
		Carried = "Carried",
		InTruck = "InTruck",
		Delivered = "Delivered",
		Broken = "Broken",
	}),
	CarryMode = table.freeze({ One = "One", Two = "Two" }),
	Tier = table.freeze({ Starter = "Starter", Family = "Family", Big = "Big" }),
	JobPhase = table.freeze({
		Loading = "Loading",
		Driving = "Driving",
		Unloading = "Unloading",
		Payout = "Payout",
	}),
	ItemEvent = table.freeze({
		Damaged = "Damaged",
		Broken = "Broken",
		Loaded = "Loaded",
		Delivered = "Delivered",
	}),
	CrewAction = table.freeze({ Join = "Join", Leave = "Leave", Start = "Start", Kick = "Kick" }),
	StrapAction = table.freeze({ Strap = "Strap", Wrap = "Wrap" }),
	-- Proposed stable ping IDs, matching the order in the spec.
	Ping = table.freeze({
		Lift = 1,
		Drop = 2,
		Stop = 3,
		Go = 4,
		PivotLeft = 5,
		PivotRight = 6,
		OverHere = 7,
		Nice = 8,
	}),
})
