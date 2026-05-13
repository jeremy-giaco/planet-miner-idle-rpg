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

    local GLASS_COL = Color3.fromRGB(140, 200, 255)
    local GLASS_MAT = Enum.Material.Glass
    local GLASS_T   = 0.3

    -- ── Ceiling (glass) ───────────────────────────────────────────────────────
    -- 5-stud thickness prevents characters from falling through the glass roof.
    part(Vector3.new(W + 2, 5, D + 2), Vector3.new(BX, BY + H + 2.5, BZ),
        GLASS_COL, GLASS_MAT, true, GLASS_T)

    -- ── Walls (glass) ─────────────────────────────────────────────────────────
    -- North wall (two glass segments + opaque lintel above door)
    part(Vector3.new(seg, H, WT), Vector3.new(BX - W/2 + seg/2, BY + H/2 + 1, BZ - D/2), GLASS_COL, GLASS_MAT, true, GLASS_T)
    part(Vector3.new(seg, H, WT), Vector3.new(BX + W/2 - seg/2, BY + H/2 + 1, BZ - D/2), GLASS_COL, GLASS_MAT, true, GLASS_T)
    part(Vector3.new(DW, 3,  WT), Vector3.new(BX,               BY + H - 0.5, BZ - D/2), col.hull)
    -- South wall (two glass segments + opaque lintel above door)
    part(Vector3.new(seg, H, WT), Vector3.new(BX - W/2 + seg/2, BY + H/2 + 1, BZ + D/2), GLASS_COL, GLASS_MAT, true, GLASS_T)
    part(Vector3.new(seg, H, WT), Vector3.new(BX + W/2 - seg/2, BY + H/2 + 1, BZ + D/2), GLASS_COL, GLASS_MAT, true, GLASS_T)
    part(Vector3.new(DW, 3,  WT), Vector3.new(BX,               BY + H - 0.5, BZ + D/2), col.hull)
    -- East wall (glass)
    part(Vector3.new(WT, H, D), Vector3.new(BX + W/2, BY + H/2 + 1, BZ), GLASS_COL, GLASS_MAT, true, GLASS_T)
    -- West wall (glass)
    part(Vector3.new(WT, H, D), Vector3.new(BX - W/2, BY + H/2 + 1, BZ), GLASS_COL, GLASS_MAT, true, GLASS_T)

    -- ── Corner pillars ────────────────────────────────────────────────────────
    -- Interior section: floor → ceiling (stays inside walls, no roof clip)
    local ceilTop = H + 4           -- top face of ceiling slab
    local intH    = ceilTop - 1     -- interior pillar height (BY+1 to BY+ceilTop)
    for _, xz in ipairs({{-W/2,-D/2},{W/2,-D/2},{-W/2,D/2},{W/2,D/2}}) do
        part(Vector3.new(4, intH, 4),
            Vector3.new(BX + xz[1], BY + intH/2 + 1, BZ + xz[2]), col.panel)
        -- Roof spire: sits cleanly on top of the ceiling
        local spireH = 24
        part(Vector3.new(3.2, spireH, 3.2),
            Vector3.new(BX + xz[1], BY + ceilTop + spireH/2, BZ + xz[2]), col.panel)
        -- Spire neon tip
        local tip = part(Vector3.new(1.5, 0.6, 1.5),
            Vector3.new(BX + xz[1], BY + ceilTop + spireH + 0.3, BZ + xz[2]),
            col.neon, Enum.Material.Neon, false)
        addLight(tip, col.neon, 1.5, 22)
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
    -- Ceiling top = BY + H + 4. Pole starts at BY + H + 10 (6 studs clear).
    local antBase = H + 10          -- bottom of pole above BY
    local antLen  = 22
    part(Vector3.new(1.2, antLen, 1.2),
        Vector3.new(BX + W/2 - 5, BY + antBase + antLen/2, BZ - D/2 + 5), col.panel, Enum.Material.Metal)
    local antTip = part(Vector3.new(2, 0.7, 2),
        Vector3.new(BX + W/2 - 5, BY + antBase + antLen + 0.35, BZ - D/2 + 5), col.neon, Enum.Material.Neon, false)
    addLight(antTip, col.neon, 4, 50)
