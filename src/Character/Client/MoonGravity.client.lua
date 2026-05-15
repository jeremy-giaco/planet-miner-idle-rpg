-- LocalScript → StarterCharacterScripts
-- Spherical gravity experiment: redirects gravity to always pull toward
-- PLANET_CENTER regardless of where on the sphere the player stands.
--
-- Strategy: keep workspace.Gravity at its normal value so the Humanoid's
-- jump power math stays intact. Each frame we:
--   1. Cancel the global -Y gravity pull  (+Y * g * dt added to velocity)
--   2. Apply our own pull toward PLANET_CENTER  (-radial * g * dt)
-- Net result: gravity always points toward the planet center.
--
-- BodyGyro keeps HRP upright relative to the surface normal (unchanged from before).

local RunService        = game:GetService("RunService")
if not RunService:IsClient() then return end
if not script.Parent:IsA("Model") then return end
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage:WaitForChild("Config"))

local PLANET_CENTER = Config.PLANET_CENTER
local PLANET_RADIUS = Config.PLANET_RADIUS
local SAFETY_RADIUS = PLANET_RADIUS * 2.2

local character = script.Parent
local humanoid  = character:WaitForChild("Humanoid")
local hrp       = character:WaitForChild("HumanoidRootPart")

humanoid.WalkSpeed  = 48
humanoid.AutoRotate = false   -- BodyGyro owns all rotation

-- ── BodyGyro — aligns HRP so its Y axis = surface normal ─────────────────────

local bodyGyro     = Instance.new("BodyGyro")
bodyGyro.MaxTorque = Vector3.new(4e5, 4e5, 4e5)
bodyGyro.P         = 2e4
bodyGyro.D         = 400
bodyGyro.CFrame    = CFrame.new()
bodyGyro.Parent    = hrp

-- ── Spherical gravity ─────────────────────────────────────────────────────────

local lastUp = Vector3.new(0, 1, 0)

RunService.Heartbeat:Connect(function(dt)
    if not hrp.Parent then return end
    if character:FindFirstChild("InShip") then return end

    local pos        = hrp.Position
    local fromCenter = pos - PLANET_CENTER
    local dist       = fromCenter.Magnitude
    if dist < 1 then return end

    local up  = fromCenter.Unit
    lastUp    = up
    local g   = workspace.Gravity

    -- Cancel global -Y gravity, apply radial pull toward planet center
    local vel = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = vel
        + Vector3.new(0, g * dt, 0)   -- undo -Y
        + (-up * g * dt)              -- toward center

    -- ── BodyGyro orientation ──────────────────────────────────────────────────
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

    -- Safety respawn
    if dist > SAFETY_RADIUS then
        hrp.CFrame = CFrame.new(PLANET_CENTER + Vector3.new(0, PLANET_RADIUS + 10, 0))
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
end)

-- ── Redirect Humanoid jump impulse to radially outward ───────────────────────

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
