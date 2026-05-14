-- Script → place in ServerScriptService, rename to "DebrisSystem"
if not game:GetService("RunService"):IsServer() then return end
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local PhysicsService    = game:GetService("PhysicsService")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

-- Debris chunks collide with the planet but not with each other
pcall(function()
    PhysicsService:RegisterCollisionGroup("Debris")
    PhysicsService:CollisionGroupSetCollidable("Debris", "Debris", false)
end)

local PLANET_CENTER = Config.PLANET_CENTER
local PLANET_RADIUS = Config.PLANET_RADIUS

-- ── Remotes (created by Core/Remotes.server.lua) ─────────────────────────────

local remotes              = ReplicatedStorage:WaitForChild("Remotes")
local hitDebrisEvent       = remotes:WaitForChild("HitDebris")
local collectFragmentEvent = remotes:WaitForChild("CollectFragment")
local collectMetalEvent    = remotes:WaitForChild("CollectMetal")
local registerCollectible  = remotes:WaitForChild("RegisterCollectible")
local serverHitDebris      = remotes:WaitForChild("ServerHitDebris")

-- ── Folders ───────────────────────────────────────────────────────────────────

local debrisFolder = Instance.new("Folder")
debrisFolder.Name   = "Debris"
debrisFolder.Parent = Workspace


-- ── Lookup tables ────────────────────────────────────────────────────────────

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

-- Per-type collectible shape, colour, and material
local COLLECTIBLE = {
    Rock = {
        shape    = Enum.PartType.Wedge,
        size     = Vector3.new(2.0, 1.6, 1.4),
        color    = Color3.fromRGB(118, 92, 62),
        material = Enum.Material.Rock,
        trans    = 0,
    },
    Metal = {
        shape    = Enum.PartType.Block,
        size     = Vector3.new(3.2, 0.6, 1.2),
        color    = Color3.fromRGB(162, 168, 178),
        material = Enum.Material.Metal,
        trans    = 0,
    },
    Crystal = {
        shape    = Enum.PartType.Wedge,
        size     = Vector3.new(0.8, 3.2, 0.7),
        color    = Color3.fromRGB(145, 75, 255),
        material = Enum.Material.SmoothPlastic,
        trans    = 0.1,
    },
    Ice = {
        shape    = Enum.PartType.Block,
        size     = Vector3.new(1.8, 1.8, 1.8),
        color    = Color3.fromRGB(185, 225, 255),
        material = Enum.Material.Glass,
        trans    = 0.3,
    },
}

local DEATH_PIECES   = 27
local CARGO_CHANCE   = 0.10   -- fraction of pieces that become collectible cargo
local COLLECT_RADIUS = 20     -- studs — proximity to auto-collect cargo

-- Weighted quantity table: {qty, weight}. Higher weight = more likely.
local CARGO_QUANTITIES = {
    { qty = 1,  weight = 55 },
    { qty = 2,  weight = 28 },
    { qty = 4,  weight = 12 },
    { qty = 8,  weight = 4  },
    { qty = 16, weight = 1  },
}

local function pickQty()
    local total = 0
    for _, e in ipairs(CARGO_QUANTITIES) do total += e.weight end
    local r, cum = math.random() * total, 0
    for _, e in ipairs(CARGO_QUANTITIES) do
        cum += e.weight
        if r <= cum then return e.qty end
    end
    return 1
end

local activeCollectibles = {}  -- array of {part, fragType, qty}

