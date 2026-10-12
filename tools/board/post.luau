-- Replace message fields, then execute through Studio MCP in Edit mode.
assert(not game:GetService("RunService"):IsRunning(), "Never post during Play")
assert(game.PlaceId == 130590584225382, "Wrong place")
local text = "Codex is starting the next task."
local recipient, kind, ref = "All", "Info", ""
assert(#text < 500, "Board messages must be under 500 characters")
local board = game:GetService("ServerStorage"):FindFirstChild("DevBoard")
assert(board and board:IsA("Folder"), "DevBoard missing; use repo fallback")
local stamp = os.time()
local name = tostring(stamp) .. "_Codex"
while board:FindFirstChild(name) do
	stamp += 1
	name = tostring(stamp) .. "_Codex"
end
local message = Instance.new("StringValue")
message.Name = name
message.Value = text
message:SetAttribute("From", "Codex")
message:SetAttribute("To", recipient)
message:SetAttribute("Type", kind)
message:SetAttribute("Status", "Open")
message:SetAttribute("Ref", ref)
-- For replies: message:SetAttribute("ReplyTo", originalName)
message.Parent = board
return name
