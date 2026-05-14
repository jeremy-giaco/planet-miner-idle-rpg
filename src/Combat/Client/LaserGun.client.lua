-- LocalScript → inside the LaserGun Tool in StarterPack
local RunService        = game:GetService("RunService")
if not RunService:IsClient() then return end
if not script.Parent:IsA("Tool") then return end
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local camera    = workspace.CurrentCamera
local tool      = script.Parent
local handle    = tool:WaitForChild("Handle")
local playerGui = player:WaitForChild("PlayerGui")

local Config         = require(ReplicatedStorage:WaitForChild("Config"))
local remotes        = ReplicatedStorage:WaitForChild("Remotes")
local hitDebrisEvent = remotes:WaitForChild("HitDebris")
local debrisFolder   = workspace:WaitForChild("Debris")

local canFire     = true
local equipped    = false
local pendingKill = {}   -- instances fired at but not yet replicated-destroyed

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

-- ── Burn light ────────────────────────────────────────────────────────────────

local BURN_COLOR = Color3.fromRGB(255, 55, 0)

local function spawnBurnLight(pos)
    local lp = Instance.new("Part")
    lp.Anchored = true; lp.CanCollide = false; lp.Transparency = 1
    lp.Size = Vector3.new(0.1, 0.1, 0.1); lp.Position = pos; lp.Parent = workspace
    local pl = Instance.new("PointLight")
    pl.Color = BURN_COLOR; pl.Brightness = 8; pl.Range = 30; pl.Parent = lp
    task.delay(0.1, function()
        if not lp.Parent then return end
        TweenService:Create(pl, TweenInfo.new(0.5), {Brightness = 0}):Play()
        task.delay(0.5, function() if lp.Parent then lp:Destroy() end end)
    end)
end

-- ── Beam visual ───────────────────────────────────────────────────────────────

local function flashBeam(startPos, endPos)
    local length = (endPos - startPos).Magnitude
    if length < 0.1 then return end
    local cf = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -length / 2)

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

    local light = Instance.new("PointLight")
    light.Color      = Config.LASER_COLOR
    light.Brightness = 8
    light.Range      = 30
    light.Parent     = beam

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

    task.delay(0.05, function()
        if beam   and beam.Parent   then beam:Destroy()   end
        if glow   and glow.Parent   then glow:Destroy()   end
        if flash  and flash.Parent  then flash:Destroy()  end
        if impact and impact.Parent then impact:Destroy() end
    end)
end

-- ── Fire animations ───────────────────────────────────────────────────────────

local recoilInfo  = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local recoverInfo = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local turnInfo    = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local defaultC0 = {}

local function getMotor(character, name)
    return character:FindFirstChild(name, true)
end

local function cacheDefaults(character)
    defaultC0 = {}
    for _, name in ipairs({"RightShoulder", "Neck", "Waist"}) do
        local m = getMotor(character, name)
        if m and m.ClassName == "Motor6D" then
            defaultC0[name] = m.C0
        end
    end
end

tool.Equipped:Connect(function()
    local character = player.Character
    if character then cacheDefaults(character) end
end)

