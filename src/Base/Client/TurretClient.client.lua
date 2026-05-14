-- LocalScript → place in StarterPlayerScripts, rename to "TurretClient"
local RunService        = game:GetService("RunService")
if not RunService:IsClient() then return end
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local camera    = workspace.CurrentCamera
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for turret parts
local turret    = workspace:WaitForChild("Turret", 15)
if not turret then return end
local seat      = turret:WaitForChild("GunnerSeat")
local eyePt     = turret:WaitForChild("EyePoint")
local barrel    = turret:WaitForChild("Barrel")
local barrelTip = turret:WaitForChild("BarrelTip")
local pivot     = turret:WaitForChild("BarrelPivot")

local remotes        = ReplicatedStorage:WaitForChild("Remotes")
local hitDebrisEvent = remotes:WaitForChild("HitDebris")

local isSeated   = false
local yaw        = 0
local pitch      = 0
local MAX_PITCH  =  50
local MIN_PITCH  = -20

-- Store default barrel transforms relative to pivot
local BARREL_OFFSET  = CFrame.new(0, 0, -2.5)   -- barrel center behind pivot
local TIP_OFFSET     = CFrame.new(0, 0, -5.0)   -- tip further out

-- ── HUD ──────────────────────────────────────────────────────────────────────

local scopeGui = Instance.new("ScreenGui")
scopeGui.Name         = "ScopeHUD"
scopeGui.ResetOnSpawn = false
scopeGui.Enabled      = false
scopeGui.Parent       = playerGui

local GREEN     = Color3.fromRGB(0, 220, 80)
local GREEN_DIM = Color3.fromRGB(0, 120, 50)
local Y_OFFSET  = -40  -- pixels above screen center to match laser aim point

-- Full-screen dark vignette
local vignette = Instance.new("Frame")
vignette.Size                   = UDim2.new(1, 0, 1, 0)
vignette.BackgroundColor3       = Color3.fromRGB(0, 12, 4)
vignette.BackgroundTransparency = 0.35
vignette.BorderSizePixel        = 0
vignette.Parent                 = scopeGui

-- Dark oval mask (simulates circular scope — crop the corners dark)
-- Scope ring (main targeting circle outline)
local scopeSize = UDim2.new(0, 540, 0, 540)
local scopePos  = UDim2.new(0.5, -270, 0.5, -270)

local scopeRing = Instance.new("Frame")
scopeRing.Name                   = "ScopeRing"
scopeRing.Size                   = scopeSize
scopeRing.Position               = scopePos
scopeRing.BackgroundTransparency = 1
scopeRing.BorderSizePixel        = 0
scopeRing.Parent                 = scopeGui

local ringStroke = Instance.new("UIStroke")
ringStroke.Color     = GREEN
ringStroke.Thickness = 2
ringStroke.Parent    = scopeRing

local ringCorner = Instance.new("UICorner")
ringCorner.CornerRadius = UDim.new(0.5, 0)
ringCorner.Parent       = scopeRing

-- Inner targeting circle (smaller, tighter)
local innerRing = Instance.new("Frame")
innerRing.Size                   = UDim2.new(0, 80, 0, 80)
innerRing.Position               = UDim2.new(0.5, -40, 0.5, Y_OFFSET - 40)
innerRing.BackgroundTransparency = 1
innerRing.BorderSizePixel        = 0
innerRing.Parent                 = scopeGui

local innerStroke = Instance.new("UIStroke")
innerStroke.Color     = GREEN
innerStroke.Thickness = 1.5
innerStroke.Parent    = innerRing

local innerCorner = Instance.new("UICorner")
innerCorner.CornerRadius = UDim.new(0.5, 0)
innerCorner.Parent       = innerRing

-- Center dot
local dot = Instance.new("Frame")
dot.Size                   = UDim2.new(0, 5, 0, 5)
dot.Position               = UDim2.new(0.5, -2.5, 0.5, Y_OFFSET - 2.5)
dot.BackgroundColor3       = GREEN
dot.BackgroundTransparency = 0
dot.BorderSizePixel        = 0
dot.Parent                 = scopeGui

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(0.5, 0)
dotCorner.Parent       = dot

