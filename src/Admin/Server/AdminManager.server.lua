-- Admin/Server/AdminManager.server.lua
-- Handles live config tweaks from the AdminConsole UI.
-- Only players listed in ADMINS (or running in Studio) can use this.
if not game:GetService("RunService"):IsServer() then return end

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Config  = require(ReplicatedStorage:WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local adminCmd     = remotes:WaitForChild("AdminCommand")
local configUpdate = remotes:WaitForChild("ConfigUpdated")

-- ── Admin whitelist ───────────────────────────────────────────────────────────
-- Add your Roblox UserId here. Also auto-allows anyone in Studio.

local ADMIN_IDS = {
    [game.CreatorId] = true,   -- game owner always admin
}

local function isAdmin(player)
    if RunService:IsStudio() then return true end
    return ADMIN_IDS[player.UserId] == true
end

-- ── Tunable keys — maps name → { configKey, min, max, isServer, applyFn }
-- isServer=true  → change applied here and replicated to clients
-- isServer=false → replicated to clients only (client script owns the value)

local TUNABLES = {
    -- Movement
    GRAVITY                = { min = 10,   max = 500,  isServer = true,
        apply = function(v) workspace.Gravity = v end },
    WALK_SPEED             = { min = 4,    max = 100,  isServer = false },
    RUN_SPEED              = { min = 4,    max = 200,  isServer = false },
    -- Jetpack (client-side)
    JETPACK_THRUST         = { min = 50,   max = 2000, isServer = false },
    JETPACK_FORWARD_THRUST = { min = 50,   max = 2000, isServer = false },
    JETPACK_MAX_UP_SPEED   = { min = 10,   max = 500,  isServer = false },
    JETPACK_MAX_HORIZ_SPEED= { min = 10,   max = 500,  isServer = false },
    -- Collection
    ORE_MAGNET_RADIUS      = { min = 2,    max = 100,  isServer = false },
    ORE_COLLECT_RADIUS     = { min = 2,    max = 30,   isServer = false },
    -- Ore spawning
    ORE_SPAWN_INTERVAL     = { min = 0.5,  max = 60,   isServer = false },
    ORE_MAX_COUNT          = { min = 1,    max = 200,  isServer = false },
    -- Debris
    DEBRIS_SPAWN_INTERVAL  = { min = 0.5,  max = 60,   isServer = false },
    DEBRIS_SPAWN_PER_WAVE  = { min = 1,    max = 20,   isServer = false },
    DEBRIS_CARGO_CHANCE    = { min = 0,    max = 1,    isServer = false },
    -- Tachyite
    TACHYITE_DROP_CHANCE   = { min = 0,    max = 1,    isServer = false },
    TACHYITE_SPEED_BONUS   = { min = 0,    max = 200,  isServer = false },
    TACHYITE_DURATION      = { min = 5,    max = 600,  isServer = false },
}

-- Build MAT_WEIGHT_<name> tunables from Config.MATERIALS
for _, mat in ipairs(Config.MATERIALS) do
    local key = "MAT_WEIGHT_" .. mat.name
    TUNABLES[key] = { min = 0, max = 500, isServer = false, matName = mat.name }
end

-- ── Handle command ────────────────────────────────────────────────────────────

-- Apply walk speed to newly spawned characters so it survives respawns
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid")
        hum.WalkSpeed = Config.RUN_SPEED  -- client toggle script manages walk/run
    end)
end)

adminCmd.OnServerInvoke = function(player, key, value)
    if not isAdmin(player) then
        return false, "Not authorized."
    end

    local tun = TUNABLES[key]
    if not tun then
        return false, "Unknown key: " .. tostring(key)
    end

    local num = tonumber(value)
    if not num then
        return false, "Value must be a number."
    end
    num = math.clamp(num, tun.min, tun.max)

    -- Mutate the live Config table so server-side reads pick it up instantly
    Config[key] = num

    -- For material weight keys, also patch the MATERIALS table entry
    if tun.matName then
        for _, mat in ipairs(Config.MATERIALS) do
            if mat.name == tun.matName then
                mat.weight = num
                break
            end
        end
    end

    -- Apply server-side effect if needed
    if tun.apply then
        pcall(tun.apply, num)
    end

    -- Broadcast to all clients so their local vars update
    configUpdate:FireAllClients(key, num)

    return true, string.format("%s = %g", key, num)
end
