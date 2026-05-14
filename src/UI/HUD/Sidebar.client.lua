-- LocalScript → StarterGui/Sidebar
-- Unified collapsible sidebar: Drones · Cargo · Settings

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = workspace.CurrentCamera

local remotes              = ReplicatedStorage:WaitForChild("Remotes")
local setDroneModeEvent    = remotes:WaitForChild("SetDroneMode")
local droneHealthEvent     = remotes:WaitForChild("DroneHealthUpdate")
local collectFragmentEvent = remotes:WaitForChild("CollectFragment")
local collectMetalEvent    = remotes:WaitForChild("CollectMetal")
local deductMetalEvent     = remotes:WaitForChild("DeductMetal")
local loadSettings         = remotes:WaitForChild("LoadSettings")
local saveSettings         = remotes:WaitForChild("SaveSettings")
local ClientSettings       = require(ReplicatedStorage:WaitForChild("ClientSettings"))

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ── Palette ───────────────────────────────────────────────────────────────────

local BG    = Color3.fromRGB(8, 6, 22)
local NEON  = Color3.fromRGB(90, 50, 220)
local TEXT  = Color3.fromRGB(200, 190, 255)
local DIM   = Color3.fromRGB(130, 120, 160)
local SEL   = Color3.fromRGB(80, 50, 180)
local UNSEL = Color3.fromRGB(25, 20, 55)

-- ── Screen GUI ────────────────────────────────────────────────────────────────

local sg = Instance.new("ScreenGui")
sg.Name = "Sidebar"; sg.ResetOnSpawn = false; sg.Parent = playerGui

-- ── Toggle button ─────────────────────────────────────────────────────────────

local TAB_W = 48
local TAB_H = 48
local sidebarOpen = false

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name                   = "SidebarToggle"
toggleBtn.Size                   = UDim2.new(0, TAB_W, 0, TAB_H)
toggleBtn.Position               = UDim2.new(0, 8, 0.5, -TAB_H / 2)
toggleBtn.BackgroundColor3       = Color3.fromRGB(20, 15, 55)
toggleBtn.BackgroundTransparency = 0.2
toggleBtn.Text                   = "≡"
toggleBtn.TextSize               = 26
toggleBtn.Font                   = Enum.Font.GothamBold
toggleBtn.TextColor3             = TEXT
toggleBtn.BorderSizePixel        = 0
toggleBtn.ZIndex                 = 12
toggleBtn.Parent                 = sg
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)
do local s = Instance.new("UIStroke"); s.Color = NEON; s.Thickness = 1.5; s.Parent = toggleBtn end

-- ── Main panel ────────────────────────────────────────────────────────────────

local PANEL_W = 270

local panel = Instance.new("Frame")
panel.Name                   = "SidebarPanel"
panel.Size                   = UDim2.new(0, PANEL_W, 0.85, 0)
panel.Position               = UDim2.new(0, -(PANEL_W + 20), 0.075, 0)
panel.BackgroundColor3       = BG
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel        = 0
panel.ClipsDescendants       = true
panel.ZIndex                 = 11
panel.Parent                 = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
do local s = Instance.new("UIStroke"); s.Color = NEON; s.Thickness = 1.5; s.Parent = panel end

local OPEN_POS  = UDim2.new(0, TAB_W + 16, 0.075, 0)
local CLOSE_POS = UDim2.new(0, -(PANEL_W + 20), 0.075, 0)
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

toggleBtn.MouseButton1Click:Connect(function()
    sidebarOpen = not sidebarOpen
    TweenService:Create(panel, tweenInfo,
        { Position = sidebarOpen and OPEN_POS or CLOSE_POS }):Play()
    toggleBtn.Text = sidebarOpen and "✕" or "≡"
end)

-- ── Scrolling content area ────────────────────────────────────────────────────

local scroll = Instance.new("ScrollingFrame")
scroll.Size                   = UDim2.new(1, 0, 1, 0)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel        = 0
scroll.ScrollBarThickness     = 4
scroll.ScrollBarImageColor3   = NEON
scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
scroll.Parent                 = panel

do
    local ll = Instance.new("UIListLayout")
    ll.FillDirection = Enum.FillDirection.Vertical
    ll.SortOrder     = Enum.SortOrder.LayoutOrder
    ll.Padding       = UDim.new(0, 0)
    ll.Parent        = scroll
