-- UI/Menus/SettingsMenu.client.lua
-- In-game settings panel. Toggle with ⚙ button (top-left, below drone/cargo tabs).
-- Saves changes to server immediately.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local player        = Players.LocalPlayer
local playerGui     = player:WaitForChild("PlayerGui")
local remotes       = ReplicatedStorage:WaitForChild("Remotes")
local loadSettings  = remotes:WaitForChild("LoadSettings")
local saveSettings  = remotes:WaitForChild("SaveSettings")
local ClientSettings = require(ReplicatedStorage:WaitForChild("ClientSettings"))

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ── Constants ─────────────────────────────────────────────────────────────────

local PANEL_W   = 260
local PANEL_H   = 280
local TAB_W     = 44
local TAB_H     = 44
local panelOpen = false

local BG    = Color3.fromRGB(8, 6, 22)
local NEON  = Color3.fromRGB(90, 50, 220)
local TEXT  = Color3.fromRGB(200, 190, 255)
local SEL   = Color3.fromRGB(80, 50, 180)
local UNSEL = Color3.fromRGB(25, 20, 55)

-- ── Screen GUI ────────────────────────────────────────────────────────────────

local sg = Instance.new("ScreenGui")
sg.Name = "SettingsUI"; sg.ResetOnSpawn = false; sg.Parent = playerGui

-- Gear toggle tab (left edge, below cargo tab)
local gearBtn = Instance.new("TextButton")
gearBtn.Size                   = UDim2.new(0, TAB_W, 0, TAB_H)
gearBtn.Position               = UDim2.new(0, 8, 0.5, TAB_H + 12)
gearBtn.BackgroundColor3       = Color3.fromRGB(20, 15, 55)
gearBtn.BackgroundTransparency = 0.2
gearBtn.Text                   = "⚙"
gearBtn.TextSize               = 22
gearBtn.Font                   = Enum.Font.GothamBold
gearBtn.TextColor3             = TEXT
gearBtn.BorderSizePixel        = 0
gearBtn.ZIndex                 = 10
gearBtn.Parent                 = sg
Instance.new("UICorner", gearBtn).CornerRadius = UDim.new(0, 10)
do local s = Instance.new("UIStroke")
   s.Color = NEON; s.Thickness = 1.5; s.Parent = gearBtn end

-- Panel (slides in from left)
local panel = Instance.new("Frame")
panel.Size                   = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position               = UDim2.new(0, -(PANEL_W + 20), 0.5, -(PANEL_H / 2) + TAB_H + 8)
panel.BackgroundColor3       = BG
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel        = 0
panel.Parent                 = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
do local s = Instance.new("UIStroke")
   s.Color = NEON; s.Thickness = 1.5; s.Parent = panel end

local OPEN_POS  = UDim2.new(0, TAB_W + 16, 0, 460)         -- slot 3: below cargo (252+200+8)
local CLOSE_POS = UDim2.new(0, -(PANEL_W + 20), 0, 460)
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

gearBtn.MouseButton1Click:Connect(function()
    panelOpen = not panelOpen
    TweenService:Create(panel, tweenInfo,
        { Position = panelOpen and OPEN_POS or CLOSE_POS }):Play()
end)

-- ── Panel header ──────────────────────────────────────────────────────────────

local header = Instance.new("TextLabel")
header.Text = "SETTINGS"; header.Size = UDim2.new(1, 0, 0, 28)
header.BackgroundTransparency = 1; header.TextColor3 = TEXT
header.TextSize = 13; header.Font = Enum.Font.GothamBold; header.Parent = panel

-- ── Helper: section label ─────────────────────────────────────────────────────

