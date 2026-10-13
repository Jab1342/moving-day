--!strict
-- Drag furniture with the cursor or a finger: press on an item to grab it, move to steer
-- it, release to drop. Input comes from a local DragDetector on each item (ResponseStyle
-- Custom, so it moves nothing itself and handles mouse/touch capture on every device).
-- Physics stays server-authorised: ItemService validates the grab, creates
-- CarryAlignPosition / CarryAlignOrientation on the item's Root and makes the lead carrier
-- (CarrierA) the network owner; the lead's client steers those constraints here. Grip 2
-- sends its cursor point to the server, which relays it to the lead.
-- Gamepad has no cursor, so ButtonX grabs the nearest item and holds it in front (no DragDetector input).

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local DEFAULTS = {
	GrabRange = 8,
	DragReach = 9, -- max horizontal distance between the player and the dragged point
	DollySpeedScale = 0.4,
	TwoCarrySpeedScale = 0.75,
	DragSpeedScale = 0.35,
	SoloHeavyMaxVelocity = 6, -- studs/s when one player hauls a two-person item alone
	SecondGripHz = 20,
	HoldHeight = 0.6, -- studs above the HumanoidRootPart for the grabbed point
	PadHoldDistance = 3.5, -- gamepad: studs in front of the player
	BedLiftRange = 14, -- near a truck bed, items lift to clear the tailgate
	BedClearance = 1.4, -- studs above the bed floor for the item's underside
}

local CarryController = {}

local tuning = table.clone(DEFAULTS)
local remotes: Folder? = nil
local held: Model? = nil
local myGrip = 0
local grabLocal = Vector3.zero -- grabbed point in the item's Root space
local yaw = 0 -- item yaw while held
local screenPoint: Vector2? = nil -- last cursor/touch position; nil = gamepad hold
local partnerPoint: Vector3? = nil
local lastSecondGripSend = 0
local baseWalkSpeed = 16
local grabbing = false

local function loadTuning()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local configModule = shared and shared:FindFirstChild("Config")
	if configModule and configModule:IsA("ModuleScript") then
		local ok, config = pcall(require, configModule)
		if ok and type(config) == "table" then
			for key in DEFAULTS do
				if type(config[key]) == "number" then
					tuning[key] = config[key]
				end
			end
		end
	end
end

local function remote(path: string): Instance?
	if not remotes then
		return nil
	end
	local group, name = string.match(path, "^([^.]+)%.([^.]+)$")
	local folder = group and remotes:FindFirstChild(group)
	return folder and name and folder:FindFirstChild(name) or nil
end

local function character(): (Model?, Humanoid?, BasePart?)
	local char = player.Character
	if not char then
		return nil, nil, nil
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return char, humanoid, root
end

