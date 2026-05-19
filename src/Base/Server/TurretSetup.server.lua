-- Script → ServerScriptService/TurretSetup
-- Builds the rooftop defence turret on top of the main base building.
if not game:GetService("RunService"):IsServer() then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

-- ── Position: roof centre ─────────────────────────────────────────────────────
-- Base ceiling slab: centre Y = H + 2.5, thickness 5 → top surface = H + 5
local bp   = Config.BASE_POSITION
local H    = Config.BASE_HEIGHT          -- 44
local ROOF_Y = H + 5                     -- 49  (top of glass ceiling slab)

local cx, cz = bp.X, bp.Z               -- directly above lobby centre

-- Turret sits on a raised octagonal platform so it clears the spire bases
-- and gives the gunner a commanding view over all four spires.
local PEDESTAL_H = 8
local cy = ROOF_Y + PEDESTAL_H          -- base of the seat ring

local NEON  = Color3.fromRGB(90, 50, 220)
local METAL = Color3.fromRGB(45, 52, 78)
local DARK  = Color3.fromRGB(28, 32, 50)
local NEON2 = Color3.fromRGB(0, 200, 255)

local function anchoredPart(name, size, cframe, color, material, parent)
    local p = Instance.new("Part")
    p.Name       = name
    p.Size       = size
    p.CFrame     = cframe
    p.Anchored   = true
    p.CanCollide = true
    p.CastShadow = true
    p.Color      = color
    p.Material   = material or Enum.Material.Metal
    p.Parent     = parent
    return p
end

local function addLight(parent, color, brightness, range)
    local l = Instance.new("PointLight")
    l.Color = color; l.Brightness = brightness; l.Range = range
    l.Parent = parent
end

-- ── Model ─────────────────────────────────────────────────────────────────────

local model = Instance.new("Model")
model.Name   = "Turret"
model.Parent = workspace

-- Pedestal (raised octagonal platform on the roof)
local pedBody = anchoredPart("PedestalBody",
    Vector3.new(10, PEDESTAL_H, 10),
    CFrame.new(cx, ROOF_Y + PEDESTAL_H/2, cz),
    METAL, Enum.Material.Metal, model)

local pedTop = anchoredPart("PedestalTop",
    Vector3.new(12, 0.5, 12),
    CFrame.new(cx, ROOF_Y + PEDESTAL_H + 0.25, cz),
    DARK, Enum.Material.SmoothPlastic, model)

-- Neon edge strip on platform rim
local rim = anchoredPart("PedestalRim",
    Vector3.new(12.2, 0.25, 12.2),
    CFrame.new(cx, ROOF_Y + PEDESTAL_H + 0.6, cz),
    NEON, Enum.Material.Neon, model)
rim.CanCollide = false
addLight(rim, NEON, 1.5, 30)

-- Neon corner posts on pedestal
for _, xz in ipairs({{-5,-5},{5,-5},{-5,5},{5,5}}) do
    local post = anchoredPart("Post",
        Vector3.new(0.6, PEDESTAL_H + 0.5, 0.6),
        CFrame.new(cx + xz[1], ROOF_Y + PEDESTAL_H/2, cz + xz[2]),
        NEON2, Enum.Material.Neon, model)
    post.CanCollide = false
    addLight(post, NEON2, 0.8, 14)
end

-- Access ladder (visual only, decorative)
for i = 0, PEDESTAL_H - 1 do
    local rung = anchoredPart("Rung",
        Vector3.new(1.8, 0.18, 0.18),
        CFrame.new(cx + 5, ROOF_Y + i + 0.6, cz),
        METAL, Enum.Material.Metal, model)
    rung.CanCollide = false
    rung.CastShadow = false
end

-- Rotating ring / swivel base
local ring = anchoredPart("Ring",
    Vector3.new(5, 0.3, 5),
    CFrame.new(cx, cy + 0.15, cz),
    NEON, Enum.Material.Neon, model)
ring.CanCollide = false
ring.CastShadow = false

local base = anchoredPart("SwivelBase",
    Vector3.new(4, 0.8, 4),
    CFrame.new(cx, cy + 0.6, cz),
    METAL, Enum.Material.Metal, model)

-- Chair seat
local seat = Instance.new("Seat")
seat.Name      = "GunnerSeat"
seat.Size      = Vector3.new(2.2, 0.25, 1.8)
seat.CFrame    = CFrame.new(cx, cy + 1.25, cz) * CFrame.Angles(0, math.pi, 0)
seat.Anchored  = true
seat.Color     = DARK
seat.Material  = Enum.Material.SmoothPlastic
seat.Parent    = model

-- Chair back
anchoredPart("ChairBack",
    Vector3.new(2.2, 2.8, 0.25),
    CFrame.new(cx, cy + 2.65, cz + 1.0),
    METAL, Enum.Material.Metal, model)

-- Headrest
anchoredPart("Headrest",
    Vector3.new(1.4, 0.8, 0.25),
    CFrame.new(cx, cy + 4.1, cz + 1.0),
    DARK, Enum.Material.SmoothPlastic, model)

-- Armrests
for _, s in ipairs({-1, 1}) do
    anchoredPart("Armrest",
        Vector3.new(0.25, 0.2, 1.6),
        CFrame.new(cx + s * 1.25, cy + 1.6, cz),
        METAL, Enum.Material.Metal, model)
end

-- Barrel pivot
local pivot = anchoredPart("BarrelPivot",
    Vector3.new(0.5, 0.5, 0.5),
    CFrame.new(cx, cy + 2.0, cz - 1.2),
    NEON, Enum.Material.Neon, model)
pivot.CanCollide = false

-- Barrel
anchoredPart("Barrel",
    Vector3.new(0.28, 0.28, 5),
    CFrame.new(cx, cy + 2.0, cz - 3.7),
    METAL, Enum.Material.Metal, model)

-- Barrel tip
local tip = anchoredPart("BarrelTip",
    Vector3.new(0.38, 0.38, 0.2),
    CFrame.new(cx, cy + 2.0, cz - 6.2),
    Color3.fromRGB(0, 230, 120), Enum.Material.Neon, model)
tip.CanCollide = false

-- Eye point (camera anchor when seated)
local eye = Instance.new("Part")
eye.Name         = "EyePoint"
eye.Size         = Vector3.new(0.1, 0.1, 0.1)
eye.CFrame       = CFrame.new(cx, cy + 2.8, cz + 0.2)
eye.Anchored     = true
eye.CanCollide   = false
eye.Transparency = 1
eye.Parent       = model

-- ── ProximityPrompt ───────────────────────────────────────────────────────────

local prompt = Instance.new("ProximityPrompt")
prompt.ActionText             = "Man Turret"
prompt.ObjectText             = "Rooftop Turret"
prompt.KeyboardKeyCode        = Enum.KeyCode.E
prompt.HoldDuration           = 0
prompt.MaxActivationDistance  = 10
prompt.Parent                 = base

prompt.Triggered:Connect(function(player)
    if seat.Occupant then return end
    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum then seat:Sit(hum) end
end)

seat:GetPropertyChangedSignal("Occupant"):Connect(function()
    prompt.Enabled = seat.Occupant == nil
end)

model.PrimaryPart = base
print("[TurretSetup] Rooftop turret ready at Y=" .. cy)
