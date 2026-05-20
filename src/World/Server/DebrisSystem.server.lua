-- Script → ServerScriptService/DebrisSystem
-- Flat-map debris: chunks fall from above under workspace gravity,
-- snap to the ground plane, then shatter into collectible materials.
if not game:GetService("RunService"):IsServer() then return end

local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local PhysicsService    = game:GetService("PhysicsService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

-- Debris chunks don't collide with each other, only with the world
pcall(function()
    PhysicsService:RegisterCollisionGroup("Debris")
    PhysicsService:CollisionGroupSetCollidable("Debris", "Debris", false)
end)

local GROUND_Y = Config.MAP_GROUND_Y   -- 0

-- ── Remotes ───────────────────────────────────────────────────────────────────

local remotes              = ReplicatedStorage:WaitForChild("Remotes")
local hitDebrisEvent       = remotes:WaitForChild("HitDebris")
local collectFragmentEvent = remotes:WaitForChild("CollectFragment")
local registerCollectible  = remotes:WaitForChild("RegisterCollectible")
local serverHitDebris      = remotes:WaitForChild("ServerHitDebris")
local tachyitePickup       = remotes:WaitForChild("TachyitePickup")

-- ── Folders ───────────────────────────────────────────────────────────────────

local debrisFolder = Instance.new("Folder")
debrisFolder.Name   = "Debris"
debrisFolder.Parent = Workspace

-- ── Material weight table ─────────────────────────────────────────────────────
-- Built from Config.MATERIALS so debris drops the right stuff.

local _matTotal = 0
for _, m in ipairs(Config.MATERIALS) do _matTotal += m.weight end

local function pickMaterial()
    local r, cum = math.random() * _matTotal, 0
    for _, m in ipairs(Config.MATERIALS) do
        cum += m.weight
        if r <= cum then return m end
    end
    return Config.MATERIALS[1]
end

-- ── Debris visual lookup ──────────────────────────────────────────────────────

local DEBRIS_COLORS = {
    Color3.fromRGB(180, 100,  35),
    Color3.fromRGB(130, 110,  85),
    Color3.fromRGB(160,  55,  45),
    Color3.fromRGB(100,  80, 200),
    Color3.fromRGB( 50, 160, 110),
    Color3.fromRGB(190, 160,  40),
}

local DEBRIS_MATERIALS = {
    Enum.Material.Rock,
    Enum.Material.SmoothPlastic,
    Enum.Material.Metal,
    Enum.Material.Rock,
}

local CHUNK_SHAPES = {
    { shape = Enum.PartType.Block,       weight = 30 },
    { shape = Enum.PartType.Wedge,       weight = 25 },
    { shape = Enum.PartType.CornerWedge, weight = 20 },
    { shape = Enum.PartType.Cylinder,    weight = 15 },
    { shape = Enum.PartType.Ball,        weight = 10 },
}
local _shapeTotal = 0
for _, s in ipairs(CHUNK_SHAPES) do _shapeTotal += s.weight end

local function pickShape()
    local r, cum = math.random() * _shapeTotal, 0
    for _, s in ipairs(CHUNK_SHAPES) do
        cum += s.weight
        if r <= cum then return s.shape end
    end
    return Enum.PartType.Block
end

local function pick(t) return t[math.random(1, #t)] end

-- ── Collectible spin loop ─────────────────────────────────────────────────────

local spinParts = {}  -- { part, beam, halo, anchor, baseCF, angle }

RunService.Heartbeat:Connect(function(dt)
    for i = #spinParts, 1, -1 do
        local s = spinParts[i]
        if not (s.part and s.part.Parent) then
            if s.beam   and s.beam.Parent   then s.beam:Destroy()   end
            if s.halo   and s.halo.Parent   then s.halo:Destroy()   end
            if s.anchor and s.anchor.Parent then s.anchor:Destroy() end
            table.remove(spinParts, i)
        else
            s.angle = s.angle + dt * Config.COLLECTIBLE_ROTATION_SPEED
            s.part.CFrame = s.baseCF * CFrame.Angles(0, s.angle, 0)
        end
    end
end)

-- ── Collectible spawner ───────────────────────────────────────────────────────

local activeCollectibles = {}  -- { part, matName, qty }

local function spawnCollectible(position, mat)
    -- mat is a Config.MATERIALS entry {name, color, rarity, element, ...}
    local color = mat.color

    -- Collectible shape: use material rarity to hint the visual
    local shape = Enum.PartType.Block
    local size  = Vector3.new(2.4, 0.8, 1.4)
    local trans = 0
    if mat.rarity == "Rare" or mat.rarity == "Exotic" then
        shape = Enum.PartType.Wedge
        size  = Vector3.new(0.9, 3.0, 0.8)
        trans = 0.1
    elseif mat.rarity == "Uncommon" then
        shape = Enum.PartType.Wedge
        size  = Vector3.new(2.0, 1.6, 1.4)
    end
    local scale = 0.75 + math.random() * 0.5

    -- Scatter in XZ around the death point, snap to ground plane
    local scatter = Vector3.new(
        position.X + math.random(-6, 6),
        GROUND_Y,
        position.Z + math.random(-6, 6)
    )

    local part        = Instance.new("Part")
    part.Name         = mat.name
    part.Shape        = shape
    part.Size         = size * scale
    part.Color        = color
    part.Material     = (mat.rarity == "Exotic") and Enum.Material.Neon or Enum.Material.SmoothPlastic
    part.Transparency = trans
    part.Anchored     = true
    part.CanCollide   = false
    part.CanQuery     = false
    part.CastShadow   = false

    local baseCF  = CFrame.new(scatter)
    part.CFrame   = baseCF
    part.Parent   = debrisFolder

    part:SetAttribute("IsFragment",   true)
    part:SetAttribute("MaterialName", mat.name)

    -- ── Beacon ────────────────────────────────────────────────────────────────
    local BEACON_H = Config.COLLECTIBLE_BEACON_HEIGHT

    local anchor      = Instance.new("Part")
    anchor.Size        = Vector3.new(0.1, 0.1, 0.1)
    anchor.CFrame      = CFrame.new(scatter + Vector3.new(0, BEACON_H, 0))
    anchor.Anchored    = true
    anchor.CanCollide  = false
    anchor.CanQuery    = false
    anchor.Transparency = 1
    anchor.CastShadow  = false
    anchor.Parent      = debrisFolder

    local att0 = Instance.new("Attachment"); att0.Parent = part
    local att1 = Instance.new("Attachment"); att1.Parent = anchor

    local beam = Instance.new("Beam")
    beam.Attachment0 = att0; beam.Attachment1 = att1
    beam.Width0 = 0.5;  beam.Width1 = 10
    beam.LightEmission = 1; beam.LightInfluence = 0
    beam.FaceCamera = true; beam.Segments = 1
    beam.CurveSize0 = 0;  beam.CurveSize1 = 0
    beam.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   color),
        ColorSequenceKeypoint.new(0.6, color),
        ColorSequenceKeypoint.new(1,   Color3.new(1, 1, 1)),
    })
    beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.2),
        NumberSequenceKeypoint.new(0.5, 0.55),
        NumberSequenceKeypoint.new(1,   1),
    })
    beam.Parent = Workspace

    local halo = Instance.new("Beam")
    halo.Attachment0 = att0; halo.Attachment1 = att1
    halo.Width0 = 3;  halo.Width1 = 28
    halo.LightEmission = 1; halo.LightInfluence = 0
    halo.FaceCamera = true; halo.Segments = 1
    halo.CurveSize0 = 0;  halo.CurveSize1 = 0
    halo.Color = ColorSequence.new(color)
    halo.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,    0.65),
        NumberSequenceKeypoint.new(0.35, 0.82),
        NumberSequenceKeypoint.new(1,    1),
    })
    halo.Parent = Workspace

    -- Particles
    local pAtt = Instance.new("Attachment"); pAtt.Parent = part

    local sparkles = Instance.new("ParticleEmitter")
    sparkles.Texture        = "rbxasset://textures/particles/sparkles_main.dds"
    sparkles.Color          = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(0.3, color),
        ColorSequenceKeypoint.new(1,   Color3.new(1, 1, 1)),
    })
    sparkles.LightEmission  = 1; sparkles.LightInfluence = 0
    sparkles.Size           = NumberSequence.new({
        NumberSequenceKeypoint.new(0,    0),
        NumberSequenceKeypoint.new(0.12, 0.6),
        NumberSequenceKeypoint.new(0.8,  0.3),
        NumberSequenceKeypoint.new(1,    0),
    })
    sparkles.Transparency   = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.6, 0.3),
        NumberSequenceKeypoint.new(1,   1),
    })
    sparkles.Speed          = NumberRange.new(14, 32)
    sparkles.Lifetime       = NumberRange.new(2, 4.5)
    sparkles.Rate           = 60
    sparkles.SpreadAngle    = Vector2.new(5, 5)
    sparkles.EmissionDirection = Enum.NormalId.Top
    sparkles.Parent         = pAtt

    local wisps = Instance.new("ParticleEmitter")
    wisps.Texture        = "rbxasset://textures/particles/smoke_main.dds"
    wisps.Color          = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   color),
        ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(1,   color),
    })
    wisps.LightEmission  = 0.9; wisps.LightInfluence = 0.1
    wisps.Size           = NumberSequence.new({
        NumberSequenceKeypoint.new(0,    0),
        NumberSequenceKeypoint.new(0.25, 1.8),
        NumberSequenceKeypoint.new(1,    0),
    })
    wisps.Transparency   = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.3),
        NumberSequenceKeypoint.new(0.5, 0.55),
        NumberSequenceKeypoint.new(1,   1),
    })
    wisps.Speed          = NumberRange.new(3, 9)
    wisps.Lifetime       = NumberRange.new(5, 10)
    wisps.Rate           = 14
    wisps.SpreadAngle    = Vector2.new(12, 12)
    wisps.EmissionDirection = Enum.NormalId.Top
    wisps.Parent         = pAtt

    local spot = Instance.new("SpotLight")
    spot.Face = Enum.NormalId.Top; spot.Color = color
    spot.Brightness = 4; spot.Range = 70; spot.Angle = 44
    spot.Parent = part

    local glow = Instance.new("PointLight")
    glow.Color = color; glow.Brightness = 4; glow.Range = 22
    glow.Parent = part

    local aura = Instance.new("PointLight")
    aura.Color = color; aura.Brightness = 1; aura.Range = 50
    aura.Parent = part

    table.insert(spinParts, {
        part = part, beam = beam, halo = halo, anchor = anchor,
        baseCF = baseCF, angle = math.random() * math.pi * 2
    })

    -- Weighted quantity
    local CARGO_QUANTITIES = {
        { qty = 1,  weight = 55 }, { qty = 2,  weight = 28 },
        { qty = 4,  weight = 12 }, { qty = 8,  weight = 4  },
        { qty = 16, weight = 1  },
    }
    local qTotal, qCum = 0, 0
    for _, e in ipairs(CARGO_QUANTITIES) do qTotal += e.weight end
    local qr = math.random() * qTotal
    local qty = 1
    for _, e in ipairs(CARGO_QUANTITIES) do
        qCum += e.weight
        if qr <= qCum then qty = e.qty; break end
    end

    local entry = { part = part, matName = mat.name, qty = qty }
    table.insert(activeCollectibles, entry)
    registerCollectible:Fire(part, "Fragment", mat.name)

    -- Spawn flash
    part.Transparency = 1
    local spawnLight = Instance.new("PointLight")
    spawnLight.Color = color; spawnLight.Brightness = 8; spawnLight.Range = 30
    spawnLight.Parent = part
    TweenService:Create(part,       TweenInfo.new(0.15), {Transparency = trans}):Play()
    TweenService:Create(spawnLight, TweenInfo.new(0.5),  {Brightness = 0}):Play()
    task.delay(0.5, function()
        if spawnLight and spawnLight.Parent then spawnLight:Destroy() end
    end)

    -- Auto-despawn
    task.delay(Config.COLLECTIBLE_LIFETIME, function()
        for i, e in ipairs(activeCollectibles) do
            if e.part == part then table.remove(activeCollectibles, i); break end
        end
        if not (part and part.Parent) then return end
        TweenService:Create(part, TweenInfo.new(2), {Transparency = 1}):Play()
        task.delay(2, function()
            if part   and part.Parent   then part:Destroy()   end
            if anchor and anchor.Parent then anchor:Destroy() end
            if beam   and beam.Parent   then beam:Destroy()   end
            if halo   and halo.Parent   then halo:Destroy()   end
        end)
    end)
