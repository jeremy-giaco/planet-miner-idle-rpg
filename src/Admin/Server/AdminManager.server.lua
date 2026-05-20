-- Admin/Server/AdminManager.server.lua
-- Handles live config tweaks from the AdminConsole UI.
-- RESET_DEFAULTS → restores Config to startup values this session.
-- SAVE_DEFAULTS  → persists current live Config to DataStore (survives restart).
if not game:GetService("RunService"):IsServer() then return end

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local DataStoreService  = game:GetService("DataStoreService")

local Config      = require(ReplicatedStorage:WaitForChild("Config"))
local remotes     = ReplicatedStorage:WaitForChild("Remotes")
local adminCmd    = remotes:WaitForChild("AdminCommand")
local configUpdate= remotes:WaitForChild("ConfigUpdated")

-- ── Snapshot Config.lua values at startup (before any mutations) ──────────────

local configDefaults = {}
for k, v in pairs(Config) do
    if type(v) == "number" then configDefaults[k] = v end
end
for _, mat in ipairs(Config.MATERIALS) do
    configDefaults["MAT_WEIGHT_" .. mat.name] = mat.weight
end

-- ── DataStore for persisted overrides ────────────────────────────────────────

local DS_KEY        = "ConfigOverrides_v1"
local overrideStore = DataStoreService:GetDataStore("AdminConfigOverrides")

local function loadOverrides()
    local ok, data = pcall(function()
        return overrideStore:GetAsync(DS_KEY)
    end)
    if not ok or type(data) ~= "table" then return end
    local count = 0
    for k, v in pairs(data) do
        if type(v) == "number" then
            Config[k] = v
            -- patch MATERIALS table for weight keys
            local matName = k:match("^MAT_WEIGHT_(.+)$")
            if matName then
                for _, mat in ipairs(Config.MATERIALS) do
                    if mat.name == matName then mat.weight = v; break end
                end
            end
            count += 1
        end
    end
    print(string.format("[AdminManager] Loaded %d config overrides from DataStore", count))
end

