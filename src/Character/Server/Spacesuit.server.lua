-- ServerScript → ServerScriptService
-- Applies default spacesuit colors via HumanoidDescription on character spawn.
-- Client-side parts (visor, shoulder pads) are handled in Spacesuit.client.lua
if not game:GetService("RunService"):IsServer() then return end
if _G._SpacsuitActive then return end
_G._SpacsuitActive = true

local Players = game:GetService("Players")

local SUIT_DARK  = Color3.fromRGB(30, 38, 58)
local SUIT_MID   = Color3.fromRGB(50, 62, 90)
local GLOVE_COL  = Color3.fromRGB(22, 28, 45)

local function applysuit(character)
    local humanoid = character:WaitForChild("Humanoid")
    task.wait(0.1)  -- let DataModel settle before ApplyDescription
    local desc = humanoid:GetAppliedDescription()

    desc.HeadColor        = SUIT_MID
    desc.TorsoColor       = SUIT_DARK
    desc.LeftArmColor     = SUIT_MID
    desc.RightArmColor    = SUIT_MID
    desc.LeftLegColor     = GLOVE_COL
    desc.RightLegColor    = GLOVE_COL
    desc.Shirt            = 0
    desc.Pants            = 0
    desc.GraphicTShirt    = 0

    local ok, err = pcall(function()
        humanoid:ApplyDescription(desc)
    end)
    if not ok then
        warn("[Spacesuit] ApplyDescription failed:", err)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(applysuit)
    if player.Character then applysuit(player.Character) end
end)
