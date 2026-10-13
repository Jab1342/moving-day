-- Builds keyframed R15 animations (format 2 JSON, Claude B) into KeyframeSequence .rbxm files.
-- Run from the repo root:  lune run assets/anim/build_keyframed.luau MD_Strap MD_Recover
-- Format 1 (static poses: MD_Carry, MD_CarryTwo) stays with tools/upload/build_animations.luau.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local rb = require("@lune/roblox")

local names = process.args
assert(#names > 0, "usage: lune run assets/anim/build_keyframed.luau <Name> [<Name> ...]")

for _, name in names do
	local data = serde.decode("json", fs.readFile("assets/anim/" .. name .. ".json"))
	assert(data.format == 2 and data.rig == "R15" and data.name == name, "Expected format 2 R15 animation " .. name)
	local animated = {}
	for _, joint in data.animated do
		animated[joint] = true
	end
	local style = rb.Enum.PoseEasingStyle[data.easing[1]]
	local direction = rb.Enum.PoseEasingDirection[data.easing[2]]

	local sequence = rb.Instance.new("KeyframeSequence")
	sequence.Name = name
	sequence.Loop = data.loop
	sequence.Priority = rb.Enum.AnimationPriority[data.priority]

	local lastTime = -1
	for _, frame in data.frames do
		assert(frame.time > lastTime, name .. ": frame times must increase")
		lastTime = frame.time
		local keyframe = rb.Instance.new("Keyframe")
		keyframe.Name = "Keyframe"
		keyframe.Time = frame.time
		local function build(tree, parent)
			for joint, children in tree do
				local pose = rb.Instance.new("Pose")
				pose.Name = joint
				local p = frame.poses[joint]
				if animated[joint] then
					assert(p, `{name}: frame {frame.time} is missing animated joint {joint}`)
					local rot = p.rot
					local pos = p.pos or { 0, 0, 0 }
					pose.CFrame = rb.CFrame.new(pos[1], pos[2], pos[3])
						* rb.CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
					pose.Weight = 1
					pose.EasingStyle = style
					pose.EasingDirection = direction
				else
					pose.CFrame = rb.CFrame.identity
					pose.Weight = 0
				end
				pose.Parent = parent
				build(children, pose)
			end
		end
		build(data.hierarchy, keyframe)
		keyframe.Parent = sequence
	end
	assert(math.abs(lastTime - data.length) < 1e-6, name .. ": last frame must sit at length")

	local bytes = rb.serializeModel({ sequence })
	local decoded = rb.deserializeModel(bytes)
	assert(#decoded == 1 and decoded[1].ClassName == "KeyframeSequence", "Round-trip root type")
	assert(#decoded[1]:GetChildren() == #data.frames, "Round-trip frame count")
	assert(decoded[1].Loop == data.loop, "Round-trip loop flag")
	fs.writeFile("assets/anim/" .. name .. ".rbxm", bytes)
	print(`PASS {name}: {#data.frames} keyframes, {data.length}s, loop={data.loop}`)
end
