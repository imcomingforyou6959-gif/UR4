Library:SetWatermarkVisibility(true)

GetPing = (function() return math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) end)
CanDoPing = pcall(function() return GetPing() end)

WatermarkConnection = game:GetService("RunService").RenderStepped:Connect(function()
    if CanDoPing then
        Library:SetWatermark(("Rawr.xyz <3 | %d ms"):format(GetPing()))
    else
        Library:SetWatermark("Rawr.xyz <3")
    end
end)
