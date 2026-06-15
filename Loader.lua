local U1 = ""

local function load_script()
    local ok, err = pcall(function()
        loadstring(game:HttpGet(U1))()
    end)
    if not ok then warn("Load failed: " .. tostring(err)) end
end

local qot = queue_on_teleport or syn.queue_on_teleport or fluxus.queue_on_teleport or krnl.queue_on_teleport

if qot then
    local ok, err = pcall(qot, [[loadstring(game:HttpGet("]] .. U1 .. [["))()]])
    if not ok then warn("Queue failed: " .. tostring(err)) end
end

load_script()