end

-- ── Visual-only shard ─────────────────────────────────────────────────────────

local function spawnShard(center)
    local sz     = 0.4 + math.random() * 1.2
    local offset = Vector3.new(math.random(-3, 3), math.random(0, 4), math.random(-3, 3))
    local p = Instance.new("Part")
    p.Name       = "Shard"
    p.Size       = Vector3.new(sz, sz, sz)
    p.CFrame     = CFrame.new(center + offset)
                 * CFrame.Angles(
                       math.random() * math.pi * 2,
                       math.random() * math.pi * 2,
                       math.random() * math.pi * 2)
    p.Color      = pick(DEBRIS_COLORS)
    p.Material   = Enum.Material.Rock
    p.Anchored   = false
    p.CanCollide = false
    p.CanQuery   = false
    p.CastShadow = false
    p.Parent     = debrisFolder

    local outDir = offset.Magnitude > 0.1 and offset.Unit
        or Vector3.new(math.random()-0.5, math.random()*0.5+0.5, math.random()-0.5).Unit
    local speed = 25 + math.random() * 55
    p:ApplyImpulse(outDir * speed * p:GetMass())

    TweenService:Create(p, TweenInfo.new(1, Enum.EasingStyle.Linear), {Transparency = 1}):Play()
    task.delay(1, function()
        if p and p.Parent then p:Destroy() end
    end)
