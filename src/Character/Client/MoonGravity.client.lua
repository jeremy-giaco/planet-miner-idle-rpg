-- LocalScript → StarterCharacterScripts
-- Spherical gravity + movement for planet walking.
--
-- Gravity: uses a VectorForce that updates every frame.
--   Force = +Y * mass * g   (cancel Roblox's global -Y pull)
--         + (-up) * mass * g (add radial pull toward planet center)
--   Net: gravity always points toward PLANET_CENTER.
--   VectorForce runs at physics sub-step rate — no sliding from under-correction.
--
-- Movement: WalkSpeed = 0, WASD read manually, camera axes projected onto
--   the surface tangent plane so movement works at any latitude.
--
-- BodyGyro: aligns HRP so character stands on the sphere surface.
--
-- Safety: if player drifts more than 2× planet radius from center, teleport
--   back to the north pole surface (prevents dying by falling into the void).

local RunService        = game:GetService("RunService")
if not RunService:IsClient() then return end
if not script.Parent:IsA("Model") then return end
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage:WaitForChild("Config"))

local PLANET_CENTER  = Config.PLANET_CENTER
local PLANET_RADIUS  = Config.PLANET_RADIUS
local WALK_SPEED     = 48
local RUN_SPEED      = 80
local SAFETY_RADIUS  = PLANET_RADIUS * 2.2   -- past this → teleport home

local character = script.Parent
local humanoid  = character:WaitForChild("Humanoid")
local hrp       = character:WaitForChild("HumanoidRootPart")

humanoid.WalkSpeed  = 0
humanoid.AutoRotate = false

-- ── VectorForce — spherical gravity ──────────────────────────────────────────
-- Applied every physics sub-step; much more stable than Heartbeat velocity edits.

local gravAtt = Instance.new("Attachment")
gravAtt.Parent = hrp

local gravForce = Instance.new("VectorForce")
gravForce.Attachment0  = gravAtt
gravForce.RelativeTo   = Enum.ActuatorRelativeTo.World
gravForce.Force        = Vector3.zero
gravForce.Parent       = hrp

-- ── BodyGyro — surface orientation ───────────────────────────────────────────

local bodyGyro     = Instance.new("BodyGyro")
bodyGyro.MaxTorque = Vector3.new(4e5, 4e5, 4e5)
bodyGyro.P         = 2e4
bodyGyro.D         = 400
bodyGyro.CFrame    = CFrame.new()
bodyGyro.Parent    = hrp

-- ── Main loop ─────────────────────────────────────────────────────────────────

RunService.Heartbeat:Connect(function(dt)
    if not hrp.Parent then return end

    local pos  = hrp.Position
    local fromCenter = pos - PLANET_CENTER
    local dist = fromCenter.Magnitude
    if dist < 1 then return end

    local up = fromCenter.Unit   -- radially outward = local "up"
    local g  = workspace.Gravity
    local mass = hrp.AssemblyMass

    -- ── Gravity force ─────────────────────────────────────────────────────────
    -- Cancel global -Y gravity and replace with pull toward planet center.
    gravForce.Force = Vector3.new(0, mass * g, 0)   -- cancel global
                    + (-up * mass * g)               -- add spherical

    -- ── BodyGyro orientation ──────────────────────────────────────────────────
    if not character:FindFirstChild("InShip") then
        local moveDir = humanoid.MoveDirection
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
        if fwd.Magnitude < 0.01 then
            fwd = Vector3.new(1, 0, 0) - Vector3.new(1, 0, 0):Dot(up) * up
        end
        bodyGyro.CFrame = CFrame.lookAt(Vector3.zero, fwd.Unit, up)
    end

    -- ── Surface-tangent movement ──────────────────────────────────────────────
    if character:FindFirstChild("InShip") then return end

    local w     = UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0
    local s     = UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0
    local a     = UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0
    local d     = UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
    local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
               or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

    local speed = shift and RUN_SPEED or WALK_SPEED
    local inputFwd   = w - s
    local inputRight = d - a

    local vel        = hrp.AssemblyLinearVelocity
    local radialVel  = vel:Dot(up)       -- gravity / jump component (preserve this)

    if inputFwd ~= 0 or inputRight ~= 0 then
        local cam      = workspace.CurrentCamera
        local camLook  = cam.CFrame.LookVector
        local camRight = cam.CFrame.RightVector

        -- Project camera axes onto the surface tangent plane
        local surfFwd   = camLook  - camLook:Dot(up)  * up
        local surfRight = camRight - camRight:Dot(up) * up

        if surfFwd.Magnitude   > 0.01 then surfFwd   = surfFwd.Unit   end
        if surfRight.Magnitude > 0.01 then surfRight = surfRight.Unit end

        local moveDir = surfFwd * inputFwd + surfRight * inputRight
        if moveDir.Magnitude > 1 then moveDir = moveDir.Unit end

        hrp.AssemblyLinearVelocity = up * radialVel + moveDir * speed
    else
        -- Damp tangential velocity (surface friction)
        local tangentVel = vel - up * radialVel
        hrp.AssemblyLinearVelocity = up * radialVel
                                   + tangentVel * (1 - math.min(dt * 14, 1))
    end

    -- ── Safety respawn ────────────────────────────────────────────────────────
    if dist > SAFETY_RADIUS then
        local safePos = PLANET_CENTER + Vector3.new(0, PLANET_RADIUS + 10, 0)
        hrp.CFrame = CFrame.new(safePos)
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
end)

-- ── Redirect Humanoid jump impulse to radially outward ───────────────────────

local lastUp = Vector3.new(0, 1, 0)

RunService.Heartbeat:Connect(function()
    if hrp.Parent then
        local d2 = (hrp.Position - PLANET_CENTER).Magnitude
        if d2 > 1 then lastUp = (hrp.Position - PLANET_CENTER).Unit end
    end
end)

humanoid.StateChanged:Connect(function(_, new)
    if new ~= Enum.HumanoidStateType.Jumping then return end
    task.defer(function()
        local vel      = hrp.AssemblyLinearVelocity
        local up       = lastUp
        local worldUp  = Vector3.new(0, 1, 0)
        local jumpY    = vel:Dot(worldUp)
        local radial   = vel:Dot(up)
        if radial < jumpY * 0.5 and jumpY > 5 then
            hrp.AssemblyLinearVelocity = vel - worldUp * jumpY + up * jumpY
        end
    end)
end)
