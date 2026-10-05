--!strict
-- GiantMonkey (server)
-- Spawns the Giant Monkey boss and runs its behavior:
--   * chases the nearest player in aggro range
--   * melee slams when close
--   * ground-pound AoE (with knockback) when several players crowd it
--   * roars on idle
--   * cleans up and respawns on death
--
-- Drop this in ServerScriptService. It expects MonkeyBuilder + MonkeyConfig in
-- ReplicatedStorage (that's where the Rojo project puts src/shared).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local MonkeyBuilder = require(ReplicatedStorage:WaitForChild("MonkeyBuilder"))
local Config = require(ReplicatedStorage:WaitForChild("MonkeyConfig"))

-- Where the boss appears. Change to taste, or point at a SpawnLocation.
local SPAWN_CFRAME = CFrame.new(0, 60, 0)
local RESPAWN_DELAY = 8 -- seconds after death before it comes back

-- ---------- helpers ----------

local function getRoot(model: Model): BasePart?
	return model.PrimaryPart
end

-- Nearest alive player character within `maxRange` of `fromPos`. Returns the
-- character model and its root, or nil.
local function nearestTarget(fromPos: Vector3, maxRange: number): (Model?, BasePart?)
	local best: Model? = nil
	local bestRoot: BasePart? = nil
	local bestDist = maxRange
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if not char then continue end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hum and hrp and hum.Health > 0 then
			local d = (hrp.Position - fromPos).Magnitude
			if d < bestDist then
				best, bestRoot, bestDist = char, hrp, d
			end
		end
	end
	return best, bestRoot
end

-- Count player characters whose root is within `radius` of `center`.
local function playersInRadius(center: Vector3, radius: number): { BasePart }
	local hit = {}
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 and (hrp.Position - center).Magnitude <= radius then
			table.insert(hit, hrp)
		end
	end
	return hit
end

local function damageChar(char: Instance, amount: number)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum:TakeDamage(amount)
	end
end

-- Briefly swing both arms down and back up (the "slam" pose).
local function animateSlam(monkey: Model)
	local motors = monkey:FindFirstChild("ArmMotors")
	if not motors then return end
	local l = (motors:FindFirstChild("LeftArmMotor") :: ObjectValue?)
	local r = (motors:FindFirstChild("RightArmMotor") :: ObjectValue?)
	local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, ref in { l, r } do
		local motor = ref and ref.Value :: Motor6D?
		if motor then
			local rest = motor.C0
			local raised = rest * CFrame.Angles(math.rad(-110), 0, 0)
			TweenService:Create(motor, info, { C0 = raised }):Play()
			task.delay(0.2, function()
				TweenService:Create(motor, TweenInfo.new(0.12), { C0 = rest }):Play()
			end)
		end
	end
end

-- A quick visual shockwave ring for the ground pound.
local function shockwave(center: Vector3, radius: number)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(1, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Neon
	ring.BrickColor = BrickColor.new("Bright orange")
	ring.Transparency = 0.3
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.5), { Transparency = 1, Size = Vector3.new(1, radius * 2.4, radius * 2.4) }):Play()
	Debris:AddItem(ring, 0.6)
end

local function doGroundPound(monkey: Model, root: BasePart)
	animateSlam(monkey)
	task.wait(0.2)
	local center = root.Position
	shockwave(center, Config.PoundRadius)
	for _, hrp in playersInRadius(center, Config.PoundRadius) do
		local char = hrp.Parent
		if char then
			damageChar(char, Config.PoundDamage)
			local away = (hrp.Position - center)
			if away.Magnitude < 1 then away = Vector3.new(0, 1, 0) end
			local dir = (away.Unit + Vector3.new(0, 0.6, 0)).Unit
			hrp.AssemblyLinearVelocity = dir * Config.PoundKnockback
		end
	end
end

local function doSlam(monkey: Model, root: BasePart, targetRoot: BasePart)
	animateSlam(monkey)
	task.wait(0.15)
	-- Confirm the target is still in range before applying damage.
	if (targetRoot.Position - root.Position).Magnitude <= Config.SlamRange * 1.3 then
		local char = targetRoot.Parent
		if char then damageChar(char, Config.SlamDamage) end
	end
end

-- ---------- main AI loop ----------

-- Forward declarations so the Died handler can re-spawn.
local spawnMonkey: () -> Model
local runMonkey: (Model) -> ()

function runMonkey(monkey: Model)
	local humanoid = monkey:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = getRoot(monkey) :: BasePart

	local nextSlam = 0
	local nextPound = 0
	local nextRoar = 0

	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not monkey.Parent or humanoid.Health <= 0 then
			conn:Disconnect()
			return
		end

		local now = os.clock()
		local pos = root.Position
		local targetChar, targetRoot = nearestTarget(pos, Config.GiveUpRange)

		if targetChar and targetRoot and (targetRoot.Position - pos).Magnitude <= Config.AggroRange then
			local dist = (targetRoot.Position - pos).Magnitude
			local crowd = playersInRadius(pos, Config.PoundRadius)

			-- Decide an attack.
			if #crowd >= Config.PoundTriggerCount and now >= nextPound then
				nextPound = now + Config.PoundCooldown
				nextSlam = now + 0.6
				humanoid:MoveTo(pos) -- hold ground
				task.spawn(doGroundPound, monkey, root)
			elseif dist <= Config.SlamRange and now >= nextSlam then
				nextSlam = now + Config.SlamCooldown
				humanoid:MoveTo(targetRoot.Position)
				task.spawn(doSlam, monkey, root, targetRoot)
			else
				humanoid:MoveTo(targetRoot.Position)
			end
		else
			-- Idle: occasional roar, hold position.
			humanoid:MoveTo(pos)
			if now >= nextRoar then
				nextRoar = now + Config.RoarInterval
				animateSlam(monkey)
			end
		end
	end)

	humanoid.Died:Connect(function()
		task.delay(RESPAWN_DELAY, function()
			if monkey.Parent then monkey:Destroy() end
			spawnMonkey()
		end)
	end)
end

function spawnMonkey()
	local monkey = MonkeyBuilder.build(Config)
	monkey:PivotTo(SPAWN_CFRAME)
	monkey.Parent = workspace
	runMonkey(monkey)
	return monkey
end

spawnMonkey()
print("[GiantMonkey] Boss spawned.")
