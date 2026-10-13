--!strict
-- Shared screen scaling: every ScreenGui gets a UIScale tied to the viewport's short side,
-- so a phone (short side ~375 px) shrinks panels to 75% and a 1440p monitor grows to 125%.

local Workspace = game:GetService("Workspace")

local REFERENCE = 720
local MIN_SCALE, MAX_SCALE = 0.75, 1.25

local Scale = {}

function Scale.attach(gui: ScreenGui): UIScale
	local scale = gui:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = gui
	local function update()
		local camera = Workspace.CurrentCamera
		local short = if camera
			then math.min(camera.ViewportSize.X, camera.ViewportSize.Y)
			else REFERENCE
		scale.Scale = math.clamp(short / REFERENCE, MIN_SCALE, MAX_SCALE)
	end
	update()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return scale
end

return Scale
