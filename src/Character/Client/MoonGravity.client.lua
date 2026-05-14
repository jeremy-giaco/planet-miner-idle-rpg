-- LocalScript → StarterCharacterScripts
-- Spherical gravity + movement experiment.
--
-- Gravity: keep workspace.Gravity at its normal value so Humanoid jump power
-- math stays intact. Each frame:
--   1. Cancel the global -Y gravity pull
--   2. Apply pull toward PLANET_CENTER
-- Net: gravity always points toward planet center.
--
-- Movement: WalkSpeed = 0 so Humanoid doesn't fight us. We read WASD and
-- project the camera's direction onto the surface tangent plane, then apply
-- that as tangential velocity directly. This fixes movement at the equator
-- where world-XZ projection of camera direction would be near-zero.
--
-- BodyGyro: aligns HRP so character stands perpendicular to sphere surface.

local RunService        = game:GetService("RunService")
if not RunService:IsClient() then return end
if not script.Parent:IsA("Model") then return end
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage:WaitForChild("Config"))

local PLANET_CENTER = Config.PLANET_CENTER
local PLANET_RADIUS = Config.PLANET_RADIUS
local WALK_SPEED    = 48
local RUN_SPEED     = 80     -- held Shift

local character = script.Parent
local humanoid  = character:WaitForChild("Humanoid")
local hrp       = character:WaitForChild("HumanoidRootPart")

humanoid.WalkSpeed  = 0      -- we drive movement manually
humanoid.AutoRotate = false   -- BodyGyro owns all rotation

-- ── BodyGyro — aligns HRP so its Y axis = surface normal ─────────────────────

local bodyGyro     = Instance.new("BodyGyro")
bodyGyro.MaxTorque = Vector3.new(4e5, 4e5, 4e5)
bodyGyro.P         = 2e4
bodyGyro.D         = 400
bodyGyro.CFrame    = CFrame.new()
bodyGyro.Parent    = hrp

-- ── Spherical gravity ─────────────────────────────────────────────────────────

-- We track the "last good up" so we can redirect the Humanoid jump impulse.
-- When the Humanoid jumps it fires a +Y world impulse; we detect the sudden
-- upward velocity spike and re-orient it to be radially outward instead.
local lastUp = Vector3.new(0, 1, 0)

RunService.Heartbeat:Connect(function(dt)
    if not hrp.Parent then return end
    if character:FindFirstChild("InShip") then return end

    local pos = hrp.Position
    local fromCenter = pos - PLANET_CENTER
    local dist = fromCenter.Magnitude
    if dist < 1 then return end

    local up   = fromCenter.Unit   -- radially outward = "up" for this player
    lastUp = up

    local g   = workspace.Gravity  -- studs/s²

    -- 1. Cancel global -Y gravity that Roblox already applied this frame
    -- 2. Apply gravity toward planet center
    -- Net: replace -Y pull with -radial pull
    local vel = hrp.AssemblyLinearVelocity
    local cancelGlobal  = Vector3.new(0, g * dt, 0)    -- undo -Y
    local sphericalPull = -up * g * dt                 -- toward center
    hrp.AssemblyLinearVelocity = vel + cancelGlobal + sphericalPull

    -- ── BodyGyro orientation ──────────────────────────────────────────────────

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
    fwd = fwd.Unit

    bodyGyro.CFrame = CFrame.lookAt(Vector3.zero, fwd, up)

    -- ── Surface-tangent movement ───────────────────────────────────────────────
    -- Read WASD, project camera axes onto the surface tangent plane, apply velocity.
    if character:FindFirstChild("InShip") then return end

    local w = UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0
    local s = UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0
    local a = UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0
    local d = UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
    local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

    local speed = shift and RUN_SPEED or WALK_SPEED
    local inputFwd   = w - s
    local inputRight = d - a

    local vel = hrp.AssemblyLinearVelocity
    local radialVel = vel:Dot(up)       -- velocity component along surface normal (gravity/jump)

    if inputFwd ~= 0 or inputRight ~= 0 then
        -- Project camera axes onto the surface tangent plane
        local cam      = workspace.CurrentCamera
        local camLook  = cam.CFrame.LookVector
        local camRight = cam.CFrame.RightVector

        local surfFwd   = camLook  - camLook:Dot(up)  * up
        local surfRight = camRight - camRight:Dot(up) * up

        if surfFwd.Magnitude   > 0.01 then surfFwd   = surfFwd.Unit   end
        if surfRight.Magnitude > 0.01 then surfRight = surfRight.Unit end

        local moveDir = (surfFwd * inputFwd + surfRight * inputRight)
        if moveDir.Magnitude > 1 then moveDir = moveDir.Unit end

        -- Preserve radial (gravity + jump) velocity, replace tangential
        hrp.AssemblyLinearVelocity = up * radialVel + moveDir * speed
    else
        -- No input: bleed off tangential velocity (friction-like damping)
        local tangentVel = vel - up * radialVel
        hrp.AssemblyLinearVelocity = up * radialVel + tangentVel * (1 - math.min(dt * 12, 1))
    end
end)

-- ── Redirect Humanoid jump impulse ───────────────────────────────────────────
-- The Humanoid applies a +Y world-space impulse on jump.
-- We intercept StateChanged→Jumping and correct any misdirected velocity.

humanoid.StateChanged:Connect(function(_, new)
    if new ~= Enum.HumanoidStateType.Jumping then return end

    task.defer(function()
        -- By the time defer runs, Roblox has applied the jump impulse.
        -- Extract the component that isn't radially outward and fix it.
        local vel    = hrp.AssemblyLinearVelocity
        local up     = lastUp
        local radial = vel:Dot(up)   -- how much velocity is radially outward

        -- If the jump gave us very little radial velocity, redirect the
        -- global +Y component to radially outward.
        local worldUp = Vector3.new(0, 1, 0)
        local jumpY   = vel:Dot(worldUp)

        if radial < jumpY * 0.5 and jumpY > 5 then
            -- Remove the global Y component, add it radially
            local corrected = vel - worldUp * jumpY + up * jumpY
            hrp.AssemblyLinearVelocity = corrected
        end
    end)
end)
