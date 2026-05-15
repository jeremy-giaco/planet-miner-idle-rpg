-- World/Server/SurfaceDecor.server.lua
-- Randomly scatters surface features across the planet sphere:
--   rocky mounds, lava pools, oil slicks, alien plant life
--
-- All features are anchored to the sphere surface normal.
-- Fixed seed = consistent layout every run.

if not game:GetService("RunService"):IsServer() then return end
if _G._SurfaceDecorActive then return end
_G._SurfaceDecorActive = true

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage:WaitForChild("Config"))

local PC = Config.PLANET_CENTER
local R  = Config.PLANET_RADIUS

local rng = Random.new(98765)

local EXCLUSION_ANGLE = math.rad(18)   -- keep north-pole base area clear

local folder = Instance.new("Folder")
folder.Name   = "SurfaceDecor"
folder.Parent = workspace

-- ── Core helpers ──────────────────────────────────────────────────────────────

local function rn(a, b) return a + rng:NextNumber() * (b - a) end
local function ri(a, b) return math.floor(rn(a, b + 1)) end

local function makePart(size, cf, color, mat, trans, collide)
    local p = Instance.new("Part")
    p.Size         = size
    p.CFrame       = cf
    p.Anchored     = true
    p.CanCollide   = collide ~= false
    p.CastShadow   = false
    p.Color        = color
    p.Material     = mat or Enum.Material.SmoothPlastic
    p.Transparency = trans or 0
    p.Parent       = folder
    return p
end

local function addLight(parent, color, brightness, range)
    local l = Instance.new("PointLight")
    l.Color = color; l.Brightness = brightness; l.Range = range
    l.Parent = parent
end

local function addParticles(parent, color1, color2, rate, speed, lifetime, size, spread)
    local e = Instance.new("ParticleEmitter")
    e.Color        = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color1),
        ColorSequenceKeypoint.new(1, color2),
    })
    e.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.6, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    e.Size         = NumberSequence.new({
        NumberSequenceKeypoint.new(0, size),
        NumberSequenceKeypoint.new(1, size * 2.5),
    })
    e.Speed        = NumberRange.new(speed * 0.5, speed)
    e.Rate         = rate
    e.Lifetime     = NumberRange.new(lifetime * 0.6, lifetime)
    e.SpreadAngle  = Vector2.new(spread, spread)
    e.LightEmission = 0.2
    e.RotSpeed     = NumberRange.new(-20, 20)
    e.Rotation     = NumberRange.new(0, 360)
    e.Parent       = parent
    return e
end

-- Build a surface-aligned CFrame. localY = surface normal.
-- heightAbove > 0 lifts off surface; < 0 recesses into sphere.
local function surfaceCF(phi, theta, heightAbove, extraYaw)
    local nx = math.sin(phi) * math.cos(theta)
    local ny = math.cos(phi)
    local nz = math.sin(phi) * math.sin(theta)
    local normal = Vector3.new(nx, ny, nz)
    local pos    = PC + normal * (R + (heightAbove or 0))
    local up     = normal
    local ref    = math.abs(up.Y) < 0.9 and Vector3.new(0,1,0) or Vector3.new(1,0,0)
    local right  = up:Cross(ref).Unit
    local fwd    = right:Cross(up).Unit
    return CFrame.fromMatrix(pos, right, up, -fwd) * CFrame.Angles(0, extraYaw or 0, 0)
end

-- Flat disc on sphere surface. Roblox Cylinder extends along X axis;
-- rotating 90° around local Z makes X = surface normal = flat disc.
local function discCF(phi, theta, heightAbove, yaw)
    return surfaceCF(phi, theta, heightAbove, yaw) * CFrame.Angles(0, 0, math.rad(90))
end

local function randomPos()
    local phi   = EXCLUSION_ANGLE + rng:NextNumber() * (math.pi * 0.72)
    local theta = rng:NextNumber() * math.pi * 2
    return phi, theta
end

-- ── Rocky mounds ─────────────────────────────────────────────────────────────
-- Low flat piles of basalt slabs, partially buried.

local ROCK_COLS = {
    Color3.fromRGB(52,  45,  40),
    Color3.fromRGB(65,  57,  52),
    Color3.fromRGB(44,  38,  34),
    Color3.fromRGB(78,  68,  60),
    Color3.fromRGB(35,  30,  28),
}

