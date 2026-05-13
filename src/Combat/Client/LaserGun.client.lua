-- LocalScript → inside the LaserGun Tool in StarterPack
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local camera    = workspace.CurrentCamera
local tool      = script.Parent
local handle    = tool:WaitForChild("Handle")
local playerGui = player:WaitForChild("PlayerGui")

local Config         = require(ReplicatedStorage:WaitForChild("Config"))
local remotes        = ReplicatedStorage:WaitForChild("Remotes")
local hitDebrisEvent = remotes:WaitForChild("HitDebris")
local debrisFolder   = workspace:WaitForChild("Debris")

local canFire  = true
local equipped = false

-- ── Camera mode detection ─────────────────────────────────────────────────────

local function isFirstPerson()
    local character = player.Character
    if not character then return false end
    local head = character:FindFirstChild("Head")
    if not head then return false end
    return (camera.CFrame.Position - head.Position).Magnitude < 1
end

-- ── Walking crosshair (1st person only) ──────────────────────────────────────

local crossGui = Instance.new("ScreenGui")
crossGui.Name         = "CrosshairHUD"
crossGui.ResetOnSpawn = false
crossGui.Enabled      = false
crossGui.Parent       = playerGui

local GREEN   = Color3.fromRGB(0, 220, 80)
local Y_OFFSET = -40

local outerRing = Instance.new("Frame")
outerRing.Size                   = UDim2.new(0, 28, 0, 28)
outerRing.Position               = UDim2.new(0.5, -14, 0.5, Y_OFFSET - 14)
outerRing.BackgroundTransparency = 1
outerRing.BorderSizePixel        = 0
outerRing.Parent                 = crossGui

local outerStroke = Instance.new("UIStroke")
outerStroke.Color     = GREEN
outerStroke.Thickness = 1.2
outerStroke.Parent    = outerRing

local outerCorner = Instance.new("UICorner")
outerCorner.CornerRadius = UDim.new(0.5, 0)
outerCorner.Parent       = outerRing

local centerDot = Instance.new("Frame")
centerDot.Size                   = UDim2.new(0, 4, 0, 4)
centerDot.Position               = UDim2.new(0.5, -2, 0.5, Y_OFFSET - 2)
centerDot.BackgroundColor3       = GREEN
centerDot.BackgroundTransparency = 0
centerDot.BorderSizePixel        = 0
centerDot.Parent                 = crossGui

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(0.5, 0)
dotCorner.Parent       = centerDot

-- ── Update mouse lock + crosshair only when mode changes ─────────────────────

local lastFirstPerson = nil

RunService.RenderStepped:Connect(function()
    if not equipped then return end
    local fp = isFirstPerson()
    if fp == lastFirstPerson then return end   -- no change, don't touch mouse
    lastFirstPerson = fp

    if fp then
        crossGui.Enabled                  = true
        UserInputService.MouseBehavior    = Enum.MouseBehavior.LockCenter
        UserInputService.MouseIconEnabled = false
    else
        crossGui.Enabled                  = false
        UserInputService.MouseBehavior    = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end
end)

tool.Equipped:Connect(function()
    equipped = true
end)
tool.Unequipped:Connect(function()
    equipped = false
    crossGui.Enabled                  = false
    UserInputService.MouseBehavior    = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
end)

-- ── Beam visual ───────────────────────────────────────────────────────────────

local function flashBeam(startPos, endPos)
    local length = (endPos - startPos).Magnitude
    if length < 0.1 then return end
    local cf = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -length / 2)

    -- Core beam
    local beam = Instance.new("Part")
    beam.Anchored    = true
    beam.CanCollide  = false
    beam.CanQuery    = false
    beam.CastShadow  = false
    beam.Size        = Vector3.new(0.35, 0.35, length)
    beam.CFrame      = cf
    beam.Material    = Enum.Material.Neon
    beam.Color       = Config.LASER_COLOR
    beam.Parent      = workspace

    -- Wide glow halo
    local glow = Instance.new("Part")
    glow.Anchored     = true
    glow.CanCollide   = false
    glow.CanQuery     = false
    glow.CastShadow   = false
    glow.Size         = Vector3.new(1.2, 1.2, length)
    glow.CFrame       = cf
    glow.Material     = Enum.Material.Neon
    glow.Color        = Config.LASER_COLOR
    glow.Transparency = 0.7
    glow.Parent       = workspace

    -- Light along beam
    local light = Instance.new("PointLight")
    light.Color      = Config.LASER_COLOR
    light.Brightness = 8
    light.Range      = 30
    light.Parent     = beam

    -- Muzzle flash
    local flash = Instance.new("Part")
    flash.Size        = Vector3.new(1.2, 1.2, 1.2)
    flash.Position    = startPos
    flash.Anchored    = true
    flash.CanCollide  = false
    flash.CastShadow  = false
    flash.Material    = Enum.Material.Neon
    flash.Color       = Color3.new(1, 1, 1)
    flash.Shape       = Enum.PartType.Ball
    flash.Parent      = workspace

    -- Impact flash at hit point
    local impact = Instance.new("Part")
    impact.Size        = Vector3.new(1.5, 1.5, 1.5)
    impact.Position    = endPos
    impact.Anchored    = true
    impact.CanCollide  = false
    impact.CastShadow  = false
    impact.Material    = Enum.Material.Neon
    impact.Color       = Config.LASER_COLOR
    impact.Shape       = Enum.PartType.Ball
    impact.Parent      = workspace

    task.delay(0.18, function()
        if beam   and beam.Parent   then beam:Destroy()   end
        if glow   and glow.Parent   then glow:Destroy()   end
        if flash  and flash.Parent  then flash:Destroy()  end
        if impact and impact.Parent then impact:Destroy() end
    end)
end

-- ── Fire ──────────────────────────────────────────────────────────────────────

local function fire()
    if not canFire then return end
    local character = player.Character
    if not character then return end
    if not tool.Parent:IsA("Model") then return end

    canFire = false

    -- Shoot toward mouse cursor in both 1st and 3rd person
    local mouse  = player:GetMouse()
    local camRay = camera:ScreenPointToRay(mouse.X, mouse.Y)

    -- Aim ray from camera: shoot far in cursor direction for visual endpoint
    local aimPos = camRay.Origin + camRay.Direction * Config.LASER_RANGE

    -- Damage ray from handle toward cursor direction, only sees Debris folder
    local aimDir = camRay.Direction  -- use camera direction directly, avoids offset issues
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = {debrisFolder}
    local result = workspace:Raycast(camRay.Origin, aimDir * Config.LASER_RANGE, params)

    local hitPos = result and result.Position or aimPos
    flashBeam(handle.Position, hitPos)

    if result and result.Instance then
        local inst = result.Instance
        -- Walk up to the debris chunk root if we hit a child
        while inst and not inst:GetAttribute("IsDebris") do
            inst = inst.Parent
        end
        if inst and inst:GetAttribute("IsDebris") then
            hitDebrisEvent:FireServer(inst)
        end
    end

    task.delay(Config.LASER_COOLDOWN, function() canFire = true end)
end

-- ── Input ─────────────────────────────────────────────────────────────────────

-- tool.Activated fires when clicking while the tool is held (reliable in all modes)
tool.Activated:Connect(fire)

-- InputBegan as backup for cases where Activated doesn't fire (e.g. empty space)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and equipped then
        fire()
    end
end)
