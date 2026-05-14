-- LocalScript → StarterGui, rename to "DroneUI"
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes           = ReplicatedStorage:WaitForChild("Remotes")
local setDroneModeEvent = remotes:WaitForChild("SetDroneMode")
local droneHealthEvent  = remotes:WaitForChild("DroneHealthUpdate")

local MODES = { "scavenger", "sentry", "guard" }

local MODE_LABEL = { scavenger = "SCAVENGE", sentry = "SENTRY", guard = "GUARD" }

-- Fill colors match RoverSystem MODE_COLOR exactly
local MODE_FILL  = {
    scavenger = Color3.fromRGB(255, 180,   0),  -- gold
    sentry    = Color3.fromRGB(220,  35,  35),  -- red
    guard     = Color3.fromRGB(  0, 210,  80),  -- green
}
local MODE_BG    = {
    scavenger = Color3.fromRGB(35, 24,  0),
    sentry    = Color3.fromRGB(40,  8,  8),
    guard     = Color3.fromRGB( 0, 30, 12),
}

local OFFLINE_FILL = Color3.fromRGB(60, 60, 60)
local OFFLINE_BG   = Color3.fromRGB(18, 18, 18)

local droneMode   = {}
local droneAlive  = {}
local healthFills = {}   -- [i] = Frame "Fill"
local modeLabels  = {}   -- [i] = TextLabel
local modeBtns    = {}   -- [i] = TextButton (the whole bar)

local DEFAULT_MODES = { "scavenger", "scavenger", "sentry", "sentry", "guard", "guard" }
for i = 1, 6 do
    droneMode[i]  = DEFAULT_MODES[i]
    droneAlive[i] = true
end

-- ── Screen GUI ────────────────────────────────────────────────────────────────

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ROW_H   = 30
local PANEL_W = 210
local PANEL_H = 20 + 6 * (ROW_H + 4)
local TAB_W   = 44
local TAB_H   = 56
local panelOpen = false

local screenGui = Instance.new("ScreenGui")
screenGui.Name         = "DroneUI"
screenGui.ResetOnSpawn = false
screenGui.Parent       = playerGui

-- Toggle tab (always visible, left edge, upper-middle)
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name                   = "DroneToggle"
toggleBtn.Size                   = UDim2.new(0, TAB_W, 0, TAB_H)
toggleBtn.Position               = UDim2.new(0, 8, 0.5, -TAB_H - 4)
toggleBtn.BackgroundColor3       = Color3.fromRGB(30, 20, 70)
toggleBtn.BackgroundTransparency = 0.2
toggleBtn.Text                   = "🤖"
toggleBtn.TextSize               = 22
toggleBtn.Font                   = Enum.Font.GothamBold
toggleBtn.TextColor3             = Color3.fromRGB(180, 140, 255)
toggleBtn.BorderSizePixel        = 0
toggleBtn.ZIndex                 = 10
toggleBtn.Parent                 = screenGui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)
do local s = Instance.new("UIStroke")
   s.Color = Color3.fromRGB(90, 50, 220); s.Thickness = 1.5; s.Parent = toggleBtn end

local panel = Instance.new("Frame")
panel.Name                   = "DronePanel"
panel.Size                   = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position               = UDim2.new(0, -(PANEL_W + 20), 0.5, -PANEL_H / 2)
panel.BackgroundColor3       = Color3.fromRGB(8, 6, 22)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel        = 0
panel.Parent                 = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = Color3.fromRGB(90, 50, 220)
panelStroke.Thickness = 1.5
panelStroke.Parent    = panel

local OPEN_POS  = UDim2.new(0, TAB_W + 16, 0, 20)          -- slot 1: top of stack
local CLOSE_POS = UDim2.new(0, -(PANEL_W + 20), 0, 20)
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

toggleBtn.MouseButton1Click:Connect(function()
    panelOpen = not panelOpen
    TweenService:Create(panel, tweenInfo,
        { Position = panelOpen and OPEN_POS or CLOSE_POS }):Play()
end)

local header = Instance.new("TextButton")
header.Text                 = "DRONE CONTROL  ⠿"
header.Size                 = UDim2.new(1, 0, 0, 22)
header.Position             = UDim2.new(0, 0, 0, 0)
header.BackgroundTransparency = 1
header.TextColor3           = Color3.fromRGB(180, 140, 255)
header.TextSize             = 11
header.Font                 = Enum.Font.GothamBold
header.AutoButtonColor      = false
header.Parent               = panel

-- Drag logic
local dragging, dragStart, panelStart
local function onDragInput(input)
    if not dragging then return end
    local delta = input.Position - dragStart
    panel.Position = UDim2.new(
        panelStart.X.Scale, panelStart.X.Offset + delta.X,
        panelStart.Y.Scale, panelStart.Y.Offset + delta.Y)
    OPEN_POS  = panel.Position
    CLOSE_POS = UDim2.new(0, -(PANEL_W + 20), OPEN_POS.Y.Scale, OPEN_POS.Y.Offset)
