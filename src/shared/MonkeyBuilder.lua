--!strict
-- MonkeyBuilder
-- Constructs a Giant Monkey rig entirely out of Parts at runtime, so you never
-- have to model anything by hand in Studio. Returns a Model with a working
-- Humanoid + HumanoidRootPart, fully welded, ready for Humanoid:MoveTo().
--
-- Design notes:
--  * Only the HumanoidRootPart has mass and collision. Every other part is
--    Massless + CanCollide=false and welded to the root. This keeps a big
--    custom rig physically stable (it walks on the HRP, not on wobbly limbs).
--  * Arms attach via Motor6D so the AI can animate a slam by tweening C0.
--  * All sizes derive from a base skeleton multiplied by config.Scale.

local MonkeyBuilder = {}

-- Base (Scale = 1) dimensions in studs, loosely human proportions.
local BASE = {
	Root = Vector3.new(2.6, 3.0, 1.4),
	Torso = Vector3.new(3.2, 3.6, 2.0),
	Head = Vector3.new(2.2, 2.0, 2.0),
	Arm = Vector3.new(1.1, 4.0, 1.1),
	Leg = Vector3.new(1.3, 3.4, 1.3),
	Brow = Vector3.new(2.3, 0.4, 0.3),
	Eye = Vector3.new(0.4, 0.4, 0.3),
	Nostril = Vector3.new(0.25, 0.25, 0.25),
	Muzzle = Vector3.new(1.6, 0.9, 0.6),
}

