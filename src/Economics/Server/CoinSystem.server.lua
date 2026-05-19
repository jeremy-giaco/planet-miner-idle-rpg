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

local remotes              = ReplicatedStorage:WaitForChild("Remotes")
local registerCollectible  = remotes:WaitForChild("RegisterCollectible")
local materialEarned       = remotes:WaitForChild("MaterialEarned")
local collectFragmentEvent = remotes:WaitForChild("CollectFragment")

local oreFolder = Instance.new("Folder")
oreFolder.Name   = "Ores"
oreFolder.Parent = Workspace

-- Spawn constants read from Config each tick so admin tweaks take effect live
-- These are read per-frame from Config so live tweaks via AdminConsole take effect
local MAGNET_SPEED    = 28  -- base studs/sec pull speed (not yet in Config)

-- Active ore registry for proximity collection
local activeOres = {}   -- { part, metal, conn, magnetized }

-- ── Weighted random metal picker ──────────────────────────────────────────────

local function pickMaterial()
    local total = 0
    for _, m in ipairs(Config.MATERIALS) do total += m.weight end
    local r, cum = math.random() * total, 0
    for _, m in ipairs(Config.MATERIALS) do
        cum += m.weight
        if r <= cum then return m end
    end
    return Config.MATERIALS[1]
end

-- ── Spawn one ore nugget on the flat world surface ───────────────────────────
-- Ores appear within the Compound + Badlands zones (radius 20-180 from origin).
-- They sit slightly above ground level and spin around the Y axis.

local function spawnOre()
    if #oreFolder:GetChildren() >= Config.ORE_MAX_COUNT then return end

    local metal = pickMaterial()

    -- Spawn from edge of safe zone outward, stay inside map ground (MAP_WIDTH/2 = 1200)
    local angle  = math.random() * math.pi * 2
    local radius = math.random(180, 1100)   -- studs from origin (within map bounds)
    local pos = Vector3.new(
        math.cos(angle) * radius,
        Config.MAP_GROUND_Y + 0.6,  -- hover a little above surface
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

    -- Register for proximity collection and rover pickup
    table.insert(activeOres, { part = ore, metal = metal, conn = conn })
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

-- ── Proximity collection loop ─────────────────────────────────────────────────

-- Collect an ore entry immediately (called from magnet coroutine or proximity loop)
local function collectOre(entry, plr, i)
    local ore      = entry.part
    local worldPos = ore.Position
    entry.conn:Disconnect()
    if entry.magnetConn then entry.magnetConn:Disconnect() end
    table.remove(activeOres, i)
    ore:Destroy()
    if _G.PlayerData then
        _G.PlayerData.addMaterial(plr, entry.metal.name, 1)
        _G.PlayerData.addXP(plr, 15)
    end
    collectFragmentEvent:FireClient(plr, entry.metal.name, 1, worldPos)
    materialEarned:Fire(plr, entry.metal.name, 1)
end

-- Proximity + magnet loop
task.spawn(function()
    while true do
        task.wait(0.15)
        for i = #activeOres, 1, -1 do
            local entry = activeOres[i]
            local ore   = entry.part
            if not (ore and ore.Parent) then
                table.remove(activeOres, i)
                continue
            end
            for _, plr in ipairs(Players:GetPlayers()) do
                local char = plr.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end
                local dist = (hrp.Position - ore.Position).Magnitude
                if dist <= Config.ORE_COLLECT_RADIUS then
                    collectOre(entry, plr, i)
                    break
                elseif dist <= Config.ORE_MAGNET_RADIUS and not entry.magnetized then
                    -- Stop the spin loop so it stops overriding the ore position
                    entry.conn:Disconnect()
                    entry.magnetized = true
                    local targetPlr  = plr
                    entry.magnetConn = RunService.Heartbeat:Connect(function(dt)
                        if not (ore and ore.Parent) then return end
                        local targetHrp = targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart")
                        if not targetHrp then return end
                        local toPlayer = targetHrp.Position - ore.Position
                        local d        = toPlayer.Magnitude
                        -- Accelerate as it closes in
                        local speed    = MAGNET_SPEED * (1 + (Config.ORE_MAGNET_RADIUS - d) / Config.ORE_MAGNET_RADIUS * 3)
                        local step     = math.min(d, speed * dt)
                        ore.CFrame     = CFrame.new(ore.Position + toPlayer.Unit * step)
                    end)
                end
            end
        end
    end
end)

-- ── Spawn loop ────────────────────────────────────────────────────────────────

local lastSpawn = 0
RunService.Heartbeat:Connect(function()
    local now = tick()
    if now - lastSpawn >= Config.ORE_SPAWN_INTERVAL then
        lastSpawn = now
        task.spawn(spawnOre)
    end
end)

print("[GameSetup] Ore system active")
