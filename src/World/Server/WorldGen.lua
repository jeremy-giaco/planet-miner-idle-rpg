-- ModuleScript → ServerScriptService/WorldGen
-- Builds the flat-map world from Config values.
-- Keeps the sci-fi base, hangar, storage room, beacons, and debris shield.
-- All sphere/planet math removed — ground is flat at Config.MAP_GROUND_Y.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local WorldGen = {}

local GROUND_Y = Config.MAP_GROUND_Y   -- 0

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

-- ── Base ──────────────────────────────────────────────────────────────────────
-- Sci-fi outpost sitting flat on the ground.

function WorldGen.buildBase()
    local bp  = Config.BASE_POSITION
    local W   = Config.BASE_WIDTH
    local D   = Config.BASE_DEPTH
    local H   = Config.BASE_HEIGHT
    local DW  = Config.BASE_DOOR_WIDTH
    local col = Config.BASE_COLORS

    local BX, BY, BZ = bp.X, GROUND_Y, bp.Z
    local WT  = 2
    local seg = (W - DW) / 2

    -- Foundation pad
    part(Vector3.new(W + 20, 4, D + 20),
        Vector3.new(BX, BY - 2, BZ), col.foundation or col.panel, Enum.Material.SmoothPlastic)

    -- Floor
    part(Vector3.new(W, 3, D), Vector3.new(BX, BY + 1.5, BZ), col.panel)

    local GLASS_COL = Color3.fromRGB(140, 200, 255)
    local GLASS_MAT = Enum.Material.Glass
    local GLASS_T   = 0.3

    -- Ceiling (glass)
    part(Vector3.new(W + 2, 5, D + 2), Vector3.new(BX, BY + H + 2.5, BZ),
        GLASS_COL, GLASS_MAT, true, GLASS_T)

    -- North wall (two glass segments + opaque lintel above door)
    part(Vector3.new(seg, H, WT), Vector3.new(BX - W/2 + seg/2, BY + H/2 + 1, BZ - D/2), GLASS_COL, GLASS_MAT, true, GLASS_T)
    part(Vector3.new(seg, H, WT), Vector3.new(BX + W/2 - seg/2, BY + H/2 + 1, BZ - D/2), GLASS_COL, GLASS_MAT, true, GLASS_T)
    part(Vector3.new(DW, 3, WT),  Vector3.new(BX, BY + H - 0.5, BZ - D/2), col.hull)
    -- South wall
    part(Vector3.new(seg, H, WT), Vector3.new(BX - W/2 + seg/2, BY + H/2 + 1, BZ + D/2), GLASS_COL, GLASS_MAT, true, GLASS_T)
    part(Vector3.new(seg, H, WT), Vector3.new(BX + W/2 - seg/2, BY + H/2 + 1, BZ + D/2), GLASS_COL, GLASS_MAT, true, GLASS_T)
    part(Vector3.new(DW, 3, WT),  Vector3.new(BX, BY + H - 0.5, BZ + D/2), col.hull)
    -- East wall (opening for storage room connection)
    local STORE_OW = 20
    local STORE_OH = 36
    local eseg = (D - STORE_OW) / 2
    part(Vector3.new(WT, H, eseg), Vector3.new(BX + W/2, BY + H/2 + 1, BZ - STORE_OW/2 - eseg/2), GLASS_COL, GLASS_MAT, true, GLASS_T)
    part(Vector3.new(WT, H, eseg), Vector3.new(BX + W/2, BY + H/2 + 1, BZ + STORE_OW/2 + eseg/2), GLASS_COL, GLASS_MAT, true, GLASS_T)
    part(Vector3.new(WT, H - STORE_OH, STORE_OW), Vector3.new(BX + W/2, BY + STORE_OH + (H - STORE_OH)/2 + 1, BZ), col.hull)
    -- West wall
    part(Vector3.new(WT, H, D), Vector3.new(BX - W/2, BY + H/2 + 1, BZ), GLASS_COL, GLASS_MAT, true, GLASS_T)

    -- Corner pillars + roof spires
    local ceilTop = H + 4
    local intH    = ceilTop - 1
    for _, xz in ipairs({{-W/2,-D/2},{W/2,-D/2},{-W/2,D/2},{W/2,D/2}}) do
        part(Vector3.new(4, intH, 4),
            Vector3.new(BX + xz[1], BY + intH/2 + 1, BZ + xz[2]), col.panel)
        local spireH = 24
        part(Vector3.new(3.2, spireH, 3.2),
            Vector3.new(BX + xz[1], BY + ceilTop + spireH/2, BZ + xz[2]), col.panel)
        local tip = part(Vector3.new(1.5, 0.6, 1.5),
            Vector3.new(BX + xz[1], BY + ceilTop + spireH + 0.3, BZ + xz[2]),
            col.neon, Enum.Material.Neon, false)
        addLight(tip, col.neon, 1.5, 22)
    end

    -- Door frame neon
    local dh = H - 2
    local dn = part(Vector3.new(DW + 0.5, 0.3, 0.3),
        Vector3.new(BX, BY + dh + 1, BZ - D/2), col.neon, Enum.Material.Neon, false)
    addLight(dn, col.neon, 1, 14)
    local ds = part(Vector3.new(DW + 0.5, 0.3, 0.3),
        Vector3.new(BX, BY + dh + 1, BZ + D/2), col.neon, Enum.Material.Neon, false)
    addLight(ds, col.neon, 1, 14)

    -- Interior ceiling neon strips
    for _, zo in ipairs({ -D*0.4, -D*0.15, 0, D*0.15, D*0.4 }) do
        local strip = part(Vector3.new(W - 8, 0.3, 0.6),
            Vector3.new(BX, BY + H + 0.3, BZ + zo), col.neon, Enum.Material.Neon, false)
        addLight(strip, col.neon, 2.5, 45)
    end

    -- Wall sconces
    for _, zo in ipairs({ -D/3, 0, D/3 }) do
        local se = part(Vector3.new(0.3, 0.8, 1.8),
            Vector3.new(BX + W/2 - 0.3, BY + H * 0.5, BZ + zo), col.neon, Enum.Material.Neon, false)
        addLight(se, col.neon, 2, 30)
        local sw = part(Vector3.new(0.3, 0.8, 1.8),
            Vector3.new(BX - W/2 + 0.3, BY + H * 0.5, BZ + zo), col.neon, Enum.Material.Neon, false)
        addLight(sw, col.neon, 2, 30)
    end

    -- Roof neon trim
    local rn2 = part(Vector3.new(W + 2, 0.25, 0.25),
        Vector3.new(BX, BY + H + 1.6, BZ - D/2), col.neon, Enum.Material.Neon, false)
    addLight(rn2, col.neon, 0.8, 22)
    local rs2 = part(Vector3.new(W + 2, 0.25, 0.25),
        Vector3.new(BX, BY + H + 1.6, BZ + D/2), col.neon, Enum.Material.Neon, false)
    addLight(rs2, col.neon, 0.8, 22)
    part(Vector3.new(0.25, 0.25, D + 2),
        Vector3.new(BX + W/2, BY + H + 1.6, BZ), col.neon, Enum.Material.Neon, false)
    part(Vector3.new(0.25, 0.25, D + 2),
        Vector3.new(BX - W/2, BY + H + 1.6, BZ), col.neon, Enum.Material.Neon, false)

    print("[WorldGen] Base built")
