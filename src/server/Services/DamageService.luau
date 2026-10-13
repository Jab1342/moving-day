--!nonstrict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local DamageModel = require(Shared.Logic.DamageModel)
local DamageService = {}
DamageService.__index = DamageService

function DamageService.new(items)
	return setmetatable({ items = items }, DamageService)
end

function DamageService:Initialize(rec)
	rec.model:SetAttribute("HP", Config.ItemMaxHP)
	rec.model:SetAttribute("BlameUserId", 0)
end

function DamageService:Step()
	local now = os.clock()
	for _, rec in self.items.records do
		local velocity = rec.root.AssemblyLinearVelocity
		local previous = rec.previousVelocity or velocity
		rec.previousVelocity = velocity
		if
			rec.state == "Delivered"
			or now < rec.graceUntil
			or now - rec.lastDamageAt < Config.DamageCooldownSeconds
		then
			continue
		end
		local deltaV = (velocity - previous).Magnitude
		local blame = if rec.truck then rec.truck.driverId else rec.lastCarrier
		local player = Players:GetPlayerByUserId(blame)
		local damage = DamageModel.impactDamage(deltaV, rec.def, {
			protection = if rec.model:GetAttribute("Wrapped") then Config.BlanketProtection else 0,
			assist = player ~= nil and player:GetAttribute("Assist") == true,
		})
		if damage <= 0 then
			continue
		end
		rec.lastDamageAt = now
		local hp = math.max(0, rec.model:GetAttribute("HP") - damage)
		rec.model:SetAttribute("HP", hp)
		rec.model:SetAttribute("BlameUserId", blame)
		local info = { itemId = rec.def.id, cframe = rec.model:GetPivot(), velocity = velocity }
		self.items:Fire(rec, if hp == 0 then "Broken" else "Damaged", info)
		if hp == 0 then
			self.items:Remove(rec, true)
		end
	end
end

return DamageService
