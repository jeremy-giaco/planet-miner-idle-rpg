-- LocalScript → inside Laser Tool
-- Builds a futuristic rifle model welded to the Handle.
-- Runs once on equip; parts are destroyed when tool is unequipped.
if not game:GetService("RunService"):IsClient() then return end

local tool   = script.Parent
local handle = tool:WaitForChild("Handle")

local BODY_COL   = Color3.fromRGB(28, 32, 52)    -- dark hull
local ACCENT_COL = Color3.fromRGB(50, 55, 85)    -- mid panels
local NEON_COL   = Color3.fromRGB(255, 30, 30)   -- red hot neon (matches laser)
local GRIP_COL   = Color3.fromRGB(18, 18, 28)    -- grip rubber

-- Force handle appearance (Rojo property overrides can be unreliable in-place)
handle.Color        = BODY_COL
handle.Material     = Enum.Material.Metal
handle.Transparency = 0
handle.CastShadow   = false

local parts = {}

local function wp(size, offset, color, mat, trans)
    local p = Instance.new("Part")
    p.Size         = size
    p.CFrame       = handle.CFrame * CFrame.new(offset)
    p.Color        = color
    p.Material     = mat or Enum.Material.Metal
    p.Transparency = trans or 0
    p.CanCollide   = false
    p.CastShadow   = false
    p.Anchored     = false
    p.Parent       = tool
    local w = Instance.new("WeldConstraint")
    w.Part0 = handle; w.Part1 = p; w.Parent = p
    table.insert(parts, p)
    return p
end

local function light(parent, color, brightness, range)
    local l = Instance.new("PointLight")
    l.Color = color; l.Brightness = brightness; l.Range = range
    l.Parent = parent
    table.insert(parts, l)
end

local function buildGun()
    -- Main receiver body
    wp(Vector3.new(0.22, 0.28, 1.4),  Vector3.new(0,  0.04,  0),    BODY_COL)
    -- Top rail
    wp(Vector3.new(0.08, 0.06, 1.3),  Vector3.new(0,  0.2,   0),    ACCENT_COL)
    -- Barrel extension
    wp(Vector3.new(0.11, 0.11, 0.7),  Vector3.new(0,  0.04,  1.0),  BODY_COL)
    -- Barrel tip neon ring
    local tip = wp(Vector3.new(0.14, 0.14, 0.06), Vector3.new(0, 0.04, 1.38), NEON_COL, Enum.Material.Neon)
    light(tip, NEON_COL, 3, 12)
    -- Expose barrel tip so LaserGun can read its world position
    local tipRef = tool:FindFirstChild("BarrelTip") or Instance.new("ObjectValue")
    tipRef.Name  = "BarrelTip"
    tipRef.Value = tip
    tipRef.Parent = tool
    table.insert(parts, tipRef)
    -- Side vents (left & right)
    wp(Vector3.new(0.04, 0.12, 0.5),  Vector3.new( 0.13, 0.04, 0.1), ACCENT_COL)
    wp(Vector3.new(0.04, 0.12, 0.5),  Vector3.new(-0.13, 0.04, 0.1), ACCENT_COL)
    -- Neon vent strips
    local ventL = wp(Vector3.new(0.03, 0.04, 0.42), Vector3.new( 0.14, 0.04, 0.1), NEON_COL, Enum.Material.Neon)
    local ventR = wp(Vector3.new(0.03, 0.04, 0.42), Vector3.new(-0.14, 0.04, 0.1), NEON_COL, Enum.Material.Neon)
    light(ventL, NEON_COL, 0.8, 6)
    light(ventR, NEON_COL, 0.8, 6)
    -- Grip
    wp(Vector3.new(0.16, 0.38, 0.2),  Vector3.new(0, -0.22, -0.35), GRIP_COL)
    -- Trigger guard
    wp(Vector3.new(0.05, 0.12, 0.22), Vector3.new(0, -0.08, -0.1),  ACCENT_COL)
    -- Stock
    wp(Vector3.new(0.14, 0.18, 0.4),  Vector3.new(0,  0.02, -0.9),  BODY_COL)
    wp(Vector3.new(0.14, 0.08, 0.3),  Vector3.new(0, -0.07, -1.0),  ACCENT_COL)
    -- Scope
    wp(Vector3.new(0.09, 0.09, 0.38), Vector3.new(0,  0.28,  0.18), BODY_COL)
    wp(Vector3.new(0.07, 0.07, 0.06), Vector3.new(0,  0.28,  0.38), NEON_COL, Enum.Material.Neon)
    -- Energy cell (glowing magazine)
    local cell = wp(Vector3.new(0.1, 0.22, 0.12), Vector3.new(0, -0.14, 0.2), NEON_COL, Enum.Material.Neon, 0.5)
    light(cell, NEON_COL, 1.5, 8)
end

local built = false

local function destroyGun()
    for _, p in ipairs(parts) do
        if p and p.Parent then p:Destroy() end
    end
    parts = {}
    built = false
end

local function safeBuild()
    if built then return end
    built = true
    task.wait()   -- let handle CFrame settle before welding
    buildGun()
end

tool.Equipped:Connect(safeBuild)

tool.Unequipped:Connect(function()
    destroyGun()
end)

-- Build immediately if already equipped when script starts
if tool.Parent and tool.Parent:FindFirstChildOfClass("Humanoid") then
    safeBuild()
end
