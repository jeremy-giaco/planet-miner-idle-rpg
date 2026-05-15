-- World/Server/SurfaceDecor.server.lua
-- Randomly scatters surface features across the planet sphere:
--   rocky mounds, lava pits (with steam), oil pools, alien plants
--
-- Avoids the base exclusion zone at the north pole.
-- Uses a fixed seed for consistent layout every run.

if not game:GetService("RunService"):IsServer() then return end
if _G._SurfaceDecorActive then return end
_G._SurfaceDecorActive = true

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage:WaitForChild("Config"))

local PC = Config.PLANET_CENTER
local R  = Config.PLANET_RADIUS

local rng = Random.new(98765)

-- Don't place features within this arc-distance of the north pole (base area)
local EXCLUSION_ANGLE = math.rad(18)  -- ~18 degrees = ~320 studs from pole

local folder = Instance.new("Folder")
folder.Name   = "SurfaceDecor"
folder.Parent = workspace

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function p(size, cf, color, mat, trans, canCollide)
    local part = Instance.new("Part")
    part.Size         = size
    part.CFrame       = cf
    part.Anchored     = true
    part.CanCollide   = canCollide ~= false
    part.CastShadow   = false
    part.Color        = color
    part.Material     = mat or Enum.Material.SmoothPlastic
    part.Transparency = trans or 0
    part.Parent       = folder
    return part
end

local function light(parent, color, brightness, range)
    local l = Instance.new("PointLight")
    l.Color = color; l.Brightness = brightness; l.Range = range
    l.Parent = parent
end

local function smoke(parent, color, density, riseVel, size)
    local e = Instance.new("ParticleEmitter")
    e.Color         = ColorSequence.new(color)
    e.Transparency  = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    e.Size          = NumberSequence.new({
        NumberSequenceKeypoint.new(0, size or 1),
        NumberSequenceKeypoint.new(1, (size or 1) * 3),
    })
    e.Speed         = NumberRange.new(riseVel or 2, (riseVel or 2) * 2)
    e.Rate          = density or 8
    e.Lifetime      = NumberRange.new(2, 4)
    e.SpreadAngle   = Vector2.new(20, 20)
    e.LightEmission = 0.3
    e.RotSpeed      = NumberRange.new(-30, 30)
    e.Rotation      = NumberRange.new(0, 360)
    e.Parent        = parent
    return e
end

-- Build a surface CFrame at spherical coords (phi, theta), oriented so
-- local Y = surface normal and rotated randomly around it.
local function surfaceCF(phi, theta, heightAbove, yaw)
    local nx = math.sin(phi) * math.cos(theta)
    local ny = math.cos(phi)
    local nz = math.sin(phi) * math.sin(theta)
    local normal = Vector3.new(nx, ny, nz)
    local pos    = PC + normal * (R + (heightAbove or 0))
    local up     = normal
    local ref    = math.abs(up.Y) < 0.9 and Vector3.new(0,1,0) or Vector3.new(1,0,0)
    local right  = up:Cross(ref).Unit
    local fwd    = right:Cross(up).Unit
    local cf     = CFrame.fromMatrix(pos, right, up, -fwd)
    return cf * CFrame.Angles(0, yaw or 0, 0)
end

-- Pick random spherical position outside the exclusion zone
local function randomSurfacePos()
    -- phi: avoid north pole cap (exclusion) and south pole cap (too far, unseen)
    local phi   = EXCLUSION_ANGLE + rng:NextNumber() * (math.pi * 0.72)
    local theta = rng:NextNumber() * math.pi * 2
    return phi, theta
end

-- ── Feature builders ──────────────────────────────────────────────────────────

