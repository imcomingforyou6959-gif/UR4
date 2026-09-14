local x,y
getthreadidentity(2)
for i,v in pairs(getgc(true)) do 
    if typeof(v) == "table" then
        local a, b = rawget(v, "Detected"), rawget(v, "Kill")
        if typeof(a) == "function" and not x then
            x = a 
            hookfunction(x, function() return true end)
        end
        if typeof(b) == "function" and rawget(v, "Variables") and not y then
            y = b
            hookfunction(y, function () end)
        end
    end
end
local o; o = hookfunction(getrenv().debug.info, newcclosure(function(a, ...)
    if x and a == x then return coroutine.yield(coroutine.running()) end
    return o(a, ...)
end))
getthreadidentity(7)
