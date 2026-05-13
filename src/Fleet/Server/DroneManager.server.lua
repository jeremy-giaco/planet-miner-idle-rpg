-- Script → ServerScriptService, rename to "RoverSystem"
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")

local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local remotes              = ReplicatedStorage:WaitForChild("Remotes")
local collectFragmentEvent = remotes:WaitForChild("CollectFragment")
local collectMetalEvent    = remotes:WaitForChild("CollectMetal")
local serverHitDebris      = ReplicatedStorage:WaitForChild("ServerHitDebris")
local registerEvent        = ReplicatedStorage:WaitForChild("RegisterCollectible")

-- Remotes created here
local setDroneModeEvent = Instance.new("RemoteEvent")
setDroneModeEvent.Name   = "SetDroneMode"
setDroneModeEvent.Parent = remotes

local deductMetalEvent = Instance.new("RemoteEvent")
deductMetalEvent.Name   = "DeductMetal"
deductMetalEvent.Parent = remotes

local droneHealthEvent = Instance.new("RemoteEvent")
droneHealthEvent.Name   = "DroneHealthUpdate"
droneHealthEvent.Parent = remotes

-- BindableEvent: CoinSystem fires this so we can track server-side metal counts
local serverMetalEarned = Instance.new("BindableEvent")
serverMetalEarned.Name   = "ServerMetalEarned"
serverMetalEarned.Parent = ReplicatedStorage

-- ── Server-side metal inventory ───────────────────────────────────────────────
-- Needed so ProximityPrompt rebuild can verify and deduct without trusting client.

local playerMetals = {}   -- [player] = { Iron=0, Copper=0, ... }
local drones       = {}   -- populated below after DRONE_CONFIGS is defined

local function addMetal(player, name)
    if not playerMetals[player] then playerMetals[player] = {} end
    playerMetals[player][name] = (playerMetals[player][name] or 0) + 1
end

-- Returns the metal name deducted, or nil if none available
local function takeMetal(player)
    local inv = playerMetals[player]
    if not inv then return nil end
    for name, count in pairs(inv) do
        if count > 0 then
            inv[name] = count - 1
            return name
        end
    end
    return nil
end

serverMetalEarned.Event:Connect(function(player, metalName)
    addMetal(player, metalName)
end)

Players.PlayerRemoving:Connect(function(player)
    playerMetals[player] = nil
end)

Players.PlayerAdded:Connect(function(player)
    -- Send current drone health to a newly joined player once drones exist
    task.wait(2)
    for _, drone in ipairs(drones) do
        droneHealthEvent:FireClient(player, drone.index, drone.health, DRONE_MAX_HEALTH, drone.alive)
    end
end)

-- ── Collectible registry ──────────────────────────────────────────────────────

local collectibles = {}   -- { part, type, name, claimed=false }

local function removeCollectible(part)
    for i, c in ipairs(collectibles) do
        if c.part == part then table.remove(collectibles, i); return end
    end
end

registerEvent.Event:Connect(function(part, collectType, collectName)
    table.insert(collectibles, { part = part, type = collectType, name = collectName, claimed = false })
end)

-- ── Flat world hover ─────────────────────────────────────────────────────────

local HOVER_HEIGHT = 12   -- studs above the ground surface

local function moonHoverPos(worldPos)
    local pc    = Config.PLANET_CENTER
    local r     = Config.PLANET_RADIUS
    local dx    = worldPos.X - pc.X
    local dz    = worldPos.Z - pc.Z
    local inner = r * r - dx * dx - dz * dz
    local surfY = pc.Y + (inner > 0 and math.sqrt(inner) or 0)
    return Vector3.new(worldPos.X, surfY + HOVER_HEIGHT, worldPos.Z)
end

-- ── Constants ─────────────────────────────────────────────────────────────────

