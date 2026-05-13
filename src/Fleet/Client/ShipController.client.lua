-- LocalScript → StarterPlayerScripts
-- Handles entering/exiting the player's personal ship via ProximityPrompt (E key).
-- When inside: full ship flight controls. Exit with E again.

local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Config            = require(ReplicatedStorage:WaitForChild("Config"))
local ClientSettings    = require(ReplicatedStorage:WaitForChild("ClientSettings"))

local PLANET_RADIUS = Config.PLANET_RADIUS
local PLANET_CENTER = Config.PLANET_CENTER

local player    = Players.LocalPlayer
local shipsFolder = workspace:WaitForChild("PlayerShips")

-- ── Constants ─────────────────────────────────────────────────────────────────

local SPEED         = 280
local HOVER_HEIGHT  = 14   -- R=1024: sphere curves ~12 st below flat floor at bay doors; 14 gives safe margin
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

local TOUCH_YAW_SENS   = math.rad(120)
local TOUCH_PITCH_SENS = math.rad(60)

local HULL_COL  = Color3.fromRGB(35,  45,  75)
local DARK_COL  = Color3.fromRGB(22,  30,  52)
local ENG_COL   = Color3.fromRGB(80, 180, 255)
local HOVER_COL = Color3.fromRGB(50, 110, 255)

-- ── State ─────────────────────────────────────────────────────────────────────

local inShip           = false
local shipModel        = nil   -- the world Model
local shipRoot         = nil   -- ShipRoot Part (used as HRP while flying)
local character, hrp, humanoid
local shipObjects      = {}
local moveConn, scrollConn
local rmDownConn, rmUpConn
local rightMouseHeld   = false
local lockedAimPos     = nil
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
local hitDebrisRemote
local sticks           = nil
local useTwinStick     = false
local cockpitMode      = false
local camToggleConn    = nil
local shipHudGui       = nil
local hudSpeed, hudAlt, hudCamMode
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local debrisRayParams = RaycastParams.new()
debrisRayParams.FilterType = Enum.RaycastFilterType.Include

-- ── Ship visual parts (welded to ShipRoot) ────────────────────────────────────

local function addPart(size, offset, color, mat, trans)
    local p = Instance.new("Part")
    p.Size         = size
    p.CFrame       = shipRoot.CFrame * CFrame.new(offset)
    p.Color        = color
    p.Material     = mat
    p.Transparency = trans or 0
    p.CanCollide   = false
    p.CastShadow   = false
    p.Anchored     = false
    p.Parent       = workspace
    local w = Instance.new("WeldConstraint")
    w.Part0 = shipRoot; w.Part1 = p; w.Parent = shipRoot
    table.insert(shipObjects, p)
    table.insert(shipObjects, w)
    return p
end

local function buildShipVisual()
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
    att0.Position = Vector3.new(0, -0.7, 2); att0.Parent = shipRoot

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

local function destroyShipVisual()
    for _, obj in ipairs(shipObjects) do
        if typeof(obj) == "RBXScriptConnection" then
            obj:Disconnect()
        elseif obj and obj.Parent then
            obj:Destroy()
        end
    end
    shipObjects = {}; beamObj = nil; beamEndAnchor = nil
end

-- ── Character visibility ──────────────────────────────────────────────────────

local savedTrans = {}

local function hideCharacter()
    if not character then return end
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
    local lp = Instance.new("Part")
    lp.Anchored = true; lp.CanCollide = false; lp.Transparency = 1
    lp.Size = Vector3.new(0.1, 0.1, 0.1); lp.Position = pos; lp.Parent = workspace
    local pl = Instance.new("PointLight")
    pl.Color = BURN_COLOR; pl.Brightness = 8; pl.Range = 30; pl.Parent = lp
    task.delay(BURN_LIFE - BURN_FADE, function()
        if not lp.Parent then return end
        local tw = TweenService:Create(pl, TweenInfo.new(BURN_FADE), {Brightness = 0})
        tw:Play(); tw.Completed:Connect(function() lp:Destroy() end)
    end)
end

-- ── Ship HUD ─────────────────────────────────────────────────────────────────

