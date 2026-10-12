--!strict
-- Free solo dolly is an entitlement, tier 1/2 are purchased speed tiers.
-- STUB(Codex): dolly tier speeds and suspension/box-truck tuning await feel tests.
return {
	Dolly = {
		displayName = "Dolly",
		freeSolo = true,
		prices = { 300, 900 },
		tradeoff = "Reduced walking speed",
	},
	Straps = {
		displayName = "Straps",
		prices = { 250, 600, 1200 },
		tradeoff = "Time to strap each item",
	},
	MovingBlankets = {
		displayName = "Moving blankets",
		prices = { 400 },
		tradeoff = "Cash and time per wrap",
	},
	LoadingRamp = {
		displayName = "Loading ramp",
		prices = { 500 },
		tradeoff = "Can be knocked loose",
	},
	BoxTruck = {
		displayName = "Box truck",
		prices = { 2000 },
		tradeoff = "Top-heavy; slower turning",
	},
	SoftSuspension = {
		displayName = "Soft suspension",
		prices = { 1500 },
		tradeoff = "Lower top speed",
	},
}
