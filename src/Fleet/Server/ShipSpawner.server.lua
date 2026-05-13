-- ServerScript → ServerScriptService
-- Spawns a personal ship inside the hangar for each player.
-- Animates hangar blast door on enter/exit.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage:WaitForChild("Config"))

local R  = Config.PLANET_RADIUS
local PC = Config.PLANET_CENTER

local shipsFolder = Instance.new("Folder")
shipsFolder.Name   = "PlayerShips"
shipsFolder.Parent = workspace

-- Wait for hangar to be built by GameSetup/WorldGen
local hangarFolder = workspace:WaitForChild("Hangar", 30)
local bayDoor      = hangarFolder and hangarFolder:WaitForChild("BayDoor", 10)

local doorClosedY = bayDoor and bayDoor:GetAttribute("ClosedY") or (R + 718)
local doorOpenY   = bayDoor and bayDoor:GetAttribute("OpenY")   or (R + 760)

local doorTween = TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local function setDoor(open)
    if not bayDoor then return end
    local targetY = open and doorOpenY or doorClosedY
    TweenService:Create(bayDoor, doorTween, { Position = Vector3.new(bayDoor.Position.X, targetY, bayDoor.Position.Z) }):Play()
    -- Also move the neon bands with it
    for _, band in ipairs(hangarFolder:GetChildren()) do
        if band.Name:sub(1,8) == "DoorBand" then
            local dy = open and (doorOpenY - doorClosedY) or (doorClosedY - doorOpenY)
            TweenService:Create(band, doorTween, { Position = band.Position + Vector3.new(0, dy, 0) }):Play()
        end
    end
end

