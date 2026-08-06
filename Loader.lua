local Loader = {}
Loader.URL = "https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Loadstring.lua"
Loader.IsLoaded = false
Loader.Loading = false

function Loader:Load()
    if self.Loading or self.IsLoaded then return end
    self.Loading = true
    
    local success, err = pcall(function()
        local script = game:HttpGet(self.URL)
        loadstring(script)()
        self.IsLoaded = true
        self.Loading = false
        warn("[Loader] Loaded..")
    end)
    
    if not success then
        self.Loading = false
        warn("[Loader] Failed to Init:", err)
        task.wait(5)
        self:Load()
    end
end

if game:IsLoaded() then
    Loader:Load()
else
    game.Loaded:Connect(function()
        Loader:Load()
    end)
end

game.Players.LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    Loader.IsLoaded = false
    Loader:Load()
end)

game:GetService("TeleportService"):TeleportInitiated:Connect(function()
    Loader.IsLoaded = false
end)

local Players = game:GetService("Players")
Players.LocalPlayer:GetPropertyChangedSignal("Character"):Connect(function()
    task.wait(0.5)
    if not Loader.IsLoaded then
        Loader:Load()
    end
end)

warn("[Loader] Waiting...")