end

-- ── Section builder ───────────────────────────────────────────────────────────
-- Returns the content Frame; children added to it are stacked by UIListLayout.

local function makeSection(icon, title, layoutOrder)
    local expanded = true

    local header = Instance.new("TextButton")
    header.Name                   = title .. "Header"
    header.Size                   = UDim2.new(1, 0, 0, 40)
    header.BackgroundColor3       = Color3.fromRGB(18, 14, 42)
    header.BackgroundTransparency = 0.1
    header.BorderSizePixel        = 0
    header.Text                   = icon .. "  " .. title .. "  ▾"
    header.TextSize               = 13
    header.Font                   = Enum.Font.GothamBold
    header.TextColor3             = TEXT
    header.TextXAlignment         = Enum.TextXAlignment.Left
    header.AutoButtonColor        = false
    header.LayoutOrder            = layoutOrder * 2 - 1
    header.Parent                 = scroll
    do
        local p = Instance.new("UIPadding")
        p.PaddingLeft = UDim.new(0, 12); p.Parent = header
    end
    do local s = Instance.new("UIStroke"); s.Color = NEON; s.Thickness = 0.6; s.Parent = header end

    local content = Instance.new("Frame")
    content.Name                  = title .. "Content"
    content.Size                  = UDim2.new(1, 0, 0, 0)
    content.AutomaticSize         = Enum.AutomaticSize.Y
    content.BackgroundTransparency = 1
    content.BorderSizePixel       = 0
    content.LayoutOrder           = layoutOrder * 2
    content.Parent                = scroll
    do
        local p = Instance.new("UIPadding")
        p.PaddingLeft = UDim.new(0, 8); p.PaddingRight  = UDim.new(0, 8)
        p.PaddingTop  = UDim.new(0, 6); p.PaddingBottom = UDim.new(0, 8)
        p.Parent = content
    end
    do
        local ll = Instance.new("UIListLayout")
        ll.FillDirection = Enum.FillDirection.Vertical
        ll.SortOrder     = Enum.SortOrder.LayoutOrder
        ll.Padding       = UDim.new(0, 4)
        ll.Parent        = content
    end

    header.MouseButton1Click:Connect(function()
        expanded = not expanded
        content.Visible = expanded
        header.Text = icon .. "  " .. title .. (expanded and "  ▾" or "  ▸")
    end)

    return content
end

-- ── DRONES ────────────────────────────────────────────────────────────────────

local droneContent = makeSection("🤖", "DRONES", 1)

local MODES      = { "scavenger", "sentry", "guard" }
local MODE_LABEL = { scavenger = "SCAVENGE", sentry = "SENTRY", guard = "GUARD" }
local MODE_FILL  = {
    scavenger = Color3.fromRGB(255, 180,   0),
    sentry    = Color3.fromRGB(220,  35,  35),
    guard     = Color3.fromRGB(  0, 210,  80),
}
local MODE_BG = {
    scavenger = Color3.fromRGB(35, 24,  0),
    sentry    = Color3.fromRGB(40,  8,  8),
    guard     = Color3.fromRGB( 0, 30, 12),
}
local OFFLINE_FILL = Color3.fromRGB(60, 60, 60)
local OFFLINE_BG   = Color3.fromRGB(18, 18, 18)

local DEFAULT_MODES = { "scavenger", "scavenger", "sentry", "sentry", "guard", "guard" }
local droneMode   = {}
local droneAlive  = {}
local healthFills = {}
local modeLabels  = {}
local modeBtns    = {}

for i = 1, 6 do droneMode[i] = DEFAULT_MODES[i]; droneAlive[i] = true end

