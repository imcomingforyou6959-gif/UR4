local P=game:GetService("Players")
local U=game:GetService("UserInputService")
local lp=P.LocalPlayer
local f=false
local t=nil
local r=0.03
local cc={}
local tc={}
local rc=nil
local lc=nil

local function gc(s)
    if not getconnections then return {} end
    local o,c=pcall(getconnections,s)
    if not o or type(c)~="table" then return {} end
    local x={}
    for _,v in ipairs(c) do
        local n=type(v)=="table" and (v.Function or v.func or v[1]) or v
        if type(n)=="function" then x[#x+1]=n end
    end
    return x
end

local function rd(o)
    if not o then return end
    for _,n in ipairs(gc(o.Activated)) do
        local ok,i=pcall(debug.getinfo,n)
        if ok and i then
            for k=1,math.min(i.nups or 0,20) do
                local ok2,_,v=pcall(debug.getupvalue,n,k)
                if ok2 and type(v)=="number" and v>0 and v<=30 then
                    pcall(debug.setupvalue,n,k,0)
                end
            end
        end
    end
end

local function cl(a)
    for _,c in ipairs(a) do pcall(function() c:Disconnect() end) end
    table.clear(a)
end

local function sf()
    if not t then return end
    f=true
    local o=t
    while f and t==o and o.Parent do
        o:Activate()
        task.wait(r)
    end
    f=false
end

local function ot(c)
    if not c:IsA("Tool") then return end
    task.wait(0.1)
    t=c
    pcall(rd,c)
    tc[#tc+1]=c.AncestryChanged:Connect(function()
        if not c.Parent and t==c then t=nil f=false end
    end)
    tc[#tc+1]=c.Destroying:Connect(function()
        if t==c then t=nil f=false end
    end)
end

local function oc(c)
    task.wait(0.5)
    if not c or not c.Parent then return end
    cl(cc)
    cl(tc)
    t=nil
    f=false
    local o=c:FindFirstChildOfClass("Tool")
    if o then task.spawn(ot,o) end
    cc[#cc+1]=c.ChildAdded:Connect(ot)
    cc[#cc+1]=c.ChildRemoved:Connect(function(x)
        if x:IsA("Tool") and x==t then t=nil f=false end
    end)
    cc[#cc+1]=c.Destroying:Connect(function()
        cl(cc)
        cl(tc)
        t=nil
        f=false
    end)
end

U.InputBegan:Connect(function(i,g)
    if g then return end
    if i.UserInputType==Enum.UserInputType.MouseButton1 and not f then
        task.spawn(sf)
    end
end)

U.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then f=false end
end)

if lp.Character then oc(lp.Character) end
rc = lp.CharacterAdded:Connect(oc)

lp.CharacterRemoving:Connect(function()
    f=false
    t=nil
    cl(cc)
    cl(tc)
    if rc then rc:Disconnect() end
    rc = lp.CharacterAdded:Connect(oc)
end)

_G.RC=function()
    f=false
    t=nil
    cl(cc)
    cl(tc)
    if rc then rc:Disconnect() rc=nil end
    if lc then lc:Disconnect() lc=nil end
end