local function makeMound(phi, theta)
    local yaw = rng:NextNumber() * math.pi * 2
    local base = surfaceCF(phi, theta, -2, yaw)

    -- 3-5 overlapping rocky lumps
    local count = 3 + math.floor(rng:NextNumber() * 3)
    local cols = {
        Color3.fromRGB(55, 48, 44),
        Color3.fromRGB(68, 60, 55),
        Color3.fromRGB(44, 38, 35),
        Color3.fromRGB(80, 72, 65),
    }
    for i = 1, count do
        local sz   = 8 + rng:NextNumber() * 18
        local offX = (rng:NextNumber() - 0.5) * 14
        local offZ = (rng:NextNumber() - 0.5) * 14
        local offY = rng:NextNumber() * 4
        local col  = cols[math.random(#cols)]
        local cf   = base * CFrame.new(offX, offY, offZ)
        local part = p(
            Vector3.new(sz * (0.7 + rng:NextNumber() * 0.6),
                        sz * (0.5 + rng:NextNumber() * 0.5),
                        sz * (0.7 + rng:NextNumber() * 0.6)),
            cf, col, Enum.Material.Basalt
        )
        part.Shape = Enum.PartType.Ball
    end
end

local function makeLavaPit(phi, theta)
    local yaw   = rng:NextNumber() * math.pi * 2
    local base  = surfaceCF(phi, theta, 0, yaw)
    local size  = 14 + rng:NextNumber() * 20
    local glow  = Color3.fromRGB(255, 80, 10)
    local lava2 = Color3.fromRGB(220, 40, 5)

    -- Main lava disc
    local disc = p(
        Vector3.new(2, size, size),
        base * CFrame.Angles(0, 0, math.rad(90)),
        Color3.fromRGB(200, 50, 5), Enum.Material.Neon
    )
    disc.Shape = Enum.PartType.Cylinder
    light(disc, glow, 2, size * 3)

    -- Bright inner pool
    local inner = p(
        Vector3.new(2.1, size * 0.45, size * 0.45),
        base * CFrame.new(0.1, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
        Color3.fromRGB(255, 160, 20), Enum.Material.Neon
    )
    inner.Shape = Enum.PartType.Cylinder

    -- Cracked rim rocks
    for i = 1, 5 do
        local ang   = (i / 5) * math.pi * 2 + rng:NextNumber() * 0.8
        local dist  = size * 0.5 + rng:NextNumber() * 4
        local rsize = 3 + rng:NextNumber() * 5
        local cf    = base * CFrame.new(math.cos(ang) * dist, 0.5, math.sin(ang) * dist)
        p(Vector3.new(rsize, rsize * 0.4, rsize * 0.7), cf,
            Color3.fromRGB(35, 28, 25), Enum.Material.Basalt)
    end

    -- Steam / smoke emitter attachment
    local att = Instance.new("Attachment")
    att.WorldPosition = disc.Position + (disc.Position - PC).Unit * 3
    att.Parent        = disc

    local s = smoke(att, Color3.fromRGB(160, 140, 120), 12, 4, 1.5)
    s.EmissionDirection = Enum.NormalId.Top

    -- Occasional ember sparks
    local sparks = Instance.new("ParticleEmitter")
    sparks.Color       = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 50)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 40,  5)),
    })
    sparks.Size        = NumberSequence.new(0.3)
    sparks.Speed       = NumberRange.new(6, 16)
    sparks.Rate        = 4
    sparks.Lifetime    = NumberRange.new(0.5, 1.5)
    sparks.SpreadAngle = Vector2.new(60, 60)
    sparks.LightEmission = 1
    sparks.Parent      = att
end

local function makeOilPool(phi, theta)
    local yaw  = rng:NextNumber() * math.pi * 2
    local base = surfaceCF(phi, theta, 0.2, yaw)
    local size = 18 + rng:NextNumber() * 28

    -- Main pool — dark oily surface
    local pool = p(
        Vector3.new(1.5, size, size),
        base * CFrame.Angles(0, 0, math.rad(90)),
        Color3.fromRGB(12, 10, 14), Enum.Material.SmoothPlastic
    )
    pool.Shape = Enum.PartType.Cylinder

    -- Iridescent sheen layer (slightly transparent teal/purple)
    local sheen = p(
        Vector3.new(1.6, size * 0.8, size * 0.8),
        base * CFrame.new(0.1, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
        Color3.fromRGB(30, 60, 80), Enum.Material.Neon, 0.7
    )
    sheen.Shape = Enum.PartType.Cylinder
    sheen.CanCollide = false

    -- Lazy bubble emitter
    local att = Instance.new("Attachment")
    att.WorldPosition = pool.Position + (pool.Position - PC).Unit * 1.5
    att.Parent        = pool

    local bubbles = Instance.new("ParticleEmitter")
    bubbles.Color       = ColorSequence.new(Color3.fromRGB(40, 80, 100))
    bubbles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 1),
    })
    bubbles.Size        = NumberSequence.new(0.4)
    bubbles.Speed       = NumberRange.new(1, 3)
    bubbles.Rate        = 3
    bubbles.Lifetime    = NumberRange.new(1, 3)
    bubbles.SpreadAngle = Vector2.new(15, 15)
    bubbles.Parent      = att