-- Crosshair lines (4 lines with gap in center)
local GAP = 22  -- pixels of gap from center
local LINE_LEN = 30
local LINE_W   = 1.5

local crossDefs = {
    -- top
    { size = UDim2.new(0, LINE_W, 0, LINE_LEN), pos = UDim2.new(0.5, -LINE_W/2, 0.5, Y_OFFSET - (GAP + LINE_LEN)) },
    -- bottom
    { size = UDim2.new(0, LINE_W, 0, LINE_LEN), pos = UDim2.new(0.5, -LINE_W/2, 0.5, Y_OFFSET + GAP) },
    -- left
    { size = UDim2.new(0, LINE_LEN, 0, LINE_W), pos = UDim2.new(0.5, -(GAP + LINE_LEN), 0.5, Y_OFFSET - LINE_W/2) },
    -- right
    { size = UDim2.new(0, LINE_LEN, 0, LINE_W), pos = UDim2.new(0.5,  GAP, 0.5, Y_OFFSET - LINE_W/2) },
}
for _, d in ipairs(crossDefs) do
    local line = Instance.new("Frame")
    line.Size                   = d.size
    line.Position               = d.pos
    line.BackgroundColor3       = GREEN
    line.BackgroundTransparency = 0
    line.BorderSizePixel        = 0
    line.Parent                 = scopeGui
end

-- Compass bracket marks (L-shapes at N/S/E/W on the main ring)
-- Each bracket = two thin rectangles forming an L, placed at the ring edge
local R = 270  -- radius of the ring in pixels
local BKT_LEN = 22
local BKT_W   = 1.5

local bracketDefs = {
    -- North: top of circle
    { { UDim2.new(0, BKT_W,   0, BKT_LEN), UDim2.new(0.5, -BKT_W/2,    0.5, -(R + BKT_LEN)) },
      { UDim2.new(0, BKT_LEN, 0, BKT_W),   UDim2.new(0.5, -BKT_LEN/2,  0.5, -R) } },
    -- South
    { { UDim2.new(0, BKT_W,   0, BKT_LEN), UDim2.new(0.5, -BKT_W/2,    0.5,  R) },
      { UDim2.new(0, BKT_LEN, 0, BKT_W),   UDim2.new(0.5, -BKT_LEN/2,  0.5,  R) } },
    -- West
    { { UDim2.new(0, BKT_LEN, 0, BKT_W),   UDim2.new(0.5, -(R + BKT_LEN), 0.5, -BKT_W/2) },
      { UDim2.new(0, BKT_W,   0, BKT_LEN), UDim2.new(0.5, -R,              0.5, -BKT_LEN/2) } },
    -- East
    { { UDim2.new(0, BKT_LEN, 0, BKT_W),   UDim2.new(0.5,  R,              0.5, -BKT_W/2) },
      { UDim2.new(0, BKT_W,   0, BKT_LEN), UDim2.new(0.5,  R,              0.5, -BKT_LEN/2) } },
}
for _, bkt in ipairs(bracketDefs) do
    for _, seg in ipairs(bkt) do
        local f = Instance.new("Frame")
        f.Size                   = seg[1]
        f.Position               = seg[2]
        f.BackgroundColor3       = GREEN
        f.BackgroundTransparency = 0
        f.BorderSizePixel        = 0
        f.Parent                 = scopeGui
    end
end

-- Scan line (animated horizontal line that sweeps downward)
local scanLine = Instance.new("Frame")
scanLine.Size                   = UDim2.new(1, 0, 0, 1)
scanLine.Position               = UDim2.new(0, 0, 0, 0)
scanLine.BackgroundColor3       = GREEN_DIM
scanLine.BackgroundTransparency = 0.6
scanLine.BorderSizePixel        = 0
scanLine.Parent                 = scopeGui

