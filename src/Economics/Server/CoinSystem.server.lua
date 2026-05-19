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

local SPAWN_INTERVAL  = 6
local MAX_ORES        = 18
local COLLECT_RADIUS  = 8   -- studs — walk-over pickup distance

-- Active ore registry for proximity collection
local activeOres = {}   -- { part, metal }

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

local COMPOUND_SURFACE_Y = 3    -- top of Compound slab
local BADLANDS_SURFACE_Y = 1.5  -- top of Badlands slab

local function surfaceYForRadius(r)
    if r <= 810 then return COMPOUND_SURFACE_Y end
    return BADLANDS_SURFACE_Y
end

local function spawnOre()
    if #oreFolder:GetChildren() >= MAX_ORES then return end

    local metal = pickMaterial()

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

task.spawn(function()
    while true do
        task.wait(0.2)
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
                if hrp and (hrp.Position - ore.Position).Magnitude <= COLLECT_RADIUS then
                    local worldPos = ore.Position
                    entry.conn:Disconnect()
                    table.remove(activeOres, i)
                    ore:Destroy()
                    if _G.PlayerData then
                        _G.PlayerData.addMaterial(plr, entry.metal.name, 1)
                        _G.PlayerData.addXP(plr, 15)
                    end
                    collectFragmentEvent:FireClient(plr, entry.metal.name, 1, worldPos)
                    materialEarned:Fire(plr, entry.metal.name, 1)
                    break
                end
            end
        end
    end
end)

-- ── Spawn loop ────────────────────────────────────────────────────────────────

local lastSpawn = 0
RunService.Heartbeat:Connect(function()
    local now = tick()
    if now - lastSpawn >= SPAWN_INTERVAL then
        lastSpawn = now
        task.spawn(spawnOre)
    end
end)

print("[GameSetup] Ore system active")
