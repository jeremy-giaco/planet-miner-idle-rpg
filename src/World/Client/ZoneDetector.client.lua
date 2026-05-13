-- LocalScript → StarterPlayerScripts
-- Detects which zone the player is in (by XZ distance from origin),
-- updates an AREA: label at the top of the screen, and tweens the
-- Lighting atmosphere when crossing a zone boundary.

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local TweenService  = game:GetService("TweenService")
local Lighting      = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local player = Players.LocalPlayer

-- ── Zone atmosphere data ──────────────────────────────────────────────────────

local ZONE_ATMO = {
    ["The Compound"] = {
        FogColor       = Color3.fromRGB( 12,  10,  28),
        FogEnd         = 18000,
        Ambient        = Color3.fromRGB(210, 208, 230),
        OutdoorAmbient = Color3.fromRGB(215, 213, 235),
    },
    ["The Badlands"] = {
        FogColor       = Color3.fromRGB( 50,  22,   8),
        FogEnd         = 12000,
        Ambient        = Color3.fromRGB(210, 165, 110),
        OutdoorAmbient = Color3.fromRGB(215, 170, 115),
    },
    ["The Wastes"] = {
        FogColor       = Color3.fromRGB( 30,  28,  20),
        FogEnd         = 10000,
        Ambient        = Color3.fromRGB(210, 207, 180),
        OutdoorAmbient = Color3.fromRGB(215, 212, 185),
    },
    ["The Lava Ring"] = {
        FogColor       = Color3.fromRGB( 70,  12,   4),
        FogEnd         = 5000,
        Ambient        = Color3.fromRGB(200, 100,  55),
        OutdoorAmbient = Color3.fromRGB(190,  90,  50),
    },
}

-- ── Build AREA: UI ────────────────────────────────────────────────────────────

local function buildUI()
    local pg = player:WaitForChild("PlayerGui")
    local sg = Instance.new("ScreenGui")
    sg.Name         = "ZoneUI"
    sg.ResetOnSpawn = false
    sg.Parent       = pg

    local label = Instance.new("TextLabel")
    label.Name                   = "ZoneLabel"
    label.Size                   = UDim2.new(0, 220, 0, 28)
    label.Position               = UDim2.new(1, -228, 0, 10)
    label.BackgroundTransparency = 1
    label.TextColor3             = Color3.fromRGB(200, 190, 255)
    label.TextSize               = 15
    label.Font                   = Enum.Font.GothamBold
    label.Text                   = "—"
    label.TextXAlignment         = Enum.TextXAlignment.Right
    label.TextStrokeColor3       = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0.4
    label.Parent                 = sg

    return label
end

-- ── Zone lookup ───────────────────────────────────────────────────────────────

local function getZoneName(xzDist)
    for _, zone in ipairs(Config.ZONES) do
        if xzDist <= zone.maxRadius then
            return zone.name
        end
    end
    return Config.ZONES[#Config.ZONES].name  -- outermost if beyond all
end

-- ── Atmosphere tween ──────────────────────────────────────────────────────────

local function tweenAtmo(zoneName)
    local atmo = ZONE_ATMO[zoneName]
    if not atmo then return end
    local info = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(Lighting, info, {
        FogColor       = atmo.FogColor,
        FogEnd         = atmo.FogEnd,
        Ambient        = atmo.Ambient,
        OutdoorAmbient = atmo.OutdoorAmbient,
    }):Play()
end

-- ── Zone color for label ──────────────────────────────────────────────────────

local ZONE_LABEL_COLOR = {
    ["The Compound"]  = Color3.fromRGB(180, 180, 255),
    ["The Badlands"]  = Color3.fromRGB(255, 140,  60),
    ["The Wastes"]    = Color3.fromRGB(230, 220, 160),
    ["The Lava Ring"] = Color3.fromRGB(255,  70,  30),
}

-- ── Main ─────────────────────────────────────────────────────────────────────

local zoneLabel   = buildUI()
local currentZone = nil
local checkTimer  = 0

RunService.Heartbeat:Connect(function(dt)
    checkTimer = checkTimer - dt
    if checkTimer > 0 then return end
    checkTimer = 0.5   -- check every half second

    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local p       = hrp.Position
    local xzDist  = Vector2.new(p.X, p.Z).Magnitude
    local newZone = getZoneName(xzDist)

    zoneLabel.Text       = (Config.PLANET_NAME or "Moon") .. ": " .. newZone
    zoneLabel.TextColor3 = ZONE_LABEL_COLOR[newZone] or Color3.new(1, 1, 1)

    if newZone ~= currentZone then
        currentZone = newZone
        tweenAtmo(newZone)
    end
end)
