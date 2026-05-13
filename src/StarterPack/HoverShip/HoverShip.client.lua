-- LocalScript → HoverShip Tool (StarterPack)
-- Equip to board the ship, unequip to exit.
-- W/S = thrust forward/back  |  A/D = yaw (rotate) left/right

local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Config            = require(ReplicatedStorage:WaitForChild("Config"))

local PLANET_RADIUS = Config.PLANET_RADIUS
local PLANET_CENTER = Config.PLANET_CENTER

local tool   = script.Parent
local player = Players.LocalPlayer

local SPEED          = 280           -- studs/s
local HOVER_HEIGHT   = 6             -- studs above sphere surface
local HOVER_BOOST    = 120           -- extra height from space bar
local ACCEL          = 8             -- velocity lerp speed (higher = snappier)
local ROLL_MAX       = math.rad(48)  -- bank into turns (full momentum)
local TILT_SPEED     = 7
local MOUSE_SENS     = 0.004         -- radians per pixel of mouse movement
local CAM_DIST       = 28            -- studs behind ship
local CAM_HEIGHT     = 10            -- studs above ship
local YAW_RATE       = math.rad(150) -- yaw rate from A/D keys at full momentum (rad/s)
local YAW_ACCEL      = 0.6           -- seconds to reach full momentum from rest
local YAW_DECAY      = 3.5           -- how quickly momentum falls off on release
local CAM_PITCH_MIN  = math.rad(-70) -- max nose-up angle
local CAM_PITCH_MAX  = math.rad(70)  -- max nose-down angle
local ORBIT_SPEED    = math.rad(80)  -- camera orbit rate via arrow keys (rad/s)
local ORBIT_P_MIN    = math.rad(-30) -- how far down orbit can go
local ORBIT_P_MAX    = math.rad(75)  -- how far overhead orbit can go
local BEAM_RANGE     = 100           -- mining beam max reach (studs)
local BEAM_COOLDOWN  = 0.3           -- seconds between damage ticks
local BEAM_COL       = Color3.fromRGB(0, 220, 255)

-- Ship color palette
local HULL_COL  = Color3.fromRGB(35,  45,  75)
local DARK_COL  = Color3.fromRGB(22,  30,  52)
local ENG_COL   = Color3.fromRGB(80, 180, 255)
local HOVER_COL = Color3.fromRGB(50, 110, 255)

local character, hrp, humanoid
local shipObjects  = {}   -- all parts + welds to clean up
local inShipValue
local moveConn
local scrollConn
local rmDownConn, rmUpConn
local rightMouseHeld = false
local shipVel        = Vector3.new(0, 0, 0)
local cameraYaw      = 0
local orbitYaw       = 0
local orbitPitch     = 0
local camDist        = CAM_DIST
local roll           = 0
local yawMomentum    = 0
local beamObj        = nil
local beamEndAnchor  = nil
local beamActive     = false  -- true while left mouse held
local beamTimer      = 0
local fireTimer      = 0
local beamMouseDownConn, beamMouseUpConn
local hitDebrisRemote
local rayParams   = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local debrisRayParams = RaycastParams.new()
debrisRayParams.FilterType = Enum.RaycastFilterType.Include

-- ── Ship model ────────────────────────────────────────────────────────────────

local function addPart(size, offset, color, mat, trans)
    local p = Instance.new("Part")
    p.Size        = size
    p.CFrame      = hrp.CFrame * CFrame.new(offset)
    p.Color       = color
    p.Material    = mat
    p.Transparency = trans or 0
    p.CanCollide  = false
    p.CastShadow  = false
    p.Anchored    = false
    p.Parent      = workspace
    local w = Instance.new("WeldConstraint")
    w.Part0 = hrp; w.Part1 = p; w.Parent = hrp
    table.insert(shipObjects, p)
    table.insert(shipObjects, w)
    return p
end