end

-- ── Impact dust ring ──────────────────────────────────────────────────────────

local function spawnImpactDust(pos, chunkColor, chunkSize)
    for i = 1, 8 do
        local a   = (i / 8) * math.pi * 2
        local dir = Vector3.new(math.cos(a), 0.3, math.sin(a)).Unit
        local rock = Instance.new("Part")
        rock.Size       = Vector3.new(0.5, 0.5, 0.5)
        rock.CFrame     = CFrame.new(pos)
        rock.Color      = chunkColor
        rock.Material   = Enum.Material.Rock
        rock.Anchored   = false
        rock.CanCollide = false
        rock.CanQuery   = false
        rock.CastShadow = false
        rock.Parent     = debrisFolder
        rock:ApplyImpulse(dir * (18 + math.random() * 14) * rock:GetMass())
        TweenService:Create(rock, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {Transparency = 1}):Play()
        task.delay(0.7, function() if rock and rock.Parent then rock:Destroy() end end)
    end

    local flash = Instance.new("Part")
    flash.Size        = Vector3.new(0.1, 0.1, 0.1)
    flash.CFrame      = CFrame.new(pos)
    flash.Anchored    = true
    flash.CanCollide  = false
    flash.Transparency = 1
    flash.Parent      = debrisFolder
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 180, 80); light.Brightness = 12; light.Range = chunkSize * 4
    light.Parent = flash
    TweenService:Create(light, TweenInfo.new(0.4), {Brightness = 0}):Play()
    task.delay(0.4, function() if flash and flash.Parent then flash:Destroy() end end)
