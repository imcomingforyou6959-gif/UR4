Library:SetWatermarkVisibility(true)

local Stats = game:GetService("Stats")

local function GetPing()
    local net = Stats:FindFirstChild("Network")
    if not net then return nil end
    local ssi = net:FindFirstChild("ServerStatsItem")
    if not ssi then return nil end
    local ping = ssi:FindFirstChild("Data Ping")
    if not ping then return nil end
    local ok, val = pcall(function() return ping:GetValue() end)
    if not ok or type(val) ~= "number" then return nil end
    return math.floor(val)
end

WatermarkConnection = game:GetService("RunService").RenderStepped:Connect(function()
    local ping = GetPing()
    if ping then
        Library:SetWatermark(("Rawr.xyz <3 | %d ms"):format(ping))
    else
        Library:SetWatermark("Rawr.xyz <3")
    end
end)