local function buildShip()
    -- Main hull
    addPart(Vector3.new(5.2, 0.65, 2.6), Vector3.new(0, -0.7, 0),
        HULL_COL, Enum.Material.Metal)
    -- Nose
    addPart(Vector3.new(1.5, 0.52, 2.1), Vector3.new(0, -0.72, -3.5),
        DARK_COL, Enum.Material.Metal)
    -- Cockpit glass
    addPart(Vector3.new(1.7, 0.9, 1.8), Vector3.new(0, 0.08, -1.2),
        Color3.fromRGB(150, 215, 255), Enum.Material.Glass, 0.22)
    -- Wings
    addPart(Vector3.new(2.6, 0.1, 1.2), Vector3.new(-3.5, -0.72, 0.6),
        DARK_COL, Enum.Material.Metal)
    addPart(Vector3.new(2.6, 0.1, 1.2), Vector3.new( 3.5, -0.72, 0.6),
        DARK_COL, Enum.Material.Metal)
    -- Wing tip neon edges (trailing edge)
    addPart(Vector3.new(2.65, 0.09, 0.18), Vector3.new(-3.5, -0.69, 1.16),
        ENG_COL, Enum.Material.Neon)
    addPart(Vector3.new(2.65, 0.09, 0.18), Vector3.new( 3.5, -0.69, 1.16),
        ENG_COL, Enum.Material.Neon)
    -- Engine pods
    addPart(Vector3.new(0.75, 0.62, 1.7), Vector3.new(-1.1, -0.58, 2.0),
        DARK_COL, Enum.Material.Metal)
    addPart(Vector3.new(0.75, 0.62, 1.7), Vector3.new( 1.1, -0.58, 2.0),
        DARK_COL, Enum.Material.Metal)
    -- Engine exhaust glow
    local glL = addPart(Vector3.new(0.58, 0.58, 0.22), Vector3.new(-1.1, -0.58, 2.88),
        ENG_COL, Enum.Material.Neon)
    local glR = addPart(Vector3.new(0.58, 0.58, 0.22), Vector3.new( 1.1, -0.58, 2.88),
        ENG_COL, Enum.Material.Neon)
    -- Engine point light
    local el = Instance.new("PointLight")
    el.Color = ENG_COL; el.Brightness = 3; el.Range = 16
    el.Parent = glL
    table.insert(shipObjects, el)
    -- Hover glow strip (underside)
    addPart(Vector3.new(5.0, 0.08, 2.55), Vector3.new(0, -1.06, 0),
        HOVER_COL, Enum.Material.Neon, 0.3)
    -- Underbelly point light for hover effect
    local hl = Instance.new("PointLight")
    hl.Color = HOVER_COL; hl.Brightness = 1.5; hl.Range = 10
    hl.Parent = glR
    table.insert(shipObjects, hl)

    -- Beam attachment between engine pods (visible from camera behind ship)
    local att0 = Instance.new("Attachment")
    att0.Position = Vector3.new(0, -0.7, 2)
    att0.Parent   = hrp

    -- Invisible anchor Part for the far end of the beam
    beamEndAnchor = Instance.new("Part")
    beamEndAnchor.Size         = Vector3.new(0.1, 0.1, 0.1)
    beamEndAnchor.Transparency = 1
    beamEndAnchor.CanCollide   = false
    beamEndAnchor.Anchored     = true
    beamEndAnchor.Parent       = workspace
    local att1 = Instance.new("Attachment")
    att1.Parent = beamEndAnchor

    beamObj = Instance.new("Beam")
    beamObj.Attachment0    = att0
    beamObj.Attachment1    = att1
    beamObj.Width0         = 1
    beamObj.Width1         = 14
    beamObj.LightEmission  = 1
    beamObj.LightInfluence = 0
    beamObj.Color          = ColorSequence.new(BEAM_COL)
    beamObj.Transparency   = NumberSequence.new(0.25)
    beamObj.Segments       = 1
    beamObj.FaceCamera     = true
    beamObj.Enabled        = false
    beamObj.Parent         = workspace

    table.insert(shipObjects, att0)
    table.insert(shipObjects, beamEndAnchor)
    table.insert(shipObjects, att1)
    table.insert(shipObjects, beamObj)
end

local function destroyShip()
    for _, obj in ipairs(shipObjects) do
        if obj and obj.Parent then obj:Destroy() end
    end
    shipObjects   = {}
    beamObj       = nil
    beamEndAnchor = nil
end

-- ── Character visibility ──────────────────────────────────────────────────────

local savedTrans = {}

local function hideCharacter()
    for _, p in ipairs(character:GetDescendants()) do
        if p:IsA("BasePart") and p ~= hrp then
            savedTrans[p] = p.Transparency; p.Transparency = 1
        elseif p:IsA("Decal") then
            savedTrans[p] = p.Transparency; p.Transparency = 1
        end
    end
end

local function showCharacter()
    for p, t in pairs(savedTrans) do
        if p and p.Parent then p.Transparency = t end
    end
    table.clear(savedTrans)
end

-- ── Ground burn light ─────────────────────────────────────────────────────────

local BURN_COLOR  = Color3.fromRGB(255, 55, 0)    -- lava orange-red
local BURN_LIFE   = 0.6   -- seconds before fade
local BURN_FADE   = 0.5   -- fade duration

