
local module = { StompEnabled = false, GrabEnabled = false }
local _52 = game:GetService("RunService")
local _56 = game:GetService("Players").LocalPlayer

Grabbed = function(Plr)
    if Plr and Plr.Character then
        local char = Plr.Character
        if char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char:FindFirstChild("Head") and char:FindFirstChild("GRABBING_CONSTRAINT") then
            return true
        end
    end
    return false
end

isDead = function(Player)
    local Character = Player.Character
    if not Character then return false end
    local BodyEffects = Character:FindFirstChild("BodyEffects")
    return BodyEffects and BodyEffects:FindFirstChild("Dead") and BodyEffects.Dead.Value == true
end

isKO = function(target)
    if not target then return false end
    local targetChar = target.Character
    if not targetChar or not targetChar.Parent then return false end
    local BodyEffects = targetChar:FindFirstChild("BodyEffects")
    return BodyEffects and BodyEffects:FindFirstChild("K.O") and BodyEffects["K.O"].Value == true
end

local stompRemote, stomping, stompConnection, stompVelocityHistory, stompMaxHistory = nil, false, nil, {}, 5

getStompRemote = function()
    if stompRemote and stompRemote.Parent then return stompRemote end
    local rs = game:GetService("ReplicatedStorage")
    for _, path in ipairs({{"GameRemotes","MainGameEvent"},{"MainRemotes","MainRemoteEvent"},{"MainEvent"}}) do
        local cur = rs
        for _, seg in ipairs(path) do cur = cur:FindFirstChild(seg) if not cur then break end end
        if cur and cur:IsA("RemoteEvent") then stompRemote = cur return cur end
    end
end

fireStomp = function()
    local remote = getStompRemote()
    if remote then pcall(function() remote:FireServer("Stomp") end) end
end

getBestStompPosition = function(targetChar)
    for _, n in ipairs({"UpperTorso","Torso","HumanoidRootPart","LowerTorso","Head"}) do
        local p = targetChar:FindFirstChild(n)
        if p and p:IsA("BasePart") then return p end
    end
end

getStompPredictedPosition = function(part)
    if not part then return end
    local vel = part.AssemblyLinearVelocity or part.Velocity
    local speed = vel.Magnitude
    local t = speed > 50 and 0.25 or (speed > 20 and 0.2 or 0.1)
    return CFrame.new(part.Position + vel * t)
end

findSafeReturnPosition = function(originalPos)
    for _, off in ipairs({Vector3.new(0,5,0),Vector3.new(5,0,0),Vector3.new(-5,0,0),Vector3.new(0,0,5),Vector3.new(0,0,-5),Vector3.new(5,5,0),Vector3.new(-5,5,0),Vector3.new(0,5,5),Vector3.new(0,5,-5),Vector3.new(0,10,0)}) do
        local checkPos = originalPos + off
        local ray = Ray.new(checkPos, Vector3.new(0,-20,0))
        local hit = workspace:FindPartOnRay(ray, _56.Character, false, true)
        if not hit then return CFrame.new(checkPos) end
    end
    return CFrame.new(originalPos + Vector3.new(0,4,0))
end

autoStompTarget = function()
    if not module.StompEnabled then return end
    local target = _G._104 and _G._104.targetplayer
    if not target or not target.Character then return end
    if stomping then return end
    
    local targetChar = target.Character
    local BodyEffects = targetChar:FindFirstChild("BodyEffects")
    if not BodyEffects then return end
    local KOCheck = BodyEffects:FindFirstChild("K.O")
    if not KOCheck or KOCheck.Value ~= true then return end
    if Grabbed(target) or isDead(target) then return end
    
    local localChar = _56.Character
    if not localChar then return end
    local localHRP = localChar:FindFirstChild("HumanoidRootPart")
    if not localHRP then return end
    
    local targetPart = getBestStompPosition(targetChar)
    if not targetPart then return end
    
    stomping = true
    stompVelocityHistory = {}
    local lastpos = localHRP.CFrame
    local stompCFrame = getStompPredictedPosition(targetPart) or targetPart.CFrame
    localHRP.CFrame = stompCFrame
    
    for i = 1, 10 do fireStomp() end
    
    if stompConnection then stompConnection:Disconnect() end
    stompConnection = _52.RenderStepped:Connect(function()
        if not stomping then stompConnection:Disconnect() stompConnection = nil return end
        local currentTargetPart = getBestStompPosition(targetChar)
        if currentTargetPart then
            local vel = currentTargetPart.AssemblyLinearVelocity or currentTargetPart.Velocity
            table.insert(stompVelocityHistory, vel)
            if #stompVelocityHistory > stompMaxHistory then table.remove(stompVelocityHistory, 1) end
            local avg = Vector3.zero
            for _, v in ipairs(stompVelocityHistory) do avg += v end
            avg /= #stompVelocityHistory
            local t = avg.Magnitude > 80 and 0.35 or (avg.Magnitude > 50 and 0.3 or (avg.Magnitude > 30 and 0.25 or (avg.Magnitude > 15 and 0.2 or 0.15)))
            localHRP.CFrame = CFrame.new(currentTargetPart.Position + avg * t)
            fireStomp()
        end
    end)
    
    task.delay(0.5, function()
        stomping = false
        if stompConnection then stompConnection:Disconnect() stompConnection = nil end
        stompVelocityHistory = {}
        pcall(function() localHRP.CFrame = findSafeReturnPosition(lastpos.Position) end)
    end)