end

-- ── Chunk builder ─────────────────────────────────────────────────────────────

local function makeChunk(pos, size, color, health, mat)
    local chunk = Instance.new("Part")
    chunk.Name     = "DebrisChunk"
    chunk.Shape    = pickShape()
    chunk.Size     = Vector3.new(
        size * (0.6 + math.random() * 0.9),
        size * (0.5 + math.random() * 0.8),
        size * (0.6 + math.random() * 0.9)
    )
    chunk.CFrame   = CFrame.new(pos) * CFrame.Angles(
        math.random() * math.pi * 2,
        math.random() * math.pi * 2,
        math.random() * math.pi * 2
    )
    chunk.Color    = color
    chunk.Material = pick(DEBRIS_MATERIALS)
    chunk.CustomPhysicalProperties = PhysicalProperties.new(1, 2, 0, 1, 1)
    chunk.CanCollide = true
    pcall(function() chunk.CollisionGroup = "Debris" end)
    chunk.Parent   = debrisFolder

    chunk:SetAttribute("IsDebris",     true)
    chunk:SetAttribute("Health",       health)
    chunk:SetAttribute("MaterialName", mat.name)

    return chunk
end

-- ── Debris spawner ────────────────────────────────────────────────────────────

local HALF_W = Config.MAP_WIDTH  / 2
local HALF_D = Config.MAP_DEPTH  / 2

