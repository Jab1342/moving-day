-- Run through Studio MCP in Edit mode. Reading never creates a board.
local board = game:GetService("ServerStorage"):FindFirstChild("DevBoard")
local out = {}
if board then
	for _, message in board:GetChildren() do
		if message:IsA("StringValue") then
			table.insert(
				out,
				{ name = message.Name, Value = message.Value, attributes = message:GetAttributes() }
			)
		end
	end
end
table.sort(out, function(a, b)
	return a.name < b.name
end)
return game:GetService("HttpService"):JSONEncode(out)
