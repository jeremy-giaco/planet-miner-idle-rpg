-- Core/Remotes.server.lua
-- Single source of truth for all RemoteEvents and BindableEvents.
-- Runs first (ServerScriptService, script priority handled by Rojo order).
-- All other scripts should WaitForChild on the Remotes folder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = Instance.new("Folder")
Remotes.Name   = "Remotes"
Remotes.Parent = ReplicatedStorage

local function remote(name)
    local r = Instance.new("RemoteEvent")
    r.Name   = name
    r.Parent = Remotes
    return r
end

local function bindable(name)
    local b = Instance.new("BindableEvent")
    b.Name   = name
    b.Parent = Remotes
    return b
end

-- ── Client ↔ Server ───────────────────────────────────────────────────────────
remote("StatsUpdated")        -- server → client: push updated stats to HUD
remote("LoadSettings")        -- server → client: push saved settings on join
remote("SaveSettings")        -- client → server: persist a settings change
remote("HitDebris")           -- client → server: laser hit a debris chunk
remote("CollectFragment")     -- server → client: fragment added to inventory
remote("CollectMetal")        -- server → client: metal added to inventory
remote("DeductMetal")         -- server → client: metal spent
remote("DroneHealthUpdate")   -- server → client: drone health/mode changed
remote("SetDroneMode")        -- client → server: player changed drone mode

-- ── Server ↔ Server ───────────────────────────────────────────────────────────
bindable("RegisterCollectible")  -- debris system registers a new collectible
bindable("ServerHitDebris")      -- drone laser hits debris (server-side)
bindable("ServerMetalEarned")    -- metal earned event for coin system
