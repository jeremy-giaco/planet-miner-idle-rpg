-- World/Server/SurfaceDecor.server.lua
-- Scatters real mesh models (rocks, asteroids, boulders) across the planet surface.
-- Templates must be placed manually in ReplicatedStorage → RockTemplates folder
-- in Studio (drag from Toolbox). This script clones them at runtime.

if not game:GetService("RunService"):IsServer() then return end
if _G._SurfaceDecorActive then return end
_G._SurfaceDecorActive = true

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config           = require(ReplicatedStorage:WaitForChild("Config"))

local PC = Config.PLANET_CENTER
local R  = Config.PLANET_RADIUS
local rng = Random.new(98765)

local EXCLUSION_ANGLE = math.rad(20)   -- keep north-pole base area clear

local folder = Instance.new("Folder")
folder.Name   = "SurfaceDecor"
folder.Parent = workspace

-- ── Template folder ───────────────────────────────────────────────────────────
-- In Studio: View → Toolbox → search by name/ID → drag models into
-- ReplicatedStorage → RockTemplates.  Any model/part in that folder is fair game.

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function rn(a, b) return a + rng:NextNumber() * (b - a) end
local function ri(a, b) return math.floor(rn(a, b + 1)) end

-- Random surface position outside the base exclusion zone
local function rpos()
    return EXCLUSION_ANGLE + rng:NextNumber() * (math.pi * 0.72),
           rng:NextNumber() * math.pi * 2
end

-- Surface-aligned CFrame at (phi, theta), heightAbove studs off surface
local function surfCF(phi, theta, heightAbove, yaw)
    local nx = math.sin(phi) * math.cos(theta)
    local ny = math.cos(phi)
    local nz = math.sin(phi) * math.sin(theta)
    local n   = Vector3.new(nx, ny, nz)
    local pos = PC + n * (R + (heightAbove or 0))
    local ref = math.abs(n.Y) < 0.9 and Vector3.new(0,1,0) or Vector3.new(1,0,0)
    local r   = n:Cross(ref).Unit
    local f   = r:Cross(n).Unit
    return CFrame.fromMatrix(pos, r, n, -f) * CFrame.Angles(0, yaw or 0, 0)
end

-- Strip all scripts, sounds, particles, lights, and anchor all parts
local function finalizeModel(model)
    local toRemove = {}
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored   = true
            d.CanCollide = true
            d.CastShadow = false
        elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript")
            or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
            or d:IsA("Sound") or d:IsA("PointLight") or d:IsA("SpotLight")
            or d:IsA("SurfaceLight") or d:IsA("SelectionBox") or d:IsA("BillboardGui")
            or d:IsA("ScreenGui") or d:IsA("Attachment") then
            table.insert(toRemove, d)
        end
    end
    for _, d in ipairs(toRemove) do
        pcall(function() d:Destroy() end)
    end
end

-- Normalize a model to fit within targetSize studs on its longest axis
local TARGET_MIN = 8    -- smallest rocks ~8 studs
local TARGET_MAX = 35   -- biggest boulders ~35 studs

local function normalizeScale(model)
    if not model:IsA("Model") then return end
    local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
    if not ok or not size then return end
    local longest = math.max(size.X, size.Y, size.Z)
    if longest <= 0 then return end
    -- Pick a random target size in our range
    local target = rn(TARGET_MIN, TARGET_MAX)
    -- 8% chance of a large hero boulder
    if rng:NextNumber() < 0.08 then target = rn(40, 80) end
    local scaleFactor = target / longest
    pcall(function() model:ScaleTo(scaleFactor) end)
end

-- ── Load templates from ReplicatedStorage ────────────────────────────────────

local templateFolder = ReplicatedStorage:FindFirstChild("objects")
if not templateFolder then
    warn("[SurfaceDecor] ReplicatedStorage.objects not found — add models in Studio first")
    return
end

local templates = templateFolder:GetChildren()
if #templates == 0 then
    warn("[SurfaceDecor] objects folder is empty — drag Toolbox models in first")
    return
end

print(string.format("[SurfaceDecor] %d templates found in objects", #templates))

-- ── Scatter ───────────────────────────────────────────────────────────────────

local SCATTER_COUNT = 300   -- total rocks/boulders across the surface

local function placeOne()
    local phi, theta = rpos()

    -- Random lean/tilt — looks like it landed or settled naturally
    local tilt    = rn(0, 0.3)
    local tiltDir = rn(0, math.pi * 2)
    local yaw     = rn(0, math.pi * 2)

    local template = templates[ri(1, #templates)]
    local model    = template:Clone()

    -- Normalize to a consistent size range before placing
    normalizeScale(model)

    -- Get bounding box after scaling to compute embed depth
    local embedDepth = 2
    if model:IsA("Model") then
        local ok, _, size = pcall(function() return model:GetBoundingBox() end)
        if ok and size then
            embedDepth = math.max(size.Y * rn(0.1, 0.3), 1)
        end
    end

    local cf = surfCF(phi, theta, -embedDepth, yaw)
             * CFrame.Angles(tilt * math.cos(tiltDir), 0, tilt * math.sin(tiltDir))

    if model:IsA("Model") then
        finalizeModel(model)
        model:PivotTo(cf)
    else
        model.CFrame     = cf
        model.Anchored   = true
        model.CanCollide = true
        model.CastShadow = false
    end

    model.Parent = folder
end

task.spawn(function()
    for i = 1, SCATTER_COUNT do
        local ok, err = pcall(placeOne)
        if not ok then
            warn("[SurfaceDecor] placeOne failed: " .. tostring(err))
        end
        if i % 20 == 0 then task.wait() end  -- yield every 20 to stay responsive
    end
    print(string.format("[SurfaceDecor] Done — %d features placed", SCATTER_COUNT))
end)
