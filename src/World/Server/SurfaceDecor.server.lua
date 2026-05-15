-- World/Server/SurfaceDecor.server.lua
-- Volcanic alien planet surface features, inspired by:
--   jagged rocky spire clusters, glowing lava rivers, dark basalt ridges,
--   bioluminescent alien flora peeking through the rock.
--
-- Fixed seed = consistent layout every run.

if not game:GetService("RunService"):IsServer() then return end
if _G._SurfaceDecorActive then return end
_G._SurfaceDecorActive = true

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage:WaitForChild("Config"))

local PC = Config.PLANET_CENTER
local R  = Config.PLANET_RADIUS

local rng = Random.new(98765)

local EXCLUSION_ANGLE = math.rad(18)   -- keep north-pole base clear

local folder = Instance.new("Folder")
folder.Name   = "SurfaceDecor"
folder.Parent = workspace

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function rn(a, b) return a + rng:NextNumber() * (b - a) end
local function ri(a, b) return math.floor(rn(a, b + 1)) end

local function part(size, cf, color, mat, trans, collide)
    local p = Instance.new("Part")
    p.Size         = size
    p.CFrame       = cf
    p.Anchored     = true
    p.CanCollide   = collide ~= false
    p.CastShadow   = false
    p.Color        = color
    p.Material     = mat or Enum.Material.Basalt
    p.Transparency = trans or 0
    p.Parent       = folder
    return p
end

local function glow(parent, color, brightness, range)
    local l = Instance.new("PointLight")
    l.Color = color; l.Brightness = brightness; l.Range = range
    l.Parent = parent
end

-- Surface-aligned CFrame: local Y = surface normal
local function surfCF(phi, theta, heightAbove, yaw)
    local nx = math.sin(phi) * math.cos(theta)
    local ny = math.cos(phi)
    local nz = math.sin(phi) * math.sin(theta)
    local n   = Vector3.new(nx, ny, nz)
    local pos = PC + n * (R + (heightAbove or 0))
    local ref = math.abs(n.Y) < 0.9 and Vector3.new(0,1,0) or Vector3.new(1,0,0)
    local r   = n:Cross(ref).Unit
    local f   = r:Cross(n).Unit
    return CFrame.fromMatrix(pos, r, n, -f) * CFrame.Angles(0, yaw or 0, 0)
end

-- Flat disc CFrame: cylinder X-axis = surface normal
local function discCF(phi, theta, h, yaw)
    return surfCF(phi, theta, h, yaw) * CFrame.Angles(0, 0, math.rad(90))
end

local function rpos()
    return EXCLUSION_ANGLE + rng:NextNumber() * (math.pi * 0.72),
           rng:NextNumber() * math.pi * 2
end

-- ── Jagged Spire Clusters ────────────────────────────────────────────────────
-- Groups of tall tapered rock columns, each leaning slightly differently.
-- This is the hero feature of the volcanic landscape.

local SPIRE_DARK = {
    Color3.fromRGB(30, 18, 12),
    Color3.fromRGB(42, 25, 16),
    Color3.fromRGB(22, 14,  9),
    Color3.fromRGB(55, 32, 20),
}
local SPIRE_MID = {
    Color3.fromRGB(70, 40, 25),
    Color3.fromRGB(85, 50, 30),
    Color3.fromRGB(60, 35, 20),
}

