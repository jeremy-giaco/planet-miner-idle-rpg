-- World/Server/SurfaceDecor.server.lua
-- Categorized surface scatter using real mesh models from ReplicatedStorage/objects.
-- Rocks/asteroids everywhere, gem clusters as ore deposits, sparse alien flora,
-- lava pools in the danger zones.

if not game:GetService("RunService"):IsServer() then return end
if _G._SurfaceDecorActive then return end
_G._SurfaceDecorActive = true

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage:WaitForChild("Config"))

local PC = Config.PLANET_CENTER
local R  = Config.PLANET_RADIUS
local rng = Random.new(98765)

local EXCLUSION_ANGLE = math.rad(20)   -- keep north-pole base area clear

local folder = Instance.new("Folder")
folder.Name   = "SurfaceDecor"
folder.Parent = workspace

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function rn(a, b) return a + rng:NextNumber() * (b - a) end
local function ri(a, b) return math.floor(rn(a, b + 1)) end

local function rpos()
    return EXCLUSION_ANGLE + rng:NextNumber() * (math.pi * 0.72),
           rng:NextNumber() * math.pi * 2
end

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

-- Strip scripts/particles/sounds/lights, anchor all parts
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
    for _, d in ipairs(toRemove) do pcall(function() d:Destroy() end) end
end

-- Scale model so its longest axis fits within [minSize, maxSize] studs
local function normalizeScale(model, minSize, maxSize, heroChance, heroMin, heroMax)
    if not model:IsA("Model") then return end
    local ok, _, size = pcall(function() return model:GetBoundingBox() end)
    if not ok or not size then return end
    local longest = math.max(size.X, size.Y, size.Z)
    if longest <= 0 then return end
    local target = rn(minSize, maxSize)
    if heroChance and rng:NextNumber() < heroChance then
        target = rn(heroMin, heroMax)
    end
    pcall(function() model:ScaleTo(target / longest) end)
end

-- Place a single model at a surface position with tilt/embed
local function placeModel(model, phi, theta, minSize, maxSize, heroChance, heroMin, heroMax, extraTilt)
    local clone = model:Clone()
    normalizeScale(clone, minSize, maxSize, heroChance, heroMin, heroMax)

    local tilt    = rn(0, extraTilt or 0.25)
    local tiltDir = rn(0, math.pi * 2)
    local yaw     = rn(0, math.pi * 2)

    local embedDepth = 2
    if clone:IsA("Model") then
        local ok, _, size = pcall(function() return clone:GetBoundingBox() end)
        if ok and size then embedDepth = math.max(size.Y * rn(0.1, 0.25), 1) end
    end

    local cf = surfCF(phi, theta, -embedDepth, yaw)
             * CFrame.Angles(tilt * math.cos(tiltDir), 0, tilt * math.sin(tiltDir))

    if clone:IsA("Model") then
        finalizeModel(clone)
        clone:PivotTo(cf)
    else
        clone.CFrame   = cf
        clone.Anchored = true
        clone.CanCollide = true
        clone.CastShadow = false
    end

    clone.Parent = folder
end

-- ── Categorize templates ─────────────────────────────────────────────────────

local templateFolder = ReplicatedStorage:FindFirstChild("objects")
if not templateFolder then
    warn("[SurfaceDecor] ReplicatedStorage.objects not found")
    return
end

local ROCKS = {}   -- boulders/asteroids scattered everywhere
local GEMS  = {}   -- crystal/gem ore deposits
local FLORA = {}   -- alien plants
local LAVA  = {}   -- lava pools (decorative)
local SKIP  = { Particles = true, Water = true }

local GEM_NAMES = {
    ["shadow gem"]=true, ["CrystalBlue"]=true, ["CrystalGreen"]=true,
    ["CrystalOrange"]=true, ["CrystalPink"]=true, ["CrystalWhite"]=true,
    ["CrystalYellow"]=true, ["CrystalBBlue"]=true, ["CrystalPurple"]=true,
    ["CrystalRed"]=true, ["Diamond"]=true, ["Enchanted Navy gemstone no sp"]=true,
    ["Crystals"]=true,
}
local FLORA_NAMES = { ["Alien Plant 2"]=true }
local LAVA_NAMES  = { ["Lava (kill brick)"]=true }
local ROCK_NAMES  = {
    ["Meteor by epic_noob144"]=true, ["Asteroid"]=true,
    ["Rock"]=true, ["MeshPart"]=true, ["Part"]=true,
}

