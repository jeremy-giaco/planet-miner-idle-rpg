-- Fleet/Client/HoverShip.client.lua
-- Equip to board the ship, unequip to exit.
-- Classic (PC): W/S = thrust | A/D = yaw | RMB = look | Scroll = zoom | LMB = beam
-- Twin-stick (mobile): left stick = thrust/strafe | right stick = camera | FIRE btn = beam

local RunService        = game:GetService("RunService")
if not RunService:IsClient() then return end
if not script.Parent:IsA("Tool") then return end
local UserInputService  = game:GetService("UserInputService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Config            = require(ReplicatedStorage:WaitForChild("Config"))
local ClientSettings    = require(ReplicatedStorage:WaitForChild("ClientSettings"))

local GROUND_Y = Config.MAP_GROUND_Y

local tool   = script.Parent
local player = Players.LocalPlayer

-- ── Constants ─────────────────────────────────────────────────────────────────

local SPEED         = 280
local HOVER_HEIGHT  = 6
local HOVER_BOOST   = 120
local ACCEL         = 8
local ROLL_MAX      = math.rad(48)
local TILT_SPEED    = 7
local MOUSE_SENS    = 0.004
local CAM_DIST      = 28
local CAM_HEIGHT    = 10
local YAW_RATE      = math.rad(150)
local YAW_ACCEL     = 0.6
local YAW_DECAY     = 3.5
local CAM_PITCH_MIN = math.rad(-70)
local CAM_PITCH_MAX = math.rad(70)
local ORBIT_SPEED   = math.rad(80)
local ORBIT_P_MIN   = math.rad(-30)
local ORBIT_P_MAX   = math.rad(75)
local BEAM_RANGE    = 100
local BEAM_COOLDOWN = 0.3
local BEAM_COL      = Color3.fromRGB(0, 220, 255)

-- Touch look sensitivity (twin-stick right stick)
local TOUCH_YAW_SENS   = math.rad(120)  -- rad/s at full deflection
local TOUCH_PITCH_SENS = math.rad(60)

-- Ship color palette
local HULL_COL  = Color3.fromRGB(35,  45,  75)
local DARK_COL  = Color3.fromRGB(22,  30,  52)
local ENG_COL   = Color3.fromRGB(80, 180, 255)
local HOVER_COL = Color3.fromRGB(50, 110, 255)

-- ── Platform detection ────────────────────────────────────────────────────────

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Resolved at equip time from ClientSettings.controlMode
-- "twin-stick" | "tap-to-fly" | "gyro" → use joystick; "classic" → mouse+keyboard
local useTwinStick = false

-- ── State ─────────────────────────────────────────────────────────────────────

local character, hrp, humanoid
local shipObjects      = {}
local inShipValue
local moveConn
local scrollConn
local rmDownConn, rmUpConn
local rightMouseHeld   = false
local lockedAimPos     = nil   -- world-space beam anchor when RMB is held
local shipVel          = Vector3.new(0, 0, 0)
local cameraYaw        = 0
local orbitYaw         = 0
local orbitPitch       = 0
local camDist          = CAM_DIST
local roll             = 0
local yawMomentum      = 0
local beamObj          = nil
local beamEndAnchor    = nil
local beamActive       = false
local beamTimer        = 0
local fireTimer        = 0
local beamMouseDownConn, beamMouseUpConn
local hitDebrisRemote
local sticks           = nil   -- VirtualJoystick handle (mobile only)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local debrisRayParams = RaycastParams.new()
debrisRayParams.FilterType = Enum.RaycastFilterType.Include

-- ── Ship model ────────────────────────────────────────────────────────────────

local function addPart(size, offset, color, mat, trans)
    local p = Instance.new("Part")
    p.Size         = size
    p.CFrame       = hrp.CFrame * CFrame.new(offset)
    p.Color        = color
    p.Material     = mat
    p.Transparency = trans or 0
    p.CanCollide   = false
    p.CastShadow   = false
    p.Anchored     = false
    p.Parent       = workspace
    local w = Instance.new("WeldConstraint")
    w.Part0 = hrp; w.Part1 = p; w.Parent = hrp
    table.insert(shipObjects, p)
    table.insert(shipObjects, w)
    return p
end

local function buildShip()
    addPart(Vector3.new(5.2, 0.65, 2.6),  Vector3.new(0, -0.7, 0),    HULL_COL, Enum.Material.Metal)
    addPart(Vector3.new(1.5, 0.52, 2.1),  Vector3.new(0, -0.72, -3.5), DARK_COL, Enum.Material.Metal)
    addPart(Vector3.new(1.7, 0.9,  1.8),  Vector3.new(0,  0.08, -1.2),
        Color3.fromRGB(150, 215, 255), Enum.Material.Glass, 0.22)
    addPart(Vector3.new(2.6, 0.1,  1.2),  Vector3.new(-3.5, -0.72, 0.6), DARK_COL, Enum.Material.Metal)
    addPart(Vector3.new(2.6, 0.1,  1.2),  Vector3.new( 3.5, -0.72, 0.6), DARK_COL, Enum.Material.Metal)
    addPart(Vector3.new(2.65, 0.09, 0.18), Vector3.new(-3.5, -0.69, 1.16), ENG_COL, Enum.Material.Neon)
    addPart(Vector3.new(2.65, 0.09, 0.18), Vector3.new( 3.5, -0.69, 1.16), ENG_COL, Enum.Material.Neon)
    addPart(Vector3.new(0.75, 0.62, 1.7), Vector3.new(-1.1, -0.58, 2.0), DARK_COL, Enum.Material.Metal)
    addPart(Vector3.new(0.75, 0.62, 1.7), Vector3.new( 1.1, -0.58, 2.0), DARK_COL, Enum.Material.Metal)
    local glL = addPart(Vector3.new(0.58, 0.58, 0.22), Vector3.new(-1.1, -0.58, 2.88), ENG_COL, Enum.Material.Neon)
    local glR = addPart(Vector3.new(0.58, 0.58, 0.22), Vector3.new( 1.1, -0.58, 2.88), ENG_COL, Enum.Material.Neon)
    local el = Instance.new("PointLight")
    el.Color = ENG_COL; el.Brightness = 3; el.Range = 16; el.Parent = glL
    table.insert(shipObjects, el)
    addPart(Vector3.new(5.0, 0.08, 2.55), Vector3.new(0, -1.06, 0), HOVER_COL, Enum.Material.Neon, 0.3)
    local hl = Instance.new("PointLight")
    hl.Color = HOVER_COL; hl.Brightness = 1.5; hl.Range = 10; hl.Parent = glR
    table.insert(shipObjects, hl)

    local att0 = Instance.new("Attachment")
    att0.Position = Vector3.new(0, -0.7, 2); att0.Parent = hrp

    beamEndAnchor = Instance.new("Part")
    beamEndAnchor.Size = Vector3.new(0.1, 0.1, 0.1)
    beamEndAnchor.Transparency = 1; beamEndAnchor.CanCollide = false
    beamEndAnchor.Anchored = true; beamEndAnchor.Parent = workspace
    local att1 = Instance.new("Attachment"); att1.Parent = beamEndAnchor

    beamObj = Instance.new("Beam")
    beamObj.Attachment0 = att0; beamObj.Attachment1 = att1
    beamObj.Width0 = 1; beamObj.Width1 = 14
    beamObj.LightEmission = 1; beamObj.LightInfluence = 0
    beamObj.Color = ColorSequence.new(BEAM_COL)
    beamObj.Transparency = NumberSequence.new(0.25)
    beamObj.Segments = 1; beamObj.FaceCamera = true
    beamObj.Enabled = false; beamObj.Parent = workspace

    table.insert(shipObjects, att0)
    table.insert(shipObjects, beamEndAnchor)
    table.insert(shipObjects, att1)
    table.insert(shipObjects, beamObj)
end

local function destroyShip()
    for _, obj in ipairs(shipObjects) do
        if obj and obj.Parent then obj:Destroy() end
    end
    shipObjects = {}; beamObj = nil; beamEndAnchor = nil
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

-- ── Burn light ────────────────────────────────────────────────────────────────

local BURN_COLOR = Color3.fromRGB(255, 55, 0)
local BURN_LIFE  = 0.6
local BURN_FADE  = 0.5

local function spawnBurnLight(pos)
    local surfPos = Vector3.new(pos.X, GROUND_Y, pos.Z)
    local p = Instance.new("Part")
    p.Size = Vector3.new(0.1, 0.1, 0.1); p.CFrame = CFrame.new(surfPos)
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false
    p.CastShadow = false; p.Transparency = 1; p.Parent = workspace
    local light = Instance.new("PointLight")
    light.Color = BURN_COLOR; light.Brightness = 1.2; light.Range = 20; light.Parent = p
    task.delay(BURN_LIFE, function()
        if not (p and p.Parent) then return end
        TweenService:Create(light, TweenInfo.new(BURN_FADE), {Brightness = 0}):Play()
        task.delay(BURN_FADE, function() if p and p.Parent then p:Destroy() end end)
    end)
end

-- ── Movement update ───────────────────────────────────────────────────────────

local function update(dt)
    if not hrp or not hrp.Parent then return end

    local fwd, str, up = 0, 0, 0

    if useTwinStick and sticks then
        -- ── Twin-stick input ──────────────────────────────────────────────────
        local lx, ly = sticks.left()
        local rx, ry = sticks.right()

        fwd = -ly   -- push stick up (negative Y) = forward
        str =  lx
        up  = sticks.rise() and 1 or -1

        -- Right stick drives camera yaw and pitch
        cameraYaw  = cameraYaw  + rx * TOUCH_YAW_SENS   * dt
        orbitPitch = math.clamp(
            orbitPitch + ry * TOUCH_PITCH_SENS * dt,
            ORBIT_P_MIN, ORBIT_P_MAX)

        beamActive = sticks.fire()
    else
        -- ── Classic keyboard/mouse input ──────────────────────────────────────
        if rightMouseHeld then
            local delta = UserInputService:GetMouseDelta()
            cameraYaw  = cameraYaw  + delta.X * MOUSE_SENS
            orbitPitch = math.clamp(orbitPitch + delta.Y * MOUSE_SENS, ORBIT_P_MIN, ORBIT_P_MAX)
        end

        local function key(k) return UserInputService:IsKeyDown(k) and 1 or 0 end
        orbitYaw   = orbitYaw + (key(Enum.KeyCode.Right) - key(Enum.KeyCode.Left)) * ORBIT_SPEED * dt
        orbitPitch = math.clamp(
            orbitPitch + (key(Enum.KeyCode.Up) - key(Enum.KeyCode.Down)) * ORBIT_SPEED * dt,
            ORBIT_P_MIN, ORBIT_P_MAX)

        fwd = key(Enum.KeyCode.W) - key(Enum.KeyCode.S)
        str = key(Enum.KeyCode.D) - key(Enum.KeyCode.A)
        up  = key(Enum.KeyCode.Space) * 2 - 1
    end

    local forward = Vector3.new(math.sin(cameraYaw), 0, -math.cos(cameraYaw))
    local right   = forward:Cross(Vector3.new(0, 1, 0)).Unit

    -- Yaw momentum (A/D or left stick X)
    if str ~= 0 then
        yawMomentum = math.clamp(yawMomentum + str * dt / YAW_ACCEL, -1, 1)
    else
        yawMomentum = yawMomentum * math.max(0, 1 - YAW_DECAY * dt)
        if math.abs(yawMomentum) < 0.01 then yawMomentum = 0 end
    end
    cameraYaw = cameraYaw + yawMomentum * YAW_RATE * dt

    local moveDir = forward * fwd + right * str
    if moveDir.Magnitude > 1 then moveDir = moveDir.Unit end

    local targetVel = moveDir * SPEED + Vector3.new(0, up * HOVER_BOOST, 0)
    local t = math.min(dt * ACCEL, 1)
    shipVel = shipVel + (targetVel - shipVel) * t

    local pos    = hrp.Position
    local newPos = pos + shipVel * dt
    if newPos.Y < GROUND_Y + HOVER_HEIGHT then
        newPos = Vector3.new(newPos.X, GROUND_Y + HOVER_HEIGHT, newPos.Z)
        if shipVel.Y < 0 then shipVel = Vector3.new(shipVel.X, 0, shipVel.Z) end
    end

    local targetRoll = -ROLL_MAX * yawMomentum
    roll = roll + (targetRoll - roll) * math.min(dt * TILT_SPEED, 1)

    local shipUp = right:Cross(forward).Unit
    hrp.CFrame = CFrame.fromMatrix(newPos, right, shipUp, -forward) * CFrame.Angles(0, 0, roll)
    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

    -- Mining beam
    beamTimer = beamTimer - dt
    fireTimer = fireTimer - dt
    if beamActive and beamObj and beamEndAnchor then
        local aimPos
        if useTwinStick then
            -- On mobile aim beam directly ahead of ship at ground level
            aimPos = Vector3.new(
                newPos.X + forward.X * BEAM_RANGE,
                GROUND_Y,
                newPos.Z + forward.Z * BEAM_RANGE
            )
        elseif rightMouseHeld then
            -- RMB held = beam stays fixed at the world position it was at when RMB was pressed
            aimPos = lockedAimPos or (newPos - forward * 15)
        else
            -- Free aim: follow mouse cursor
            local mouse  = Players.LocalPlayer:GetMouse()
            local camRay = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
            local aimResult = workspace:Raycast(camRay.Origin, camRay.Direction * 2000, rayParams)
            aimPos = aimResult and aimResult.Position or (newPos + forward * 15)
        end

        beamEndAnchor.Position = aimPos
        beamObj.Enabled = true

        if fireTimer <= 0 then
            spawnBurnLight(aimPos)
            fireTimer = 0.02
        end

        if beamTimer <= 0 and hitDebrisRemote then
            local beamDir = (aimPos - newPos).Unit
            -- Blockcast along full beam length so anything the beam passes through gets hit
            local beamLength = (aimPos - newPos).Magnitude
            local beamCF     = CFrame.lookAt(newPos, newPos + beamDir) * CFrame.new(0, 0, -beamLength / 2)
            local beamSize   = Vector3.new(0.5, 0.5, beamLength)
            local overlapParams = OverlapParams.new()
            overlapParams.FilterType = Enum.RaycastFilterType.Include
            overlapParams.FilterDescendantsInstances = {workspace:FindFirstChild("Debris")}
            local hits = workspace:GetPartBoundsInBox(beamCF, beamSize, overlapParams)
            local fired      = false
            for _, part in ipairs(hits) do
                local inst = part
                while inst and not inst:GetAttribute("IsDebris") do
                    inst = inst.Parent
                end
                if inst and inst:GetAttribute("IsDebris") then
                    hitDebrisRemote:FireServer(inst)
                    fired = true
                end
            end
            if fired then beamTimer = BEAM_COOLDOWN end
        end
    elseif beamObj then
        beamObj.Enabled = false
    end

    -- Camera
    local camAngle = cameraYaw + orbitYaw
    local camBack  = Vector3.new(-math.sin(camAngle), 0, math.cos(camAngle))
    local camPos   = newPos
        + camBack * camDist * math.cos(orbitPitch)
        + Vector3.new(0, CAM_HEIGHT + camDist * math.sin(orbitPitch), 0)
    workspace.CurrentCamera.CFrame = CFrame.lookAt(camPos, newPos + Vector3.new(0, 1, 0))
end

-- ── Equip ─────────────────────────────────────────────────────────────────────

tool.Equipped:Connect(function()
    character = player.Character
    if not character then return end
    hrp      = character:WaitForChild("HumanoidRootPart")
    humanoid = character:WaitForChild("Humanoid")

    inShipValue = Instance.new("BoolValue")
    inShipValue.Name = "InShip"; inShipValue.Value = true
    inShipValue.Parent = character

    humanoid.WalkSpeed = 0
    shipVel = Vector3.new(0, 0, 0)
    roll = 0; yawMomentum = 0; orbitYaw = 0; orbitPitch = 0
    beamTimer = 0; fireTimer = 0; beamActive = false

    rayParams.FilterDescendantsInstances = {character}
    debrisRayParams.FilterDescendantsInstances = {workspace:WaitForChild("Debris")}

    local remotes   = ReplicatedStorage:WaitForChild("Remotes")
    hitDebrisRemote = remotes:WaitForChild("HitDebris")

    local lv  = workspace.CurrentCamera.CFrame.LookVector
    cameraYaw = math.atan2(lv.X, -lv.Z)
    camDist   = CAM_DIST
    rightMouseHeld = false
    workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default

    -- Resolve control mode from settings; default to "classic" on PC, twin-stick on mobile.
    local mode = ClientSettings.controlMode or (isMobile and "twin-stick" or "classic")
    useTwinStick = (mode == "twin-stick" or mode == "tap-to-fly" or mode == "gyro")
        or (isMobile and mode == "classic")

    if useTwinStick then
        -- Spawn virtual joystick over the game UI
        local VirtualJoystick = require(ReplicatedStorage:WaitForChild("VirtualJoystick"))
        local gui = player:WaitForChild("PlayerGui")
        local sg  = Instance.new("ScreenGui")
        sg.Name = "ShipJoystickUI"; sg.ResetOnSpawn = false
        sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; sg.Parent = gui
        sticks = VirtualJoystick.create(sg)
    else
        -- Classic: right mouse look
        rmDownConn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                rightMouseHeld = true
                UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                -- Snap beam anchor to current aim position
                if beamActive and beamEndAnchor then
                    lockedAimPos = beamEndAnchor.Position
                end
            end
        end)
        rmUpConn = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                rightMouseHeld = false
                lockedAimPos   = nil
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            end
        end)
        scrollConn = UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseWheel then
                camDist = math.clamp(camDist - input.Position.Z * 4, 8, 80)
            end
        end)
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
    end

    showCharacter()
    buildShip()
    hideCharacter()
    moveConn = RunService.Heartbeat:Connect(update)
end)

-- ── Unequip ───────────────────────────────────────────────────────────────────

tool.Unequipped:Connect(function()
    if moveConn          then moveConn:Disconnect();          moveConn          = nil end
    if scrollConn        then scrollConn:Disconnect();        scrollConn        = nil end
    if rmDownConn        then rmDownConn:Disconnect();        rmDownConn        = nil end
    if rmUpConn          then rmUpConn:Disconnect();          rmUpConn          = nil end
    if beamMouseDownConn then beamMouseDownConn:Disconnect(); beamMouseDownConn = nil end
    if beamMouseUpConn   then beamMouseUpConn:Disconnect();   beamMouseUpConn   = nil end
    if sticks            then sticks.destroy();               sticks            = nil end

    -- Destroy joystick GUI
    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        local sg = gui:FindFirstChild("ShipJoystickUI")
        if sg then sg:Destroy() end
    end

    beamActive = false; rightMouseHeld = false
    destroyShip(); showCharacter()
    if inShipValue then inShipValue:Destroy(); inShipValue = nil end
    if humanoid    then humanoid.WalkSpeed = 32 end
    workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    UserInputService.MouseBehavior     = Enum.MouseBehavior.Default
end)