local CARGO_COLOR      = Color3.fromRGB(255, 255, 255)
local ROVER_SPEED      = 60
local GUN_RANGE        = 160
local GUN_COOLDOWN     = 3
local GUN_DAMAGE       = 15
local GUARD_RADIUS     = 10   -- ring radius around player in the surface-tangent plane
local GUARD_HEIGHT     = 18   -- studs above player in the outward radial direction
local DRONE_MAX_HEALTH = 100
local DEBRIS_DAMAGE    = 25   -- damage per debris chunk that touches a drone
local REPAIR_THRESHOLD = 40   -- HP — return to station below this
local REPAIR_RATE      = 8    -- HP per second while docked
local REPAIR_COLOR     = Color3.fromRGB(255, 160, 20)  -- orange = repairing

local MODE_COLOR = {
    scavenger = Color3.fromRGB(255, 180,   0),  -- gold
    sentry    = Color3.fromRGB(220,  35,  35),  -- red
    guard     = Color3.fromRGB(  0, 210,  80),  -- green
}

-- Offsets match the 6 docking pads built by GameSetup's createDroneStation()
local DRONE_CONFIGS = {
    { offset = Vector3.new(  0, 2, -24), color = Color3.fromRGB(  0, 200, 120), defaultMode = "scavenger" }, -- N pad
    { offset = Vector3.new(  0, 2,  24), color = Color3.fromRGB(  0, 180, 255), defaultMode = "scavenger" }, -- S pad
    { offset = Vector3.new(-24, 2,   0), color = Color3.fromRGB(255, 140,   0), defaultMode = "sentry"    }, -- W pad
    { offset = Vector3.new( 24, 2,   0), color = Color3.fromRGB(180,   0, 255), defaultMode = "sentry"    }, -- E pad
    { offset = Vector3.new(-10, 2, -10), color = Color3.fromRGB(255,  60,  60), defaultMode = "guard"     }, -- NW pad
    { offset = Vector3.new( 10, 2,  10), color = Color3.fromRGB(255, 220,   0), defaultMode = "guard"     }, -- SE pad
}

-- ── Visuals ───────────────────────────────────────────────────────────────────

local function flashDroneLaser(fromPos, toPos, color)
    local len = (toPos - fromPos).Magnitude
    if len < 0.5 then return end
    local beam = Instance.new("Part")
    beam.Anchored   = true
    beam.CanCollide = false
    beam.CanQuery   = false
    beam.CastShadow = false
    beam.Size       = Vector3.new(0.25, 0.25, len)
    beam.CFrame     = CFrame.lookAt(fromPos, toPos) * CFrame.new(0, 0, -len / 2)
    beam.Material   = Enum.Material.Neon
    beam.Color      = color
    beam.Parent     = Workspace
    Debris:AddItem(beam, 0.15)
end

local function setDroneColor(drone, color)
    drone.neonColor = color
    if not drone.model or not drone.model.Parent then return end
    for _, part in ipairs(drone.model:GetDescendants()) do
        if part:IsA("BasePart") and part.Name == "Stripe" then
            part.Color = color
        elseif part:IsA("PointLight") then
            part.Color = color
        end
    end
end

local function buildDroneModel(name, homePos, neonColor)
    local model = Instance.new("Model")
    model.Name  = name

    local function p(partName, size, offset, color, mat)
        local part = Instance.new("Part")
        part.Name       = partName
        part.Size       = size
        part.CFrame     = CFrame.new(homePos + offset)
        part.Anchored   = true
        part.Color      = color
        part.Material   = mat or Enum.Material.Metal
        part.CastShadow = false
        part.Parent     = model
        return part
    end

    local BODY = Color3.fromRGB(55, 65, 100)
    local DARK = Color3.fromRGB(30, 35, 55)

    local body = p("Body", Vector3.new(3.2, 1.2, 4.4), Vector3.new(0, 0, 0), BODY)

    for _, s in ipairs({-1, 1}) do
        local pod = p("Thruster"..s, Vector3.new(0.8, 0.6, 1.6), Vector3.new(s*2.2, -0.2, 0), DARK)
        local glow = Instance.new("PointLight")
        glow.Brightness = 2; glow.Range = 12; glow.Color = neonColor; glow.Parent = pod
    end

    p("Dome",   Vector3.new(1.2, 0.8, 1.2), Vector3.new(0, 1.0, -0.4),
        Color3.fromRGB(180, 220, 255), Enum.Material.Glass)
    p("Stripe", Vector3.new(3.4, 0.16, 4.6), Vector3.new(0, 0.6, 0),
        neonColor, Enum.Material.Neon)

    local cargoLight = p("CargoLight", Vector3.new(1.0, 0.2, 1.0),
        Vector3.new(0, -0.7, 1.2), DARK, Enum.Material.Neon)

    model.PrimaryPart = body
    model.Parent      = Workspace
    return model, body, cargoLight
