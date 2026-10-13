--!strict
-- Drives the crew truck from the driver's client. The driver is the network owner of the
-- truck (TruckService sets it), so motor and steering changes made here are simulated here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local DEFAULTS = {
	MaxSpeed = 60, -- studs/s at full throttle
	ReverseSpeed = 22,
	MaxSteerAngle = 32, -- degrees at standstill
	HighSpeedSteerAngle = 12, -- degrees at MaxSpeed
	DriveTorque = 30000,
	BrakeTorque = 60000,
	WheelRadius = 1.5,
	-- Arcade brakes: wheel motors alone stop the truck far too slowly, so braking also
	-- pushes the chassis back at this fraction of gravity. Hard stops are what shift cargo.
	-- While braking above HoldSpeed the wheels roll free and only that force slows the truck,
	-- so a full stop is exactly BrakeDecelG (locked wheels on top measured > 1.1 g from 60).
	BrakeDecelG = 0.65,
	CoastDecelG = 0.05,
	HoldSpeed = 2, -- below this the wheel motors lock to hold the truck still
	MotorMaxAcceleration = 400, -- lets locked wheels actually lock
	-- Launch cap: drive torque is limited to what pushes the truck's mass at DriveAccelG
	-- (0-60 in ~1 s). At full DriveTorque it launched at ~1 g and threw loose cargo out.
	DriveAccelG = 0.3,
}

local function loadTuning()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local configModule = shared and shared:FindFirstChild("Config")
	if configModule and configModule:IsA("ModuleScript") then
		local ok, config = pcall(require, configModule)
		if ok and type(config) == "table" and type(config.Truck) == "table" then
			local merged = table.clone(DEFAULTS)
			for k, v in config.Truck do
				merged[k] = v
			end
			return merged
		end
	end
	return DEFAULTS
end

-- Per-truck overrides (upgrades): a number attribute MD_<Key> on the truck model replaces
-- that tuning value, e.g. MD_MaxSpeed on a soft-suspension truck, MD_MaxSteerAngle on a box truck.
local function withTruckOverrides(base: typeof(DEFAULTS), model: Model): typeof(DEFAULTS)
	local merged = table.clone(base)
	for key in DEFAULTS do
		local value = model:GetAttribute("MD_" .. key)
		if type(value) == "number" then
			merged[key] = value
		end
	end
	return merged
end

type Rig = {
	model: Model,
	seat: VehicleSeat,
	chassis: BasePart,
	motors: { HingeConstraint },
	steering: { CylindricalConstraint },
	brake: VectorForce,
}

local function findRig(seat: VehicleSeat): Rig?
	local model = seat:FindFirstAncestorOfClass("Model")
	while model and not model:FindFirstChild("Wheels") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	if not model then
		return nil
	end
	local wheels = model:FindFirstChild("Wheels")
	local chassis = model.PrimaryPart
	if not wheels or not chassis then
		return nil
	end
	local motors, steering = {}, {}
	for _, inst in wheels:GetDescendants() do
		if inst:IsA("HingeConstraint") and inst.Name == "Motor" then
			table.insert(motors, inst)
		elseif
			inst:IsA("CylindricalConstraint")
			and inst.AngularActuatorType == Enum.ActuatorType.Servo
		then
			table.insert(steering, inst)
		end
	end

	-- client-local brake force (the driver owns the truck, so it simulates here)
	local brake = chassis:FindFirstChild("MD_BrakeForce") :: VectorForce?
	if not brake then
		local attachment = Instance.new("Attachment")
		attachment.Name = "MD_BrakeAttachment"
		attachment.Parent = chassis
		local force = Instance.new("VectorForce")
		force.Name = "MD_BrakeForce"
		force.Attachment0 = attachment
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass = true
		force.Force = Vector3.zero
		force.Parent = chassis
		brake = force
	end
	return {
		model = model,
		seat = seat,
		chassis = chassis,
		motors = motors,
		steering = steering,
		brake = brake :: VectorForce,
	}
end

local TruckController = {}

local baseTuning = DEFAULTS
local tuning = DEFAULTS
local active: Rig? = nil
local stepConn: RBXScriptConnection? = nil

local function setMotors(rig: Rig, angularVelocity: number, torque: number)
	for _, motor in rig.motors do
		motor.AngularVelocity = angularVelocity
		motor.MotorMaxTorque = torque
	end
end