local function spawnShip(player)
    -- Spawn inside hangar center, just above floor
    -- Hangar floor Y = PLANET_RADIUS + 3 (floor thickness), center Z = northZ - HD/2
    local northZ   = PC.Z - (Config.PLANET_RADIUS)   -- approximate: base sits at R, north wall at Z = -100
    -- Use fixed hangar center offset from Config values
    local hangarCenterZ = PC.Z - 100 - 27   -- northZ -100, centre of 55-deep hangar = -127.5
    local shipPos = Vector3.new(PC.X, R + 15, hangarCenterZ)

    local ship = Instance.new("Model")
    ship.Name   = player.Name .. "_Ship"
    ship.Parent = shipsFolder

    -- ── Colour palette ────────────────────────────────────────────────────────
    local HULL_COL  = Color3.fromRGB(35,  45,  75)
    local DARK_COL  = Color3.fromRGB(22,  30,  52)
    local ENG_COL   = Color3.fromRGB(80, 180, 255)
    local HOVER_COL = Color3.fromRGB(50, 110, 255)
    local GLASS_COL = Color3.fromRGB(150, 215, 255)

    -- ── Root part ─────────────────────────────────────────────────────────────
    local root = Instance.new("Part")
    root.Name       = "ShipRoot"
    root.Size       = Vector3.new(13, 2, 7)
    root.CFrame     = CFrame.new(shipPos)
    root.Anchored   = true
    root.CanCollide = true
    root.Color      = HULL_COL
    root.Material   = Enum.Material.Metal
    root.CastShadow = false
    root.Parent     = ship
    ship.PrimaryPart = root

    -- ── Weld helper ───────────────────────────────────────────────────────────
    local function wp(size, off, color, mat, trans)
        local p = Instance.new("Part")
        p.Size         = size
        p.CFrame       = root.CFrame * CFrame.new(off)
        p.Anchored     = false
        p.CanCollide   = false
        p.CastShadow   = false
        p.Color        = color
        p.Material     = mat or Enum.Material.Metal
        p.Transparency = trans or 0
        p.Parent       = ship
        local w = Instance.new("WeldConstraint")
        w.Part0 = root; w.Part1 = p; w.Parent = p
        return p
    end

    local function addLight(parent, color, brightness, range)
        local l = Instance.new("PointLight")
        l.Color = color; l.Brightness = brightness; l.Range = range
        l.Parent = parent
    end

    -- ── Hull body ─────────────────────────────────────────────────────────────
    wp(Vector3.new(13, 2, 7),    Vector3.new(0, -1.8, 0),    HULL_COL)   -- lower hull
    wp(Vector3.new(7,  1.4, 5),  Vector3.new(0,  0.7, -0.5), DARK_COL)   -- upper spine
    -- Nose
    wp(Vector3.new(4,  1.8, 5.5),Vector3.new(0, -0.1, -5.5), DARK_COL)
    wp(Vector3.new(2,  1.4, 3),  Vector3.new(0,  0.2, -7.8), DARK_COL)

    -- ── Cockpit glass ─────────────────────────────────────────────────────────
    local cockpit = wp(Vector3.new(4.2, 2.2, 4.5), Vector3.new(0, 1.5, -2.5),
        GLASS_COL, Enum.Material.Glass, 0.18)
    addLight(cockpit, GLASS_COL, 0.6, 12)

    -- ── Wings ─────────────────────────────────────────────────────────────────
    wp(Vector3.new(8, 0.35, 4.5), Vector3.new(-9,  -1.6,  1), DARK_COL)  -- left wing
    wp(Vector3.new(8, 0.35, 4.5), Vector3.new( 9,  -1.6,  1), DARK_COL)  -- right wing
    -- Wing tips
    wp(Vector3.new(2.5, 0.25, 2), Vector3.new(-13.5, -1.5, 1), HULL_COL)
    wp(Vector3.new(2.5, 0.25, 2), Vector3.new( 13.5, -1.5, 1), HULL_COL)
    -- Wing neon accent strips
    local wL = wp(Vector3.new(7.5, 0.12, 0.25), Vector3.new(-9, -1.35, 3), ENG_COL, Enum.Material.Neon, 0)
    local wR = wp(Vector3.new(7.5, 0.12, 0.25), Vector3.new( 9, -1.35, 3), ENG_COL, Enum.Material.Neon, 0)
    addLight(wL, ENG_COL, 1.5, 18)
    addLight(wR, ENG_COL, 1.5, 18)

    -- ── Rear engines ──────────────────────────────────────────────────────────
    wp(Vector3.new(2.2, 2,   2.5), Vector3.new(-3.5, -1.4, 4.5), DARK_COL)
    wp(Vector3.new(2.2, 2,   2.5), Vector3.new( 3.5, -1.4, 4.5), DARK_COL)
    local eL = wp(Vector3.new(1.8, 1.8, 0.5), Vector3.new(-3.5, -1.4, 5.85), ENG_COL, Enum.Material.Neon)
    local eR = wp(Vector3.new(1.8, 1.8, 0.5), Vector3.new( 3.5, -1.4, 5.85), ENG_COL, Enum.Material.Neon)
    addLight(eL, ENG_COL, 5, 24)
    addLight(eR, ENG_COL, 5, 24)

    -- ── Underbelly hover plate ─────────────────────────────────────────────────
    local hover = wp(Vector3.new(12.5, 0.2, 6.5), Vector3.new(0, -2.75, 0),
        HOVER_COL, Enum.Material.Neon, 0.3)
    addLight(hover, HOVER_COL, 2, 18)

    -- ── Billboard label ───────────────────────────────────────────────────────
    local bb = Instance.new("BillboardGui")
    bb.Size        = UDim2.new(0, 140, 0, 44)
    bb.StudsOffset = Vector3.new(0, 6, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 600
    bb.Parent      = root
    local bbl = Instance.new("TextLabel")
    bbl.Size = UDim2.new(1,0,1,0); bbl.BackgroundTransparency = 1
    bbl.Text = "▶ YOUR SHIP"; bbl.TextColor3 = ENG_COL
    bbl.Font = Enum.Font.GothamBold; bbl.TextSize = 16
    bbl.Parent = bb

    -- ── Owner tag ─────────────────────────────────────────────────────────────
    local ownerTag = Instance.new("StringValue")
    ownerTag.Name  = "Owner"; ownerTag.Value = player.Name; ownerTag.Parent = ship

    -- ── ProximityPrompt ───────────────────────────────────────────────────────
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText           = "Enter Ship"
    prompt.ObjectText           = "Ship"
    prompt.KeyboardKeyCode      = Enum.KeyCode.E
    prompt.HoldDuration         = 0
    prompt.RequiresLineOfSight  = false
    prompt.MaxActivationDistance = 40
    prompt.Parent               = root

    -- ── Door logic (server-side) ──────────────────────────────────────────────
    local inShip = false
    prompt.Triggered:Connect(function()
        inShip = not inShip
        setDoor(inShip)
        prompt.ActionText = inShip and "Exit Ship" or "Enter Ship"
        if not inShip then
            -- Player exited — server reclaims authority, re-anchors, restores collision
            pcall(function() root:SetNetworkOwner(nil) end)
            root.CanCollide = true
            root.Anchored   = true
        end
    end)

    return ship
end

local function removeShip(player)
    local ship = shipsFolder:FindFirstChild(player.Name .. "_Ship")
    if ship then ship:Destroy() end
end

Players.PlayerAdded:Connect(function(player)
    spawnShip(player)
    player.CharacterAdded:Connect(function()
        if not shipsFolder:FindFirstChild(player.Name .. "_Ship") then
            spawnShip(player)
        end
    end)
end)

Players.PlayerRemoving:Connect(removeShip)

for _, player in ipairs(Players:GetPlayers()) do
    spawnShip(player)
end

-- ── Recall console ────────────────────────────────────────────────────────────
-- Wire up the ProximityPrompt built by WorldGen inside the hangar.
-- Teleports the triggering player's ship back to the hangar home position.
task.spawn(function()
    local hangarCenterZ = PC.Z - 100 - 27
    local homePos = Vector3.new(PC.X, R + 15, hangarCenterZ)

    -- Find the prompt (it lives on the screen Part inside the Hangar folder)
    local hangar = workspace:WaitForChild("Hangar", 30)
    if not hangar then
        warn("[ShipSpawner] Hangar not found — recall console not wired")
        return
    end

    -- Find the RecallButton part and its ProximityPrompt
    local recallBtn    = hangar:FindFirstChild("RecallButton", true)
    local recallPrompt = recallBtn and recallBtn:FindFirstChildOfClass("ProximityPrompt")

    if not recallPrompt then
        warn("[ShipSpawner] Recall button not found in Hangar")
        return
    end

    recallPrompt.Triggered:Connect(function(player)
        local ship = shipsFolder:FindFirstChild(player.Name .. "_Ship")
        if not ship then return end
        local root = ship:FindFirstChild("ShipRoot")
        if not root then return end

        -- Don't recall if player is currently flying it
        local char = player.Character
        if char and char:FindFirstChild("InShip") then return end

        recallPrompt.Enabled = false

        -- Animate button press: push in then spring back
        local btnPart   = recallBtn
        local pressedCF = btnPart.CFrame * CFrame.new(0, 0, 0.35)   -- push INTO wall (local Z)
        local restCF    = btnPart.CFrame
        TweenService:Create(btnPart, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In),  { CFrame = pressedCF }):Play()
        task.wait(0.12)
        TweenService:Create(btnPart, TweenInfo.new(0.18, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { CFrame = restCF }):Play()
        task.wait(0.3)

        setDoor(true)
        task.wait(2)    -- door opens

        -- Reclaim server authority then anchor for tween
        pcall(function() root:SetNetworkOwner(nil) end)
        root.CanCollide = true
        root.Anchored   = true
        local tween = TweenService:Create(
            root,
            TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
            { CFrame = CFrame.new(homePos) }
        )
        tween:Play()
        tween.Completed:Wait()

        task.wait(20)   -- leave door open so player can walk in
        setDoor(false)
        task.wait(2)
        recallPrompt.Enabled = true
        print("[ShipSpawner] Recalled " .. player.Name .. "'s ship to hangar")
    end)

    print("[ShipSpawner] Recall console wired")
end)

print("[ShipSpawner] Active")