end

-- ── Hangar ───────────────────────────────────────────────────────────────────
-- Attached to the north face of the base. The existing north door becomes the
-- hallway. A large sliding blast door faces outward on the north face.

function WorldGen.buildHangar(cfg)
    local bc  = cfg.base
    local pos = bc.position
    local W   = bc.width  or 60
    local D   = bc.depth  or 80
    local H   = bc.height or 12
    local col = bc.colors

    local BX, BY, BZ = pos.X, pos.Y, pos.Z
    local northZ = BZ - D/2      -- Z of base north wall = -100

    -- Hangar dims
    local HW  = 100       -- hangar width  (X)
    local HD  = 55        -- hangar depth  (Z, extending north)
    local HH  = H + 14    -- hangar height (taller than base interior)
    local WT  = 2.5   -- wall thickness
    local bayW = 70   -- bay opening width
    local bayH = 30   -- bay opening height
    local conW = 20   -- connection opening width (south wall, into base)

    -- World coords
    local cx = BX
    local cz = northZ - HD/2    -- hangar centre Z = -127.5
    local fy = BY                -- floor level Y = 700

    local folder = Instance.new("Folder")
    folder.Name = "Hangar"; folder.Parent = workspace

    local function hp(size, wx, wy, wz, color, mat, trans, collide)
        local p = Instance.new("Part")
        p.Size = size
        p.Position = Vector3.new(wx, wy, wz)
        p.Anchored = true
        p.CanCollide = collide ~= false
        p.CastShadow = false
        p.Color = color
        p.Material = mat or Enum.Material.Metal
        p.Transparency = trans or 0
        p.Parent = folder
        return p
    end

    -- Visible floor
    hp(Vector3.new(HW, 3, HD), cx, fy+1.5, cz, col.panel)
    -- Ceiling
    hp(Vector3.new(HW+WT*2, 5, HD+WT*2), cx, fy+HH+2.5, cz, col.hull)

    -- South wall (Z = northZ): opening aligned with base north door
    local cs = (HW - conW)/2
    hp(Vector3.new(cs, HH, WT), cx - HW/2 + cs/2, fy+HH/2+3, northZ, col.hull)
    hp(Vector3.new(cs, HH, WT), cx + HW/2 - cs/2, fy+HH/2+3, northZ, col.hull)
    hp(Vector3.new(conW, HH-H+2, WT), cx, fy+H+(HH-H+2)/2+1, northZ, col.hull)

    -- North face (Z = northZ-HD): bay opening
    local bs = (HW - bayW)/2
    hp(Vector3.new(bs, HH, WT),       cx - HW/2 + bs/2, fy+HH/2+3, northZ-HD, col.hull)
    hp(Vector3.new(bs, HH, WT),       cx + HW/2 - bs/2, fy+HH/2+3, northZ-HD, col.hull)
    hp(Vector3.new(bayW, HH-bayH, WT), cx,               fy+bayH+(HH-bayH)/2+3, northZ-HD, col.hull)

    -- Side walls
    hp(Vector3.new(WT, HH, HD), cx+HW/2, fy+HH/2+3, cz, col.hull)
    hp(Vector3.new(WT, HH, HD), cx-HW/2, fy+HH/2+3, cz, col.hull)

    -- Corner pillars
    for _, xz in ipairs({{-HW/2,-HD/2},{HW/2,-HD/2},{-HW/2,HD/2},{HW/2,HD/2}}) do
        hp(Vector3.new(5, HH+6, 5), cx+xz[1], fy+HH/2+4, northZ+xz[2], col.panel)
    end

    -- Interior ceiling neon strips
    local s1 = hp(Vector3.new(HW-12, 0.3, 0.7), cx, fy+HH+0.5, cz-HD/4, col.neon, Enum.Material.Neon, 0, false)
    addLight(s1, col.neon, 4, 60)
    local s2 = hp(Vector3.new(HW-12, 0.3, 0.7), cx, fy+HH+0.5, cz+HD/4, col.neon, Enum.Material.Neon, 0, false)
    addLight(s2, col.neon, 4, 60)

    -- Floor guide lines leading to bay
    hp(Vector3.new(0.4, 0.2, HD-4), cx-bayW/2+2, fy+3.1, cz, col.neon, Enum.Material.Neon, 0, false)
    hp(Vector3.new(0.4, 0.2, HD-4), cx+bayW/2-2, fy+3.1, cz, col.neon, Enum.Material.Neon, 0, false)

    -- Bay door neon frame
    local df = hp(Vector3.new(bayW+2, 0.5, 0.5), cx, fy+bayH+3.5, northZ-HD, col.neon, Enum.Material.Neon, 0, false)
    addLight(df, col.neon, 3, 28)

    -- ── Blast door (slides UP to open) ───────────────────────────────────────
    local doorY_closed = fy + 3 + bayH/2  -- resting on floor
    local doorY_open   = fy + 3 + bayH + bayH/2 + 2  -- fully retracted up
    local door = hp(Vector3.new(bayW, bayH, 1.2),
        cx, doorY_closed, northZ-HD, col.hull)
    door.Name = "BayDoor"

    -- Neon horizontal bands on door
    for i = 0, 2 do
        local band = hp(Vector3.new(bayW-2, 0.4, 0.2),
            cx, doorY_closed - bayH/2 + (i+1)*(bayH/4), northZ-HD-0.7,
            col.neon, Enum.Material.Neon, 0, false)
        band.Name = "DoorBand"..i
        addLight(band, col.neon, 1.5, 18)
    end

    -- Store open/closed Y in attributes for ShipSpawner to read
    door:SetAttribute("ClosedY", doorY_closed)
    door:SetAttribute("OpenY",   doorY_open)

    -- ── Recall button — mounted on inside of south wall ──────────────────────
    local RED      = Color3.fromRGB(220, 30,  30)
    local HOUSING  = Color3.fromRGB(28,  28,  34)
    local RING_COL = Color3.fromRGB(60,  62,  72)
    local btnX     = cx + conW/2 + 6
    local wallZ    = northZ + WT          -- inner face of south wall
    local btnY     = fy + 9

    -- Backing plate (rectangular, dark, flush with wall)
    hp(Vector3.new(7, 9, 0.3), btnX, btnY, wallZ + 0.15, HOUSING, Enum.Material.Metal)
    -- Collar ring: cylinder whose circular face points into the hangar (+Z)
    -- Roblox cylinder axis = X by default; rotate 90° around Y to point along Z.
    local collar = Instance.new("Part")
    collar.Shape     = Enum.PartType.Cylinder
    collar.Size      = Vector3.new(0.6, 4.2, 4.2)   -- depth, diameter, diameter — truly circular
    collar.CFrame    = CFrame.new(btnX, btnY, wallZ + 0.6) * CFrame.Angles(0, math.rad(90), 0)
    collar.Anchored  = true; collar.CanCollide = false; collar.CastShadow = false
    collar.Color     = RING_COL; collar.Material = Enum.Material.Metal
    collar.Parent    = folder

    -- Dome: sphere so it looks perfectly circular from all angles (fire-alarm style)
    local btn = Instance.new("Part")
    btn.Name     = "RecallButton"
    btn.Shape    = Enum.PartType.Ball
    btn.Size     = Vector3.new(3.2, 3.2, 3.2)
    btn.Position = Vector3.new(btnX, btnY, wallZ + 1.1)   -- protrudes from collar
    btn.Anchored = true; btn.CanCollide = false; btn.CastShadow = false
    btn.Color    = RED; btn.Material = Enum.Material.Neon
    btn.Parent   = folder
    addLight(btn, RED, 4, 18)

    -- ── Sign above the button ─────────────────────────────────────────────────
    -- Physical sign plate so it's visible even without BillboardGui
    local signPlate = hp(Vector3.new(7, 2.2, 0.25), btnX, btnY + 5.8, wallZ + 0.15,
        Color3.fromRGB(10, 10, 14), Enum.Material.SmoothPlastic)
    local bb = Instance.new("BillboardGui")
    bb.Size        = UDim2.new(0, 220, 0, 52)
    bb.StudsOffset = Vector3.new(0, 0, 0.5)   -- float 0.5 studs in front of plate
    bb.AlwaysOnTop = false
    bb.MaxDistance = 40
    bb.Parent      = signPlate
    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = "RECALL SHIP"
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 20
    lbl.TextColor3             = Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0.3
    lbl.Parent                 = bb

    -- ProximityPrompt on the button dome
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText            = "Recall Ship"
    prompt.ObjectText            = "RECALL SHIP"
    prompt.KeyboardKeyCode       = Enum.KeyCode.F
    prompt.HoldDuration          = 0.4
    prompt.RequiresLineOfSight   = false
    prompt.MaxActivationDistance = 16
    prompt.Parent                = btn

    print("[WorldGen] Hangar built. Door closed Y=" .. doorY_closed .. " open Y=" .. doorY_open)
    return folder
