-- LocalScript → StarterCharacterScripts
-- Jetpack: Space held = thrust away from planet center (radial up)
-- Builds a visible thruster pack on the character's back with particle exhaust.

local RunService        = game:GetService("RunService")
if not RunService:IsClient() then return end
if not script.Parent:IsA("Model") then return end
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage:WaitForChild("Config"))

local PLANET_CENTER = Config.PLANET_CENTER

local character = script.Parent
local humanoid  = character:WaitForChild("Humanoid")
local hrp       = character:WaitForChild("HumanoidRootPart")
local torso     = character:WaitForChild("UpperTorso")

local THRUST       = 140
local MAX_UP_SPEED = 90

-- ── Jetpack model ─────────────────────────────────────────────────────────────

local PACK_COL    = Color3.fromRGB(40, 50, 80)
local NEON_COL    = Color3.fromRGB(80, 180, 255)
local THRUSTER_COL = Color3.fromRGB(60, 70, 100)

local function weld(part, anchor)
    local w = Instance.new("WeldConstraint")
    w.Part0 = anchor; w.Part1 = part; w.Parent = part
end

local function makePart(size, cframe, color, mat, trans)
    local p = Instance.new("Part")
    p.Size         = size
    p.CFrame       = cframe
    p.Anchored     = false
    p.CanCollide   = false
    p.CastShadow   = false
    p.Color        = color
    p.Material     = mat or Enum.Material.SmoothPlastic
    p.Transparency = trans or 0
    p.Parent       = character
    return p
end

-- Main pack body (attached to back of torso)
local packCF = torso.CFrame * CFrame.new(0, 0.1, 0.85) * CFrame.Angles(0, math.pi, 0)
local pack = makePart(Vector3.new(0.9, 1.1, 0.45), packCF, PACK_COL)
weld(pack, torso)

-- Top accent strip
local strip = makePart(Vector3.new(0.85, 0.15, 0.5), packCF * CFrame.new(0, 0.55, 0), NEON_COL, Enum.Material.Neon)
weld(strip, torso)
local stripLight = Instance.new("PointLight")
stripLight.Color = NEON_COL; stripLight.Brightness = 1.5; stripLight.Range = 8
stripLight.Parent = strip

-- Two thruster nozzles (bottom of pack)
local nozzleOffsets = { -0.22, 0.22 }
local nozzles = {}
for i, xOff in ipairs(nozzleOffsets) do
    local noz = makePart(
        Vector3.new(0.28, 0.35, 0.28),
        packCF * CFrame.new(xOff, -0.65, 0),
        THRUSTER_COL
    )
    Instance.new("UICorner") -- cosmetic only, no effect on Part
    weld(noz, torso)
    nozzles[i] = noz

    -- Nozzle inner glow ring
    local glow = makePart(Vector3.new(0.18, 0.1, 0.18),
        packCF * CFrame.new(xOff, -0.83, 0), NEON_COL, Enum.Material.Neon)
    weld(glow, torso)
end

-- ── Exhaust particles ─────────────────────────────────────────────────────────

local exhaustParts = {}
for i, xOff in ipairs(nozzleOffsets) do
    local att = Instance.new("Attachment")
    att.Position = Vector3.new(xOff, -0.83, 0)  -- relative to torso bottom-back
    att.Parent   = torso

    local particles = Instance.new("ParticleEmitter")
    particles.Texture       = "rbxasset://textures/particles/sparkles_main.dds"
    particles.Color         = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 200, 255)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(80, 130, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 40, 120)),
    })
    particles.LightEmission  = 1
    particles.LightInfluence = 0
    particles.Size           = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.5, 0.15),
        NumberSequenceKeypoint.new(1, 0),
    })
    particles.Transparency   = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    })
    particles.Speed          = NumberRange.new(14, 28)
    particles.Lifetime       = NumberRange.new(0.3, 0.65)
    particles.Rate           = 0      -- controlled manually
    particles.SpreadAngle    = Vector2.new(25, 25)
    particles.Rotation       = NumberRange.new(0, 360)
    particles.RotSpeed       = NumberRange.new(-180, 180)
    particles.EmissionDirection = Enum.NormalId.Top  -- attachment handles orientation
    particles.Parent         = att

    exhaustParts[i] = particles
end

-- ── Thrust logic ─────────────────────────────────────────────────────────────

local thrusting = false

RunService.Heartbeat:Connect(function(dt)
    if humanoid.Health <= 0 then return end
    if character:FindFirstChild("InShip") then
        -- hide particles when in ship
        for _, p in ipairs(exhaustParts) do p.Rate = 0 end
        return
    end

    local isThrustKey = UserInputService:IsKeyDown(Enum.KeyCode.Space)

    -- Mobile: check rise button from VirtualJoystick if available
    -- (sticks.rise() returns true when the ▲ button is held)

    if isThrustKey then
        local upDir  = (hrp.Position - PLANET_CENTER).Unit
        local vel    = hrp.AssemblyLinearVelocity
        local upSpeed = vel:Dot(upDir)
        if upSpeed < MAX_UP_SPEED then
            local boost = math.min(THRUST * dt, MAX_UP_SPEED - upSpeed)
            hrp.AssemblyLinearVelocity = vel + upDir * boost
        end
        if not thrusting then
            thrusting = true
            for _, p in ipairs(exhaustParts) do p.Rate = 120 end
            stripLight.Brightness = 6
        end
    else
        if thrusting then
            thrusting = false
            for _, p in ipairs(exhaustParts) do p.Rate = 0 end
            stripLight.Brightness = 1.5
        end
    end
end)