local function itemRoot(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChild("Root") :: BasePart?
end

local function freeGrip(model: Model): number
	local state = model:GetAttribute("State")
	if state == "Broken" or state == "Delivered" then
		return 0
	end
	if (model:GetAttribute("CarrierA") or 0) == 0 then
		return 1
	elseif model:GetAttribute("Carry") == "Two" and (model:GetAttribute("CarrierB") or 0) == 0 then
		return 2
	end
	return 0
end

local function setWalkSpeed(scale: number)
	local _, humanoid = character()
	if humanoid then
		humanoid.WalkSpeed = baseWalkSpeed * scale
	end
end

local function clearHeld()
	if held then
		local root = itemRoot(held)
		local alignPos = root and root:FindFirstChild("CarryAlignPosition") :: AlignPosition?
		if alignPos then
			alignPos.MaxVelocity = math.huge
		end
	end
	held = nil
	myGrip = 0
	screenPoint = nil
	partnerPoint = nil
	setWalkSpeed(1)
end

local function grab(model: Model, hitPoint: Vector3?, atScreen: Vector2?)
	if held or grabbing then
		return
	end
	local grip = freeGrip(model)
	local requestGrab = remote("Carry.RequestGrab")
	local root = itemRoot(model)
	if grip == 0 or not root or not requestGrab or not requestGrab:IsA("RemoteFunction") then
		return
	end
	grabbing = true
	local ok, reason = requestGrab:InvokeServer(model:GetAttribute("ItemUid"), grip)
	grabbing = false
	if not ok then
		if reason then
			warn(`[Carry] grab refused: {reason}`)
		end
		return
	end
	held = model
	myGrip = grip
	screenPoint = atScreen
	partnerPoint = nil
	local _, ry = root.CFrame:ToOrientation()
	yaw = ry
	-- Two-person items are steered by their grips; one-person items by the clicked point.
	if model:GetAttribute("Carry") == "Two" then
		local g = root:FindFirstChild("Grip" .. grip) :: Attachment?
		grabLocal = if g then g.Position else Vector3.zero
	else
		grabLocal = if hitPoint then root.CFrame:PointToObjectSpace(hitPoint) else Vector3.zero
	end
	local _, humanoid = character()
	if humanoid then
		baseWalkSpeed = humanoid.WalkSpeed
	end
end

local function drop()
	local requestDrop = remote("Carry.RequestDrop")
	if held and requestDrop and requestDrop:IsA("RemoteEvent") then
		requestDrop:FireServer(held:GetAttribute("ItemUid"))
	end
	clearHeld()
end

-- DragDetector input on each furniture item (local only: RunLocally + Custom response).
local function attachDetector(model: Model)
	if model:FindFirstChild("MD_Drag") or not model:GetAttribute("ItemUid") then
		return
	end
	local detector = Instance.new("DragDetector")
	detector.Name = "MD_Drag"
	detector.RunLocally = true
	detector.ResponseStyle = Enum.DragDetectorResponseStyle.Custom
	detector.DragStyle = Enum.DragDetectorDragStyle.TranslateViewPlane
	detector.MaxActivationDistance = tuning.GrabRange + 6
	detector.CursorIcon = ""
	detector.Parent = model
	detector.DragStart:Connect(function(_who, cursorRay: Ray, _viewFrame, hitFrame: CFrame)
		local camera = Workspace.CurrentCamera
		local _, _, hrp = character()
		if not camera or not hrp then
			return
		end
		local hit = hitFrame.Position
		if (hit - hrp.Position).Magnitude > tuning.GrabRange + 4 then
			return -- too far: you have to walk up to furniture
		end
		local screen = camera:WorldToViewportPoint(cursorRay.Origin + cursorRay.Direction * 20)
		task.spawn(grab, model, hit, Vector2.new(screen.X, screen.Y))
	end)
	detector.DragContinue:Connect(function(_who, cursorRay: Ray)
		local camera = Workspace.CurrentCamera
		if held == model and camera then
			local screen = camera:WorldToViewportPoint(cursorRay.Origin + cursorRay.Direction * 20)
			screenPoint = Vector2.new(screen.X, screen.Y)
		end
	end)
	detector.DragEnd:Connect(function()
		if held == model then
			drop()
		end
	end)
end

local function watchFurniture()
	local function consider(inst: Instance)
		if inst:IsA("Model") and inst:GetAttribute("ItemUid") then
			attachDetector(inst)
		end
	end
	for _, d in Workspace:GetDescendants() do
		consider(d)
	end
	Workspace.DescendantAdded:Connect(consider)
end

-- Nearest grabbable item in front of the player (gamepad path).
local function nearestItem(): Model?
	local _, _, hrp = character()
	if not hrp then
		return nil
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local best: Model? = nil
	local bestScore = math.huge
	for _, part in Workspace:GetPartBoundsInRadius(hrp.Position, tuning.GrabRange, params) do
		local model = part:FindFirstAncestorWhichIsA("Model")
		if model and model:GetAttribute("ItemUid") and freeGrip(model) > 0 then
			local root = itemRoot(model)
			if root then
				local offset = root.Position - hrp.Position
				local score = offset.Magnitude - hrp.CFrame.LookVector:Dot(offset.Unit) * 3
				if score < bestScore then
					best, bestScore = model, score
				end
			end
		end
	end
	return best
end

local function onPadGrab(_, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if held then
		drop()
	else
		local target = nearestItem()
		if target then
			task.spawn(grab, target, nil, nil)
		end
	end
	return Enum.ContextActionResult.Sink
end

local function onRotate(_, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin or not held or myGrip ~= 1 then
		return Enum.ContextActionResult.Pass
	end
	yaw += math.pi / 2
	return Enum.ContextActionResult.Sink
end

-- World point the player is steering toward this frame: the spot on the ground under the
-- cursor/touch, lifted to `planeY` and clamped to arm's reach. Gamepad: in front of the player.
local function steerPoint(hrp: BasePart, planeY: number): Vector3
	local camera = Workspace.CurrentCamera
	local point: Vector3
	if screenPoint and camera then
		local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character :: Instance, held :: Instance }
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
		if hit then
			point = hit.Position
		else
			-- nothing under the cursor (sky): use the plane at the player's feet
			local feetY = hrp.Position.Y - 3
			local dy = ray.Direction.Y
			local t = if dy < -1e-3 then (feetY - ray.Origin.Y) / dy else 0
			point = if t > 0
				then ray.Origin + ray.Direction * t
				else hrp.Position + hrp.CFrame.LookVector * tuning.PadHoldDistance
		end
	else
		point = hrp.Position + hrp.CFrame.LookVector * tuning.PadHoldDistance
	end
	local flat = Vector3.new(point.X - hrp.Position.X, 0, point.Z - hrp.Position.Z)
	if flat.Magnitude > tuning.DragReach then
		flat = flat.Unit * tuning.DragReach
	end
	return Vector3.new(hrp.Position.X + flat.X, planeY, hrp.Position.Z + flat.Z)
end

-- Near a truck bed (tagged "TruckBed"), raise the target so the item's underside clears
-- the tailgate; otherwise loading would need a jump.
local function liftForBed(model: Model, root: BasePart, goal: CFrame): CFrame
	local best: BasePart? = nil
	local bestDist = tuning.BedLiftRange
	for _, bed in CollectionService:GetTagged("TruckBed") do
		if bed:IsA("BasePart") and bed:IsDescendantOf(Workspace) then
			local d = Vector3.new(bed.Position.X - goal.X, 0, bed.Position.Z - goal.Z).Magnitude
			if d < bestDist then
				best, bestDist = bed, d
			end
		end
	end
	if not best then
		return goal
	end
	local boxCf, boxSize = model:GetBoundingBox()
	local rootAboveBottom = root.Position.Y - (boxCf.Y - boxSize.Y / 2)
	local minY = best.Position.Y + best.Size.Y / 2 + tuning.BedClearance + rootAboveBottom
	if goal.Y >= minY then
		return goal
	end
	return goal + Vector3.new(0, minY - goal.Y, 0)
end

-- Item CFrame that puts the midpoint between its two grips at `mid`, with the grip axis
-- running from the lead toward the partner.
local function twoHandedCFrame(root: BasePart, mid: Vector3, toPartner: Vector3): CFrame?
	local g1 = root:FindFirstChild("Grip1") :: Attachment?
	local g2 = root:FindFirstChild("Grip2") :: Attachment?
	if not g1 or not g2 then
		return nil
	end
	local axis = g2.Position - g1.Position
	local flat = Vector3.new(toPartner.X, 0, toPartner.Z)
	if flat.Magnitude < 0.1 or Vector3.new(axis.X, 0, axis.Z).Magnitude < 0.1 then
		return nil
	end
	local worldYaw = math.atan2(-flat.X, -flat.Z)
	local localYaw = math.atan2(-axis.X, -axis.Z)
	local gripMid = (g1.Position + g2.Position) / 2
	return CFrame.new(mid) * CFrame.Angles(0, worldYaw - localYaw, 0) * CFrame.new(-gripMid)
end

local function stepLead(model: Model, root: BasePart, hrp: BasePart)
	local alignPos = root:FindFirstChild("CarryAlignPosition") :: AlignPosition?
	local alignOri = root:FindFirstChild("CarryAlignOrientation") :: AlignOrientation?
	if not alignPos or not alignOri then
		return
	end
	local carry = model:GetAttribute("Carry")
	local partnerId = model:GetAttribute("CarrierB") or 0
	local onDolly = model:GetAttribute("Dolly") == true
	local holdY = hrp.Position.Y + tuning.HoldHeight

	if carry == "Two" and partnerId ~= 0 and partnerPoint then
		setWalkSpeed(tuning.TwoCarrySpeedScale)
		alignPos.MaxVelocity = math.huge
		local mine = steerPoint(hrp, holdY)
		local target = twoHandedCFrame(root, (mine + partnerPoint) / 2, partnerPoint - mine)
		if target then
			target = liftForBed(model, root, target)
			alignPos.Position = target.Position
			alignOri.CFrame = target.Rotation
			return
		end
	end

	local rotation = CFrame.Angles(0, yaw, 0)
	local goal: CFrame
	if carry == "Two" and not onDolly then
		-- Alone on a two-person item: haul it along the floor, slowly.
		setWalkSpeed(tuning.DragSpeedScale)
		alignPos.MaxVelocity = tuning.SoloHeavyMaxVelocity
		local grabWorldY = (root.CFrame * CFrame.new(grabLocal)).Y
		local point = steerPoint(hrp, grabWorldY)
		goal = CFrame.new(point) * rotation * CFrame.new(-grabLocal)
		goal = CFrame.new(goal.X, root.Position.Y, goal.Z) * rotation
	else
		setWalkSpeed(if onDolly then tuning.DollySpeedScale else 1)
		alignPos.MaxVelocity = math.huge
		local planeY = if onDolly then hrp.Position.Y - 1.5 else holdY
		goal = CFrame.new(steerPoint(hrp, planeY)) * rotation * CFrame.new(-grabLocal)
		if not onDolly then
			goal = liftForBed(model, root, goal)
		end
	end
	alignPos.Position = goal.Position
	alignOri.CFrame = goal.Rotation
end

local function stepSecond(model: Model, hrp: BasePart, now: number)
	setWalkSpeed(tuning.TwoCarrySpeedScale)
	if now - lastSecondGripSend < 1 / tuning.SecondGripHz then
		return
	end
	lastSecondGripSend = now
	local send = remote("Carry.SecondGrip")
	if send and send:IsA("UnreliableRemoteEvent") then
		send:FireServer(
			model:GetAttribute("ItemUid"),
			steerPoint(hrp, hrp.Position.Y + tuning.HoldHeight)
		)
	end
end

local function step()
	local model = held
	if not model then
		return
	end
	local _, humanoid, hrp = character()
	local root = itemRoot(model)
	if not model.Parent or not root or not hrp or not humanoid or humanoid.Health <= 0 then
		clearHeld()
		return
	end
	-- The server is the source of truth: follow CarrierA/CarrierB, including lead hand-over.
	if model:GetAttribute("CarrierA") == player.UserId then
		myGrip = 1
		stepLead(model, root, hrp)
	elseif model:GetAttribute("CarrierB") == player.UserId then
		myGrip = 2
		stepSecond(model, hrp, os.clock())
	else
		clearHeld()
	end
end

local function onRelay(itemUid: string, _userId: number, point: Vector3)
	if held and held:GetAttribute("ItemUid") == itemUid and myGrip == 1 then
		partnerPoint = point
	end
end

function CarryController.Start()
	loadTuning()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	remotes = shared:WaitForChild("Remotes") :: Folder
	local relay = remotes and remotes:WaitForChild("Carry"):WaitForChild("SecondGripRelay")
	if relay and relay:IsA("UnreliableRemoteEvent") then
		relay.OnClientEvent:Connect(onRelay)
	end

	watchFurniture()
	ContextActionService:BindAction("MD_PadGrab", onPadGrab, false, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction(
		"MD_Rotate",
		onRotate,
		true,
		Enum.KeyCode.R,
		Enum.KeyCode.ButtonY
	)
	ContextActionService:SetTitle("MD_Rotate", "Rotate")

	player.CharacterAdded:Connect(clearHeld)
	RunService.Heartbeat:Connect(step)
end

return CarryController
