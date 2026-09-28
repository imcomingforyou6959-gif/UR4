local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local localPlayer=Players.LocalPlayer
local isFiring=false
local currentTool=nil
local fireRate=0.02
local rapidFireEnabled=true
local characterConns={}
local toolConns={}
local hintedNotify=nil

local function getConnections(signal)
    if not getconnections then return {} end
    local ok, conns = pcall(getconnections, signal)
    if not ok or type(conns) ~= "table" then return {} end
    local out = {}
    for _, c in ipairs(conns) do
        local fn = c
        if type(c) == "table" then
            fn = c.Function or c.func or c[1]
        end
        if fn and type(fn) == "function" then
            table.insert(out, fn)
        end
    end
    return out
end

local function removeDelays(tool)
    if not tool then return end
    local funcs = getConnections(tool.Activated)
    for _, fn in ipairs(funcs) do
        local ok, info = pcall(debug.getinfo, fn)
        if not ok or not info then continue end
        local nups = info.nups or 0
        for i = 1, math.min(nups, 15) do
            local ok2, name, val = pcall(debug.getupvalue, fn, i)
            if ok2 and type(val) == "number" then
                if val >= 0 and val <= 30 then
                    pcall(debug.setupvalue, fn, i, 0)
                end
            end
        end
    end
end

local function clearToolConns()
    for _, c in ipairs(toolConns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(toolConns)
end

local function clearCharacterConns()
    for _, c in ipairs(characterConns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(characterConns)
end

local function startRapidFire()
    if not currentTool then return end
    if not rapidFireEnabled then return end
    isFiring=true
    while isFiring and currentTool and currentTool.Parent and rapidFireEnabled do
        local ok = pcall(function()
            currentTool:Activate()
        end)
        if not ok then
            isFiring = false
            break
        end
        task.wait(fireRate)
    end
    isFiring=false
end

local function notifyRapidFire()
    if hintedNotify then
        pcall(hintedNotify, rapidFireEnabled and "Rapid Fire: ON" or "Rapid Fire: OFF")
    end
end

local function toggleRapidFire()
    rapidFireEnabled=not rapidFireEnabled
    if not rapidFireEnabled then
        isFiring=false
    end
    notifyRapidFire()
end

UserInputService.InputBegan:Connect(function(input,gameProcessed)
    if gameProcessed then return end
    if input.KeyCode==Enum.KeyCode.M then
        toggleRapidFire()
    end
    if input.UserInputType==Enum.UserInputType.MouseButton1 and rapidFireEnabled then
        if isFiring then return end
        task.spawn(startRapidFire)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        isFiring=false
    end
end)

local function onCharacterAdded(character)
    task.wait(0.5)
    if not character or not character.Parent then return end

    clearCharacterConns()
    clearToolConns()
    currentTool=nil
    isFiring=false

    local function checkTools()
        if not character or not character.Parent then return end
        local tool=character:FindFirstChildOfClass("Tool")
        if tool and tool~=currentTool then
            currentTool=tool
            pcall(function()
                removeDelays(tool)
            end)
        elseif not tool then
            currentTool=nil
        end
    end

    checkTools()

    table.insert(characterConns, character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and character == localPlayer.Character then
            task.wait(0.1)
            currentTool=child
            pcall(function()
                removeDelays(child)
            end)
        end
    end))

    table.insert(characterConns, character.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") and child==currentTool then
            currentTool=nil
            isFiring=false
        end
    end))
end

if hintedNotify == nil then
    hintedNotify = function(msg)
        if Library and Library.Notify then
            pcall(Library.Notify, Library, msg, 2)
        end
    end
end

if localPlayer.Character then
    onCharacterAdded(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)
