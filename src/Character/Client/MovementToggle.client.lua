-- LocalScript → StarterCharacterScripts/MovementToggle
-- R key      : toggle walk / run (persistent)
-- Shift held : temporarily switch to the opposite mode, revert on release
if not game:GetService("RunService"):IsClient() then return end

local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local Config    = require(ReplicatedStorage:WaitForChild("Config"))
local character = script.Parent
local humanoid  = character:WaitForChild("Humanoid")
local player    = Players.LocalPlayer

-- Read live-tweaked speeds if admin console is active, else use Config
local function walkSpeed() return (_G.LiveConfig and _G.LiveConfig.WALK_SPEED) or Config.WALK_SPEED end
local function runSpeed()  return (_G.LiveConfig and _G.LiveConfig.RUN_SPEED)  or Config.RUN_SPEED  end

-- State
local isRunning   = true   -- default: running
local shiftHeld   = false

local function applySpeed()
    -- If shift is held, use opposite of current toggle state
    local wantRun = isRunning
    if shiftHeld then wantRun = not wantRun end
    local base  = wantRun and runSpeed() or walkSpeed()
    local bonus = (wantRun and _G.TachyiteBonus) or 0
    humanoid.WalkSpeed = base + (bonus or 0)
end

-- R toggles run/walk
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.R then
        isRunning = not isRunning
        applySpeed()
    end
end)

-- Shift = temporary opposite
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.LeftShift
    or input.KeyCode == Enum.KeyCode.RightShift then
        shiftHeld = true
        applySpeed()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift
    or input.KeyCode == Enum.KeyCode.RightShift then
        shiftHeld = false
        applySpeed()
    end
end)

-- Apply initial speed on spawn
applySpeed()

-- Keep speed in sync if admin console changes the values live
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local configUpdate = remotes:WaitForChild("ConfigUpdated")
configUpdate.OnClientEvent:Connect(function(key)
    if key == "WALK_SPEED" or key == "RUN_SPEED" then
        applySpeed()
    end
end)
