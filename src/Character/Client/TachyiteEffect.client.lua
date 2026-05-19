-- LocalScript → StarterPlayerScripts/TachyiteEffect
-- Manages Tachyite speed-buff stacks, single shared timer, and HUD countdown.
-- Sets _G.TachyiteBonus (number) = stacks * TACHYITE_SPEED_BONUS for MovementToggle.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Config  = require(ReplicatedStorage:WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local tachyitePickup  = remotes:WaitForChild("TachyitePickup")
local configUpdated   = remotes:WaitForChild("ConfigUpdated")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

_G.TachyiteBonus = 0

-- ── Live config helper ────────────────────────────────────────────────────────

local liveConfig = {}
local function live(key)
    return liveConfig[key] or Config[key]
end
configUpdated.OnClientEvent:Connect(function(key, value)
    liveConfig[key] = value
end)

-- ── HUD: countdown label ──────────────────────────────────────────────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "TachyiteHUD"
screenGui.ResetOnSpawn    = false
screenGui.IgnoreGuiInset  = false
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.Parent          = playerGui

-- Background pill
local bg = Instance.new("Frame")
bg.Name            = "TachyiteBuff"
bg.Size            = UDim2.new(0, 180, 0, 44)
bg.Position        = UDim2.new(0.5, -90, 0, 70)   -- below top bar
bg.BackgroundColor3 = Color3.fromRGB(20, 30, 60)
bg.BackgroundTransparency = 0.25
bg.BorderSizePixel = 0
bg.Visible         = false
bg.Parent          = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent       = bg

local stroke = Instance.new("UIStroke")
stroke.Color     = Color3.fromRGB(60, 130, 255)
stroke.Thickness = 2
stroke.Parent    = bg

-- Icon orb glyph
local icon = Instance.new("TextLabel")
icon.Size              = UDim2.new(0, 36, 1, 0)
icon.Position          = UDim2.new(0, 4, 0, 0)
icon.BackgroundTransparency = 1
icon.Text              = "⚡"
icon.TextColor3        = Color3.fromRGB(100, 180, 255)
icon.TextScaled        = true
icon.Font              = Enum.Font.GothamBold
icon.Parent            = bg

-- Stack count
local stackLabel = Instance.new("TextLabel")
stackLabel.Name            = "Stacks"
stackLabel.Size            = UDim2.new(0, 50, 1, 0)
stackLabel.Position        = UDim2.new(0, 42, 0, 0)
stackLabel.BackgroundTransparency = 1
stackLabel.Text            = "x1"
stackLabel.TextColor3      = Color3.fromRGB(255, 255, 255)
stackLabel.TextScaled      = true
stackLabel.Font            = Enum.Font.GothamBold
stackLabel.TextXAlignment  = Enum.TextXAlignment.Left
stackLabel.Parent          = bg

-- Countdown
local timerLabel = Instance.new("TextLabel")
timerLabel.Name            = "Timer"
timerLabel.Size            = UDim2.new(0, 76, 1, 0)
timerLabel.Position        = UDim2.new(0, 96, 0, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.Text            = "3:00"
timerLabel.TextColor3      = Color3.fromRGB(140, 200, 255)
timerLabel.TextScaled      = true
timerLabel.Font            = Enum.Font.Gotham
timerLabel.TextXAlignment  = Enum.TextXAlignment.Right
timerLabel.Parent          = bg

-- ── State ─────────────────────────────────────────────────────────────────────

local stacks      = 0
local timeLeft    = 0    -- seconds remaining
local timerActive = false

local function formatTime(s)
    local m = math.floor(s / 60)
    local sec = math.floor(s % 60)
    return string.format("%d:%02d", m, sec)
end

local function applyBonus()
    _G.TachyiteBonus = stacks * live("TACHYITE_SPEED_BONUS")
end

local function expireBuff()
    stacks            = 0
    timeLeft          = 0
    timerActive       = false
    _G.TachyiteBonus  = 0
    bg.Visible        = false
end

-- ── Pickup handler ────────────────────────────────────────────────────────────

tachyitePickup.OnClientEvent:Connect(function(newStackCount)
    stacks      = newStackCount
    timeLeft    = live("TACHYITE_DURATION")
    timerActive = true
    applyBonus()
    bg.Visible         = true
    stackLabel.Text    = "x" .. stacks
    timerLabel.Text    = formatTime(timeLeft)

    -- Flash the border briefly on pickup
    stroke.Color = Color3.fromRGB(255, 255, 255)
    task.delay(0.2, function()
        stroke.Color = Color3.fromRGB(60, 130, 255)
    end)
end)

-- ── Countdown tick ────────────────────────────────────────────────────────────

RunService.Heartbeat:Connect(function(dt)
    if not timerActive then return end
    timeLeft = timeLeft - dt
    if timeLeft <= 0 then
        expireBuff()
        return
    end
    timerLabel.Text = formatTime(timeLeft)
    -- Pulse color red when under 30s
    if timeLeft < 30 then
        local t = math.abs(math.sin(tick() * 3))
        timerLabel.TextColor3 = Color3.fromRGB(255, math.floor(60 + t*60), math.floor(60 + t*60))
    else
        timerLabel.TextColor3 = Color3.fromRGB(140, 200, 255)
    end
end)

print("[TachyiteEffect] Active")