local function buildShipHud()
    local gui = player:WaitForChild("PlayerGui")
    local sg  = Instance.new("ScreenGui")
    sg.Name = "ShipHUD"; sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; sg.Parent = gui

    local BG   = Color3.fromRGB(6, 8, 20)
    local TEXT = Color3.fromRGB(140, 210, 255)

    local panel = Instance.new("Frame")
    panel.Size                   = UDim2.new(0, 160, 0, 70)
    panel.Position               = UDim2.new(1, -168, 0, 8)
    panel.BackgroundColor3       = BG
    panel.BackgroundTransparency = 0.3
    panel.BorderSizePixel        = 0
    panel.Parent                 = sg
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
    do local s = Instance.new("UIStroke")
       s.Color = Color3.fromRGB(60, 150, 255); s.Thickness = 1; s.Parent = panel end

    local function row(yOff, labelText)
        local lbl = Instance.new("TextLabel")
        lbl.Size                   = UDim2.new(1, -8, 0, 20)
        lbl.Position               = UDim2.new(0, 4, 0, yOff)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3             = TEXT
        lbl.TextSize               = 12
        lbl.Font                   = Enum.Font.RobotoMono
        lbl.Text                   = labelText
        lbl.TextXAlignment         = Enum.TextXAlignment.Left
        lbl.Parent                 = panel
        return lbl
    end

    hudSpeed   = row(4,  "SPD   ---")
    hudAlt     = row(24, "ALT   ---")
    hudCamMode = row(44, "CAM   CHASE  [V]")
    shipHudGui = sg
end

local function destroyShipHud()
    if shipHudGui then shipHudGui:Destroy(); shipHudGui = nil end
    hudSpeed = nil; hudAlt = nil; hudCamMode = nil
end

-- ── Enter / Exit ──────────────────────────────────────────────────────────────

local function enterShip()
    character = player.Character
    if not character then return end
    hrp      = character:WaitForChild("HumanoidRootPart")
    humanoid = character:WaitForChild("Humanoid")

    -- Teleport character inside ship (invisible)
    showCharacter()
    hideCharacter()
    hrp.CFrame = shipRoot.CFrame * CFrame.new(0, 2, 0)

    -- Tag so other scripts know we're in ship
    local tag = Instance.new("BoolValue")
    tag.Name = "InShip"; tag.Value = true; tag.Parent = character

    -- Unanchor and disable collision while flying (CFrame-driven, no physics needed)
    shipRoot.CanCollide = false
    shipRoot.Anchored   = false
    shipRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

    -- Hide prompt while flying so it can't be accidentally clicked
    local prompt = shipRoot:FindFirstChildOfClass("ProximityPrompt")
    if prompt then prompt.Enabled = false end

    -- Snap camera yaw to current
    local lv = workspace.CurrentCamera.CFrame.LookVector
    cameraYaw = math.atan2(lv.X, -lv.Z)
    camDist = CAM_DIST; orbitPitch = math.rad(18); rightMouseHeld = false
    workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default

    -- Resolve control mode
    local mode = ClientSettings.controlMode or "classic"
    useTwinStick = (mode == "twin-stick" or mode == "tap-to-fly" or mode == "gyro")
        or (isMobile and mode == "classic")

    -- Remotes
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    hitDebrisRemote = remotes:WaitForChild("HitDebris")
    rayParams.FilterDescendantsInstances = {character, shipModel}
    debrisRayParams.FilterDescendantsInstances = {workspace:WaitForChild("Debris")}

    buildShipVisual()

    -- Classic mouse controls
    if not useTwinStick then
        rmDownConn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                rightMouseHeld = true
                UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                if beamActive and beamEndAnchor then
                    lockedAimPos = beamEndAnchor.Position
                end
            end
        end)
        rmUpConn = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                rightMouseHeld = false; lockedAimPos = nil
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            end
        end)
        scrollConn = UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseWheel then
                camDist = math.clamp(camDist - input.Position.Z * 4, 0, 80)
            end
        end)
        -- Beam LMB
        local beamDownConn, beamUpConn
        beamDownConn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                beamActive = true; beamTimer = 0
            end
        end)
        beamUpConn = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                beamActive = false
            end
        end)
        table.insert(shipObjects, beamDownConn)
        table.insert(shipObjects, beamUpConn)
    else
        local VirtualJoystick = require(ReplicatedStorage:WaitForChild("VirtualJoystick"))
        local gui = player:WaitForChild("PlayerGui")
        local sg  = Instance.new("ScreenGui")
        sg.Name = "ShipJoystickUI"; sg.ResetOnSpawn = false
        sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; sg.Parent = gui
        sticks = VirtualJoystick.create(sg)
    end

    -- V key: toggle cockpit ↔ chase camera
    cockpitMode = false
    camToggleConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.V and inShip then
            cockpitMode = not cockpitMode
            camDist = cockpitMode and 0 or CAM_DIST
        end
    end)

    buildShipHud()
    inShip = true
