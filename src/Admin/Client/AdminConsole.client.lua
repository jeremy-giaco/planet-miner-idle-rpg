-- Admin/Client/AdminConsole.client.lua
-- Live-tuning panel. Toggle with F8 or backtick.
-- +/- apply immediately. Hold to auto-repeat with acceleration.
-- ↺ Reset  → restores every value to Config.lua defaults this session.
-- 💾 Save  → persists current live values to DataStore (survives restarts).
if not game:GetService("RunService"):IsClient() then return end

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local Config      = require(ReplicatedStorage:WaitForChild("Config"))
local remotes     = ReplicatedStorage:WaitForChild("Remotes")
local adminCmd    = remotes:WaitForChild("AdminCommand")
local configUpdate= remotes:WaitForChild("ConfigUpdated")
local player      = Players.LocalPlayer

-- ── Live config mirror ────────────────────────────────────────────────────────

local LiveConfig = {}
for k, v in pairs(Config) do
    if type(v) == "number" then LiveConfig[k] = v end
end
for _, mat in ipairs(Config.MATERIALS) do
    LiveConfig["MAT_WEIGHT_" .. mat.name] = mat.weight
end
_G.LiveConfig = LiveConfig

configUpdate.OnClientEvent:Connect(function(key, value)
    LiveConfig[key] = value
end)

-- ── Section / row definitions ─────────────────────────────────────────────────

local matWeightRows = {}
for _, mat in ipairs(Config.MATERIALS) do
    table.insert(matWeightRows, {
        label = mat.name .. " (" .. mat.rarity .. ")",
        key   = "MAT_WEIGHT_" .. mat.name,
        step  = 1,
        color = mat.color,
        desc  = mat.description .. "\nRelative spawn weight — higher = drops more often vs other materials.",
    })
end

