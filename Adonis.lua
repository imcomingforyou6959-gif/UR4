if getgenv().BYPASSED_ADONIS then return end
getgenv().BYPASSED_ADONIS = true

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function log(...) warn("[Adonis Bypass]", ...) end

local function armBypass()
    local hasHookfunction = typeof(hookfunction) == "function"
    local hasNewcclosure = typeof(newcclosure) == "function"
    local hasGetgc = typeof(getgc) == "function"
    
    if not hasHookfunction or not hasNewcclosure or not hasGetgc then
        log("Missing functions, trying fallback...")
        return false
    end
    
    -- Find Detected in GC
    local function findDetected()
        for _, v in getgc(true) do
            if typeof(v) == "table" then
                if rawget(v, "Detected") and rawget(v, "Detectors") and rawget(v, "RLocked") then
                    local d = rawget(v, "Detected")
                    if typeof(d) == "function" then return d end
                end
            end
        end
    end
    
    -- Wait for Adonis to load
    local detected, attempt = nil, 0
    repeat
        attempt += 1
        detected = findDetected()
        if not detected then
            if attempt <= 3 or attempt % 10 == 0 then
                log("Waiting for Adonis... attempt", attempt)
            end
            task.wait(1)
        end
    until detected or attempt > 60
    
    if not detected then
        log("Detected not found, trying fallback...")
        return false
    end

    local noop = newcclosure(function(action, info, nocrash)
        return true
    end)
    
    local ok = pcall(hookfunction, detected, noop)
    if ok then
        log("Adonis bypass")
        return true
    end
    
    log("hookfunction failed, trying fallback...")
    return false
end

local function armFallback()
    local hasHookfunction = typeof(hookfunction) == "function"
    if not hasHookfunction then return false end
    
    -- Hook Kick
    local Kick = hookfunction(LocalPlayer.Kick, function(...)
        if checkcaller() then return Kick(...) end
        local script = tostring(getcallingscript())
        if script == "ClientMover" then return end -- Block Adonis kick
        return Kick(...)
    end)
    
    local DebugInfo = hookfunction(debug.info, function(...)
        if checkcaller() then return DebugInfo(...) end
        local script = tostring(getcallingscript())
        local what = select(2, ...)
        if script == "ClientMover" and what == "slanf" then
            return coroutine.yield() -- Hang checker
        end
        return DebugInfo(...)
    end)
    
    for _, v in getgc(true) do
        if typeof(v) == "table" then
            local Detected, Kill = rawget(v, "Detected"), rawget(v, "Kill")
            
            if typeof(Kill) == "function" and debug.info(Kill, "s") == ".Client.Client" then
                hookfunction(Kill, function(info) end) -- No-op
            end
            
            if typeof(Detected) == "function" and debug.info(Detected, "s") == ".Client.Core.Anti" then
                hookfunction(Detected, function(action, info, nocrash) end) -- No-op
            end
        end
    end
    
    log("bypass")
    return true
end

task.spawn(function()
    local success = armBypass()
    if not success then
        task.wait(2)
        armFallback()
    end
end)