local function makeSpireCluster(phi, theta)
    local base  = surfCF(phi, theta, 0, rn(0, math.pi * 2))
    local count = ri(3, 7)   -- spires per cluster

    for _ = 1, count do
        local height = rn(12, 45)
        local baseW  = rn(3, 8)
        local ox     = rn(-12, 12)
        local oz     = rn(-12, 12)
        local lean   = rn(-0.18, 0.18)   -- slight random lean
        local leanDir = rn(0, math.pi * 2)
        local segs   = ri(4, 7)

        for s = 1, segs do
            local t0   = (s - 1) / segs
            local t1   = s       / segs
            local tmid = (t0 + t1) * 0.5
            local segH = height / segs
            -- Taper: wide at base, pointed at top
            local w    = baseW * (1 - tmid * 0.88)
            local col  = tmid < 0.5 and SPIRE_DARK[ri(1,#SPIRE_DARK)]
                                     or SPIRE_MID[ri(1,#SPIRE_MID)]
            -- Slight zigzag per segment for jagged look
            local jx   = rn(-0.8, 0.8)
            local jz   = rn(-0.8, 0.8)
            local cf   = base
                * CFrame.new(ox + jx, height * t0 + segH * 0.5, oz + jz)
                * CFrame.Angles(lean * math.cos(leanDir), rn(-0.08, 0.08),
                                lean * math.sin(leanDir))
            -- Alternate between Wedge and Block for irregular silhouette
            local p = part(Vector3.new(w, segH + 0.2, w * rn(0.7, 1.3)), cf, col)
            if ri(1,3) == 1 then p.Shape = Enum.PartType.Wedge end
        end

        -- Lava seep at base of some spires (1 in 3 chance)
        if ri(1,3) == 1 then
            local seepCF = base * CFrame.new(ox, 0.3, oz)
            local seep   = part(
                Vector3.new(baseW * rn(1.2, 2), baseW * rn(0.4, 0.8), baseW * rn(1.2, 2)),
                seepCF, Color3.fromRGB(200, 55, 5), Enum.Material.Neon, 0, false
            )
            glow(seep, Color3.fromRGB(255, 100, 15), 1.2, baseW * 12)
        end
    end

    -- Scattered rubble around the base of the cluster
    for _ = 1, ri(3, 6) do
        local rx = rn(-18, 18); local rz = rn(-18, 18)
        local rw = rn(2, 6); local rh = rn(1, 3)
        local rcf = base * CFrame.new(rx, rh * 0.3, rz)
                         * CFrame.Angles(rn(-0.3,0.3), rn(0,math.pi), rn(-0.2,0.2))
        part(Vector3.new(rw, rh, rw * rn(0.5,1.5)), rcf, SPIRE_DARK[ri(1,#SPIRE_DARK)])
    end
end

-- ── Lava Rivers ──────────────────────────────────────────────────────────────
-- Winding strips of glowing lava cutting across the surface.
-- Built as a chain of overlapping flat segments that curve along the surface.

local function makeLavaRiver(phi, theta)
    local length  = ri(8, 18)      -- number of segments
    local width   = rn(4, 10)
    local hotCol  = Color3.fromRGB(255, 140, 15)
    local coreCol = Color3.fromRGB(255, 220, 60)

    -- Walk along a random great-circle direction on the surface
    local base  = surfCF(phi, theta, -0.5)
    local dir   = rn(0, math.pi * 2)   -- initial walk direction
    local curPhi, curTheta = phi, theta

    for i = 1, length do
        -- Step ~8 studs along the surface in direction `dir`, with slight curve
        dir = dir + rn(-0.25, 0.25)
        local stepAngle = 8 / R   -- arc corresponding to ~8 studs on surface
        curPhi   = math.clamp(curPhi   + stepAngle * math.cos(dir), 0.01, math.pi - 0.01)
        curTheta = curTheta + stepAngle * math.sin(dir)

        local segW = width * rn(0.85, 1.15)
        local dc   = discCF(curPhi, curTheta, -0.4 + rn(-0.3, 0.3), 0)

        -- Outer lava (darker)
        local outer = part(Vector3.new(1, segW * 1.4, segW * 1.4), dc,
            Color3.fromRGB(180, 45, 5), Enum.Material.Neon)
        outer.Shape      = Enum.PartType.Cylinder
        outer.CanCollide = false

        -- Bright inner channel
        local inner = part(Vector3.new(1.1, segW * 0.55, segW * 0.55), dc,
            coreCol, Enum.Material.Neon, 0.1)
        inner.Shape      = Enum.PartType.Cylinder
        inner.CanCollide = false

        -- One light per few segments (performance)
        if i % 3 == 1 then
            glow(outer, hotCol, 1.8, segW * 6)
        end

        -- Steam/heat shimmer emitter on some segments
        if i % 4 == 1 then
            local att = Instance.new("Attachment")
            att.WorldPosition = outer.Position + (outer.Position - PC).Unit * 2
            att.Parent        = outer
            local e = Instance.new("ParticleEmitter")
            e.Color       = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 160, 100)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(60,  40,  25)),
            })
            e.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.3),
                NumberSequenceKeypoint.new(1, 1),
            })
            e.Size        = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.8),
                NumberSequenceKeypoint.new(1, 3),
            })
            e.Speed       = NumberRange.new(2, 6)
            e.Rate        = 6
            e.Lifetime    = NumberRange.new(2, 4)
            e.SpreadAngle = Vector2.new(20, 20)
            e.LightEmission = 0.4
            e.Parent      = att
        end
    end