for i = 1, 6 do
    local initMode = DEFAULT_MODES[i]

    local row = Instance.new("Frame")
    row.Name              = "Drone" .. i
    row.Size              = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3  = Color3.fromRGB(14, 12, 30)
    row.BackgroundTransparency = 0.3
    row.BorderSizePixel   = 0
    row.LayoutOrder       = i
    row.Parent            = droneContent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Text = tostring(i); lbl.Size = UDim2.new(0, 20, 1, 0)
    lbl.Position = UDim2.new(0, 6, 0, 0); lbl.BackgroundTransparency = 1
    lbl.TextColor3 = DIM; lbl.TextSize = 11; lbl.Font = Enum.Font.GothamBold
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Name = "ModeBtn"; btn.Size = UDim2.new(1, -32, 1, -6)
    btn.Position = UDim2.new(0, 28, 0, 3); btn.BackgroundColor3 = MODE_BG[initMode]
    btn.Text = ""; btn.BorderSizePixel = 0; btn.AutoButtonColor = false
    btn.ClipsDescendants = true; btn.Parent = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    local fill = Instance.new("Frame")
    fill.Name = "Fill"; fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = MODE_FILL[initMode]; fill.BorderSizePixel = 0
    fill.ZIndex = btn.ZIndex + 1; fill.Parent = btn
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 5)

    local modeText = Instance.new("TextLabel")
    modeText.Text = MODE_LABEL[initMode]; modeText.Size = UDim2.new(1, 0, 1, 0)
    modeText.BackgroundTransparency = 1; modeText.TextColor3 = Color3.new(0, 0, 0)
    modeText.TextSize = 10; modeText.Font = Enum.Font.GothamBold
    modeText.ZIndex = fill.ZIndex + 1; modeText.Parent = btn

    healthFills[i] = fill; modeLabels[i] = modeText; modeBtns[i] = btn

    local idx = i
    btn.MouseButton1Click:Connect(function()
        if not droneAlive[idx] then return end
        local cur = droneMode[idx]; local nextIdx = 1
        for m, mode in ipairs(MODES) do
            if mode == cur then nextIdx = (m % #MODES) + 1; break end
        end
        local newMode = MODES[nextIdx]; droneMode[idx] = newMode
        fill.BackgroundColor3 = MODE_FILL[newMode]
        btn.BackgroundColor3  = MODE_BG[newMode]
        modeText.Text         = MODE_LABEL[newMode]
        setDroneModeEvent:FireServer(idx, newMode)
    end)
end

droneHealthEvent.OnClientEvent:Connect(function(droneIndex, health, maxHealth, alive)
    local fill = healthFills[droneIndex]; local btn = modeBtns[droneIndex]
    local mt   = modeLabels[droneIndex]
    if not fill then return end
    droneAlive[droneIndex] = alive
    if not alive then
        fill.Size = UDim2.new(0, 0, 1, 0); fill.BackgroundColor3 = OFFLINE_FILL
        btn.BackgroundColor3 = OFFLINE_BG; mt.Text = "OFFLINE"
        mt.TextColor3 = Color3.fromRGB(180, 60, 60)
    else
        local t = math.clamp(health / (maxHealth or 100), 0, 1)
        fill.Size = UDim2.new(t, 0, 1, 0)
        local mode = droneMode[droneIndex]
        fill.BackgroundColor3 = MODE_FILL[mode]; btn.BackgroundColor3 = MODE_BG[mode]
        mt.Text = MODE_LABEL[mode]; mt.TextColor3 = Color3.new(0, 0, 0)
    end
end)

-- ── CARGO ─────────────────────────────────────────────────────────────────────

local cargoContent = makeSection("📦", "CARGO", 2)

local inventory = { fragments = {}, metals = {} }
local itemSlots = {}

local SLOT_COLOR = {
    Rock = Color3.fromRGB(130, 100, 70), Metal = Color3.fromRGB(160, 165, 185),
    Crystal = Color3.fromRGB(130, 75, 240), Ice = Color3.fromRGB(150, 200, 255),
    Iron = Color3.fromRGB(140, 130, 120), Copper = Color3.fromRGB(210, 105, 55),
    Silver = Color3.fromRGB(200, 205, 220), Gold = Color3.fromRGB(220, 170, 20),
    Titanium = Color3.fromRGB(155, 175, 200),
}

local function makeToast(text, color, worldPos)
    local sx, sy = 0.5, 0.5
    if worldPos then
        local sp, on = camera:WorldToScreenPoint(worldPos)
        if on then local vp = camera.ViewportSize; sx = sp.X/vp.X; sy = sp.Y/vp.Y end
    end
    local t = Instance.new("TextLabel")
    t.Text = text; t.Size = UDim2.new(0, 180, 0, 32)
    t.Position = UDim2.new(sx, -90, sy, -16); t.BackgroundTransparency = 1
    t.TextColor3 = color; t.TextTransparency = 0.1; t.TextSize = 20
    t.Font = Enum.Font.GothamBold; t.TextStrokeColor3 = Color3.new(0,0,0)
    t.TextStrokeTransparency = 0.45; t.Parent = sg
    TweenService:Create(t, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextTransparency = 1, TextStrokeTransparency = 1,
        Position = UDim2.new(sx, -90, sy - 0.06, -16),
    }):Play()
    task.delay(1.2, function() if t and t.Parent then t:Destroy() end end)