local function makePart(name: string, size: Vector3, color: string, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.BrickColor = BrickColor.new(color)
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	if shape then
		-- Only Part supports Shape; Block/Ball/Cylinder are the common ones.
		(p :: any).Shape = shape
	end
	return p
end

-- Rigidly weld `part` so it moves with `to`, placing it at `offset` (studs,
-- already scaled) relative to the root's center.
local function weldTo(part: BasePart, to: BasePart, root: BasePart, offset: Vector3)
	part.CFrame = root.CFrame * CFrame.new(offset)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = part
end

-- Attach an arm with a Motor6D so it can be animated (slam). Returns the motor.
local function motorArm(arm: BasePart, torso: BasePart, shoulderOffset: Vector3): Motor6D
	local motor = Instance.new("Motor6D")
	motor.Name = arm.Name .. "Motor"
	motor.Part0 = torso
	motor.Part1 = arm
	-- C0 is the shoulder socket on the torso; C1 is the top of the arm.
	motor.C0 = CFrame.new(shoulderOffset)
	motor.C1 = CFrame.new(0, arm.Size.Y / 2, 0)
	motor.Parent = torso
	return motor
end

-- Builds and returns the monkey Model. Does NOT parent it anywhere.
function MonkeyBuilder.build(config): Model
	local s = config.Scale

	local model = Instance.new("Model")
	model.Name = "GiantMonkey"

	-- ---- Root (the only collidable, massive part) ----
	local root = makePart("HumanoidRootPart", BASE.Root * s, config.FurColor)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	root.Parent = model

	-- ---- Torso ----
	local torso = makePart("Torso", BASE.Torso * s, config.FurColor)
	torso.Parent = model
	weldTo(torso, root, root, Vector3.new(0, 0, 0))

	-- ---- Head ----
	local head = makePart("Head", BASE.Head * s, config.FaceColor)
	head.Parent = model
	local headOffset = Vector3.new(0, (BASE.Torso.Y / 2 + BASE.Head.Y / 2) * s, 0)
	weldTo(head, torso, root, headOffset)

	-- Face: muzzle, brow, eyes, nostrils — welded to the head so they ride along.
	local faceZ = -(BASE.Head.Z / 2) * s -- front of the head (-Z faces forward)
	local function face(part: BasePart, local_: Vector3)
		part.Parent = model
		weldTo(part, head, root, headOffset + local_)
	end

	local muzzle = makePart("Muzzle", BASE.Muzzle * s, config.FaceColor)
	face(muzzle, Vector3.new(0, -0.5 * s, faceZ - (BASE.Muzzle.Z / 2) * s))

	local brow = makePart("Brow", BASE.Brow * s, config.FurColor)
	face(brow, Vector3.new(0, 0.7 * s, faceZ - 0.05 * s))

	local leftEye = makePart("LeftEye", BASE.Eye * s, config.EyeColor, Enum.PartType.Ball)
	face(leftEye, Vector3.new(-0.5 * s, 0.35 * s, faceZ - 0.1 * s))
	local rightEye = makePart("RightEye", BASE.Eye * s, config.EyeColor, Enum.PartType.Ball)
	face(rightEye, Vector3.new(0.5 * s, 0.35 * s, faceZ - 0.1 * s))

	local leftNostril = makePart("LeftNostril", BASE.Nostril * s, config.EyeColor, Enum.PartType.Ball)
	face(leftNostril, Vector3.new(-0.3 * s, -0.4 * s, faceZ - (BASE.Muzzle.Z) * s))
	local rightNostril = makePart("RightNostril", BASE.Nostril * s, config.EyeColor, Enum.PartType.Ball)
	face(rightNostril, Vector3.new(0.3 * s, -0.4 * s, faceZ - (BASE.Muzzle.Z) * s))

	-- ---- Arms (Motor6D so they can slam) ----
	local armY = BASE.Arm.Y * s
	local shoulderX = (BASE.Torso.X / 2 + BASE.Arm.X / 2) * s
	local shoulderY = (BASE.Torso.Y / 2 - BASE.Arm.X / 2) * s

	local leftArm = makePart("LeftArm", BASE.Arm * s, config.FurColor)
	leftArm.Parent = model
	local leftMotor = motorArm(leftArm, torso, Vector3.new(-shoulderX, shoulderY, 0))

	local rightArm = makePart("RightArm", BASE.Arm * s, config.FurColor)
	rightArm.Parent = model
	local rightMotor = motorArm(rightArm, torso, Vector3.new(shoulderX, shoulderY, 0))

	-- Dark "knuckle" caps on the fists.
	local function fist(arm: BasePart, side: number)
		local f = makePart(arm.Name .. "Fist", Vector3.new(BASE.Arm.X * 1.3, BASE.Arm.X * 1.0, BASE.Arm.X * 1.3) * s, config.NailColor)
		f.Parent = model
		local x = side * shoulderX
		weldTo(f, arm, root, Vector3.new(x, shoulderY - armY, 0))
		-- Re-weld to the arm specifically (weldTo used root for placement math).
		for _, w in f:GetChildren() do w:Destroy() end
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = arm
		weld.Part1 = f
		weld.Parent = f
	end
	fist(leftArm, -1)
	fist(rightArm, 1)

	-- ---- Legs ----
	local legY = BASE.Leg.Y * s
	local hipX = (BASE.Torso.X / 2 - BASE.Leg.X / 2) * s
	local hipY = -(BASE.Torso.Y / 2 + BASE.Leg.Y / 2) * s

	local leftLeg = makePart("LeftLeg", BASE.Leg * s, config.FurColor)
	leftLeg.Parent = model
	weldTo(leftLeg, torso, root, Vector3.new(-hipX, hipY, 0))

	local rightLeg = makePart("RightLeg", BASE.Leg * s, config.FurColor)
	rightLeg.Parent = model
	weldTo(rightLeg, torso, root, Vector3.new(hipX, hipY, 0))

	-- ---- Humanoid ----
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = config.MaxHealth
	humanoid.Health = config.MaxHealth
	humanoid.WalkSpeed = config.WalkSpeed
	humanoid.AutoRotate = true
	-- Float the root so the legs rest on the ground.
	humanoid.HipHeight = legY + (BASE.Torso.Y / 2) * s - (BASE.Root.Y / 2) * s
	humanoid.Parent = model

	model.PrimaryPart = root

	-- Expose the arm motors + their rest poses so the AI can animate/restore them.
	local motors = Instance.new("Folder")
	motors.Name = "ArmMotors"
	leftMotor.Parent = torso -- already parented; kept for clarity
	local lRef = Instance.new("ObjectValue"); lRef.Name = "LeftArmMotor"; lRef.Value = leftMotor; lRef.Parent = motors
	local rRef = Instance.new("ObjectValue"); rRef.Name = "RightArmMotor"; rRef.Value = rightMotor; rRef.Parent = motors
	motors.Parent = model

	return model
end

return MonkeyBuilder
