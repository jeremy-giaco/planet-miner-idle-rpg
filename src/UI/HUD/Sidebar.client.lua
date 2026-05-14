-- LocalScript → StarterGui/Sidebar
-- Top dropdown bar: three tabs (Drones · Cargo · Settings) each expand downward.

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

local BG_COL  = Color3.fromRGB(10, 6, 28)
local NEON    = Color3.fromRGB(100, 60, 240)
local TEXT    = Color3.fromRGB(220, 210, 255)
local DIM     = Color3.fromRGB(150, 135, 185)
local SEL     = Color3.fromRGB(90, 55, 200)
local UNSEL   = Color3.fromRGB(30, 22, 65)
local ALPHA   = 0.55   -- transparency for all backgrounds

-- ── Constants ─────────────────────────────────────────────────────────────────

local TAB_H   = 40     -- height of the tab bar
local ROW_H   = 26     -- row height inside panels
local PANEL_H = 210    -- expanded panel height (fits all content; cargo scrolls if needed)

-- ── Screen GUI ────────────────────────────────────────────────────────────────

local sg = Instance.new("ScreenGui")
sg.Name = "Sidebar"; sg.ResetOnSpawn = false; sg.Parent = playerGui

-- ── Tab bar ───────────────────────────────────────────────────────────────────

local tabBar = Instance.new("Frame")
tabBar.Name                   = "TabBar"
tabBar.Size                   = UDim2.new(1, 0, 0, TAB_H)
tabBar.Position               = UDim2.new(0, 0, 0, 0)
tabBar.BackgroundColor3       = BG_COL
tabBar.BackgroundTransparency = ALPHA
tabBar.BorderSizePixel        = 0
tabBar.ZIndex                 = 12
tabBar.Parent                 = sg
do local s = Instance.new("UIStroke"); s.Color = NEON; s.Thickness = 1; s.Parent = tabBar end
do
    local ll = Instance.new("UIListLayout")
    ll.FillDirection  = Enum.FillDirection.Horizontal
    ll.SortOrder      = Enum.SortOrder.LayoutOrder
    ll.HorizontalAlignment = Enum.HorizontalAlignment.Left
    ll.Padding        = UDim.new(0, 0)
    ll.Parent         = tabBar
end

-- ── Dropdown panel (below tab bar, slides open/closed) ───────────────────────

local dropPanel = Instance.new("Frame")
dropPanel.Name                   = "DropPanel"
dropPanel.Size                   = UDim2.new(1, 0, 0, 0)   -- starts collapsed
dropPanel.Position               = UDim2.new(0, 0, 0, TAB_H)
dropPanel.BackgroundColor3       = BG_COL
dropPanel.BackgroundTransparency = ALPHA
dropPanel.BorderSizePixel        = 0
dropPanel.ClipsDescendants       = true
dropPanel.ZIndex                 = 11
dropPanel.Parent                 = sg
do local s = Instance.new("UIStroke"); s.Color = NEON; s.Thickness = 1; s.Parent = dropPanel end

local tweenOpen  = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local tweenClose = TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

-- ── Content frames (one per tab, only one visible at a time) ──────────────────

local contentFrames = {}   -- ["drones"|"cargo"|"settings"] = Frame

local function makeContentFrame(key)
    local f = Instance.new("ScrollingFrame")
    f.Name                   = key
    f.Size                   = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.BorderSizePixel        = 0
    f.ScrollBarThickness     = 3
    f.ScrollBarImageColor3   = NEON
    f.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    f.CanvasSize             = UDim2.new(0, 0, 0, 0)
    f.Visible                = false
    f.Parent                 = dropPanel
    do
        local p = Instance.new("UIPadding")
        p.PaddingLeft = UDim.new(0, 8); p.PaddingRight  = UDim.new(0, 8)
        p.PaddingTop  = UDim.new(0, 6); p.PaddingBottom = UDim.new(0, 6)
        p.Parent = f
    end
    do
        local ll = Instance.new("UIListLayout")
        ll.FillDirection = Enum.FillDirection.Vertical
        ll.SortOrder     = Enum.SortOrder.LayoutOrder
        ll.Padding       = UDim.new(0, 3)
        ll.Parent        = f
    end
    contentFrames[key] = f
    return f