-- Corner text labels (immersion)
local function cornerLabel(text, anchorX, anchorY, posX, posY)
    local lbl = Instance.new("TextLabel")
    lbl.Text                 = text
    lbl.Size                 = UDim2.new(0, 120, 0, 16)
    lbl.Position             = UDim2.new(posX, 0, posY, 0)
    lbl.AnchorPoint          = Vector2.new(anchorX, anchorY)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3           = GREEN_DIM
    lbl.TextSize             = 11
    lbl.Font                 = Enum.Font.Code
    lbl.TextXAlignment       = anchorX == 0 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
    lbl.Parent               = scopeGui
end
cornerLabel("SYS: ONLINE",  0, 0, 0.02, 0.04)
cornerLabel("TURRET MK-I",  1, 0, 0.98, 0.04)
cornerLabel("PWR: 100%",    0, 1, 0.02, 0.96)
cornerLabel("E = EXIT",     1, 1, 0.98, 0.96)

-- ── Character visibility toggle ───────────────────────────────────────────────

local function setCharVis(visible)
    for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") then
            d.LocalTransparencyModifier = visible and 0 or 1
        end
    end
end

-- ── Sit / stand detection ─────────────────────────────────────────────────────

humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
    if humanoid.SeatPart == seat then
        isSeated = true
        -- Initialise yaw from current camera look direction
        yaw   = math.deg(math.atan2(-camera.CFrame.LookVector.X, -camera.CFrame.LookVector.Z))
        pitch = 0
        camera.CameraType = Enum.CameraType.Scriptable
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        setCharVis(false)
        scopeGui.Enabled = true
    else
        isSeated = false
        camera.CameraType = Enum.CameraType.Custom
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        setCharVis(true)
        scopeGui.Enabled = false
    end
end)

-- E key exits turret
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.E and isSeated then
        humanoid.Jump = true
    end
end)

-- ── Fire while seated ─────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not isSeated then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {character, turret}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local origin    = camera.CFrame.Position
    local direction = camera.CFrame.LookVector * 600

    local result = workspace:Raycast(origin, direction, params)

    -- Beam
    local hitPos = result and result.Position or (origin + direction)
    local beamLen = (hitPos - barrelTip.Position).Magnitude
    local beam = Instance.new("Part")
    beam.Name        = "LaserBeam"
    beam.Anchored    = true
    beam.CanCollide  = false
    beam.CanQuery    = false
    beam.CastShadow  = false
    beam.Size        = Vector3.new(0.1, 0.1, beamLen)
    beam.CFrame      = CFrame.lookAt(barrelTip.Position, hitPos) * CFrame.new(0, 0, -beamLen/2)
    beam.Material    = Enum.Material.Neon
    beam.Color       = Color3.fromRGB(0, 230, 120)
    beam.Parent      = workspace
    task.delay(0.08, function() if beam and beam.Parent then beam:Destroy() end end)

    if result and result.Instance and result.Instance:GetAttribute("IsDebris") then
        hitDebrisEvent:FireServer(result.Instance)
    end
end)

-- ── RenderStepped: camera + barrel tracking + scan line ─────────────────────

local scanY = 0
RunService.RenderStepped:Connect(function(dt)
    if not isSeated then return end

    -- Read mouse delta and accumulate yaw/pitch
    local delta = UserInputService:GetMouseDelta()
    yaw   = yaw   - delta.X * 0.25
    pitch = math.clamp(pitch - delta.Y * 0.25, MIN_PITCH, MAX_PITCH)

    -- Build camera CFrame at eye position
    local cf = CFrame.new(eyePt.Position)
        * CFrame.Angles(0, math.rad(yaw), 0)
        * CFrame.Angles(math.rad(pitch), 0, 0)
    camera.CFrame = cf

    -- Rotate barrel parts to match (client-side visual only)
    local pivotCF = CFrame.new(pivot.Position)
        * CFrame.Angles(0, math.rad(yaw), 0)
        * CFrame.Angles(math.rad(pitch), 0, 0)
    barrel.CFrame    = pivotCF * BARREL_OFFSET
    barrelTip.CFrame = pivotCF * TIP_OFFSET

    -- Animate scan line
    scanY = (scanY + dt * 80) % 600
    scanLine.Position = UDim2.new(0, 0, 0, scanY)
end)
