--!strict
-- Client reads; only the designated server owner writes.
return {
	Furniture = {
		ItemId = { type = "string", owner = "ItemService" },
		ItemUid = { type = "string", owner = "ItemService" },
		CrewId = { type = "string", owner = "ItemService" },
		HP = { type = "number", owner = "DamageService", min = 0, max = 100 },
		State = { type = "ItemState", owner = "ItemService" },
		CarrierA = { type = "number", owner = "ItemService", default = 0 },
		CarrierB = { type = "number", owner = "ItemService", default = 0 },
		-- Physical attachment held by CarrierA; CarrierB holds the other one.
		LeadGrip = { type = "number", owner = "ItemService", min = 1, max = 2, default = 1 },
		BlameUserId = { type = "number", owner = "DamageService" },
		Strapped = { type = "boolean", owner = "ItemService", default = false },
		Wrapped = { type = "boolean", owner = "ItemService", default = false },
		Dolly = { type = "boolean", owner = "ItemService", default = false },
	},
	Truck = {
		CrewId = { type = "string", owner = "TruckService" },
		DriverUserId = { type = "number", owner = "TruckService", default = 0 },
		-- Optional finite positive overrides. Absent values use Config.Truck.
		MD_MaxSpeed = { type = "number", owner = "TruckService", min = 0 },
		MD_MaxSteerAngle = { type = "number", owner = "TruckService", min = 0 },
		MD_HighSpeedSteerAngle = { type = "number", owner = "TruckService", min = 0 },
		RampLoose = { type = "boolean", owner = "TruckService", default = false },
	},
	Player = {
		CrewId = { type = "string", owner = "CrewService" },
		Level = { type = "number", owner = "DataService" },
		Assist = { type = "boolean", owner = "DataService" },
	},
}
