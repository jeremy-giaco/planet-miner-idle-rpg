-- Admin/Client/AdminConsole.client.lua
-- Minimal live-tuning panel. Toggle with F9 (or backtick `).
-- Only visible if the server grants admin.
if not game:GetService("RunService"):IsClient() then return end

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")

local Config  = require(ReplicatedStorage:WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local adminCmd     = remotes:WaitForChild("AdminCommand")
local configUpdate = remotes:WaitForChild("ConfigUpdated")

local player = Players.LocalPlayer

-- ── Live config mirror (client side) ─────────────────────────────────────────
-- Jetpack reads this table each frame once we hook it up.

local LiveConfig = {}
for k, v in pairs(Config) do
    if type(v) == "number" then LiveConfig[k] = v end
end
-- Seed material weight keys
for _, mat in ipairs(Config.MATERIALS) do
    LiveConfig["MAT_WEIGHT_" .. mat.name] = mat.weight
end
_G.LiveConfig = LiveConfig   -- Jetpack.client.lua reads _G.LiveConfig if present

configUpdate.OnClientEvent:Connect(function(key, value)
    LiveConfig[key] = value
end)

-- ── Layout data ───────────────────────────────────────────────────────────────

-- Build material weight rows dynamically from Config
local matWeightRows = {}
for _, mat in ipairs(Config.MATERIALS) do
    table.insert(matWeightRows, {
        label = mat.name .. " (" .. mat.rarity .. ")",
        key   = "MAT_WEIGHT_" .. mat.name,
        step  = 1,
        color = mat.color,   -- tint the label to the material colour
    })
end

local SECTIONS = {
    {
        title = "MOVEMENT",
        rows  = {
            { label = "Walk Speed",    key = "WALK_SPEED",    step = 1  },
            { label = "Run Speed",     key = "RUN_SPEED",     step = 2  },
            { label = "Gravity",       key = "GRAVITY",       step = 10 },
        },
    },
    {
        title = "JETPACK",
        rows  = {
            { label = "Up Thrust",     key = "JETPACK_THRUST",          step = 20 },
            { label = "Fwd Thrust",    key = "JETPACK_FORWARD_THRUST",  step = 20 },
            { label = "Max Up Speed",  key = "JETPACK_MAX_UP_SPEED",    step = 5  },
            { label = "Max Fwd Speed", key = "JETPACK_MAX_HORIZ_SPEED", step = 5  },
        },
    },
    {
        title = "COLLECTION",
        rows  = {
            { label = "Magnet Radius", key = "ORE_MAGNET_RADIUS",  step = 2 },
            { label = "Collect Dist",  key = "ORE_COLLECT_RADIUS", step = 1 },
        },
    },
    {
        title = "ORE SPAWNING",
        rows  = {
            { label = "Spawn Interval", key = "ORE_SPAWN_INTERVAL", step = 1  },
            { label = "Max Ore Count",  key = "ORE_MAX_COUNT",       step = 5  },
        },
    },
    {
        title = "DEBRIS",
        rows  = {
            { label = "Wave Interval",  key = "DEBRIS_SPAWN_INTERVAL", step = 1    },
            { label = "Per Wave",       key = "DEBRIS_SPAWN_PER_WAVE", step = 1    },
            { label = "Drop Chance",    key = "DEBRIS_CARGO_CHANCE",   step = 0.05 },
        },
    },
    {
        title = "MATERIAL WEIGHTS",
        rows  = matWeightRows,
    },
}

-- ── Colours ───────────────────────────────────────────────────────────────────

local C = {
    bg      = Color3.fromRGB(16,  18,  28),
    panel   = Color3.fromRGB(22,  26,  42),
    header  = Color3.fromRGB(30,  36,  58),
    section = Color3.fromRGB(40,  46,  72),
    neon    = Color3.fromRGB(80, 160, 255),
    text    = Color3.fromRGB(210, 215, 235),
    dim     = Color3.fromRGB(120, 130, 160),
    green   = Color3.fromRGB( 60, 210, 120),
    red     = Color3.fromRGB(220,  60,  60),
    gold    = Color3.fromRGB(255, 200,  60),
}

-- ── Build UI ──────────────────────────────────────────────────────────────────

local pg = player:WaitForChild("PlayerGui")

local sg = Instance.new("ScreenGui")
sg.Name            = "AdminConsole"
sg.ResetOnSpawn    = false
sg.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset  = true
sg.Enabled         = false
sg.Parent          = pg

local PANEL_W      = 340
local TITLE_H      = 32
local STATUS_H     = 26
local MAX_PANEL_H  = 560   -- max visible height before scrolling kicks in

-- Outer draggable frame (fixed height, clipped)
local frame = Instance.new("Frame")
frame.Name              = "Panel"
frame.Size              = UDim2.new(0, PANEL_W, 0, MAX_PANEL_H)
frame.Position          = UDim2.new(0, 20, 0, 60)
frame.BackgroundColor3  = C.bg
frame.BorderSizePixel   = 0
frame.ClipsDescendants  = true
frame.Parent            = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local uiStroke = Instance.new("UIStroke", frame)
uiStroke.Color = C.neon; uiStroke.Thickness = 1; uiStroke.Transparency = 0.6

-- Title bar (sits above scroll area, always visible)
local titleBar = Instance.new("Frame")
titleBar.Size              = UDim2.new(1, 0, 0, TITLE_H)
titleBar.BackgroundColor3  = C.header
titleBar.BorderSizePixel   = 0
titleBar.Parent            = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size                   = UDim2.new(1, -12, 1, 0)
titleLabel.Position               = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text                   = "⚙  ADMIN CONSOLE   [F8 / `]"
titleLabel.Font                   = Enum.Font.GothamBold
titleLabel.TextSize               = 13
titleLabel.TextColor3             = C.neon
titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
titleLabel.Parent                 = titleBar

