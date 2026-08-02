-- SHARED FUNCTIONS
Grabbed = function(Plr)
    if Plr and Plr.Character then
        local char = Plr.Character
        if char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char:FindFirstChild("Head") and char:FindFirstChild("GRABBING_CONSTRAINT") then
            return true
        end
    end
    return false
end

function isDead(Player)
    local Character = Player.Character
    if not Character then return false end
    
    local BodyEffects = Character:FindFirstChild("BodyEffects")
    if BodyEffects and BodyEffects:FindFirstChild("Dead") and BodyEffects.Dead.Value == true then
        return true
    end
    
    return false
end

-- AUTO STOMP
local StompEnabled = false
local StompToggle = _78:AddToggle('AutoStomp', {
    Text = 'Auto Stomp',
    Default = false,
})

StompToggle:OnChanged(function(value)
    StompEnabled = value
end)

local stompRemote = nil
local function getStompRemote()
    if stompRemote and stompRemote.Parent then
        return stompRemote
    end
    
    local replicatedStorage = game:GetService("ReplicatedStorage")
    
    local gameRemotes = replicatedStorage:FindFirstChild("GameRemotes")
    if gameRemotes then
        local mainGameEvent = gameRemotes:FindFirstChild("MainGameEvent")
        if mainGameEvent then
            stompRemote = mainGameEvent
            return stompRemote
        end
    end
    
    local mainRemotes = replicatedStorage:FindFirstChild("MainRemotes")
    if mainRemotes then
        local mainRemoteEvent = mainRemotes:FindFirstChild("MainRemoteEvent")
        if mainRemoteEvent then
            stompRemote = mainRemoteEvent
            return stompRemote
        end
    end
    
    local mainEvent = replicatedStorage:FindFirstChild("MainEvent")
    if mainEvent then
        stompRemote = mainEvent
        return stompRemote
    end
    
    return nil
end

function fireStomp()
    local remote = getStompRemote()
    if not remote then return end
    pcall(function()
        remote:FireServer("Stomp")
    end)
end

local stomping = false
local stompConnection = nil
local stompVelocityHistory = {}
local stompMaxHistory = 5

function getBestStompPosition(targetChar)
    local parts = {"UpperTorso", "Torso", "HumanoidRootPart", "LowerTorso", "Head"}
    for _, partName in ipairs(parts) do
        local part = targetChar:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            return part
        end
    end
    return nil
end

function getStompPredictedPosition(part)
    if not part then return nil end
    
    local velocity = part.Velocity
    if part.AssemblyLinearVelocity then
        velocity = part.AssemblyLinearVelocity
    end
    
    local speed = velocity.Magnitude
    
    if speed > 50 then
        local predictionTime = 0.25
        local predictedPos = part.Position + (velocity * predictionTime)
        return CFrame.new(predictedPos)
    elseif speed > 20 then
        local predictionTime = 0.2
        local predictedPos = part.Position + (velocity * predictionTime)
        return CFrame.new(predictedPos)
    else
        local predictionTime = 0.1
        local predictedPos = part.Position + (velocity * predictionTime)
        return CFrame.new(predictedPos)
    end
end

function findSafeReturnPosition(originalPos)
    local directions = {
        Vector3.new(0, 5, 0),
        Vector3.new(5, 0, 0),
        Vector3.new(-5, 0, 0),
        Vector3.new(0, 0, 5),
        Vector3.new(0, 0, -5),
        Vector3.new(5, 5, 0),
        Vector3.new(-5, 5, 0),
        Vector3.new(0, 5, 5),
        Vector3.new(0, 5, -5),
        Vector3.new(0, 10, 0),
    }
    
    for _, offset in ipairs(directions) do
        local checkPos = originalPos + offset
        local ray = Ray.new(checkPos, Vector3.new(0, -20, 0))
        local hit = workspace:FindPartOnRay(ray, _56.Character, false, true)
        
        if not hit then
            return CFrame.new(checkPos)
        end
    end
    
    return CFrame.new(originalPos + Vector3.new(0, 4, 0))