end

-- AUTO GRAB
local grabState = {remote=nil,type=nil,connection=nil,velocityHistory={},fired=false,timer=nil,active=false,grabbing=false,lastGrabTime=0,returnPos=nil,ping=0}
local CONSTANTS = {MAX_HISTORY=3,GRAB_COOLDOWN=0.3,MAX_DURATION=0.6,AUTO_GRAB_COOLDOWN=1.0,LOOP_WAIT=0.01}

getPing = function()
    local network = game:GetService("Stats"):FindFirstChild("Network")
    if network then local ping = network:FindFirstChild("Ping") if ping then return ping.Value/1000 end end
    return 0.05
end

getGroundPosition = function(pos)
    local ray = Ray.new(pos, Vector3.new(0,-100,0))
    local hit, hitPos = workspace:FindPartOnRay(ray, _56.Character, false, true)
    return hit and hitPos and Vector3.new(pos.X, hitPos.Y+2, pos.Z) or Vector3.new(pos.X, math.min(pos.Y,5), pos.Z)
end

cleanupGrabState = function()
    grabState.grabbing, grabState.active = false, false
    if grabState.connection then pcall(function() grabState.connection:Disconnect() end) grabState.connection = nil end
    if grabState.timer then pcall(function() grabState.timer:Cancel() end) grabState.timer = nil end
    grabState.velocityHistory, grabState.fired, grabState.returnPos = {}, false, nil
end

getGrabRemote = function()
    if grabState.remote and grabState.remote.Parent then return grabState.remote, grabState.type end
    local rs = game:GetService("ReplicatedStorage")
    if not rs then return end
    for _, info in ipairs({{{"MainRemotes","MainRemoteEvent"},"NewGrabbing"},{{"GameRemotes","MainGameEvent"},"Grabbing"},{{"MainEvent"},"Grabbing"}}) do
        local cur = rs
        for _, seg in ipairs(info[1]) do cur = cur:FindFirstChild(seg) if not cur then break end end
        if cur and cur:IsA("RemoteEvent") then grabState.remote, grabState.type = cur, info[2] return cur, info[2] end
    end
end

fireGrab = function()
    local remote, gType = getGrabRemote()
    if remote then
        pcall(function()
            if gType == "NewGrabbing" then remote:FireServer("NewGrabbing", false)
            else remote:FireServer("Grabbing", false) end
        end)
    end
    pcall(function() game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.G, false, game) task.wait(0.01) game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.G, false, game) end)
end

getBestGrabPosition = function(targetChar)
    if not targetChar then return end
    for _, n in ipairs({"UpperTorso","Torso","HumanoidRootPart","LowerTorso","Head"}) do
        local p = targetChar:FindFirstChild(n)
        if p and p:IsA("BasePart") then return p end
    end
end

autoGrabTarget = function()
    if not module.GrabEnabled or grabState.grabbing or grabState.active then return end
    local target = _G._104 and _G._104.targetplayer
    if not target then return end
    if isDead(target) or not isKO(target) or Grabbed(target) then return end
    
    local localChar = _56.Character
    if not localChar then return end
    local localHRP = localChar:FindFirstChild("HumanoidRootPart")
    if not localHRP then return end
    
    local targetPart = getBestGrabPosition(target.Character)
    if not targetPart then return end
    
    grabState.active, grabState.grabbing, grabState.lastGrabTime = true, true, 0
    grabState.returnPos = localHRP.Position
    local startTime = tick()
    
    pcall(function() localHRP.CFrame = targetPart.CFrame * CFrame.new(0,0.8,0.5) end)
    for i = 1, 3 do fireGrab() task.wait(0.05) end
    grabState.lastGrabTime = tick()
    
    while grabState.grabbing and tick()-startTime < CONSTANTS.MAX_DURATION do
        if isDead(target) or not isKO(target) or Grabbed(target) then break end
        local curPart = getBestGrabPosition(target.Character)
        if curPart then
            local vel = curPart.AssemblyLinearVelocity or curPart.Velocity
            local t = vel.Magnitude > 100 and 0.15 or (vel.Magnitude > 50 and 0.1 or 0.05)
            pcall(function() localHRP.CFrame = CFrame.new(curPart.Position + vel*t) * CFrame.new(0,0.8,0.5) end)
        end
        if tick()-grabState.lastGrabTime >= CONSTANTS.GRAB_COOLDOWN and not Grabbed(target) then
            fireGrab() grabState.lastGrabTime = tick()
        end
        task.wait(CONSTANTS.LOOP_WAIT)
    end
    
    for i = 1, 2 do if not Grabbed(target) then fireGrab() end task.wait(0.05) end
    if grabState.returnPos then pcall(function() localHRP.CFrame = CFrame.new(getGroundPosition(grabState.returnPos)) end) end
    cleanupGrabState()
end

module.autoStompTarget = autoStompTarget
module.autoGrabTarget = autoGrabTarget
module.cleanup = function()
    module.StompEnabled, module.GrabEnabled = false, false
    if stompConnection then stompConnection:Disconnect() end
    cleanupGrabState()
end

return module
