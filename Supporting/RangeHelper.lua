local _40, _ = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Adonis.lua", true))()
end)

local Players = game:GetService('Players');
local RunService = game:GetService('RunService');
local ReplicatedStorage = game:GetService('ReplicatedStorage');
local LocalPlayer = Players.LocalPlayer;

task.spawn(function()
    local MainEvent = ReplicatedStorage:FindFirstChild('MainRemoteEvent') or ReplicatedStorage:WaitForChild('MainEvent', 10);
    if MainEvent then
        RunService.Heartbeat:Connect(function()
            local Character = LocalPlayer.Character;
            if Character then
                for _, Tool in next, Character:GetChildren() do
                    if Tool:IsA('Tool') then
                        local R = Tool:FindFirstChild('Range');
                        if R then R.Value = 999999 end;
                    end;
                end;
            end;
            local Backpack = LocalPlayer:FindFirstChild('Backpack');
            if Backpack then
                for _, Tool in next, Backpack:GetChildren() do
                    if Tool:IsA('Tool') then
                        local R = Tool:FindFirstChild('Range');
                        if R then R.Value = 999999 end;
                    end;
                end;
            end;
        end);
        local hookMM = hookmetamethod or (getgenv and getgenv().hookmetamethod);
        if hookMM then
            local oldNC;
            oldNC = hookMM(game, '__namecall', function(self, ...)
                local method = getnamecallmethod();
                local args = {...};
                if self == MainEvent and method == 'FireServer' and args[1] == 'ShootGun' then
                    if args[6] and type(args[6]) == 'number' then
                        args[6] = 10;
                    end;
                    if args[3] and args[5] then
                        local Dir = (args[3] - args[5]).Unit;
                        args[3] = args[5] + Dir * 10;
                    end;
                end;
                if args[1] == 'CHECKER_4' then return nil end;
                return oldNC(self, unpack(args));
            end);
        end;
    end;
end);
