-- LocalScript → StarterCharacterScripts, rename to "AutoEquip"
local Players  = game:GetService("Players")
local player   = Players.LocalPlayer
local humanoid = script.Parent:WaitForChild("Humanoid")
local backpack  = player:WaitForChild("Backpack")

local tool = backpack:WaitForChild("LaserGun", 5)
if tool then
    humanoid:EquipTool(tool)
end