for _, obj in ipairs(templateFolder:GetChildren()) do
    local name = obj.Name
    if SKIP[name] then
        -- ignore
    elseif GEM_NAMES[name] then
        table.insert(GEMS, obj)
    elseif FLORA_NAMES[name] then
        table.insert(FLORA, obj)
    elseif LAVA_NAMES[name] then
        table.insert(LAVA, obj)
    else
        -- Default: treat as rock (covers ROCK_NAMES and anything unrecognized)
        table.insert(ROCKS, obj)
    end
end

print(string.format("[SurfaceDecor] Rocks:%d  Gems:%d  Flora:%d  Lava:%d",
    #ROCKS, #GEMS, #FLORA, #LAVA))

if #ROCKS == 0 and #GEMS == 0 and #FLORA == 0 then
    warn("[SurfaceDecor] No usable templates — aborting")
    return
end

-- ── Scatter ───────────────────────────────────────────────────────────────────

task.spawn(function()
    local n = 0

    -- 1. ROCKS — 250 boulders/asteroids, varied sizes, all over surface
    if #ROCKS > 0 then
        for _ = 1, 250 do
            local phi, theta = rpos()
            local ok, err = pcall(placeModel,
                ROCKS[ri(1,#ROCKS)], phi, theta,
                6, 30,     -- normal size range
                0.07, 40, 70,  -- 7% hero boulders
                0.3)
            if not ok then warn("[SurfaceDecor] Rock: " .. tostring(err)) end
            n += 1
            if n % 25 == 0 then task.wait() end
        end
        print("[SurfaceDecor] Rocks placed")
    end

    -- 2. GEMS — 120 crystals in tight clusters of 2-5
    if #GEMS > 0 then
        for _ = 1, 30 do   -- 30 cluster centers
            local cphi, ctheta = rpos()
            local clusterSize = ri(2, 5)
            for _ = 1, clusterSize do
                -- Offset within ~15 studs of cluster center
                local spread = 15 / R
                local phi   = math.clamp(cphi   + rn(-spread, spread), 0.01, math.pi-0.01)
                local theta = ctheta + rn(-spread, spread)
                local ok, err = pcall(placeModel,
                    GEMS[ri(1,#GEMS)], phi, theta,
                    3, 10,    -- gems are smaller
                    0.05, 12, 18,
                    0.15)     -- less tilt, they grow upright
                if not ok then warn("[SurfaceDecor] Gem: " .. tostring(err)) end
                n += 1
                if n % 25 == 0 then task.wait() end
            end
        end
        print("[SurfaceDecor] Gems placed")
    end

    -- 3. FLORA — 50 alien plants, sparse
    if #FLORA > 0 then
        for _ = 1, 50 do
            local phi, theta = rpos()
            local ok, err = pcall(placeModel,
                FLORA[ri(1,#FLORA)], phi, theta,
                4, 14,
                0.05, 16, 22,
                0.1)   -- plants stand fairly upright
            if not ok then warn("[SurfaceDecor] Flora: " .. tostring(err)) end
            n += 1
            if n % 25 == 0 then task.wait() end
        end
        print("[SurfaceDecor] Flora placed")
    end

    -- 4. LAVA — 25 pools, sit flush with surface (no embed)
    if #LAVA > 0 then
        for _ = 1, 25 do
            local phi, theta = rpos()
            local clone = LAVA[ri(1,#LAVA)]:Clone()
            normalizeScale(clone, 15, 40, 0.1, 45, 70)
            local cf = surfCF(phi, theta, 0, rn(0, math.pi*2))
            if clone:IsA("Model") then
                -- Keep scripts for kill brick behavior
                for _, d in ipairs(clone:GetDescendants()) do
                    if d:IsA("BasePart") then
                        d.Anchored   = true
                        d.CastShadow = false
                    end
                end
                clone:PivotTo(cf)
            else
                clone.CFrame   = cf
                clone.Anchored = true
            end
            clone.Parent = folder
            n += 1
            if n % 25 == 0 then task.wait() end
        end
        print("[SurfaceDecor] Lava placed")
    end

    print(string.format("[SurfaceDecor] Done — %d total features placed", n))
end)