end

function autoStompTarget()
    if not StompEnabled then return end
    if _118 then return end
    if stomping then return end
    if _AA_busy then return end
    
    local target = _104.targetplayer
    if not target then return end
    
    local targetChar = target.Character
    if not targetChar then return end
    
    local BodyEffects = targetChar:FindFirstChild("BodyEffects")
    if not BodyEffects then return end
    
    local KOCheck = BodyEffects:FindFirstChild("K.O")
    if not KOCheck or KOCheck.Value ~= true then return end
    if Grabbed(target) then return end
    if isDead(target) then return end
    
    local localChar = _56.Character
    if not localChar then return end
    
    local localHRP = localChar:FindFirstChild("HumanoidRootPart")
    if not localHRP then return end
    
    local targetPart = getBestStompPosition(targetChar)
    if not targetPart then return end
    
    stomping = true
    stompVelocityHistory = {}
    local lastpos = localHRP.CFrame
    
    local predictedCFrame = getStompPredictedPosition(targetPart)
    local stompCFrame = predictedCFrame or targetPart.CFrame
    localHRP.CFrame = stompCFrame * CFrame.new(0, 0, 0)
    
    for i = 1, 10 do
        fireStomp()
    end
    
    if stompConnection then stompConnection:Disconnect() end
    stompConnection = _52.RenderStepped:Connect(function()
        if not stomping then
            stompConnection:Disconnect()
            stompConnection = nil
            return
        end
        
        local currentTargetPart = getBestStompPosition(targetChar)
        if currentTargetPart then
            local velocity = currentTargetPart.Velocity
            if currentTargetPart.AssemblyLinearVelocity then
                velocity = currentTargetPart.AssemblyLinearVelocity
            end
            
            table.insert(stompVelocityHistory, velocity)
            if #stompVelocityHistory > stompMaxHistory then
                table.remove(stompVelocityHistory, 1)
            end
            
            local avgVelocity = Vector3.new(0, 0, 0)
            for _, v in ipairs(stompVelocityHistory) do
                avgVelocity = avgVelocity + v
            end
            avgVelocity = avgVelocity / #stompVelocityHistory
            
            local speed = avgVelocity.Magnitude
            local predictionTime = 0.15
            
            if speed > 80 then
                predictionTime = 0.35
            elseif speed > 50 then
                predictionTime = 0.3
            elseif speed > 30 then
                predictionTime = 0.25
            elseif speed > 15 then
                predictionTime = 0.2
            end
            
            local predictedPos = currentTargetPart.Position + (avgVelocity * predictionTime)
            local stompCFrame = CFrame.new(predictedPos)
            
            localHRP.CFrame = stompCFrame * CFrame.new(0, 0, 0)
            fireStomp()
        end
    end)
    
    task.delay(0.5, function()
        stomping = false
        if stompConnection then
            stompConnection:Disconnect()
            stompConnection = nil
        end
        stompVelocityHistory = {}
        
        local safeReturn = findSafeReturnPosition(lastpos.Position)
        pcall(function()
            localHRP.CFrame = safeReturn
        end)
    end)
end

-- AUTO GRAB
local GrabEnabled = false

local grabState = {
    remote = nil,
    type = nil,
    connection = nil,
    velocityHistory = {},
    fired = false,
    timer = nil,
    active = false,
    grabbing = false,
    lastGrabTime = 0,
    returnPos = nil,
    ping = 0
}

local CONSTANTS = {
    MAX_HISTORY = 3,
    GRAB_COOLDOWN = 0.3,
    MAX_DURATION = 0.6,
    AUTO_GRAB_COOLDOWN = 1.0,
    LOOP_WAIT = 0.01,
    GROUND_OFFSET = 2,
    GRAB_OFFSET = Vector3.new(0, 1, 0.5)
}