local BASE_SAFE_RADIUS = 300  -- studs around origin — no debris spawns here

local function spawnDebris()
    -- Random position within the map bounds, avoiding the base safe zone
    local x, z
    repeat
        x = math.random(-HALF_W, HALF_W)
        z = math.random(-HALF_D, HALF_D)
    until math.sqrt(x*x + z*z) >= BASE_SAFE_RADIUS

    local spawnPos = Vector3.new(x, Config.DEBRIS_SPAWN_HEIGHT, z)

    local s   = math.random(13, 21)
    local mat = pickMaterial()
    local chunk = makeChunk(spawnPos, s, mat.color, Config.DEBRIS_HEALTH, mat)

    -- Aim toward the base with some spread so it's not perfectly accurate
    local toBase    = Vector3.new(-x, 0, -z)
    local dist      = toBase.Magnitude
    local baseDir   = dist > 0 and toBase.Unit or Vector3.new(0, 0, 1)
    -- Random spread: deflect up to 25° off the base direction
    local spread    = math.rad(25)
    local angle     = (math.random() * 2 - 1) * spread
    local cosA, sinA = math.cos(angle), math.sin(angle)
    local aimDir    = Vector3.new(
        baseDir.X * cosA - baseDir.Z * sinA,
        0,
        baseDir.X * sinA + baseDir.Z * cosA
    )
    local hSpeed    = Config.DEBRIS_SPEED + math.random() * 20
    local dnSpeed   = 30 + math.random() * 30
    chunk:ApplyImpulse((aimDir * hSpeed + Vector3.new(0, -dnSpeed, 0)) * chunk:GetMass())

    -- Force-snap fallback after Config.DEBRIS_SURFACE_SNAP_DELAY seconds
    task.delay(Config.DEBRIS_SURFACE_SNAP_DELAY, function()
        if not (chunk and chunk.Parent) or chunk.Anchored then return end
        chunk.AssemblyLinearVelocity  = Vector3.zero
        chunk.AssemblyAngularVelocity = Vector3.zero
        chunk.CFrame = CFrame.new(chunk.Position.X, GROUND_Y + chunk.Size.Y * 0.35, chunk.Position.Z)
                     * (chunk.CFrame - chunk.CFrame.Position)
        chunk.Anchored = true
    end)

    task.delay(Config.DEBRIS_LIFETIME, function()
        if chunk and chunk.Parent then chunk:Destroy() end
    end)
end

local spawnTachyite  -- forward declaration; defined in the Tachyite section below

-- ── Damage / death ────────────────────────────────────────────────────────────

local function applyDamage(chunk, damage)
    if not chunk or not chunk.Parent then return end
    if not chunk:GetAttribute("IsDebris") then return end

    local hp   = (chunk:GetAttribute("Health") or 0) - damage
    local orig = chunk.Color
    chunk.Color = Color3.new(1, 1, 1)
    task.delay(Config.DAMAGE_FLASH_DURATION, function()
        if chunk and chunk.Parent then chunk.Color = orig end
    end)

    if hp <= 0 then
        local pos     = chunk.Position
        local matName = chunk:GetAttribute("MaterialName")
        -- Look up the material entry by name (fallback to random)
        local mat
        for _, m in ipairs(Config.MATERIALS) do
            if m.name == matName then mat = m; break end
        end
        mat = mat or pickMaterial()
        chunk:Destroy()

        for _ = 1, Config.DEBRIS_DEATH_PIECES do
            if math.random() < Config.DEBRIS_CARGO_CHANCE then
                task.spawn(spawnCollectible, pos, mat)
            else
                task.spawn(spawnShard, pos)
            end
        end
        if math.random() < Config.TACHYITE_DROP_CHANCE then
            task.spawn(spawnTachyite, pos)
        end
    else
        chunk:SetAttribute("Health", hp)
    end
