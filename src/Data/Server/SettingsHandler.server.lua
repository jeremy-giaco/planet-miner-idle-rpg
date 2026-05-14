-- Data/Server/SettingsHandler.server.lua
-- Pushes saved settings to the client on join.
-- Listens for SaveSettings remote to persist changes.
if not game:GetService("RunService"):IsServer() then return end
if _G._SettingsHandlerActive then return end
_G._SettingsHandlerActive = true

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes         = ReplicatedStorage:WaitForChild("Remotes")
local loadSettings    = remotes:WaitForChild("LoadSettings")
local loadInventory   = remotes:WaitForChild("LoadInventory")
local saveSettings    = remotes:WaitForChild("SaveSettings")

local VALID_MODES = { classic = true, ["twin-stick"] = true, ["tap-to-fly"] = true, gyro = true }

Players.PlayerAdded:Connect(function(player)
    -- Wait for DataStore to populate, then send settings to client
    task.wait(1)
    local data = _G.PlayerData and _G.PlayerData.get(player)
    if data then
        if data.settings  then loadSettings:FireClient(player, data.settings) end
        loadInventory:FireClient(player, data.fragments or {}, data.metals or {})
    end
end)

saveSettings.OnServerEvent:Connect(function(player, key, value)
    local data = _G.PlayerData and _G.PlayerData.get(player)
    if not data then return end

    -- Validate
    if key == "controlMode" then
        if not VALID_MODES[value] then return end
        data.settings.controlMode = value
    elseif key == "gyroSensitivity" then
        data.settings.gyroSensitivity = math.clamp(tonumber(value) or 1, 0.1, 3.0)
    elseif key == "invertY" then
        data.settings.invertY = value == true
    end

    _G.PlayerData.save(player)
end)

print("[SettingsHandler] Active")