end

-- ── Lava Pools ───────────────────────────────────────────────────────────────
-- Flat circular pools at the base of spires and depressions.

local function makeLavaPool(phi, theta)
    local size = rn(10, 28)
    local dc   = discCF(phi, theta, -1, rn(0, math.pi*2))

    local pool = part(Vector3.new(1.2, size, size), dc,
        Color3.fromRGB(200, 50, 5), Enum.Material.Neon)
    pool.Shape = Enum.PartType.Cylinder
    glow(pool, Color3.fromRGB(255, 110, 20), 2.2, size * 3.5)

    local inner = part(Vector3.new(1.3, size * 0.4, size * 0.4), dc,
        Color3.fromRGB(255, 200, 40), Enum.Material.Neon, 0.05)
    inner.Shape      = Enum.PartType.Cylinder
    inner.CanCollide = false

    -- Cracked rim slabs
    local rimBase = surfCF(phi, theta, 0)
    for i = 1, ri(4, 7) do
        local a  = (i / 6) * math.pi * 2 + rn(-0.4, 0.4)
        local d  = size * 0.52 + rn(0, 5)
        local rw = rn(3, 9); local rh = rn(1, 2.5)
        local cf = rimBase
            * CFrame.new(math.cos(a)*d, rh*0.3, math.sin(a)*d)
            * CFrame.Angles(rn(-0.2,0.2), a, rn(-0.1,0.1))
        part(Vector3.new(rw, rh, rw*0.6), cf, Color3.fromRGB(28, 16, 10))
    end

    -- Embers
    local att = Instance.new("Attachment")
    att.WorldPosition = pool.Position + (pool.Position - PC).Unit * 2
    att.Parent = pool
    local sparks = Instance.new("ParticleEmitter")
    sparks.Color         = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 80)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 35,  5)),
    })
    sparks.Transparency  = NumberSequence.new({
        NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)
    })
    sparks.Size          = NumberSequence.new(0.28)
    sparks.Speed         = NumberRange.new(4, 14)
    sparks.Rate          = 8
    sparks.Lifetime      = NumberRange.new(0.4, 1.4)
    sparks.SpreadAngle   = Vector2.new(65, 65)
    sparks.LightEmission = 1
    sparks.Parent        = att
end

-- ── Dark Rocky Ridges ────────────────────────────────────────────────────────
-- Low elongated basalt ridges like hardened lava flows.

