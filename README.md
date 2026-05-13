# Sky Base — Roblox Studio Setup

Space-base defense game: survive incoming debris, shoot it with your laser,
collect fragments, and eventually build out your platform.

---

## Folder layout

```
src/
  ReplicatedStorage/
    Config.lua              ← shared config (ModuleScript)
  ServerScriptService/
    GameSetup.server.lua    ← scene, lighting, nebula
    DebrisSystem.server.lua ← spawn loop + hit handling
  StarterPack/
    LaserGun/
      LaserGun.client.lua   ← weapon LocalScript (goes inside the Tool)
  StarterGui/
    InventoryUI.client.lua  ← fragment HUD (LocalScript)
```

---

## Manual setup in Roblox Studio

Open `sky-base.rbxl` in Roblox Studio, then follow these steps.

### 1 — Config (ModuleScript)

1. In **Explorer**, right-click **ReplicatedStorage** → Insert Object → **ModuleScript**
2. Rename it `Config`
3. Open it and paste the contents of `src/ReplicatedStorage/Config.lua`

### 2 — GameSetup (Script)

1. Right-click **ServerScriptService** → Insert Object → **Script**
2. Rename it `GameSetup`
3. Paste contents of `src/ServerScriptService/GameSetup.server.lua`

### 3 — DebrisSystem (Script)

1. Right-click **ServerScriptService** → Insert Object → **Script**
2. Rename it `DebrisSystem`
3. Paste contents of `src/ServerScriptService/DebrisSystem.server.lua`

### 4 — LaserGun (Tool)

This requires a few sub-steps because a Tool needs a physical Handle part.

1. Right-click **StarterPack** → Insert Object → **Tool**
2. Rename it `LaserGun`
3. With **LaserGun** selected, Insert Object → **Part**, rename it `Handle`
   - Size: `1, 0.5, 3`
   - Material: **Neon**
   - Color: any bright green (matches laser color)
   - Make sure **CanCollide** is unchecked
4. With **LaserGun** selected, Insert Object → **LocalScript**
5. Rename the LocalScript `LaserGun`
6. Paste contents of `src/StarterPack/LaserGun/LaserGun.client.lua`

### 5 — InventoryUI (LocalScript)

1. Right-click **StarterGui** → Insert Object → **LocalScript**
2. Rename it `InventoryUI`
3. Paste contents of `src/StarterGui/InventoryUI.client.lua`

---

## Running the game

Hit **Play** (F5) in Roblox Studio.

- You should spawn on a small floating metallic platform surrounded by colorful
  nebula clouds (purple, pink, blue, white).
- Debris chunks will start flying in every 4 seconds.
- Click to fire the laser — green beam, hits debris.
- Debris takes 4 hits to destroy, then pops into 3 fragments (Rock, Metal,
  Crystal, or Ice).
- Walk into / touch fragments to collect them — they appear in the **CARGO HOLD**
  panel (bottom-right).

---

## Tweaking

All the important numbers live in `Config.lua`:

| Key | What it does |
|-----|-------------|
| `DEBRIS_SPAWN_INTERVAL` | Seconds between debris spawns (lower = harder) |
| `DEBRIS_SPEED` | How fast debris flies toward you |
| `DEBRIS_HEALTH` | Shots needed to destroy (100 hp / 30 dmg = 4 shots) |
| `LASER_COOLDOWN` | Fire rate (0.25 s = 4 shots/sec) |
| `PLATFORM_POSITION` | Where your base floats |

Nebula cloud positions and colors are in `GameSetup.server.lua` → `NEBULA_DEFS`.

---

## What's stubbed / next steps

- [ ] Platform building — place collected fragments as modules on the base
- [ ] Wave system — debris gets faster / bigger over time
- [ ] Multiple weapon types (unlocked from fragment types)
- [ ] Health/shields for the platform
- [ ] Persistent inventory between rounds
