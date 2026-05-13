-- LocalScript → StarterCharacterScripts
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local character = script.Parent
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")

local THRUST       = 120
local MAX_UP_SPEED = 80

RunService.Heartbeat:Connect(function(dt)
    if humanoid.Health <= 0 then return end
    if not UserInputService:IsKeyDown(Enum.KeyCode.Space) then return end

    -- Flat world: up is always +Y
    local upDir   = Vector3.new(0, 1, 0)
    local vel     = rootPart.AssemblyLinearVelocity
    local upSpeed = vel:Dot(upDir)
    if upSpeed < MAX_UP_SPEED then
        local boost = math.min(THRUST * dt, MAX_UP_SPEED - upSpeed)
        rootPart.AssemblyLinearVelocity = vel + upDir * boost
    end
end)
