-- LocalScript → StarterCharacterScripts
-- Aligns the character perpendicular to the sphere surface using BodyGyro.
-- workspace.Gravity handles the downward pull; this keeps the player upright
-- relative to the planet rather than the global Y axis.

local RunService        = game:GetService("RunService")
if not RunService:IsClient() then return end
if not script.Parent:IsA("Model") then return end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage:WaitForChild("Config"))

local PLANET_CENTER = Config.PLANET_CENTER

local character = script.Parent
local humanoid  = character:WaitForChild("Humanoid")
local hrp       = character:WaitForChild("HumanoidRootPart")

humanoid.WalkSpeed  = 48
humanoid.AutoRotate = false   -- BodyGyro owns all rotation; prevents fight/shake
humanoid.HipHeight  = 0       -- sink feet to actual ground surface (default 1.35 causes floating)

-- BodyGyro keeps HRP upright AND facing movement direction
local bodyGyro     = Instance.new("BodyGyro")
bodyGyro.MaxTorque = Vector3.new(4e5, 4e5, 4e5)
bodyGyro.P         = 2e4
bodyGyro.D         = 400
bodyGyro.CFrame    = CFrame.new()
bodyGyro.Parent    = hrp

RunService.Heartbeat:Connect(function()
    if not hrp.Parent then return end
    if character:FindFirstChild("InShip") then return end

    local up      = (hrp.Position - PLANET_CENTER).Unit
    local moveDir = humanoid.MoveDirection

    -- Forward: face movement direction when moving, otherwise preserve current facing
    local fwd
    if moveDir.Magnitude > 0.1 then
        fwd = moveDir - moveDir:Dot(up) * up
    else
        fwd = hrp.CFrame.LookVector
        fwd = fwd - fwd:Dot(up) * up
    end
    if fwd.Magnitude < 0.01 then
        fwd = Vector3.new(0, 0, -1) - Vector3.new(0, 0, -1):Dot(up) * up
    end
    fwd = fwd.Unit

    -- CFrame.lookAt: position at origin, look toward fwd, up = sphere normal
    bodyGyro.CFrame = CFrame.lookAt(Vector3.zero, fwd, up)
end)
