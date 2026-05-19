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
    materials = {},  -- unified: { Iron=0, Carbon=0, Crystal=0, ... } (Config.MATERIALS)
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
