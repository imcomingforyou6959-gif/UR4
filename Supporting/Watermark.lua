_G.WatermarkConnection = nil
_G.WatermarkRunning = true

Library:SetWatermarkVisibility(true)

_G.GetPing = (function() return math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) end)
_G.CanDoPing = pcall(function() return _G.GetPing() end)

local function StartWatermark()
    _G.WatermarkRunning = true
    
    _G.WatermarkConnection = game:GetService("RunService").RenderStepped:Connect(function()
        if not _G.WatermarkRunning then return end
        
        pcall(function()
            if _G.CanDoPing then
                local ping = _G.GetPing()
                Library:SetWatermark("Rawr.xyz <3 | " .. ping .. " ms")
            else
                Library:SetWatermark("Rawr.xyz <3")
            end
        end)
    end)
end

StartWatermark()

Library:OnUnload(function()
    print("!")
end)