local SECTIONS = {
    { title = "MOVEMENT", rows = {
        { label = "Walk Speed",      key = "WALK_SPEED",    step = 1,  desc = "Slow walk speed (studs/s). Default mode when toggle is off. R key switches walk/run." },
        { label = "Run Speed",       key = "RUN_SPEED",     step = 2,  desc = "Base run speed (studs/s). Tachyite stacks add on top of this when running." },
        { label = "Jump Power",      key = "JUMP_POWER",    step = 5,  desc = "Jump force applied to the character. Default Roblox is 50." },
        { label = "Gravity",         key = "GRAVITY",       step = 10, desc = "Workspace gravity (studs/s²). Default Roblox is 196.2. Lower = floatier, moon-like movement." },
    }},
    { title = "JETPACK", rows = {
        { label = "Up Thrust",       key = "JETPACK_THRUST",           step = 20,  desc = "Upward force applied while Space is held. Higher = faster vertical ascent." },
        { label = "Fwd Thrust",      key = "JETPACK_FORWARD_THRUST",   step = 20,  desc = "Horizontal thrust when flying forward. Higher = faster lateral movement." },
        { label = "Max Up Speed",    key = "JETPACK_MAX_UP_SPEED",     step = 5,   desc = "Terminal vertical velocity cap (studs/s). Prevents infinite upward acceleration." },
        { label = "Max Fwd Speed",   key = "JETPACK_MAX_HORIZ_SPEED",  step = 5,   desc = "Terminal horizontal velocity cap (studs/s). Prevents infinite forward acceleration." },
        { label = "Activation Delay",key = "JETPACK_ACTIVATION_DELAY", step = 0.1, desc = "Seconds Space must be held before jetpack fires. Prevents accidental activation." },
    }},
    { title = "LASER", rows = {
        { label = "Damage",          key = "LASER_DAMAGE",   step = 10,   desc = "Damage dealt to debris per laser shot." },
        { label = "Range (studs)",   key = "LASER_RANGE",    step = 100,  desc = "Maximum raycast distance of the laser beam (studs)." },
        { label = "Cooldown (s)",    key = "LASER_COOLDOWN", step = 0.05, desc = "Minimum seconds between laser shots. Lower = faster fire rate." },
    }},
    { title = "SHIELD", rows = {
        { label = "Radius (studs)",  key = "SHIELD_RADIUS",        step = 1,  desc = "Size of the energy bubble (studs). Debris within this radius gets destroyed." },
        { label = "Energy Max",      key = "SHIELD_ENERGY_MAX",    step = 10, desc = "Total shield energy capacity. More = shield lasts longer before depleting." },
        { label = "Drain / Hit",     key = "SHIELD_ENERGY_DRAIN",  step = 1,  desc = "Energy lost each time the shield destroys a debris chunk. Lower = longer lasting." },
        { label = "Recharge /s",     key = "SHIELD_RECHARGE_RATE", step = 5,  desc = "Energy restored per second while the shield tool is unequipped." },
        { label = "Damage / Hit",    key = "SHIELD_DAMAGE",        step = 10, desc = "Damage dealt to a debris chunk per shield hit. Independent from laser damage." },
    }},
    { title = "TACHYITE", rows = {
        { label = "Drop Chance",     key = "TACHYITE_DROP_CHANCE",  step = 0.01, desc = "Probability (0–1) that a blue speed orb drops on each debris death. 0.08 = 8% chance." },
        { label = "Speed Bonus",     key = "TACHYITE_SPEED_BONUS",  step = 5,    desc = "Run speed added per Tachyite stack. Stacks accumulate until the timer expires." },
        { label = "Duration (s)",    key = "TACHYITE_DURATION",     step = 10,   desc = "Seconds before all Tachyite stacks expire. Resets to full on every new pickup." },
    }},
    { title = "DEBRIS", rows = {
        { label = "Wave Interval",   key = "DEBRIS_SPAWN_INTERVAL",    step = 0.5,  desc = "Seconds between debris spawn waves. Lower = more frequent asteroid rain." },
        { label = "Per Wave",        key = "DEBRIS_SPAWN_PER_WAVE",    step = 1,    desc = "Number of debris chunks spawned per wave." },
        { label = "Initial Burst",   key = "DEBRIS_INITIAL_BURST",     step = 10,   desc = "Chunks spawned immediately when the server starts." },
        { label = "Speed",           key = "DEBRIS_SPEED",             step = 5,    desc = "Initial velocity (studs/s) debris travels toward the base when spawned." },
        { label = "Spawn Height",    key = "DEBRIS_SPAWN_HEIGHT",      step = 50,   desc = "Y altitude (studs) at which debris spawns before falling." },
        { label = "Health",          key = "DEBRIS_HEALTH",            step = 10,   desc = "Hit points of each debris chunk. Higher = takes more shots to destroy." },
        { label = "Lifetime (s)",    key = "DEBRIS_LIFETIME",          step = 10,   desc = "Seconds before a debris chunk auto-cleans up if not destroyed." },
        { label = "Hit Cooldown",    key = "DEBRIS_HIT_COOLDOWN",      step = 0.05, desc = "Seconds before the same chunk can take damage again. Prevents hit spam." },
        { label = "Death Pieces",    key = "DEBRIS_DEATH_PIECES",      step = 1,    desc = "Total shards/collectibles spawned when a chunk is destroyed." },
        { label = "Cargo Chance",    key = "DEBRIS_CARGO_CHANCE",      step = 0.05, desc = "Fraction of death shards that become collectible materials (0–1)." },
        { label = "Collect Radius",  key = "DEBRIS_COLLECT_RADIUS",    step = 5,    desc = "Radius (studs) around the player that auto-collects nearby debris drops." },
    }},
    { title = "COLLECTION", rows = {
        { label = "Magnet Radius",   key = "ORE_MAGNET_RADIUS",        step = 2,    desc = "Distance (studs) at which ore starts flying toward the player automatically." },
        { label = "Collect Dist",    key = "ORE_COLLECT_RADIUS",       step = 1,    desc = "Distance (studs) at which ore is actually collected. Must be less than Magnet Radius." },
        { label = "Collectible Life",key = "COLLECTIBLE_LIFETIME",     step = 10,   desc = "Seconds before an uncollected material orb despawns." },
        { label = "Rotation Speed",  key = "COLLECTIBLE_ROTATION_SPEED",step = 0.1, desc = "Spin speed (rad/s) of collectible material orbs." },
    }},
    { title = "ORE SPAWNING", rows = {
        { label = "Spawn Interval",  key = "ORE_SPAWN_INTERVAL", step = 1, desc = "Seconds between ore node spawn ticks. Lower = ore appears more frequently." },
        { label = "Max Ore Count",   key = "ORE_MAX_COUNT",      step = 5, desc = "Maximum ore nodes alive at once. New spawns are skipped when this cap is reached." },
    }},
    { title = "DRONES", rows = {
        { label = "Speed",           key = "DRONE_SPEED",            step = 5,  desc = "Drone flight speed (studs/s)." },
        { label = "Cargo Capacity",  key = "DRONE_CARGO_CAPACITY",   step = 5,  desc = "Max materials a drone can carry before returning to base." },
        { label = "Gun Range",       key = "DRONE_GUN_RANGE",        step = 10, desc = "Distance (studs) at which the drone's gun can engage debris." },
        { label = "Gun Cooldown",    key = "DRONE_GUN_COOLDOWN",     step = 0.5,desc = "Seconds between drone gun shots." },
        { label = "Gun Damage",      key = "DRONE_GUN_DAMAGE",       step = 5,  desc = "Damage per drone gun shot." },
        { label = "Guard Radius",    key = "DRONE_GUARD_RADIUS",     step = 2,  desc = "Radius (studs) drones orbit around the player when in guard mode." },
        { label = "Guard Height",    key = "DRONE_GUARD_HEIGHT",     step = 2,  desc = "Height (studs) above player drones hover in guard mode." },
        { label = "Max Health",      key = "DRONE_MAX_HEALTH",       step = 10, desc = "Maximum drone hit points before it needs repair." },
        { label = "Debris Damage",   key = "DRONE_DEBRIS_DAMAGE",    step = 5,  desc = "Damage dealt to a drone each time it collides with debris." },
        { label = "Repair Threshold",key = "DRONE_REPAIR_THRESHOLD", step = 5,  desc = "Health level at which a drone automatically returns to the repair station." },
        { label = "Repair Rate",     key = "DRONE_REPAIR_RATE",      step = 1,  desc = "Health points restored per second while docked at the repair station." },
        { label = "Rover Hover Ht",  key = "ROVER_HOVER_HEIGHT",     step = 1,  desc = "Height (studs) the rover-mode drone hovers above the ground." },
    }},
    { title = "MATERIAL WEIGHTS", rows = matWeightRows },
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
    orange  = Color3.fromRGB(255, 140,  40),
}

