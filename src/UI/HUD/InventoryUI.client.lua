-- LocalScript → StarterGui, rename to "InventoryUI"
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for remotes (DebrisSystem creates these; retry until ready)
local remotes              = ReplicatedStorage:WaitForChild("Remotes")
local collectFragmentEvent = remotes:WaitForChild("CollectFragment")
local collectMetalEvent    = remotes:WaitForChild("CollectMetal")
local deductMetalEvent     = remotes:WaitForChild("DeductMetal")

local camera = workspace.CurrentCamera

local inventory = { fragments = {}, metals = {} }

-- ── Screen GUI ───────────────────────────────────────────────────────────────

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local screenGui = Instance.new("ScreenGui")
screenGui.Name         = "InventoryUI"
screenGui.ResetOnSpawn = false
screenGui.Parent       = playerGui

-- ── CARGO HOLD panel ─────────────────────────────────────────────────────────

local PANEL_W   = 230
local PANEL_H   = 200
local TAB_W     = 44
local TAB_H     = 56
local panelOpen = false

-- Toggle tab (left edge, just below drone toggle)
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name                   = "CargoToggle"
toggleBtn.Size                   = UDim2.new(0, TAB_W, 0, TAB_H)
toggleBtn.Position               = UDim2.new(0, 8, 0.5, 4)
toggleBtn.BackgroundColor3       = Color3.fromRGB(20, 15, 55)
toggleBtn.BackgroundTransparency = 0.2
toggleBtn.Text                   = "📦"
toggleBtn.TextSize               = 22
toggleBtn.Font                   = Enum.Font.GothamBold
toggleBtn.TextColor3             = Color3.fromRGB(180, 140, 255)
toggleBtn.BorderSizePixel        = 0
toggleBtn.ZIndex                 = 10
toggleBtn.Parent                 = screenGui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)
do local s = Instance.new("UIStroke")
   s.Color = Color3.fromRGB(100, 60, 220); s.Thickness = 1.5; s.Parent = toggleBtn end

local panel = Instance.new("Frame")
panel.Name                   = "Panel"
panel.Size                   = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position               = UDim2.new(0, -(PANEL_W + 20), 0.5, -PANEL_H / 2)
panel.BackgroundColor3       = Color3.fromRGB(8, 6, 22)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel        = 0
panel.Parent                 = screenGui

local OPEN_POS  = UDim2.new(0, TAB_W + 16, 0, 252)         -- slot 2: below drone (20+224+8)
local CLOSE_POS = UDim2.new(0, -(PANEL_W + 20), 0, 252)
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local function updateToggleGlow()
    local hasItems = next(inventory.fragments) ~= nil or next(inventory.metals) ~= nil
    toggleBtn.BackgroundColor3 = hasItems
        and Color3.fromRGB(80, 50, 180)
        or  Color3.fromRGB(20, 15, 55)
    toggleBtn.TextColor3 = hasItems
        and Color3.fromRGB(255, 220, 100)
        or  Color3.fromRGB(180, 140, 255)
end

toggleBtn.MouseButton1Click:Connect(function()
    panelOpen = not panelOpen
    TweenService:Create(panel, tweenInfo,
        { Position = panelOpen and OPEN_POS or CLOSE_POS }):Play()
end)

do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = panel
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(100,60,220); s.Thickness = 1.5; s.Parent = panel

    local t = Instance.new("TextButton")
    t.Text = "CARGO HOLD  ⠿"; t.Size = UDim2.new(1,0,0,30)
    t.BackgroundTransparency = 1; t.TextColor3 = Color3.fromRGB(180,140,255)
    t.TextSize = 13; t.Font = Enum.Font.GothamBold
    t.AutoButtonColor = false; t.Parent = panel

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
    t.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging   = true
            dragStart  = input.Position
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
end

local SLOT_COLOR = {
    -- Fragments
    Rock    = Color3.fromRGB(130, 100,  70),
    Metal   = Color3.fromRGB(160, 165, 185),
    Crystal = Color3.fromRGB(130,  75, 240),
    Ice     = Color3.fromRGB(150, 200, 255),
    -- Metals
    Iron     = Color3.fromRGB(140, 130, 120),
    Copper   = Color3.fromRGB(210, 105,  55),
    Silver   = Color3.fromRGB(200, 205, 220),
    Gold     = Color3.fromRGB(220, 170,  20),
    Titanium = Color3.fromRGB(155, 175, 200),
}

local itemSlots = {}

