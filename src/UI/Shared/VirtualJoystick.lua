-- UI/Shared/VirtualJoystick.lua
-- Twin-stick virtual joystick for mobile ship controls.
-- Usage:
--   local VJ = require(...)
--   local sticks = VJ.create(screenGui)
--   -- in update loop:
--   local lx, ly = sticks.left()     -- -1..1 movement axes
--   local rx, ry = sticks.right()    -- -1..1 camera axes
--   local fire   = sticks.fire()     -- bool
--   local rise   = sticks.rise()     -- bool
--   sticks.destroy()

local UserInputService = game:GetService("UserInputService")

local VirtualJoystick = {}

local STICK_RADIUS  = 55   -- px: outer ring radius
local KNOB_RADIUS   = 24   -- px: draggable knob radius
local BTN_SIZE      = 64   -- px: fire/rise button size
local STICK_ALPHA   = 0.35
local KNOB_ALPHA    = 0.55

local function makeCircle(parent, size, color, alpha, zIndex)
    local f = Instance.new("Frame")
    f.Size                   = UDim2.new(0, size * 2, 0, size * 2)
    f.BackgroundColor3       = color
    f.BackgroundTransparency = alpha
    f.BorderSizePixel        = 0
    f.ZIndex                 = zIndex or 5
    f.Parent                 = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
    return f
end

local function makeButton(parent, text, pos, size, color)
    local btn = Instance.new("TextButton")
    btn.Size                   = UDim2.new(0, size, 0, size)
    btn.Position               = pos
    btn.AnchorPoint            = Vector2.new(0.5, 0.5)
    btn.BackgroundColor3       = color
    btn.BackgroundTransparency = 0.4
    btn.Text                   = text
    btn.TextSize               = 18
    btn.Font                   = Enum.Font.GothamBold
    btn.TextColor3             = Color3.new(1, 1, 1)
    btn.BorderSizePixel        = 0
    btn.ZIndex                 = 6
    btn.Parent                 = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    return btn
end

function VirtualJoystick.create(gui)
    local container = Instance.new("Frame")
    container.Name                   = "JoystickContainer"
    container.Size                   = UDim2.new(1, 0, 1, 0)
    container.BackgroundTransparency = 1
    container.ZIndex                 = 5
    container.Parent                 = gui

    -- ── Left stick ────────────────────────────────────────────────────────────
    local leftBase = makeCircle(container, STICK_RADIUS,
        Color3.fromRGB(180, 180, 255), STICK_ALPHA, 5)
    leftBase.AnchorPoint = Vector2.new(0.5, 0.5)
    leftBase.Position    = UDim2.new(0, 110, 1, -110)

    local leftKnob = makeCircle(leftBase, KNOB_RADIUS,
        Color3.fromRGB(120, 120, 255), KNOB_ALPHA, 6)
    leftKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    leftKnob.Position    = UDim2.new(0.5, 0, 0.5, 0)

    -- ── Right stick ───────────────────────────────────────────────────────────
    local rightBase = makeCircle(container, STICK_RADIUS,
        Color3.fromRGB(255, 180, 180), STICK_ALPHA, 5)
    rightBase.AnchorPoint = Vector2.new(0.5, 0.5)
    rightBase.Position    = UDim2.new(1, -110, 1, -110)

    local rightKnob = makeCircle(rightBase, KNOB_RADIUS,
        Color3.fromRGB(255, 120, 120), KNOB_ALPHA, 6)
    rightKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    rightKnob.Position    = UDim2.new(0.5, 0, 0.5, 0)

    -- ── Fire button ───────────────────────────────────────────────────────────
    local fireBtn = makeButton(container, "⚡ FIRE",
        UDim2.new(1, -110, 1, -220), BTN_SIZE + 20,
        Color3.fromRGB(0, 180, 255))

    -- ── Rise button ───────────────────────────────────────────────────────────
    local riseBtn = makeButton(container, "▲",
        UDim2.new(1, -200, 1, -200), BTN_SIZE,
        Color3.fromRGB(80, 220, 80))

    -- ── Input tracking ────────────────────────────────────────────────────────
    local leftVec  = Vector2.new(0, 0)
    local rightVec = Vector2.new(0, 0)
    local fireHeld = false
    local riseHeld = false

    -- Track which touch owns which stick
    local leftTouchId  = nil
    local rightTouchId = nil

    local function getAbsCenter(frame)
        local abs = frame.AbsolutePosition
        local sz  = frame.AbsoluteSize
        return Vector2.new(abs.X + sz.X / 2, abs.Y + sz.Y / 2)
    end

    local function updateKnob(knob, offset, radius)
        local clamped = offset.Magnitude > radius
            and offset.Unit * radius or offset
        knob.Position = UDim2.new(0.5, clamped.X, 0.5, clamped.Y)
        return clamped / radius  -- normalized -1..1
    end

    local inputConn = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch then return end
        local pos   = Vector2.new(input.Position.X, input.Position.Y)
        local vp    = workspace.CurrentCamera.ViewportSize
        local half  = vp.X / 2

        if pos.X < half then
            -- Left side → left stick
            leftTouchId = input
            local center = getAbsCenter(leftBase)
            local offset = pos - center
            leftVec = updateKnob(leftKnob, offset, STICK_RADIUS)
        else
            -- Right side → right stick (unless it hit a button, handled by button)
            rightTouchId = input
            local center = getAbsCenter(rightBase)
            local offset = pos - center
            rightVec = updateKnob(rightKnob, offset, STICK_RADIUS)
        end
    end)

    local movedConn = UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch then return end
        local pos = Vector2.new(input.Position.X, input.Position.Y)

        if input == leftTouchId then
            local center = getAbsCenter(leftBase)
            leftVec = updateKnob(leftKnob, pos - center, STICK_RADIUS)
        elseif input == rightTouchId then
            local center = getAbsCenter(rightBase)
            rightVec = updateKnob(rightKnob, pos - center, STICK_RADIUS)
        end
    end)

    local endedConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch then return end
        if input == leftTouchId then
            leftTouchId = nil
            leftVec     = Vector2.new(0, 0)
            leftKnob.Position = UDim2.new(0.5, 0, 0.5, 0)
        elseif input == rightTouchId then
            rightTouchId = nil
            rightVec     = Vector2.new(0, 0)
            rightKnob.Position = UDim2.new(0.5, 0, 0.5, 0)
        end
    end)

    -- Fire / rise buttons
    fireBtn.MouseButton1Down:Connect(function() fireHeld = true  end)
    fireBtn.MouseButton1Up:Connect(function()   fireHeld = false end)
    riseBtn.MouseButton1Down:Connect(function() riseHeld = true  end)
    riseBtn.MouseButton1Up:Connect(function()   riseHeld = false end)

    -- ── Public API ────────────────────────────────────────────────────────────
    return {
        -- Left stick: X = strafe (-1=left, 1=right), Y = thrust (-1=fwd, 1=back)
        left  = function() return leftVec.X, leftVec.Y end,
        -- Right stick: X = yaw, Y = pitch
        right = function() return rightVec.X, rightVec.Y end,
        fire  = function() return fireHeld end,
        rise  = function() return riseHeld end,

        destroy = function()
            inputConn:Disconnect()
            movedConn:Disconnect()
            endedConn:Disconnect()
            container:Destroy()
        end,
    }
end

return VirtualJoystick
