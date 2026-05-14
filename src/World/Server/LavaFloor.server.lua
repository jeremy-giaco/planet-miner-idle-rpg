-- World/Server/LavaFloor.server.lua
-- Tiered ring system below the playable surface (Y≈1019).
-- Players falling off the main surface drop through three zones:
--
--   Zone 1 — Obsidian Crust  (Y=880, r≤1300) — safe, walkable outer ring
--   Zone 2 — Cracked Lava   (Y=720, r≤1900) — slow burn (5 HP/s)
--   Zone 3 — Molten Core    (Y=520, r≤2600) — instant death
--
-- Each zone is a full cylinder at a lower Y than the one inside it, so
-- the inner disk "floats" above the outer one, exposing the ring edge.
-- Players can jetpack between rings; falling takes them progressively deeper.

if not game:GetService("RunService"):IsServer() then return end
if _G._LavaFloorActive then return end
_G._LavaFloorActive = true

local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local PC = Config.PLANET_CENTER   -- (0, 0, 0)

-- ── Zone definitions ──────────────────────────────────────────────────────────

local ZONES = {
    {
        name      = "Obsidian",
        y         = 880,
        radius    = 2200,
        colorA    = Color3.fromRGB(28,  22,  22),
        colorB    = Color3.fromRGB(45,  30,  28),
        neon      = false,
        material  = Enum.Material.Basalt,
        lightBri  = 0,
        damage    = 0,     -- safe
    },
    {
        name      = "CrackedLava",
        y         = 720,
        radius    = 1900,
        colorA    = Color3.fromRGB(180,  40,   5),
        colorB    = Color3.fromRGB(220,  70,  10),
        neon      = true,
        material  = Enum.Material.Neon,
        lightBri  = 1.5,
        lightRange= 80,
        damage    = 5,     -- HP per second
    },
    {
        name      = "MoltenCore",
        y         = 520,
        radius    = 2600,
        colorA    = Color3.fromRGB(255,  85,  10),
        colorB    = Color3.fromRGB(255, 130,  20),
        neon      = true,
        material  = Enum.Material.Neon,
        lightBri  = 3,
        lightRange= 140,
        damage    = math.huge,   -- instant kill
    },
}

-- ── Build rings ───────────────────────────────────────────────────────────────

local ringParts = {}

for _, zone in ipairs(ZONES) do
    local part = Instance.new("Part")
    part.Name        = "LavaZone_" .. zone.name
    part.Shape       = Enum.PartType.Cylinder
    part.Size        = Vector3.new(30, zone.radius * 2, zone.radius * 2)
    part.CFrame      = CFrame.new(PC.X, zone.y, PC.Z) * CFrame.Angles(0, 0, math.rad(90))
    part.Anchored    = true
    part.CanCollide  = true
    part.CastShadow  = false
    part.Material    = zone.material
    part.Color       = zone.colorA
    part.Parent      = workspace

    if zone.lightBri and zone.lightBri > 0 then
        local light = Instance.new("PointLight")
        light.Brightness = zone.lightBri
        light.Range      = zone.lightRange or 100
        light.Color      = zone.colorB
        light.Parent     = part
    end

    -- Slow pulse for lava zones
    if zone.neon then
        task.spawn(function()
            while part.Parent do
                TweenService:Create(part, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    { Color = zone.colorB }):Play()
                task.wait(2.2)
                TweenService:Create(part, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    { Color = zone.colorA }):Play()
                task.wait(2.2)
            end
        end)
    end

    table.insert(ringParts, { part = part, zone = zone })
end

-- ── Lava sign on the obsidian ring edge ──────────────────────────────────────

local sign = Instance.new("Part")
sign.Name        = "LavaSign"
sign.Size        = Vector3.new(0.3, 6, 14)
sign.CFrame      = CFrame.new(PC.X + 2160, 886, PC.Z)  -- just inside obsidian edge
sign.Anchored    = true
sign.CanCollide  = true
sign.CastShadow  = false
sign.Material    = Enum.Material.SmoothPlastic
sign.Color       = Color3.fromRGB(30, 20, 15)
sign.Parent      = workspace

local bb = Instance.new("BillboardGui")
bb.Size                  = UDim2.new(0, 340, 0, 100)
bb.StudsOffset           = Vector3.new(0, 4, 0)
bb.AlwaysOnTop           = false
bb.MaxDistance           = 200
bb.Parent                = sign

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
-- Checks each player's XZ radius each frame to determine zone damage.
-- Zone 3 (instant kill) also handled here for consistency.

local recentlyKilled = {}
local burnAccum      = {}   -- [player] accumulated burn seconds

RunService.Heartbeat:Connect(function(dt)
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid or humanoid.Health <= 0 then continue end

        local pos = hrp.Position
        local xzRadius = math.sqrt((pos.X - PC.X)^2 + (pos.Z - PC.Z)^2)

        -- Determine which zone the player is in based on XZ radius and Y
        local activeZone = nil
        for i = #ZONES, 1, -1 do
            local z = ZONES[i]
            if xzRadius <= z.radius and pos.Y <= z.y + 35 then
                activeZone = z
                break
            end
        end

        if not activeZone or activeZone.damage == 0 then
            burnAccum[player] = 0
            continue
        end

        if activeZone.damage == math.huge then
            -- Instant kill
            if not recentlyKilled[player] then
                recentlyKilled[player] = true
                humanoid.Health = 0
                task.delay(3, function() recentlyKilled[player] = nil end)
            end
        else
            -- Slow burn
            burnAccum[player] = (burnAccum[player] or 0) + activeZone.damage * dt
            if burnAccum[player] >= 1 then
                local dmg = math.floor(burnAccum[player])
                burnAccum[player] = burnAccum[player] - dmg
                humanoid.Health = math.max(0, humanoid.Health - dmg)
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    recentlyKilled[player] = nil
    burnAccum[player]      = nil
end)

print("[LavaFloor] Three-zone lava ring system active")
