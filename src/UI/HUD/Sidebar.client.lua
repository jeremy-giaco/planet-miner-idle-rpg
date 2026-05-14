-- LocalScript → StarterGui/Sidebar
-- Three independent popdown buttons at top of screen (right of Roblox buttons).

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

local BG    = Color3.fromRGB(10, 6, 28)
local NEON  = Color3.fromRGB(100, 60, 240)
local TEXT  = Color3.fromRGB(235, 225, 255)
local DIM   = Color3.fromRGB(190, 175, 225)
local SEL   = Color3.fromRGB(90, 55, 200)
local UNSEL = Color3.fromRGB(45, 32, 90)
local ALPHA = 0.0   -- popups fully opaque for readability

local ROW_H          = 26
local BTN_H          = 36
local POPUP_W        = 175   -- default popup width; settings overrides to wider
local SETTINGS_POP_W = 240   -- extra width so 4 control buttons aren't cramped
-- Roblox's home + chat buttons; IgnoreGuiInset=true so we share the same top bar.
-- On most phones the Roblox buttons are ~36px tall and ~180px wide (home+chat+backpack).
local ROBLOX_RESERVED = 196

-- ── Screen GUI ────────────────────────────────────────────────────────────────

local sg = Instance.new("ScreenGui")
sg.Name = "Sidebar"; sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = playerGui

-- ── Backdrop — invisible full-screen button; click anywhere to close popups ───

local backdrop = Instance.new("TextButton")
backdrop.Name                   = "Backdrop"
backdrop.Size                   = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundTransparency = 1
backdrop.Text                   = ""
backdrop.BorderSizePixel        = 0
backdrop.ZIndex                 = 5   -- below popups (ZIndex 20) and buttons (ZIndex 15)
backdrop.Visible                = false
backdrop.Parent                 = sg

local function closeAll()
    backdrop.Visible = false
    -- allCloseFns populated later; call via shared table
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function applyBg(f, alpha)
    f.BackgroundColor3       = BG
    f.BackgroundTransparency = alpha or ALPHA
    f.BorderSizePixel        = 0
end

local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or NEON; s.Thickness = thickness or 1; s.Parent = parent
end

local function corner(parent, r)
    Instance.new("UICorner", parent).CornerRadius = UDim.new(0, r or 8)
end

-- ── Button container (fills top bar right of Roblox buttons) ─────────────────

local btnBar = Instance.new("Frame")
btnBar.Name     = "BtnBar"
btnBar.Size     = UDim2.new(1, -ROBLOX_RESERVED, 0, BTN_H)
btnBar.Position = UDim2.new(0, ROBLOX_RESERVED, 0, 0)
btnBar.BackgroundTransparency = 1
btnBar.BorderSizePixel = 0
btnBar.Parent = sg

do
    local ll = Instance.new("UIListLayout")
    ll.FillDirection = Enum.FillDirection.Horizontal
    ll.HorizontalAlignment = Enum.HorizontalAlignment.Left
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Padding = UDim.new(0, 0)
    ll.Parent = btnBar
end

-- ── Popup builder (slides down from under its button) ─────────────────────────