-- Status bar pinned at bottom of outer frame
local statusLabel = Instance.new("TextLabel")
statusLabel.Name                   = "Status"
statusLabel.Size                   = UDim2.new(1, -12, 0, STATUS_H)
statusLabel.Position               = UDim2.new(0, 8, 1, -STATUS_H - 2)
statusLabel.BackgroundTransparency = 1
statusLabel.Text                   = ""
statusLabel.Font                   = Enum.Font.Gotham
statusLabel.TextSize               = 11
statusLabel.TextColor3             = C.green
statusLabel.TextXAlignment         = Enum.TextXAlignment.Left
statusLabel.ZIndex                 = 10
statusLabel.Parent                 = frame

-- ScrollingFrame fills the space between title bar and status bar
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name                   = "Scroll"
scrollFrame.Size                   = UDim2.new(1, 0, 1, -(TITLE_H + STATUS_H + 4))
scrollFrame.Position               = UDim2.new(0, 0, 0, TITLE_H)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel        = 0
scrollFrame.ScrollBarThickness     = 4
scrollFrame.ScrollBarImageColor3   = C.neon
scrollFrame.CanvasSize             = UDim2.new(0, 0, 0, 0)  -- updated after rows built
scrollFrame.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scrollFrame.ElasticBehavior        = Enum.ElasticBehavior.Never
scrollFrame.Parent                 = frame

-- ── Row builder ───────────────────────────────────────────────────────────────

local ROW_H      = 30
local SEC_HDR_H  = 22
local PAD        = 8

local inputs = {}   -- key → TextBox ref

local function makeLabel(parent, text, size, pos, color, font, align)
    local l = Instance.new("TextLabel")
    l.Size                   = size
    l.Position               = pos
    l.BackgroundTransparency = 1
    l.Text                   = text
    l.Font                   = font or Enum.Font.Gotham
    l.TextSize               = 12
    l.TextColor3             = color or C.text
    l.TextXAlignment         = align or Enum.TextXAlignment.Left
    l.Parent                 = parent
    return l
end

local function sendValue(key, rawText)
    local num = tonumber(rawText)
    if not num then
        statusLabel.Text       = "✗  not a number"
        statusLabel.TextColor3 = C.red
        return
    end
    statusLabel.Text       = "..."
    statusLabel.TextColor3 = C.dim

    task.spawn(function()
        local ok, msg = adminCmd:InvokeServer(key, num)
        if ok then
            statusLabel.Text       = "✓  " .. msg
            statusLabel.TextColor3 = C.green
            -- refresh the box to show clamped value
            if inputs[key] then
                inputs[key].Text = tostring(LiveConfig[key] or num)
            end
        else
            statusLabel.Text       = "✗  " .. (msg or "error")
            statusLabel.TextColor3 = C.red
        end
    end)
end

local curY = 4   -- padding inside scroll frame