local function spawnBurnLight(pos)
    local surfPos = PLANET_CENTER + (pos - PLANET_CENTER).Unit * PLANET_RADIUS

    local p = Instance.new("Part")
    p.Size        = Vector3.new(0.1, 0.1, 0.1)
    p.CFrame      = CFrame.new(surfPos)
    p.Anchored    = true
    p.CanCollide  = false
    p.CanQuery    = false
    p.CastShadow  = false
    p.Transparency = 1
    p.Parent      = workspace

    local light = Instance.new("PointLight")
    light.Color      = BURN_COLOR
    light.Brightness = 1.2
    light.Range      = 20
    light.Parent     = p

    task.delay(BURN_LIFE, function()
        if not (p and p.Parent) then return end
        TweenService:Create(light, TweenInfo.new(BURN_FADE), {Brightness = 0}):Play()
        task.delay(BURN_FADE, function()
            if p and p.Parent then p:Destroy() end
        end)
    end)
end

-- ── Movement update ───────────────────────────────────────────────────────────

local function update(dt)
    if not hrp or not hrp.Parent then return end

    -- Right mouse held: yaw with mouse X, tilt camera with mouse Y
    if rightMouseHeld then
        local delta = UserInputService:GetMouseDelta()
        cameraYaw  = cameraYaw + delta.X * MOUSE_SENS
        orbitPitch = math.clamp(orbitPitch + delta.Y * MOUSE_SENS, ORBIT_P_MIN, ORBIT_P_MAX)
    end
    local forward = Vector3.new(math.sin(cameraYaw), 0, -math.cos(cameraYaw))
    local right   = forward:Cross(Vector3.new(0, 1, 0)).Unit

    -- Arrow keys: orbit camera around ship (independent of movement)
    local function key(k) return UserInputService:IsKeyDown(k) and 1 or 0 end
    orbitYaw   = orbitYaw + (key(Enum.KeyCode.Right) - key(Enum.KeyCode.Left)) * ORBIT_SPEED * dt
    orbitPitch = math.clamp(
        orbitPitch + (key(Enum.KeyCode.Up) - key(Enum.KeyCode.Down)) * ORBIT_SPEED * dt,
        ORBIT_P_MIN, ORBIT_P_MAX)

    -- WASD + Space: movement only
    local fwd = key(Enum.KeyCode.W) - key(Enum.KeyCode.S)
    local str = key(Enum.KeyCode.D) - key(Enum.KeyCode.A)
    local up  = key(Enum.KeyCode.Space) * 2 - 1  -- 1 when held, -1 when not

    -- Build yaw momentum: ramps up while A/D held, decays quickly on release
    if str ~= 0 then
        yawMomentum = math.clamp(yawMomentum + str * dt / YAW_ACCEL, -1, 1)
    else
        yawMomentum = yawMomentum * math.max(0, 1 - YAW_DECAY * dt)
        if math.abs(yawMomentum) < 0.01 then yawMomentum = 0 end
    end
    cameraYaw = cameraYaw + yawMomentum * YAW_RATE * dt

    local moveDir = forward * fwd + right * str
    if moveDir.Magnitude > 1 then moveDir = moveDir.Unit end

    -- Smooth 3D velocity; space rises, releasing sinks (floor clamp is the bottom)
    local targetVel = moveDir * SPEED + Vector3.new(0, up * HOVER_BOOST, 0)
    local t = math.min(dt * ACCEL, 1)
    shipVel = shipVel + (targetVel - shipVel) * t

    -- Free 3D position; sphere surface is the floor
    local pos    = hrp.Position
    local newPos = pos + shipVel * dt
    local dx     = newPos.X - PLANET_CENTER.X
    local dz     = newPos.Z - PLANET_CENTER.Z
    local inner  = PLANET_RADIUS * PLANET_RADIUS - dx * dx - dz * dz
    local surfY  = PLANET_CENTER.Y + (inner > 0 and math.sqrt(inner) or 0)
    if newPos.Y < surfY + HOVER_HEIGHT then
        newPos = Vector3.new(newPos.X, surfY + HOVER_HEIGHT, newPos.Z)
        if shipVel.Y < 0 then
            shipVel = Vector3.new(shipVel.X, 0, shipVel.Z)
        end
    end

    local targetRoll = -ROLL_MAX * yawMomentum
    roll = roll + (targetRoll - roll) * math.min(dt * TILT_SPEED, 1)

    -- Orient ship: align along 3D forward, apply roll on top
    local shipUp = right:Cross(forward).Unit
    hrp.CFrame = CFrame.fromMatrix(newPos, right, shipUp, -forward)
              * CFrame.Angles(0, 0, roll)
    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

    -- Mining beam
    beamTimer = beamTimer - dt
    fireTimer = fireTimer - dt
    if beamActive and beamObj and beamEndAnchor then
        -- Aim point: cast camera ray through mouse cursor into the world
        local mouse  = Players.LocalPlayer:GetMouse()
        local camRay = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
        local aimResult = workspace:Raycast(camRay.Origin, camRay.Direction * 2000, rayParams)

        local aimPos
        if aimResult then
            aimPos = aimResult.Position
        else
            -- Cursor aimed at sky: fall back to sphere surface ahead of ship
            local tgtX   = newPos.X + forward.X * BEAM_RANGE
            local tgtZ   = newPos.Z + forward.Z * BEAM_RANGE
            local dx2    = tgtX - PLANET_CENTER.X
            local dz2    = tgtZ - PLANET_CENTER.Z
            local inner2 = PLANET_RADIUS * PLANET_RADIUS - dx2 * dx2 - dz2 * dz2
            aimPos = Vector3.new(tgtX,
                PLANET_CENTER.Y + (inner2 > 0 and math.sqrt(inner2) or 0), tgtZ)
        end

        beamEndAnchor.Position = aimPos
        beamObj.Enabled = true

        -- Burn light at ground contact
        if fireTimer <= 0 then
            local isGround = not (aimResult and aimResult.Instance:GetAttribute("IsDebris"))
            if isGround then
                spawnBurnLight(aimPos)
                fireTimer = 0.02
            end
        end

        -- Separate debris-only ray so the planet can't block shots to embedded chunks
        if beamTimer <= 0 and hitDebrisRemote then
            local debrisHit = workspace:Raycast(
                camRay.Origin, camRay.Direction * BEAM_RANGE * 4, debrisRayParams)
            if debrisHit then
                hitDebrisRemote:FireServer(debrisHit.Instance)
                beamTimer = BEAM_COOLDOWN
            end
        end
    elseif beamObj then
        beamObj.Enabled = false
    end

    -- Camera: behind ship + arrow-key orbit offset, always looks at ship
    local camAngle = cameraYaw + orbitYaw
    local camBack  = Vector3.new(-math.sin(camAngle), 0, math.cos(camAngle))
    local camPos   = newPos
        + camBack  * camDist * math.cos(orbitPitch)
        + Vector3.new(0, CAM_HEIGHT + camDist * math.sin(orbitPitch), 0)
    workspace.CurrentCamera.CFrame = CFrame.lookAt(camPos, newPos + Vector3.new(0, 1, 0))
