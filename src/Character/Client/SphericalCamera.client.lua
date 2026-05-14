-- LocalScript → StarterCharacterScripts
-- Spherical orbit camera: tilts with the surface normal so WASD always
-- moves along the planet surface regardless of latitude.
-- RMB held = orbit  |  Scroll = zoom  |  no cursor lock by default.

local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config           = require(ReplicatedStorage:WaitForChild("Config"))

local PLANET_CENTER = Config.PLANET_CENTER

local character = script.Parent
local hrp       = character:WaitForChild("HumanoidRootPart")
local camera    = workspace.CurrentCamera

-- ── Settings ──────────────────────────────────────────────────────────────────
local distance    = 28      -- current zoom distance (studs)
local MIN_DIST    = 6
local MAX_DIST    = 120
local ZOOM_SPEED  = 4       -- studs per scroll tick
local SENSITIVITY = 0.005
local MIN_PITCH   = math.rad(-20)
local MAX_PITCH   = math.rad(70)

-- ── State ─────────────────────────────────────────────────────────────────────
local yaw   = 0
local pitch = math.rad(20)
local rmbDown = false

camera.CameraType = Enum.CameraType.Scriptable

-- ── Input ─────────────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        rmbDown = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        rmbDown = false
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
end)

UserInputService.InputChanged:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.MouseMovement and rmbDown then
        yaw   = yaw   - input.Delta.X * SENSITIVITY
        pitch = math.clamp(pitch - input.Delta.Y * SENSITIVITY, MIN_PITCH, MAX_PITCH)
    elseif input.UserInputType == Enum.UserInputType.MouseWheel then
        distance = math.clamp(distance - input.Position.Z * ZOOM_SPEED, MIN_DIST, MAX_DIST)
    end
end)

-- ── Render loop ───────────────────────────────────────────────────────────────
RunService.RenderStepped:Connect(function()
    if character:FindFirstChild("InShip") then
        camera.CameraType = Enum.CameraType.Custom
        return
    end
    camera.CameraType = Enum.CameraType.Scriptable

    local pos = hrp.Position
    local up  = (pos - PLANET_CENTER).Unit

    -- Build a local surface frame (up = surface normal)
    local ref   = (math.abs(up.Y) < 0.9) and Vector3.new(0, 1, 0) or Vector3.new(1, 0, 0)
    local east  = up:Cross(ref).Unit
    local north = east:Cross(up).Unit

    -- Apply yaw (horizontal orbit around surface normal)
    local cosY, sinY = math.cos(yaw), math.sin(yaw)
    local camFwd = north * cosY + east * sinY

    -- Apply pitch (tilt above/below the surface horizon)
    local cosP, sinP = math.cos(pitch), math.sin(pitch)
    local camDir = camFwd * cosP + up * sinP  -- direction from target to camera (reversed below)

    local camPos = pos - camDir * distance + up * 1.5
    camera.CFrame = CFrame.lookAt(camPos, pos + up * 1.5, up)
end)