end

-- ── Hit events ────────────────────────────────────────────────────────────────

local recentlyHit = {}

hitDebrisEvent.OnServerEvent:Connect(function(_player, chunk, damage)
    if not chunk or not chunk.Parent then return end
    if not chunk:GetAttribute("IsDebris") then return end
    if recentlyHit[chunk] then return end
    recentlyHit[chunk] = true
    task.delay(Config.DEBRIS_HIT_COOLDOWN, function() recentlyHit[chunk] = nil end)
    applyDamage(chunk, damage or Config.LASER_DAMAGE)
end)

serverHitDebris.Event:Connect(function(chunk, damage)
    applyDamage(chunk, damage)
end)

-- ── Ground-snap Heartbeat ─────────────────────────────────────────────────────
-- Workspace gravity pulls chunks down; we just detect landing and anchor.

RunService.Heartbeat:Connect(function()
    for _, chunk in ipairs(debrisFolder:GetChildren()) do
        if chunk:IsA("BasePart") and not chunk.Anchored and chunk:GetAttribute("IsDebris") then
            local halfH = chunk.Size.Y * 0.5
            if chunk.Position.Y <= GROUND_Y + halfH then
                chunk.AssemblyLinearVelocity  = Vector3.zero
                chunk.AssemblyAngularVelocity = Vector3.zero
                local snapY = GROUND_Y + halfH * 0.35   -- slightly embedded
                chunk.CFrame = CFrame.new(chunk.Position.X, snapY, chunk.Position.Z)
                             * (chunk.CFrame - chunk.CFrame.Position)
                task.spawn(spawnImpactDust, chunk.Position, chunk.Color, chunk.Size.X)
                chunk.Anchored = true
            end
        end
    end
end)

-- ── Proximity + magnet collection ────────────────────────────────────────────

local FRAG_MAGNET_SPEED   = 28    -- base studs/sec (reads Config.ORE_MAGNET_RADIUS / ORE_COLLECT_RADIUS live)

-- ── Tachyite orbs ─────────────────────────────────────────────────────────────

local activeTachyites = {}   -- { part, magnetized, magnetConn }

local TACHYITE_COLOR  = Color3.fromRGB(60, 130, 255)
local TACHYITE_RADIUS = 1.6

spawnTachyite = function(origin)
    local orb      = Instance.new("Part")
    orb.Shape      = Enum.PartType.Ball
    orb.Size       = Vector3.new(TACHYITE_RADIUS*2, TACHYITE_RADIUS*2, TACHYITE_RADIUS*2)
    orb.Color      = TACHYITE_COLOR
    orb.Material   = Enum.Material.Neon
    orb.CanCollide = false
    orb.CastShadow = false
    orb.Anchored   = false
    orb.Position   = origin + Vector3.new(
        math.random(-4, 4), math.random(2, 6), math.random(-4, 4))
    orb.Parent     = Workspace

    local light     = Instance.new("PointLight")
    light.Color     = TACHYITE_COLOR
    light.Brightness = 3
    light.Range     = 20
    light.Parent    = orb

    -- gentle float: give a tiny upward nudge so it bobs
    orb.AssemblyLinearVelocity = Vector3.new(0, 6, 0)

    local entry = { part = orb, magnetized = false, magnetConn = nil }
    table.insert(activeTachyites, entry)

    -- auto-despawn after collectible lifetime
    task.delay(Config.COLLECTIBLE_LIFETIME, function()
        if orb and orb.Parent then
            orb:Destroy()
        end
    end)
end

local function collectFragment(entry, plr, i)
    local p       = entry.part
    local worldPos = p.Position
    if entry.magnetConn then entry.magnetConn:Disconnect() end
    table.remove(activeCollectibles, i)
    p:Destroy()
    if _G.PlayerData then
        _G.PlayerData.addMaterial(plr, entry.matName, entry.qty)
        _G.PlayerData.addXP(plr, entry.qty * 5)
    end
    collectFragmentEvent:FireClient(plr, entry.matName, entry.qty, worldPos)
