-- World/Server/SurfaceDecor.server.lua
-- Scatters real mesh models (rocks, asteroids, boulders) across the planet surface.
-- Models are loaded from the Roblox Creator Store via InsertService, then cloned,
-- scaled, randomly rotated, and placed flush with the sphere surface.

if not game:GetService("RunService"):IsServer() then return end
if _G._SurfaceDecorActive then return end
_G._SurfaceDecorActive = true

local InsertService    = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config           = require(ReplicatedStorage:WaitForChild("Config"))

local PC = Config.PLANET_CENTER
local R  = Config.PLANET_RADIUS
local rng = Random.new(98765)

local EXCLUSION_ANGLE = math.rad(20)   -- keep north-pole base area clear

local folder = Instance.new("Folder")
folder.Name   = "SurfaceDecor"
folder.Parent = workspace

-- ── Asset IDs ─────────────────────────────────────────────────────────────────
-- Free Creator Store models selected by the user.
-- Mix of asteroid rocks, boulders, mineral chunks, alien formations.
local ASSET_IDS = {
    124679136030955,
    104255070586802,
    104331582218001,
    126997999714585,
    18264896943,
    122914102246073,
    102475743881757,
    81642219399552,
    4776164961,
    3637979087,
    73562988443438,
    11896342858,
    7973780306,
    85471893867855,
    15359965253,
    107261160523126,
    258794641,
    15876671760,
    8021078503,
    74299985742800,
    2655317176,
    103760903802024,
    118226550971856,
    13519873434,
    120624064750029,
    135086947258395,
    5606182405,
    16515639712,
}

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

-- Anchor all BaseParts in a model and strip scripts
local function finalizeModel(model)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored   = true
            d.CanCollide = true
            d.CastShadow = false
        elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
            d:Destroy()
        end
    end
end

-- ── Load templates ────────────────────────────────────────────────────────────

local templates = {}

print("[SurfaceDecor] Loading mesh templates...")

for _, id in ipairs(ASSET_IDS) do
    local ok, result = pcall(function()
        return InsertService:LoadAsset(id)
    end)
    if ok and result then
        -- LoadAsset returns a Model container; grab the first child Model inside
        local child = result:FindFirstChildWhichIsA("Model")
                   or result:FindFirstChildWhichIsA("MeshPart")
                   or result:FindFirstChildWhichIsA("Part")
        if child then
            child.Parent = nil
            table.insert(templates, child)
            print(string.format("[SurfaceDecor] Loaded asset %d → %s", id, child.Name))
        else
            -- Some assets ARE the model directly
            result.Parent = nil
            table.insert(templates, result)
            print(string.format("[SurfaceDecor] Loaded asset %d → %s (root)", id, result.Name))
        end
    else
        warn(string.format("[SurfaceDecor] Failed to load asset %d: %s", id, tostring(result)))
    end
    task.wait()   -- yield between loads to avoid throttling
end

print(string.format("[SurfaceDecor] %d/%d templates loaded", #templates, #ASSET_IDS))

if #templates == 0 then
    warn("[SurfaceDecor] No templates loaded — aborting scatter")
    return
end

-- ── Scatter ───────────────────────────────────────────────────────────────────

local SCATTER_COUNT = 300   -- total rocks/boulders across the surface

local function placeOne()
    local phi, theta = rpos()

    -- Random scale: most are small, occasional large boulders
    local scale = rn(0.3, 1.0)
    if rng:NextNumber() < 0.08 then scale = rn(1.5, 3.5) end  -- 8% chance big boulder

    -- Random lean/tilt — looks like it landed or grew from rock
    local tilt = rn(0, 0.35)
    local tiltDir = rn(0, math.pi * 2)
    local yaw = rn(0, math.pi * 2)

    -- Sink slightly into surface so it looks embedded, not floating
    local embed = -scale * rn(0.1, 0.4)

    local cf = surfCF(phi, theta, embed, yaw)
             * CFrame.Angles(tilt * math.cos(tiltDir), 0, tilt * math.sin(tiltDir))

    local template = templates[ri(1, #templates)]
    local model = template:Clone()

    -- Scale uniformly
    if model:IsA("Model") then
        local ok = pcall(function() model:ScaleTo(scale) end)
        if not ok then
            -- Fallback: scale each part manually
            for _, p in ipairs(model:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.Size = p.Size * scale
                end
            end
        end
        finalizeModel(model)
        model:PivotTo(cf)
    else
        -- Single part (MeshPart / Part)
        model.Size    = model.Size * scale
        model.CFrame  = cf
        model.Anchored   = true
        model.CanCollide = true
        model.CastShadow = false
        if model:IsA("Script") or model:IsA("LocalScript") then
            model:Destroy()
            return
        end
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
