-- Data/Shared/DataSchema.lua
-- Defines the default player data structure.
-- All new fields must have defaults here so old saves auto-migrate.

return {
    -- ── Character ─────────────────────────────────────────────────────────────
    level       = 1,
    xp          = 0,

    -- ── Stats (wired for expansion) ───────────────────────────────────────────
    stats = {
        attack   = 10,
        defense  = 10,
        speed    = 16,   -- walkspeed
        capacity = 20,   -- max cargo slots
    },

    -- ── Cargo / Inventory ─────────────────────────────────────────────────────
    fragments = {},  -- { Rock=0, Metal=0, Crystal=0, Ice=0 }
    metals    = {},  -- { Iron=0, Copper=0, Silver=0, Gold=0, Titanium=0 }
    coins     = 0,

    -- ── Loadout ───────────────────────────────────────────────────────────────
    loadout = {
        weapon    = nil,  -- item id string
        secondary = nil,
        suit      = nil,
        shield    = nil,
        bag       = nil,
        ship      = "starter_ship",
    },

    -- ── Unlocks ───────────────────────────────────────────────────────────────
    unlockedShips   = { "starter_ship" },
    unlockedPlanets = { "moon" },

    -- ── Settings ──────────────────────────────────────────────────────────────
    settings = {
        controlMode  = "classic",   -- classic | twin-stick | tap-to-fly | gyro
        gyroSensitivity = 1.0,
        invertY      = false,
    },
}
