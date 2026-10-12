--!strict
-- Grab, carry, rotate and drop furniture. The server (ItemService) validates every grab,
-- creates CarryAlignPosition / CarryAlignOrientation on the item's Root, and makes the lead
-- carrier (CarrierA) the network owner. The lead's client steers those constraints here.
-- Grip 2 sends its hand point to the server, which relays it to the lead.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local DEFAULTS = {
	GrabRange = 8,
	DollySpeedScale = 0.4,
	TwoCarrySpeedScale = 0.75,
	DragSpeedScale = 0.35,
	SecondGripHz = 20,
	HoldDistance = 1.6, -- studs in front of the chest, beyond the item's half depth
	HoldHeight = 0.6, -- studs above the HumanoidRootPart
	BedLiftRange = 14, -- near a truck bed, items lift to clear the tailgate
	BedClearance = 1.4, -- studs above the bed floor for the item's underside
}

local CarryController = {}

local tuning = table.clone(DEFAULTS)
local remotes: Folder? = nil
local held: Model? = nil
local myGrip = 0
local yawOffset = 0
local partnerHand: Vector3? = nil
local lastSecondGripSend = 0
local baseWalkSpeed = 16

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

local function isFurniture(inst: Instance): boolean
	return inst:IsA("Model") and inst:GetAttribute("ItemUid") ~= nil
end

-- Nearest grabbable item in front of the player, within GrabRange.
local function findTarget(): (Model?, number)
	local _, _, hrp = character()
	if not hrp then
		return nil, 0
	end
	local best: Model? = nil
	local bestScore = math.huge
	local bestGrip = 0
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local parts = workspace:GetPartBoundsInRadius(hrp.Position, tuning.GrabRange, params)
	local seen: { [Model]: boolean } = {}
	for _, part in parts do
		local model = part:FindFirstAncestorWhichIsA("Model")
		while model and not isFurniture(model) do
			model = model.Parent and model.Parent:FindFirstAncestorWhichIsA("Model") or nil
		end
		if model and not seen[model] then
			seen[model] = true
			local state = model:GetAttribute("State")
			local grip = 0
			if state ~= "Broken" and state ~= "Delivered" then
				if (model:GetAttribute("CarrierA") or 0) == 0 then
					grip = 1
				elseif model:GetAttribute("Carry") == "Two" and (model:GetAttribute("CarrierB") or 0) == 0 then
					grip = 2
				end
			end
			local root = itemRoot(model)
			if grip > 0 and root then
				local offset = root.Position - hrp.Position
				local facing = hrp.CFrame.LookVector:Dot(offset.Unit)
				local score = offset.Magnitude - facing * 3 -- prefer items in front
				if score < bestScore then
					best, bestScore, bestGrip = model, score, grip
				end
			end
		end
	end
	return best, bestGrip
end

local function setWalkSpeed(scale: number)
	local _, humanoid = character()
	if humanoid then
		humanoid.WalkSpeed = baseWalkSpeed * scale
	end
end

local function clearHeld()
	held = nil
	myGrip = 0
	yawOffset = 0
	partnerHand = nil
	setWalkSpeed(1)
end

local function requestGrab()
	local target, grip = findTarget()
	if not target then
		return
	end
	local grab = remote("Carry.RequestGrab")
	if not grab or not grab:IsA("RemoteFunction") then
		return
	end
	local ok, reason = grab:InvokeServer(target:GetAttribute("ItemUid"), grip)
	if ok then
		held = target
		myGrip = grip
		yawOffset = 0
		partnerHand = nil
		local _, humanoid = character()
		if humanoid then
			baseWalkSpeed = humanoid.WalkSpeed
		end
	elseif reason then
		warn(`[Carry] grab refused: {reason}`)
	end
end

local function requestDrop()
	local drop = remote("Carry.RequestDrop")
	if held and drop and drop:IsA("RemoteEvent") then
		drop:FireServer(held:GetAttribute("ItemUid"))
	end
	clearHeld()
end

local function onGrab(_, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if held then
		requestDrop()
	else
		requestGrab()
	end
	return Enum.ContextActionResult.Sink
end

local function onRotate(_, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin or not held or myGrip ~= 1 then
		return Enum.ContextActionResult.Pass
	end
	yawOffset = (yawOffset + math.pi / 2) % (2 * math.pi)
	return Enum.ContextActionResult.Sink
end

-- Near a truck bed (tagged "TruckBed"), raise the target so the item's underside clears
-- the tailgate; otherwise loading would need a jump.
local function liftForBed(model: Model, root: BasePart, goal: CFrame): CFrame
	local best: BasePart? = nil
	local bestDist = tuning.BedLiftRange
	for _, bed in CollectionService:GetTagged("TruckBed") do
		if bed:IsA("BasePart") and bed:IsDescendantOf(workspace) then
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

-- Hand point a carrier holds their grip at.
local function handPoint(hrp: BasePart): Vector3
	return hrp.Position + hrp.CFrame.LookVector * 1.2 + Vector3.yAxis * tuning.HoldHeight
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
	local size = model:GetExtentsSize()
	local _, yaw = hrp.CFrame:ToOrientation()

	if carry == "Two" and partnerId ~= 0 and partnerHand then
		setWalkSpeed(tuning.TwoCarrySpeedScale)
		local mine = handPoint(hrp)
		local target = twoHandedCFrame(root, (mine + partnerHand) / 2, partnerHand - mine)
		if target then
			target = liftForBed(model, root, target)
			alignPos.Position = target.Position
			alignOri.CFrame = target.Rotation
			return
		end
	end

	local goal: CFrame
	if carry == "Two" and not onDolly then
		-- Alone on a two-person item: drag it along the floor, slowly.
		setWalkSpeed(tuning.DragSpeedScale)
		local reach = hrp.Position + hrp.CFrame.LookVector * (size.Z / 2 + tuning.HoldDistance)
		goal = CFrame.new(reach.X, root.Position.Y, reach.Z) * CFrame.Angles(0, yaw + yawOffset, 0)
	else
		setWalkSpeed(if onDolly then tuning.DollySpeedScale else 1)
		local ahead = size.Z / 2 + tuning.HoldDistance
		local lift = if onDolly then -1.5 else tuning.HoldHeight
		goal = CFrame.new(hrp.Position + hrp.CFrame.LookVector * ahead + Vector3.yAxis * lift)
			* CFrame.Angles(0, yaw + yawOffset, 0)
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
		send:FireServer(model:GetAttribute("ItemUid"), handPoint(hrp))
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
	local userId = player.UserId
	-- The server is the source of truth: follow CarrierA/CarrierB, including lead hand-over.
	if model:GetAttribute("CarrierA") == userId then
		myGrip = 1
		stepLead(model, root, hrp)
	elseif model:GetAttribute("CarrierB") == userId then
		myGrip = 2
		stepSecond(model, hrp, os.clock())
	else
		clearHeld()
	end
end

local function onRelay(itemUid: string, _userId: number, handPos: Vector3)
	if held and held:GetAttribute("ItemUid") == itemUid and myGrip == 1 then
		partnerHand = handPos
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

	ContextActionService:BindAction("MD_Grab", onGrab, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("MD_Grab", "Grab")
	ContextActionService:BindAction("MD_Rotate", onRotate, true, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("MD_Rotate", "Rotate")

	player.CharacterAdded:Connect(clearHeld)
	RunService.Heartbeat:Connect(step)
end

return CarryController