local function makeSlot(label, color, col, row, yStart)
    local slot = Instance.new("TextLabel")
    slot.Text                   = label
    slot.Size                   = UDim2.new(0.46, 0, 0, 24)
    slot.Position               = UDim2.new(col * 0.5 + 0.02, 0, 0, yStart + row * 28)
    slot.BackgroundColor3       = color
    slot.BackgroundTransparency = 0.5
    slot.TextColor3             = Color3.new(1, 1, 1)
    slot.TextSize               = 11
    slot.Font                   = Enum.Font.Gotham
    slot.BorderSizePixel        = 0
    slot.Parent                 = panel
    Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 5)
    return slot
end

local function rebuildSlots()
    for _, s in pairs(itemSlots) do s:Destroy() end
    itemSlots = {}

    -- Section label: Metals
    local mi = 0
    for name, count in pairs(inventory.metals) do
        local slot = makeSlot(
            string.format("%s ×%d", name, count),
            SLOT_COLOR[name] or Color3.fromRGB(180,160,80),
            mi % 2, math.floor(mi / 2), 34
        )
        itemSlots["m_"..name] = slot
        mi += 1
    end

    -- Section label: Fragments (below metals)
    local metalRows = math.ceil(mi / 2)
    local fragYStart = 34 + metalRows * 28 + (mi > 0 and 8 or 0)
    local fi = 0
    for fragType, count in pairs(inventory.fragments) do
        local slot = makeSlot(
            string.format("%s ×%d", fragType, count),
            SLOT_COLOR[fragType] or Color3.fromRGB(90, 90, 110),
            fi % 2, math.floor(fi / 2), fragYStart
        )
        itemSlots["f_"..fragType] = slot
        fi += 1
    end

    -- Grow panel height to fit content
    local totalRows = math.ceil(mi / 2) + math.ceil(fi / 2)
    local newH = math.max(200, 34 + totalRows * 28 + 36)
    panel.Size  = UDim2.new(0, PANEL_W, 0, newH)
    OPEN_POS    = UDim2.new(0, TAB_W + 16, 0.5, -newH / 2)
    CLOSE_POS   = UDim2.new(0, -(PANEL_W + 20), 0.5, -newH / 2)
    if panelOpen then panel.Position = OPEN_POS end
    updateToggleGlow()
end

-- ── Toast notification ────────────────────────────────────────────────────────

-- Shows a toast floating up from a world position (or screen center if nil)
local function showToast(text, color, worldPos)
    local sx, sy = 0.5, 0.5
    if worldPos then
        local screenPt, onScreen = camera:WorldToScreenPoint(worldPos)
        if onScreen then
            local vp = camera.ViewportSize
            sx = screenPt.X / vp.X
            sy = screenPt.Y / vp.Y
        end
    end

    local toast = Instance.new("TextLabel")
    toast.Text                   = text
    toast.Size                   = UDim2.new(0, 180, 0, 32)
    toast.Position               = UDim2.new(sx, -90, sy, -16)
    toast.BackgroundTransparency = 1
    toast.TextColor3             = color
    toast.TextTransparency       = 0.1
    toast.TextSize               = 20
    toast.Font                   = Enum.Font.GothamBold
    toast.TextStrokeColor3       = Color3.new(0, 0, 0)
    toast.TextStrokeTransparency = 0.45
    toast.Parent                 = screenGui

    TweenService:Create(toast, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextTransparency      = 1,
        TextStrokeTransparency = 1,
        Position = UDim2.new(sx, -90, sy - 0.06, -16),
    }):Play()
    task.delay(1.2, function()
        if toast and toast.Parent then toast:Destroy() end
    end)
end

-- ── Events ────────────────────────────────────────────────────────────────────

collectFragmentEvent.OnClientEvent:Connect(function(fragType, qty, worldPos)
    local amount = qty or 1
    inventory.fragments[fragType] = (inventory.fragments[fragType] or 0) + amount
    rebuildSlots()
    showToast("+" .. amount .. " " .. fragType, SLOT_COLOR[fragType] or Color3.new(1,1,1), worldPos)
end)

collectMetalEvent.OnClientEvent:Connect(function(metalName)
    inventory.metals[metalName] = (inventory.metals[metalName] or 0) + 1
    rebuildSlots()
    showToast("+ " .. metalName, SLOT_COLOR[metalName] or Color3.fromRGB(255, 210, 50))
end)

deductMetalEvent.OnClientEvent:Connect(function(metalName)
    local count = inventory.metals[metalName] or 0
    if count <= 1 then
        inventory.metals[metalName] = nil
    else
        inventory.metals[metalName] = count - 1
    end
    rebuildSlots()
    showToast("- " .. metalName, Color3.fromRGB(200, 80, 80))
end)

rebuildSlots()
