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
