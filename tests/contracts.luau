local config = require("../src/shared/Config")
local items = require("../src/shared/ItemDefs")
local upgrades = require("../src/shared/UpgradeDefs")
local remotes = require("../src/shared/Contracts/Remotes")
local enums = require("../src/shared/Contracts/Enums")
local attributes = require("../src/shared/Contracts/Attributes")
local carry = require("../src/shared/Contracts/Carry")
local count = 0
local models = {}
for id, def in items do
	count += 1
	assert(id == def.id and def.value > 0 and def.fragility > 0, "Catalogue identity and values")
	assert(def.carry == "One" or def.carry == "Two", "Valid carry mode")
	assert(
		string.sub(def.model, 1, 4) == "FUR_" and def.fractured == def.model .. "_Frac",
		"Model names match contract"
	)
	assert(not models[def.model], "Duplicate model")
	models[def.model] = true
end
assert(count == 15, "Spec requires 15 furniture definitions")
assert(items.piano.value == 600 and items.vase.fragility == 2.5, "Piano and vase match spec")
assert(items.couch.carry == "Two" and items.box.carry == "One", "Couch and box carry modes")
count = 0
local functions = 0
for path, def in remotes do
	count += 1
	assert(string.match(path, "^%w+%.%w+$"), "Remote path uses one folder and name")
	if def.className == "RemoteFunction" then
		functions += 1
		assert(def.direction == "ClientToServer", "InvokeClient forbidden")
	end
	if def.direction == "ClientToServer" then
		assert(
			type(def.checks) == "string" and #def.checks > 0,
			"Client request validation documented"
		)
	end
end
assert(count == 18 and functions == 5, "18 remotes and 5 functions with proposed purchase contract")
assert(remotes["Fx.Ragdoll"].direction == "ServerToClient", "Ragdoll is server-driven")
assert(string.find(remotes["Job.ItemEvent"].args, "ItemEventInfo", 1, true), "VFX snapshot payload")
assert(attributes.Furniture.Dolly.owner == "ItemService", "Dolly is server-owned")
assert(
	carry.Attachment == "CarryAttachment" and carry.PositionMode == "OneAttachment",
	"Carry rig contract"
)
assert(
	config.Truck.WheelRadius == 1.5 and config.Truck.MaxSpeed == 60,
	"Truck tuning matches review"
)
assert(
	remotes["Carry.SecondGrip"].className == "UnreliableRemoteEvent",
	"Grip uses unreliable transport"
)
assert(remotes["Carry.SecondGripRelay"].direction == "ServerToLead", "Grip relay targets lead")
assert(config.MaxProtection == 0.5 and config.GrabRange == 8, "Protection and range match spec")
assert(config.MaxCrews * config.MaxCrewSize == 16, "16 player capacity")
assert(attributes.Furniture.HP.max == config.ItemMaxHP, "HP schema agrees with config")
assert(attributes.Furniture.State.owner == "ItemService", "ItemService owns state")
assert(enums.Ping.Nice == 8, "Eight ping IDs")
for _, upgrade in upgrades do
	assert(#upgrade.prices > 0, "Upgrade has priced tiers")
	for _, price in upgrade.prices do
		assert(price > 0 and price % 1 == 0, "Positive integer tier price")
	end
end
assert(
	upgrades.Dolly.freeSolo and upgrades.Straps.prices[3] == 1200,
	"Free solo dolly and strap prices"
)
print("PASS: H0 contract, catalogue, tuning and upgrade consistency")
