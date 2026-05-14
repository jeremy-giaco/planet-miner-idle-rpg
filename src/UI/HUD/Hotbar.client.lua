-- LocalScript → StarterGui
-- Custom tool hotbar replacing the default Roblox backpack UI.
-- Slots auto-populate from the player's backpack. Click or press 1-9 to equip.
if not game:GetService("RunService"):IsClient() then return end

local Players           = game:GetService("Players")
local StarterGui        = game:GetService("StarterGui")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local backpack  = player:WaitForChild("Backpack")

-- Disable default backpack UI
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

-- ── Constants ─────────────────────────────────────────────────────────────────

local SLOT_W     = 64
local SLOT_H     = 64
local SLOT_PAD   = 8
local CORNER     = 10
local BG         = Color3.fromRGB(8, 6, 22)
local BORDER     = Color3.fromRGB(60, 40, 140)
local ACTIVE_BG  = Color3.fromRGB(80, 50, 200)
local ACTIVE_BDR = Color3.fromRGB(120, 80, 255)
local TEXT_COL   = Color3.fromRGB(200, 190, 255)
local DIM_COL    = Color3.fromRGB(100, 90, 140)

-- Tool icon map (emoji fallback if no icon)
local TOOL_ICONS = {
    Laser  = "⚡",
    Beam   = "🔆",
    Shield = "🛡",
}

-- ── Screen GUI ────────────────────────────────────────────────────────────────

local sg = Instance.new("ScreenGui")
sg.Name = "HotbarUI"; sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = playerGui

-- Container centered at bottom
local container = Instance.new("Frame")
container.Name                   = "HotbarContainer"
container.BackgroundTransparency = 1
container.AnchorPoint            = Vector2.new(0.5, 1)
container.Position               = UDim2.new(0.5, 0, 1, -16)
container.Size                   = UDim2.new(0, 1, 0, SLOT_H)  -- resized dynamically
container.Parent                 = sg

local layout = Instance.new("UIListLayout")
layout.FillDirection  = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment   = Enum.VerticalAlignment.Center
layout.Padding        = UDim.new(0, SLOT_PAD)
layout.Parent         = container

-- ── Slot builder ──────────────────────────────────────────────────────────────

local slots = {}  -- { frame, label, hotkey, toolName }

local function getEquippedTool()
    local char = player.Character
    if not char then return nil end
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") then return item end
    end
    return nil
end

local function equipTool(toolName)
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local equipped = getEquippedTool()
    if equipped and equipped.Name == toolName then
        -- Unequip: put back in backpack
        humanoid:UnequipTools()
        return
    end

    -- Equip from backpack
    local tool = backpack:FindFirstChild(toolName)
    if tool then humanoid:EquipTool(tool) end
end

local function makeSlot(index, toolName)
    local frame = Instance.new("Frame")
    frame.Name                   = "Slot_" .. toolName
    frame.LayoutOrder            = index
    frame.Size                   = UDim2.new(0, SLOT_W, 0, SLOT_H)
    frame.BackgroundColor3       = BG
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel        = 0
    frame.Parent                 = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, CORNER)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color     = BORDER
    stroke.Thickness = 1.5
    stroke.Parent    = frame

    -- Icon / name
    local icon = Instance.new("TextLabel")
    icon.Name                   = "Icon"
    icon.Size                   = UDim2.new(1, 0, 0, 36)
    icon.Position               = UDim2.new(0, 0, 0, 6)
    icon.BackgroundTransparency = 1
    icon.Text                   = TOOL_ICONS[toolName] or "🔧"
    icon.TextSize               = 26
    icon.Font                   = Enum.Font.GothamBold
    icon.TextColor3             = TEXT_COL
    icon.Parent                 = frame

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name                   = "Name"
    nameLabel.Size                   = UDim2.new(1, -4, 0, 16)
    nameLabel.Position               = UDim2.new(0, 2, 0, 40)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text                   = toolName
    nameLabel.TextSize               = 10
    nameLabel.Font                   = Enum.Font.GothamBold
    nameLabel.TextColor3             = DIM_COL
    nameLabel.TextScaled             = true
    nameLabel.Parent                 = frame

    -- Hotkey badge
    local hotkey = Instance.new("TextLabel")
    hotkey.Name                   = "Hotkey"
    hotkey.Size                   = UDim2.new(0, 16, 0, 16)
    hotkey.Position               = UDim2.new(0, 4, 0, 4)
    hotkey.BackgroundColor3       = Color3.fromRGB(30, 20, 70)
    hotkey.BackgroundTransparency = 0.3
    hotkey.Text                   = tostring(index)
    hotkey.TextSize               = 9
    hotkey.Font                   = Enum.Font.GothamBold
    hotkey.TextColor3             = DIM_COL
    hotkey.BorderSizePixel        = 0
    hotkey.Parent                 = frame
    Instance.new("UICorner", hotkey).CornerRadius = UDim.new(0, 4)

    -- Click to equip
    local btn = Instance.new("TextButton")
    btn.Size                   = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text                   = ""
    btn.Parent                 = frame
    btn.MouseButton1Click:Connect(function()
        equipTool(toolName)
    end)

    return { frame = frame, stroke = stroke, toolName = toolName, index = index }
