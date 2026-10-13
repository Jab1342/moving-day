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

type Rig = {
	model: Model,
	seat: VehicleSeat,
	chassis: BasePart,
	motors: { HingeConstraint },
	steering: { CylindricalConstraint },
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
	return { model = model, seat = seat, chassis = chassis, motors = motors, steering = steering }
end

local TruckController = {}

local tuning = DEFAULTS
local active: Rig? = nil
local stepConn: RBXScriptConnection? = nil

local function setMotors(rig: Rig, angularVelocity: number, torque: number)
	for _, motor in rig.motors do
		motor.AngularVelocity = angularVelocity
		motor.MotorMaxTorque = torque
	end
end

local function release(rig: Rig)
	setMotors(rig, 0, tuning.BrakeTorque)
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

	if throttle > 0 then
		if forwardSpeed < -2 then
			setMotors(rig, 0, tuning.BrakeTorque) -- braking out of reverse
		else
			-- negative angular velocity about +X rolls the truck toward -Z
			setMotors(rig, -throttle * tuning.MaxSpeed / radius, tuning.DriveTorque)
		end
	elseif throttle < 0 then
		if forwardSpeed > 2 then
			setMotors(rig, 0, tuning.BrakeTorque) -- braking
		else
			setMotors(rig, -throttle * tuning.ReverseSpeed / radius, tuning.DriveTorque)
		end
	else
		setMotors(rig, 0, tuning.DriveTorque * 0.15) -- gentle engine braking, lets cargo shift on hard stops only when braking
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
	tuning = loadTuning()

	local player = Players.LocalPlayer
	if player.Character then
		bindCharacter(player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)
end

return TruckController
