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
	-- Steering servos: at the template's responsiveness (45) the front wheels wandered +-5-12
	-- degrees at speed and the truck drifted ~12 studs sideways over 180 with no input.
	SteerResponsiveness = 200,
	SteerSpeed = 8, -- rad/s
	-- Straight-line assist: with no steering input above HoldHeadingSpeed, steer back toward
	-- the heading you let go at (degrees of wheel per degree of heading error, capped).
	HoldHeadingSpeed = 10,
	HoldHeadingGain = 1.5,
	HoldHeadingMaxAngle = 4,
	-- Space/jump exits the seat; above this speed it's blocked so a stray jump can't throw
	-- the driver out mid-drive. Stop (or nearly) to hop out.
	ExitSpeed = 6,
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
local driver: Humanoid? = nil
local savedJump: { height: number, power: number }? = nil
local heldHeading: number? = nil -- degrees, set when steering input goes to zero

-- Jump height 0 keeps a seated humanoid in its seat; restore it when slow or getting out.
local function lockJump(locked: boolean)
	if not driver then
		return
	end
	if locked and not savedJump then
		savedJump = { height = driver.JumpHeight, power = driver.JumpPower }
		driver.JumpHeight = 0
		driver.JumpPower = 0
	elseif not locked and savedJump then
		driver.JumpHeight = savedJump.height
		driver.JumpPower = savedJump.power
		savedJump = nil
	end
end

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

	-- stay locked until a jump held through the stop is released, or it fires on unlock
	local jumpHeld = savedJump ~= nil and driver ~= nil and driver.Jump
	lockJump(math.abs(forwardSpeed) > tuning.ExitSpeed or jumpHeld == true)

	local speedFactor = math.clamp(math.abs(forwardSpeed) / tuning.MaxSpeed, 0, 1)
	local maxAngle = tuning.MaxSteerAngle
		+ (tuning.HighSpeedSteerAngle - tuning.MaxSteerAngle) * speedFactor
	-- positive SteerFloat = right; servo angle is about +Y, so right turn is negative
	local angle = -steer * maxAngle
	local _, yaw = rig.chassis.CFrame:ToOrientation() -- +yaw = turned left
	local heading = math.deg(yaw)
	if math.abs(steer) < 0.05 and forwardSpeed > tuning.HoldHeadingSpeed then
		heldHeading = heldHeading or heading
		local err = ((heldHeading :: number) - heading + 180) % 360 - 180
		angle = math.clamp(
			err * tuning.HoldHeadingGain,
			-tuning.HoldHeadingMaxAngle,
			tuning.HoldHeadingMaxAngle
		)
	else
		heldHeading = nil
	end
	for _, servo in rig.steering do
		servo.TargetAngle = angle
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
	lockJump(false)
	heldHeading = nil
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
	-- the driver's client simulates the truck, so these local servo settings are what count
	for _, servo in rig.steering do
		servo.AngularResponsiveness = tuning.SteerResponsiveness
		servo.AngularSpeed = tuning.SteerSpeed
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
	driver = humanoid
	savedJump = nil
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