for _, sec in ipairs(SECTIONS) do
    -- Section header
    local hdr = Instance.new("Frame")
    hdr.Size             = UDim2.new(1, -PAD*2, 0, SEC_HDR_H)
    hdr.Position         = UDim2.new(0, PAD, 0, curY + 4)
    hdr.BackgroundColor3 = C.section
    hdr.BorderSizePixel  = 0
    hdr.Parent           = scrollFrame
    Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 4)
    makeLabel(hdr, sec.title, UDim2.new(1,-8,1,0), UDim2.new(0,8,0,0),
        C.gold, Enum.Font.GothamBold)
    curY = curY + SEC_HDR_H + 8

    for _, row in ipairs(sec.rows) do
        local currentVal = LiveConfig[row.key] or Config[row.key] or 0

        -- Row label (material weight rows use the material's colour)
        makeLabel(scrollFrame, row.label,
            UDim2.new(0, 130, 0, ROW_H),
            UDim2.new(0, PAD + 4, 0, curY),
            row.color or C.text)

        -- Text input
        local box = Instance.new("TextBox")
        box.Size                  = UDim2.new(0, 90, 0, 22)
        box.Position              = UDim2.new(0, 148, 0, curY + 4)
        box.BackgroundColor3      = C.panel
        box.BorderSizePixel       = 0
        box.Text                  = tostring(currentVal)
        box.Font                  = Enum.Font.GothamBold
        box.TextSize              = 13
        box.TextColor3            = C.neon
        box.ClearTextOnFocus      = false
        box.PlaceholderText       = "value"
        box.Parent                = scrollFrame
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
        Instance.new("UIStroke", box).Color        = C.neon

        inputs[row.key] = box

        -- Send on Enter / focus-lost
        local key = row.key
        box.FocusLost:Connect(function(enterPressed)
            if enterPressed then sendValue(key, box.Text) end
        end)

        -- − button
        local btnMinus = Instance.new("TextButton")
        btnMinus.Size              = UDim2.new(0, 22, 0, 22)
        btnMinus.Position          = UDim2.new(0, 244, 0, curY + 4)
        btnMinus.BackgroundColor3  = C.header
        btnMinus.BorderSizePixel   = 0
        btnMinus.Text              = "−"
        btnMinus.Font              = Enum.Font.GothamBold
        btnMinus.TextSize          = 14
        btnMinus.TextColor3        = C.dim
        btnMinus.Parent            = scrollFrame
        Instance.new("UICorner", btnMinus).CornerRadius = UDim.new(0, 4)
        btnMinus.MouseButton1Click:Connect(function()
            local v = tonumber(box.Text) or (LiveConfig[key] or 0)
            box.Text = tostring(v - row.step)
            sendValue(key, box.Text)
        end)

        -- + button
        local btnPlus = Instance.new("TextButton")
        btnPlus.Size              = UDim2.new(0, 22, 0, 22)
        btnPlus.Position          = UDim2.new(0, 270, 0, curY + 4)
        btnPlus.BackgroundColor3  = C.header
        btnPlus.BorderSizePixel   = 0
        btnPlus.Text              = "+"
        btnPlus.Font              = Enum.Font.GothamBold
        btnPlus.TextSize          = 14
        btnPlus.TextColor3        = C.neon
        btnPlus.Parent            = scrollFrame
        Instance.new("UICorner", btnPlus).CornerRadius = UDim.new(0, 4)
        btnPlus.MouseButton1Click:Connect(function()
            local v = tonumber(box.Text) or (LiveConfig[key] or 0)
            box.Text = tostring(v + row.step)
            sendValue(key, box.Text)
        end)

        -- Apply button
        local btnApply = Instance.new("TextButton")
        btnApply.Size              = UDim2.new(0, 36, 0, 22)
        btnApply.Position          = UDim2.new(0, 298, 0, curY + 4)
        btnApply.BackgroundColor3  = C.neon
        btnApply.BorderSizePixel   = 0
        btnApply.Text              = "SET"
        btnApply.Font              = Enum.Font.GothamBold
        btnApply.TextSize          = 11
        btnApply.TextColor3        = C.bg
        btnApply.Parent            = scrollFrame
        Instance.new("UICorner", btnApply).CornerRadius = UDim.new(0, 4)
        btnApply.MouseButton1Click:Connect(function()
            sendValue(key, box.Text)
        end)

        curY = curY + ROW_H
    end

    curY = curY + 6   -- gap after section
end


-- ── Drag behaviour ────────────────────────────────────────────────────────────

local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging  = true
        dragStart = input.Position
        startPos  = frame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- ── Toggle ────────────────────────────────────────────────────────────────────

-- Refresh boxes whenever panel opens so values are current
local function refreshBoxes()
    for key, box in pairs(inputs) do
        box.Text = tostring(LiveConfig[key] or Config[key] or "")
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F8
    or input.KeyCode == Enum.KeyCode.Backquote then
        sg.Enabled = not sg.Enabled
        if sg.Enabled then refreshBoxes() end
    end
end)

-- Keep LiveConfig in sync as server sends updates
configUpdate.OnClientEvent:Connect(function(key, value)
    if inputs[key] and not inputs[key]:IsFocused() then
        inputs[key].Text = tostring(value)
    end
end)
