-- LocalScript → StarterGui/InventoryUI
if not game:GetService("RunService"):IsClient() then return end

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = workspace.CurrentCamera

-- ── Remote ────────────────────────────────────────────────────────────────────

local remotes              = ReplicatedStorage:WaitForChild("Remotes")
local collectMaterialEvent = remotes:WaitForChild("CollectFragment")  -- server fires this

-- ── Material lookup (built from Config) ──────────────────────────────────────
-- matInfo[name] = { color, rarity, element }

local matInfo   = {}
local rarityOrder = { Common = 1, Uncommon = 2, Rare = 3, Exotic = 4 }

for _, m in ipairs(Config.MATERIALS) do
    matInfo[m.name] = { color = m.color, rarity = m.rarity, element = m.element }
end

-- Rarity header colors
local RARITY_COLOR = {}
for _, r in ipairs(Config.RARITIES) do
    RARITY_COLOR[r.name] = r.color
end

-- ── Inventory state ───────────────────────────────────────────────────────────

local inventory = {}   -- inventory[matName] = qty

-- ── Screen GUI ────────────────────────────────────────────────────────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name         = "InventoryUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent       = playerGui

-- ── Toggle tab ────────────────────────────────────────────────────────────────

local PANEL_W   = 240
local TAB_W     = 44
local TAB_H     = 56
local panelOpen = false

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name                   = "InvToggle"
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
do
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(100, 60, 220); s.Thickness = 1.5; s.Parent = toggleBtn
end

-- ── Panel ─────────────────────────────────────────────────────────────────────

local panel = Instance.new("Frame")
panel.Name                   = "Panel"
panel.Size                   = UDim2.new(0, PANEL_W, 0, 200)
panel.Position               = UDim2.new(0, -(PANEL_W + 20), 0.5, -100)
panel.BackgroundColor3       = Color3.fromRGB(8, 6, 22)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel        = 0
panel.ClipsDescendants       = true
panel.Parent                 = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
do
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(100, 60, 220); s.Thickness = 1.5; s.Parent = panel
end

local OPEN_POS  = UDim2.new(0, TAB_W + 16, 0.5, -100)
local CLOSE_POS = UDim2.new(0, -(PANEL_W + 20), 0.5, -100)
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- ── Title bar (draggable) ─────────────────────────────────────────────────────

local titleBar = Instance.new("TextButton")
titleBar.Text                   = "INVENTORY"
titleBar.Size                   = UDim2.new(1, 0, 0, 32)
titleBar.Position               = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundColor3       = Color3.fromRGB(18, 12, 48)
titleBar.BackgroundTransparency = 0
titleBar.TextColor3             = Color3.fromRGB(180, 140, 255)
titleBar.TextSize               = 13
titleBar.Font                   = Enum.Font.GothamBold
titleBar.BorderSizePixel        = 0
titleBar.AutoButtonColor        = false
titleBar.ZIndex                 = 5
titleBar.Parent                 = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

do
    local dragging, dragStart, panelStart
    local function onInput(input)
        if not dragging then return end
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(
            panelStart.X.Scale, panelStart.X.Offset + delta.X,
            panelStart.Y.Scale, panelStart.Y.Offset + delta.Y)
        OPEN_POS  = panel.Position
        CLOSE_POS = UDim2.new(0, -(PANEL_W + 20), OPEN_POS.Y.Scale, OPEN_POS.Y.Offset)
    end
    titleBar.InputBegan:Connect(function(input)
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
            onInput(input)
        end
    end)
end

-- ── Scroll frame for items ────────────────────────────────────────────────────

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name                    = "ItemScroll"
scrollFrame.Size                    = UDim2.new(1, -8, 1, -36)
scrollFrame.Position                = UDim2.new(0, 4, 0, 34)
scrollFrame.BackgroundTransparency  = 1
scrollFrame.BorderSizePixel         = 0
scrollFrame.ScrollBarThickness      = 4
scrollFrame.ScrollBarImageColor3    = Color3.fromRGB(100, 60, 220)
scrollFrame.CanvasSize              = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize     = Enum.AutomaticSize.Y
scrollFrame.Parent                  = panel

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder       = Enum.SortOrder.LayoutOrder
listLayout.Padding         = UDim.new(0, 3)
listLayout.Parent          = scrollFrame