end

local function exitShip()
    inShip = false

    -- Remove InShip tag
    if character then
        local tag = character:FindFirstChild("InShip")
        if tag then tag:Destroy() end
    end

    -- Tell server to close the hangar door
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local shipExitedRemote = remotes:FindFirstChild("ShipExited")
    if shipExitedRemote then shipExitedRemote:FireServer() end

    -- Re-anchor and restore collision so ship sits properly when parked
    shipRoot.CanCollide = true
    shipRoot.Anchored   = true

    -- Reset camera
    workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default

    -- Disconnect controls
    if rmDownConn    then rmDownConn:Disconnect();    rmDownConn    = nil end
    if rmUpConn      then rmUpConn:Disconnect();      rmUpConn      = nil end
    if scrollConn    then scrollConn:Disconnect();    scrollConn    = nil end
    if moveConn      then moveConn:Disconnect();      moveConn      = nil end
    if camToggleConn then camToggleConn:Disconnect(); camToggleConn = nil end
    destroyShipHud()

    -- Destroy joystick if mobile
    if sticks then sticks.destroy(); sticks = nil end
    local sg = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("ShipJoystickUI")
    if sg then sg:Destroy() end

    -- Show character, teleport out of ship
    showCharacter()
    if hrp and shipRoot then
        hrp.CFrame = shipRoot.CFrame * CFrame.new(0, 6, -8)
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end

    -- Re-enable prompt so player can re-enter
    local prompt = shipRoot:FindFirstChildOfClass("ProximityPrompt")
    if prompt then prompt.Enabled = true; prompt.ActionText = "Enter Ship" end

    beamActive = false; rightMouseHeld = false; lockedAimPos = nil
    destroyShipVisual()

    -- Reset ship state
    shipVel = Vector3.new(0, 0, 0); roll = 0; yawMomentum = 0
    orbitYaw = 0; orbitPitch = 0; camDist = CAM_DIST
end

-- ── Flight loop ───────────────────────────────────────────────────────────────