-- ── Build UI ──────────────────────────────────────────────────────────────────

local pg = player:WaitForChild("PlayerGui")

local sg = Instance.new("ScreenGui")
sg.Name           = "AdminConsole"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset = true
sg.Enabled        = false
sg.Parent         = pg

local PANEL_W  = 360   -- slightly wider to fit info icon
local TITLE_H  = 36
local STATUS_H = 24
local PAD      = 8

-- Outer frame — full height minus top/bottom margin to clear Roblox UI chrome
local TOP_MARGIN    = 48   -- clears the Roblox top bar
local BOTTOM_MARGIN = 52   -- clears the hotbar / bottom buttons
local frame = Instance.new("Frame")
frame.Name             = "Panel"
frame.Size             = UDim2.new(0, PANEL_W, 1, -(TOP_MARGIN + BOTTOM_MARGIN))
frame.Position         = UDim2.new(0, 20, 0, TOP_MARGIN)
frame.BackgroundColor3 = C.bg
frame.BorderSizePixel  = 0
frame.ClipsDescendants = true
frame.Parent           = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
local uiStroke = Instance.new("UIStroke", frame)
uiStroke.Color = C.neon; uiStroke.Thickness = 1; uiStroke.Transparency = 0.6

-- ── Title bar ─────────────────────────────────────────────────────────────────