local function sectionLabel(text, yPos)
    local lbl = Instance.new("TextLabel")
    lbl.Text = text; lbl.Size = UDim2.new(1, -16, 0, 18)
    lbl.Position = UDim2.new(0, 8, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(140, 120, 200)
    lbl.TextSize = 10; lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = panel
end

-- ── Helper: option button row ─────────────────────────────────────────────────

local function optionRow(options, yPos, currentKey, onSelect)
    local btnW = (PANEL_W - 16) / #options
    local btns = {}
    for i, opt in ipairs(options) do
        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(0, btnW - 4, 0, 30)
        btn.Position         = UDim2.new(0, 8 + (i-1) * btnW, 0, yPos)
        btn.BackgroundColor3 = (opt.key == currentKey) and SEL or UNSEL
        btn.Text             = opt.label
        btn.TextSize         = 11
        btn.Font             = Enum.Font.GothamBold
        btn.TextColor3       = Color3.new(1, 1, 1)
        btn.BorderSizePixel  = 0
        btn.AutoButtonColor  = false
        btn.Parent           = panel
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btns[i] = btn

        btn.MouseButton1Click:Connect(function()
            for _, b in ipairs(btns) do b.BackgroundColor3 = UNSEL end
            btn.BackgroundColor3 = SEL
            onSelect(opt.key)
        end)
    end
    return btns
end

-- ── Helper: toggle ────────────────────────────────────────────────────────────

local function toggle(label, yPos, currentVal, onToggle)
    local lbl = Instance.new("TextLabel")
    lbl.Text = label; lbl.Size = UDim2.new(0.65, 0, 0, 28)
    lbl.Position = UDim2.new(0, 8, 0, yPos)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = TEXT
    lbl.TextSize = 11; lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = panel

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 60, 0, 24)
    btn.Position = UDim2.new(1, -68, 0, yPos + 2)
    btn.BackgroundColor3 = currentVal and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(80, 30, 30)
    btn.Text = currentVal and "ON" or "OFF"
    btn.TextSize = 11; btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.BorderSizePixel = 0; btn.AutoButtonColor = false; btn.Parent = panel
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local state = currentVal
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(80, 30, 30)
        btn.Text = state and "ON" or "OFF"
        onToggle(state)
    end)
end

-- ── Build UI content ──────────────────────────────────────────────────────────

local CONTROL_MODES = {
    { key = "classic",    label = "Classic"  },
    { key = "twin-stick", label = "Sticks"   },
    { key = "tap-to-fly", label = "Tap-Fly"  },
    { key = "gyro",       label = "Gyro"     },
}

sectionLabel("CONTROL MODE", 30)
optionRow(CONTROL_MODES, 50, ClientSettings.controlMode, function(key)
    ClientSettings.controlMode = key
    saveSettings:FireServer("controlMode", key)
end)

sectionLabel("INVERT Y", 92)
toggle("Invert Y-Axis", 110, ClientSettings.invertY, function(val)
    ClientSettings.invertY = val
    saveSettings:FireServer("invertY", val)
end)

-- Gyro sensitivity (only relevant on mobile)
if isMobile then
    sectionLabel("GYRO SENSITIVITY", 148)
    -- Simple - / + buttons
    local sensVal = ClientSettings.gyroSensitivity or 1.0

    local sensLabel = Instance.new("TextLabel")
    sensLabel.Size = UDim2.new(0, 60, 0, 28)
    sensLabel.Position = UDim2.new(0.5, -30, 0, 166)
    sensLabel.BackgroundTransparency = 1; sensLabel.TextColor3 = TEXT
    sensLabel.TextSize = 13; sensLabel.Font = Enum.Font.GothamBold
    sensLabel.Text = string.format("%.1f", sensVal); sensLabel.Parent = panel

    local function makeAdjBtn(label, xPos, delta)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 36, 0, 28)
        btn.Position = UDim2.new(0, xPos, 0, 166)
        btn.BackgroundColor3 = UNSEL; btn.Text = label
        btn.TextSize = 16; btn.Font = Enum.Font.GothamBold
        btn.TextColor3 = TEXT; btn.BorderSizePixel = 0
        btn.AutoButtonColor = false; btn.Parent = panel
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.MouseButton1Click:Connect(function()
            sensVal = math.clamp(sensVal + delta, 0.1, 3.0)
            sensLabel.Text = string.format("%.1f", sensVal)
            ClientSettings.gyroSensitivity = sensVal
            saveSettings:FireServer("gyroSensitivity", sensVal)
        end)
    end
    makeAdjBtn("−", 60,  -0.1)
    makeAdjBtn("+", 164,  0.1)
end

-- ── Load settings from server on join ────────────────────────────────────────

loadSettings.OnClientEvent:Connect(function(settings)
    -- Update ClientSettings cache
    for k, v in pairs(settings) do
        ClientSettings[k] = v
    end
    -- Auto-switch to twin-stick on mobile if not explicitly set
    if isMobile and ClientSettings.controlMode == "classic" then
        ClientSettings.controlMode = "twin-stick"
    end
end)

print("[SettingsMenu] Active")