end

-- ── Hangar ────────────────────────────────────────────────────────────────────

function WorldGen.buildHangar()
    local bp  = Config.BASE_POSITION
    local W   = Config.BASE_WIDTH
    local D   = Config.BASE_DEPTH
    local H   = Config.BASE_HEIGHT
    local DW  = Config.BASE_DOOR_WIDTH
    local col = Config.BASE_COLORS

    local BX, BY, BZ = bp.X, GROUND_Y, bp.Z
    local northZ = BZ - D/2

    local HW  = 100
    local HD  = 55
    local HH  = H + 14
    local WT  = 2.5
    local bayW = 70
    local bayH = 30
    local conW = 20

    local cx = BX
    local cz = northZ - HD/2
    local fy = BY

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

    -- Foundation
    hp(Vector3.new(HW + 4, 4, HD + 4), cx, fy - 2, cz, col.foundation or col.hull)
    -- Floor
    hp(Vector3.new(HW, 3, HD), cx, fy+1.5, cz, col.panel)
    -- Ceiling
    hp(Vector3.new(HW+WT*2, 5, HD+WT*2), cx, fy+HH+2.5, cz, col.hull)

    -- South wall
    local cs = (HW - conW)/2
    hp(Vector3.new(cs, HH, WT), cx - HW/2 + cs/2, fy+HH/2+3, northZ, col.hull)
    hp(Vector3.new(cs, HH, WT), cx + HW/2 - cs/2, fy+HH/2+3, northZ, col.hull)
    hp(Vector3.new(conW, HH-H+2, WT), cx, fy+H+(HH-H+2)/2+1, northZ, col.hull)

    -- North face (bay opening)
    local bs = (HW - bayW)/2
    hp(Vector3.new(bs, HH, WT),        cx - HW/2 + bs/2, fy+HH/2+3, northZ-HD, col.hull)
    hp(Vector3.new(bs, HH, WT),        cx + HW/2 - bs/2, fy+HH/2+3, northZ-HD, col.hull)
    hp(Vector3.new(bayW, HH-bayH, WT), cx, fy+bayH+(HH-bayH)/2+3, northZ-HD, col.hull)

    -- Side walls
    hp(Vector3.new(WT, HH, HD), cx+HW/2, fy+HH/2+3, cz, col.hull)
    hp(Vector3.new(WT, HH, HD), cx-HW/2, fy+HH/2+3, cz, col.hull)

    -- Corner pillars
    for _, xz in ipairs({{-HW/2,-HD/2},{HW/2,-HD/2},{-HW/2,HD/2},{HW/2,HD/2}}) do
        hp(Vector3.new(5, HH+6, 5), cx+xz[1], fy+HH/2+4, northZ+xz[2], col.panel)
    end

    -- Ceiling neon strips
    local s1 = hp(Vector3.new(HW-12, 0.3, 0.7), cx, fy+HH+0.5, cz-HD/4, col.neon, Enum.Material.Neon, 0, false)
    addLight(s1, col.neon, 4, 60)
    local s2 = hp(Vector3.new(HW-12, 0.3, 0.7), cx, fy+HH+0.5, cz+HD/4, col.neon, Enum.Material.Neon, 0, false)
    addLight(s2, col.neon, 4, 60)

    -- Floor guide lines
    hp(Vector3.new(0.4, 0.2, HD-4), cx-bayW/2+2, fy+3.1, cz, col.neon, Enum.Material.Neon, 0, false)
    hp(Vector3.new(0.4, 0.2, HD-4), cx+bayW/2-2, fy+3.1, cz, col.neon, Enum.Material.Neon, 0, false)

    -- Bay door neon frame
    local df = hp(Vector3.new(bayW+2, 0.5, 0.5), cx, fy+bayH+3.5, northZ-HD, col.neon, Enum.Material.Neon, 0, false)
    addLight(df, col.neon, 3, 28)

    -- Blast door
    local doorY_closed = fy + 3 + bayH/2
    local doorY_open   = fy + 3 + bayH + bayH/2 + 2
    local door = hp(Vector3.new(bayW, bayH, 1.2), cx, doorY_closed, northZ-HD, col.hull)
    door.Name = "BayDoor"
    for i = 0, 2 do
        local band = hp(Vector3.new(bayW-2, 0.4, 0.2),
            cx, doorY_closed - bayH/2 + (i+1)*(bayH/4), northZ-HD-0.7,
            col.neon, Enum.Material.Neon, 0, false)
        band.Name = "DoorBand"..i
        addLight(band, col.neon, 1.5, 18)
    end
    door:SetAttribute("ClosedY", doorY_closed)
    door:SetAttribute("OpenY",   doorY_open)

    -- Recall button
    local RED      = Color3.fromRGB(220, 30,  30)
    local HOUSING  = Color3.fromRGB(28,  28,  34)
    local RING_COL = Color3.fromRGB(60,  62,  72)
    local btnX     = cx + conW/2 + 6
    local wallZ    = northZ + WT
    local btnY     = fy + 9

    hp(Vector3.new(7, 9, 0.3), btnX, btnY, wallZ + 0.15, HOUSING, Enum.Material.Metal)
    local collar = Instance.new("Part")
    collar.Shape     = Enum.PartType.Cylinder
    collar.Size      = Vector3.new(0.6, 4.2, 4.2)
    collar.CFrame    = CFrame.new(btnX, btnY, wallZ + 0.6) * CFrame.Angles(0, math.rad(90), 0)
    collar.Anchored  = true; collar.CanCollide = false; collar.CastShadow = false
    collar.Color     = RING_COL; collar.Material = Enum.Material.Metal
    collar.Parent    = folder

    local btn = Instance.new("Part")
    btn.Name     = "RecallButton"
    btn.Shape    = Enum.PartType.Ball
    btn.Size     = Vector3.new(3.2, 3.2, 3.2)
    btn.Position = Vector3.new(btnX, btnY, wallZ + 1.1)
    btn.Anchored = true; btn.CanCollide = false; btn.CastShadow = false
    btn.Color    = RED; btn.Material = Enum.Material.Neon
    btn.Parent   = folder
    addLight(btn, RED, 4, 18)

    local signPlate = hp(Vector3.new(7, 2.2, 0.25), btnX, btnY + 5.8, wallZ + 0.15,
        Color3.fromRGB(10, 10, 14), Enum.Material.SmoothPlastic)
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 220, 0, 52); bb.StudsOffset = Vector3.new(0, 0, 0.5)
    bb.AlwaysOnTop = false; bb.MaxDistance = 40; bb.Parent = signPlate
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Text = "RECALL SHIP"; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 20
    lbl.TextColor3 = Color3.fromRGB(255,255,255)
    lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0); lbl.TextStrokeTransparency = 0.3
    lbl.Parent = bb

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Recall Ship"; prompt.ObjectText = "RECALL SHIP"
    prompt.KeyboardKeyCode = Enum.KeyCode.F; prompt.HoldDuration = 0.4
    prompt.RequiresLineOfSight = false; prompt.MaxActivationDistance = 16
    prompt.Parent = btn

    print("[WorldGen] Hangar built. Door closed Y=" .. doorY_closed .. " open Y=" .. doorY_open)
    return folder