local function makeRidge(phi, theta)
    local base  = surfCF(phi, theta, -1, rn(0, math.pi * 2))
    local segs  = ri(4, 9)
    local len   = rn(20, 60)

    for s = 1, segs do
        local t   = (s - 0.5) / segs
        local ox  = (t - 0.5) * len + rn(-3, 3)
        local w   = rn(4, 10) * (1 - math.abs(t - 0.5) * 1.2)  -- taper at ends
        local h   = rn(2, 6)
        local col = SPIRE_DARK[ri(1, #SPIRE_DARK)]
        local cf  = base * CFrame.new(ox, h * 0.3, rn(-3, 3))
                         * CFrame.Angles(rn(-0.15,0.15), rn(-0.1,0.1), rn(-0.1,0.1))
        part(Vector3.new(len / segs + 2, h, w), cf, col)
    end
end

-- ── Alien Flora ──────────────────────────────────────────────────────────────
-- Four types inspired by AI alien plant art:
--   mushroom caps, tentacle vines, succulent rosettes, pod stalks

-- Stem colors: dark organic purples, deep greens, near-black
local STEM_COLS = {
    Color3.fromRGB(35,  18,  45),   -- deep purple
    Color3.fromRGB(12,  35,  20),   -- dark green
    Color3.fromRGB(40,  22,  10),   -- dark brown
    Color3.fromRGB(18,  12,  38),   -- midnight violet
    Color3.fromRGB(8,   28,  30),   -- deep teal bark
}
-- Cap/tip colors: saturated but organic, not garish neon
local CAP_COLS = {
    Color3.fromRGB(200,  60, 180),  -- magenta mushroom
    Color3.fromRGB( 60, 180, 255),  -- bioluminescent blue
    Color3.fromRGB(120, 220,  80),  -- toxic lime
    Color3.fromRGB(255, 120,  40),  -- ember orange
    Color3.fromRGB(160,  80, 255),  -- deep violet
    Color3.fromRGB( 40, 220, 180),  -- teal spore
    Color3.fromRGB(220, 200,  60),  -- amber gold
}

local function stemCol() return STEM_COLS[ri(1,#STEM_COLS)] end
local function capCol()  return CAP_COLS[ri(1,#CAP_COLS)]   end

-- 1. Mushroom: thick squat stem, wide drooping cap, glow underneath
local function makeMushroom(base)
    local sc    = stemCol()
    local cc    = capCol()
    local stemH = rn(3, 9)
    local stemW = rn(1.2, 2.8)
    local capR  = stemW * rn(3, 6)   -- cap much wider than stem
    local capH  = capR  * rn(0.25, 0.4)

    -- Stem — slightly tapered, bulging at base
    for s = 1, 3 do
        local t  = (s - 0.5) / 3
        local sw = stemW * (1 + (1 - t) * 0.5)   -- wider at bottom
        part(Vector3.new(sw, stemH/3 + 0.1, sw),
            base * CFrame.new(0, stemH * (s-1)/3 + stemH/6, 0),
            sc, Enum.Material.SmoothPlastic)
    end
    -- Cap — flat ball, drooping at edges via wedges
    local capCF = base * CFrame.new(0, stemH + capH * 0.3, 0)
    local cap = part(Vector3.new(capR, capH, capR), capCF, cc, Enum.Material.SmoothPlastic)
    cap.Shape  = Enum.PartType.Ball
    -- Drooping rim flaps (3-5 wedge-like slabs around cap edge)
    local flaps = ri(3, 5)
    for i = 1, flaps do
        local ang  = (i / flaps) * math.pi * 2
        local fw   = capR * 0.55
        local fh   = capH * 0.55
        local cf   = base
            * CFrame.new(0, stemH + capH * 0.05, 0)
            * CFrame.Angles(0, ang, 0)
            * CFrame.new(capR * 0.45, 0, 0)
            * CFrame.Angles(0, 0, math.rad(rn(20, 45)))   -- droop outward
        part(Vector3.new(fw, fh, fw * 0.35), cf, cc, Enum.Material.SmoothPlastic)
    end
    -- Soft underglow
    glow(cap, cc, 0.8, capR * 5)
end

-- 2. Tentacle vine: chain of tapering cylinders curving outward from base
local function makeTentacleVine(base)
    local sc     = stemCol()
    local tipC   = capCol()
    local vines  = ri(3, 6)
    for _ = 1, vines do
        local segs  = ri(5, 9)
        local baseW = rn(0.8, 1.8)
        local len   = rn(6, 16)
        -- Each vine curves in a random direction then arcs over
        local curveDir = rn(0, math.pi * 2)
        local curveLean = rn(0.3, 0.7)   -- how much it bends
        local startOff = Vector3.new(rn(-4,4), 0, rn(-4,4))

        local prevCF = base * CFrame.new(startOff.X, 0, startOff.Z)
        for s = 1, segs do
            local t    = s / segs
            local segL = len / segs
            local w    = baseW * (1 - t * 0.75)   -- taper toward tip
            -- Arc: lean increases then levels off
            local lean = curveLean * math.sin(t * math.pi * 0.8)
            local cf   = prevCF
                * CFrame.new(0, segL * 0.5, 0)
                * CFrame.Angles(lean * math.cos(curveDir), rn(-0.05,0.05),
                                lean * math.sin(curveDir))
            local col  = t > 0.85 and tipC or sc
            local mat  = t > 0.85 and Enum.Material.Neon or Enum.Material.SmoothPlastic
            part(Vector3.new(w, segL + 0.05, w), cf, col, mat)
            prevCF = prevCF * CFrame.new(0, segL, 0)
                            * CFrame.Angles(lean * math.cos(curveDir) * 0.5, 0,
                                            lean * math.sin(curveDir) * 0.5)
        end
        -- Glowing bulb tip
        local tipSz = baseW * rn(1.2, 2.0)
        local tipP  = part(Vector3.new(tipSz,tipSz,tipSz), prevCF, tipC, Enum.Material.Neon)
        tipP.Shape  = Enum.PartType.Ball
        glow(tipP, tipC, 0.7, tipSz * 8)
    end
end

-- 3. Succulent rosette: wide flat wedge-leaves arranged in a circle
local function makeSucculent(base)
    local sc    = stemCol()
    local cc    = capCol()
    local leaves = ri(6, 10)
    local llen   = rn(3, 8)
    local lwide  = llen * rn(0.5, 0.9)
    local tilt   = math.rad(rn(25, 55))   -- how much leaves spread outward

    -- Tiny central nub
    part(Vector3.new(1.2, 1.2, 1.2), base * CFrame.new(0, 0.6, 0), sc, Enum.Material.SmoothPlastic)

    for i = 1, leaves do
        local ang = (i / leaves) * math.pi * 2
        local cf  = base
            * CFrame.Angles(0, ang, 0)
            * CFrame.Angles(tilt, 0, 0)
            * CFrame.new(0, llen * 0.5, 0)
        -- Tip color fade
        local t = ri(1,2)
        part(Vector3.new(lwide, llen, lwide * 0.25), cf,
            t == 1 and cc or sc, Enum.Material.SmoothPlastic)
    end
    glow(folder, cc, 0.4, llen * 4)
end

-- 4. Pod stalk cluster: tall thin stems with swollen seed pods on top
local function makePodStalks(base)
    local sc    = stemCol()
    local cc    = capCol()
    local count = ri(4, 8)

    for _ = 1, count do
        local h   = rn(5, 14)
        local sw  = rn(0.3, 0.7)
        local ox  = rn(-5, 5); local oz = rn(-5, 5)
        local lean = rn(-0.15, 0.15)

        -- Thin wiry stem
        part(Vector3.new(sw, h, sw),
            base * CFrame.new(ox, h*0.5, oz) * CFrame.Angles(lean, 0, lean),
            sc, Enum.Material.SmoothPlastic)

        -- Swollen pod
        local psz = sw * rn(3, 6)
        local podCF = base * CFrame.new(ox, h + psz*0.4, oz)
        local pod = part(Vector3.new(psz, psz*1.3, psz), podCF, cc, Enum.Material.SmoothPlastic)
        pod.Shape = Enum.PartType.Ball

        -- Tiny neon ring around pod middle
        local ring = part(
            Vector3.new(0.3, psz * 1.1, psz * 1.1),
            podCF * CFrame.Angles(0, 0, math.rad(90)),
            cc, Enum.Material.Neon, 0.2, false
        )
        ring.Shape = Enum.PartType.Cylinder
        glow(pod, cc, 0.6, psz * 7)
    end
end

local FLORA_KINDS = { makeMushroom, makeTentacleVine, makeSucculent, makePodStalks }

local function makeFlora(phi, theta)
    local base = surfCF(phi, theta, 0, rn(0, math.pi*2))
    FLORA_KINDS[ri(1, #FLORA_KINDS)](base)
end

-- ── Scatter ───────────────────────────────────────────────────────────────────

local COUNTS = { spire=80, river=30, pool=45, ridge=60, flora=70 }

task.spawn(function()
    local n = 0
    for _ = 1, COUNTS.spire  do makeSpireCluster(rpos()) n+=1 if n%8  ==0 then task.wait() end end
    for _ = 1, COUNTS.river  do makeLavaRiver(rpos())    n+=1 if n%5  ==0 then task.wait() end end
    for _ = 1, COUNTS.pool   do makeLavaPool(rpos())     n+=1 if n%10 ==0 then task.wait() end end
    for _ = 1, COUNTS.ridge  do makeRidge(rpos())        n+=1 if n%12 ==0 then task.wait() end end
    for _ = 1, COUNTS.flora  do makeFlora(rpos())        n+=1 if n%15 ==0 then task.wait() end end
    local total = COUNTS.spire+COUNTS.river+COUNTS.pool+COUNTS.ridge+COUNTS.flora
    print(string.format("[SurfaceDecor] Volcanic surface: %d features placed", total))
end)