local function animateFire(hitPos)
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Arm recoil
    local shoulder = getMotor(character, "RightShoulder")
    if shoulder and shoulder.ClassName == "Motor6D" and defaultC0["RightShoulder"] then
        local orig = defaultC0["RightShoulder"]
        TweenService:Create(shoulder, recoilInfo,  { C0 = orig * CFrame.Angles(-math.rad(25), 0, 0) }):Play()
        task.delay(0.06, function()
            TweenService:Create(shoulder, recoverInfo, { C0 = orig }):Play()
        end)
    end

    -- Torso + head turn toward target
    local toTarget = hitPos - hrp.Position
    local localDir = hrp.CFrame:VectorToObjectSpace(toTarget)
    local yaw      = math.clamp(math.atan2(localDir.X, -localDir.Z), -math.rad(70), math.rad(70))
    local flatDist = math.sqrt(localDir.X^2 + localDir.Z^2)
    local pitch    = math.clamp(-math.atan2(localDir.Y, flatDist), -math.rad(40), math.rad(40))

    if not defaultC0["Waist"] or not defaultC0["Neck"] then
        cacheDefaults(character)
    end

    local waist = getMotor(character, "Waist")
    local neck  = getMotor(character, "Neck")

    if waist and waist.ClassName == "Motor6D" and defaultC0["Waist"] then
        local orig = defaultC0["Waist"]
        TweenService:Create(waist, turnInfo,    { C0 = orig * CFrame.Angles(0, -yaw * 0.5, 0) }):Play()
        task.delay(0.18, function()
            TweenService:Create(waist, recoverInfo, { C0 = orig }):Play()
        end)
    end

    if neck and neck.ClassName == "Motor6D" and defaultC0["Neck"] then
        local orig = defaultC0["Neck"]
        TweenService:Create(neck, turnInfo,    { C0 = orig * CFrame.Angles(-yaw * 0.7, 0, pitch * 0.6) }):Play()
        task.delay(0.18, function()
            TweenService:Create(neck, recoverInfo, { C0 = orig }):Play()
        end)
    end
end

-- ── Fire ──────────────────────────────────────────────────────────────────────

local function fire()
    if not canFire then return end
    if not equipped then return end
    local character = player.Character
    if not character then return end

    canFire = false

    local mouse  = player:GetMouse()
    local camRay = camera:ScreenPointToRay(mouse.X, mouse.Y)

    local VISUAL_RANGE = 400
    local aimPos = camRay.Origin + camRay.Direction * VISUAL_RANGE

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = {debrisFolder}
    local result = workspace:Raycast(camRay.Origin, camRay.Direction * Config.LASER_RANGE, params)

    local hitPos = result and result.Position or aimPos
    animateFire(hitPos)

    -- Barrel tip with velocity correction so beam leads character movement
    local tipRef  = tool:FindFirstChild("BarrelTip")
    local basePos = (tipRef and tipRef.Value and tipRef.Value.Parent)
        and tipRef.Value.Position
        or handle.CFrame.Position
    local hrp     = character:FindFirstChild("HumanoidRootPart")
    local vel     = hrp and hrp.AssemblyLinearVelocity or Vector3.zero
    local startPos = basePos + vel * (vel.Magnitude / 3000)
    flashBeam(startPos, hitPos)
    spawnBurnLight(hitPos)

    -- Primary: Include-filter raycast (only hits CanQuery=true parts in Debris folder)
    local inst = result and result.Instance
    if inst then
        while inst and not inst:GetAttribute("IsDebris") do
            inst = inst.Parent
        end
    end

    -- Fallback: second raycast with Exclude filter (skips character + non-debris)
    -- This catches chunks that mouse.Target would see but the Include ray misses.
    if not (inst and inst:GetAttribute("IsDebris")) then
        local exParams = RaycastParams.new()
        exParams.FilterType = Enum.RaycastFilterType.Exclude
        exParams.FilterDescendantsInstances = { player.Character }
        local r2 = workspace:Raycast(camRay.Origin, camRay.Direction * Config.LASER_RANGE, exParams)
        if r2 and r2.Instance then
            local i2 = r2.Instance
            while i2 and not i2:GetAttribute("IsDebris") do
                i2 = i2.Parent
            end
            if i2 and i2:GetAttribute("IsDebris") then
                inst = i2
            end
        end
    end

    -- Skip chunks we already fired at (server destroy hasn't replicated yet)
    if inst and pendingKill[inst] then inst = nil end

    if inst and inst:GetAttribute("IsDebris") then
        pendingKill[inst] = true
        -- Clear after replication window; instance will be gone by then anyway
        task.delay(0.5, function() pendingKill[inst] = nil end)
        hitDebrisEvent:FireServer(inst)
    end

    task.delay(Config.LASER_COOLDOWN, function() canFire = true end)
end

-- ── Input ─────────────────────────────────────────────────────────────────────

tool.Activated:Connect(function()
    fire()
end)
