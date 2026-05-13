-- Script → place in ServerScriptService, rename to "TurretSetup"
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Flat world: compound top surface is at Y=3
local basePos = Vector3.new(0, 0, 0)  -- XZ center of compound
local topY    = 3                      -- Y = top surface of the Compound slab

local NEON  = Color3.fromRGB(90, 50, 220)
local METAL = Color3.fromRGB(45, 52, 78)
local DARK  = Color3.fromRGB(28, 32, 50)

local function anchoredPart(name, size, cframe, color, material, parent)
    local p = Instance.new("Part")
    p.Name     = name
    p.Size     = size
    p.CFrame   = cframe
    p.Anchored = true
    p.Color    = color
    p.Material = material or Enum.Material.Metal
    p.CastShadow = true
    p.Parent   = parent
    return p
end

-- ── Model ────────────────────────────────────────────────────────────────────

local model = Instance.new("Model")
model.Name   = "Turret"
model.Parent = workspace

local cx, cy, cz = basePos.X, topY, basePos.Z  -- center of platform top

-- Rotating ring / base plate
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

-- Chair seat (real Seat instance so Roblox handles the sit animation)
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

-- Barrel pivot (where the barrel rotates from)
local pivot = anchoredPart("BarrelPivot",
    Vector3.new(0.5, 0.5, 0.5),
    CFrame.new(cx, cy + 2.0, cz - 1.2),
    NEON, Enum.Material.Neon, model)
pivot.CanCollide = false

-- Barrel
local barrel = anchoredPart("Barrel",
    Vector3.new(0.28, 0.28, 5),
    CFrame.new(cx, cy + 2.0, cz - 3.7),
    METAL, Enum.Material.Metal, model)

-- Barrel tip (neon, where beam fires from)
local tip = anchoredPart("BarrelTip",
    Vector3.new(0.38, 0.38, 0.2),
    CFrame.new(cx, cy + 2.0, cz - 6.2),
    Color3.fromRGB(0, 230, 120), Enum.Material.Neon, model)
tip.CanCollide = false

-- Eye point — camera anchors here when seated
local eye = Instance.new("Part")
eye.Name         = "EyePoint"
eye.Size         = Vector3.new(0.1, 0.1, 0.1)
eye.CFrame       = CFrame.new(cx, cy + 2.8, cz + 0.2)
eye.Anchored     = true
eye.CanCollide   = false
eye.Transparency = 1
eye.Parent       = model

-- ── ProximityPrompt ──────────────────────────────────────────────────────────

local prompt = Instance.new("ProximityPrompt")
prompt.ActionText             = "Man Turret"
prompt.ObjectText             = "Gunner Seat"
prompt.KeyboardKeyCode        = Enum.KeyCode.E
prompt.HoldDuration           = 0
prompt.MaxActivationDistance  = 8
prompt.Parent                 = base

prompt.Triggered:Connect(function(player)
    if seat.Occupant then return end
    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum then seat:Sit(hum) end
end)

-- Disable prompt while occupied so E doesn't re-trigger
seat:GetPropertyChangedSignal("Occupant"):Connect(function()
    prompt.Enabled = seat.Occupant == nil
end)

model.PrimaryPart = base
print("[SkyBase] Turret ready")
