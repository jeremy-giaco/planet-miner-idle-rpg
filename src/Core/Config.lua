-- ModuleScript → ReplicatedStorage/Config
-- SOURCE OF TRUTH for all default game values.
-- Live overrides are stored in DataStore and merged on top at runtime.
-- To make a live tweak permanent: update this file, commit, clear DataStore override.

return {

    -- ── World ─────────────────────────────────────────────────────────────────

    PLANET_NAME     = "Moon",
    MAP_WIDTH       = 5000,         -- total flat map width (studs)
    MAP_DEPTH       = 5000,         -- total flat map depth (studs)
    MAP_GROUND_Y    = 0,            -- Y level of the ground plane
    BASE_POSITION   = Vector3.new(0, 0, 0),   -- center of the base (north/safe zone)

    -- ── Physics ───────────────────────────────────────────────────────────────

    GRAVITY         = 196.2,        -- workspace gravity (studs/s²)

    -- ── Lighting ─────────────────────────────────────────────────────────────

    LIGHTING_CLOCK_TIME      = 7.083,   -- time of day (6:05 AM)
    LIGHTING_BRIGHTNESS      = 3.5,
    LIGHTING_DIFFUSE_SCALE   = 0.15,
    LIGHTING_SPECULAR_SCALE  = 0.8,
    LIGHTING_AMBIENT         = Color3.fromRGB(18, 18, 28),
    LIGHTING_OUTDOOR_AMBIENT = Color3.fromRGB(22, 22, 35),
    LIGHTING_FOG_START       = 4000,
    LIGHTING_FOG_END         = 7000,
    LIGHTING_FOG_COLOR       = Color3.fromRGB(2, 2, 8),

    -- ── Player ────────────────────────────────────────────────────────────────

    WALK_SPEED      = 15,           -- slow walk speed
    RUN_SPEED       = 40,           -- run speed (toggle with R)
    JUMP_POWER      = 50,           -- default Roblox jump power

    -- ── Tachyite ──────────────────────────────────────────────────────────────

    TACHYITE_DROP_CHANCE    = 0.20,     -- probability per debris death
    TACHYITE_SPEED_BONUS    = 10,       -- run-speed added per stack
    TACHYITE_DURATION       = 180,      -- seconds before all stacks expire

    -- ── Jetpack ──────────────────────────────────────────────────────────────

    JETPACK_THRUST              = 200,
    JETPACK_MAX_UP_SPEED        = 200,
    JETPACK_FORWARD_THRUST      = 300,
    JETPACK_MAX_HORIZ_SPEED     = 300,
    JETPACK_ACTIVATION_DELAY    = 0.5,

    -- ── Shield ───────────────────────────────────────────────────────────────

    SHIELD_RADIUS       = 5,     -- bubble radius in studs
    SHIELD_ENERGY_MAX   = 500,   -- max energy capacity
    SHIELD_ENERGY_DRAIN = 1,     -- energy lost per debris chunk destroyed
    SHIELD_RECHARGE_RATE= 30,    -- energy per second while unequipped
    SHIELD_DAMAGE       = 50,    -- damage dealt to debris per shield hit

    -- ── Weapons ──────────────────────────────────────────────────────────────

    LASER_DAMAGE    = 50,
    LASER_RANGE     = 8000,
    LASER_COOLDOWN  = 0.1,
    LASER_COLOR     = Color3.fromRGB(255, 30, 30),

    -- ── Debris ───────────────────────────────────────────────────────────────

    DEBRIS_SPAWN_INTERVAL   = 1,        -- seconds between spawn waves
    DEBRIS_SPAWN_PER_WAVE   = 25,        -- chunks per wave
    DEBRIS_INITIAL_BURST    = 100,       -- chunks spawned on server start
    DEBRIS_SPEED            = 50,       -- studs/s initial velocity toward base
    DEBRIS_SPAWN_HEIGHT     = 800,      -- Y altitude debris spawns from
    DEBRIS_HEALTH           = 200,
    DEBRIS_LIFETIME         = 120,      -- seconds before auto-cleanup
    DEBRIS_SURFACE_SNAP_DELAY = 5,      -- seconds before anchoring on ground
    DEBRIS_HIT_COOLDOWN     = 0.2,      -- dedup window for repeated hits
    DAMAGE_FLASH_DURATION   = 0.06,     -- seconds part flashes red on hit

    FRAGMENTS_ON_DEATH      = 3,        -- collectible fragments per debris death
    DEBRIS_DEATH_PIECES     = 27,       -- visual shards on death
    DEBRIS_CARGO_CHANCE     = 0.20,     -- fraction of shards becoming collectible
    DEBRIS_COLLECT_RADIUS   = 50,       -- studs for auto-collect proximity
    ORE_MAGNET_RADIUS       = 50,       -- studs — ore starts flying toward player
    ORE_COLLECT_RADIUS      = 20,        -- studs — ore collected on arrival
    ORE_SPAWN_INTERVAL      = 5,        -- seconds between ore spawns
    ORE_MAX_COUNT           = 500,       -- max ore nodes alive at once

    COLLECTIBLE_LIFETIME        = 500,   -- seconds before collectible despawns
    COLLECTIBLE_BEACON_HEIGHT   = 90,   -- height of collection beacon beam
    COLLECTIBLE_ROTATION_SPEED  = 1.9,  -- rad/s spin speed

    -- ── Materials ────────────────────────────────────────────────────────────
    -- Raw materials dropped by debris. weight = relative spawn probability.
    -- element = elemental affinity for combat/crafting interactions.

    MATERIALS = {
        { name = "Iron",       rarity = "Common",   weight = 35, element = "Earth",
          color = Color3.fromRGB(140, 130, 120),
          description = "Abundant structural metal. Base crafting material." },

        { name = "Carbon",     rarity = "Common",   weight = 30, element = "Earth",
          color = Color3.fromRGB(40,  40,  40),
          description = "Coal-like. Combines with Iron to make Steel." },

        { name = "Silicate",   rarity = "Common",   weight = 20, element = "Earth",
          color = Color3.fromRGB(200, 195, 180),
          description = "Sandy mineral. Refines into Glass." },

        { name = "Copper",     rarity = "Uncommon", weight = 10, element = "Electric",
          color = Color3.fromRGB(210, 105,  55),
          description = "Excellent conductor. Electric-attuned weapons." },

        { name = "Nickel",     rarity = "Uncommon", weight = 8,  element = "Earth",
          color = Color3.fromRGB(160, 165, 160),
          description = "Hardens alloys. Combines with Iron for tougher gear." },

        { name = "Silver",     rarity = "Rare",     weight = 4,  element = "Ice",
          color = Color3.fromRGB(200, 205, 220),
          description = "Valuable. Currency and Ice-attuned crafting." },

        { name = "Gold",       rarity = "Rare",     weight = 3,  element = "Fire",
          color = Color3.fromRGB(255, 200,  30),
          description = "Valuable. Currency and Fire-attuned crafting." },

        { name = "Titanium",   rarity = "Rare",     weight = 2,  element = "Fire",
          color = Color3.fromRGB(155, 175, 200),
          description = "Extreme heat resistance. Best armor material." },

        { name = "Crystal",    rarity = "Exotic",   weight = 1,  element = "varies",
          color = Color3.fromRGB(180, 220, 255),
          description = "Element depends on crystal type. Rare drop." },

        { name = "VoidMatter", rarity = "Exotic",   weight = 0.5, element = "Void",
          color = Color3.fromRGB(60,  0,  80),
          description = "Unknown properties. Endgame material." },
    },

    -- ── Elements ─────────────────────────────────────────────────────────────
    -- Elemental affinities for weapons, enemies, areas, and materials.
    -- weakness = takes double damage from this element
    -- strength = takes half damage from this element

    ELEMENTS = {
        Earth   = { weakness = "Void",     strength = "Electric" },
        Fire    = { weakness = "Ice",      strength = "Earth"    },
        Ice     = { weakness = "Fire",     strength = "Void"     },
        Electric= { weakness = "Earth",    strength = "Ice"      },
        Void    = { weakness = "Light",    strength = "Fire"     },
        Light   = { weakness = "Electric", strength = "Void"     },
        Poison  = { weakness = "Fire",     strength = "Light"    },
    },

    -- ── Areas ─────────────────────────────────────────────────────────────────
    -- Flat map areas defined by polygon boundaries (x,z coordinates).
    -- difficulty_multiplier scales enemy health/attack/defense within this area.
    -- boundary is defined clockwise as {x, z} pairs.
    -- For now using simple radius bands as placeholder — replace with polygons.

    AREAS = {
        {
            id                   = 1,
            name                 = "area_1",
            display_name         = "The Compound",
            element              = "Earth",
            difficulty_multiplier = 1,
            min_radius           = 0,
            max_radius           = 250,
        },
        {
            id                   = 2,
            name                 = "area_2",
            display_name         = "The Badlands",
            element              = "Fire",
            difficulty_multiplier = 3,
            min_radius           = 250,
            max_radius           = 650,
        },
        {
            id                   = 3,
            name                 = "area_3",
            display_name         = "The Wastes",
            element              = "Poison",
            difficulty_multiplier = 8,
            min_radius           = 650,
            max_radius           = 1050,
        },
        {
            id                   = 4,
            name                 = "area_4",
            display_name         = "The Lava Ring",
            element              = "Fire",
            difficulty_multiplier = 20,
            min_radius           = 1050,
            max_radius           = math.huge,
        },
    },

    -- ── Drones ───────────────────────────────────────────────────────────────

    DRONE_SPEED             = 60,
    DRONE_CARGO_CAPACITY    = 50,
    DRONE_GUN_RANGE         = 160,
    DRONE_GUN_COOLDOWN      = 3,
    DRONE_GUN_DAMAGE        = 15,
    DRONE_GUARD_RADIUS      = 10,
    DRONE_GUARD_HEIGHT      = 18,
    DRONE_MAX_HEALTH        = 100,
    DRONE_DEBRIS_DAMAGE     = 25,
    DRONE_REPAIR_THRESHOLD  = 40,
    DRONE_REPAIR_RATE       = 8,
    ROVER_HOVER_HEIGHT      = 12,

    -- ── Base ─────────────────────────────────────────────────────────────────

    BASE_WIDTH      = 140,
    BASE_DEPTH      = 200,
    BASE_HEIGHT     = 44,
    BASE_DOOR_WIDTH = 16,
    BASE_COLORS = {
        hull       = Color3.fromRGB(36,  42,  62),
        panel      = Color3.fromRGB(50,  58,  85),
        neon       = Color3.fromRGB(60, 150, 255),
        foundation = Color3.fromRGB(160, 157, 170),
    },

    -- Drone repair station position (relative to base)
    STATION_POS = Vector3.new(0, 44, -100),

    -- ── Admin ────────────────────────────────────────────────────────────────
    -- Roblox usernames that can access the admin console.

    ADMIN_USERS = { "jeromeo79" },

    -- ── Ability Classes ───────────────────────────────────────────────────────
    -- The six ability classes. XP is tracked per class per player/drone.
    -- Organic growth — use it more, get better at it.

    ABILITY_CLASSES = {
        { name = "Melee",      description = "Swords, hammers, close combat" },
        { name = "Ranged",     description = "Lasers, beams, projectiles"    },
        { name = "Defense",    description = "Shields, armor, barriers"      },
        { name = "Harvesting", description = "Mining, collecting, salvaging" },
        { name = "Flight",     description = "Jetpack, ships, hover"         },
        { name = "Support",    description = "Scanning, repair, utility"     },
        { name = "Explosive",  description = "Grenades, mines, rockets"      },
    },

    -- ── Item Rarities ─────────────────────────────────────────────────────────

    RARITIES = {
        { name = "Common",    color = Color3.fromRGB(180, 180, 180), weight = 60 },
        { name = "Uncommon",  color = Color3.fromRGB(80,  200,  80), weight = 25 },
        { name = "Rare",      color = Color3.fromRGB(60,  120, 255), weight = 10 },
        { name = "Epic",      color = Color3.fromRGB(160,  60, 255), weight = 4  },
        { name = "Legendary", color = Color3.fromRGB(255, 165,   0), weight = 1  },
    },
}
