local fs = require("@lune/fs")
local serde = require("@lune/serde")
local rb = require("@lune/roblox")
for _, name in { "MD_Carry", "MD_CarryTwo" } do
	local data = serde.decode("json", fs.readFile("assets/anim/" .. name .. ".json"))
	assert(
		data.rig == "R15" and data.name == name and data.priority == "Action",
		"Expected authored R15 carry pose"
	)
	local sequence = rb.Instance.new("KeyframeSequence")
	sequence.Name = name
	sequence.Loop = data.loop
	sequence.Priority = rb.Enum.AnimationPriority.Action
	local function poses(tree, parent)
		for joint, children in tree do
			local pose = rb.Instance.new("Pose")
			pose.Name = joint
			local angles = data.poses_deg_xyz[joint]
			pose.Weight = if angles then 1 else 0
			pose.CFrame = if angles
				then rb.CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3]))
				else rb.CFrame.identity
			pose.Parent = parent
			poses(children, pose)
		end
	end
	for _, time in data.keyframes do
		local frame = rb.Instance.new("Keyframe")
		frame.Name = "Keyframe"
		frame.Time = time
		frame.Parent = sequence
		poses(data.hierarchy, frame)
	end
	local bytes = rb.serializeModel({ sequence })
	local decoded = rb.deserializeModel(bytes)
	assert(#decoded == 1 and decoded[1].ClassName == "KeyframeSequence", "Round-trip root type")
	assert(
		#decoded[1]:GetChildren() == #data.keyframes and decoded[1].Loop,
		"Round-trip frames/loop"
	)
	fs.writeFile("assets/anim/" .. name .. ".rbxm", bytes)
	print("PASS animation model round-trip: " .. name)
end
