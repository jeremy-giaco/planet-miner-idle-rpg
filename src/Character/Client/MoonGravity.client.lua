-- LocalScript → StarterCharacterScripts
-- Spherical gravity: pulls toward PLANET_CENTER from any direction.
--
-- Uses a VectorForce that cancels Roblox's global -Y gravity and replaces
-- it with a radial pull toward the planet center. VectorForce is updated
-- every Heartbeat; it runs at physics sub-step rate internally so there's
-- no under-correction / sliding from frame-rate mismatch.
--
-- WalkSpeed is left at 48 so the Humanoid handles movement naturally.
-- This means the equator is still awkward (camera is world-Y up so WASD
-- doesn't map cleanly to "up the sphere") but everything else feels right.
--
-- BodyGyro keeps the character upright relative to the surface normal.
-- Safety respawn if player drifts too far from the planet.

local RunService        = game:GetService("RunService")
if not RunService:IsClient() then return end
if not script.Parent:IsA("Model") then return end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage:WaitForChild("Config"))

local PLANET_CENTER  = Config.PLANET_CENTER
local PLANET_RADIUS  = Config.PLANET_RADIUS
local SAFETY_RADIUS  = PLANET_RADIUS * 2.2

local character = script.Parent
local humanoid  = character:WaitForChild("Humanoid")
local hrp       = character:WaitForChild("HumanoidRootPart")

humanoid.WalkSpeed  = 48
humanoid.AutoRotate = false

-- ── VectorForce — spherical gravity ──────────────────────────────────────────

local gravAtt = Instance.new("Attachment")
gravAtt.Parent = hrp

local gravForce = Instance.new("VectorForce")
gravForce.Attachment0 = gravAtt
gravForce.RelativeTo  = Enum.ActuatorRelativeTo.World
gravForce.Force       = Vector3.zero
gravForce.Parent      = hrp

-- ── BodyGyro — surface orientation ───────────────────────────────────────────

local bodyGyro     = Instance.new("BodyGyro")
bodyGyro.MaxTorque = Vector3.new(4e5, 4e5, 4e5)
bodyGyro.P         = 2e4
bodyGyro.D         = 400
bodyGyro.CFrame    = CFrame.new()
bodyGyro.Parent    = hrp

-- ── Main loop ─────────────────────────────────────────────────────────────────

RunService.Heartbeat:Connect(function()
    if not hrp.Parent then return end
    if character:FindFirstChild("InShip") then return end

    local pos  = hrp.Position
    local dist = (pos - PLANET_CENTER).Magnitude
    if dist < 1 then return end

    local up   = (pos - PLANET_CENTER).Unit
    local g    = workspace.Gravity
    local mass = hrp.AssemblyMass

    -- Cancel global -Y gravity, apply radial pull toward planet center
    gravForce.Force = Vector3.new(0, mass * g, 0) + (-up * mass * g)

    -- Orient character to stand on sphere surface
    local moveDir = humanoid.MoveDirection
    local fwd
    if moveDir.Magnitude > 0.1 then
        fwd = moveDir - moveDir:Dot(up) * up
    else
        fwd = hrp.CFrame.LookVector - hrp.CFrame.LookVector:Dot(up) * up
    end
    if fwd.Magnitude < 0.01 then
        fwd = Vector3.new(0, 0, -1) - Vector3.new(0, 0, -1):Dot(up) * up
    end
    if fwd.Magnitude < 0.01 then
        fwd = Vector3.new(1, 0, 0) - Vector3.new(1, 0, 0):Dot(up) * up
    end
    bodyGyro.CFrame = CFrame.lookAt(Vector3.zero, fwd.Unit, up)

    -- Safety: if drifted into space, snap back to north pole
    if dist > SAFETY_RADIUS then
        hrp.CFrame = CFrame.new(PLANET_CENTER + Vector3.new(0, PLANET_RADIUS + 10, 0))
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
end)

-- ── Redirect jump impulse to radially outward ────────────────────────────────

local lastUp = Vector3.new(0, 1, 0)

RunService.Heartbeat:Connect(function()
    if hrp.Parent and (hrp.Position - PLANET_CENTER).Magnitude > 1 then
        lastUp = (hrp.Position - PLANET_CENTER).Unit
    end
end)

humanoid.StateChanged:Connect(function(_, new)
    if new ~= Enum.HumanoidStateType.Jumping then return end
    task.defer(function()
        local vel     = hrp.AssemblyLinearVelocity
        local up      = lastUp
        local worldUp = Vector3.new(0, 1, 0)
        local jumpY   = vel:Dot(worldUp)
        local radial  = vel:Dot(up)
        if radial < jumpY * 0.5 and jumpY > 5 then
            hrp.AssemblyLinearVelocity = vel - worldUp * jumpY + up * jumpY
        end
    end)
end)
