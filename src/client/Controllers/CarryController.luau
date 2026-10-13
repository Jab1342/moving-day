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
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Gate = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Gate"))

local DEFAULTS = {
	GrabRange = 8,
	DragReach = 7, -- max horizontal distance between the player and the dragged point
	HandPositionTolerance = 8, -- server rejects steer points farther than this from the player
	MaxCarryDistance = 10, -- server restores items whose root strays farther than this
	MaxCarrySpeed = 80, -- server speed cap for carried items
	DollySpeedScale = 0.4,
	TwoCarrySpeedScale = 0.75,
	DragSpeedScale = 0.35,
	LeashSpeedScale = 0.4, -- grip 2 slows down when stretched past SecondGripSlowRange
	SecondGripSlowRange = 6,
	SoloHeavyMaxVelocity = 6, -- studs/s when one player hauls a two-person item alone
	StrapRange = 8, -- same as the server's GrabRange check
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
-- Bumped on every press and release; a grab whose press was already released while the
-- server answered is dropped instead of held.
local dragGen = 0
local toast: (text: string) -> () -- short on-screen hint, defined below
local dollyTier = 0 -- PublicProfile.upgrades.Dolly
local dollyTierScales: { number } = { 0.55, 0.70 }

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
			if type(config.DollyTierSpeedScale) == "table" then
				dollyTierScales = config.DollyTierSpeedScale
			end
		end
	end
end

-- Dolly walk speed: tier 0 is Config.DollySpeedScale, bought tiers use DollyTierSpeedScale.
local function dollySpeedScale(): number
	local scale = dollyTier > 0 and dollyTierScales[math.min(dollyTier, #dollyTierScales)]
	return if type(scale) == "number" then scale else tuning.DollySpeedScale
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

-- Carry pose: a looping Action animation while holding, so everyone sees you lifting.
-- Plays only once ANIM_Carry / ANIM_CarryTwo exist in AssetIds.
local poseTrack: AnimationTrack? = nil
local function assetId(name: string): string?
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = shared and shared:FindFirstChild("AssetIds")
	if module and module:IsA("ModuleScript") then
		local ok, ids = pcall(require, module)
		if ok and type(ids) == "table" and type(ids[name]) == "string" then
			return ids[name]
		end
	end
	return nil
end

local function stopPose()
	if poseTrack then
		poseTrack:Stop(0.2)
		poseTrack = nil
	end
end

-- An Action-priority track for an AssetIds animation, or nil until it's registered.
local function loadTrack(names: { string }, looped: boolean): AnimationTrack?
	local _, humanoid = character()
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local id: string? = nil
	for _, name in names do
		id = id or assetId(name)
	end
	if not animator or not id then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if not ok or not track then
		return nil
	end
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = looped
	return track
end

local function playPose(twoPerson: boolean)
	stopPose()
	local track =
		loadTrack(if twoPerson then { "ANIM_CarryTwo", "ANIM_Carry" } else { "ANIM_Carry" }, true)
	if track then
		track:Play(0.15)
		poseTrack = track
	end
end

local function clearHeld()
	stopPose()
	if held then
		local root = itemRoot(held)
		local alignPos = root and root:FindFirstChild("CarryAlignPosition") :: AlignPosition?
		if alignPos then
			alignPos.MaxVelocity = tuning.MaxCarrySpeed
		end
	end
	held = nil
	myGrip = 0
	screenPoint = nil
	partnerPoint = nil
	setWalkSpeed(1)
end

local function grab(model: Model, hitPoint: Vector3?, atScreen: Vector2?, gen: number?)
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
	if gen and gen ~= dragGen then
		-- released before the server answered: give it straight back
		local requestDrop = remote("Carry.RequestDrop")
		if requestDrop and requestDrop:IsA("RemoteEvent") then
			requestDrop:FireServer(model:GetAttribute("ItemUid"))
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
	playPose(model:GetAttribute("Carry") == "Two")
	Gate.markGrabbed()
end

local function drop()
	local requestDrop = remote("Carry.RequestDrop")
	if held and requestDrop and requestDrop:IsA("RemoteEvent") then
		requestDrop:FireServer(held:GetAttribute("ItemUid"))
	end
	clearHeld()
end

-- Raycast that passes through parts Invisicam has faded (walls between camera and player).
-- Returns the first solid hit and whether a faded part was skipped on the way.
local function castThroughFaded(
	origin: Vector3,
	direction: Vector3,
	exclude: { Instance }
): (RaycastResult?, boolean)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skipped = table.clone(exclude)
	local passedFaded = false
	for _ = 1, 6 do
		params.FilterDescendantsInstances = skipped
		local hit = Workspace:Raycast(origin, direction, params)
		if not hit or hit.Instance.LocalTransparencyModifier <= 0.3 then
			return hit, passedFaded
		end
		passedFaded = true
		table.insert(skipped, hit.Instance)
	end
	return nil, passedFaded
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
		local root = itemRoot(model)
		-- same rule as the server: item centre within GrabRange of the player
		if not root or (root.Position - hrp.Position).Magnitude > tuning.GrabRange then
			toast("Get closer to grab that")
			return
		end
		local screen = camera:WorldToViewportPoint(cursorRay.Origin + cursorRay.Direction * 20)
		dragGen += 1
		task.spawn(grab, model, hit, Vector2.new(screen.X, screen.Y), dragGen)
	end)
	detector.DragContinue:Connect(function(_who, cursorRay: Ray)
		local camera = Workspace.CurrentCamera
		if held == model and camera then
			local screen = camera:WorldToViewportPoint(cursorRay.Origin + cursorRay.Direction * 20)
			screenPoint = Vector2.new(screen.X, screen.Y)
		end
	end)
	detector.DragEnd:Connect(function()
		dragGen += 1
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

-- Invisicam fades walls between the camera and the player, but a faded wall still blocks the
-- DragDetector's click ray, so furniture you can see through it can't be grabbed. For those
-- clicks we cast our own ray that skips faded parts and run the same grab/drag/release flow.
local seeThroughInput: InputObject? = nil

local function itemBehindFadedPart(screen: Vector2): (Model?, Vector3?)
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil, nil
	end
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local hit, passedFaded =
		castThroughFaded(ray.Origin, ray.Direction * 200, { player.Character :: Instance })
	-- only take over when a faded part was in the way; otherwise the DragDetector has it
	if not hit or not passedFaded then
		return nil, nil
	end
	local model = hit.Instance:FindFirstAncestorWhichIsA("Model")
	while model and not model:GetAttribute("ItemUid") do
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return model, if model then hit.Position else nil
end

local function watchSeeThroughClicks()
	UserInputService.InputBegan:Connect(function(input, processed)
		local kind = input.UserInputType
		if
			processed
			or held
			or grabbing
			or seeThroughInput
			or (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch)
		then
			return
		end
		local inset = GuiService:GetGuiInset()
		local screen = Vector2.new(input.Position.X, input.Position.Y) + inset
		local model, hit = itemBehindFadedPart(screen)
		local _, _, hrp = character()
		local root = model and itemRoot(model)
		if not model or not root or not hrp or freeGrip(model) == 0 then
			return
		end
		if (root.Position - hrp.Position).Magnitude > tuning.GrabRange then
			toast("Get closer to grab that")
			return
		end
		seeThroughInput = input
		dragGen += 1
		task.spawn(grab, model, hit, screen, dragGen)
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not seeThroughInput or not held then
			return
		end
		local kind = input.UserInputType
		if
			(
				seeThroughInput.UserInputType == Enum.UserInputType.MouseButton1
				and kind == Enum.UserInputType.MouseMovement
			) or input == seeThroughInput
		then
			local inset = GuiService:GetGuiInset()
			screenPoint = Vector2.new(input.Position.X, input.Position.Y) + inset
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input ~= seeThroughInput
			and not (
				seeThroughInput
				and seeThroughInput.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseButton1
			)
		then
			return
		end
		seeThroughInput = nil
		dragGen += 1
		if held then
			drop()
		end
	end)
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

local toastLabel: TextLabel? = nil
function toast(text: string)
	if not toastLabel then
		local gui = Instance.new("ScreenGui")
		gui.Name = "CarryToast"
		gui.ResetOnSpawn = false
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 1)
		label.Position = UDim2.new(0.5, 0, 1, -120)
		label.Size = UDim2.fromOffset(320, 40)
		label.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
		label.BackgroundTransparency = 0.2
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 18
		label.Visible = false
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = label
		label.Parent = gui
		gui.Parent = player:WaitForChild("PlayerGui")
		toastLabel = label
	end
	local label = toastLabel :: TextLabel
	label.Text = text
	label.Visible = true
	task.delay(2, function()
		if label.Text == text then
			label.Visible = false
		end
	end)
end

-- Nearest unstrapped cargo of mine sitting in a truck bed.
local function nearestCargo(): Model?
	local _, _, hrp = character()
	if not hrp then
		return nil
	end
	local best: Model? = nil
	local bestDist = tuning.StrapRange
	for _, part in Workspace:GetPartBoundsInRadius(hrp.Position, tuning.StrapRange) do
		local model = part:FindFirstAncestorWhichIsA("Model")
		if
			model
			and model:GetAttribute("ItemUid")
			and model:GetAttribute("State") == "InTruck"
			and model:GetAttribute("Strapped") ~= true
		then
			local root = itemRoot(model)
			local d = root and (root.Position - hrp.Position).Magnitude or math.huge
			if d < bestDist then
				best, bestDist = model, d
			end
		end
	end
	return best
end

-- F / ButtonB / touch "Strap": wrap the item you're holding, or strap the nearest cargo.
local function onStrap(_, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local request = remote("Carry.RequestStrap")
	if not request or not request:IsA("RemoteFunction") then
		return Enum.ContextActionResult.Sink
	end
	local target = held
	local action = "Wrap"
	if not target then
		target = nearestCargo()
		action = "Strap"
	end
	if not target then
		toast("Nothing to strap here")
		return Enum.ContextActionResult.Sink
	end
	toast(if action == "Strap" then "Strapping..." else "Wrapping...")
	-- strap pull loops for as long as the server holds the strap pending (StrapSeconds)
	local strapTrack = if action == "Strap" then loadTrack({ "ANIM_Strap" }, true) else nil
	if strapTrack then
		strapTrack:Play(0.15)
	end
	task.spawn(function()
		local ok, reason = (request :: RemoteFunction):InvokeServer(
			target:GetAttribute("ItemUid"),
			action
		)
		if strapTrack then
			strapTrack:Stop(0.2) -- done or cancelled
		end
		if ok then
			toast(if action == "Strap" then "Strapped down" else "Wrapped")
		else
			toast(
				if reason == "Cancelled"
					then `{action} cancelled`
					else `Can't {string.lower(action)}: {reason or "try again"}`
			)
		end
	end)
	return Enum.ContextActionResult.Sink
end

-- World point the player is steering toward this frame: the spot on the ground under the
-- cursor/touch, lifted to `planeY` and clamped to arm's reach. Gamepad: in front of the player.
local function steerPoint(hrp: BasePart, planeY: number): Vector3
	local camera = Workspace.CurrentCamera
	local point: Vector3
	if screenPoint and camera then
		local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
		local hit = castThroughFaded(
			ray.Origin,
			ray.Direction * 500,
			{ player.Character :: Instance, held :: Instance }
		)
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
	local result = Vector3.new(hrp.Position.X + flat.X, planeY, hrp.Position.Z + flat.Z)
	-- stay inside the server's hand tolerance, height included
	local offset = result - hrp.Position
	local limit = tuning.HandPositionTolerance - 0.5
	if offset.Magnitude > limit then
		result = hrp.Position + offset.Unit * limit
	end
	return result
end

-- Keep the item's root inside the server's carry distance after grip offsets and bed lift.
local function clampReach(goal: CFrame, hrp: BasePart): CFrame
	local offset = goal.Position - hrp.Position
	local limit = tuning.MaxCarryDistance - 0.5
	if offset.Magnitude <= limit then
		return goal
	end
	return CFrame.new(hrp.Position + offset.Unit * limit) * goal.Rotation
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
		alignPos.MaxVelocity = tuning.MaxCarrySpeed
		local mine = steerPoint(hrp, holdY)
		local target = twoHandedCFrame(root, (mine + partnerPoint) / 2, partnerPoint - mine)
		if target then
			target = clampReach(liftForBed(model, root, target), hrp)
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
		setWalkSpeed(if onDolly then dollySpeedScale() else 1)
		alignPos.MaxVelocity = tuning.MaxCarrySpeed
		local planeY = if onDolly then hrp.Position.Y - 1.5 else holdY
		goal = CFrame.new(steerPoint(hrp, planeY)) * rotation * CFrame.new(-grabLocal)
		if not onDolly then
			goal = liftForBed(model, root, goal)
		end
	end
	goal = clampReach(goal, hrp)
	alignPos.Position = goal.Position
	alignOri.CFrame = goal.Rotation
end

local function stepSecond(model: Model, root: BasePart, hrp: BasePart, now: number)
	-- soft leash: stretched too far from your grip and you slow right down (server drops at
	-- SecondGripDropRange)
	local grip = root:FindFirstChild("Grip2") :: Attachment?
	local stretch = if grip then (grip.WorldPosition - hrp.Position).Magnitude else 0
	setWalkSpeed(
		if stretch > tuning.SecondGripSlowRange
			then tuning.LeashSpeedScale
			else tuning.TwoCarrySpeedScale
	)
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
		stepSecond(model, root, hrp, os.clock())
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
	task.spawn(function()
		local profile = (remotes :: Folder)
				:WaitForChild("Data")
				:WaitForChild("Profile") :: RemoteEvent
		profile.OnClientEvent:Connect(function(p)
			local tier = type(p) == "table" and type(p.upgrades) == "table" and p.upgrades.Dolly
			dollyTier = if type(tier) == "number" then tier else 0
		end)
	end)

	watchFurniture()
	watchSeeThroughClicks()
	ContextActionService:BindAction("MD_PadGrab", onPadGrab, false, Enum.KeyCode.ButtonX)
	-- Rotate and Strap only exist when they can do something, so touch screens stay clean.
	local rotateBound, strapBound, strapTitle = false, false, ""
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.3 then
			return
		end
		acc = 0
		local wantRotate = held ~= nil and myGrip == 1
		if wantRotate ~= rotateBound then
			rotateBound = wantRotate
			if wantRotate then
				ContextActionService:BindAction(
					"MD_Rotate",
					onRotate,
					true,
					Enum.KeyCode.R,
					Enum.KeyCode.ButtonY
				)
				ContextActionService:SetTitle("MD_Rotate", "Rotate")
			else
				ContextActionService:UnbindAction("MD_Rotate")
			end
		end
		local wantStrap = held ~= nil or nearestCargo() ~= nil
		local title = if held then "Wrap" else "Strap"
		if wantStrap ~= strapBound or (wantStrap and title ~= strapTitle) then
			strapBound = wantStrap
			strapTitle = title
			if wantStrap then
				ContextActionService:BindAction(
					"MD_Strap",
					onStrap,
					true,
					Enum.KeyCode.F,
					Enum.KeyCode.ButtonB
				)
				ContextActionService:SetTitle("MD_Strap", title)
			else
				ContextActionService:UnbindAction("MD_Strap")
			end
		end
	end)

	player.CharacterAdded:Connect(clearHeld)
	RunService.Heartbeat:Connect(step)
end

return CarryController