end

task.spawn(function()
    while true do
        task.wait(0.15)
        for i = #activeCollectibles, 1, -1 do
            local entry = activeCollectibles[i]
            local p     = entry.part
            if not (p and p.Parent) then
                table.remove(activeCollectibles, i)
                continue
            end
            for _, plr in ipairs(Players:GetPlayers()) do
                local char = plr.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end
                local dist = (hrp.Position - p.Position).Magnitude
                if dist <= Config.ORE_COLLECT_RADIUS then
                    collectFragment(entry, plr, i)
                    break
                elseif dist <= Config.ORE_MAGNET_RADIUS and not entry.magnetized then
                    entry.magnetized = true
                    -- Remove from spin table so it stops fighting the magnet movement
                    for si = #spinParts, 1, -1 do
                        if spinParts[si].part == p then
                            table.remove(spinParts, si)
                            break
                        end
                    end
                    local targetPlr  = plr
                    entry.magnetConn = RunService.Heartbeat:Connect(function(dt)
                        if not (p and p.Parent) then return end
                        local targetHrp = targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart")
                        if not targetHrp then return end
                        local toPlayer = targetHrp.Position - p.Position
                        local d        = toPlayer.Magnitude
                        local speed    = FRAG_MAGNET_SPEED * (1 + (Config.ORE_MAGNET_RADIUS - d) / Config.ORE_MAGNET_RADIUS * 3)
                        local step     = math.min(d, speed * dt)
                        p.CFrame       = CFrame.new(p.Position + toPlayer.Unit * step)
                    end)
                end
            end
        end
    end
end)

-- ── Tachyite proximity + magnet ──────────────────────────────────────────────
-- Per-player stack counts tracked server-side for the FireClient call.

local playerTachyiteStacks = {}   -- [Player] = number

task.spawn(function()
    while true do
        task.wait(0.15)
        for i = #activeTachyites, 1, -1 do
            local entry = activeTachyites[i]
            local p     = entry.part
            if not (p and p.Parent) then
                table.remove(activeTachyites, i)
                continue
            end
            for _, plr in ipairs(Players:GetPlayers()) do
                local char = plr.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end
                local dist = (hrp.Position - p.Position).Magnitude
                if dist <= Config.ORE_COLLECT_RADIUS then
                    -- Collect
                    if entry.magnetConn then entry.magnetConn:Disconnect() end
                    table.remove(activeTachyites, i)
                    p:Destroy()
                    playerTachyiteStacks[plr] = (playerTachyiteStacks[plr] or 0) + 1
                    tachyitePickup:FireClient(plr, playerTachyiteStacks[plr])
                    break
                elseif dist <= Config.ORE_MAGNET_RADIUS and not entry.magnetized then
                    entry.magnetized = true
                    local targetPlr  = plr
                    entry.magnetConn = RunService.Heartbeat:Connect(function(dt)
                        if not (p and p.Parent) then return end
                        local tHrp = targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart")
                        if not tHrp then return end
                        local toPlayer = tHrp.Position - p.Position
                        local d        = toPlayer.Magnitude
                        local speed    = FRAG_MAGNET_SPEED * (1 + (Config.ORE_MAGNET_RADIUS - d) / Config.ORE_MAGNET_RADIUS * 3)
                        local step     = math.min(d, speed * dt)
                        p.CFrame       = CFrame.new(p.Position + toPlayer.Unit * step)
                    end)
                end
            end
        end
    end
end)

-- Reset stack count when player leaves (so rejoining doesn't carry ghosts)
Players.PlayerRemoving:Connect(function(plr)
    playerTachyiteStacks[plr] = nil
end)

-- ── Spawn loop ────────────────────────────────────────────────────────────────

for _ = 1, Config.DEBRIS_INITIAL_BURST do
    task.spawn(spawnDebris)
end

task.spawn(function()
    while true do
        task.wait(Config.DEBRIS_SPAWN_INTERVAL)
        for _ = 1, Config.DEBRIS_SPAWN_PER_WAVE do
            task.spawn(spawnDebris)
        end
    end
end)

print("[GameSetup] Debris system active")