end
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging  = true
        dragStart = input.Position
        panelStart = panel.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        onDragInput(input)
    end
end)

-- ── Per-drone rows ────────────────────────────────────────────────────────────

for i = 1, 6 do
    local yPos = 20 + (i - 1) * (ROW_H + 4)

    local row = Instance.new("Frame")
    row.Size                   = UDim2.new(1, -12, 0, ROW_H)
    row.Position               = UDim2.new(0, 6, 0, yPos)
    row.BackgroundColor3       = Color3.fromRGB(14, 12, 30)
    row.BackgroundTransparency = 0.3
    row.BorderSizePixel        = 0
    row.Parent                 = panel
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    -- Drone number label on the left
    local lbl = Instance.new("TextLabel")
    lbl.Text                 = tostring(i)
    lbl.Size                 = UDim2.new(0, 20, 1, 0)
    lbl.Position             = UDim2.new(0, 6, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3           = Color3.fromRGB(130, 120, 160)
    lbl.TextSize             = 11
    lbl.Font                 = Enum.Font.GothamBold
    lbl.Parent               = row

    -- Health-bar button (right side of the row)
    -- Outer button: dark background, click to cycle mode
    local initMode = DEFAULT_MODES[i]

    local btn = Instance.new("TextButton")
    btn.Name             = "ModeBtn"
    btn.Size             = UDim2.new(1, -30, 1, -6)
    btn.Position         = UDim2.new(0, 26, 0, 3)
    btn.BackgroundColor3 = MODE_BG[initMode]
    btn.Text             = ""
    btn.BorderSizePixel  = 0
    btn.AutoButtonColor  = false
    btn.ClipsDescendants = true
    btn.Parent           = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    -- Fill frame: width = health %, color = mode
    local fill = Instance.new("Frame")
    fill.Name             = "Fill"
    fill.Size             = UDim2.new(1, 0, 1, 0)   -- starts full
    fill.BackgroundColor3 = MODE_FILL[initMode]
    fill.BorderSizePixel  = 0
    fill.ZIndex           = btn.ZIndex + 1
    fill.Parent           = btn
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 5)

    -- Mode text on top of the fill
    local modeText = Instance.new("TextLabel")
    modeText.Name                 = "ModeText"
    modeText.Text                 = MODE_LABEL[initMode]
    modeText.Size                 = UDim2.new(1, 0, 1, 0)
    modeText.BackgroundTransparency = 1
    modeText.TextColor3           = Color3.new(0, 0, 0)
    modeText.TextSize             = 10
    modeText.Font                 = Enum.Font.GothamBold
    modeText.ZIndex               = fill.ZIndex + 1
    modeText.Parent               = btn

    healthFills[i] = fill
    modeLabels[i]  = modeText
    modeBtns[i]    = btn

    -- Click cycles mode (only if alive)
    local idx = i
    btn.MouseButton1Click:Connect(function()
        if not droneAlive[idx] then return end
        local cur     = droneMode[idx]
        local nextIdx = 1
        for m, mode in ipairs(MODES) do
            if mode == cur then nextIdx = (m % #MODES) + 1; break end
        end
        local newMode    = MODES[nextIdx]
        droneMode[idx]   = newMode
        fill.BackgroundColor3 = MODE_FILL[newMode]
        btn.BackgroundColor3  = MODE_BG[newMode]
        modeText.Text         = MODE_LABEL[newMode]
        setDroneModeEvent:FireServer(idx, newMode)
    end)

    btn.MouseEnter:Connect(function()
        if droneAlive[idx] then btn.BackgroundTransparency = 0.4 end
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundTransparency = 0
    end)
end

-- ── Health updates from server ────────────────────────────────────────────────

droneHealthEvent.OnClientEvent:Connect(function(droneIndex, health, maxHealth, alive)
    local fill     = healthFills[droneIndex]
    local modeText = modeLabels[droneIndex]
    local btn      = modeBtns[droneIndex]
    if not fill then return end

    droneAlive[droneIndex] = alive

    if not alive then
        fill.Size             = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = OFFLINE_FILL
        btn.BackgroundColor3  = OFFLINE_BG
        modeText.Text         = "OFFLINE"
        modeText.TextColor3   = Color3.fromRGB(180, 60, 60)
    else
        local t = math.clamp(health / (maxHealth or 100), 0, 1)
        fill.Size             = UDim2.new(t, 0, 1, 0)
        -- Color shifts gold→red as health drops (for scavenger; others keep their hue)
        local mode = droneMode[droneIndex]
        fill.BackgroundColor3 = MODE_FILL[mode]
        btn.BackgroundColor3  = MODE_BG[mode]
        modeText.Text         = MODE_LABEL[mode]
        modeText.TextColor3   = Color3.new(0, 0, 0)
    end
end)
