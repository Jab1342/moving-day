--!strict
-- Client entry point: starts every controller in Controllers/.

local controllers = script:WaitForChild("Controllers")

for _, module in controllers:GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, controller = pcall(require, module)
		if ok and type(controller) == "table" and type(controller.Start) == "function" then
			task.spawn(controller.Start)
		else
			warn(`[Client] failed to start {module.Name}: {controller}`)
		end
	end
end