end

-- ── Tab button builder ────────────────────────────────────────────────────────

local activeTab   = nil
local tabButtons  = {}

local function setTab(key)
    -- Same tab tapped → close
    if activeTab == key then
        activeTab = nil
        for _, btn in pairs(tabButtons) do
            btn.BackgroundColor3 = BG_COL
            btn.BackgroundTransparency = ALPHA + 0.1
        end
        for _, f in pairs(contentFrames) do f.Visible = false end
        TweenService:Create(dropPanel, tweenClose, { Size = UDim2.new(1, 0, 0, 0) }):Play()
        return
    end
    -- Switch to new tab
    activeTab = key
    for k, btn in pairs(tabButtons) do
        btn.BackgroundColor3       = (k == key) and SEL or BG_COL
        btn.BackgroundTransparency = (k == key) and 0.25 or (ALPHA + 0.1)
    end
    for k, f in pairs(contentFrames) do f.Visible = (k == key) end
    TweenService:Create(dropPanel, tweenOpen, { Size = UDim2.new(1, 0, 0, PANEL_H) }):Play()
end

local TAB_DEFS = {
    { key = "drones",   icon = "🤖", label = "DRONES",   order = 1 },
    { key = "cargo",    icon = "📦", label = "CARGO",    order = 2 },
    { key = "settings", icon = "⚙",  label = "SETTINGS", order = 3 },
}

for _, def in ipairs(TAB_DEFS) do
    makeContentFrame(def.key)

    local btn = Instance.new("TextButton")
    btn.Name                   = def.key .. "Tab"
    btn.Size                   = UDim2.new(1/3, 0, 1, 0)
    btn.BackgroundColor3       = BG_COL
    btn.BackgroundTransparency = ALPHA + 0.1
    btn.Text                   = def.icon .. " " .. def.label
    btn.TextSize               = 13
    btn.Font                   = Enum.Font.GothamBold
    btn.TextColor3             = TEXT
    btn.BorderSizePixel        = 0
    btn.AutoButtonColor        = false
    btn.LayoutOrder            = def.order
    btn.ZIndex                 = 13
    btn.Parent                 = tabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 0)

    tabButtons[def.key] = btn
    local k = def.key
    btn.MouseButton1Click:Connect(function() setTab(k) end)
end

-- ── Helper: plain row label ────────────────────────────────────────────────────

