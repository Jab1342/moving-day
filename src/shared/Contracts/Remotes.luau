--!strict
-- Dot-separated names map to folders: Shared.Remotes.Carry.RequestGrab, etc.
-- Payloads are positional arguments; RemoteFunctions return (ok: boolean, reason: string?).
return {
	["Carry.RequestGrab"] = {
		className = "RemoteFunction",
		direction = "ClientToServer",
		args = "itemUid: string, grip: 1 | 2",
		checks = "same crew; range <= Config.GrabRange; grip free; not Broken",
	},
	["Carry.RequestDrop"] = {
		className = "RemoteEvent",
		direction = "ClientToServer",
		args = "itemUid: string",
		checks = "caller is a carrier",
	},
	["Carry.SecondGrip"] = {
		className = "UnreliableRemoteEvent",
		direction = "ClientToServer",
		args = "itemUid: string, handPos: Vector3",
		checks = "caller holds grip 2; finite vector; Config.SecondGripHz; relay to lead",
	},
	["Carry.SecondGripRelay"] = {
		className = "UnreliableRemoteEvent",
		direction = "ServerToLead",
		args = "itemUid: string, userId: number, handPos: Vector3",
	},
	["Carry.RequestStrap"] = {
		className = "RemoteFunction",
		direction = "ClientToServer",
		args = "itemUid: string, action: StrapAction",
		checks = "own truck bed for Strap, held for Wrap; slots; cash",
	},
	["Ping.Send"] = {
		className = "RemoteEvent",
		direction = "ClientToServer",
		args = "pingId: number, worldPos: Vector3?",
		checks = "valid ping; finite vector; Config.PingPerSecond",
	},
	["Ping.Broadcast"] = {
		className = "RemoteEvent",
		direction = "ServerToCrew",
		args = "userId: number, pingId: number, worldPos: Vector3?",
	},
	["Crew.Action"] = {
		className = "RemoteFunction",
		direction = "ClientToServer",
		args = "action: CrewAction, arg: number?",
		checks = "capacity; leader-only Start/Kick; target membership",
	},
	["Crew.State"] = {
		className = "RemoteEvent",
		direction = "ServerToClient",
		args = "state: CrewState",
	},
	["Job.State"] = {
		className = "RemoteEvent",
		direction = "ServerToCrew",
		args = "state: JobState",
	},
	["Job.ItemEvent"] = {
		className = "RemoteEvent",
		direction = "ServerToCrew",
		args = "itemUid: string, kind: ItemEventKind, hp: number, info: ItemEventInfo?",
		notes = "info required on Damaged and Broken; snapshot before destroying item",
	},
	["Fx.Ragdoll"] = {
		className = "RemoteEvent",
		direction = "ServerToClient",
		args = "duration: number, impulse: Vector3",
	},
	["Job.Payout"] = {
		className = "RemoteEvent",
		direction = "ServerToCrew",
		args = "report: PayoutReport",
	},
	["Shop.Buy"] = {
		className = "RemoteFunction",
		direction = "ClientToServer",
		args = "upgradeId: string, tier: number",
		checks = "at HQ; server price; prerequisites",
	},
	["Monetization.RequestPurchase"] = {
		className = "RemoteFunction",
		direction = "ClientToServer",
		args = "sku: PurchaseSku, jobId: string?",
		checks = "rate limit; profile and verified pass state ready; configured/implemented SKU; first grab; one prompt per job; job context; no outstanding prompt; no client price or grant",
		notes = "server opens Roblox prompt after validation; ok means prompt requested, never purchase granted; unsupported effects return NotReady",
	},
	["Monetization.State"] = {
		className = "RemoteEvent",
		direction = "ServerToClient",
		args = "state: MonetizationState",
		notes = "pass ownership comes from Roblox server API; availability requires real configured IDs and implemented effects",
	},
	["Data.Profile"] = {
		className = "RemoteEvent",
		direction = "ServerToClient",
		args = "profile: PublicProfile",
	},
	["Settings.Set"] = {
		className = "RemoteEvent",
		direction = "ClientToServer",
		args = "key: SettingKey, value: boolean",
		checks = "assist only; boolean",
	},
}