local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, TITLE_H)
titleBar.BackgroundColor3 = C.header
titleBar.BorderSizePixel  = 0
titleBar.Parent           = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size               = UDim2.new(1, -200, 1, 0)
titleLabel.Position           = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text               = "⚙  ADMIN   [F8/`]"
titleLabel.Font               = Enum.Font.GothamMedium
titleLabel.TextSize           = 12
titleLabel.TextColor3         = C.neon
titleLabel.TextXAlignment     = Enum.TextXAlignment.Left
titleLabel.Parent             = titleBar

local function makeTitleBtn(text, xOffset, bgColor, txtColor)
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0, 82, 0, 24)
    btn.Position         = UDim2.new(1, xOffset, 0.5, -12)
    btn.BackgroundColor3 = bgColor
    btn.BorderSizePixel  = 0
    btn.Text             = text
    btn.Font             = Enum.Font.GothamMedium
    btn.TextSize         = 10
    btn.TextColor3       = txtColor
    btn.Parent           = titleBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    return btn
end

local btnReset = makeTitleBtn("↺  RESET",    -174, C.header, C.orange)
local btnSave  = makeTitleBtn("💾  SAVE DEF", -86,  C.green,  C.bg)

-- UIStroke on reset button so it's visible against header
local resetStroke = Instance.new("UIStroke", btnReset)
resetStroke.Color = C.orange; resetStroke.Thickness = 1.2

-- ── Status bar ────────────────────────────────────────────────────────────────

local statusLabel = Instance.new("TextLabel")
statusLabel.Name               = "Status"
statusLabel.Size               = UDim2.new(1, -12, 0, STATUS_H)
statusLabel.Position           = UDim2.new(0, 8, 1, -STATUS_H - 2)
statusLabel.BackgroundTransparency = 1
statusLabel.Text               = ""
statusLabel.Font               = Enum.Font.Gotham
statusLabel.TextSize           = 11
statusLabel.TextColor3         = C.green
statusLabel.TextXAlignment     = Enum.TextXAlignment.Left
statusLabel.ZIndex             = 10
statusLabel.Parent             = frame

local function setStatus(msg, color, duration)
    statusLabel.Text       = msg
    statusLabel.TextColor3 = color or C.green
    if duration then
        task.delay(duration, function()
            if statusLabel.Text == msg then statusLabel.Text = "" end
        end)
    end
end

-- ── Scroll area ───────────────────────────────────────────────────────────────

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size                = UDim2.new(1, 0, 1, -(TITLE_H + STATUS_H + 4))
scrollFrame.Position            = UDim2.new(0, 0, 0, TITLE_H)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel     = 0
scrollFrame.ScrollBarThickness  = 4
scrollFrame.ScrollBarImageColor3= C.neon
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.CanvasSize          = UDim2.new(0, 0, 0, 0)
scrollFrame.ElasticBehavior     = Enum.ElasticBehavior.Never
scrollFrame.Parent              = frame

-- ── Tooltip ───────────────────────────────────────────────────────────────────
-- Floats above the panel (high ZIndex), repositioned on each hover.