local function saveOverrides()
    -- Collect all current live numeric Config values that differ from Config.lua defaults
    local data = {}
    for k, defVal in pairs(configDefaults) do
        local cur = Config[k]
        if type(cur) == "number" and cur ~= defVal then
            data[k] = cur
        end
    end
    -- Also save material weight overrides
    for _, mat in ipairs(Config.MATERIALS) do
        local k = "MAT_WEIGHT_" .. mat.name
        if mat.weight ~= configDefaults[k] then
            data[k] = mat.weight
        end
    end
    local ok, err = pcall(function()
        overrideStore:SetAsync(DS_KEY, data)
    end)
    if ok then
        print(string.format("[AdminManager] Saved %d config overrides to DataStore", #data))
    end
    return ok, err
end

-- Load persisted overrides immediately so they're live before any player joins
loadOverrides()

-- ── Admin whitelist ───────────────────────────────────────────────────────────

local ADMIN_IDS = {
    [game.CreatorId] = true,
}

local function isAdmin(player)
    if RunService:IsStudio() then return true end
    return ADMIN_IDS[player.UserId] == true
end

-- ── Tunables ──────────────────────────────────────────────────────────────────

local TUNABLES = {
    -- Movement
    GRAVITY                   = { min = 10,   max = 500,   isServer = true,
        apply = function(v) workspace.Gravity = v end },
    WALK_SPEED                = { min = 4,    max = 100,   isServer = false },
    RUN_SPEED                 = { min = 4,    max = 200,   isServer = false },
    JUMP_POWER                = { min = 10,   max = 500,   isServer = false },
    -- Jetpack
    JETPACK_THRUST            = { min = 50,   max = 2000,  isServer = false },
    JETPACK_FORWARD_THRUST    = { min = 50,   max = 2000,  isServer = false },
    JETPACK_MAX_UP_SPEED      = { min = 10,   max = 500,   isServer = false },
    JETPACK_MAX_HORIZ_SPEED   = { min = 10,   max = 500,   isServer = false },
    JETPACK_ACTIVATION_DELAY  = { min = 0,    max = 3,     isServer = false },
    -- Laser
    LASER_DAMAGE              = { min = 1,    max = 10000, isServer = false },
    LASER_RANGE               = { min = 10,   max = 50000, isServer = false },
    LASER_COOLDOWN            = { min = 0.02, max = 10,    isServer = false },
    -- Shield
    SHIELD_RADIUS             = { min = 4,    max = 40,    isServer = false },
    SHIELD_ENERGY_MAX         = { min = 10,   max = 10000, isServer = false },
    SHIELD_ENERGY_DRAIN       = { min = 0,    max = 100,   isServer = false },
    SHIELD_RECHARGE_RATE      = { min = 1,    max = 500,   isServer = false },
    SHIELD_DAMAGE             = { min = 1,    max = 10000, isServer = false },
    -- Tachyite
    TACHYITE_DROP_CHANCE      = { min = 0,    max = 1,     isServer = false },
    TACHYITE_SPEED_BONUS      = { min = 0,    max = 200,   isServer = false },
    TACHYITE_DURATION         = { min = 5,    max = 600,   isServer = false },
    -- Debris
    DEBRIS_SPAWN_INTERVAL     = { min = 0.1,  max = 60,    isServer = false },
    DEBRIS_SPAWN_PER_WAVE     = { min = 1,    max = 500,   isServer = false },
    DEBRIS_INITIAL_BURST      = { min = 0,    max = 1000,  isServer = false },
    DEBRIS_SPEED              = { min = 1,    max = 1000,  isServer = false },
    DEBRIS_SPAWN_HEIGHT       = { min = 100,  max = 5000,  isServer = false },
    DEBRIS_HEALTH             = { min = 1,    max = 10000, isServer = false },
    DEBRIS_LIFETIME           = { min = 5,    max = 600,   isServer = false },
    DEBRIS_HIT_COOLDOWN       = { min = 0,    max = 5,     isServer = false },
    DEBRIS_DEATH_PIECES       = { min = 1,    max = 100,   isServer = false },
    DEBRIS_CARGO_CHANCE       = { min = 0,    max = 1,     isServer = false },
    DEBRIS_COLLECT_RADIUS     = { min = 1,    max = 200,   isServer = false },
    -- Collection
    ORE_MAGNET_RADIUS         = { min = 2,    max = 200,   isServer = false },
    ORE_COLLECT_RADIUS        = { min = 1,    max = 50,    isServer = false },
    COLLECTIBLE_LIFETIME      = { min = 5,    max = 3600,  isServer = false },
    COLLECTIBLE_ROTATION_SPEED= { min = 0,    max = 20,    isServer = false },
    -- Ore spawning
    ORE_SPAWN_INTERVAL        = { min = 0.5,  max = 60,    isServer = false },
    ORE_MAX_COUNT             = { min = 1,    max = 2000,  isServer = false },
    -- Drones
    DRONE_SPEED               = { min = 1,    max = 500,   isServer = false },
    DRONE_CARGO_CAPACITY      = { min = 1,    max = 1000,  isServer = false },
    DRONE_GUN_RANGE           = { min = 10,   max = 2000,  isServer = false },
    DRONE_GUN_COOLDOWN        = { min = 0.1,  max = 30,    isServer = false },
    DRONE_GUN_DAMAGE          = { min = 1,    max = 10000, isServer = false },
    DRONE_GUARD_RADIUS        = { min = 2,    max = 100,   isServer = false },
    DRONE_GUARD_HEIGHT        = { min = 2,    max = 100,   isServer = false },
    DRONE_MAX_HEALTH          = { min = 10,   max = 10000, isServer = false },
    DRONE_DEBRIS_DAMAGE       = { min = 0,    max = 1000,  isServer = false },
    DRONE_REPAIR_THRESHOLD    = { min = 1,    max = 1000,  isServer = false },
    DRONE_REPAIR_RATE         = { min = 0.1,  max = 1000,  isServer = false },
    ROVER_HOVER_HEIGHT        = { min = 1,    max = 100,   isServer = false },
}

for _, mat in ipairs(Config.MATERIALS) do
    TUNABLES["MAT_WEIGHT_" .. mat.name] = { min = 0, max = 500, isServer = false, matName = mat.name }
end

-- ── Walk speed on spawn ───────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid")
        hum.WalkSpeed = Config.RUN_SPEED
    end)
end)

-- ── Command handler ───────────────────────────────────────────────────────────

adminCmd.OnServerInvoke = function(player, key, value)
    if not isAdmin(player) then return false, "Not authorized." end

    -- ── Special commands ──────────────────────────────────────────────────────

    if key == "RESET_DEFAULTS" then
        -- Restore all Config values to their Config.lua startup snapshot
        for k, v in pairs(configDefaults) do
            Config[k] = v
            local matName = k:match("^MAT_WEIGHT_(.+)$")
            if matName then
                for _, mat in ipairs(Config.MATERIALS) do
                    if mat.name == matName then mat.weight = v; break end
                end
            end
            configUpdate:FireAllClients(k, v)
        end
        if Config.GRAVITY then workspace.Gravity = Config.GRAVITY end
        print("[AdminManager] Config reset to defaults by " .. player.Name)
        return true, "Reset to Config.lua defaults"
    end

    if key == "SAVE_DEFAULTS" then
        local ok, err = saveOverrides()
        if ok then
            print("[AdminManager] Config overrides saved by " .. player.Name)
            return true, "Overrides saved to DataStore"
        else
            return false, tostring(err)
        end
    end

    -- ── Regular tunable ───────────────────────────────────────────────────────

    local tun = TUNABLES[key]
    if not tun then return false, "Unknown key: " .. tostring(key) end

    local num = tonumber(value)
    if not num then return false, "Value must be a number." end
    num = math.clamp(num, tun.min, tun.max)

    Config[key] = num

    if tun.matName then
        for _, mat in ipairs(Config.MATERIALS) do
            if mat.name == tun.matName then mat.weight = num; break end
        end
    end

    if tun.apply then pcall(tun.apply, num) end

    configUpdate:FireAllClients(key, num)
    return true, string.format("%s = %g", key, num)
end