end

-- ── Storage Room ──────────────────────────────────────────────────────────────

function WorldGen.buildStorageRoom()
    local bp  = Config.BASE_POSITION
    local W   = Config.BASE_WIDTH
    local D   = Config.BASE_DEPTH
    local H   = Config.BASE_HEIGHT
    local col = Config.BASE_COLORS

    local BX, BY, BZ = bp.X, GROUND_Y, bp.Z

    local RW  = 90
    local RD  = 120
    local RH  = H
    local WT  = 2
    local OW  = 20
    local OH  = 36

    local rx = BX + W/2 + RW/2
    local rz = BZ
    local ry = BY

    local WARM_NEON = col.neon

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

    -- Foundation, floor, ceiling, walls
    sp(Vector3.new(RW+4, 4, RD+4), rx, ry-2, rz, col.foundation or col.panel)
    sp(Vector3.new(RW, 3, RD), rx, ry+1.5, rz, col.panel)
    sp(Vector3.new(RW+WT*2, 5, RD+WT*2), rx, ry+RH+2.5, rz, col.hull)
    sp(Vector3.new(WT, RH, RD), BX+W/2+RW, ry+RH/2+1, rz, col.hull)
    sp(Vector3.new(RW+WT, RH, WT), rx-WT/2, ry+RH/2+1, rz-RD/2, col.hull)
    sp(Vector3.new(RW+WT, RH, WT), rx-WT/2, ry+RH/2+1, rz+RD/2, col.hull)

    -- Entrance neon frame
    local nf = sp(Vector3.new(OW+1, 0.35, 0.35), BX+W/2, ry+OH+1, rz, WARM_NEON, Enum.Material.Neon, 0, false)
    sl(nf, WARM_NEON, 2, 18)

    -- STORAGE sign
    local signPlate = sp(Vector3.new(20, 3.5, 0.3), BX+W/2+1, ry+OH+3.5, rz,
        Color3.fromRGB(12, 12, 18), Enum.Material.SmoothPlastic)
    do
        local bb2 = Instance.new("BillboardGui")
        bb2.Size = UDim2.new(0, 280, 0, 56); bb2.StudsOffset = Vector3.new(0, 0, 0.5)
        bb2.AlwaysOnTop = false; bb2.MaxDistance = 60; bb2.Parent = signPlate
        local lbl2 = Instance.new("TextLabel")
        lbl2.Size = UDim2.new(1,0,1,0); lbl2.BackgroundTransparency = 1
        lbl2.Text = "⬡  STORAGE  ⬡"; lbl2.Font = Enum.Font.GothamBold; lbl2.TextSize = 20
        lbl2.TextColor3 = Color3.fromRGB(255,235,150)
        lbl2.TextStrokeColor3 = Color3.fromRGB(0,0,0); lbl2.TextStrokeTransparency = 0.2
        lbl2.Parent = bb2
    end

    -- Ceiling light grid
    for _, lx in ipairs({ BX+W/2 + RW*0.28, BX+W/2 + RW*0.72 }) do
        for _, lz2 in ipairs({ rz - RD*0.3, rz, rz + RD*0.3 }) do
            local panel = sp(Vector3.new(14, 0.35, 0.7), lx, ry+RH+0.4, lz2, WARM_NEON, Enum.Material.Neon, 0, false)
            sl(panel, WARM_NEON, 2.5, 45)
        end
    end
    for _, lz2 in ipairs({ rz-RD/2+1, rz+RD/2-1 }) do
        local sconce = sp(Vector3.new(0.35, 1, 2), rx, ry+5, lz2, WARM_NEON, Enum.Material.Neon, 0, false)
        sl(sconce, WARM_NEON, 2, 28)
    end

    -- Corner pillars
    for _, xz in ipairs({ {BX+W/2, rz-RD/2}, {BX+W/2+RW, rz-RD/2}, {BX+W/2, rz+RD/2}, {BX+W/2+RW, rz+RD/2} }) do
        sp(Vector3.new(3, RH+4, 3), xz[1], ry+RH/2+3, xz[2], col.panel)
    end

    -- ── Resource bins — driven by Config.MATERIALS ────────────────────────────
    local BIN_W, BIN_D, BIN_H = 10, 10, 6
    local BIN_Y   = ry + 3 + BIN_H/2
    local BIN_TOP = ry + 3 + BIN_H

    -- Use first 9 materials from Config (fills the U-shape)
    local binPositions = {
        { x = rx - 28, z = rz - RD/2 + 9 },
        { x = rx,      z = rz - RD/2 + 9 },
        { x = rx + 28, z = rz - RD/2 + 9 },
        { x = BX+W/2+RW - 9, z = rz - 28 },
        { x = BX+W/2+RW - 9, z = rz      },
        { x = BX+W/2+RW - 9, z = rz + 28 },
        { x = rx + 28, z = rz + RD/2 - 9 },
        { x = rx,      z = rz + RD/2 - 9 },
        { x = rx - 28, z = rz + RD/2 - 9 },
    }

    for i = 1, math.min(#Config.MATERIALS, #binPositions) do
        local mat  = Config.MATERIALS[i]
        local bp2  = binPositions[i]

        local body = sp(Vector3.new(BIN_W, BIN_H, BIN_D), bp2.x, BIN_Y, bp2.z,
            Color3.fromRGB(24, 28, 40), Enum.Material.Metal)
        body.Name = "Bin_" .. mat.name
        body:SetAttribute("Count", 0)

        local top = sp(Vector3.new(BIN_W, 0.4, BIN_D), bp2.x, BIN_TOP + 0.2, bp2.z,
            mat.color, Enum.Material.Neon, 0.2, false)
        sl(top, mat.color, 1.5, 12)

        sp(Vector3.new(BIN_W+0.1, 0.5, 0.25), bp2.x, BIN_Y + BIN_H*0.3, bp2.z - BIN_D/2,
            mat.color, Enum.Material.Neon, 0.4, false)

        -- Ingot stack on top for metal-type materials
        if mat.element == "Earth" or mat.element == "Electric" or mat.element == "Fire" then
            for row = 0, 2 do
                local count = 3 - row
                for c = 0, count - 1 do
                    local ox = (c - (count-1)*0.5) * 2.2
                    sp(Vector3.new(1.8, 0.7, 3.2),
                        bp2.x + ox, BIN_TOP + 0.35 + row * 0.75, bp2.z,
                        mat.color, Enum.Material.Metal, 0, false)
                end
            end
        end

        -- Label
        local bb3 = Instance.new("BillboardGui")
        bb3.Size = UDim2.new(0, 140, 0, 50); bb3.StudsOffset = Vector3.new(0, BIN_H/2 + 3.5, 0)
        bb3.AlwaysOnTop = false; bb3.MaxDistance = 60; bb3.Parent = body

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1,0,0.55,0); nameLabel.BackgroundTransparency = 1
        nameLabel.Text = mat.name:upper(); nameLabel.Font = Enum.Font.GothamBold; nameLabel.TextSize = 14
        nameLabel.TextColor3 = Color3.fromRGB(255,255,255)
        nameLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0); nameLabel.TextStrokeTransparency = 0.15
        nameLabel.Parent = bb3

        local countLabel = Instance.new("TextLabel")
        countLabel.Name = "CountLabel"
        countLabel.Size = UDim2.new(1,0,0.45,0); countLabel.Position = UDim2.new(0,0,0.55,0)
        countLabel.BackgroundTransparency = 1
        countLabel.Text = "× 0"; countLabel.Font = Enum.Font.GothamBold; countLabel.TextSize = 13
        countLabel.TextColor3 = mat.color
        countLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0); countLabel.TextStrokeTransparency = 0.15
        countLabel.Parent = bb3
    end

    print("[WorldGen] Storage room built")
    return folder
