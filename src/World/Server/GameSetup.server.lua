-- Script → ServerScriptService/GameSetup
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config   = require(ReplicatedStorage:WaitForChild("Config"))
local WorldGen = require(ServerScriptService:WaitForChild("WorldGen"))

-- ── Moon world config ─────────────────────────────────────────────────────────

local MOON_CONFIG = {
    planet = {
        radius   = Config.PLANET_RADIUS,
        center   = Config.PLANET_CENTER,
        color    = Color3.fromRGB(192, 189, 202),   -- pale grey moon rock
        material = Enum.Material.SmoothPlastic,
    },
    base = {
        position  = Vector3.new(0, Config.PLANET_RADIUS, 0),  -- north pole
        width     = 140,
        depth     = 200,
        height    = 28,
        doorWidth = 16,
        colors = {
            hull       = Color3.fromRGB(36, 42, 62),
            panel      = Color3.fromRGB(50, 58, 85),
            neon       = Color3.fromRGB(60, 150, 255),
            foundation = Color3.fromRGB(160, 157, 170),
        },
    },
}

local R  = Config.PLANET_RADIUS
local PC = Config.PLANET_CENTER

-- ── Lighting ─────────────────────────────────────────────────────────────────

local function setupLighting()
    for _, obj in ipairs(Lighting:GetChildren()) do obj:Destroy() end

    Lighting.Ambient                  = Color3.fromRGB(45, 44, 62)    -- dark fill so shadows read
    Lighting.OutdoorAmbient           = Color3.fromRGB(55, 54, 75)
    Lighting.Brightness               = 4.5                           -- strong directional for crisp shadows
    Lighting.EnvironmentDiffuseScale  = 0.4
    Lighting.EnvironmentSpecularScale = 0.9
    Lighting.ClockTime                = 12                            -- sun at noon
    Lighting.GeographicLatitude       = 90                            -- sun directly overhead the north pole
    Lighting.FogStart = 2000
    Lighting.FogEnd   = 4000
    Lighting.FogColor = Color3.fromRGB(6, 5, 18)    -- deep space

    -- Space sky
    local sky = Instance.new("Sky")
    sky.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
    sky.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
    sky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
    sky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
    sky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
    sky.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
    sky.StarCount = 4000
    sky.Parent    = Lighting

    local bloom = Instance.new("BloomEffect")
    bloom.Intensity = 0.4; bloom.Size = 24; bloom.Threshold = 0.95
    bloom.Parent = Lighting

    local cc = Instance.new("ColorCorrectionEffect")
    cc.Saturation = 0.1; cc.TintColor = Color3.fromRGB(180, 184, 215)
    cc.Parent = Lighting
end

-- ── Spawn ─────────────────────────────────────────────────────────────────────

local function setupSpawn()
    for _, s in ipairs(workspace:GetDescendants()) do
        if s:IsA("SpawnLocation") then s:Destroy() end
    end
    local spawn = Instance.new("SpawnLocation")
    spawn.Size     = Vector3.new(6, 1, 6)
    spawn.Position = Vector3.new(0, R + 6, 0)   -- just above pole surface
    spawn.Anchored = true; spawn.Neutral = true
    spawn.AllowTeamChangeOnTouch = false
    spawn.Duration = 0; spawn.Transparency = 1
    spawn.Parent = workspace
end

-- ── Drone Repair Station ─────────────────────────────────────────────────────

