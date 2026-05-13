-- ModuleScript → ServerScriptService/WorldGen
-- Builds a planet from a config table. Used by GameSetup.
-- Pass a different config to build a different planet (mars, ice, etc.)
--
-- Config shape:
--   planet  = { radius, center, color, material }
--   base    = { position, width, depth, height, doorWidth, colors={hull,panel,neon,foundation} }
--   beacons = { neonColor, positions = { {x,z}, ... } }

local WorldGen = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function part(size, pos, color, mat, collide, trans)
    local p = Instance.new("Part")
    p.Size         = size
    p.Position     = pos
    p.Anchored     = true
    p.CanCollide   = collide ~= false
    p.CastShadow   = false
    p.Color        = color
    p.Material     = mat or Enum.Material.Metal
    p.Transparency = trans or 0
    p.Parent       = workspace
    return p
end

local function addLight(parent, color, brightness, range)
    local l = Instance.new("PointLight")
    l.Color = color; l.Brightness = brightness; l.Range = range
    l.Parent = parent
end

-- ── Surface math ─────────────────────────────────────────────────────────────

-- Y coordinate of sphere surface at world (x, z).
function WorldGen.surfaceY(cfg, x, z)
    local c = cfg.planet.center
    local r = cfg.planet.radius
    local dx, dz = x - c.X, z - c.Z
    local inner = r * r - dx * dx - dz * dz
    if inner <= 0 then return c.Y end
    return c.Y + math.sqrt(inner)
end

-- ── Planet sphere ─────────────────────────────────────────────────────────────

function WorldGen.buildPlanet(cfg)
    local pc     = cfg.planet
    local sphere = Instance.new("Part")
    sphere.Name      = "PlanetSurface"
    sphere.Shape     = Enum.PartType.Ball
    sphere.Size      = Vector3.new(pc.radius * 2, pc.radius * 2, pc.radius * 2)
    sphere.Position  = pc.center
    sphere.Anchored  = true
    sphere.CanCollide = true
    sphere.CastShadow = false
    sphere.Color     = pc.color
    sphere.Material  = pc.material or Enum.Material.SmoothPlastic
    sphere.CustomPhysicalProperties = PhysicalProperties.new(0.9, 0.6, 0.05, 0.5, 0.5)
    sphere.Parent    = workspace
    return sphere
end

-- ── Base building ─────────────────────────────────────────────────────────────
-- A walkable sci-fi outpost. Interior is open for future upgrade stations.

