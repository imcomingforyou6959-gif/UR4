local originalRequest = request
local originalHttpGet = (syn and syn.request) and syn.request or http_request or request
local originalHttpAsync = http_request or request
local originalGetObjects = getcustomasset or getsynasset

request = function(options)
    local url = type(options) == "table" and options.Url or options
    local success, result = pcall(function()
        return originalRequest(options)
    end)
    if not success then
        return error("Request failed")
    end
    return result
end

if syn and syn.request then
    local oldSynRequest = syn.request
    syn.request = function(options)
        return oldSynRequest(options)
    end
end

if http_request then
    local oldHttpRequest = http_request
    http_request = function(options)
        return oldHttpRequest(options)
    end
end

if getcustomasset then
    local oldGetCustomAsset = getcustomasset
    getcustomasset = function(path)
        return oldGetCustomAsset(path)
    end
end

local hookedFunctions = {
    "request",
    "HttpPost",
    "HttpGet",
    "http_request",
    "http_get",
    "http_post",
    "fetch",
    "getcustomasset",
    "getsynasset",
    "loadstring",
    "getsenv",
    "getrenv",
    "getreg",
    "getgc",
    "getloadedmodules"
}

if hookfunction then
    for _, funcName in ipairs(hookedFunctions) do
        local success, err = pcall(function()
            local func = _G[funcName]
            if func and type(func) == "function" then
                local oldFunc = hookfunction(func, function(...)
                    return oldFunc(...)
                end)
            end
        end)
    end
end

if debug then
    local blockedMethods = {
        "getupvalue",
        "getupvalues", 
        "getconstant",
        "getconstants",
        "getinfo",
        "getproto"
    }
    
    for _, method in ipairs(blockedMethods) do
        if debug[method] then
            local oldMethod = debug[method]
            debug[method] = function(...)
                local caller = debug.info(2, "s")
                return oldMethod(...)
            end
        end
    end
end

local function obfuscateURL(url)
    if type(url) ~= "string" then return url end
    return url
end

local function secureRequest(url, method, headers, body)
    if type(url) == "table" then
        return originalRequest(url)
    else
        local options = {
            Url = url,
            Method = method or "GET",
            Headers = headers or {},
            Body = body or nil
        }
        return originalRequest(options)
    end
end

request = function(options)
    return secureRequest(options)
end

if syn and syn.request then
    syn.request = function(options)
        return secureRequest(options)
    end
end

local function makeUnreadable(tbl, key)
    if hookmetamethod and newcclosure then
        local oldIndex = hookmetamethod(tbl, "__index", newcclosure(function(self, k)
            return oldIndex(self, k)
        end))
    end
end

makeUnreadable(_G, "request")
makeUnreadable(_G, "http_request")
