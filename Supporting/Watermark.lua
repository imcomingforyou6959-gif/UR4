Library:SetWatermarkVisibility(true)

local FrameTimer = tick()
local FrameCounter = 0
local FPS = 60
local GetPing = (function() return math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) end)
local CanDoPing = pcall(function() return GetPing() end)

local WatermarkConnection = game:GetService("RunService").RenderStepped:Connect(function()
    FrameCounter += 1

    if (tick() - FrameTimer) >= 1 then
        FPS = FrameCounter
        FrameTimer = tick()
        FrameCounter = 0
    end

    if CanDoPing then
        Library:SetWatermark(("Rawr.xyz <3 | %d fps | %d ms"):format(
            math.floor(FPS),
            GetPing()
        ))
    else
        Library:SetWatermark(("Rawr.xyz <3 | %d fps"):format(
            math.floor(FPS)
        ))
    end
end)

Library:OnUnload(function()
    WatermarkConnection:Disconnect()

    print("Unloaded!")
    Library.Unloaded = true
end)
