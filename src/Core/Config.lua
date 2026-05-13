-- ModuleScript → place in ReplicatedStorage, rename to "Config"
return {
    -- Planet
    PLANET_NAME   = "Moon",
    PLANET_RADIUS = 700,
    PLANET_CENTER = Vector3.new(0, 0, 0),

    -- Drone repair station — south of the base, on sphere surface.
    -- surfaceY at z=180: sqrt(700²-180²) ≈ 676.6  (18.5 studs below pole level, barely noticeable)
    -- South base wall is at z=+100; station sits ~80 studs beyond it.
    STATION_POS = Vector3.new(0, 676.6, 180),

    -- Debris spawning
    DEBRIS_SPAWN_INTERVAL = 4,
    DEBRIS_SPEED          = 60,    -- studs/s initial push toward compound
    DEBRIS_SPAWN_HEIGHT   = 800,   -- Y altitude debris spawns from
    DEBRIS_HEALTH         = 100,
    FRAGMENTS_ON_DEATH    = 3,
    FRAGMENT_TYPES        = {"Rock", "Metal", "Crystal", "Ice"},

    -- Planet surface radius (debris spawns within this XZ footprint)
    MAP_RADIUS = 600,

    -- Metal ore deposits (spawned on surface, collected by rover or player)
    -- weight = relative spawn probability; higher = more common
    METAL_TYPES = {
        { name = "Iron",     color = Color3.fromRGB(140, 130, 120), weight = 50 },
        { name = "Copper",   color = Color3.fromRGB(210, 105,  55), weight = 30 },
        { name = "Silver",   color = Color3.fromRGB(200, 205, 220), weight = 12 },
        { name = "Gold",     color = Color3.fromRGB(255, 200,  30), weight = 6  },
        { name = "Titanium", color = Color3.fromRGB(155, 175, 200), weight = 2  },
    },

    -- Zone radii (XZ distance from origin, innermost first)
    ZONES = {
        { name = "The Compound",  maxRadius =  80  },
        { name = "The Badlands",  maxRadius =  300 },
        { name = "The Wastes",    maxRadius =  500 },
        { name = "The Lava Ring", maxRadius =  math.huge },
    },

    -- Laser tool
    LASER_DAMAGE   = 100,
    LASER_RANGE    = 8000,
    LASER_COOLDOWN = 0.25,
    LASER_COLOR    = Color3.fromRGB(255, 30, 30),
}