end

local function rebuildCargo()
    for _, s in pairs(itemSlots) do s:Destroy() end
    itemSlots = {}
    local order = 1
    for name, count in pairs(inventory.metals) do
        local slot = Instance.new("TextLabel")
        slot.Text = string.format("%s ×%d", name, count)
        slot.Size = UDim2.new(1, 0, 0, 28)
        slot.BackgroundColor3 = SLOT_COLOR[name] or Color3.fromRGB(180, 160, 80)
        slot.BackgroundTransparency = 0.45; slot.TextColor3 = Color3.new(1,1,1)
        slot.TextSize = 12; slot.Font = Enum.Font.Gotham
        slot.BorderSizePixel = 0; slot.LayoutOrder = order; slot.Parent = cargoContent
        Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 5)
        itemSlots["m_"..name] = slot; order += 1
    end
    for fragType, count in pairs(inventory.fragments) do
        local slot = Instance.new("TextLabel")
        slot.Text = string.format("%s ×%d", fragType, count)
        slot.Size = UDim2.new(1, 0, 0, 28)
        slot.BackgroundColor3 = SLOT_COLOR[fragType] or Color3.fromRGB(90, 90, 110)
        slot.BackgroundTransparency = 0.45; slot.TextColor3 = Color3.new(1,1,1)
        slot.TextSize = 12; slot.Font = Enum.Font.Gotham
        slot.BorderSizePixel = 0; slot.LayoutOrder = order; slot.Parent = cargoContent
        Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 5)
        itemSlots["f_"..fragType] = slot; order += 1
    end
    local hasItems = next(inventory.fragments) ~= nil or next(inventory.metals) ~= nil
    toggleBtn.BackgroundColor3 = hasItems and Color3.fromRGB(80, 50, 180) or Color3.fromRGB(20, 15, 55)
    toggleBtn.TextColor3 = hasItems and Color3.fromRGB(255, 220, 100) or TEXT
end

collectFragmentEvent.OnClientEvent:Connect(function(fragType, qty, worldPos)
    inventory.fragments[fragType] = (inventory.fragments[fragType] or 0) + (qty or 1)
    rebuildCargo()
    makeToast("+" .. (qty or 1) .. " " .. fragType, SLOT_COLOR[fragType] or Color3.new(1,1,1), worldPos)
end)
collectMetalEvent.OnClientEvent:Connect(function(metalName)
    inventory.metals[metalName] = (inventory.metals[metalName] or 0) + 1
    rebuildCargo()
    makeToast("+ " .. metalName, SLOT_COLOR[metalName] or Color3.fromRGB(255, 210, 50))
end)
deductMetalEvent.OnClientEvent:Connect(function(metalName)
    local c = inventory.metals[metalName] or 0
    inventory.metals[metalName] = c <= 1 and nil or c - 1
    rebuildCargo()
    makeToast("- " .. metalName, Color3.fromRGB(200, 80, 80))
end)

rebuildCargo()

-- ── SETTINGS ──────────────────────────────────────────────────────────────────

local settingsContent = makeSection("⚙", "SETTINGS", 3)

