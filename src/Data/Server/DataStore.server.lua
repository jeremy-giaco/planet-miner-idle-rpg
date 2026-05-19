-- Data/Server/DataStore.server.lua
-- Handles all player data persistence via Roblox DataStoreService.
-- Exposes a PlayerData module to other server scripts via _G.PlayerData.
if not game:GetService("RunService"):IsServer() then return end
-- Prevent a second instance (Studio user_src mirror) from running and
-- overwriting _G.PlayerData / saving a stale cache over the real one.
if _G.PlayerData then return end

local DataStoreService  = game:GetService("DataStoreService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Schema = require(ReplicatedStorage:WaitForChild("DataSchema"))

local store  = DataStoreService:GetDataStore("PlayerData_v1")

-- In-memory cache: [player] = data table
local cache  = {}

-- ── Deep copy a table ─────────────────────────────────────────────────────────

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do copy[k] = deepCopy(v) end
    return copy
end

-- ── Migrate: fill in any missing keys from schema defaults ────────────────────

local function migrate(data, schema)
    for k, v in pairs(schema) do
        if data[k] == nil then
            data[k] = deepCopy(v)
        elseif type(v) == "table" and type(data[k]) == "table" then
            migrate(data[k], v)
        end
    end
    return data
end

-- ── Load player data ──────────────────────────────────────────────────────────

local function loadData(player)
    local key     = "player_" .. player.UserId
    local success, result = pcall(function()
        return store:GetAsync(key)
    end)

    local data
    if success and result then
        data = migrate(result, deepCopy(Schema))
    else
        if not success then
            warn("[DataStore] Failed to load data for", player.Name, ":", result)
        end
        data = deepCopy(Schema)
    end

    cache[player] = data
    return data
end

-- ── Save player data ──────────────────────────────────────────────────────────

local function saveData(player)
    local data = cache[player]
    if not data then return end

    local key = "player_" .. player.UserId
    local success, err = pcall(function()
        store:SetAsync(key, data)
    end)

    if not success then
        warn("[DataStore] Failed to save data for", player.Name, ":", err)
    end
end

-- ── Public API via _G.PlayerData ─────────────────────────────────────────────

_G.PlayerData = {
    -- Get a player's live data table (modify directly, it's the live cache)
    get = function(player)
        return cache[player]
    end,

    -- Force an immediate save (e.g. after a purchase)
    save = function(player)
        saveData(player)
    end,

    -- Add material (unified — replaces addFragment / addMetal)
    addMaterial = function(player, matName, qty)
        local data = cache[player]
        if not data then return end
        data.materials[matName] = (data.materials[matName] or 0) + (qty or 1)
    end,

    -- Deduct material, returns true if successful
    deductMaterial = function(player, matName, qty)
        local data = cache[player]
        if not data then return false end
        local count = data.materials[matName] or 0
        local amount = qty or 1
        if count < amount then return false end
        data.materials[matName] = count - amount
        return true
    end,

    -- Add coins
    addCoins = function(player, amount)
        local data = cache[player]
        if not data then return end
        data.coins = (data.coins or 0) + amount
    end,

    -- Add XP, handle level up
    addXP = function(player, amount)
        local data = cache[player]
        if not data then return end
        data.xp = (data.xp or 0) + amount
        -- Simple level curve: 100 * level^1.5 XP per level
        local xpNeeded = math.floor(100 * (data.level ^ 1.5))
        while data.xp >= xpNeeded do
            data.xp     = data.xp - xpNeeded
            data.level  = data.level + 1
            xpNeeded    = math.floor(100 * (data.level ^ 1.5))
            print("[DataStore]", player.Name, "leveled up to", data.level)
            -- Bump base stats on level up
            data.stats.attack   = data.stats.attack   + 2
            data.stats.defense  = data.stats.defense  + 2
            data.stats.capacity = data.stats.capacity + 1
            -- Notify StatManager to refresh
            if _G.StatManager then _G.StatManager.refresh(player) end
        end
    end,
}

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
    loadData(player)
    print("[DataStore] Loaded data for", player.Name)
end)

Players.PlayerRemoving:Connect(function(player)
    saveData(player)   -- yields until SetAsync completes
    print("[DataStore] Saved data for", player.Name)
    cache[player] = nil
end)

-- Auto-save all players every 30 seconds
task.spawn(function()
    while true do
        task.wait(30)
        for player, _ in pairs(cache) do
            if player and player.Parent then
                saveData(player)
            end
        end
    end
end)

-- Save all on server shutdown — run in parallel and WAIT for completion
-- so Studio shutdown doesn't cut off SetAsync calls mid-write
game:BindToClose(function()
    local pending = 0
    for player, _ in pairs(cache) do
        pending += 1
        task.spawn(function()
            saveData(player)
            pending -= 1
        end)
    end
    -- Yield until all saves finish (or 10s safety timeout)
    local t = 0
    while pending > 0 and t < 10 do
        task.wait(0.1)
        t += 0.1
    end
end)

print("[DataStore] Player data system active")