local function makePopup(contentHeight)
    local popup = Instance.new("Frame")
    popup.Name    = "Popup"
    popup.Size    = UDim2.new(0, POPUP_W, 0, 0)   -- starts collapsed
    popup.Position= UDim2.new(0, 0, 0, BTN_H)     -- X set after layout
    applyBg(popup, ALPHA)
    popup.ClipsDescendants = true
    popup.ZIndex = 20
    popup.Parent = sg
    corner(popup, 8)
    stroke(popup)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = NEON
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.Parent = popup
    do
        local p = Instance.new("UIPadding")
        p.PaddingLeft=UDim.new(0,8); p.PaddingRight=UDim.new(0,8)
        p.PaddingTop=UDim.new(0,6);  p.PaddingBottom=UDim.new(0,6)
        p.Parent = scroll
    end
    do
        local ll = Instance.new("UIListLayout")
        ll.FillDirection = Enum.FillDirection.Vertical
        ll.SortOrder = Enum.SortOrder.LayoutOrder
        ll.Padding = UDim.new(0, 3)
        ll.Parent = scroll
    end

    local openH  = contentHeight
    local isOpen = false
    local twOpen  = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local twClose = TweenInfo.new(0.14, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

    local function toggle()
        isOpen = not isOpen
        local w = popup.Size.X.Offset
        TweenService:Create(popup, isOpen and twOpen or twClose,
            { Size = UDim2.new(0, w, 0, isOpen and openH or 0) }):Play()
        return isOpen
    end

    local function close()
        if isOpen then isOpen = false
            local w = popup.Size.X.Offset
            TweenService:Create(popup, twClose, { Size = UDim2.new(0, w, 0, 0) }):Play()
        end
    end

    return popup, scroll, toggle, close
end

-- ── Tab button builder ────────────────────────────────────────────────────────

-- Track open popups so only one is open at a time
local allCloseFns = {}
local allTabBtns  = {}

backdrop.MouseButton1Click:Connect(function()
    for _, fn in ipairs(allCloseFns) do fn() end
    for _, b  in ipairs(allTabBtns)  do b.TextColor3 = Color3.fromRGB(255,255,255) end
    backdrop.Visible = false
end)

local function makeTabBtn(icon, label, order, popup, toggleFn, closeFn)
    table.insert(allCloseFns, closeFn)

    local btn = Instance.new("TextButton")
    btn.Name   = label .. "TabBtn"
    btn.Size   = UDim2.new(1/3, 0, 1, 0)
    btn.BackgroundTransparency = 1   -- no background, just floating text
    btn.BorderSizePixel = 0
    btn.Text   = icon .. " " .. label
    btn.TextSize = 13
    btn.Font   = Enum.Font.GothamBold
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextStrokeColor3 = Color3.new(0, 0, 0)
    btn.TextStrokeTransparency = 0.4
    btn.AutoButtonColor = false
    btn.LayoutOrder = order
    btn.ZIndex = 15
    btn.Parent = btnBar

    -- Set popup X position after layout resolves (use popup's own width for centering)
    task.defer(function()
        local ax = btn.AbsolutePosition.X
        local bw = btn.AbsoluteSize.X
        local pw = popup.Size.X.Offset
        local px = ax + bw/2 - pw/2
        local screenW = camera.ViewportSize.X
        px = math.clamp(px, 4, screenW - pw - 4)
        popup.Position = UDim2.new(0, px, 0, BTN_H)
    end)

    table.insert(allTabBtns, btn)

    btn.MouseButton1Click:Connect(function()
        local opening = toggleFn()
        if opening then
            for _, fn in ipairs(allCloseFns) do
                if fn ~= closeFn then fn() end
            end
            for _, b in ipairs(allTabBtns) do b.TextColor3 = Color3.fromRGB(255,255,255) end
            btn.TextColor3  = Color3.fromRGB(255, 240, 100)
            backdrop.Visible = true
        else
            btn.TextColor3   = Color3.fromRGB(255, 255, 255)
            backdrop.Visible = false
        end
    end)

    return btn
end

-- ══════════════════════════════════════════════════════════════════════════════
-- DRONES  (6 rows × 26px + padding ≈ 190px)
-- ══════════════════════════════════════════════════════════════════════════════

local dronePopup, droneScroll, droneToggle, droneClose = makePopup(196)

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

local droneMode={} local droneAlive={} local healthFills={} local modeLabels={} local modeBtns={}
for i=1,6 do droneMode[i]=DEFAULT_MODES[i]; droneAlive[i]=true end

for i = 1, 6 do
    local init = DEFAULT_MODES[i]
    local row = Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,ROW_H); row.BackgroundTransparency=1
    row.BorderSizePixel=0; row.LayoutOrder=i; row.Parent=droneScroll

    local lbl=Instance.new("TextLabel")
    lbl.Text=tostring(i); lbl.Size=UDim2.new(0,14,1,0)
    lbl.BackgroundTransparency=1; lbl.TextColor3=TEXT
    lbl.TextSize=12; lbl.Font=Enum.Font.GothamBold; lbl.Parent=row

    local btn=Instance.new("TextButton")
    btn.Name="ModeBtn"; btn.Size=UDim2.new(1,-18,1,-2)
    btn.Position=UDim2.new(0,16,0,1); btn.BackgroundColor3=MODE_BG[init]
    btn.Text=""; btn.BorderSizePixel=0; btn.AutoButtonColor=false
    btn.ClipsDescendants=true; btn.Parent=row
    corner(btn,4)

    local fill=Instance.new("Frame")
    fill.Size=UDim2.new(1,0,1,0); fill.BackgroundColor3=MODE_FILL[init]
    fill.BorderSizePixel=0; fill.ZIndex=btn.ZIndex+1; fill.Parent=btn
    corner(fill,4)

    local mt=Instance.new("TextLabel")
    mt.Text=MODE_LABEL[init]; mt.Size=UDim2.new(1,0,1,0)
    mt.BackgroundTransparency=1; mt.TextColor3=Color3.new(1,1,1)
    mt.TextSize=11; mt.Font=Enum.Font.GothamBold
    mt.ZIndex=fill.ZIndex+1; mt.Parent=btn

    healthFills[i]=fill; modeLabels[i]=mt; modeBtns[i]=btn
    local idx=i
    btn.MouseButton1Click:Connect(function()
        if not droneAlive[idx] then return end
        local cur=droneMode[idx]; local ni=1
        for m,mode in ipairs(MODES) do
            if mode==cur then ni=(m%#MODES)+1; break end
        end
        local nm=MODES[ni]; droneMode[idx]=nm
        fill.BackgroundColor3=MODE_FILL[nm]
        btn.BackgroundColor3=MODE_BG[nm]
        mt.Text=MODE_LABEL[nm]
        setDroneModeEvent:FireServer(idx,nm)
    end)
end

droneHealthEvent.OnClientEvent:Connect(function(idx,health,maxHealth,alive)
    local fill=healthFills[idx]; local btn=modeBtns[idx]; local mt=modeLabels[idx]
    if not fill then return end
    droneAlive[idx]=alive
    if not alive then
        fill.Size=UDim2.new(0,0,1,0); fill.BackgroundColor3=OFFLINE_FILL
        btn.BackgroundColor3=OFFLINE_BG; mt.Text="OFFLINE"
        mt.TextColor3=Color3.fromRGB(180,60,60)
    else
        fill.Size=UDim2.new(math.clamp(health/(maxHealth or 100),0,1),0,1,0)
        local mode=droneMode[idx]
        fill.BackgroundColor3=MODE_FILL[mode]; btn.BackgroundColor3=MODE_BG[mode]
        mt.Text=MODE_LABEL[mode]; mt.TextColor3=Color3.new(1,1,1)
    end
end)

local droneTabBtn = makeTabBtn("🤖","DRONES",1,dronePopup,droneToggle,droneClose)

-- ══════════════════════════════════════════════════════════════════════════════
-- CARGO  — all resource types always shown, icon dot + name + qty
-- ══════════════════════════════════════════════════════════════════════════════

-- Fragment types + metal types always shown even at 0
local RESOURCE_DEFS = {
    -- Fragments
    { key="f_Rock",     label="Rock",     color=Color3.fromRGB(130,100, 70), kind="fragment" },
    { key="f_Metal",    label="Metal",    color=Color3.fromRGB(160,165,185), kind="fragment" },
    { key="f_Crystal",  label="Crystal",  color=Color3.fromRGB(130, 75,240), kind="fragment" },
    { key="f_Ice",      label="Ice",      color=Color3.fromRGB(150,200,255), kind="fragment" },
    -- Metals
    { key="m_Iron",     label="Iron",     color=Color3.fromRGB(140,130,120), kind="metal" },
    { key="m_Copper",   label="Copper",   color=Color3.fromRGB(210,105, 55), kind="metal" },
    { key="m_Silver",   label="Silver",   color=Color3.fromRGB(200,205,220), kind="metal" },
    { key="m_Gold",     label="Gold",     color=Color3.fromRGB(220,170, 20), kind="metal" },
    { key="m_Titanium", label="Titanium", color=Color3.fromRGB(155,175,200), kind="metal" },
}

local CARGO_ROW_H = 22
-- 9 resources + section divider line ≈ 9×25 + 16 = 241 → round up
local cargoPopup, cargoScroll, cargoToggle, cargoClose = makePopup(246)

local inventory = { fragments={}, metals={} }
local qtyLabels = {}   -- [key] = TextLabel showing qty

-- Build all slots once (always present)
for order, def in ipairs(RESOURCE_DEFS) do
    local row = Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,CARGO_ROW_H); row.BackgroundTransparency=1
    row.BorderSizePixel=0; row.LayoutOrder=order; row.Parent=cargoScroll

    -- Coloured dot
    local dot=Instance.new("Frame")
    dot.Size=UDim2.new(0,10,0,10); dot.Position=UDim2.new(0,0,0.5,-5)
    dot.BackgroundColor3=def.color; dot.BorderSizePixel=0; dot.Parent=row
    corner(dot,5)

    -- Resource name
    local name=Instance.new("TextLabel")
    name.Text=def.label; name.Size=UDim2.new(0.65,0,1,0)
    name.Position=UDim2.new(0,16,0,0)
    name.BackgroundTransparency=1; name.TextColor3=TEXT
    name.TextSize=12; name.Font=Enum.Font.Gotham
    name.TextXAlignment=Enum.TextXAlignment.Left; name.Parent=row

    -- Qty (right-aligned)
    local qty=Instance.new("TextLabel")
    qty.Name="Qty"; qty.Text="0"; qty.Size=UDim2.new(0.3,0,1,0)
    qty.Position=UDim2.new(0.7,0,0,0)
    qty.BackgroundTransparency=1; qty.TextColor3=DIM
    qty.TextSize=12; qty.Font=Enum.Font.GothamBold
    qty.TextXAlignment=Enum.TextXAlignment.Right; qty.Parent=row

    qtyLabels[def.key] = qty
end

local function updateCargo()
    for _, def in ipairs(RESOURCE_DEFS) do
        local qty = 0
        if def.kind=="fragment" then
            qty = inventory.fragments[def.label] or 0
        else
            qty = inventory.metals[def.label] or 0
        end
        local lbl = qtyLabels[def.key]
        if lbl then
            lbl.Text = tostring(qty)
            lbl.TextColor3 = qty>0 and Color3.fromRGB(255,240,130) or DIM
        end
    end
    -- Glow cargo tab when carrying anything
    local has = next(inventory.fragments)~=nil or next(inventory.metals)~=nil
    -- find cargo tab btn (set in makeTabBtn, stored below)
end

local function makeToast(text,color,worldPos)
    local sx,sy=0.5,0.5
    if worldPos then
        local sp,on=camera:WorldToScreenPoint(worldPos)
        if on then local vp=camera.ViewportSize; sx=sp.X/vp.X; sy=sp.Y/vp.Y end
    end
    local t=Instance.new("TextLabel")
    t.Text=text; t.Size=UDim2.new(0,180,0,32); t.Position=UDim2.new(sx,-90,sy,-16)
    t.BackgroundTransparency=1; t.TextColor3=color; t.TextTransparency=0.1; t.TextSize=20
    t.Font=Enum.Font.GothamBold; t.TextStrokeColor3=Color3.new(0,0,0)
    t.TextStrokeTransparency=0.45; t.Parent=sg
    TweenService:Create(t,TweenInfo.new(1.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
        TextTransparency=1,TextStrokeTransparency=1,Position=UDim2.new(sx,-90,sy-0.06,-16),
    }):Play()
    task.delay(1.2,function() if t and t.Parent then t:Destroy() end end)
end

collectFragmentEvent.OnClientEvent:Connect(function(ft,qty,wp)
    inventory.fragments[ft]=(inventory.fragments[ft] or 0)+(qty or 1)
    updateCargo(); makeToast("+"..( qty or 1).." "..ft, Color3.fromRGB(200,200,255), wp)
end)
collectMetalEvent.OnClientEvent:Connect(function(name)
    inventory.metals[name]=(inventory.metals[name] or 0)+1
    updateCargo(); makeToast("+ "..name, Color3.fromRGB(255,210,50))
end)
deductMetalEvent.OnClientEvent:Connect(function(name)
    local c=inventory.metals[name] or 0
    inventory.metals[name]=c<=1 and nil or c-1
    updateCargo(); makeToast("- "..name, Color3.fromRGB(200,80,80))
end)
updateCargo()

local cargoTabBtn = makeTabBtn("📦","CARGO",2,cargoPopup,cargoToggle,cargoClose)

-- ══════════════════════════════════════════════════════════════════════════════
-- SETTINGS
-- ══════════════════════════════════════════════════════════════════════════════

-- Control mode (4 opts) + invert Y + optional gyro ≈ 180px
local settingsPopup, settingsScroll, settingsToggle, settingsClose = makePopup(185)
settingsPopup.Size = UDim2.new(0, SETTINGS_POP_W, 0, 0)   -- wider for 4 control buttons

local function oRow(options, currentKey, order, onSelect)
    local c=Instance.new("Frame")
    c.Size=UDim2.new(1,0,0,ROW_H); c.BackgroundTransparency=1
    c.LayoutOrder=order; c.Parent=settingsScroll
    local ll=Instance.new("UIListLayout")
    ll.FillDirection=Enum.FillDirection.Horizontal; ll.Padding=UDim.new(0,3); ll.Parent=c
    local btns={}
    for _,opt in ipairs(options) do
        local btn=Instance.new("TextButton")
        btn.Size=UDim2.new(1/#options,-3,1,0)
        btn.BackgroundColor3=(opt.key==currentKey) and SEL or UNSEL
        btn.Text=opt.label; btn.TextSize=12; btn.Font=Enum.Font.GothamBold
        btn.TextColor3=Color3.new(1,1,1); btn.BorderSizePixel=0
        btn.AutoButtonColor=false; btn.Parent=c
        corner(btn,4)
        table.insert(btns,btn)
        btn.MouseButton1Click:Connect(function()
            for _,b in ipairs(btns) do b.BackgroundColor3=UNSEL end
            btn.BackgroundColor3=SEL; onSelect(opt.key)
        end)
    end
end

local function sLbl(text,order)
    local l=Instance.new("TextLabel")
    l.Text=text; l.Size=UDim2.new(1,0,0,14)
    l.BackgroundTransparency=1; l.TextColor3=DIM
    l.TextSize=11; l.Font=Enum.Font.GothamBold
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.LayoutOrder=order; l.Parent=settingsScroll
end

local function tRow(label,currentVal,order,onToggle)
    local c=Instance.new("Frame")
    c.Size=UDim2.new(1,0,0,ROW_H); c.BackgroundTransparency=1
    c.LayoutOrder=order; c.Parent=settingsScroll
    local lbl=Instance.new("TextLabel")
    lbl.Text=label; lbl.Size=UDim2.new(0.6,0,1,0)
    lbl.BackgroundTransparency=1; lbl.TextColor3=TEXT
    lbl.TextSize=12; lbl.Font=Enum.Font.Gotham
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=c
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(0,46,0,ROW_H-2); btn.Position=UDim2.new(1,-46,0.5,-(ROW_H-2)/2)
    btn.BackgroundColor3=currentVal and Color3.fromRGB(0,170,70) or Color3.fromRGB(80,30,30)
    btn.Text=currentVal and "ON" or "OFF"; btn.TextSize=12; btn.Font=Enum.Font.GothamBold
    btn.TextColor3=Color3.new(1,1,1); btn.BorderSizePixel=0; btn.AutoButtonColor=false; btn.Parent=c
    corner(btn,4)
    local state=currentVal
    btn.MouseButton1Click:Connect(function()
        state=not state
        btn.BackgroundColor3=state and Color3.fromRGB(0,170,70) or Color3.fromRGB(80,30,30)
        btn.Text=state and "ON" or "OFF"; onToggle(state)
    end)
end

local CONTROL_MODES={
    {key="classic",label="Classic"},{key="twin-stick",label="Sticks"},
    {key="tap-to-fly",label="Tap"},{key="gyro",label="Gyro"},
}
sLbl("CONTROL MODE",1)
oRow(CONTROL_MODES,ClientSettings.controlMode,2,function(key)
    ClientSettings.controlMode=key; saveSettings:FireServer("controlMode",key)
end)
sLbl("INVERT Y",3)
tRow("Invert Y-Axis",ClientSettings.invertY,4,function(val)
    ClientSettings.invertY=val; saveSettings:FireServer("invertY",val)
end)

if isMobile then
    sLbl("GYRO SENSITIVITY",5)
    local sensVal=ClientSettings.gyroSensitivity or 1.0
    local sc=Instance.new("Frame")
    sc.Size=UDim2.new(1,0,0,ROW_H+4); sc.BackgroundTransparency=1
    sc.LayoutOrder=6; sc.Parent=settingsScroll
    local sensLbl=Instance.new("TextLabel")
    sensLbl.Size=UDim2.new(0,40,1,0); sensLbl.Position=UDim2.new(0.5,-20,0,0)
    sensLbl.BackgroundTransparency=1; sensLbl.TextColor3=TEXT
    sensLbl.TextSize=12; sensLbl.Font=Enum.Font.GothamBold
    sensLbl.Text=string.format("%.1f",sensVal); sensLbl.Parent=sc
    local function adjBtn(lbl,xOff,delta)
        local b=Instance.new("TextButton")
        b.Size=UDim2.new(0,34,0,ROW_H); b.Position=UDim2.new(0,xOff,0.5,-ROW_H/2)
        b.BackgroundColor3=UNSEL; b.Text=lbl; b.TextSize=16
        b.Font=Enum.Font.GothamBold; b.TextColor3=TEXT
        b.BorderSizePixel=0; b.AutoButtonColor=false; b.Parent=sc
        corner(b,4)
        b.MouseButton1Click:Connect(function()
            sensVal=math.clamp(sensVal+delta,0.1,3.0)
            sensLbl.Text=string.format("%.1f",sensVal)
            ClientSettings.gyroSensitivity=sensVal
            saveSettings:FireServer("gyroSensitivity",sensVal)
        end)
    end
    adjBtn("−",4,-0.1); adjBtn("+",100,0.1)
end

loadSettings.OnClientEvent:Connect(function(settings)
    for k,v in pairs(settings) do ClientSettings[k]=v end
    if isMobile and ClientSettings.controlMode=="classic" then
        ClientSettings.controlMode="twin-stick"
    end
end)

makeTabBtn("⚙","SETTINGS",3,settingsPopup,settingsToggle,settingsClose)

print("[Sidebar] Active")
