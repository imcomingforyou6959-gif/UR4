local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Track current humanoid
local currentHumanoid = nil

local function setupHumanoid(humanoid)
    if not humanoid then return end
    currentHumanoid = humanoid
    -- Keep UseJumpPower enabled so the main gui's JumpPower slider works
    humanoid.UseJumpPower = true
end

local function getHumanoid()
    local character = LocalPlayer.Character
    if character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then
            setupHumanoid(hum)
            return hum
        end
    end
    return nil
end

-- Handle character respawning
LocalPlayer.CharacterAdded:Connect(function(character)
    local hum = character:WaitForChild("Humanoid", 5)
    if hum then
        setupHumanoid(hum)
    end
end)

-- Check on every Heartbeat to ensure UseJumpPower stays true
RunService.Heartbeat:Connect(function()
    local humanoid = getHumanoid()
    if humanoid then
        -- Keep UseJumpPower enabled so the JumpPower slider works
        if not humanoid.UseJumpPower then
            humanoid.UseJumpPower = true
        end
    end
end)
