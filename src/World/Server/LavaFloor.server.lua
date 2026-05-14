-- World/Server/LavaFloor.server.lua
-- Flat ring surface at Y=10 (sphere equator), extending outward like Saturn's rings.
-- The planet sphere (radius 1019, center Y=0) pokes up through the ring naturally.
-- Players falling off the north pole surface (Y≈1019) land on the ring.
--
-- Zones (by XZ radius from planet center):
--   Ring surface  (r = 1019 – 2800) : safe, flat, walkable
--   Danger band   (r = 2800 – 3400) : slow burn 5 HP/s
--   Death zone    (r > 3400)        : instant kill

if not game:GetService("RunService"):IsServer() then return end
if _G._LavaFloorActive then return end
_G._LavaFloorActive = true

local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local PC            = Config.PLANET_CENTER   -- (0, 0, 0)
local RING_Y        = 10
local RING_THICK    = 20    -- slab thickness

local SAFE_OUTER    = 2800
local DANGER_OUTER  = 3400
local DEATH_OUTER   = 4200

-- ── Ring surface slab (safe walkable area) ────────────────────────────────────

local ring = Instance.new("Part")
ring.Name        = "RingSurface"
ring.Shape       = Enum.PartType.Cylinder
ring.Size        = Vector3.new(RING_THICK, SAFE_OUTER * 2, SAFE_OUTER * 2)
ring.CFrame      = CFrame.new(PC.X, RING_Y, PC.Z) * CFrame.Angles(0, 0, math.rad(90))
ring.Anchored    = true
ring.CanCollide  = true
ring.CastShadow  = false
ring.Material    = Enum.Material.Basalt
ring.Color       = Color3.fromRGB(35, 30, 28)
ring.Parent      = workspace

-- ── Danger band ───────────────────────────────────────────────────────────────

local danger = Instance.new("Part")
danger.Name        = "DangerBand"
danger.Shape       = Enum.PartType.Cylinder
danger.Size        = Vector3.new(RING_THICK - 2, DANGER_OUTER * 2, DANGER_OUTER * 2)
danger.CFrame      = CFrame.new(PC.X, RING_Y - 1, PC.Z) * CFrame.Angles(0, 0, math.rad(90))
danger.Anchored    = true
danger.CanCollide  = true
danger.CastShadow  = false
danger.Material    = Enum.Material.Neon
danger.Color       = Color3.fromRGB(180, 40, 5)
danger.Parent      = workspace

local dangerLight = Instance.new("PointLight")
dangerLight.Brightness = 1.5
dangerLight.Range      = 80
dangerLight.Color      = Color3.fromRGB(220, 70, 10)
dangerLight.Parent     = danger

task.spawn(function()
    while danger.Parent do
        TweenService:Create(danger, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { Color = Color3.fromRGB(220, 70, 10) }):Play()
        task.wait(2.2)
        TweenService:Create(danger, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { Color = Color3.fromRGB(180, 40, 5) }):Play()
        task.wait(2.2)
    end
end)

-- ── Death zone ────────────────────────────────────────────────────────────────

local death = Instance.new("Part")
death.Name        = "DeathZone"
death.Shape       = Enum.PartType.Cylinder
death.Size        = Vector3.new(RING_THICK - 4, DEATH_OUTER * 2, DEATH_OUTER * 2)
death.CFrame      = CFrame.new(PC.X, RING_Y - 2, PC.Z) * CFrame.Angles(0, 0, math.rad(90))
death.Anchored    = true
death.CanCollide  = true
death.CastShadow  = false
death.Material    = Enum.Material.Neon
death.Color       = Color3.fromRGB(255, 85, 10)
death.Parent      = workspace

local deathLight = Instance.new("PointLight")
deathLight.Brightness = 3
deathLight.Range      = 140
deathLight.Color      = Color3.fromRGB(255, 130, 20)
deathLight.Parent     = death

task.spawn(function()
    while death.Parent do
        TweenService:Create(death, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { Color = Color3.fromRGB(255, 130, 20) }):Play()
        task.wait(1.8)
        TweenService:Create(death, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { Color = Color3.fromRGB(220, 50, 5) }):Play()
        task.wait(1.8)
    end
end)

-- ── Warning sign at safe zone edge ───────────────────────────────────────────

local sign = Instance.new("Part")
sign.Name        = "LavaSign"
sign.Size        = Vector3.new(0.3, 6, 14)
sign.CFrame      = CFrame.new(PC.X + SAFE_OUTER - 40, RING_Y + 13, PC.Z)
sign.Anchored    = true
sign.CanCollide  = true
sign.CastShadow  = false
sign.Material    = Enum.Material.SmoothPlastic
sign.Color       = Color3.fromRGB(30, 20, 15)
sign.Parent      = workspace

local bb = Instance.new("BillboardGui")
bb.Size        = UDim2.new(0, 340, 0, 100)
bb.StudsOffset = Vector3.new(0, 4, 0)
bb.AlwaysOnTop = false
bb.MaxDistance = 200
bb.Parent      = sign

local line1 = Instance.new("TextLabel")
line1.Text                   = "⚠  LAVA LAKE OF DEATH  ⚠"
line1.Size                   = UDim2.new(1, 0, 0.5, 0)
line1.BackgroundTransparency = 1
line1.TextColor3             = Color3.fromRGB(255, 80, 10)
line1.TextSize               = 22
line1.Font                   = Enum.Font.GothamBold
line1.TextStrokeColor3       = Color3.new(0, 0, 0)
line1.TextStrokeTransparency = 0.3
line1.Parent                 = bb

local line2 = Instance.new("TextLabel")
line2.Text                   = "No lifeguard on duty"
line2.Size                   = UDim2.new(1, 0, 0.5, 0)
line2.Position               = UDim2.new(0, 0, 0.5, 0)
line2.BackgroundTransparency = 1
line2.TextColor3             = Color3.fromRGB(220, 200, 180)
line2.TextSize               = 16
line2.Font                   = Enum.Font.GothamBold
line2.TextStrokeColor3       = Color3.new(0, 0, 0)
line2.TextStrokeTransparency = 0.4
line2.Parent                 = bb

-- ── Damage loop ───────────────────────────────────────────────────────────────

local recentlyKilled = {}
local burnAccum      = {}

RunService.Heartbeat:Connect(function(dt)
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if not char then continue end
        local hrp      = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid or humanoid.Health <= 0 then continue end

        local pos = hrp.Position
        local xzR = math.sqrt((pos.X - PC.X)^2 + (pos.Z - PC.Z)^2)

        if xzR <= SAFE_OUTER then
            burnAccum[player] = 0

        elseif xzR <= DANGER_OUTER then
            burnAccum[player] = (burnAccum[player] or 0) + 5 * dt
            if burnAccum[player] >= 1 then
                local dmg = math.floor(burnAccum[player])
                burnAccum[player] = burnAccum[player] - dmg
                humanoid.Health = math.max(0, humanoid.Health - dmg)
            end

        else
            if not recentlyKilled[player] then
                recentlyKilled[player] = true
                humanoid.Health = 0
                task.delay(3, function() recentlyKilled[player] = nil end)
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    recentlyKilled[player] = nil
    burnAccum[player]      = nil
end)

print("[LavaFloor] Saturn ring surface active at Y=" .. RING_Y)
