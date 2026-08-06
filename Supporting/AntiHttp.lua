local requestFunction = (syn or http).request

local methodCheck = {
    HttpGet = not syn,
    HttpGetAsync = not syn,
    GetObjects = true,
    HttpPost = not syn,
    HttpPostAsync = not syn,
}

local detectionMessage = 'detected lmao'
local detectionTriggered = false

task.spawn(function()
    while task.wait(1) do
        local function recursiveStackCheck(counter, maxCount)
            if maxCount < 19991 then
                return recursiveStackCheck(counter, maxCount + 1)
            end
            counter('Hello')
        end

        local success, stackResult = pcall(recursiveStackCheck, http.request, -4)
        
        local outputFunctions = {
            rconsoleprint,
            print,
            setclipboard,
            rconsoleclear,
            rconsolewarn,
            warn,
            error,
        }
        
        local nextFunction = next
        local functionList = outputFunctions
        local currentIndex = nil

        while true do
            local key, value = nextFunction(outputFunctions, currentIndex)
            if key == nil then
                break
            end
            currentIndex = key

            local originalFunction = nil
            originalFunction = hookfunction(value, newcclosure(function(...)
                local nextArg = next
                local args = {...}
                local argIndex = nil

                while true do
                    local argKey, argValue
                    argIndex, argValue = nextArg(args, argIndex)
                    
                    if argIndex == nil then
                        break
                    end
                    
                    if tostring(argIndex):find('https') or tostring(argValue):find('https') then
                        rconsolewarn(detectionMessage)
                        error(detectionMessage)
                        warn(detectionMessage)
                        print(detectionMessage)
                        return rconsolewarn(detectionMessage)
                    end
                end
                return originalFunction(...)
            end))
        end

        local pairFunction, tableValue, index = pairs(outputFunctions)
        while true do
            local funcKey
            index, funcKey = pairFunction(tableValue, index)
            if index == nil then
                break
            end
            restorefunction(funcKey)
        end

        if stackResult:find('stack') then
            detectionTriggered = true

            hookfunction(http and http.request or function() end, newcclosure(function(requestParams)
                if checkcaller() then
                    return originalHttpRequest(requestParams)
                end
                requestParams.Url = detectionMessage
                return rconsolewarn(detectionMessage)
            end))
            
            hookfunction(game.HttpGet, newcclosure(function(self, url, ...)
                if checkcaller() then
                    return originalHttpGet(self, url, ...)
                else
                    return detectionMessage
                end
            end))

            local originalNamecall = nil
            originalNamecall = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
                if not methodCheck[getnamecallmethod()] then
                    return originalNamecall(self, ...)
                end
                rconsolewarn(detectionMessage)
                return detectionMessage
            end))

            local originalRequest = nil
            originalRequest = hookfunction(requestFunction, newcclosure(function(requestData)
                if typeof(requestData) ~= 'table' then
                    return originalRequest(requestData)
                end
                rconsolewarn(detectionMessage)
                requestData.Url = detectionMessage
                return originalRequest(requestData.Url)
            end))

            hookfunction(rconsolewarn, newcclosure(function()
                return detectionMessage
            end))
            
            hookfunction(rconsoleprint, newcclosure(function()
                return detectionMessage
            end))
        end
        
        if detectionTriggered then
            task.spawn(function()
                while true do
                    rconsoleinfo(detectionMessage)
                    task.wait()
                end
            end)
        end
    end
end)

local fileList = listfiles and listfiles('') or {}
local iterate, tableValue, index = ipairs(fileList)
local message = detectionMessage

while true do
    local fileName
    index, fileName = iterate(tableValue, index)
    if index == nil then
        break
    end
    if string.find(fileName:lower(), 'log') then
        return rconsoleprint(message .. 'fock u')
    end
end
