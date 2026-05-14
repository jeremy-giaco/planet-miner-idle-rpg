-- LocalScript → EnergyShield Tool (StarterPack)
-- Equip to raise a protective energy bubble.
-- Automatically destroys any debris that enters the shield radius.
-- Energy drains per hit; recharges while unequipped.

local RunService        = game:GetService("RunService")
if not RunService:IsClient() then return end
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local tool   = script.Parent
local player = Players.LocalPlayer

local SHIELD_RADIUS   = 5     -- studs — bubble size
local ENERGY_MAX      = 100
local ENERGY_DRAIN    = 22    -- per debris chunk destroyed
local RECHARGE_RATE   = 12    -- energy per second while unequipped
local SHOOT_INTERVAL  = 0.12  -- seconds between auto-shots

local SHIELD_COLOR = Color3.fromRGB(80, 200, 255)
local HIT_COLOR    = Color3.fromRGB(255, 100, 100)

local remotes      = ReplicatedStorage:WaitForChild("Remotes")
local hitDebrisEvent = remotes:WaitForChild("HitDebris")

local character, hrp

local energy       = ENERGY_MAX
local active       = false
local pulseT       = 0
local shootTimer   = 0

local outerSphere, innerSphere, shieldLight
local shieldParts  = {}

local moveConn, rechargeConn
local energyFill, energyLabel, shieldFrame

-- ── Bubble visuals ────────────────────────────────────────────────────────────

local function makeSphere(radius, color, transparency)
    local p = Instance.new("Part")
    p.Shape       = Enum.PartType.Ball
    p.Size        = Vector3.new(radius * 2, radius * 2, radius * 2)
    p.CFrame      = hrp.CFrame
    p.Color       = color
    p.Material    = Enum.Material.Neon
    p.Transparency = transparency
    p.CanCollide  = false
    p.CastShadow  = false
    p.Anchored    = false
    p.Parent      = workspace
    local w = Instance.new("WeldConstraint")
    w.Part0 = hrp; w.Part1 = p; w.Parent = hrp
    table.insert(shieldParts, p)
    table.insert(shieldParts, w)
    return p
end

local function buildBubble()
    shieldParts = {}
    outerSphere = makeSphere(SHIELD_RADIUS,
        SHIELD_COLOR, 0.80)
    innerSphere = makeSphere(SHIELD_RADIUS - 1.5,
        Color3.fromRGB(120, 220, 255), 0.93)

    shieldLight = Instance.new("PointLight")
    shieldLight.Color      = SHIELD_COLOR
    shieldLight.Brightness = 2.5
    shieldLight.Range      = SHIELD_RADIUS * 2.5
    shieldLight.Parent     = outerSphere
    table.insert(shieldParts, shieldLight)
end

local function destroyBubble()
    for _, obj in ipairs(shieldParts) do
        if obj and obj.Parent then obj:Destroy() end
    end
    shieldParts  = {}
    outerSphere  = nil
    innerSphere  = nil
    shieldLight  = nil
end

-- ── Flash on hit ──────────────────────────────────────────────────────────────

local function flashShield()
    if not outerSphere or not outerSphere.Parent then return end
    outerSphere.Color       = HIT_COLOR
    outerSphere.Transparency = 0.35
    if shieldLight then shieldLight.Color = HIT_COLOR end
    task.delay(0.12, function()
        if outerSphere and outerSphere.Parent then
            outerSphere.Color       = SHIELD_COLOR
            outerSphere.Transparency = 0.80
            if shieldLight then shieldLight.Color = SHIELD_COLOR end
        end
    end)
end

-- ── Energy UI ─────────────────────────────────────────────────────────────────

local function buildEnergyUI()
    local pg = player:WaitForChild("PlayerGui")
    local sg = Instance.new("ScreenGui")
    sg.Name         = "ShieldUI"
    sg.ResetOnSpawn = false
    sg.Parent       = pg

    shieldFrame = Instance.new("Frame")
    shieldFrame.Size                   = UDim2.new(0, 180, 0, 38)
    shieldFrame.Position               = UDim2.new(0, 12, 1, -60)
    shieldFrame.BackgroundColor3       = Color3.fromRGB(6, 14, 28)
    shieldFrame.BackgroundTransparency = 0.25
    shieldFrame.BorderSizePixel        = 0
    shieldFrame.Parent                 = sg
    Instance.new("UICorner", shieldFrame).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke")
    stroke.Color = SHIELD_COLOR; stroke.Thickness = 1.5; stroke.Parent = shieldFrame

    local lbl = Instance.new("TextLabel")
    lbl.Text = "SHIELD"; lbl.Size = UDim2.new(1, 0, 0, 14)
    lbl.Position = UDim2.new(0, 0, 0, 3)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = SHIELD_COLOR
    lbl.TextSize = 10; lbl.Font = Enum.Font.GothamBold
    lbl.Parent = shieldFrame

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0.88, 0, 0, 9)
    bg.Position = UDim2.new(0.06, 0, 0, 20)
    bg.BackgroundColor3 = Color3.fromRGB(10, 20, 35)
    bg.BackgroundTransparency = 0.2; bg.BorderSizePixel = 0
    bg.Parent = shieldFrame
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

    energyFill = Instance.new("Frame")
    energyFill.Name = "Fill"; energyFill.Size = UDim2.new(1, 0, 1, 0)
    energyFill.BackgroundColor3 = SHIELD_COLOR; energyFill.BorderSizePixel = 0
    energyFill.Parent = bg
    Instance.new("UICorner", energyFill).CornerRadius = UDim.new(1, 0)

    energyLabel = Instance.new("TextLabel")
    energyLabel.Name = "Pct"; energyLabel.Text = "100%"
    energyLabel.Size = UDim2.new(1, 0, 0, 9); energyLabel.Position = UDim2.new(0, 0, 1, 1)
    energyLabel.BackgroundTransparency = 1
    energyLabel.TextColor3 = Color3.fromRGB(120, 190, 255)
    energyLabel.TextSize = 8; energyLabel.Font = Enum.Font.Gotham
    energyLabel.Parent = bg

    return sg
