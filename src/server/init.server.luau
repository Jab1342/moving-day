--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local definitions = require(shared.Contracts.Remotes)

local function folder(parent: Instance, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("Folder"), name .. " must be a Folder")
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

local remotes = folder(shared, "Remotes")
for path, definition in definitions do
	local group, name = string.match(path, "^([^.]+)%.([^.]+)$")
	assert(group and name, "Invalid remote path: " .. path)
	local parent = folder(remotes, group)
	local remote = parent:FindFirstChild(name)
	if remote then
		assert(remote.ClassName == definition.className, "Remote class mismatch: " .. path)
	else
		remote = Instance.new(definition.className)
		remote.Name = name
		remote.Parent = parent
	end
	if remote:IsA("RemoteFunction") then
		-- STUB(Codex): fail closed until the owning service installs validation/handler.
		remote.OnServerInvoke = function()
			return false, "NotReady"
		end
	end
end
