--!strict
-- First-60-seconds rule: a brand-new player sees no screen UI until their first grab.
-- Returning players (profile.firstJobDone) see everything straight away.
-- Gate.bind(gui) keeps a ScreenGui disabled until the gate opens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local Gate = {}

local watching = false

local function watchProfile()
	if watching then
		return
	end
	watching = true
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
		local profile = remotes:WaitForChild("Data"):WaitForChild("Profile") :: RemoteEvent
		profile.OnClientEvent:Connect(function(p)
			if type(p) == "table" and p.firstJobDone == true then
				player:SetAttribute("MD_Returning", true)
			end
		end)
	end)
end

function Gate.open(): boolean
	return player:GetAttribute("MD_HasGrabbed") == true
		or player:GetAttribute("MD_Returning") == true
end

-- Called by CarryController on the first successful grab.
function Gate.markGrabbed()
	player:SetAttribute("MD_HasGrabbed", true)
end

-- Run `callback` once the gate is open (immediately if it already is).
function Gate.whenOpen(callback: () -> ())
	watchProfile()
	if Gate.open() then
		callback()
		return
	end
	local connections: { RBXScriptConnection } = {}
	local function check()
		if Gate.open() then
			for _, c in connections do
				c:Disconnect()
			end
			callback()
		end
	end
	table.insert(connections, player:GetAttributeChangedSignal("MD_HasGrabbed"):Connect(check))
	table.insert(connections, player:GetAttributeChangedSignal("MD_Returning"):Connect(check))
end

function Gate.bind(gui: ScreenGui)
	gui.Enabled = Gate.open()
	Gate.whenOpen(function()
		gui.Enabled = true
	end)
end

return Gate