end

local shieldGui

local function updateEnergyUI()
    if not energyFill then return end
    local t = math.clamp(energy / ENERGY_MAX, 0, 1)
    energyFill.Size             = UDim2.new(t, 0, 1, 0)
    energyFill.BackgroundColor3 = Color3.fromRGB(
        math.floor(SHIELD_COLOR.R * 255 * t + 220 * (1 - t)),
        math.floor(SHIELD_COLOR.G * 255 * t +  60 * (1 - t)),
        math.floor(SHIELD_COLOR.B * 255 * t +  60 * (1 - t))
    )
    if energyLabel then
        energyLabel.Text = string.format("%d%%", math.floor(t * 100))
    end
    -- Pulse the UIStroke when low
    if shieldFrame then
        local stroke2 = shieldFrame:FindFirstChildOfClass("UIStroke")
        if stroke2 then
            stroke2.Color = t < 0.25 and HIT_COLOR or SHIELD_COLOR
        end
    end
end

-- ── Deactivate (energy depleted or unequipped) ────────────────────────────────

local function deactivate()
    active = false
    if moveConn then moveConn:Disconnect(); moveConn = nil end
    destroyBubble()

    -- Start recharging
    if rechargeConn then rechargeConn:Disconnect() end
    rechargeConn = RunService.Heartbeat:Connect(function(dt)
        if energy >= ENERGY_MAX then
            energy = ENERGY_MAX
            updateEnergyUI()
            rechargeConn:Disconnect(); rechargeConn = nil
            return
        end
        energy = math.min(ENERGY_MAX, energy + RECHARGE_RATE * dt)
        updateEnergyUI()
    end)
end

-- ── Main update ───────────────────────────────────────────────────────────────

local function update(dt)
    if not hrp or not hrp.Parent then return end
    if not active then return end

    -- Pulse outer shell
    pulseT += dt * 2.5
    if outerSphere and outerSphere.Parent then
        outerSphere.Transparency = 0.78 + 0.07 * math.abs(math.sin(pulseT))
    end

    -- Auto-destroy nearby debris
    shootTimer = math.max(0, shootTimer - dt)
    if shootTimer > 0 then return end

    local debrisFolder = workspace:FindFirstChild("Debris")
    if not debrisFolder then return end

    local pos = hrp.Position
    for _, chunk in ipairs(debrisFolder:GetChildren()) do
        if chunk:IsA("BasePart") and chunk:GetAttribute("IsDebris") then
            local contactDist = SHIELD_RADIUS + chunk.Size.X * 0.5
            if (chunk.Position - pos).Magnitude < contactDist then
                hitDebrisEvent:FireServer(chunk)
                if not chunk.Anchored then
                    energy = math.max(0, energy - ENERGY_DRAIN)
                    updateEnergyUI()
                    flashShield()
                end
                shootTimer = SHOOT_INTERVAL
                if energy <= 0 then
                    deactivate()
                    return
                end
                break  -- one target per interval
            end
        end
    end
end

-- ── Equip / Unequip ───────────────────────────────────────────────────────────

tool.Equipped:Connect(function()
    character = player.Character
    if not character then return end
    hrp = character:WaitForChild("HumanoidRootPart")

    -- Stop any recharge in progress (we're now active)
    if rechargeConn then rechargeConn:Disconnect(); rechargeConn = nil end

    if not shieldGui then
        shieldGui = buildEnergyUI()
    end
    updateEnergyUI()

    if energy <= 0 then return end  -- depleted, can't activate

    active     = true
    pulseT     = 0
    shootTimer = 0
    buildBubble()
    moveConn = RunService.Heartbeat:Connect(update)
end)

tool.Unequipped:Connect(function()
    deactivate()
end)