RunService.Heartbeat:Connect(function(dt)
    if not inShip or not shipRoot or not hrp then return end

    local newPos = shipRoot.Position
    local up     = (newPos - PLANET_CENTER).Unit

    -- ── Input ─────────────────────────────────────────────────────────────────
    local fwd, str, upInput = 0, 0, 0

    if useTwinStick and sticks then
        local lx, ly = sticks.left()
        local rx, ry = sticks.right()
        fwd = -ly; str = lx
        cameraYaw  = cameraYaw  + rx * TOUCH_YAW_SENS  * dt
        orbitPitch = math.clamp(orbitPitch + ry * TOUCH_PITCH_SENS * dt, ORBIT_P_MIN, ORBIT_P_MAX)
        if sticks.fire() then beamActive = true; beamTimer = 0 else beamActive = false end
        if sticks.rise() then upInput = 1 end
    else
        -- RMB: yaw ship + tilt camera + feed roll (original feel)
        if rightMouseHeld then
            local delta = UserInputService:GetMouseDelta()
            cameraYaw  = cameraYaw  + delta.X * MOUSE_SENS
            orbitPitch = math.clamp(orbitPitch + delta.Y * MOUSE_SENS, ORBIT_P_MIN, ORBIT_P_MAX)
            -- RMB horizontal drag also drives roll (same as A/D momentum)
            yawMomentum = math.clamp(yawMomentum + delta.X * MOUSE_SENS / YAW_ACCEL, -1, 1)
        end
        -- Arrow keys: orbit camera independently
        local function key(k) return UserInputService:IsKeyDown(k) and 1 or 0 end
        orbitYaw   = orbitYaw + (key(Enum.KeyCode.Right) - key(Enum.KeyCode.Left)) * ORBIT_SPEED * dt
        orbitPitch = math.clamp(
            orbitPitch + (key(Enum.KeyCode.Up) - key(Enum.KeyCode.Down)) * ORBIT_SPEED * dt,
            ORBIT_P_MIN, ORBIT_P_MAX)

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then fwd =  1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then fwd = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then str = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then str =  1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then upInput = 1 end
    end

    -- ── Orientation ───────────────────────────────────────────────────────────
    local forward = Vector3.new(math.sin(cameraYaw), 0, -math.cos(cameraYaw))
    local right   = forward:Cross(Vector3.new(0, 1, 0)).Unit

    -- Yaw momentum (original formula: normalized [-1,1] * YAW_RATE)
    if str ~= 0 then
        yawMomentum = math.clamp(yawMomentum + str * dt / YAW_ACCEL, -1, 1)
    else
        yawMomentum = yawMomentum * math.max(0, 1 - YAW_DECAY * dt)
        if math.abs(yawMomentum) < 0.01 then yawMomentum = 0 end
    end
    cameraYaw = cameraYaw + yawMomentum * YAW_RATE * dt

    -- Target velocity
    local moveDir = forward * fwd + right * str
    if moveDir.Magnitude > 1 then moveDir = moveDir.Unit end
    local upVal = upInput > 0 and 1 or -1
    local targetVel = moveDir * SPEED + Vector3.new(0, upVal * HOVER_BOOST, 0)
    shipVel = shipVel + (targetVel - shipVel) * math.min(dt * ACCEL, 1)

    -- Hover: simple floor clamp (original feel)
    local dx    = newPos.X - PLANET_CENTER.X
    local dz    = newPos.Z - PLANET_CENTER.Z
    local inner = PLANET_RADIUS * PLANET_RADIUS - dx * dx - dz * dz
    local surfY = PLANET_CENTER.Y + (inner > 0 and math.sqrt(inner) or 0)

    -- Roll
    local targetRoll = -ROLL_MAX * yawMomentum
    roll = roll + (targetRoll - roll) * math.min(dt * TILT_SPEED, 1)

    local newPos2 = newPos + shipVel * dt
    -- Radial floor clamp — works anywhere on the sphere, not just north pole
    local fromCenter = newPos2 - PLANET_CENTER
    local radialDist = fromCenter.Magnitude
    local radialUp   = fromCenter.Unit
    local minDist    = PLANET_RADIUS + HOVER_HEIGHT
    if radialDist < minDist then
        newPos2 = PLANET_CENTER + radialUp * minDist
        local inward = shipVel:Dot(radialUp)
        if inward < 0 then shipVel = shipVel - radialUp * inward end
    end

    local shipUp = right:Cross(forward).Unit
    shipRoot.CFrame = CFrame.fromMatrix(newPos2, right, shipUp, -forward) * CFrame.Angles(0, 0, roll)
    shipRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

    local up2 = radialUp

    -- Keep character welded inside ship (invisible)
    hrp.CFrame = shipRoot.CFrame * CFrame.new(0, 2, 0)
    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

    -- ── Beam ─────────────────────────────────────────────────────────────────
    beamTimer = beamTimer - dt
    fireTimer = fireTimer - dt
    if beamActive and beamObj and beamEndAnchor then
        local aimPos
        if useTwinStick then
            local tgtX   = newPos2.X + forward.X * BEAM_RANGE
            local tgtZ   = newPos2.Z + forward.Z * BEAM_RANGE
            local dx2    = tgtX - PLANET_CENTER.X
            local dz2    = tgtZ - PLANET_CENTER.Z
            local inner2 = PLANET_RADIUS * PLANET_RADIUS - dx2 * dx2 - dz2 * dz2
            aimPos = Vector3.new(tgtX, PLANET_CENTER.Y + (inner2 > 0 and math.sqrt(inner2) or 0), tgtZ)
        elseif rightMouseHeld then
            aimPos = lockedAimPos or (newPos2 - forward * 15)
        else
            local mouse  = Players.LocalPlayer:GetMouse()
            local camRay = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
            local aimResult = workspace:Raycast(camRay.Origin, camRay.Direction * 2000, rayParams)
            aimPos = aimResult and aimResult.Position or (newPos2 + forward * 15)
        end

        beamEndAnchor.Position = aimPos
        beamObj.Enabled = true

        if fireTimer <= 0 then spawnBurnLight(aimPos); fireTimer = 0.02 end

        if beamTimer <= 0 and hitDebrisRemote then
            local beamDir
            if rightMouseHeld then
                beamDir = (PLANET_CENTER - newPos2).Unit
            else
                local mouse  = Players.LocalPlayer:GetMouse()
                local camRay = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
                beamDir = camRay.Direction
            end
            local castLen = BEAM_RANGE * 4
            local beamCF  = CFrame.lookAt(newPos2, newPos2 + beamDir) * CFrame.new(0, 0, -castLen / 2)
            local beamSize = Vector3.new(0.6, 0.6, castLen)
            local overlapParams = OverlapParams.new()
            overlapParams.FilterType = Enum.RaycastFilterType.Include
            overlapParams.FilterDescendantsInstances = {workspace:FindFirstChild("Debris")}
            local hits = workspace:GetPartBoundsInBox(beamCF, beamSize, overlapParams)
            local fired = false; local seen = {}
            for _, part in ipairs(hits) do
                local inst = part
                while inst and not inst:GetAttribute("IsDebris") do inst = inst.Parent end
                if inst and inst:GetAttribute("IsDebris") and not seen[inst] then
                    seen[inst] = true; hitDebrisRemote:FireServer(inst); fired = true
                end
            end
            if fired then beamTimer = BEAM_COOLDOWN end
        end
    elseif beamObj then
        beamObj.Enabled = false
    end

    -- ── Camera ────────────────────────────────────────────────────────────────
    local FP_DIST  = 3
    local camAngle = cameraYaw + orbitYaw
    local camBack  = Vector3.new(-math.sin(camAngle), 0, math.cos(camAngle))
    if camDist <= FP_DIST then
        -- First person cockpit view
        local cockpitPos = newPos2 + forward * (-1.5) + up2 * 1.4
        local shipRight  = forward:Cross(up2).Unit
        local cockpitUp  = shipRight:Cross(forward).Unit
        workspace.CurrentCamera.CFrame = CFrame.fromMatrix(cockpitPos, shipRight, cockpitUp, -forward)
    else
        local camPos = newPos2
            + camBack * camDist * math.cos(orbitPitch)
            + Vector3.new(0, CAM_HEIGHT + camDist * math.sin(orbitPitch), 0)
        workspace.CurrentCamera.CFrame = CFrame.lookAt(camPos, newPos2 + Vector3.new(0, 1, 0))
    end

    -- ── HUD update ────────────────────────────────────────────────────────────
    if hudSpeed then
        local spd = math.floor(shipVel.Magnitude + 0.5)
        local fromCenter2 = newPos2 - PLANET_CENTER
        local alt = math.floor(math.max(0, fromCenter2.Magnitude - PLANET_RADIUS) + 0.5)
        hudSpeed.Text   = string.format("SPD   %3d st/s", spd)
        hudAlt.Text     = string.format("ALT   %3d st",   alt)
        hudCamMode.Text = "CAM   " .. (camDist <= FP_DIST and "COCKPIT" or "CHASE  [V]")
    end
end)

-- ── Wait for ship and wire prompt ─────────────────────────────────────────────

local function wireShip(ship)
    shipModel = ship
    shipRoot  = ship:WaitForChild("ShipRoot")

    local prompt = shipRoot:WaitForChild("ProximityPrompt")
    prompt.Triggered:Connect(function()
        if not inShip then
            enterShip()
        else
            exitShip()
        end
    end)
end

-- Wait for our ship to appear
local function findMyShip()
    local ship = shipsFolder:FindFirstChild(player.Name .. "_Ship")
    if ship then
        wireShip(ship)
    else
        shipsFolder.ChildAdded:Connect(function(child)
            if child.Name == player.Name .. "_Ship" then
                wireShip(child)
            end
        end)
    end
end

findMyShip()

-- E key exits ship (prompt is hidden while flying to prevent accidental clicks)
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.E and inShip then
        exitShip()
    end
end)

-- Also re-wire on character respawn (in case ship respawned too)
player.CharacterAdded:Connect(function(char)
    character = char
    if inShip then exitShip() end
end)

print("[ShipController] Active")
