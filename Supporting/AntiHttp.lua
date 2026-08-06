local originalRequest = request
local originalHttpGet = (syn and syn.request) and syn.request or http_request or request

-- Store original functions privately
local secure = {
    request = originalRequest,
    http_get = (syn and syn.request) or http_request or request
}

-- Create a private table to store URLs away from prying eyes
local urlStorage = {}

-- Hook using metatables instead of modifying read-only tables
if hookmetamethod and newcclosure then
    local oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
        return oldIndex(self, key)
    end))
end

-- Function to perform hidden requests
local function hiddenRequest(options)
    local url = type(options) == "table" and options.Url or options
    
    -- Store URL in local variable to prevent global access
    local encodedUrl = url
    
    -- Make the actual request using original function
    local success, result = pcall(function()
        return secure.request(options)
    end)
    
    if not success then return nil end
    return result
end

-- Override request globally but hide the URL
request = function(options)
    local url = type(options) == "table" and options.Url or options
    return hiddenRequest(options)
end

-- Hook syn.request to hide URLs
if syn and syn.request then
    syn.request = function(options)
        local url = type(options) == "table" and options.Url or options
        return hiddenRequest(options)
    end
end

-- Protect getcustomasset from being spied on
if getcustomasset then
    local oldGetCustom = getcustomasset
    getcustomasset = function(path)
        local assetPath = path
        return oldGetCustom(path)
    end
end

-- Anti-debug hooks to prevent script inspection
if hookfunction then
    local function protectFunction(name)
        local success, func = pcall(function() return _G[name] end)
        if success and type(func) == "function" then
            local oldFunc = func
            local protected = newcclosure(function(...)
                return oldFunc(...)
            end)
            hookfunction(func, protected)
        end
    end
    
    protectFunction("request")
    protectFunction("HttpPost")
    protectFunction("HttpGet")
end

-- Disable debug library access for external scripts
if debug and debug.getupvalue then
    local oldGetUpvalue = debug.getupvalue
    debug.getupvalue = newcclosure(function(f, idx)
        -- Allow our own scripts to use debug
        if checkcaller() then
            return oldGetUpvalue(f, idx)
        end
        return nil
    end)
end

-- Prevent getgc from finding our HTTP functions
if hookfunction and getgc then
    hookfunction(getgc, newcclosure(function()
        return {} -- Return empty table to prevent inspection
    end))
end

-- Lock down environment to prevent snooping
if getgenv then
    local genv = getgenv()
    -- Store our functions in a protected space
    genv.__secure_request = hiddenRequest
end