end

-- ── Beacon tower ─────────────────────────────────────────────────────────────

function WorldGen.buildBeacon(cfg, x, z, neonColor)
    local surfY = WorldGen.surfaceY(cfg, x, z)
    local DARK  = Color3.fromRGB(32, 38, 58)
    local MID   = Color3.fromRGB(48, 56, 82)

    -- Wide base pad
    part(Vector3.new(10, 2, 10),    Vector3.new(x, surfY + 1,    z), MID)
    -- Tall pole (80 studs — visible above the base roofline)
    part(Vector3.new(2.5, 78, 2.5), Vector3.new(x, surfY + 41,   z), DARK)
    -- Mid-section ring accent
    local ring = part(Vector3.new(5, 0.6, 5),
        Vector3.new(x, surfY + 40, z), neonColor, Enum.Material.Neon, false)
    addLight(ring, neonColor, 1.5, 30)
    -- Cap
    local cap = part(Vector3.new(5, 1, 5),
        Vector3.new(x, surfY + 81, z), neonColor, Enum.Material.Neon, false)
    addLight(cap, neonColor, 4, 90)
    -- Blinking warning light
    local beacon = part(Vector3.new(1.2, 1.2, 1.2),
        Vector3.new(x, surfY + 82.6, z), Color3.fromRGB(255, 50, 50), Enum.Material.Neon, false)
    addLight(beacon, Color3.fromRGB(255, 50, 50), 5, 100)
    task.spawn(function()
        while beacon.Parent do
            beacon.Transparency = 0; task.wait(0.7)
            beacon.Transparency = 0.9; task.wait(0.7)
        end
    end)
