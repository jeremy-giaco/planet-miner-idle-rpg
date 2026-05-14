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
    sphere.Material  = pc.material or Enum.Material.Rock
    sphere.CustomPhysicalProperties = PhysicalProperties.new(0.9, 0.6, 0.05, 0.5, 0.5)
    if pc.textureId then
        local sa = Instance.new("SurfaceAppearance")
        sa.ColorMap   = pc.textureId
        sa.RoughnessMap = pc.roughnessMap or ""
        sa.NormalMap    = pc.normalMap    or ""
        sa.Parent = sphere
    end
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
    -- Buried deep enough that its bottom clears the sphere surface at the
    -- furthest corner of the base+hangar footprint (worst gap ~12 st at R=1024).
    part(Vector3.new(W + 20, 18, D + 20), Vector3.new(BX, BY - 9, BZ),
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
    -- East wall (glass) — opening cut for storage room connection (20 wide, 36 tall)
    local STORE_OW = 20   -- opening width (Z)
    local STORE_OH = 36   -- opening height
    local eseg = (D - STORE_OW) / 2
    part(Vector3.new(WT, H, eseg), Vector3.new(BX + W/2, BY + H/2 + 1, BZ - STORE_OW/2 - eseg/2), GLASS_COL, GLASS_MAT, true, GLASS_T)
    part(Vector3.new(WT, H, eseg), Vector3.new(BX + W/2, BY + H/2 + 1, BZ + STORE_OW/2 + eseg/2), GLASS_COL, GLASS_MAT, true, GLASS_T)
    part(Vector3.new(WT, H - STORE_OH, STORE_OW), Vector3.new(BX + W/2, BY + STORE_OH + (H - STORE_OH)/2 + 1, BZ), col.hull)
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

    -- ── Interior ceiling neon strips (5 rows) ────────────────────────────────
    local stripOffsets = { -D*0.4, -D*0.15, 0, D*0.15, D*0.4 }
    for _, zo in ipairs(stripOffsets) do
        local strip = part(Vector3.new(W - 8, 0.3, 0.6),
            Vector3.new(BX, BY + H + 0.3, BZ + zo), col.neon, Enum.Material.Neon, false)
        addLight(strip, col.neon, 2.5, 45)
    end

    -- ── Wall sconces (mid-height on east/west walls) ──────────────────────────
    local sconceOffsets = { -D/3, 0, D/3 }
    for _, zo in ipairs(sconceOffsets) do
        local se = part(Vector3.new(0.3, 0.8, 1.8),
            Vector3.new(BX + W/2 - 0.3, BY + H * 0.5, BZ + zo), col.neon, Enum.Material.Neon, false)
        addLight(se, col.neon, 2, 30)
        local sw = part(Vector3.new(0.3, 0.8, 1.8),
            Vector3.new(BX - W/2 + 0.3, BY + H * 0.5, BZ + zo), col.neon, Enum.Material.Neon, false)
        addLight(sw, col.neon, 2, 30)
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

    -- ── Exterior ramps (north + south doors) ─────────────────────────────────
    local R2  = cfg.planet.radius
    local PC2 = cfg.planet.center
    local rampRun = 16   -- horizontal depth of each ramp

    local function surfYAtZ(z)
        local dz = z - PC2.Z
        local inner = R2*R2 - dz*dz
        return PC2.Y + (inner > 0 and math.sqrt(inner) or 0)
    end

    local function buildRamp(centerX, centerY, centerZ, rampLen, angleX)
        local r = Instance.new("Part")
        r.Size      = Vector3.new(DW, 1.2, rampLen)
        r.CFrame    = CFrame.new(centerX, centerY, centerZ) * CFrame.Angles(angleX, 0, 0)
        r.Anchored  = true; r.CanCollide = true; r.CastShadow = false
        r.Color     = col.panel; r.Material = Enum.Material.Metal
        r.Parent    = workspace
        -- Neon edge strips along both sides
        for _, sx in ipairs({ DW/2, -DW/2 }) do
            local strip = Instance.new("Part")
            strip.Size      = Vector3.new(0.25, 0.25, rampLen)
            strip.CFrame    = CFrame.new(centerX + sx, centerY + 0.7, centerZ) * CFrame.Angles(angleX, 0, 0)
            strip.Anchored  = true; strip.CanCollide = false; strip.CastShadow = false
            strip.Color     = col.neon; strip.Material = Enum.Material.Neon
            strip.Parent    = workspace
            addLight(strip, col.neon, 0.6, 10)
        end
    end

    local foundation = 10   -- foundation slab extends 10 studs past each wall

    -- South ramp: high end at foundation edge (z=BZ+D/2+foundation), low end beyond
    local sStartZ = BZ + D/2 + foundation
    local sFarZ   = sStartZ + rampRun
    local sSurfY  = surfYAtZ(sFarZ)
    local sRise   = BY - sSurfY
    local sLen    = math.sqrt(rampRun*rampRun + sRise*sRise)
    local sAng    = math.atan2(sRise, rampRun)
    buildRamp(BX, (BY + sSurfY)/2, sStartZ + rampRun/2, sLen, sAng)

    -- North ramp: high end at foundation edge (z=BZ-D/2-foundation), low end beyond
    local nStartZ = BZ - D/2 - foundation
    local nFarZ   = nStartZ - rampRun
    local nSurfY  = surfYAtZ(nFarZ)
    local nRise   = BY - nSurfY
    local nLen    = math.sqrt(rampRun*rampRun + nRise*nRise)
    local nAng    = math.atan2(nRise, rampRun)
    buildRamp(BX, (BY + nSurfY)/2, nStartZ - rampRun/2, nLen, -nAng)

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

    -- Foundation fill — buries hangar into sphere so no gap at edges
    hp(Vector3.new(HW + 4, 18, HD + 4), cx, fy - 9, cz, col.foundation or col.hull)
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

-- ── Storage Room ─────────────────────────────────────────────────────────────
-- Bright industrial room attached to the east side of the base.
-- Contains 9 resource bins (one per material type) in a U-shape.
-- Bins are named "Bin_<ResourceName>" for the drone deposit system.

function WorldGen.buildStorageRoom(cfg)
    local bc  = cfg.base
    local pos = bc.position
    local W   = bc.width  or 60
    local D   = bc.depth  or 80
    local H   = bc.height or 12
    local col = bc.colors

    local BX, BY, BZ = pos.X, pos.Y, pos.Z

    -- Room dimensions (extends east from base east wall)
    local RW  = 90    -- room width (X)
    local RD  = 120   -- room depth (Z)
    local RH  = H     -- same height as base
    local WT  = 2     -- wall thickness
    local OW  = 20    -- opening width (Z, must match base east wall cut)
    local OH  = 36    -- opening height (must match base east wall cut)

    -- Room world-space center
    local rx = BX + W/2 + RW/2   -- 0 + 70 + 45 = 115
    local rz = BZ                 -- 0
    local ry = BY                 -- 1019

    -- Colors: match main base palette
    local WALL_COL  = col.hull
    local FLOOR_COL = col.panel
    local CEIL_COL  = col.hull
    local WARM_NEON = col.neon
    local WARM_LITE = col.neon

    local folder = Instance.new("Folder")
    folder.Name = "StorageRoom"; folder.Parent = workspace

    local function sp(size, wx, wy, wz, color, mat, trans, collide)
        local p = Instance.new("Part")
        p.Size = size; p.Position = Vector3.new(wx, wy, wz)
        p.Anchored = true; p.CanCollide = collide ~= false; p.CastShadow = false
        p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic
        p.Transparency = trans or 0; p.Parent = folder
        return p
    end
    local function sl(parent, color, brightness, range)
        local l = Instance.new("PointLight")
        l.Color = color; l.Brightness = brightness; l.Range = range; l.Parent = parent
    end

    -- Foundation
    sp(Vector3.new(RW+4, 18, RD+4), rx, ry-9, rz, col.foundation or col.panel)

    -- Floor
    sp(Vector3.new(RW, 3, RD), rx, ry+1.5, rz, FLOOR_COL)

    -- Ceiling
    sp(Vector3.new(RW+WT*2, 5, RD+WT*2), rx, ry+RH+2.5, rz, CEIL_COL)

    -- East wall (far side)
    sp(Vector3.new(WT, RH, RD), BX+W/2+RW, ry+RH/2+1, rz, WALL_COL)

    -- North wall
    sp(Vector3.new(RW+WT, RH, WT), rx-WT/2, ry+RH/2+1, rz-RD/2, WALL_COL)

    -- South wall
    sp(Vector3.new(RW+WT, RH, WT), rx-WT/2, ry+RH/2+1, rz+RD/2, WALL_COL)

    -- West wall: no parts needed — the base east glass wall already provides this boundary.

    -- Entrance neon frame
    local nf = sp(Vector3.new(OW+1, 0.35, 0.35), BX+W/2, ry+OH+1, rz, WARM_NEON, Enum.Material.Neon, 0, false)
    sl(nf, WARM_LITE, 2, 18)

    -- STORAGE sign above entrance (inside the room, facing west)
    local signPlate = sp(Vector3.new(20, 3.5, 0.3), BX+W/2+1, ry+OH+3.5, rz,
        Color3.fromRGB(12, 12, 18), Enum.Material.SmoothPlastic)
    do
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0, 280, 0, 56); bb.StudsOffset = Vector3.new(0, 0, 0.5)
        bb.AlwaysOnTop = false; bb.MaxDistance = 60; bb.Parent = signPlate
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
        lbl.Text = "⬡  STORAGE  ⬡"; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 20
        lbl.TextColor3 = Color3.fromRGB(255,235,150)
        lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0); lbl.TextStrokeTransparency = 0.2
        lbl.Parent = bb
    end

    -- ── Ceiling light grid (6 panels, very bright) ──────────────────────────
    local lightX = { BX+W/2 + RW*0.28, BX+W/2 + RW*0.72 }
    local lightZ = { rz - RD*0.3, rz, rz + RD*0.3 }
    for _, lx in ipairs(lightX) do
        for _, lz in ipairs(lightZ) do
            local panel = sp(Vector3.new(14, 0.35, 0.7), lx, ry+RH+0.4, lz, WARM_NEON, Enum.Material.Neon, 0, false)
            sl(panel, WARM_LITE, 2.5, 45)
        end
    end
    -- Extra fill lights near floor on north/south walls
    for _, lz in ipairs({ rz-RD/2+1, rz+RD/2-1 }) do
        local sconce = sp(Vector3.new(0.35, 1, 2), rx, ry+5, lz, WARM_NEON, Enum.Material.Neon, 0, false)
        sl(sconce, WARM_LITE, 2, 28)
    end

    -- ── Corner pillars ───────────────────────────────────────────────────────
    for _, xz in ipairs({ {BX+W/2, rz-RD/2}, {BX+W/2+RW, rz-RD/2}, {BX+W/2, rz+RD/2}, {BX+W/2+RW, rz+RD/2} }) do
        sp(Vector3.new(3, RH+4, 3), xz[1], ry+RH/2+3, xz[2], col.panel)
    end

    -- ── Resource bins (U-shape: north wall, east wall, south wall) ───────────
    local RESOURCES = {
        { name="Rock",     color=Color3.fromRGB(130,100, 70) },
        { name="Metal",    color=Color3.fromRGB(160,165,185) },
        { name="Crystal",  color=Color3.fromRGB(130, 75,240) },
        { name="Ice",      color=Color3.fromRGB(150,200,255) },
        { name="Iron",     color=Color3.fromRGB(140,130,120) },
        { name="Copper",   color=Color3.fromRGB(210,105, 55) },
        { name="Silver",   color=Color3.fromRGB(200,205,220) },
        { name="Gold",     color=Color3.fromRGB(220,170, 20) },
        { name="Titanium", color=Color3.fromRGB(155,175,200) },
    }
    local BIN_W, BIN_D, BIN_H = 10, 10, 14
    local BIN_Y = ry + 3 + BIN_H/2   -- sitting on floor

    -- Bin positions: north wall (3), east wall (3), south wall (3)
    local binPositions = {
        -- North wall
        { x = rx - 28, z = rz - RD/2 + 9 },
        { x = rx,      z = rz - RD/2 + 9 },
        { x = rx + 28, z = rz - RD/2 + 9 },
        -- East wall
        { x = BX+W/2+RW - 9, z = rz - 28 },
        { x = BX+W/2+RW - 9, z = rz      },
        { x = BX+W/2+RW - 9, z = rz + 28 },
        -- South wall
        { x = rx + 28, z = rz + RD/2 - 9 },
        { x = rx,      z = rz + RD/2 - 9 },
        { x = rx - 28, z = rz + RD/2 - 9 },
    }

    for i, res in ipairs(RESOURCES) do
        local bp = binPositions[i]

        -- Main container body
        local body = sp(Vector3.new(BIN_W, BIN_H, BIN_D), bp.x, BIN_Y, bp.z,
            Color3.fromRGB(24, 28, 40), Enum.Material.Metal)
        body.Name = "Bin_" .. res.name

        -- Coloured indicator top (neon glow, resource colour)
        local top = sp(Vector3.new(BIN_W, 0.4, BIN_D), bp.x, ry+3+BIN_H+0.2, bp.z,
            res.color, Enum.Material.Neon, 0.2, false)
        sl(top, res.color, 1.5, 12)

        -- Dark recessed interior
        sp(Vector3.new(BIN_W-1.5, 0.3, BIN_D-1.5), bp.x, ry+3+BIN_H-0.1, bp.z,
            Color3.fromRGB(10, 12, 18), Enum.Material.SmoothPlastic, 0, false)

        -- Side accent stripe
        sp(Vector3.new(BIN_W+0.1, 0.5, 0.25), bp.x, BIN_Y + BIN_H*0.3, bp.z - BIN_D/2,
            res.color, Enum.Material.Neon, 0.4, false)

        -- Label billboard
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0, 130, 0, 38); bb.StudsOffset = Vector3.new(0, BIN_H/2 + 2.5, 0)
        bb.AlwaysOnTop = false; bb.MaxDistance = 50; bb.Parent = body
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
        lbl.Text = res.name:upper(); lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 15
        lbl.TextColor3 = Color3.fromRGB(255,255,255)
        lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0); lbl.TextStrokeTransparency = 0.15
        lbl.Parent = bb
    end

    print("[WorldGen] Storage room built")
    return folder
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