local function rowLabel(parent, text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Text = text; lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = DIM
    lbl.TextSize = 9; lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order; lbl.Parent = parent
end

-- ══════════════════════════════════════════════════════════════════════════════
-- DRONES
-- ══════════════════════════════════════════════════════════════════════════════

local droneFrame = contentFrames["drones"]

local MODES      = { "scavenger", "sentry", "guard" }
local MODE_LABEL = { scavenger = "SCVNG", sentry = "SNTRY", guard = "GUARD" }
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
    row.Size = UDim2.new(1, 0, 0, ROW_H)
    row.BackgroundTransparency = 1; row.BorderSizePixel = 0
    row.LayoutOrder = i; row.Parent = droneFrame

    local lbl = Instance.new("TextLabel")
    lbl.Text = tostring(i); lbl.Size = UDim2.new(0, 14, 1, 0)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = DIM
    lbl.TextSize = 9; lbl.Font = Enum.Font.GothamBold; lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Name = "ModeBtn"; btn.Size = UDim2.new(1, -18, 1, -2)
    btn.Position = UDim2.new(0, 16, 0, 1)
    btn.BackgroundColor3 = MODE_BG[initMode]; btn.Text = ""
    btn.BorderSizePixel = 0; btn.AutoButtonColor = false
    btn.ClipsDescendants = true; btn.Parent = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(1, 0, 1, 0); fill.BackgroundColor3 = MODE_FILL[initMode]
    fill.BorderSizePixel = 0; fill.ZIndex = btn.ZIndex + 1; fill.Parent = btn
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

    local mt = Instance.new("TextLabel")
    mt.Text = MODE_LABEL[initMode]; mt.Size = UDim2.new(1, 0, 1, 0)
    mt.BackgroundTransparency = 1; mt.TextColor3 = Color3.new(0, 0, 0)
    mt.TextSize = 9; mt.Font = Enum.Font.GothamBold
    mt.ZIndex = fill.ZIndex + 1; mt.Parent = btn

    healthFills[i] = fill; modeLabels[i] = mt; modeBtns[i] = btn

    local idx = i
    btn.MouseButton1Click:Connect(function()
        if not droneAlive[idx] then return end
        local cur = droneMode[idx]; local ni = 1
        for m, mode in ipairs(MODES) do
            if mode == cur then ni = (m % #MODES) + 1; break end
        end
        local nm = MODES[ni]; droneMode[idx] = nm
        fill.BackgroundColor3 = MODE_FILL[nm]
        btn.BackgroundColor3  = MODE_BG[nm]
        mt.Text               = MODE_LABEL[nm]
        setDroneModeEvent:FireServer(idx, nm)
    end)
end

droneHealthEvent.OnClientEvent:Connect(function(idx, health, maxHealth, alive)
    local fill = healthFills[idx]; local btn = modeBtns[idx]; local mt = modeLabels[idx]
    if not fill then return end
    droneAlive[idx] = alive
    if not alive then
        fill.Size = UDim2.new(0, 0, 1, 0); fill.BackgroundColor3 = OFFLINE_FILL
        btn.BackgroundColor3 = OFFLINE_BG; mt.Text = "OFFLN"
        mt.TextColor3 = Color3.fromRGB(180, 60, 60)
    else
        fill.Size = UDim2.new(math.clamp(health/(maxHealth or 100),0,1), 0, 1, 0)
        local mode = droneMode[idx]
        fill.BackgroundColor3 = MODE_FILL[mode]; btn.BackgroundColor3 = MODE_BG[mode]
        mt.Text = MODE_LABEL[mode]; mt.TextColor3 = Color3.new(0, 0, 0)
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- CARGO
-- ══════════════════════════════════════════════════════════════════════════════

local cargoFrame = contentFrames["cargo"]

local inventory = { fragments = {}, metals = {} }
local itemSlots = {}

local SLOT_COLOR = {
    Rock = Color3.fromRGB(130,100,70), Metal = Color3.fromRGB(160,165,185),
    Crystal = Color3.fromRGB(130,75,240), Ice = Color3.fromRGB(150,200,255),
    Iron = Color3.fromRGB(140,130,120), Copper = Color3.fromRGB(210,105,55),
    Silver = Color3.fromRGB(200,205,220), Gold = Color3.fromRGB(220,170,20),
    Titanium = Color3.fromRGB(155,175,200),
}

local function makeToast(text, color, worldPos)
    local sx, sy = 0.5, 0.5
    if worldPos then
        local sp, on = camera:WorldToScreenPoint(worldPos)
        if on then local vp = camera.ViewportSize; sx=sp.X/vp.X; sy=sp.Y/vp.Y end
    end
    local t = Instance.new("TextLabel")
    t.Text=text; t.Size=UDim2.new(0,180,0,32); t.Position=UDim2.new(sx,-90,sy,-16)
    t.BackgroundTransparency=1; t.TextColor3=color; t.TextTransparency=0.1; t.TextSize=20
    t.Font=Enum.Font.GothamBold; t.TextStrokeColor3=Color3.new(0,0,0)
    t.TextStrokeTransparency=0.45; t.Parent=sg
    TweenService:Create(t, TweenInfo.new(1.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
        TextTransparency=1,TextStrokeTransparency=1,Position=UDim2.new(sx,-90,sy-0.06,-16),
    }):Play()
    task.delay(1.2, function() if t and t.Parent then t:Destroy() end end)
end

local function rebuildCargo()
    for _, s in pairs(itemSlots) do s:Destroy() end
    itemSlots = {}
    local order = 1
    local function makeSlot(text, color, key)
        local s = Instance.new("TextLabel")
        s.Text=text; s.Size=UDim2.new(1,0,0,ROW_H)
        s.BackgroundColor3=color; s.BackgroundTransparency=0.45
        s.TextColor3=Color3.new(1,1,1); s.TextSize=11; s.Font=Enum.Font.Gotham
        s.BorderSizePixel=0; s.LayoutOrder=order; s.Parent=cargoFrame
        Instance.new("UICorner",s).CornerRadius=UDim.new(0,4)
        itemSlots[key]=s; order+=1
    end
    for name,count in pairs(inventory.metals) do
        makeSlot(string.format("%s ×%d",name,count), SLOT_COLOR[name] or Color3.fromRGB(180,160,80), "m_"..name)
    end
    for ft,count in pairs(inventory.fragments) do
        makeSlot(string.format("%s ×%d",ft,count), SLOT_COLOR[ft] or Color3.fromRGB(90,90,110), "f_"..ft)
    end
    -- Glow cargo tab if items present
    local has = next(inventory.fragments)~=nil or next(inventory.metals)~=nil
    tabButtons["cargo"].TextColor3 = has and Color3.fromRGB(255,220,80) or TEXT
end

collectFragmentEvent.OnClientEvent:Connect(function(ft,qty,wp)
    inventory.fragments[ft]=(inventory.fragments[ft] or 0)+(qty or 1)
    rebuildCargo(); makeToast("+"..( qty or 1).." "..ft, SLOT_COLOR[ft] or Color3.new(1,1,1), wp)
end)
collectMetalEvent.OnClientEvent:Connect(function(name)
    inventory.metals[name]=(inventory.metals[name] or 0)+1
    rebuildCargo(); makeToast("+ "..name, SLOT_COLOR[name] or Color3.fromRGB(255,210,50))
end)
deductMetalEvent.OnClientEvent:Connect(function(name)
    local c=inventory.metals[name] or 0
    inventory.metals[name]=c<=1 and nil or c-1
    rebuildCargo(); makeToast("- "..name, Color3.fromRGB(200,80,80))
end)
rebuildCargo()

-- ══════════════════════════════════════════════════════════════════════════════
-- SETTINGS
-- ══════════════════════════════════════════════════════════════════════════════

local settingsFrame = contentFrames["settings"]

local function oRow(options, currentKey, order, onSelect)
    local c = Instance.new("Frame")
    c.Size=UDim2.new(1,0,0,ROW_H+2); c.BackgroundTransparency=1
    c.LayoutOrder=order; c.Parent=settingsFrame
    local ll=Instance.new("UIListLayout")
    ll.FillDirection=Enum.FillDirection.Horizontal; ll.Padding=UDim.new(0,3); ll.Parent=c
    local btns={}
    for _,opt in ipairs(options) do
        local btn=Instance.new("TextButton")
        btn.Size=UDim2.new(1/#options,-3,1,0)
        btn.BackgroundColor3=(opt.key==currentKey) and SEL or UNSEL
        btn.Text=opt.label; btn.TextSize=10; btn.Font=Enum.Font.GothamBold
        btn.TextColor3=Color3.new(1,1,1); btn.BorderSizePixel=0
        btn.AutoButtonColor=false; btn.Parent=c
        Instance.new("UICorner",btn).CornerRadius=UDim.new(0,4)
        table.insert(btns,btn)
        btn.MouseButton1Click:Connect(function()
            for _,b in ipairs(btns) do b.BackgroundColor3=UNSEL end
            btn.BackgroundColor3=SEL; onSelect(opt.key)
        end)
    end
end

local function tRow(label, currentVal, order, onToggle)
    local c=Instance.new("Frame")
    c.Size=UDim2.new(1,0,0,ROW_H); c.BackgroundTransparency=1
    c.LayoutOrder=order; c.Parent=settingsFrame
    local lbl=Instance.new("TextLabel")
    lbl.Text=label; lbl.Size=UDim2.new(0.6,0,1,0)
    lbl.BackgroundTransparency=1; lbl.TextColor3=TEXT
    lbl.TextSize=10; lbl.Font=Enum.Font.Gotham
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=c
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(0,46,0,ROW_H-2); btn.Position=UDim2.new(1,-46,0.5,-(ROW_H-2)/2)
    btn.BackgroundColor3=currentVal and Color3.fromRGB(0,170,70) or Color3.fromRGB(80,30,30)
    btn.Text=currentVal and "ON" or "OFF"; btn.TextSize=10; btn.Font=Enum.Font.GothamBold
    btn.TextColor3=Color3.new(1,1,1); btn.BorderSizePixel=0; btn.AutoButtonColor=false; btn.Parent=c
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,4)
    local state=currentVal
    btn.MouseButton1Click:Connect(function()
        state=not state
        btn.BackgroundColor3=state and Color3.fromRGB(0,170,70) or Color3.fromRGB(80,30,30)
        btn.Text=state and "ON" or "OFF"; onToggle(state)
    end)
end

local CONTROL_MODES = {
    {key="classic",label="Classic"},{key="twin-stick",label="Sticks"},
    {key="tap-to-fly",label="Tap"},{key="gyro",label="Gyro"},
}
rowLabel(settingsFrame, "CONTROL MODE", 1)
oRow(CONTROL_MODES, ClientSettings.controlMode, 2, function(key)
    ClientSettings.controlMode=key; saveSettings:FireServer("controlMode",key)
end)
rowLabel(settingsFrame, "INVERT Y", 3)
tRow("Invert Y-Axis", ClientSettings.invertY, 4, function(val)
    ClientSettings.invertY=val; saveSettings:FireServer("invertY",val)
end)

if isMobile then
    rowLabel(settingsFrame, "GYRO SENSITIVITY", 5)
    local sensVal=ClientSettings.gyroSensitivity or 1.0
    local sc=Instance.new("Frame")
    sc.Size=UDim2.new(1,0,0,ROW_H+4); sc.BackgroundTransparency=1
    sc.LayoutOrder=6; sc.Parent=settingsFrame
    local sensLbl=Instance.new("TextLabel")
    sensLbl.Size=UDim2.new(0,40,1,0); sensLbl.Position=UDim2.new(0.5,-20,0,0)
    sensLbl.BackgroundTransparency=1; sensLbl.TextColor3=TEXT
    sensLbl.TextSize=12; sensLbl.Font=Enum.Font.GothamBold
    sensLbl.Text=string.format("%.1f",sensVal); sensLbl.Parent=sc
    local function adjBtn(label,xOff,delta)
        local btn=Instance.new("TextButton")
        btn.Size=UDim2.new(0,34,0,ROW_H); btn.Position=UDim2.new(0,xOff,0.5,-ROW_H/2)
        btn.BackgroundColor3=UNSEL; btn.Text=label; btn.TextSize=16
        btn.Font=Enum.Font.GothamBold; btn.TextColor3=TEXT
        btn.BorderSizePixel=0; btn.AutoButtonColor=false; btn.Parent=sc
        Instance.new("UICorner",btn).CornerRadius=UDim.new(0,4)
        btn.MouseButton1Click:Connect(function()
            sensVal=math.clamp(sensVal+delta,0.1,3.0)
            sensLbl.Text=string.format("%.1f",sensVal)
            ClientSettings.gyroSensitivity=sensVal
            saveSettings:FireServer("gyroSensitivity",sensVal)
        end)
    end
    adjBtn("−",4,-0.1); adjBtn("+",110,0.1)
end

loadSettings.OnClientEvent:Connect(function(settings)
    for k,v in pairs(settings) do ClientSettings[k]=v end
    if isMobile and ClientSettings.controlMode=="classic" then
        ClientSettings.controlMode="twin-stick"
    end
end)

print("[Sidebar] Active")