local tooltip = Instance.new("Frame")
tooltip.Name               = "Tooltip"
tooltip.Size               = UDim2.new(0, 220, 0, 60)   -- height auto-adjusts via SizeConstraint
tooltip.BackgroundColor3   = Color3.fromRGB(12, 16, 32)
tooltip.BackgroundTransparency = 0.08
tooltip.BorderSizePixel    = 0
tooltip.Visible            = false
tooltip.ZIndex             = 50
tooltip.Parent             = sg
Instance.new("UICorner", tooltip).CornerRadius = UDim.new(0, 6)
local ttStroke = Instance.new("UIStroke", tooltip)
ttStroke.Color = C.neon; ttStroke.Thickness = 1; ttStroke.Transparency = 0.5

local ttLabel = Instance.new("TextLabel", tooltip)
ttLabel.Size               = UDim2.new(1, -14, 1, -10)
ttLabel.Position           = UDim2.new(0, 7, 0, 5)
ttLabel.BackgroundTransparency = 1
ttLabel.Text               = ""
ttLabel.Font               = Enum.Font.Gotham
ttLabel.TextSize           = 11
ttLabel.TextColor3         = Color3.fromRGB(190, 200, 225)
ttLabel.TextXAlignment     = Enum.TextXAlignment.Left
ttLabel.TextYAlignment     = Enum.TextYAlignment.Top
ttLabel.TextWrapped        = true
ttLabel.ZIndex             = 51

-- Auto-size the tooltip height to fit wrapped text
local ttSizeConst = Instance.new("UISizeConstraint", tooltip)
ttSizeConst.MinSize = Vector2.new(220, 30)