function WorldGen.buildBase(cfg)
    local bc  = cfg.base
    local pos = bc.position           -- floor-level center on sphere surface
    local W   = bc.width    or 60     -- exterior width  (X)
    local D   = bc.depth    or 80     -- exterior depth  (Z)
    local H   = bc.height   or 12     -- wall height
    local DW  = bc.doorWidth or 10    -- door opening width
    local col = bc.colors

    local BY, BX, BZ = pos.Y, pos.X, pos.Z
    local WT  = 2                     -- wall thickness
    local seg = (W - DW) / 2         -- wall segment either side of door

    -- ── Foundation pad ───────────────────────────────────────────────────────
    -- Raised platform that hides sphere-curvature intersection at edges.
    part(Vector3.new(W + 20, 4, D + 20), Vector3.new(BX, BY - 2, BZ),
        col.foundation or col.panel, Enum.Material.SmoothPlastic)

    -- ── Floor ─────────────────────────────────────────────────────────────────
    part(Vector3.new(W, 3, D), Vector3.new(BX, BY + 1.5, BZ), col.panel)

    -- ── Ceiling ───────────────────────────────────────────────────────────────
    part(Vector3.new(W + 2, 4, D + 2), Vector3.new(BX, BY + H + 2, BZ), col.hull)

    -- ── Walls ─────────────────────────────────────────────────────────────────
    -- North wall (two segments + lintel)
    part(Vector3.new(seg, H, WT), Vector3.new(BX - W/2 + seg/2, BY + H/2 + 1, BZ - D/2), col.hull)
    part(Vector3.new(seg, H, WT), Vector3.new(BX + W/2 - seg/2, BY + H/2 + 1, BZ - D/2), col.hull)
    part(Vector3.new(DW, 3,  WT), Vector3.new(BX,               BY + H - 0.5, BZ - D/2), col.hull)
    -- South wall (two segments + lintel)
    part(Vector3.new(seg, H, WT), Vector3.new(BX - W/2 + seg/2, BY + H/2 + 1, BZ + D/2), col.hull)
    part(Vector3.new(seg, H, WT), Vector3.new(BX + W/2 - seg/2, BY + H/2 + 1, BZ + D/2), col.hull)
    part(Vector3.new(DW, 3,  WT), Vector3.new(BX,               BY + H - 0.5, BZ + D/2), col.hull)
    -- East wall (solid)
    part(Vector3.new(WT, H, D), Vector3.new(BX + W/2, BY + H/2 + 1, BZ), col.hull)
    -- West wall (solid)
    part(Vector3.new(WT, H, D), Vector3.new(BX - W/2, BY + H/2 + 1, BZ), col.hull)

    -- ── Windows (glass panels in east/west walls) ─────────────────────────────
    part(Vector3.new(0.4, H * 0.45, D * 0.3),
        Vector3.new(BX + W/2, BY + H * 0.6, BZ),
        Color3.fromRGB(130, 200, 255), Enum.Material.Glass, false, 0.35)
    part(Vector3.new(0.4, H * 0.45, D * 0.3),
        Vector3.new(BX - W/2, BY + H * 0.6, BZ),
        Color3.fromRGB(130, 200, 255), Enum.Material.Glass, false, 0.35)

    -- ── Corner pillars ────────────────────────────────────────────────────────
    local ph = H + 8
    for _, xz in ipairs({{-W/2,-D/2},{W/2,-D/2},{-W/2,D/2},{W/2,D/2}}) do
        part(Vector3.new(4, ph, 4),
            Vector3.new(BX + xz[1], BY + ph/2 + 1, BZ + xz[2]), col.panel)
    end

    -- ── Door frame neon ───────────────────────────────────────────────────────
    local dh = H - 2   -- door top height
    local dn = part(Vector3.new(DW + 0.5, 0.3, 0.3),
        Vector3.new(BX, BY + dh + 1, BZ - D/2), col.neon, Enum.Material.Neon, false)
    addLight(dn, col.neon, 1, 14)
    local ds = part(Vector3.new(DW + 0.5, 0.3, 0.3),
        Vector3.new(BX, BY + dh + 1, BZ + D/2), col.neon, Enum.Material.Neon, false)
    addLight(ds, col.neon, 1, 14)

    -- ── Interior ceiling neon strips (3 rows) ────────────────────────────────
    local stripOffsets = { -D/3, 0, D/3 }
    for _, zo in ipairs(stripOffsets) do
        local strip = part(Vector3.new(W - 8, 0.25, 0.5),
            Vector3.new(BX, BY + H + 0.3, BZ + zo), col.neon, Enum.Material.Neon, false)
        addLight(strip, col.neon, 2.5, 45)
    end

    -- ── Wall sconces (mid-height on east/west walls) ──────────────────────────
    local sconceOffsets = { -D/3, 0, D/3 }
    for _, zo in ipairs(sconceOffsets) do
        local se = part(Vector3.new(0.3, 0.8, 1.8),
            Vector3.new(BX + W/2 - 0.3, BY + H * 0.5, BZ + zo), col.neon, Enum.Material.Neon, false)
        addLight(se, col.neon, 1.8, 28)
        local sw = part(Vector3.new(0.3, 0.8, 1.8),
            Vector3.new(BX - W/2 + 0.3, BY + H * 0.5, BZ + zo), col.neon, Enum.Material.Neon, false)
        addLight(sw, col.neon, 1.8, 28)
    end

    -- ── Roof neon trim ────────────────────────────────────────────────────────
    local rn = part(Vector3.new(W + 2, 0.25, 0.25),
        Vector3.new(BX, BY + H + 1.6, BZ - D/2), col.neon, Enum.Material.Neon, false)
    addLight(rn, col.neon, 0.8, 22)
    local rs = part(Vector3.new(W + 2, 0.25, 0.25),
        Vector3.new(BX, BY + H + 1.6, BZ + D/2), col.neon, Enum.Material.Neon, false)
    addLight(rs, col.neon, 0.8, 22)
    part(Vector3.new(0.25, 0.25, D + 2),
        Vector3.new(BX + W/2, BY + H + 1.6, BZ), col.neon, Enum.Material.Neon, false)
    part(Vector3.new(0.25, 0.25, D + 2),
        Vector3.new(BX - W/2, BY + H + 1.6, BZ), col.neon, Enum.Material.Neon, false)

    -- ── Rooftop antenna ───────────────────────────────────────────────────────
    part(Vector3.new(1.2, 14, 1.2),
        Vector3.new(BX + W/2 - 5, BY + H + 8, BZ - D/2 + 5), col.panel, Enum.Material.Metal)
    local antTip = part(Vector3.new(2, 0.7, 2),
        Vector3.new(BX + W/2 - 5, BY + H + 15.4, BZ - D/2 + 5), col.neon, Enum.Material.Neon, false)
    addLight(antTip, col.neon, 4, 50)
end

-- ── Beacon tower ─────────────────────────────────────────────────────────────

function WorldGen.buildBeacon(cfg, x, z, neonColor)
    local surfY = WorldGen.surfaceY(cfg, x, z)
    local DARK  = Color3.fromRGB(32, 38, 58)
    local MID   = Color3.fromRGB(48, 56, 82)

    part(Vector3.new(8, 1.5, 8),   Vector3.new(x, surfY + 0.75, z), MID)
    part(Vector3.new(2.5, 28, 2.5), Vector3.new(x, surfY + 15.5, z), DARK)
    local cap = part(Vector3.new(4.5, 0.8, 4.5),
        Vector3.new(x, surfY + 30, z), neonColor, Enum.Material.Neon, false)
    addLight(cap, neonColor, 3, 70)

    local beacon = part(Vector3.new(1, 1, 1),
        Vector3.new(x, surfY + 31, z), Color3.fromRGB(255, 50, 50), Enum.Material.Neon, false)
    addLight(beacon, Color3.fromRGB(255, 50, 50), 4, 80)
    task.spawn(function()
        while beacon.Parent do
            beacon.Transparency = 0; task.wait(0.7)
            beacon.Transparency = 0.9; task.wait(0.7)
        end
    end)
end

return WorldGen
