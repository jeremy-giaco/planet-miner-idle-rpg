-- Core/ClientSettings.lua (ModuleScript → ReplicatedStorage)
-- Client-side settings cache. Populated by server on join via LoadSettings remote.
-- Other client scripts require this to read settings without server round-trips.

local ClientSettings = {
    controlMode     = "classic",   -- classic | twin-stick | tap-to-fly | gyro
    gyroSensitivity = 1.0,
    invertY         = false,
}

return ClientSettings
