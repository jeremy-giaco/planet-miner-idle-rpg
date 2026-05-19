-- LocalScript → StarterCharacterScripts
-- Keeps the character upright on the flat map and facing their movement direction.
-- workspace.Gravity handles downward pull. Up is always world Y.

local RunService = game:GetService("RunService")
if not RunService:IsClient() then return end
if not script.Parent:IsA("Model") then return end

local character = script.Parent
local humanoid  = character:WaitForChild("Humanoid")
local hrp       = character:WaitForChild("HumanoidRootPart")

humanoid.WalkSpeed  = 48
humanoid.AutoRotate = false   -- BodyGyro owns rotation

local bodyGyro     = Instance.new("BodyGyro")
bodyGyro.MaxTorque = Vector3.new(4e5, 4e5, 4e5)
bodyGyro.P         = 2e4
bodyGyro.D         = 400
bodyGyro.CFrame    = CFrame.new()
bodyGyro.Parent    = hrp

local UP = Vector3.new(0, 1, 0)

RunService.Heartbeat:Connect(function()
    if not hrp.Parent then return end
    if character:FindFirstChild("InShip") then return end

    local moveDir = humanoid.MoveDirection
    local fwd
    if moveDir.Magnitude > 0.1 then
        -- Project onto horizontal plane (remove Y) so character doesn't tilt while jumping
        fwd = Vector3.new(moveDir.X, 0, moveDir.Z)
    else
        fwd = hrp.CFrame.LookVector
        fwd = Vector3.new(fwd.X, 0, fwd.Z)
    end
    if fwd.Magnitude < 0.01 then fwd = Vector3.new(0, 0, -1) end
    fwd = fwd.Unit

    bodyGyro.CFrame = CFrame.lookAt(Vector3.zero, fwd, UP)
end)