local function getPing()
    local stats = game:GetService("Stats")
    local network = stats:FindFirstChild("Network")
    if network then
        local ping = network:FindFirstChild("Ping")
        if ping then
            return ping.Value / 1000
        end
    end
    return 0.05
end

local function getGroundPosition(pos)
    local ray = Ray.new(pos, Vector3.new(0, -100, 0))
    local hit, hitPos = workspace:FindPartOnRay(ray, _56.Character, false, true)
    
    if hit and hitPos then
        return Vector3.new(pos.X, hitPos.Y + 2, pos.Z)
    end
    
    local yPos = math.min(pos.Y, 5)
    return Vector3.new(pos.X, yPos, pos.Z)
end

local function cleanupGrabState()
    grabState.grabbing = false
    grabState.active = false
    
    if grabState.connection then
        pcall(function() grabState.connection:Disconnect() end)
        grabState.connection = nil
    end
    
    if grabState.timer then
        pcall(function() grabState.timer:Cancel() end)
        grabState.timer = nil
    end
    
    grabState.velocityHistory = {}
    grabState.fired = false
    grabState.returnPos = nil
end

local GrabToggle = _78:AddToggle('AutoGrab', {
    Text = 'Auto Grab',
    Default = false,
})

GrabToggle:OnChanged(function(value)
    GrabEnabled = value
    if not value then
        cleanupGrabState()
    end
end)

function getGrabRemote()
    if grabState.remote and grabState.remote.Parent then
        return grabState.remote, grabState.type
    end
    
    local replicatedStorage = game:GetService("ReplicatedStorage")
    if not replicatedStorage then return nil, nil end
    
    local remotePaths = {
        {path = {"MainRemotes", "MainRemoteEvent"}, type = "NewGrabbing"},
        {path = {"GameRemotes", "MainGameEvent"}, type = "Grabbing"},
        {path = {"MainEvent"}, type = "Grabbing"}
    }
    
    for _, remoteInfo in ipairs(remotePaths) do
        local current = replicatedStorage
        local valid = true
        
        for _, segment in ipairs(remoteInfo.path) do
            current = current:FindFirstChild(segment)
            if not current then
                valid = false
                break
            end
        end
        
        if valid and current:IsA("RemoteEvent") then
            grabState.remote = current
            grabState.type = remoteInfo.type
            return current, remoteInfo.type
        end
    end
    
    return nil, nil
end

function fireGrab()
    grabState.ping = getPing()
    
    local remote, gType = getGrabRemote()
    if remote then
        local success = pcall(function()
            if gType == "NewGrabbing" then
                remote:FireServer("NewGrabbing", false)
            else
                remote:FireServer("Grabbing", false)
            end
        end)
        if success then return true end
    end
    
    pcall(function()
        local VirtualInputManager = game:GetService("VirtualInputManager")
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.G, false, game)
        task.wait(0.01)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.G, false, game)
    end)
    return true
end

function getBestGrabPosition(targetChar)
    if not targetChar then return nil end
    
    local priorityParts = {"UpperTorso", "Torso", "HumanoidRootPart", "LowerTorso", "Head"}
    
    for _, partName in ipairs(priorityParts) do
        local part = targetChar:FindFirstChild(partName)
        if part and part:IsA("BasePart") and part.Parent == targetChar then
            return part
        end
    end
    return nil
end

function isDead(target)
    if not target then return true end
    local targetChar = target.Character
    if not targetChar or not targetChar.Parent then return true end
    
    local BodyEffects = targetChar:FindFirstChild("BodyEffects")
    if not BodyEffects then return true end
    
    local deadCheck = BodyEffects:FindFirstChild("Dead")
    if deadCheck and deadCheck.Value == true then
        return true
    end
    
    return false
end