local function createDroneStation()
    local sp    = Config.STATION_POS
    local DARK  = Color3.fromRGB(22,  30,  52)
    local MID   = Color3.fromRGB(36,  44,  72)
    local STEEL = Color3.fromRGB(52,  62,  95)
    local NB    = Color3.fromRGB(60, 150, 255)
    local NG    = Color3.fromRGB(0,  210, 120)
    local NR    = Color3.fromRGB(255, 50,  50)

    local function p(size, offset, color, mat, collide)
        local part = Instance.new("Part")
        part.Size       = size
        part.Position   = sp + offset
        part.Anchored   = true
        part.CanCollide = collide ~= false
        part.CastShadow = false
        part.Color      = color
        part.Material   = mat or Enum.Material.Metal
        part.Parent     = workspace
        return part
    end

    local function light(parent, color, brightness, range)
        local l = Instance.new("PointLight")
        l.Color = color; l.Brightness = brightness; l.Range = range
        l.Parent = parent
    end

    p(Vector3.new(30, 1.2, 30), Vector3.new(0, 0.6, 0), MID)
    p(Vector3.new(28, 0.12, 28), Vector3.new(0, 1.27, 0), NB, Enum.Material.Neon, false)

    p(Vector3.new(10, 9, 10), Vector3.new(0, 5.7, 0), DARK)
    p(Vector3.new(7.5, 4, 7.5), Vector3.new(0, 12.2, 0), MID)
    p(Vector3.new(10.3, 0.45, 10.3), Vector3.new(0, 6,  0), NB, Enum.Material.Neon, false)
    p(Vector3.new(10.3, 0.45, 10.3), Vector3.new(0, 10, 0), NG, Enum.Material.Neon, false)
    for _, xz in ipairs({ {5.1,0,0}, {-5.1,0,0}, {0,0,5.1}, {0,0,-5.1} }) do
        p(Vector3.new(0.2, 2.5, 2.5), Vector3.new(xz[1], 7, xz[3]),
            Color3.fromRGB(140, 210, 255), Enum.Material.Neon, false)
    end

    local dome = Instance.new("Part")
    dome.Shape    = Enum.PartType.Ball
    dome.Size     = Vector3.new(9, 9, 9)
    dome.Position = sp + Vector3.new(0, 19, 0)
    dome.Anchored = true; dome.CanCollide = false; dome.CastShadow = false
    dome.Color    = Color3.fromRGB(130, 200, 255)
    dome.Material = Enum.Material.Glass; dome.Transparency = 0.48
    dome.Parent   = workspace
    light(dome, NB, 3, 70)

    p(Vector3.new(2, 18, 2), Vector3.new(0, 32, 0), MID)
    p(Vector3.new(0.8, 0.7, 9), Vector3.new(0, 41, 4.5), STEEL)
    p(Vector3.new(9, 0.7, 0.8), Vector3.new(0, 41, 0), STEEL)
    p(Vector3.new(1.8, 1.8, 1.8), Vector3.new(0, 41.8, 0), NB, Enum.Material.Neon, false)
    p(Vector3.new(0.35, 6, 0.35), Vector3.new(0, 46, 0), NG, Enum.Material.Neon, false)
    local beacon = p(Vector3.new(0.8, 0.8, 0.8), Vector3.new(0, 50, 0), NR, Enum.Material.Neon, false)
    light(beacon, NR, 5, 100)
    task.spawn(function()
        while beacon.Parent do
            beacon.Transparency = 0; task.wait(0.6)
            beacon.Transparency = 0.9; task.wait(0.6)
        end
    end)

    for _, a in ipairs({
        { size = Vector3.new(3, 0.9, 12), offset = Vector3.new(0,  1.65, -21) },
        { size = Vector3.new(3, 0.9, 12), offset = Vector3.new(0,  1.65,  21) },
        { size = Vector3.new(12, 0.9, 3), offset = Vector3.new(-21, 1.65,  0) },
        { size = Vector3.new(12, 0.9, 3), offset = Vector3.new( 21, 1.65,  0) },
    }) do p(a.size, a.offset, MID) end
    p(Vector3.new(0.5, 0.12, 12), Vector3.new(0,  2.2, -21), NG, Enum.Material.Neon, false)
    p(Vector3.new(0.5, 0.12, 12), Vector3.new(0,  2.2,  21), NG, Enum.Material.Neon, false)
    p(Vector3.new(12, 0.12, 0.5), Vector3.new(-21, 2.2,  0), NG, Enum.Material.Neon, false)
    p(Vector3.new(12, 0.12, 0.5), Vector3.new( 21, 2.2,  0), NG, Enum.Material.Neon, false)

    for _, off in ipairs({
        Vector3.new(  0, 2, -24), Vector3.new(  0, 2,  24),
        Vector3.new(-24, 2,   0), Vector3.new( 24, 2,   0),
        Vector3.new(-10, 2, -10), Vector3.new( 10, 2,  10),
    }) do
        local pad = p(Vector3.new(6, 0.35, 6), off, NB, Enum.Material.Neon, false)
        light(pad, NB, 2, 22)
        p(Vector3.new(3, 0.12, 3), off + Vector3.new(0, 0.24, 0), NG, Enum.Material.Neon, false)
    end

    for i = 0, 7 do
        local a    = i * math.pi / 4
        local post = p(Vector3.new(0.8, 3.5, 0.8),
            Vector3.new(math.cos(a)*14, 2.95, math.sin(a)*14), STEEL)
        local cap  = p(Vector3.new(1.2, 0.5, 1.2),
            Vector3.new(math.cos(a)*14, 4.95, math.sin(a)*14),
            (i % 2 == 0) and NB or NG, Enum.Material.Neon, false)
        light(cap, (i % 2 == 0) and NB or NG, 1.5, 18)
    end

    print("[SkyBase] Drone station built")
end

-- ── Run ──────────────────────────────────────────────────────────────────────

workspace.Gravity = 60   -- standard-ish, works fine at the north pole

pcall(function() workspace.Terrain:Clear() end)
local bp = workspace:FindFirstChild("Baseplate")
if bp then bp:Destroy() end

print("[SkyBase] GameSetup starting...")

setupLighting()
print("[SkyBase] Lighting done")

WorldGen.buildPlanet(MOON_CONFIG)
print("[SkyBase] Planet built")

WorldGen.buildBase(MOON_CONFIG)
print("[SkyBase] Base built")

-- Beacon towers at compass points around the base
local NB_COLOR = Color3.fromRGB(60, 150, 255)
WorldGen.buildBeacon(MOON_CONFIG,  160, 0,    NB_COLOR)
WorldGen.buildBeacon(MOON_CONFIG, -160, 0,    NB_COLOR)
WorldGen.buildBeacon(MOON_CONFIG,  0,   160,  NB_COLOR)
WorldGen.buildBeacon(MOON_CONFIG,  0,  -160,  NB_COLOR)
print("[SkyBase] Beacons built")

setupSpawn()
createDroneStation()

print("[SkyBase] Done")