local function pick(t) return t[math.random(1, #t)] end


-- ── Collectible spawner ───────────────────────────────────────────────────────

local function spawnCollectible(position, fragType)
    local cfg   = COLLECTIBLE[fragType] or COLLECTIBLE.Rock
    local scale = 0.75 + math.random() * 0.5

    local part          = Instance.new("Part")
    part.Name           = fragType
    part.Shape          = cfg.shape
    part.Size           = cfg.size * scale
    part.Color          = cfg.color
    part.Material       = cfg.material
    part.Transparency   = cfg.trans
    part.Anchored       = true
    part.CanCollide     = false
    part.CanQuery       = false
    part.CastShadow     = false

    -- Scatter in the tangent plane of the sphere at the death point, then
    -- project back to the surface so collectibles sit ON the planet.
    local radialDir = (position - PLANET_CENTER)
    if radialDir.Magnitude < 0.1 then radialDir = Vector3.new(0, 1, 0) end
    local surfNormal = radialDir.Unit
    local ref        = math.abs(surfNormal.Y) < 0.9 and Vector3.new(0, 1, 0) or Vector3.new(1, 0, 0)
    local tanA       = surfNormal:Cross(ref).Unit
    local tanB       = surfNormal:Cross(tanA).Unit
    local scattered  = position + tanA * math.random(-6, 6) + tanB * math.random(-6, 6)
    local snapDir    = (scattered - PLANET_CENTER)
    if snapDir.Magnitude < 0.1 then snapDir = surfNormal end
    -- Place centre at the surface so the collectible sits flush
    local surfPos    = PLANET_CENTER + snapDir.Unit * PLANET_RADIUS

    part.CFrame      = CFrame.new(surfPos)
                     * CFrame.Angles(
                           math.random() * math.pi * 2,
                           math.random() * math.pi * 2,
                           math.random() * math.pi * 2)
    part.Parent      = debrisFolder

    part:SetAttribute("IsFragment",   true)
    part:SetAttribute("FragmentType", fragType)

    -- Roll quantity and track for proximity collection
    local qty   = pickQty()
    local entry = {part = part, fragType = fragType, qty = qty}
    table.insert(activeCollectibles, entry)

    registerCollectible:Fire(part, "Fragment", fragType)

    -- Flash the part on spawn so players can spot it
    part.Transparency = 1
    local spawnLight = Instance.new("PointLight")
    spawnLight.Color      = cfg.color
    spawnLight.Brightness = 6
    spawnLight.Range      = 22
    spawnLight.Parent     = part
    TweenService:Create(part,       TweenInfo.new(0.12), {Transparency = cfg.trans}):Play()
    TweenService:Create(spawnLight, TweenInfo.new(0.5),  {Brightness = 0}):Play()
    task.delay(0.5, function()
        if spawnLight and spawnLight.Parent then spawnLight:Destroy() end
    end)

    task.delay(60, function()
        -- Remove from proximity table
        for i, e in ipairs(activeCollectibles) do
            if e.part == part then table.remove(activeCollectibles, i); break end
        end
        if not (part and part.Parent) then return end
        TweenService:Create(part, TweenInfo.new(2), {Transparency = 1}):Play()
        task.delay(2, function()
            if part and part.Parent then part:Destroy() end
        end)
    end)
end

-- ── Visual-only shard (no cargo value) ───────────────────────────────────────

local function spawnShard(center)
    local sz     = 0.4 + math.random() * 1.2
    local offset = Vector3.new(math.random(-3,3), math.random(-3,3), math.random(-3,3))
    local part = Instance.new("Part")
    part.Name       = "Shard"
    part.Size       = Vector3.new(sz, sz, sz)
    part.CFrame     = CFrame.new(center + offset)
                    * CFrame.Angles(
                          math.random() * math.pi * 2,
                          math.random() * math.pi * 2,
                          math.random() * math.pi * 2)
    part.Color      = pick(DEBRIS_COLORS)
    part.Material   = Enum.Material.Rock
    part.Anchored   = false
    part.CanCollide = false
    part.CanQuery   = false
    part.CastShadow = false
    part.Parent     = debrisFolder

    local outDir = offset.Magnitude > 0.1 and offset.Unit
        or Vector3.new(math.random()-0.5, math.random()-0.5, math.random()-0.5).Unit
    local speed = 25 + math.random() * 55
    part:ApplyImpulse(outDir * speed * part:GetMass())

    TweenService:Create(part, TweenInfo.new(1, Enum.EasingStyle.Linear), {Transparency = 1}):Play()
    task.delay(1, function()
        if part and part.Parent then part:Destroy() end
    end)
end

-- ── Chunk builder ────────────────────────────────────────────────────────────

local function makeChunk(pos, size, color, health, fragType)
    local chunk = Instance.new("Part")
    chunk.Name     = "DebrisChunk"
    chunk.Shape    = Enum.PartType.Block
    chunk.Size     = Vector3.new(size, size, size)
    chunk.Position = pos
    chunk.Color    = color
    chunk.Material = pick(DEBRIS_MATERIALS)
    chunk.CustomPhysicalProperties = PhysicalProperties.new(1, 2, 0, 1, 1)
    chunk.CanCollide = true
    pcall(function() chunk.CollisionGroup = "Debris" end)  -- no debris-debris collisions
    chunk.Parent   = debrisFolder

    chunk:SetAttribute("IsDebris",  true)
    chunk:SetAttribute("Health",    health)
    chunk:SetAttribute("FragType",  fragType)

    return chunk
end

-- Debris spawn uses XZ radius capped to sphere footprint
local SPAWN_RADIUS = PLANET_RADIUS * 0.85

-- ── Debris spawner ───────────────────────────────────────────────────────────

local DEBRIS_GRAVITY  = 220  -- radial pull toward planet centre (studs/s²)

local function spawnDebris()
    -- Spawn above the playable area using the original flat Y ceiling
    local angle   = math.random() * math.pi * 2
    local spawnR  = math.random(0, SPAWN_RADIUS)
    local spawnPos = Vector3.new(
        math.cos(angle) * spawnR,
        Config.DEBRIS_SPAWN_HEIGHT,
        math.sin(angle) * spawnR
    )

    local s        = math.random(13, 21)
    local fragType = pick(Config.FRAGMENT_TYPES)
    local color    = pick(DEBRIS_COLORS)
    local chunk    = makeChunk(spawnPos, s, color, Config.DEBRIS_HEALTH, fragType)

    -- Give a strong horizontal (tangential) velocity plus a downward push
    -- so chunks streak across the sky at an angle rather than dropping straight down
    local hAngle  = math.random() * math.pi * 2
    local tanDir  = Vector3.new(math.cos(hAngle), 0, math.sin(hAngle))
    local tanSpeed = 40 + math.random() * 40   -- 40–80 studs/s horizontal
    local downSpeed = 30 + math.random() * 30  -- 30–60 studs/s downward
    chunk:ApplyImpulse((tanDir * tanSpeed + Vector3.new(0, -downSpeed, 0)) * chunk:GetMass())

    -- Guaranteed surface snap after 5 seconds regardless of physics
    task.delay(5, function()
        if not (chunk and chunk.Parent) or chunk.Anchored then return end
        chunk.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
        chunk.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        local dir = (chunk.Position - PLANET_CENTER)
        if dir.Magnitude > 0.1 then
            chunk.CFrame = CFrame.new(PLANET_CENTER + dir.Unit * (PLANET_RADIUS - s * 0.15))
                         * (chunk.CFrame - chunk.CFrame.Position)
        end
        chunk.Anchored = true
    end)

    task.delay(120, function()
        if chunk and chunk.Parent then chunk:Destroy() end
    end)
end

-- ── Hit handling ─────────────────────────────────────────────────────────────

local function applyDamage(chunk, damage)
    if not chunk or not chunk.Parent then return end
    if not chunk:GetAttribute("IsDebris") then return end

    local hp   = chunk:GetAttribute("Health") - damage
    local orig = chunk.Color
    chunk.Color = Color3.new(1, 1, 1)
    task.delay(0.06, function()
        if chunk and chunk.Parent then chunk.Color = orig end
    end)

    if hp <= 0 then
        local pos      = chunk.Position
        local fragType = chunk:GetAttribute("FragType") or pick(Config.FRAGMENT_TYPES)
        chunk:Destroy()

        for _ = 1, DEATH_PIECES do
            if math.random() < CARGO_CHANCE then
                task.spawn(spawnCollectible, pos, fragType)
            else
                task.spawn(spawnShard, pos)
            end
        end
    else
        chunk:SetAttribute("Health", hp)
    end
end

-- Player laser (client → server)
hitDebrisEvent.OnServerEvent:Connect(function(_player, chunk)
    applyDamage(chunk, Config.LASER_DAMAGE)
end)

-- Drone laser (server → server via BindableEvent)
serverHitDebris.Event:Connect(function(chunk, damage)
    applyDamage(chunk, damage)
end)

-- ── Proximity collection loop ────────────────────────────────────────────────

task.spawn(function()
    while true do
        task.wait(0.25)
        local players = Players:GetPlayers()
        for i = #activeCollectibles, 1, -1 do
            local entry = activeCollectibles[i]
            local part  = entry.part
            if not (part and part.Parent) then
                table.remove(activeCollectibles, i)
                continue
            end
            for _, plr in ipairs(players) do
                local char = plr.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - part.Position).Magnitude <= COLLECT_RADIUS then
                    local worldPos = part.Position
                    table.remove(activeCollectibles, i)
                    part:Destroy()
                    -- Persist to DataStore
                    if _G.PlayerData then
                        _G.PlayerData.addFragment(plr, entry.fragType, entry.qty)
                        _G.PlayerData.addXP(plr, entry.qty * 5)
                    end
                    collectFragmentEvent:FireClient(plr, entry.fragType, entry.qty, worldPos)
                    break
                end
            end
        end
    end
end)

-- ── Spawn loop ───────────────────────────────────────────────────────────────

local SPAWN_INTERVAL  = 1    -- seconds between waves
local SPAWN_PER_WAVE  = 3
local INITIAL_BURST   = 12

for _ = 1, INITIAL_BURST do
    task.spawn(spawnDebris)
end


local lastSpawn = tick()
RunService.Heartbeat:Connect(function(dt)
    for _, chunk in ipairs(debrisFolder:GetChildren()) do
        if chunk:IsA("BasePart") and not chunk.Anchored and chunk:GetAttribute("IsDebris") then
            -- Pull debris toward planet centre each frame
            local toCenter = PLANET_CENTER - chunk.Position
            local dist     = toCenter.Magnitude
            if dist > 0.1 then
                chunk:ApplyImpulse(toCenter.Unit * DEBRIS_GRAVITY * chunk:GetMass() * dt)
            end

            -- Anchor when chunk centre is within one half-size of the surface
            if dist <= PLANET_RADIUS + chunk.Size.X * 0.5 then
                chunk.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
                chunk.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                local snapDir = (chunk.Position - PLANET_CENTER)
                if snapDir.Magnitude > 0.1 then
                    -- 65% buried: centre is 0.15 * size below surface
                    local snapPos = PLANET_CENTER + snapDir.Unit * (PLANET_RADIUS - chunk.Size.X * 0.15)
                    chunk.CFrame = CFrame.new(snapPos) * (chunk.CFrame - chunk.CFrame.Position)
                    task.spawn(function()
                        local impactPos = PLANET_CENTER + snapDir.Unit * (PLANET_RADIUS + chunk.Size.X * 0.1)
                        -- Dust ring: several small parts blasted outward in the tangent plane
                        local ref = math.abs(snapDir.Unit.Y) < 0.9 and Vector3.new(0,1,0) or Vector3.new(1,0,0)
                        local tanA = snapDir.Unit:Cross(ref).Unit
                        local tanB = snapDir.Unit:Cross(tanA).Unit
                        for i = 1, 8 do
                            local a     = (i / 8) * math.pi * 2
                            local dir2  = tanA * math.cos(a) + tanB * math.sin(a)
                            local rock  = Instance.new("Part")
                            rock.Size        = Vector3.new(0.5, 0.5, 0.5)
                            rock.CFrame      = CFrame.new(impactPos)
                            rock.Color       = chunk.Color
                            rock.Material    = Enum.Material.Rock
                            rock.Anchored    = false
                            rock.CanCollide  = false
                            rock.CanQuery    = false
                            rock.CastShadow  = false
                            rock.Parent      = debrisFolder
                            rock:ApplyImpulse((dir2 * (18 + math.random()*14) + snapDir.Unit * (6 + math.random()*8)) * rock:GetMass())
                            TweenService:Create(rock, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {Transparency = 1}):Play()
                            task.delay(0.7, function() if rock and rock.Parent then rock:Destroy() end end)
                        end
                        -- Flash light at impact point
                        local flash = Instance.new("Part")
                        flash.Size        = Vector3.new(0.1, 0.1, 0.1)
                        flash.CFrame      = CFrame.new(impactPos)
                        flash.Anchored    = true
                        flash.CanCollide  = false
                        flash.Transparency = 1
                        flash.Parent      = debrisFolder
                        local light = Instance.new("PointLight")
                        light.Color      = Color3.fromRGB(255, 180, 80)
                        light.Brightness = 12
                        light.Range      = chunk.Size.X * 4
                        light.Parent     = flash
                        TweenService:Create(light, TweenInfo.new(0.4), {Brightness = 0}):Play()
                        task.delay(0.4, function() if flash and flash.Parent then flash:Destroy() end end)
                    end)
                end
                chunk.Anchored = true
            end
        end
    end

    local now = tick()
    if now - lastSpawn >= SPAWN_INTERVAL then
        lastSpawn = now
        for _ = 1, SPAWN_PER_WAVE do
            task.spawn(spawnDebris)
        end
    end
end)

print("[SkyBase] Debris system active")