local function sLabel(text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Text = text; lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = DIM
    lbl.TextSize = 10; lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order; lbl.Parent = settingsContent
end

local function oRow(options, currentKey, order, onSelect)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(1, 0, 0, 34); c.BackgroundTransparency = 1
    c.LayoutOrder = order; c.Parent = settingsContent
    local ll = Instance.new("UIListLayout")
    ll.FillDirection = Enum.FillDirection.Horizontal; ll.Padding = UDim.new(0, 4); ll.Parent = c
    local btns = {}
    for _, opt in ipairs(options) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1/#options, -4, 1, 0)
        btn.BackgroundColor3 = (opt.key == currentKey) and SEL or UNSEL
        btn.Text = opt.label; btn.TextSize = 11; btn.Font = Enum.Font.GothamBold
        btn.TextColor3 = Color3.new(1,1,1); btn.BorderSizePixel = 0
        btn.AutoButtonColor = false; btn.Parent = c
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        table.insert(btns, btn)
        btn.MouseButton1Click:Connect(function()
            for _, b in ipairs(btns) do b.BackgroundColor3 = UNSEL end
            btn.BackgroundColor3 = SEL; onSelect(opt.key)
        end)
    end
end

local function tRow(label, currentVal, order, onToggle)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(1, 0, 0, 32); c.BackgroundTransparency = 1
    c.LayoutOrder = order; c.Parent = settingsContent
    local lbl = Instance.new("TextLabel")
    lbl.Text = label; lbl.Size = UDim2.new(0.65, 0, 1, 0)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = TEXT
    lbl.TextSize = 11; lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = c
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 60, 0, 26); btn.Position = UDim2.new(1, -60, 0.5, -13)
    btn.BackgroundColor3 = currentVal and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(80, 30, 30)
    btn.Text = currentVal and "ON" or "OFF"; btn.TextSize = 11; btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = Color3.new(1,1,1); btn.BorderSizePixel = 0
    btn.AutoButtonColor = false; btn.Parent = c
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local state = currentVal
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(80, 30, 30)
        btn.Text = state and "ON" or "OFF"; onToggle(state)
    end)
end

local CONTROL_MODES = {
    { key = "classic",    label = "Classic" },
    { key = "twin-stick", label = "Sticks"  },
    { key = "tap-to-fly", label = "Tap-Fly" },
    { key = "gyro",       label = "Gyro"    },
}
sLabel("CONTROL MODE", 1)
oRow(CONTROL_MODES, ClientSettings.controlMode, 2, function(key)
    ClientSettings.controlMode = key; saveSettings:FireServer("controlMode", key)
end)
sLabel("INVERT Y", 3)
tRow("Invert Y-Axis", ClientSettings.invertY, 4, function(val)
    ClientSettings.invertY = val; saveSettings:FireServer("invertY", val)
end)

if isMobile then
    sLabel("GYRO SENSITIVITY", 5)
    local sensVal = ClientSettings.gyroSensitivity or 1.0
    local sc = Instance.new("Frame")
    sc.Size = UDim2.new(1, 0, 0, 34); sc.BackgroundTransparency = 1
    sc.LayoutOrder = 6; sc.Parent = settingsContent
    local sensLbl = Instance.new("TextLabel")
    sensLbl.Size = UDim2.new(0, 60, 1, 0); sensLbl.Position = UDim2.new(0.5, -30, 0, 0)
    sensLbl.BackgroundTransparency = 1; sensLbl.TextColor3 = TEXT
    sensLbl.TextSize = 13; sensLbl.Font = Enum.Font.GothamBold
    sensLbl.Text = string.format("%.1f", sensVal); sensLbl.Parent = sc
    local function adjBtn(label, xOff, delta)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 40, 0, 30); btn.Position = UDim2.new(0, xOff, 0.5, -15)
        btn.BackgroundColor3 = UNSEL; btn.Text = label; btn.TextSize = 18
        btn.Font = Enum.Font.GothamBold; btn.TextColor3 = TEXT
        btn.BorderSizePixel = 0; btn.AutoButtonColor = false; btn.Parent = sc
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.MouseButton1Click:Connect(function()
            sensVal = math.clamp(sensVal + delta, 0.1, 3.0)
            sensLbl.Text = string.format("%.1f", sensVal)
            ClientSettings.gyroSensitivity = sensVal
            saveSettings:FireServer("gyroSensitivity", sensVal)
        end)
    end
    adjBtn("−", 8, -0.1); adjBtn("+", 180, 0.1)
end

loadSettings.OnClientEvent:Connect(function(settings)
    for k, v in pairs(settings) do ClientSettings[k] = v end
    if isMobile and ClientSettings.controlMode == "classic" then
        ClientSettings.controlMode = "twin-stick"
    end
end)

print("[Sidebar] Active")
