-- Script → ServerScriptService (CoinSystem renamed to MetalSystem internally)
-- Spawns metal ore deposits on the moon surface. Rover and player can collect them.
if not game:GetService("RunService"):IsServer() then return end
if _G._CoinSystemActive then return end
_G._CoinSystemActive = true
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local remotes             = ReplicatedStorage:WaitForChild("Remotes")
local registerCollectible = remotes:WaitForChild("RegisterCollectible")
local serverMetalEarned   = remotes:WaitForChild("ServerMetalEarned")
local collectMetalEvent   = remotes:WaitForChild("CollectMetal")

local oreFolder = Instance.new("Folder")
oreFolder.Name   = "Ores"
oreFolder.Parent = Workspace

local SPAWN_INTERVAL = 6
local MAX_ORES       = 18

-- ── Weighted random metal picker ──────────────────────────────────────────────

local function pickMetal()
    local total = 0
    for _, m in ipairs(Config.METAL_TYPES) do total += m.weight end
    local r = math.random() * total
    local cum = 0
    for _, m in ipairs(Config.METAL_TYPES) do
        cum += m.weight
        if r <= cum then return m end
    end
    return Config.METAL_TYPES[1]
end

-- ── Spawn one ore nugget on the flat world surface ───────────────────────────
-- Ores appear within the Compound + Badlands zones (radius 20-180 from origin).
-- They sit slightly above ground level and spin around the Y axis.

local COMPOUND_SURFACE_Y = 3    -- top of Compound slab
local BADLANDS_SURFACE_Y = 1.5  -- top of Badlands slab

local function surfaceYForRadius(r)
    if r <= 810 then return COMPOUND_SURFACE_Y end
    return BADLANDS_SURFACE_Y
end

local function spawnOre()
    if #oreFolder:GetChildren() >= MAX_ORES then return end

    local metal = pickMetal()

    -- Random flat-world position within compound/badlands
    local angle  = math.random() * math.pi * 2
    local radius = math.random(200, 1800)   -- 200-1800 studs from origin
    local groundY = surfaceYForRadius(radius)
    local pos = Vector3.new(
        math.cos(angle) * radius,
        groundY + 0.6,   -- hover a little above surface
        math.sin(angle) * radius
    )

    -- Size varies slightly by rarity — rarer metals are smaller nuggets
    local s = math.random(18, 28) / 10   -- 1.8–2.8 studs

    local ore = Instance.new("Part")
    ore.Name      = metal.name
    ore.Shape     = Enum.PartType.Block
    ore.Size      = Vector3.new(s, s * 0.6, s)
    ore.Position  = pos
    ore.Color     = metal.color
    ore.Material  = Enum.Material.Neon
    ore.Anchored  = true
    ore.CanCollide = false
    ore.CastShadow = false
    ore.Parent    = oreFolder

    ore:SetAttribute("IsMetal",    true)
    ore:SetAttribute("MetalType",  metal.name)

    -- Gentle Y-axis spin so it's easy to spot
    local spinAngle = math.random() * 360
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if not ore or not ore.Parent then conn:Disconnect() return end
        spinAngle += dt * 80
        ore.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(spinAngle), 0)
    end)

    -- Player walk-over collection
    ore.Touched:Connect(function(hit)
        if not ore.Parent then return end
        local char = hit.Parent
        if not char or not char:FindFirstChildOfClass("Humanoid") then return end
        local player = Players:GetPlayerFromCharacter(char)
        if not player then return end
        conn:Disconnect()
        ore:Destroy()
        if _G.PlayerData then
            _G.PlayerData.addMetal(player, metal.name)
            _G.PlayerData.addXP(player, 15)
        end
        collectMetalEvent:FireClient(player, metal.name)
        serverMetalEarned:Fire(player, metal.name)
    end)

    -- Register with rover
    registerCollectible:Fire(ore, "Metal", metal.name)

    -- Despawn if uncollected after 60s
    task.delay(60, function()
        if ore and ore.Parent then
            conn:Disconnect()
            TweenService:Create(ore, TweenInfo.new(1.5), {Transparency = 1}):Play()
            task.delay(1.5, function()
                if ore and ore.Parent then ore:Destroy() end
            end)
        end
    end)
end

-- ── Spawn loop ────────────────────────────────────────────────────────────────

local lastSpawn = 0
RunService.Heartbeat:Connect(function()
    local now = tick()
    if now - lastSpawn >= SPAWN_INTERVAL then
        lastSpawn = now
        task.spawn(spawnOre)
    end
end)

print("[SkyBase] Metal ore system active")