end

-- ── Beacon tower ──────────────────────────────────────────────────────────────

function WorldGen.buildBeacon(x, z, neonColor)
    local DARK = Color3.fromRGB(32, 38, 58)
    local MID  = Color3.fromRGB(48, 56, 82)
    local y    = GROUND_Y

    part(Vector3.new(10, 2, 10),    Vector3.new(x, y + 1,  z), MID)
    part(Vector3.new(2.5, 78, 2.5), Vector3.new(x, y + 41, z), DARK)
    local ring = part(Vector3.new(5, 0.6, 5),
        Vector3.new(x, y + 40, z), neonColor, Enum.Material.Neon, false)
    addLight(ring, neonColor, 1.5, 30)
    local cap = part(Vector3.new(5, 1, 5),
        Vector3.new(x, y + 81, z), neonColor, Enum.Material.Neon, false)
    addLight(cap, neonColor, 4, 90)
    local beacon = part(Vector3.new(1.2, 1.2, 1.2),
        Vector3.new(x, y + 82.6, z), Color3.fromRGB(255, 50, 50), Enum.Material.Neon, false)
    addLight(beacon, Color3.fromRGB(255, 50, 50), 5, 100)
    task.spawn(function()
        while beacon.Parent do
            beacon.Transparency = 0; task.wait(0.7)
            beacon.Transparency = 0.9; task.wait(0.7)
        end
    end)
