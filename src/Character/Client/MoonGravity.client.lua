-- LocalScript → StarterCharacterScripts
-- Aligns the character perpendicular to the sphere surface using BodyGyro.
-- workspace.Gravity handles the downward pull; this keeps the player upright
-- relative to the planet rather than the global Y axis.

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage:WaitForChild("Config"))

local PLANET_CENTER = Config.PLANET_CENTER

local character = script.Parent
local humanoid  = character:WaitForChild("Humanoid")
local hrp       = character:WaitForChild("HumanoidRootPart")

humanoid.WalkSpeed = 56

-- BodyGyro keeps HRP upright relative to sphere surface (up = away from center)
local bodyGyro         = Instance.new("BodyGyro")
bodyGyro.MaxTorque     = Vector3.new(4e5, 4e5, 4e5)
bodyGyro.P             = 3e4
bodyGyro.D             = 500
bodyGyro.CFrame        = CFrame.new()
bodyGyro.Parent        = hrp

RunService.Heartbeat:Connect(function()
    if not hrp.Parent then return end
    if character:FindFirstChild("InShip") then return end

    -- Up vector = away from planet center
    local up = (hrp.Position - PLANET_CENTER).Unit

    -- Preserve horizontal facing: project current right vector onto plane ⊥ to up
    local right = hrp.CFrame.RightVector
    right = right - right:Dot(up) * up
    if right.Magnitude < 0.01 then
        -- fallback: use world X
        right = Vector3.new(1, 0, 0) - Vector3.new(1, 0, 0):Dot(up) * up
    end
    right = right.Unit

    -- Build target orientation: right stays horizontal, up = sphere normal
    bodyGyro.CFrame = CFrame.fromMatrix(Vector3.new(), right, up)
end)