function isKO(target)
    if not target then return false end
    local targetChar = target.Character
    if not targetChar or not targetChar.Parent then return false end
    
    local BodyEffects = targetChar:FindFirstChild("BodyEffects")
    if not BodyEffects then return false end
    
    local KOCheck = BodyEffects:FindFirstChild("K.O")
    if KOCheck and KOCheck.Value == true then
        return true
    end
    
    return false
end

function autoGrabTarget()
    if not GrabEnabled then return end
    if _118 then return end
    if grabState.grabbing then return end
    if stomping then return end
    if _AA_busy then return end
    if grabState.active then return end
    
    local target = _104.targetplayer
    if not target then return end
    if isDead(target) then return end
    if not isKO(target) then return end
    if Grabbed(target) then return end
    
    local localChar = _56.Character
    if not localChar or not localChar.Parent then return end
    
    local localHRP = localChar:FindFirstChild("HumanoidRootPart")
    if not localHRP then return end
    
    local targetChar = target.Character
    if not targetChar or not targetChar.Parent then return end
    
    local targetPart = getBestGrabPosition(targetChar)
    if not targetPart then return end
    
    grabState.ping = getPing()
    
    grabState.active = true
    grabState.grabbing = true
    grabState.velocityHistory = {}
    grabState.fired = false
    grabState.lastGrabTime = 0
    grabState.returnPos = localHRP.Position
    
    local startTime = tick()
    local grabbedSuccess = false
    
    local offset = Vector3.new(0, 0.8, 0.5)
    
    pcall(function()
        localHRP.CFrame = targetPart.CFrame * CFrame.new(offset)
    end)
    
    for i = 1, 3 do
        fireGrab()
        task.wait(0.05)
    end
    grabState.fired = true
    grabState.lastGrabTime = tick()
    
    while grabState.grabbing and grabState.active do
        local elapsed = tick() - startTime
        if elapsed >= CONSTANTS.MAX_DURATION then break end
        if isDead(target) or not isKO(target) then break end
        if Grabbed(target) then grabbedSuccess = true; break end
        
        targetChar = target.Character
        if not targetChar or not targetChar.Parent then break end
        
        local currentTargetPart = getBestGrabPosition(targetChar)
        if currentTargetPart then
            local velocity = currentTargetPart.Velocity
            if currentTargetPart.AssemblyLinearVelocity then
                velocity = currentTargetPart.AssemblyLinearVelocity
            end
            
            local speed = velocity.Magnitude
            local predictionTime = 0.05
            
            if speed > 100 then
                predictionTime = 0.15
            elseif speed > 50 then
                predictionTime = 0.1
            end
            
            local predictedPos = currentTargetPart.Position + (velocity * predictionTime)
            
            pcall(function()
                localHRP.CFrame = CFrame.new(predictedPos) * CFrame.new(offset)
            end)
        end
        
        -- Fire less frequently (0.3 seconds)
        if tick() - grabState.lastGrabTime >= CONSTANTS.GRAB_COOLDOWN then
            if not Grabbed(target) then
                fireGrab()
                grabState.lastGrabTime = tick()
            end
        end
        
        task.wait(CONSTANTS.LOOP_WAIT)
    end
    
    -- Only 2
    for i = 1, 2 do
        if not Grabbed(target) then
            fireGrab()
        end
        task.wait(0.05)
    end
    
    if grabState.returnPos then
        local groundPos = getGroundPosition(grabState.returnPos)
        pcall(function()
            localHRP.CFrame = CFrame.new(groundPos)
        end)
    end
    
    grabState.grabbing = false
    grabState.active = false
    cleanupGrabState()
end

local lastAutoGrabTime = 0
local _autoGrabTarget = autoGrabTarget

autoGrabTarget = function()
    local currentTime = tick()
    if currentTime - lastAutoGrabTime < CONSTANTS.AUTO_GRAB_COOLDOWN then return end
    if grabState.active then return end
    
    lastAutoGrabTime = currentTime
    
    pcall(function()
        _autoGrabTarget()
    end)
end
