-- LocalScript → inside the MiningBeam Tool in StarterPack
-- Hold LMB to fire a wide mining beam from the character toward the cursor.
-- Damages all debris in the beam volume each BEAM_COOLDOWN seconds.

local RunService        = game:GetService("RunService")
if not RunService:IsClient() then return end
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local player     = Players.LocalPlayer
local camera     = workspace.CurrentCamera
local tool       = script.Parent
local playerGui  = player:WaitForChild("PlayerGui")

local Config         = require(ReplicatedStorage:WaitForChild("Config"))
local remotes        = ReplicatedStorage:WaitForChild("Remotes")
local hitDebrisEvent = remotes:WaitForChild("HitDebris")
local debrisFolder   = workspace:WaitForChild("Debris")

local BEAM_RANGE    = 300
local BEAM_COOLDOWN = 0.3
local BEAM_WIDTH    = 8      -- studs wide (horizontal sweep)
local BEAM_COL      = Color3.fromRGB(0, 220, 255)
local GLOW_COL      = Color3.fromRGB(80, 180, 255)

local equipped  = false
local firing    = false
local beamTimer = 0

-- ── Beam visual (Beam object between two attachments) ─────────────────────────

local beamOrigin     = nil   -- Part at character chest
local beamEndAnchor  = nil   -- invisible anchor at aim point
local beamObj        = nil
local beamGlow       = nil
local beamLight      = nil

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

local function buildBeam()
    local character = player.Character
    if not character then return end
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    if not torso then return end

    -- Origin attachment on torso
    beamOrigin = Instance.new("Part")
    beamOrigin.Size = Vector3.new(0.1, 0.1, 0.1)
    beamOrigin.Transparency = 1; beamOrigin.CanCollide = false
    beamOrigin.Anchored = false; beamOrigin.Parent = character
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = torso; weld.Part1 = beamOrigin; weld.Parent = beamOrigin

    local att0 = Instance.new("Attachment"); att0.Parent = beamOrigin

    -- End anchor (floats in world space, moved each frame)
    beamEndAnchor = Instance.new("Part")
    beamEndAnchor.Size = Vector3.new(0.1, 0.1, 0.1)
    beamEndAnchor.Transparency = 1; beamEndAnchor.CanCollide = false
    beamEndAnchor.Anchored = true; beamEndAnchor.Parent = workspace
    local att1 = Instance.new("Attachment"); att1.Parent = beamEndAnchor

    -- Core beam
    beamObj = Instance.new("Beam")
    beamObj.Attachment0    = att0
    beamObj.Attachment1    = att1
    beamObj.Width0         = BEAM_WIDTH
    beamObj.Width1         = BEAM_WIDTH * 0.3
    beamObj.LightEmission  = 1
    beamObj.LightInfluence = 0
    beamObj.Color          = ColorSequence.new({
        ColorSequenceKeypoint.new(0, BEAM_COL),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 240, 255)),
    })
    beamObj.Transparency   = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 0.6),
    })
    beamObj.Segments   = 1
    beamObj.FaceCamera = false
    beamObj.Enabled    = false
    beamObj.Parent     = workspace

    -- Glow halo
    beamGlow = Instance.new("Beam")
    beamGlow.Attachment0    = att0
    beamGlow.Attachment1    = att1
    beamGlow.Width0         = BEAM_WIDTH * 2
    beamGlow.Width1         = BEAM_WIDTH * 0.6
    beamGlow.LightEmission  = 1
    beamGlow.LightInfluence = 0
    beamGlow.Color          = ColorSequence.new(GLOW_COL)
    beamGlow.Transparency   = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.7),
        NumberSequenceKeypoint.new(1, 1),
    })
    beamGlow.Segments   = 1
    beamGlow.FaceCamera = false
    beamGlow.Enabled    = false
    beamGlow.Parent     = workspace

    -- Light that travels with beam midpoint
    beamLight = Instance.new("PointLight")
    beamLight.Color = BEAM_COL; beamLight.Brightness = 6; beamLight.Range = 40
    beamLight.Enabled = false
    beamLight.Parent = beamOrigin
end

local function destroyBeam()
    if beamObj        then beamObj:Destroy();        beamObj        = nil end
    if beamGlow       then beamGlow:Destroy();       beamGlow       = nil end
    if beamOrigin     then beamOrigin:Destroy();     beamOrigin     = nil end
    if beamEndAnchor  then beamEndAnchor:Destroy();  beamEndAnchor  = nil end
    beamLight = nil
end

-- ── Aim helpers ───────────────────────────────────────────────────────────────

local function getAimPos()
    local mouse  = player:GetMouse()
    local camRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
    -- Aim at whatever the cursor hits, or project far into space
    local aimParams = RaycastParams.new()
    aimParams.FilterType = Enum.RaycastFilterType.Exclude
    aimParams.FilterDescendantsInstances = { player.Character }
    local result = workspace:Raycast(camRay.Origin, camRay.Direction * BEAM_RANGE, aimParams)
    return result and result.Position or (camRay.Origin + camRay.Direction * BEAM_RANGE),
           camRay.Direction
end

-- ── Damage: blockcast along beam volume ───────────────────────────────────────

local function damageBeam(camDir)
    local origin = beamOrigin and beamOrigin.Position
    if not origin then return end

    -- Cast full beam range in camera direction, ignoring ground
    local castLen  = BEAM_RANGE
    local endpoint = origin + camDir * castLen
    local beamCF   = CFrame.lookAt(origin, endpoint) * CFrame.new(0, 0, -castLen / 2)
    local beamSize  = Vector3.new(BEAM_WIDTH, BEAM_WIDTH * 0.5, castLen)

    local hits = workspace:GetPartBoundsInBox(beamCF, beamSize, overlapParams)
    local seen  = {}
    for _, part in ipairs(hits) do
        local inst = part
        while inst and not inst:GetAttribute("IsDebris") do
            inst = inst.Parent
        end
        if inst and inst:GetAttribute("IsDebris") and not seen[inst] then
            seen[inst] = true
            hitDebrisEvent:FireServer(inst)
        end
    end
end

-- ── Main loop ─────────────────────────────────────────────────────────────────

local renderConn

local function startFiring()
    if renderConn then return end
    renderConn = RunService.RenderStepped:Connect(function(dt)
        if not firing or not beamObj then return end

        local aimPos, camDir = getAimPos()
        beamEndAnchor.Position = aimPos

        beamObj.Enabled   = true
        beamGlow.Enabled  = true
        beamLight.Enabled = true

        beamTimer = beamTimer - dt
        if beamTimer <= 0 then
            damageBeam(camDir)
            beamTimer = BEAM_COOLDOWN
        end
    end)
end

local function stopFiring()
    firing = false
    if beamObj        then beamObj.Enabled   = false end
    if beamGlow       then beamGlow.Enabled  = false end
    if beamLight      then beamLight.Enabled = false end
end

-- ── Tool connections ──────────────────────────────────────────────────────────

tool.Equipped:Connect(function()
    equipped = true
    -- Set debris filter now that folder is guaranteed to exist
    overlapParams.FilterDescendantsInstances = {workspace:WaitForChild("Debris")}
    buildBeam()
    startFiring()
end)

tool.Unequipped:Connect(function()
    equipped = false
    firing = false
    stopFiring()
    if renderConn then renderConn:Disconnect(); renderConn = nil end
    destroyBeam()
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or not equipped then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        firing = true
        beamTimer = 0
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        stopFiring()
    end
end)
