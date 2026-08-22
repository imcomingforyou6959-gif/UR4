repeat task.wait() until game:IsLoaded()
local _1 = game:GetService("StarterPlayer")
local _2 = game:GetService("Players")
local _3 = _2.LocalPlayer
if not _3 then
    repeat task.wait() until _2.LocalPlayer
    _3 = _2.LocalPlayer
end

local _4 = _1.StarterPlayerScripts:FindFirstChild("ClientOptimizer")
if _4 then
    _4:Destroy()
end
if _3 then
    local _5 = _3.PlayerScripts:FindFirstChild("ClientOptimizer")
    if _5 then
        _5:Destroy()
    end
end

_1.StarterPlayerScripts.ChildAdded:Connect(function(_6)
    if _6.Name == "ClientOptimizer" then
        task.wait()
        _6:Destroy()
    end
end)

if _3 then
    _3.PlayerScripts.ChildAdded:Connect(function(_7)
        if _7.Name == "ClientOptimizer" then
            task.wait()
            _7:Destroy()
        end
    end)
end