end

-- ── Debris Shield (bubble) ────────────────────────────────────────────────────
-- Invisible sphere that stops debris from entering the base compound.
-- Uses "DebrisShield" collision group → passes players & ships, stops debris.

function WorldGen.buildDebrisShield(cfg)
    local bc  = cfg.base
    local pos = bc.position
    local BX, BY, BZ = pos.X, pos.Y, pos.Z
    local col = bc.colors

    -- Radius 300, centered 120 studs above the pole.
    -- Bottom of sphere is BY-180 (underground), cross-section at ground level ≈275 studs.
    -- Fully encloses base + hangar compound from all angles above.
    local R = 300
    local shield = Instance.new("Part")
    shield.Name     = "DebrisShield"
    shield.Shape    = Enum.PartType.Ball
    shield.Size     = Vector3.new(R * 2, R * 2, R * 2)
    shield.Position = Vector3.new(BX, BY + 120, BZ)
    shield.Anchored = true
    shield.CanCollide = true
    shield.CastShadow = false
    shield.Color    = col.neon
    shield.Material = Enum.Material.Neon
    -- Very faint bubble so players can just barely see the dome boundary
    shield.Transparency = 0.97
    pcall(function() shield.CollisionGroup = "DebrisShield" end)
    shield.Parent = workspace


    print("[WorldGen] Debris shield built. Radius=" .. R)
    return shield
end

return WorldGen
