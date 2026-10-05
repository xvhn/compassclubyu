--!strict
-- MonkeyConfig
-- Central tuning for the Giant Monkey boss. Tweak numbers here and both the
-- builder (looks) and the AI (behavior) pick them up. Nothing in here spawns
-- anything on its own.

local MonkeyConfig = {
	-- ===== Size =====
	-- Everything is built from a human-ish base skeleton and multiplied by Scale.
	-- 1 = roughly player sized. 6 = towering boss.
	Scale = 6,

	-- ===== Stats =====
	MaxHealth = 2500,
	WalkSpeed = 14, -- studs/sec while chasing
	AggroRange = 180, -- starts hunting a player within this many studs
	GiveUpRange = 320, -- loses interest past this

	-- ===== Melee slam =====
	SlamRange = 22, -- how close before it slams
	SlamDamage = 45,
	SlamCooldown = 2.2, -- seconds between slams

	-- ===== Ground pound (AoE) =====
	PoundRadius = 40, -- studs
	PoundDamage = 70,
	PoundKnockback = 120, -- velocity applied outward
	PoundCooldown = 9, -- seconds between pounds
	PoundTriggerCount = 2, -- pounds instead of slamming when >= this many players are in range

	-- ===== Roar =====
	RoarInterval = 12, -- seconds between idle roars

	-- ===== Colors (BrickColor names) =====
	FurColor = "Reddish brown",
	FaceColor = "Nougat",
	EyeColor = "Really black",
	NailColor = "Black",
}

return MonkeyConfig
