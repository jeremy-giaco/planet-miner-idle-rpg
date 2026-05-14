-- World/Server/LavaFloor.server.lua
-- Spawns a lava ocean below the playable surface.
-- Any player or character that touches it is killed and respawned at spawn.
if not game:GetService("RunService"):IsServer() then return end
if _G._LavaFloorActive then return end
_G._LavaFloorActive = true

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

-- Place lava well below the sphere surface. Planet center is Y=0, radius=1019,
-- so north-pole surface = Y≈1019. Lava sits at Y=550 — reachable only by falling.
local LAVA_Y      = 550
local LAVA_RADIUS = 2200   -- wide enough to catch any fall direction

-- ── Build lava plane ──────────────────────────────────────────────────────────

local lava = Instance.new("Part")
lava.Name        = "LavaOcean"
lava.Shape       = Enum.PartType.Cylinder
lava.Size        = Vector3.new(40, LAVA_RADIUS * 2, LAVA_RADIUS * 2)
lava.CFrame      = CFrame.new(Config.PLANET_CENTER.X, LAVA_Y, Config.PLANET_CENTER.Z)
               * CFrame.Angles(0, 0, math.rad(90))   -- lay cylinder flat
lava.Anchored    = true
lava.CanCollide  = true
lava.CastShadow  = false
lava.Material    = Enum.Material.Neon
lava.Color       = Color3.fromRGB(255, 80, 10)
lava.Parent      = workspace

-- Subtle glow
local light = Instance.new("PointLight")
light.Brightness = 3
light.Range      = 120
light.Color      = Color3.fromRGB(255, 100, 20)
light.Parent     = lava

-- Slow pulse so it feels alive
task.spawn(function()
    while lava.Parent do
        TweenService:Create(lava, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { Color = Color3.fromRGB(220, 50, 5) }):Play()
        task.wait(1.8)
        TweenService:Create(lava, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { Color = Color3.fromRGB(255, 100, 20) }):Play()
        task.wait(1.8)
    end
end)

-- ── Kill on touch ─────────────────────────────────────────────────────────────

local recentlyKilled = {}   -- debounce so we don't fire twice per character

lava.Touched:Connect(function(hit)
    local char = hit.Parent
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    local player = Players:GetPlayerFromCharacter(char)
    if not player then return end
    if recentlyKilled[player] then return end

    recentlyKilled[player] = true
    humanoid.Health = 0   -- triggers normal Roblox respawn

    task.delay(3, function()
        recentlyKilled[player] = nil
    end)
end)

print("[LavaFloor] Lava ocean active at Y=" .. LAVA_Y)
