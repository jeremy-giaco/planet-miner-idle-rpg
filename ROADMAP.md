# Sky Base — Game Roadmap

## Phase 1 — Foundation & Mobile (Next Up)

### Bug Fixes
- [ ] Character falls through base roof — thicken collision surfaces
- [ ] Base too small — scale up significantly, fix proportions

### Mobile Controls
- [ ] Twin-stick virtual joystick for ship flight (left = thrust/strafe, right = camera)
- [ ] Configurable control modes: twin-stick, tap-to-fly, gyro, classic (keyboard/mouse)
- [ ] Auto-detect platform and set default mode
- [ ] In-game settings screen to switch control mode + gyro sensitivity

### UI / HUD Polish
- [ ] Zone label shows planet + zone: `Moon: Badlands`
- [ ] Ship HUD — speed, altitude, shield, energy, cargo (cockpit + chase)
- [ ] Camera mode toggle (single button cycles relevant modes)
  - Character: 3rd person / 1st person
  - Ship: cockpit (1st person) / chase (3rd person with mini HUD)

### Persistence
- [ ] Per-player cargo saved via `DataStoreService` (persists between sessions)

---

## Phase 2 — Loot & RPG Systems

### Loot Overhaul
- [ ] No auto-inventory — player must return loot to base to bank it
- [ ] Spinning pickup indicator with glow (classic RPG drop style)
- [ ] No despawn timer — loot persists until collected
- [ ] On death: drop all unbanked cargo at death location
- [ ] Loot beacon on HUD pointing to your dropped loot
- [ ] Ship can scoop loot from the ground

### Diablo-Style Weapon Affixes
- [ ] Weapons have prefix (primary stat) + suffix (secondary bonus)
- [ ] Rarity tiers: Common / Magic / Rare / Legendary
- [ ] Rarity determines number of affixes and strength
- [ ] Example: *"Crackling Plasma Rifle of the Void"*

### RPG Stats & Leveling
- [ ] Player XP and level system
- [ ] Drone XP and level system
- [ ] Core stats (wired for expansion): Attack, Defense, Speed, Capacity
- [ ] Future stats: Crit Chance, Crit %, Attack Speed, Range, etc.
- [ ] Drone specialization on level up (scavenger → cargo bonus, sentry → crit chance, etc.)

### Loadout Slots
- [ ] Primary weapon (looted, affixed)
- [ ] Secondary weapon (TBD — grenade, melee, etc.)
- [ ] Suit (defense + speed + cosmetic style/color)
- [ ] Shield (personal → ship-mounted → both at endgame)
- [ ] Bag (cargo capacity)
- [ ] Ship (its own upgrade/skin slot)

---

## Phase 3 — Economy & Shop

### Shop (inside base)
- [ ] Ground floor of base
- [ ] Purchase ship with cargo fragments (not free)
- [ ] Buy suits, weapons, bags with materials/fragments
- [ ] Multiple ship types:
  - Scout — fast, low cargo
  - Freighter — slow, massive cargo hold
  - Gunship — weapons hardpoints, strong shields

### Currency
- [ ] Debris → materials/crafting resources
- [ ] Enemies → coins / crypto drops
- [ ] Each enemy faction drops a different crypto token
- [ ] Robux shop: cosmetics, XP boosts, extra drone slot, convenience (no pay-to-win)
- [ ] Crypto investment system (tabled — endgame feature)

### Loot Tiers
- [ ] Fragment rarity: Common / Rare / Epic
- [ ] Rarity affects XP value and shop price

---

## Phase 4 — Enemies & Combat

### Enemy Ships & Creatures
- [ ] Enemy ships land on planet surface (event-style encounter)
- [ ] Aliens/creatures emerge and must be defeated for loot + coins
- [ ] Zone-scaled difficulty:
  - Compound — scout ships, weak enemies, common loot
  - Badlands — raider parties, tougher, better drops
  - Wastes — heavy assault ships, elite enemies, rare loot
  - Lava Ring — boss-tier ships, legendary drops