end

-- ── Build / rebuild hotbar ────────────────────────────────────────────────────

local function getTools()
    local tools = {}
    local char  = player.Character
    -- From backpack
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            table.insert(tools, item.Name)
        end
    end
    -- Currently equipped tool (it's in character, not backpack)
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then
                -- Add if not already listed
                local found = false
                for _, n in ipairs(tools) do if n == item.Name then found = true break end end
                if not found then table.insert(tools, item.Name) end
            end
        end
    end
    -- Explicit order: Laser=1, Beam=2, Shield=3
    local PRIORITY = { LaserGun = 1, Laser = 1, Beam = 2, Shield = 3 }
    table.sort(tools, function(a, b)
        local pa = PRIORITY[a] or 99
        local pb = PRIORITY[b] or 99
        if pa ~= pb then return pa < pb end
        return a < b
    end)
    return tools
end

local function rebuildHotbar()
    -- Clear existing slots
    for _, s in ipairs(slots) do
        if s.frame and s.frame.Parent then s.frame:Destroy() end
    end
    slots = {}

    local tools = getTools()
    for i, name in ipairs(tools) do
        local slot = makeSlot(i, name)
        table.insert(slots, slot)
    end

    -- Resize container
    local count = #slots
    local totalW = count * SLOT_W + math.max(0, count - 1) * SLOT_PAD
    container.Size = UDim2.new(0, totalW, 0, SLOT_H)
end

-- ── Highlight active tool ─────────────────────────────────────────────────────

local function updateHighlight()
    local equipped = getEquippedTool()
    local equippedName = equipped and equipped.Name or nil
    for _, slot in ipairs(slots) do
        local active = slot.toolName == equippedName
        slot.frame.BackgroundColor3 = active and ACTIVE_BG or BG
        slot.stroke.Color           = active and ACTIVE_BDR or BORDER
        local hotkey = slot.frame:FindFirstChild("Hotkey")
        if hotkey then hotkey.TextColor3 = active and TEXT_COL or DIM_COL end
        local nameLabel = slot.frame:FindFirstChild("Name")
        if nameLabel then nameLabel.TextColor3 = active and TEXT_COL or DIM_COL end
    end
end

-- ── Keyboard shortcuts (1-9) ──────────────────────────────────────────────────

local keyMap = {
    [Enum.KeyCode.One]   = 1, [Enum.KeyCode.Two]   = 2, [Enum.KeyCode.Three] = 3,
    [Enum.KeyCode.Four]  = 4, [Enum.KeyCode.Five]  = 5, [Enum.KeyCode.Six]   = 6,
    [Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8, [Enum.KeyCode.Nine]  = 9,
}

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    local idx = keyMap[input.KeyCode]
    if idx and slots[idx] then
        equipTool(slots[idx].toolName)
    end
end)

-- ── Watch for backpack / character changes ────────────────────────────────────

backpack.ChildAdded:Connect(rebuildHotbar)
backpack.ChildRemoved:Connect(rebuildHotbar)

local function wireCharacter(char)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then rebuildHotbar(); updateHighlight() end
    end)
    char.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then rebuildHotbar(); updateHighlight() end
    end)
end

player.CharacterAdded:Connect(function(char)
    task.wait(0.1)
    rebuildHotbar()
    wireCharacter(char)
end)

-- Wire the already-loaded character (script starts after first spawn)
if player.Character then wireCharacter(player.Character) end

-- Poll highlight (cheap, runs every 0.1s)
task.spawn(function()
    while true do
        updateHighlight()
        task.wait(0.1)
    end
end)

rebuildHotbar()
print("[Hotbar] Active")
