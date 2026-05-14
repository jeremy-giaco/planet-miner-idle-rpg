-- LocalScript → StarterCharacterScripts
-- Spherical camera: orbits the character with the surface normal as the
-- camera's up vector. This means the camera always looks "tangent" to the
-- sphere no matter where on the planet you are, so the built-in camera
-- input axes correctly map onto the surface.
--
-- Uses Scriptable CameraType — overrides the default Roblox follow-cam.

local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config           = require(ReplicatedStorage:WaitForChild("Config"))

local PLANET_CENTER = Config.PLANET_CENTER

local character = script.Parent
local hrp       = character:WaitForChild("HumanoidRootPart")
local camera    = workspace.CurrentCamera

-- ── Settings ──────────────────────────────────────────────────────────────────
local DISTANCE    = 22      -- studs behind the character
local HEIGHT      = 6       -- studs above the character shoulder level
local SENSITIVITY = 0.004   -- mouse / touch sensitivity
local MIN_PITCH   = math.rad(-25)   -- max look down
local MAX_PITCH   = math.rad(60)    -- max look up

-- ── State ─────────────────────────────────────────────────────────────────────
local yaw   = 0             -- angle around the surface normal (horizontal orbit)
local pitch = math.rad(15)  -- angle above the surface horizon (vertical tilt)

camera.CameraType = Enum.CameraType.Scriptable
UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

-- ── Input ─────────────────────────────────────────────────────────────────────
UserInputService.InputChanged:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        yaw   = yaw   - input.Delta.X * SENSITIVITY
        pitch = math.clamp(pitch - input.Delta.Y * SENSITIVITY, MIN_PITCH, MAX_PITCH)
    elseif input.UserInputType == Enum.UserInputType.Touch then
        -- touch delta is handled by the default JumpButton / thumbstick UI;
        -- secondary finger drag = camera look
        yaw   = yaw   - input.Delta.X * SENSITIVITY * 0.5
        pitch = math.clamp(pitch - input.Delta.Y * SENSITIVITY * 0.5, MIN_PITCH, MAX_PITCH)
    end
end)

-- ── Render loop ───────────────────────────────────────────────────────────────
RunService.RenderStepped:Connect(function()
    if character:FindFirstChild("InShip") then
        -- Let the ship scripts handle the camera
        camera.CameraType = Enum.CameraType.Custom
        return
    end
    camera.CameraType = Enum.CameraType.Scriptable

    local pos = hrp.Position
    local up  = (pos - PLANET_CENTER).Unit

    -- Build a local frame on the sphere surface:
    -- up   = surface normal (radially outward)
    -- ref  = a world axis not parallel to up (for cross product)
    -- east = tangent vector pointing "east" at this latitude
    -- north= tangent vector pointing "north" (toward pole from equator)
    local ref   = (math.abs(up.Y) < 0.9) and Vector3.new(0, 1, 0) or Vector3.new(1, 0, 0)
    local east  = up:Cross(ref).Unit
    local north = east:Cross(up).Unit      -- completes the right-hand frame

    -- Rotate the camera horizontally (yaw around surface normal)
    local cosY, sinY = math.cos(yaw), math.sin(yaw)
    local camFwd   = north * cosY + east * sinY    -- horizontal forward (yaw applied)
    local camRight = east  * cosY - north * sinY   -- horizontal right

    -- Apply pitch: tilt camFwd toward/away from up
    local cosP, sinP = math.cos(pitch), math.sin(pitch)
    local camDir = camFwd * cosP + up * sinP        -- camera "forward into the scene"

    -- Camera sits behind-and-above the character
    local camPos = pos - camDir * DISTANCE + up * HEIGHT

    camera.CFrame = CFrame.lookAt(camPos, pos + up * 1.5, up)
end)