### Weapons Expansion
- [ ] Foot laser: wide cone/beam (not pixel-perfect aim required)
  - Beam width as a stat/affix (tight = high damage, wide = AoE lower damage)
- [ ] Explosives — dual use: mining large rocks + combat
- [ ] Missiles — ship-mounted
- [ ] Placeable turrets — deploy anywhere on planet (costs materials + energy)
- [ ] Permanent base turrets — built-in upgrade, defends against landings

---

## Phase 5 — Base & Energy

### Base Overhaul
- [ ] Much larger base footprint
- [ ] Multi-level structure:
  - Ground floor: shop, storage
  - Mid level: upgrades, energy systems
  - Roof: drone station, landing pad with runway lights
- [ ] Each floor separately upgradeable with resources
- [ ] Realistic lighting: spotlights, interior light spill, landing pad edge lights (no oversaturation)
- [ ] Drone recharge station always on roof, upgradeable

### Energy System (progression)
- [ ] Solar panels — free, weak, planet/weather dependent
- [ ] Battery bank — stores solar, limited capacity
- [ ] Fuel generator — burns rock/crystal fragments
- [ ] Plasma reactor — uses rare metals, high output
- [ ] Fusion core — titanium + crystal, powers everything
- [ ] Quantum tap — endgame, self-sustaining
- [ ] Planet type affects available energy sources:
  - Lava → geothermal bonus
  - Ocean → tidal/hydro
  - Deep space → solar nearly useless
- [ ] Energy governs drones, shields, turrets, upgrades

### Depot Stations
- [ ] Placeable around planet near mining zones
- [ ] Ships auto-run cargo routes between depots and base
- [ ] Strategic placement = meaningful on large planet

---

## Phase 6 — World & Planets

### Planet Scale
- [ ] Much larger planet (target ~5–10x current radius)
- [ ] Debris size variation: small rocks → medium chunks → massive boulders
- [ ] Zone travel feels like real distance

### Planet Profiles
- [ ] Each planet defines: sky, fog, atmosphere, sun color/intensity, ambient, stars, time-of-day cycle speed
- [ ] Planet types: Moon, Ocean, Lava, Deep Space, etc.
- [ ] Sun distance/availability affects solar energy
- [ ] Realistic lighting driven by planet type (not hardcoded time of day)
- [ ] Time of day cycles within planet context

### Multiple Planets & Teleport
- [ ] Planets discovered/unlocked through exploration or quests
- [ ] Teleport station base upgrade:
  - Tier 1: one-way beacon (go but fly back)
  - Tier 2: two-way teleport
  - Tier 3: multi-destination with planet selection UI

---

## Phase 7 — Visuals & Polish

### Debris & Loot
- [ ] Debris shape variety — unions, meshes, varied rotation/scale
- [ ] Impact particles, debris chunks fly off on hit
- [ ] Screen shake on big impacts

### Environment
- [ ] Planet surface detail: craters, rock formations, texture variation
- [ ] Atmospheric effects: lens flare, god rays, reactive star field
- [ ] Base: blinking lights, animated panels

### Ships
- [ ] Ship trails — engine exhaust particles, boost effect
- [ ] More realistic ship models with actual cockpit interiors
- [ ] Cockpit view with instrument panel framing

---

## Phase 8 — Idle Game Layer

- [ ] Drones auto-collect debris and defend while offline
- [ ] Turrets auto-fire at incoming enemy ships
- [ ] Collectors auto-scoop loot and bank to base storage
- [ ] Energy system governs idle effectiveness (run out = systems shut down)
- [ ] Login report: loot collected, enemies repelled, energy consumed while away
- [ ] Ship auto-routes between depot stations while idle

---

## Tabled / Future
- Crypto investment system
- Fine-tuned RPG stats (crit, attack speed, etc.) — system wired, values TBD
- Additional weapon types (secondary slot)
- PvP angle
- Guild/clan system
