-- World/Server/LavaFloor.server.lua
-- Thin flat discs centered at Y=0 (sphere equator, radius=1019).
-- The planet sphere (opaque ball) hides the center of each disc,
-- leaving only the outer ring visible — Saturn rings effect.
--
-- Disc stack (each slightly below the last so outer bands peek out):
--   Ring surface  Y= 0  r=2800  dark basalt — safe walkable
--   Danger band   Y=-5  r=3400  cracked lava — 5 HP/s burn
--   Death zone    Y=-10 r=4200  molten lava  — instant kill

if not game:GetService("RunService"):IsServer() then return end
if _G._LavaFloorActive then return end
_G._LavaFloorActive = true

local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local PC = Config.PLANET_CENTER   -- (0, 0, 0)

local SAFE_OUTER   = 2800
local DANGER_OUTER = 3400
local DEATH_OUTER  = 4200
local SLAB_THICK   = 6

local function makeSlab(y, radius, color, material)
    local p = Instance.new("Part")
    p.Shape      = Enum.PartType.Cylinder
    p.Size       = Vector3.new(SLAB_THICK, radius * 2, radius * 2)
    p.CFrame     = CFrame.new(PC.X, y, PC.Z) * CFrame.Angles(0, 0, math.rad(90))
    p.Anchored   = true
    p.CanCollide = true
    p.CastShadow = false
    p.Material   = material
    p.Color      = color
    p.Parent     = workspace
    return p
end

-- ── Safe ring ─────────────────────────────────────────────────────────────────

local ring = makeSlab(0, SAFE_OUTER, Color3.fromRGB(35, 28, 25), Enum.Material.Basalt)
ring.Name = "RingSurface"

-- ── Danger band ───────────────────────────────────────────────────────────────

local danger = makeSlab(-5, DANGER_OUTER, Color3.fromRGB(180, 40, 5), Enum.Material.Neon)
danger.Name = "DangerBand"

local dl = Instance.new("PointLight")
dl.Brightness = 1.5; dl.Range = 80; dl.Color = Color3.fromRGB(220, 70, 10); dl.Parent = danger

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

local death = makeSlab(-10, DEATH_OUTER, Color3.fromRGB(255, 85, 10), Enum.Material.Neon)
death.Name = "DeathZone"

local deathL = Instance.new("PointLight")
deathL.Brightness = 3; deathL.Range = 140; deathL.Color = Color3.fromRGB(255, 130, 20); deathL.Parent = death

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

-- ── Warning sign ──────────────────────────────────────────────────────────────

local sign = Instance.new("Part")
sign.Name     = "LavaSign"
sign.Size     = Vector3.new(0.3, 8, 16)
sign.CFrame   = CFrame.new(PC.X + SAFE_OUTER - 40, 10, PC.Z)
sign.Anchored = true; sign.CanCollide = true; sign.CastShadow = false
sign.Material = Enum.Material.SmoothPlastic
sign.Color    = Color3.fromRGB(30, 20, 15)
sign.Parent   = workspace

local bb = Instance.new("BillboardGui")
bb.Size = UDim2.new(0, 340, 0, 100); bb.StudsOffset = Vector3.new(0, 6, 0)
bb.AlwaysOnTop = false; bb.MaxDistance = 300; bb.Parent = sign

local l1 = Instance.new("TextLabel")
l1.Text = "⚠  LAVA LAKE OF DEATH  ⚠"; l1.Size = UDim2.new(1,0,0.5,0)
l1.BackgroundTransparency = 1; l1.TextColor3 = Color3.fromRGB(255, 80, 10)
l1.TextSize = 22; l1.Font = Enum.Font.GothamBold
l1.TextStrokeColor3 = Color3.new(0,0,0); l1.TextStrokeTransparency = 0.3
l1.Parent = bb

local l2 = Instance.new("TextLabel")
l2.Text = "No lifeguard on duty"; l2.Size = UDim2.new(1,0,0.5,0)
l2.Position = UDim2.new(0,0,0.5,0); l2.BackgroundTransparency = 1
l2.TextColor3 = Color3.fromRGB(220, 200, 180); l2.TextSize = 16
l2.Font = Enum.Font.GothamBold
l2.TextStrokeColor3 = Color3.new(0,0,0); l2.TextStrokeTransparency = 0.4
l2.Parent = bb

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

print("[LavaFloor] Saturn ring surface active")