local padding = Instance.new("UIPadding")
padding.PaddingTop    = UDim.new(0, 4)
padding.PaddingBottom = UDim.new(0, 4)
padding.PaddingLeft   = UDim.new(0, 4)
padding.PaddingRight  = UDim.new(0, 4)
padding.Parent        = scrollFrame

-- ── Slot builders ─────────────────────────────────────────────────────────────

local function makeHeader(text, color, order)
    local lbl = Instance.new("TextLabel")
    lbl.Text                   = text
    lbl.Size                   = UDim2.new(1, -8, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3             = color
    lbl.TextSize               = 10
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.LayoutOrder            = order
    lbl.Parent                 = scrollFrame
    return lbl
end

local function makeSlot(matName, qty, matColor, rarityColor, order)
    local row = Instance.new("Frame")
    row.Size                   = UDim2.new(1, -8, 0, 26)
    row.BackgroundColor3       = Color3.fromRGB(18, 14, 38)
    row.BackgroundTransparency = 0.3
    row.BorderSizePixel        = 0
    row.LayoutOrder            = order
    row.Parent                 = scrollFrame
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

    -- Left color swatch
    local swatch = Instance.new("Frame")
    swatch.Size             = UDim2.new(0, 6, 0.7, 0)
    swatch.Position         = UDim2.new(0, 4, 0.15, 0)
    swatch.BackgroundColor3 = matColor
    swatch.BorderSizePixel  = 0
    swatch.Parent           = row
    Instance.new("UICorner", swatch).CornerRadius = UDim.new(0, 3)

    -- Material name
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Text               = matName
    nameLbl.Size               = UDim2.new(1, -70, 1, 0)
    nameLbl.Position           = UDim2.new(0, 16, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.TextColor3         = Color3.new(1, 1, 1)
    nameLbl.TextSize           = 12
    nameLbl.Font               = Enum.Font.Gotham
    nameLbl.TextXAlignment     = Enum.TextXAlignment.Left
    nameLbl.Parent             = row

    -- Quantity (right-aligned)
    local qtyLbl = Instance.new("TextLabel")
    qtyLbl.Text              = "×" .. tostring(qty)
    qtyLbl.Size              = UDim2.new(0, 60, 1, 0)
    qtyLbl.Position          = UDim2.new(1, -64, 0, 0)
    qtyLbl.BackgroundTransparency = 1
    qtyLbl.TextColor3        = rarityColor or Color3.new(1, 1, 1)
    qtyLbl.TextSize          = 12
    qtyLbl.Font              = Enum.Font.GothamBold
    qtyLbl.TextXAlignment    = Enum.TextXAlignment.Right
    qtyLbl.Parent            = row

    return row
end

-- ── Rebuild inventory panel ───────────────────────────────────────────────────

local slotInstances = {}

local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Exotic" }

local function rebuildSlots()
    for _, inst in pairs(slotInstances) do inst:Destroy() end
    slotInstances = {}

    -- Group by rarity
    local groups = {}
    for name, qty in pairs(inventory) do
        local info = matInfo[name]
        if info and qty > 0 then
            local r = info.rarity or "Common"
            if not groups[r] then groups[r] = {} end
            table.insert(groups[r], { name = name, qty = qty, color = info.color })
        end
    end

    -- Sort each group alphabetically
    for _, list in pairs(groups) do
        table.sort(list, function(a, b) return a.name < b.name end)
    end

    local layoutOrder = 0
    local hasAny = false

    for _, rarityName in ipairs(RARITY_ORDER) do
        local list = groups[rarityName]
        if list and #list > 0 then
            hasAny = true
            local hColor = RARITY_COLOR[rarityName] or Color3.new(1, 1, 1)
            local header = makeHeader("── " .. rarityName:upper() .. " ──", hColor, layoutOrder)
            table.insert(slotInstances, header)
            layoutOrder += 1

            for _, entry in ipairs(list) do
                local slot = makeSlot(entry.name, entry.qty, entry.color, hColor, layoutOrder)
                table.insert(slotInstances, slot)
                layoutOrder += 1
            end
        end
    end

    -- Empty state
    if not hasAny then
        local empty = Instance.new("TextLabel")
        empty.Text               = "No materials collected"
        empty.Size               = UDim2.new(1, -8, 0, 32)
        empty.BackgroundTransparency = 1
        empty.TextColor3         = Color3.fromRGB(100, 90, 130)
        empty.TextSize           = 11
        empty.Font               = Enum.Font.Gotham
        empty.LayoutOrder        = 0
        empty.Parent             = scrollFrame
        table.insert(slotInstances, empty)
    end

    -- Resize panel to fit (capped at 400px, scrolls beyond)
    local contentH = listLayout.AbsoluteContentSize.Y + 12
    local panelH   = math.clamp(contentH + 38, 80, 420)
    panel.Size     = UDim2.new(0, PANEL_W, 0, panelH)
    OPEN_POS       = UDim2.new(OPEN_POS.X.Scale, OPEN_POS.X.Offset, OPEN_POS.Y.Scale, -panelH / 2)
    CLOSE_POS      = UDim2.new(0, -(PANEL_W + 20), OPEN_POS.Y.Scale, -panelH / 2)
    if panelOpen then panel.Position = OPEN_POS end

    -- Toggle glow
    toggleBtn.BackgroundColor3 = hasAny
        and Color3.fromRGB(80, 50, 180)
        or  Color3.fromRGB(20, 15, 55)
    toggleBtn.TextColor3 = hasAny
        and Color3.fromRGB(255, 220, 100)
        or  Color3.fromRGB(180, 140, 255)
end

-- ── Toggle ────────────────────────────────────────────────────────────────────

toggleBtn.MouseButton1Click:Connect(function()
    panelOpen = not panelOpen
    TweenService:Create(panel, tweenInfo,
        { Position = panelOpen and OPEN_POS or CLOSE_POS }):Play()
end)

-- ── Toast ─────────────────────────────────────────────────────────────────────

local function showToast(text, color, worldPos)
    local sx, sy = 0.5, 0.45
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
    toast.Size                   = UDim2.new(0, 200, 0, 32)
    toast.Position               = UDim2.new(sx, -100, sy, -16)
    toast.BackgroundTransparency = 1
    toast.TextColor3             = color
    toast.TextTransparency       = 0.05
    toast.TextSize               = 20
    toast.Font                   = Enum.Font.GothamBold
    toast.TextStrokeColor3       = Color3.new(0, 0, 0)
    toast.TextStrokeTransparency = 0.4
    toast.Parent                 = screenGui

    TweenService:Create(toast, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextTransparency       = 1,
        TextStrokeTransparency = 1,
        Position               = UDim2.new(sx, -100, sy - 0.07, -16),
    }):Play()
    task.delay(1.4, function()
        if toast and toast.Parent then toast:Destroy() end
    end)
end

-- ── Collect event ─────────────────────────────────────────────────────────────

collectMaterialEvent.OnClientEvent:Connect(function(matName, qty, worldPos)
    local amount = qty or 1
    inventory[matName] = (inventory[matName] or 0) + amount

    local info  = matInfo[matName]
    local color = info and info.color or Color3.new(1, 1, 1)
    local rarity = info and info.rarity or "Common"
    local rc    = RARITY_COLOR[rarity] or Color3.new(1, 1, 1)

    rebuildSlots()

    local label = (amount > 1) and ("+" .. amount .. " " .. matName) or ("+ " .. matName)
    showToast(label, rc, worldPos)
end)

-- ── Init ──────────────────────────────────────────────────────────────────────

rebuildSlots()
