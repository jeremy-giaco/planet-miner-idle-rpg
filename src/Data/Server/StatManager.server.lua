-- Data/Server/StatManager.server.lua
-- Computes and applies player stats from base schema + equipment bonuses.
-- Other systems read stats via _G.StatManager.get(player, statName).
-- Wired for expansion: add new stats to DataSchema and modifiers here.
if not game:GetService("RunService"):IsServer() then return end
if _G._StatManagerActive then return end
_G._StatManagerActive = true

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes      = ReplicatedStorage:WaitForChild("Remotes")
local statsUpdated = remotes:WaitForChild("StatsUpdated")

-- ── Stat modifiers from equipment ─────────────────────────────────────────────
-- When loadout system is built, each item will register modifiers here.
-- Format: { attack=5, defense=2 } etc.

local equipmentMods = {}  -- [player] = { statName = totalBonus }

-- ── Compute final stats for a player ─────────────────────────────────────────

local function computeStats(player)
    local data = _G.PlayerData and _G.PlayerData.get(player)
    if not data then return nil end

    local base = data.stats
    local mods = equipmentMods[player] or {}

    return {
        attack   = (base.attack   or 10) + (mods.attack   or 0),
        defense  = (base.defense  or 10) + (mods.defense  or 0),
        speed    = (base.speed    or 16) + (mods.speed    or 0),
        capacity = (base.capacity or 20) + (mods.capacity or 0),
        -- Future stats wired in below when needed:
        -- critChance  = (base.critChance  or 0)  + (mods.critChance  or 0),
        -- critPercent = (base.critPercent or 150) + (mods.critPercent or 0),
        -- attackSpeed = (base.attackSpeed or 1)   + (mods.attackSpeed or 0),
        -- range       = (base.range       or 100) + (mods.range       or 0),
    }
end

-- ── Apply stats to character ──────────────────────────────────────────────────

local function applyToCharacter(player, stats)
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.WalkSpeed = math.clamp(stats.speed, 8, 100)
end

-- ── Public API ────────────────────────────────────────────────────────────────

_G.StatManager = {
    -- Get a single stat value for a player
    get = function(player, statName)
        local stats = computeStats(player)
        return stats and stats[statName] or 0
    end,

    -- Get all stats
    getAll = function(player)
        return computeStats(player)
    end,

    -- Register equipment modifiers (called by loadout system later)
    setEquipmentMods = function(player, mods)
        equipmentMods[player] = mods
        -- Reapply to character
        local stats = computeStats(player)
        if stats then
            applyToCharacter(player, stats)
            statsUpdated:FireClient(player, stats)
        end
    end,

    -- Refresh and push stats to client (call after level up, equip change, etc.)
    refresh = function(player)
        local stats = computeStats(player)
        if not stats then return end
        applyToCharacter(player, stats)
        statsUpdated:FireClient(player, stats)
    end,
}

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
    -- Wait for DataStore to load, then apply stats
    player.CharacterAdded:Connect(function()
        task.wait(0.5)  -- let DataStore finish loading
        _G.StatManager.refresh(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    equipmentMods[player] = nil
end)

print("[StatManager] Stat system active")