local function makeMound(phi, theta)
    local base  = surfaceCF(phi, theta, -3, rn(0, math.pi * 2))
    local count = ri(4, 7)
    for _ = 1, count do
        local w  = rn(6, 20)
        local h  = rn(2, 6)      -- flat slabs, not tall boulders
        local d  = rn(6, 20)
        local ox = rn(-10, 10)
        local oz = rn(-10, 10)
        local oy = rn(-2, h * 0.3)   -- mostly below "ground" level
        local cf = base
            * CFrame.new(ox, oy, oz)
            * CFrame.Angles(rn(-0.25, 0.25), rn(0, math.pi), rn(-0.2, 0.2))
        local col = ROCK_COLS[ri(1, #ROCK_COLS)]
        makePart(Vector3.new(w, h, d), cf, col, Enum.Material.Basalt)
    end
end

-- ── Lava pools ────────────────────────────────────────────────────────────────
-- Glowing pools recessed into the surface with cracked rock rim and steam.

local function makeLavaPool(phi, theta)
    local yaw  = rn(0, math.pi * 2)
    local size = rn(16, 36)

    -- Main lava surface — recessed 1 stud into sphere
    local dc  = discCF(phi, theta, -1, yaw)
    local hot = Color3.fromRGB(255, 120, 10)
    local lava = makePart(
        Vector3.new(1.2, size, size), dc,
        Color3.fromRGB(210, 55, 5), Enum.Material.Neon
    )
    lava.Shape = Enum.PartType.Cylinder
    addLight(lava, hot, 2.5, size * 4)

    -- Slightly brighter inner pool
    local inner = makePart(
        Vector3.new(1.3, size * 0.5, size * 0.5),
        discCF(phi, theta, -0.8, yaw),
        Color3.fromRGB(255, 180, 30), Enum.Material.Neon
    )
    inner.Shape      = Enum.PartType.Cylinder
    inner.CanCollide = false

    -- Dark cracked rim
    local rimBase = surfaceCF(phi, theta, -0.5, yaw)
    for i = 1, 6 do
        local ang  = (i / 6) * math.pi * 2 + rn(-0.3, 0.3)
        local dist = size * 0.52 + rn(1, 5)
        local rw   = rn(3, 8)
        local rh   = rn(1, 3)
        local cf   = rimBase
            * CFrame.new(math.cos(ang) * dist, rh * 0.2, math.sin(ang) * dist)
            * CFrame.Angles(rn(-0.2, 0.2), ang, rn(-0.15, 0.15))
        makePart(Vector3.new(rw, rh, rw * 0.6), cf,
            Color3.fromRGB(30, 24, 22), Enum.Material.Basalt)
    end

    -- Steam rising from pool surface
    local att = Instance.new("Attachment")
    att.WorldPosition = lava.Position + (lava.Position - PC).Unit * 2
    att.Parent        = lava
    addParticles(att,
        Color3.fromRGB(180, 160, 140),
        Color3.fromRGB(80,  70,  65),
        10, 5, 3.5, 1.2, 18
    )

    -- Ember sparks
    local sparks = Instance.new("ParticleEmitter")
    sparks.Color         = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 80)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180,  30,  5)),
    })
    sparks.Transparency  = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)
    })
    sparks.Size          = NumberSequence.new(0.25)
    sparks.Speed         = NumberRange.new(4, 12)
    sparks.Rate          = 6
    sparks.Lifetime      = NumberRange.new(0.4, 1.2)
    sparks.SpreadAngle   = Vector2.new(70, 70)
    sparks.LightEmission = 1
    sparks.Parent        = att
end

-- ── Oil slicks ────────────────────────────────────────────────────────────────
-- Flat dark pools with a faint iridescent edge and lazy gas bubbles.

local function makeOilPool(phi, theta)
    local yaw  = rn(0, math.pi * 2)
    local size = rn(20, 45)

    -- Main slick — dead flat, flush with surface
    local dc   = discCF(phi, theta, 0, yaw)
    local pool = makePart(
        Vector3.new(1, size, size), dc,
        Color3.fromRGB(8, 7, 10), Enum.Material.SmoothPlastic
    )
    pool.Shape = Enum.PartType.Cylinder

    -- Iridescent edge ring (slightly larger, thin, transparent)
    local edge = makePart(
        Vector3.new(0.8, size * 1.12, size * 1.12),
        discCF(phi, theta, 0.1, yaw),
        Color3.fromRGB(30, 55, 70), Enum.Material.Neon, 0.75
    )
    edge.Shape      = Enum.PartType.Cylinder
    edge.CanCollide = false

    -- Slow bubbling gas emitter
    local att = Instance.new("Attachment")
    att.WorldPosition = pool.Position + (pool.Position - PC).Unit * 1
    att.Parent        = pool
    addParticles(att,
        Color3.fromRGB(25, 40, 50),
        Color3.fromRGB(15, 25, 35),
        2, 1.5, 4, 0.35, 10
    )
end

-- ── Alien plants ─────────────────────────────────────────────────────────────
-- Three organic varieties: stalked bulb, spiky grass tuft, wide fan fern.

local PLANT_COLS = {
    { stem = Color3.fromRGB(20, 60, 35),  tip = Color3.fromRGB(40, 200, 90)  },  -- bioluminescent green
    { stem = Color3.fromRGB(30, 30, 60),  tip = Color3.fromRGB(80, 120, 255) },  -- deep blue
    { stem = Color3.fromRGB(50, 20, 55),  tip = Color3.fromRGB(200, 80, 255) },  -- violet spore
    { stem = Color3.fromRGB(55, 35, 10),  tip = Color3.fromRGB(255, 180, 30) },  -- amber glow
    { stem = Color3.fromRGB(10, 50, 50),  tip = Color3.fromRGB(0,  220, 180) },  -- teal algae
}