end

-- ── Equip / Unequip ───────────────────────────────────────────────────────────

tool.Equipped:Connect(function()
    character = player.Character
    if not character then return end
    hrp      = character:WaitForChild("HumanoidRootPart")
    humanoid = character:WaitForChild("Humanoid")

    -- Tell MoonGravity to stand down
    inShipValue        = Instance.new("BoolValue")
    inShipValue.Name   = "InShip"
    inShipValue.Value  = true
    inShipValue.Parent = character

    humanoid.WalkSpeed = 0
    shipVel        = Vector3.new(0, 0, 0)
    roll           = 0
    yawMomentum    = 0
    orbitYaw       = 0
    orbitPitch     = 0
    beamTimer      = 0
    fireTimer      = 0
    rayParams.FilterDescendantsInstances = {character}
    debrisRayParams.FilterDescendantsInstances = {workspace:WaitForChild("Debris")}

    local remotes   = ReplicatedStorage:WaitForChild("Remotes")
    hitDebrisRemote = remotes:WaitForChild("HitDebris")

    local lv   = workspace.CurrentCamera.CFrame.LookVector
    cameraYaw  = math.atan2(lv.X, -lv.Z)
    camDist    = CAM_DIST
    rightMouseHeld = false
    workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default

    -- Right mouse: hold to yaw
    rmDownConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            rightMouseHeld = true
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        end
    end)
    rmUpConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            rightMouseHeld = false
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end)

    -- Scroll wheel zoom
    scrollConn = UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            camDist = math.clamp(camDist - input.Position.Z * 4, 8, 80)
        end
    end)

    -- Left mouse button: hold to fire mining beam
    beamMouseDownConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            beamActive = true
        end
    end)
    beamMouseUpConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            beamActive = false
        end
    end)

    showCharacter()   -- clear any stale hidden state before re-hiding
    buildShip()
    hideCharacter()

    moveConn = RunService.Heartbeat:Connect(update)
end)

tool.Unequipped:Connect(function()
    if moveConn          then moveConn:Disconnect();          moveConn          = nil end
    if scrollConn        then scrollConn:Disconnect();        scrollConn        = nil end
    if rmDownConn        then rmDownConn:Disconnect();        rmDownConn        = nil end
    if rmUpConn          then rmUpConn:Disconnect();          rmUpConn          = nil end
    if beamMouseDownConn then beamMouseDownConn:Disconnect(); beamMouseDownConn = nil end
    if beamMouseUpConn   then beamMouseUpConn:Disconnect();   beamMouseUpConn   = nil end
    beamActive     = false
    rightMouseHeld = false
    destroyShip()
    showCharacter()
    if inShipValue then inShipValue:Destroy(); inShipValue = nil end
    if humanoid    then humanoid.WalkSpeed = 32                  end
    workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    UserInputService.MouseBehavior     = Enum.MouseBehavior.Default
end)
