-- LocalScript → StarterCharacterScripts
-- Attaches visible spacesuit parts: visor, helmet rim, shoulder pads, antenna.
-- Suit body colors are applied server-side in Character/Server/Spacesuit.server.lua

local character = script.Parent
local humanoid  = character:WaitForChild("Humanoid") -- luacheck: ignore

local SUIT_MID  = Color3.fromRGB(50, 62, 90)
local VISOR_COL = Color3.fromRGB(80, 180, 255)
local GLOVE_COL = Color3.fromRGB(22, 28, 45)

-- ── Helmet visor (Part welded to head) ───────────────────────────────────────

local head = character:WaitForChild("Head")

-- Visor glass
local visor = Instance.new("Part")
visor.Name        = "Visor"
visor.Size        = Vector3.new(1.05, 0.55, 0.3)
visor.CFrame      = head.CFrame * CFrame.new(0, 0.05, -0.52)
visor.Anchored    = false
visor.CanCollide  = false
visor.CastShadow  = false
visor.Material    = Enum.Material.Glass
visor.Color       = VISOR_COL
visor.Transparency = 0.25
visor.Parent      = character

local visorWeld = Instance.new("WeldConstraint")
visorWeld.Part0 = head; visorWeld.Part1 = visor; visorWeld.Parent = visor

-- Visor inner glow
local visorLight = Instance.new("PointLight")
visorLight.Color      = VISOR_COL
visorLight.Brightness = 0.8
visorLight.Range      = 6
visorLight.Parent     = visor

-- Helmet rim (dark band around head)
local rim = Instance.new("Part")
rim.Name        = "HelmetRim"
rim.Size        = Vector3.new(1.15, 0.18, 1.15)
rim.CFrame      = head.CFrame * CFrame.new(0, -0.3, 0)
rim.Anchored    = false
rim.CanCollide  = false
rim.CastShadow  = false
rim.Material    = Enum.Material.SmoothPlastic
rim.Color       = GLOVE_COL
rim.Parent      = character

local rimWeld = Instance.new("WeldConstraint")
rimWeld.Part0 = head; rimWeld.Part1 = rim; rimWeld.Parent = rim

-- Top antenna nub
local antenna = Instance.new("Part")
antenna.Name       = "Antenna"
antenna.Size       = Vector3.new(0.08, 0.22, 0.08)
antenna.CFrame     = head.CFrame * CFrame.new(0.3, 0.62, 0)
antenna.Anchored   = false
antenna.CanCollide = false
antenna.CastShadow = false
antenna.Material   = Enum.Material.Neon
antenna.Color      = VISOR_COL
antenna.Parent     = character

local antWeld = Instance.new("WeldConstraint")
antWeld.Part0 = head; antWeld.Part1 = antenna; antWeld.Parent = antenna

-- Shoulder pads
local function shoulderPad(side)
    local arm = character:WaitForChild(side .. "UpperArm")
    local pad = Instance.new("Part")
    pad.Name       = side .. "ShoulderPad"
    pad.Size       = Vector3.new(0.55, 0.3, 0.65)
    pad.CFrame     = arm.CFrame * CFrame.new(side == "Left" and -0.18 or 0.18, 0.25, 0)
    pad.Anchored   = false
    pad.CanCollide = false
    pad.CastShadow = false
    pad.Material   = Enum.Material.SmoothPlastic
    pad.Color      = SUIT_MID
    pad.Parent     = character
    local w = Instance.new("WeldConstraint")
    w.Part0 = arm; w.Part1 = pad; w.Parent = pad
end

shoulderPad("Left")
shoulderPad("Right")

print("[Spacesuit] Applied")
