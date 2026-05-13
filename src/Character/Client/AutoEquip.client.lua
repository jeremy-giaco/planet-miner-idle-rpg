-- LocalScript → StarterCharacterScripts, rename to "AutoEquip"
local Players  = game:GetService("Players")
local player   = Players.LocalPlayer
local humanoid = script.Parent:WaitForChild("Humanoid")
local backpack  = player:WaitForChild("Backpack")

-- Try both possible tool names (in-Studio name may differ from script references)
local PREFERRED = { "LaserGun", "Laser" }

local function findTool()
    for _, name in ipairs(PREFERRED) do
        local t = backpack:FindFirstChild(name)
        if t then return t end
    end
    return nil
end

-- Wait up to 5 seconds for a laser tool to appear
local tool = findTool()
if not tool then
    local deadline = tick() + 5
    while not tool and tick() < deadline do
        task.wait(0.1)
        tool = findTool()
    end
end

if tool then
    humanoid:EquipTool(tool)
end