local function showTooltip(desc, iconAbsPos)
    ttLabel.Text    = desc
    -- Measure approximate height needed (rough: ~14px per line, ~28 chars/line at 220px width)
    local charsPerLine = 32
    local lines = 0
    for seg in (desc .. "\n"):gmatch("([^\n]*)\n") do
        lines += math.max(1, math.ceil(#seg / charsPerLine))
    end
    local ttH = math.max(36, lines * 15 + 12)
    tooltip.Size = UDim2.new(0, 220, 0, ttH)

    -- Position: to the right of the panel, aligned to the icon row
    local px = frame.AbsolutePosition.X + PANEL_W + 8
    local py = iconAbsPos.Y - 4
    -- Clamp so it doesn't go off the bottom of the screen
    local screenH = sg.AbsoluteSize.Y
    py = math.min(py, screenH - ttH - 8)
    tooltip.Position = UDim2.new(0, px, 0, py)
    tooltip.Visible  = true
end

local function hideTooltip()
    tooltip.Visible = false
end

-- ── Row builder ───────────────────────────────────────────────────────────────

local ROW_H     = 28
local SEC_HDR_H = 22
local valueLabels = {}   -- key → TextLabel showing current value

local function sendValue(key, num)
    task.spawn(function()
        local ok, msg = adminCmd:InvokeServer(key, num)
        if ok then
            setStatus("✓  " .. msg, C.green, 2)
            if valueLabels[key] then
                valueLabels[key].Text = tostring(LiveConfig[key] or num)
            end
        else
            setStatus("✗  " .. (msg or "error"), C.red, 3)
        end
    end)
end

-- Hold-to-repeat with acceleration
-- Phase 1: 0.35s initial delay before first repeat
-- Phase 2: repeats at step×1 for 1s, then step×4, then step×16 (caps there)
local function attachHold(btn, key, stepSign, getStep)
    local holding     = false
    local holdConn

    local function startHold()
        holding = true
        -- initial delay before auto-repeat
        task.delay(0.35, function()
            if not holding then return end
            local multiplier = 1
            local elapsed    = 0
            holdConn = RunService.Heartbeat:Connect(function(dt)
                if not holding then
                    holdConn:Disconnect(); holdConn = nil; return
                end
                elapsed += dt
                -- accelerate: 4× after 1s, 16× after 2.5s
                if elapsed > 2.5 then
                    multiplier = 16
                elseif elapsed > 1.0 then
                    multiplier = 4
                else
                    multiplier = 1
                end
                local step = getStep() * multiplier
                -- fire roughly 10 times/sec
                if elapsed % 0.1 < dt then
                    local cur = LiveConfig[key] or 0
                    local nv  = cur + step * stepSign
                    sendValue(key, nv)
                end
            end)
        end)
    end

    local function stopHold()
        holding = false
        if holdConn then holdConn:Disconnect(); holdConn = nil end
    end

    btn.MouseButton1Down:Connect(startHold)
    btn.MouseButton1Up:Connect(stopHold)
    btn.MouseLeave:Connect(stopHold)

    -- single click (fires on Up before hold kicks in if released quickly)
    btn.MouseButton1Click:Connect(function()
        local cur = LiveConfig[key] or 0
        local nv  = cur + getStep() * stepSign
        sendValue(key, nv)
    end)
end

local curY = 4

for _, sec in ipairs(SECTIONS) do
    -- Section header
    local hdr = Instance.new("Frame")
    hdr.Size             = UDim2.new(1, -PAD*2, 0, SEC_HDR_H)
    hdr.Position         = UDim2.new(0, PAD, 0, curY + 4)
    hdr.BackgroundColor3 = C.section
    hdr.BorderSizePixel  = 0
    hdr.Parent           = scrollFrame
    Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 4)
    local hl = Instance.new("TextLabel", hdr)
    hl.Size = UDim2.new(1,-8,1,0); hl.Position = UDim2.new(0,8,0,0)
    hl.BackgroundTransparency = 1; hl.Text = sec.title
    hl.Font = Enum.Font.GothamBold; hl.TextSize = 11
    hl.TextColor3 = C.gold; hl.TextXAlignment = Enum.TextXAlignment.Left
    curY = curY + SEC_HDR_H + 6

    for _, row in ipairs(sec.rows) do
        local key = row.key

        -- Label
        local lbl = Instance.new("TextLabel", scrollFrame)
        lbl.Size               = UDim2.new(0, 138, 0, ROW_H)
        lbl.Position           = UDim2.new(0, PAD + 4, 0, curY)
        lbl.BackgroundTransparency = 1
        lbl.Text               = row.label
        lbl.Font               = Enum.Font.Gotham
        lbl.TextSize           = 11
        lbl.TextColor3         = row.color or C.text
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        lbl.TextYAlignment     = Enum.TextYAlignment.Center

        -- − button
        local btnM = Instance.new("TextButton", scrollFrame)
        btnM.Size             = UDim2.new(0, 28, 0, 22)
        btnM.Position         = UDim2.new(0, 150, 0, curY + 3)
        btnM.BackgroundColor3 = C.header
        btnM.BorderSizePixel  = 0
        btnM.Text             = "−"
        btnM.Font             = Enum.Font.GothamMedium
        btnM.TextSize         = 16
        btnM.TextColor3       = C.red
        Instance.new("UICorner", btnM).CornerRadius = UDim.new(0, 4)
        local ms = Instance.new("UIStroke", btnM)
        ms.Color = C.red; ms.Thickness = 1; ms.Transparency = 0.6

        -- Value display
        local valLbl = Instance.new("TextLabel", scrollFrame)
        valLbl.Size               = UDim2.new(0, 80, 0, 22)
        valLbl.Position           = UDim2.new(0, 182, 0, curY + 3)
        valLbl.BackgroundColor3   = C.panel
        valLbl.BackgroundTransparency = 0
        valLbl.BorderSizePixel    = 0
        valLbl.Text               = tostring(LiveConfig[key] or Config[key] or 0)
        valLbl.Font               = Enum.Font.Gotham
        valLbl.TextSize           = 12
        valLbl.TextColor3         = C.neon
        valLbl.TextXAlignment     = Enum.TextXAlignment.Center
        Instance.new("UICorner", valLbl).CornerRadius = UDim.new(0, 4)
        Instance.new("UIStroke", valLbl).Color        = C.neon
        valueLabels[key] = valLbl

        -- + button
        local btnP = Instance.new("TextButton", scrollFrame)
        btnP.Size             = UDim2.new(0, 28, 0, 22)
        btnP.Position         = UDim2.new(0, 266, 0, curY + 3)
        btnP.BackgroundColor3 = C.header
        btnP.BorderSizePixel  = 0
        btnP.Text             = "+"
        btnP.Font             = Enum.Font.GothamMedium
        btnP.TextSize         = 16
        btnP.TextColor3       = C.green
        Instance.new("UICorner", btnP).CornerRadius = UDim.new(0, 4)
        local ps = Instance.new("UIStroke", btnP)
        ps.Color = C.green; ps.Thickness = 1; ps.Transparency = 0.6

        attachHold(btnM, key, -1, function() return row.step end)
        attachHold(btnP, key,  1, function() return row.step end)

        -- ⓘ info icon (only if row has a description)
        if row.desc then
            local info = Instance.new("TextButton", scrollFrame)
            info.Size             = UDim2.new(0, 16, 0, 16)
            info.Position         = UDim2.new(0, 298, 0, curY + 6)
            info.BackgroundColor3 = C.header
            info.BorderSizePixel  = 0
            info.Text             = "i"
            info.Font             = Enum.Font.GothamMedium
            info.TextSize         = 10
            info.TextColor3       = C.dim
            info.AutoButtonColor  = false
            Instance.new("UICorner", info).CornerRadius = UDim.new(1, 0)
            local iStroke = Instance.new("UIStroke", info)
            iStroke.Color = C.dim; iStroke.Thickness = 1; iStroke.Transparency = 0.4

            local desc = row.desc
            info.MouseEnter:Connect(function()
                iStroke.Color  = C.neon
                info.TextColor3= C.neon
                showTooltip(desc, info.AbsolutePosition)
            end)
            info.MouseLeave:Connect(function()
                iStroke.Color  = C.dim
                info.TextColor3= C.dim
                hideTooltip()
            end)
            -- prevent click from doing anything
            info.MouseButton1Click:Connect(function() end)
        end

        curY = curY + ROW_H
    end

    curY = curY + 8
end

-- ── Keep value labels in sync ─────────────────────────────────────────────────

configUpdate.OnClientEvent:Connect(function(key, value)
    LiveConfig[key] = value
    if valueLabels[key] then
        valueLabels[key].Text = tostring(value)
    end
end)

-- ── Reset to Config defaults ──────────────────────────────────────────────────

btnReset.MouseButton1Click:Connect(function()
    setStatus("Resetting…", C.orange)
    task.spawn(function()
        local ok, msg = adminCmd:InvokeServer("RESET_DEFAULTS", 0)
        if ok then
            setStatus("✓  Reset to Config defaults", C.orange, 3)
        else
            setStatus("✗  " .. (msg or "error"), C.red, 3)
        end
    end)
end)

-- ── Save as defaults ──────────────────────────────────────────────────────────

btnSave.MouseButton1Click:Connect(function()
    setStatus("Saving…", C.dim)
    task.spawn(function()
        local ok, msg = adminCmd:InvokeServer("SAVE_DEFAULTS", 0)
        if ok then
            setStatus("✓  Saved as defaults", C.green, 3)
        else
            setStatus("✗  " .. (msg or "error"), C.red, 3)
        end
    end)
end)

-- ── Drag ─────────────────────────────────────────────────────────────────────

local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = frame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local d = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                    startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- ── Toggle ────────────────────────────────────────────────────────────────────

local function refreshValues()
    for key, lbl in pairs(valueLabels) do
        lbl.Text = tostring(LiveConfig[key] or Config[key] or "")
    end
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F8
    or input.KeyCode == Enum.KeyCode.Backquote then
        sg.Enabled = not sg.Enabled
        if sg.Enabled then refreshValues() end
    end
end)