end

-- ── Health bar ────────────────────────────────────────────────────────────────

local function addDroneHealthBar(drone)
    local bb = Instance.new("BillboardGui")
    bb.Name                  = "HealthBar"
    bb.Size                  = UDim2.new(0, 80, 0, 8)
    bb.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop           = false
    bb.Parent                = drone.body

    local bg = Instance.new("Frame")
    bg.Size              = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3  = Color3.fromRGB(15, 15, 15)
    bg.BorderSizePixel   = 0
    bg.Parent            = bb
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Name            = "Fill"
    fill.Size            = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 210, 80)
    fill.BorderSizePixel = 0
    fill.Parent          = bg
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    drone.healthBarFill = fill
end

local function updateHealthBar(drone)
    local fill = drone.healthBarFill
    if not fill or not fill.Parent then return end
    local t = math.clamp(drone.health / DRONE_MAX_HEALTH, 0, 1)
    fill.Size             = UDim2.new(t, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(
        math.floor(220 * (1 - t)),
        math.floor(210 * t),
        math.floor(80 * t)
    )
end

-- ── Drone table ───────────────────────────────────────────────────────────────

-- Forward declare so connectDebrisDamage can reference applyDroneDamage
local applyDroneDamage

for i, cfg in ipairs(DRONE_CONFIGS) do
    -- Use station Y directly (it sits on the base roof, not on raw sphere surface)
    local sp = Config.STATION_POS
    local homePos = Vector3.new(sp.X + cfg.offset.X, sp.Y + cfg.offset.Y + 4, sp.Z + cfg.offset.Z)
    local model, body, cargoLight = buildDroneModel("Drone"..i, homePos, cfg.color)
    drones[i] = {
        index          = i,
        model          = model,
        body           = body,
        cargoLight     = cargoLight,
        neonColor      = cfg.color,
        homePos        = homePos,
        pos            = homePos,
        state          = "idle",
        target         = nil,
        cargo          = nil,
        fireCooldown   = math.random() * GUN_COOLDOWN,
        mode           = cfg.defaultMode,
        assignedPlayer = nil,
        guardAngle     = (i - 1) * (math.pi * 2 / 6),
        health         = DRONE_MAX_HEALTH,
        alive          = true,
        healthBarFill  = nil,
        rebuildMarker  = nil,
        damageCooldown = 0,   -- prevents multi-hit spam from one debris chunk
        repairTimer    = 0,   -- throttles health broadcasts during repair
    }
end

-- ── Cargo light ───────────────────────────────────────────────────────────────

local function setCargoLight(drone, on)
    if not drone.cargoLight or not drone.cargoLight.Parent then return end
    drone.cargoLight.Color = on and CARGO_COLOR or Color3.fromRGB(30, 35, 55)
end

-- ── Debris damage + death + rebuild ──────────────────────────────────────────

local function broadcastDroneHealth(drone)
    droneHealthEvent:FireAllClients(drone.index, drone.health, DRONE_MAX_HEALTH, drone.alive)
end

local function createRebuildMarker(drone)
    local marker = Instance.new("Part")
    marker.Name        = "DroneRebuildMarker"
    marker.Size        = Vector3.new(2.5, 0.3, 2.5)
    marker.CFrame      = CFrame.new(drone.homePos)
    marker.Anchored    = true
    marker.CanCollide  = false
    marker.CastShadow  = false
    marker.Material    = Enum.Material.Neon
    marker.Color       = Color3.fromRGB(180, 30, 30)
    marker.Parent      = Workspace

    -- Pulsing transparency via a simple loop
    task.spawn(function()
        local t = 0
        while marker.Parent do
            t += task.wait(0.05)
            marker.Transparency = 0.4 + 0.35 * math.abs(math.sin(t * 2))
        end
    end)

    local label = Instance.new("BillboardGui")
    label.Size                  = UDim2.new(0, 120, 0, 30)
    label.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    label.AlwaysOnTop           = true
    label.Parent                = marker
    local txt = Instance.new("TextLabel")
    txt.Text                   = "Drone " .. drone.index .. " — OFFLINE"
    txt.Size                   = UDim2.new(1, 0, 0.5, 0)
    txt.BackgroundTransparency = 1
    txt.TextColor3             = Color3.fromRGB(255, 80, 80)
    txt.TextSize               = 12
    txt.Font                   = Enum.Font.GothamBold
    txt.Parent                 = label
    local sub = Instance.new("TextLabel")
    sub.Text                   = "Rebuild (1 Metal)"
    sub.Size                   = UDim2.new(1, 0, 0.5, 0)
    sub.Position               = UDim2.new(0, 0, 0.5, 0)
    sub.BackgroundTransparency = 1
    sub.TextColor3             = Color3.fromRGB(200, 200, 200)
    sub.TextSize               = 10
    sub.Font                   = Enum.Font.Gotham
    sub.Parent                 = label

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText            = "Rebuild"
    prompt.ObjectText            = "Drone " .. drone.index .. " (1 Metal)"
    prompt.MaxActivationDistance = 30
    prompt.HoldDuration          = 0
    prompt.Parent                = marker

    prompt.Triggered:Connect(function(player)
        local metalName = takeMetal(player)
        if not metalName then return end  -- no metal, do nothing
        -- Tell client to remove one metal from their UI
        deductMetalEvent:FireClient(player, metalName)
        marker:Destroy()
        drone.rebuildMarker = nil
        -- Rebuild
        local model, body, cargoLight = buildDroneModel(
            "Drone" .. drone.index, drone.homePos, MODE_COLOR[drone.mode])
        drone.model        = model
        drone.body         = body
        drone.cargoLight   = cargoLight
        drone.health       = DRONE_MAX_HEALTH
        drone.alive        = true
        drone.pos          = drone.homePos
        drone.state        = "idle"
        drone.target       = nil
        drone.cargo        = nil
        drone.damageCooldown = 0
        addDroneHealthBar(drone)
        updateHealthBar(drone)
        setDroneColor(drone, MODE_COLOR[drone.mode])
        connectDebrisDamage(drone)
        broadcastDroneHealth(drone)
    end)

    drone.rebuildMarker = marker
end

local function killDrone(drone)
    drone.alive = false
    drone.healthBarFill = nil
    broadcastDroneHealth(drone)
    if drone.target then
        drone.target.claimed = false
        drone.target = nil
    end
    drone.cargo  = nil
    drone.state  = "idle"
    -- Explosion flash
    if drone.model and drone.model.Parent then
        for _, part in ipairs(drone.model:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Color = Color3.fromRGB(255, 120, 0)
            end
        end
        task.delay(0.1, function()
            if drone.model and drone.model.Parent then
                drone.model:Destroy()
            end
        end)
    end
    createRebuildMarker(drone)
end

applyDroneDamage = function(drone, damage)
    if not drone.alive then return end
    if drone.damageCooldown > 0 then return end
    drone.damageCooldown = 0.5   -- half-second between hits from same debris
    drone.health = math.max(0, drone.health - damage)
    -- Flash body white
    if drone.body and drone.body.Parent then
        local origColor = drone.body.Color
        drone.body.Color = Color3.new(1, 1, 1)
        task.delay(0.08, function()
            if drone.body and drone.body.Parent then
                drone.body.Color = origColor
            end
        end)
    end
    updateHealthBar(drone)
    broadcastDroneHealth(drone)
    if drone.health <= 0 then
        killDrone(drone)
    end
end

function connectDebrisDamage(drone)
    for _, part in ipairs(drone.model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Touched:Connect(function(hit)
                if not drone.alive then return end
                if not hit:GetAttribute("IsDebris") then return end
                applyDroneDamage(drone, DEBRIS_DAMAGE)
            end)
        end
    end
end

-- ── Initialise all drones ─────────────────────────────────────────────────────

for _, drone in ipairs(drones) do
    setDroneColor(drone, MODE_COLOR[drone.mode])
    addDroneHealthBar(drone)
    updateHealthBar(drone)
    connectDebrisDamage(drone)
end

-- ── Per-drone movement ────────────────────────────────────────────────────────

local function moveDrone(drone, targetPos, dt)
    local dir  = targetPos - drone.pos
    local dist = dir.Magnitude
    if dist < 0.8 then return true end
    local step = math.min(ROVER_SPEED * dt, dist)
    drone.pos  = drone.pos + dir.Unit * step
    drone.model:SetPrimaryPartCFrame(
        CFrame.new(drone.pos) * CFrame.Angles(0, math.atan2(-dir.X, -dir.Z), 0)
    )
    return false
end

-- ── Debris dodge check ────────────────────────────────────────────────────────

local function nearDebris(pos)
    local debrisFolder = Workspace:FindFirstChild("Debris")
    if not debrisFolder then return false end
    for _, chunk in ipairs(debrisFolder:GetChildren()) do
        if chunk:GetAttribute("IsDebris") and (chunk.Position - pos).Magnitude < 5 then
            return true
        end
    end
    return false
end

-- ── Deliver cargo ─────────────────────────────────────────────────────────────

local function deliverCargo(drone)
    local playerList = Players:GetPlayers()
    if drone.cargo.type == "Fragment" then
        for _, player in ipairs(playerList) do
            collectFragmentEvent:FireClient(player, drone.cargo.name)
        end
    elseif drone.cargo.type == "Metal" then
        for _, player in ipairs(playerList) do
            collectMetalEvent:FireClient(player, drone.cargo.name)
            addMetal(player, drone.cargo.name)
        end
    end
    drone.cargo = nil
    setCargoLight(drone, false)
end

-- ── Mode switching ────────────────────────────────────────────────────────────

local function resetDrone(drone)
    if drone.target then
        drone.target.claimed = false
        drone.target = nil
    end
    if drone.cargo then
        drone.cargo = nil
        setCargoLight(drone, false)
    end
    drone.state = "idle"
end

setDroneModeEvent.OnServerEvent:Connect(function(player, droneIndex, newMode)
    local drone = drones[droneIndex]
    if not drone or not drone.alive then return end
    if newMode ~= "scavenger" and newMode ~= "sentry" and newMode ~= "guard" then return end
    resetDrone(drone)
    drone.mode           = newMode
    drone.assignedPlayer = (newMode == "guard") and player or nil
    setDroneColor(drone, MODE_COLOR[newMode])
end)

-- ── Main loop ─────────────────────────────────────────────────────────────────

RunService.Heartbeat:Connect(function(dt)
    for _, drone in ipairs(drones) do
        if not drone.alive then continue end

        -- Tick down damage cooldown
        if drone.damageCooldown > 0 then
            drone.damageCooldown = math.max(0, drone.damageCooldown - dt)
        end

        -- ── Repair: fly back to station when health is low ────────────────────
        if drone.health < REPAIR_THRESHOLD and drone.state ~= "repairing" then
            resetDrone(drone)
            drone.state = "repairing"
            setDroneColor(drone, REPAIR_COLOR)
        end

        if drone.state == "repairing" then
            moveDrone(drone, drone.homePos, dt)
            if (drone.pos - drone.homePos).Magnitude < 3 then
                -- Docked — recharge
                drone.health = math.min(DRONE_MAX_HEALTH, drone.health + REPAIR_RATE * dt)
                updateHealthBar(drone)
                drone.repairTimer -= dt
                if drone.repairTimer <= 0 then
                    broadcastDroneHealth(drone)
                    drone.repairTimer = 0.4
                end
                if drone.health >= DRONE_MAX_HEALTH then
                    drone.health = DRONE_MAX_HEALTH
                    drone.state  = "idle"
                    setDroneColor(drone, MODE_COLOR[drone.mode])
                    broadcastDroneHealth(drone)
                end
            end
            continue  -- skip guns and mode logic while repairing
        end

        -- ── Gun: all modes ────────────────────────────────────────────────────
        drone.fireCooldown = drone.fireCooldown - dt
        if drone.fireCooldown <= 0 then
            local debrisFolder = Workspace:FindFirstChild("Debris")
            if debrisFolder then
                local nearest, nearestDist = nil, math.huge
                for _, chunk in ipairs(debrisFolder:GetChildren()) do
                    if chunk:IsA("BasePart") and chunk:GetAttribute("IsDebris") then
                        local d = (chunk.Position - drone.pos).Magnitude
                        if d < GUN_RANGE and d < nearestDist then
                            nearestDist = d
                            nearest     = chunk
                        end
                    end
                end
                if nearest then
                    flashDroneLaser(drone.pos, nearest.Position, drone.neonColor)
                    serverHitDebris:Fire(nearest, GUN_DAMAGE)
                    drone.fireCooldown = GUN_COOLDOWN
                else
                    drone.fireCooldown = 0.5
                end
            end
        end

        -- ── Mode behaviour ────────────────────────────────────────────────────

        if drone.mode == "sentry" then
            moveDrone(drone, drone.homePos, dt)

        elseif drone.mode == "guard" then
            local p = drone.assignedPlayer
            if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local playerPos = p.Character.HumanoidRootPart.Position
                -- Ring above the player in the plane perpendicular to the surface normal
                local up  = (playerPos - Config.PLANET_CENTER).Unit
                local ref = math.abs(up.Y) < 0.9 and Vector3.new(0, 1, 0) or Vector3.new(1, 0, 0)
                local tanA = up:Cross(ref).Unit
                local tanB = up:Cross(tanA).Unit
                local guardPos = playerPos
                    + up    * GUARD_HEIGHT
                    + tanA  * math.cos(drone.guardAngle) * GUARD_RADIUS
                    + tanB  * math.sin(drone.guardAngle) * GUARD_RADIUS
                moveDrone(drone, guardPos, dt)
            else
                moveDrone(drone, drone.homePos, dt)
            end

        elseif drone.mode == "scavenger" then
            if drone.state == "idle" then
                local nearest, nearestDist = nil, math.huge
                for _, c in ipairs(collectibles) do
                    if not c.claimed and c.part and c.part.Parent then
                        local d = (c.part.Position - drone.pos).Magnitude
                        if d < nearestDist then nearestDist = d; nearest = c end
                    end
                end
                if nearest then
                    nearest.claimed = true
                    drone.target    = nearest
                    drone.state     = "flying_out"
                end

            elseif drone.state == "flying_out" then
                if not drone.target or not drone.target.part or not drone.target.part.Parent then
                    if drone.target then
                        drone.target.claimed = false
                        removeCollectible(drone.target.part)
                    end
                    drone.target = nil; drone.state = "idle"
                else
                    if nearDebris(drone.pos) then
                        drone.target.claimed = false
                        drone.target = nil; drone.state = "flying_back"
                    else
                        local arrived = moveDrone(drone, moonHoverPos(drone.target.part.Position), dt)
                        if arrived then drone.state = "collecting" end
                    end
                end

            elseif drone.state == "collecting" then
                local c = drone.target
                if c and c.part and c.part.Parent then
                    drone.cargo = { type = c.type, name = c.name }
                    removeCollectible(c.part)
                    c.part:Destroy()
                    setCargoLight(drone, true)
                end
                drone.target = nil; drone.state = "flying_back"

            elseif drone.state == "flying_back" then
                local arrived = moveDrone(drone, drone.homePos, dt)
                if arrived then
                    if drone.cargo then deliverCargo(drone) end
                    drone.state = "idle"
                end
            end
        end
    end
end)

print("[SkyBase] Rover system active — 6 drones online (Scavenger / Sentry / Guard)")