end

local PLANT_GLOWS = {
    Color3.fromRGB(40, 220, 120),   -- bioluminescent green
    Color3.fromRGB(80, 140, 255),   -- electric blue
    Color3.fromRGB(180, 60, 255),   -- alien violet
    Color3.fromRGB(255, 200, 40),   -- amber crystal
    Color3.fromRGB(0, 255, 200),    -- cyan spore
}

local function makePlant(phi, theta)
    local yaw  = rng:NextNumber() * math.pi * 2
    local base = surfaceCF(phi, theta, 0, yaw)
    local col  = PLANT_GLOWS[math.random(#PLANT_GLOWS)]
    local kind = math.random(3)

    if kind == 1 then
        -- Crystal spire: tapered stack of cylinders
        local height = 6 + rng:NextNumber() * 10
        local w      = 1.2 + rng:NextNumber() * 1.5
        local segs   = 3 + math.floor(rng:NextNumber() * 3)
        for i = 1, segs do
            local t   = (i - 1) / segs
            local segH = height / segs
            local segW = w * (1 - t * 0.7)
            local cf   = base * CFrame.new(0, height * t + segH * 0.5, 0)
            local seg  = p(Vector3.new(segW, segH, segW), cf, col, Enum.Material.Neon, 0.1)
            seg.Shape  = Enum.PartType.Cylinder
            seg.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
        end
        -- Tip glow
        light(folder, col, 1.5, height * 4)

    elseif kind == 2 then
        -- Mushroom cap: thick stem + dome cap
        local stemH = 4 + rng:NextNumber() * 6
        local capR  = 3 + rng:NextNumber() * 5
        local stemCF = base * CFrame.new(0, stemH * 0.5, 0)
        p(Vector3.new(1.2, stemH, 1.2), stemCF,
            Color3.fromRGB(30, 30, 40), Enum.Material.SmoothPlastic)

        local capCF = base * CFrame.new(0, stemH, 0)
        local cap   = p(Vector3.new(capR, capR * 0.55, capR), capCF,
            col, Enum.Material.Neon, 0.05)
        cap.Shape   = Enum.PartType.Ball
        light(cap, col, 1.2, capR * 5)

    else
        -- Coral fan: several thin wedges fanning out from base
        local count = 3 + math.floor(rng:NextNumber() * 4)
        local h     = 5 + rng:NextNumber() * 8
        for i = 1, count do
            local ang = ((i - 1) / count) * math.pi * 2
            local tilt = math.rad(20 + rng:NextNumber() * 40)
            local cf   = base
                * CFrame.Angles(0, ang, 0)
                * CFrame.new(0, h * 0.5, 0)
                * CFrame.Angles(tilt, 0, 0)
            p(Vector3.new(0.5, h, h * 0.4), cf, col, Enum.Material.Neon, 0.1)
        end
        light(folder, col, 1, h * 3)
    end
end

-- ── Scatter features ──────────────────────────────────────────────────────────

local COUNTS = {
    mound   = 120,
    lava    = 55,
    oil     = 40,
    plant   = 90,
}

local function scatter()
    local n = 0

    for _ = 1, COUNTS.mound do
        makeMound(randomSurfacePos())
        n += 1
        if n % 20 == 0 then task.wait() end
    end

    for _ = 1, COUNTS.lava do
        makeLavaPit(randomSurfacePos())
        n += 1
        if n % 10 == 0 then task.wait() end
    end

    for _ = 1, COUNTS.oil do
        makeOilPool(randomSurfacePos())
        n += 1
        if n % 10 == 0 then task.wait() end
    end

    for _ = 1, COUNTS.plant do
        makePlant(randomSurfacePos())
        n += 1
        if n % 15 == 0 then task.wait() end
    end

    local total = COUNTS.mound + COUNTS.lava + COUNTS.oil + COUNTS.plant
    print(string.format("[SurfaceDecor] Placed %d features on planet surface", total))
end

task.spawn(scatter)