end

-- ── Debris Shield ─────────────────────────────────────────────────────────────

function WorldGen.buildDebrisShield()
    local bp  = Config.BASE_POSITION
    local col = Config.BASE_COLORS

    local R = 300
    local shield = Instance.new("Part")
    shield.Name      = "DebrisShield"
    shield.Shape     = Enum.PartType.Ball
    shield.Size      = Vector3.new(R * 2, R * 2, R * 2)
    shield.Position  = Vector3.new(bp.X, GROUND_Y + 120, bp.Z)
    shield.Anchored  = true
    shield.CanCollide = true
    shield.CastShadow = false
    shield.Color     = col.neon
    shield.Material  = Enum.Material.Neon
    shield.Transparency = 0.97
    pcall(function() shield.CollisionGroup = "DebrisShield" end)
    shield.Parent = workspace

    print("[WorldGen] Debris shield built. Radius=" .. R)
    return shield
end

-- ── Ground plane ──────────────────────────────────────────────────────────────
-- Simple flat ground while Terrain generation is not yet built.
-- Replace this with Terrain API calls once procedural gen is ready.

function WorldGen.buildGround()
    local W = Config.MAP_WIDTH
    local D = Config.MAP_DEPTH

    local ground = Instance.new("Part")
    ground.Name      = "Ground"
    ground.Size      = Vector3.new(W, 4, D)
    ground.Position  = Vector3.new(0, GROUND_Y - 2, 0)
    ground.Anchored  = true
    ground.CanCollide = true
    ground.CastShadow = false
    ground.Color     = Color3.fromRGB(148, 145, 158)
    ground.Material  = Enum.Material.Granite
    ground.Parent    = workspace

    print("[WorldGen] Ground plane built (" .. W .. "x" .. D .. ")")
    return ground
end

return WorldGen
