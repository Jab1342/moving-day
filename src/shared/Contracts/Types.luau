--!strict
export type ItemState = "Idle" | "Carried" | "InTruck" | "Delivered" | "Broken"
export type CarryMode = "One" | "Two"
export type Tier = "Starter" | "Family" | "Big"
export type JobPhase = "Loading" | "Driving" | "Unloading" | "Payout"
export type CrewAction = "Join" | "Leave" | "Start" | "Kick"
export type StrapAction = "Strap" | "Wrap"
export type ItemEventKind = "Damaged" | "Broken" | "Loaded" | "Delivered"
export type SettingKey = "assist"
export type ItemDef = {
	id: string,
	displayName: string,
	carry: CarryMode,
	value: number,
	fragility: number,
	massScale: number,
	model: string,
	fractured: string,
	impactSound: string?,
}
export type JobState = {
	jobId: string,
	crewId: string,
	tier: Tier,
	lotId: number,
	phase: JobPhase,
	startedAt: number,
	softEndsAt: number,
	manifest: { [string]: ItemState },
}
export type PayoutLine = {
	itemUid: string,
	itemId: string,
	valueKept: number,
	valueLost: number,
	blameUserId: number?,
}
export type PayoutReport = {
	jobId: string,
	lines: { PayoutLine },
	jobFee: number,
	timeBonus: number,
	total: number,
	perPlayer: number,
	xpEach: number,
	stars: number,
	nextJob: { tier: Tier, lotId: number },
}
export type Profile = {
	version: number,
	cash: number,
	xp: number,
	level: number,
	upgrades: { [string]: number },
	cosmetics: { [string]: boolean },
	catalog: { [string]: boolean },
	stats: { jobs: number, delivered: number, broken: number, moneyLost: number },
	streak: { lastDay: number, count: number },
	settings: { assist: boolean },
	firstJobDone: boolean,
	purchases: { [string]: boolean },
}
-- PROPOSED H0 definitions: referenced but not specified in the PDF. ClaudeA must review.
export type PublicProfile = {
	cash: number,
	xp: number,
	level: number,
	upgrades: { [string]: number },
	cosmetics: { [string]: boolean },
	settings: { assist: boolean },
	firstJobDone: boolean,
}
export type CrewState = {
	crewId: string?,
	padId: number?,
	leaderUserId: number?,
	memberUserIds: { number },
	autoStartsAt: number?,
	jobId: string?,
}
export type JobResult = {
	jobId: string,
	tier: Tier,
	elapsedSeconds: number,
	assist: boolean,
	lines: { PayoutLine },
	nextJob: { tier: Tier, lotId: number },
}
export type RoomPlacement = {
	template: string,
	gridX: number,
	gridZ: number,
	floor: number,
	quarterTurns: number,
}
export type ItemSocket = { roomIndex: number, socketName: string, itemId: string }
export type HouseLayout = {
	seed: number,
	tier: Tier,
	rooms: { RoomPlacement },
	items: { ItemSocket },
}
export type DamageMods = { protection: number, assist: boolean }
export type DamageModelAPI = { impactDamage: (number, ItemDef, DamageMods) -> number }
export type PayoutAPI = { compute: (JobResult, number) -> PayoutReport }
export type EconomyAPI =
	{ levelForXp: (number) -> number, upgradePrice: (string, number) -> number }
export type JobGenAPI = { generate: (number, Tier) -> HouseLayout }
return {}