local function setBrake(rig: Rig, decelG: number)
	local v = rig.chassis.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	if decelG <= 0 or flat.Magnitude < 2 then
		rig.brake.Force = Vector3.zero
		return
	end
	rig.brake.Force = -flat.Unit * rig.chassis.AssemblyMass * workspace.Gravity * decelG
end

local function release(rig: Rig)
	setMotors(rig, 0, tuning.BrakeTorque)
	rig.brake.Force = Vector3.zero
	for _, servo in rig.steering do
		servo.TargetAngle = 0
	end
end

local function step(rig: Rig)
	local throttle = rig.seat.ThrottleFloat
	local steer = rig.seat.SteerFloat
	-- the chassis LookVector (-Z) is the truck's front
	local forwardSpeed = rig.chassis.CFrame.LookVector:Dot(rig.chassis.AssemblyLinearVelocity)
	local radius = tuning.WheelRadius
	-- per-wheel torque that accelerates the whole truck (cargo included) at DriveAccelG
	local driveTorque = math.min(
		tuning.DriveTorque,
		rig.chassis.AssemblyMass
			* tuning.DriveAccelG
			* workspace.Gravity
			* radius
			/ math.max(#rig.motors, 1)
	)

	if throttle > 0 then
		if forwardSpeed < -tuning.HoldSpeed then
			setMotors(rig, 0, 0) -- braking out of reverse: free wheels, brake force only
			setBrake(rig, tuning.BrakeDecelG)
		else
			-- negative angular velocity about +X rolls the truck toward -Z
			setMotors(rig, -throttle * tuning.MaxSpeed / radius, driveTorque)
			-- wheel slip lets the truck creep past MaxSpeed downhill; trim it back gently
			setBrake(rig, if forwardSpeed > tuning.MaxSpeed then 0.15 else 0)
		end
	elseif throttle < 0 then
		if forwardSpeed > tuning.HoldSpeed then
			setMotors(rig, 0, 0) -- braking: free wheels, brake force only
			setBrake(rig, tuning.BrakeDecelG)
		else
			setMotors(rig, -throttle * tuning.ReverseSpeed / radius, driveTorque)
			setBrake(rig, 0)
		end
	else
		setMotors(rig, 0, tuning.DriveTorque * 0.15) -- gentle engine braking
		setBrake(rig, tuning.CoastDecelG)
	end

	local speedFactor = math.clamp(math.abs(forwardSpeed) / tuning.MaxSpeed, 0, 1)
	local maxAngle = tuning.MaxSteerAngle
		+ (tuning.HighSpeedSteerAngle - tuning.MaxSteerAngle) * speedFactor
	for _, servo in rig.steering do
		-- positive SteerFloat = right; servo angle is about +Y, so right turn is negative
		servo.TargetAngle = -steer * maxAngle
	end
end

-- Horn: H / L3 / touch button while driving. Local-only sound for v1.
local function onHorn(_, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin or not active then
		return Enum.ContextActionResult.Pass
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local horn = assets
		and assets:FindFirstChild("Sounds")
		and assets.Sounds:FindFirstChild("SFX_Horn")
	if horn and horn:IsA("Sound") then
		local s = horn:Clone()
		s.Parent = active.chassis
		s:Play()
		task.delay(3, function()
			s:Destroy()
		end)
	end
	return Enum.ContextActionResult.Sink
end

local function onSeated(isSeated: boolean, seatPart: BasePart?)
	if active then
		release(active)
		active = nil
	end
	if stepConn then
		stepConn:Disconnect()
		stepConn = nil
	end
	ContextActionService:UnbindAction("MD_Horn")
	if not isSeated or not seatPart or not seatPart:IsA("VehicleSeat") then
		return
	end
	local rig = findRig(seatPart)
	if not rig then
		return
	end
	active = rig
	tuning = withTruckOverrides(baseTuning, rig.model)
	for _, motor in rig.motors do
		motor.MotorMaxAcceleration = tuning.MotorMaxAcceleration
	end
	-- the horn button only exists while you're driving
	ContextActionService:BindAction("MD_Horn", onHorn, true, Enum.KeyCode.H, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("MD_Horn", "Horn")
	stepConn = RunService.Heartbeat:Connect(function()
		if active and active.seat.Occupant then
			step(active)
		end
	end)
end

local function bindCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Seated:Connect(onSeated)
end

function TruckController.Start()
	baseTuning = loadTuning()
	tuning = baseTuning

	local player = Players.LocalPlayer
	if player.Character then
		bindCharacter(player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)
end

return TruckController