local function makeStalkedBulb(base, col)
    -- Tapered stem made of stacked boxes (no rotation issues)
    local stemH = rn(5, 14)
    local segs  = ri(3, 5)
    for i = 1, segs do
        local t   = (i - 0.5) / segs
        local segH = stemH / segs
        local w   = rn(0.5, 1.0) * (1 - t * 0.5)
        local cf  = base * CFrame.new(0, t * stemH, 0)
        makePart(Vector3.new(w, segH + 0.1, w), cf, col.stem, Enum.Material.SmoothPlastic)
    end
    -- Bulb at top
    local bsize = rn(1.8, 3.5)
    local bulbCF = base * CFrame.new(0, stemH + bsize * 0.4, 0)
    local bulb  = makePart(Vector3.new(bsize, bsize * 1.2, bsize), bulbCF,
        col.tip, Enum.Material.Neon)
    bulb.Shape  = Enum.PartType.Ball
    addLight(bulb, col.tip, 1.2, bsize * 8)
    -- Small drooping leaf-tabs off the stem midpoint
    local leafH = stemH * 0.5
    for i = 1, ri(2, 4) do
        local ang  = (i / 4) * math.pi * 2
        local lw   = rn(1.5, 3)
        local lh   = rn(0.3, 0.7)
        local cf   = base
            * CFrame.new(0, leafH, 0)
            * CFrame.Angles(0, ang, 0)
            * CFrame.new(lw * 0.5, 0, 0)
            * CFrame.Angles(0, 0, math.rad(rn(-30, -10)))
        makePart(Vector3.new(lw, lh, lw * 0.4), cf, col.stem, Enum.Material.Grass)
    end
end

local function makeGrassTuft(base, col)
    -- Cluster of thin spikes at varied heights and lean angles
    local count = ri(6, 12)
    for _ = 1, count do
        local h   = rn(3, 10)
        local w   = rn(0.3, 0.8)
        local ox  = rn(-4, 4)
        local oz  = rn(-4, 4)
        local lean = rn(-0.35, 0.35)
        local cf  = base
            * CFrame.new(ox, h * 0.5, oz)
            * CFrame.Angles(lean, rn(0, math.pi * 2), rn(-0.1, 0.1))
        -- Tip is brighter
        local tipFrac = 0.25
        makePart(Vector3.new(w, h * (1-tipFrac), w), cf, col.stem, Enum.Material.SmoothPlastic)
        local tipCF = base
            * CFrame.new(ox, h * (1 - tipFrac * 0.5), oz)
            * CFrame.Angles(lean, 0, 0)
        makePart(Vector3.new(w * 0.7, h * tipFrac, w * 0.7), tipCF,
            col.tip, Enum.Material.Neon)
    end
end

local function makeFanFern(base, col)
    -- Several wide flat wedge "fronds" arcing outward from a central stem
    local stemH = rn(3, 7)
    makePart(Vector3.new(0.8, stemH, 0.8),
        base * CFrame.new(0, stemH * 0.5, 0), col.stem, Enum.Material.SmoothPlastic)

    local fronds = ri(4, 7)
    for i = 1, fronds do
        local ang   = (i / fronds) * math.pi * 2 + rn(-0.2, 0.2)
        local tilt  = math.rad(rn(30, 65))   -- droop outward
        local flen  = rn(4, 9)
        local fwide = rn(1.5, 3.5)
        local cf    = base
            * CFrame.new(0, stemH, 0)
            * CFrame.Angles(0, ang, 0)
            * CFrame.Angles(tilt, 0, 0)
            * CFrame.new(0, flen * 0.5, 0)
        makePart(Vector3.new(fwide, flen, fwide * 0.3), cf, col.tip, Enum.Material.Grass)
    end
    addLight(folder, col.tip, 0.6, stemH * 6)
end

local function makePlant(phi, theta)
    local base = surfaceCF(phi, theta, 0, rn(0, math.pi * 2))
    local col  = PLANT_COLS[ri(1, #PLANT_COLS)]
    local kind = ri(1, 3)
    if     kind == 1 then makeStalkedBulb(base, col)
    elseif kind == 2 then makeGrassTuft(base, col)
    else                   makeFanFern(base, col)
    end
end

-- ── Scatter ───────────────────────────────────────────────────────────────────

local COUNTS = { mound=100, lava=50, oil=35, plant=85 }

task.spawn(function()
    local n = 0
    for _ = 1, COUNTS.mound  do makeMound(randomPos())    n+=1 if n%20==0 then task.wait() end end
    for _ = 1, COUNTS.lava   do makeLavaPool(randomPos()) n+=1 if n%10==0 then task.wait() end end
    for _ = 1, COUNTS.oil    do makeOilPool(randomPos())  n+=1 if n%10==0 then task.wait() end end
    for _ = 1, COUNTS.plant  do makePlant(randomPos())    n+=1 if n%15==0 then task.wait() end end
    print(string.format("[SurfaceDecor] Placed %d features", COUNTS.mound+COUNTS.lava+COUNTS.oil+COUNTS.plant))
end)
