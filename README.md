# my-game — Giant Monkey boss

A giant monkey boss for Roblox, built **entirely from code**. Nothing to model
by hand: when the game runs, the script assembles the monkey out of Parts and
drives its behavior.

## What it does

- **Builds itself** — a ~6× scaled blocky gorilla (torso, head with face, arms,
  legs) welded together with a working `Humanoid`.
- **Chases** the nearest player in range.
- **Melee slam** when a player gets close.
- **Ground pound** AoE with knockback when several players crowd it.
- **Roars** (arm raise) when idle.
- **Respawns** a few seconds after it dies.

All numbers (size, health, damage, ranges, colors) live in
`src/shared/MonkeyConfig.lua` — tune there.

## Files

| File | Goes to (in Studio) | Role |
|------|---------------------|------|
| `src/shared/MonkeyConfig.lua`  | `ReplicatedStorage` | Tunable settings (ModuleScript) |
| `src/shared/MonkeyBuilder.lua` | `ReplicatedStorage` | Builds the rig (ModuleScript) |
| `src/server/GiantMonkey.server.lua` | `ServerScriptService` | Spawns + AI (Script) |

## Get it into Studio

### Option A — Rojo (recommended for code-first dev)

1. Install [Rojo](https://rojo.space/) and its Studio plugin.
2. In this folder: `rojo serve`
3. In Studio: open the Rojo plugin → **Connect**. The files sync into
   `ReplicatedStorage` and `ServerScriptService` automatically.
4. Press **Play**. The monkey spawns at the world origin (60 studs up).

### Option B — paste by hand (no tooling)

1. In Studio, create two **ModuleScript**s in `ReplicatedStorage` named exactly
   `MonkeyConfig` and `MonkeyBuilder`; paste in the matching file contents.
2. Create a **Script** in `ServerScriptService` (any name); paste in
   `GiantMonkey.server.lua`.
3. Press **Play**.

## Tuning

Open `MonkeyConfig.lua`:

- `Scale` — overall size (1 = player-sized, 6 = boss).
- `MaxHealth`, `WalkSpeed`, `AggroRange` — core stats.
- `SlamDamage` / `PoundDamage` / `PoundKnockback` — attack power.
- `FurColor`, `FaceColor`, etc. — use any Roblox `BrickColor` name.

Change the spawn point in `GiantMonkey.server.lua` via `SPAWN_CFRAME`.
