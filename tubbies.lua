local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local Lighting=game:GetService("Lighting")
local UIS=game:GetService("UserInputService")
local LP=Players.LocalPlayer
local repo='https://raw.githubusercontent.com/LionTheGreatRealFrFr/MobileLinoriaLib/main/'
local Library=loadstring(game:HttpGet(repo..'Library.lua'))()
local ThemeManager=loadstring(game:HttpGet(repo..'addons/ThemeManager.lua'))()
local SaveManager=loadstring(game:HttpGet(repo..'addons/SaveManager.lua'))()
getgenv().SlendyLibrary=Library
local ESP={
    Enabled=false,
    ShowNames=true,
    ShowDistance=true,
    ShowHealth=true,
    ShowHighlight=true,
    MaxDistance=5000,
    Labels={},
    Highlights={},
    Container=nil,
    TextColor=Color3.fromRGB(255,255,255),
    HighlightColor=Color3.fromRGB(255,255,255),
    HighlightTransparency=0.5,
}
local Walk={Enabled=false,Speed=60,Conn=nil,OrigWalk=nil}
local Custard={Enabled=false,Delay=0.15,Running=false,Thread=nil}
local WorldState={FullBright=false,Saved={}}
local _stopping=false
do
    local g=Instance.new("ScreenGui")
    g.Name="\0SlendyESP"
    g.ResetOnSpawn=false
    g.IgnoreGuiInset=true
    g.ZIndexBehavior=Enum.ZIndexBehavior.Global
    local ok=false
    if gethui then local s,h=pcall(gethui);if s and h then g.Parent=h;ok=true end end
    if not ok and syn and syn.protect_gui then pcall(function()syn.protect_gui(g)end);g.Parent=game:GetService("CoreGui")
    elseif not ok then g.Parent=game:GetService("CoreGui") end
    ESP.Container=g
end
local function getLocalTeam()
    local my=LP.Character
    if not my then return nil,nil end
    local root=Workspace:FindFirstChild("game")
    if not root then return nil,nil end
    local pf=root:FindFirstChild("Players")
    local mf=root:FindFirstChild("Monsters")
    if pf and (my==pf or my:IsDescendantOf(pf)) then return "Players",mf end
    if mf and (my==mf or my:IsDescendantOf(mf)) then return "Monsters",pf end
    return nil,mf or pf
end
local function getEnemies()
    local _,ef=getLocalTeam()
    if not ef then return {} end
    local list={}
    local lp=LP.Character
    for _,m in ipairs(ef:GetDescendants()) do
        if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
            if not lp or (m~=lp and not m:IsDescendantOf(lp)) then table.insert(list,m) end
        end
    end
    return list
end
local function createLabel(m)
    if ESP.Labels[m] and ESP.Labels[m].Parent then return ESP.Labels[m] end
    local l=Instance.new("TextLabel")
    l.Name="EnemyLabel"
    l.BackgroundTransparency=1
    l.AnchorPoint=Vector2.new(0.5,1)
    l.Size=UDim2.new(0,200,0,20)
    l.Font=Enum.Font.GothamBold
    l.TextSize=14
    l.TextColor3=ESP.TextColor
    l.TextStrokeTransparency=0
    l.TextStrokeColor3=Color3.new(0,0,0)
    l.Text=""
    l.Visible=false
    l.Parent=ESP.Container
    ESP.Labels[m]=l
    return l
end
local function createHighlight(m)
    if ESP.Highlights[m] and ESP.Highlights[m].Parent then return ESP.Highlights[m] end
    local h=Instance.new("Highlight")
    h.Name="EnemyHighlight"
    h.FillColor=ESP.HighlightColor
    h.OutlineColor=ESP.HighlightColor
    h.FillTransparency=ESP.HighlightTransparency
    h.OutlineTransparency=0
    h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee=m
    h.Parent=m
    ESP.Highlights[m]=h
    return h
end
local function getName(m)
    local h=m:FindFirstChildOfClass("Humanoid")
    if h and h.DisplayName and h.DisplayName~="" then return h.DisplayName end
    return m.Name
end
local function updateLabel(m)
    local l=ESP.Labels[m] or createLabel(m)
    if not ESP.Enabled or not m.Parent then l.Visible=false;return end
    local head=m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")
    if not head then l.Visible=false;return end
    local hum=m:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health<=0 then l.Visible=false;return end
    local cam=Workspace.CurrentCamera
    if not cam then l.Visible=false;return end
    local mc=LP.Character
    local mh=mc and mc:FindFirstChild("HumanoidRootPart")
    if not mh then l.Visible=false;return end
    local dist=(mh.Position-head.Position).Magnitude
    if dist>ESP.MaxDistance then l.Visible=false;return end
    local sp,on=cam:WorldToViewportPoint(head.Position+Vector3.new(0,1.5,0))
    if not on or sp.Z<=0 then l.Visible=false;return end
    local p={}
    if ESP.ShowNames then table.insert(p,getName(m)) end
    if ESP.ShowDistance then table.insert(p,string.format("[%d]",math.floor(dist))) end
    if ESP.ShowHealth then table.insert(p,string.format("%d HP",math.floor(hum.Health))) end
    if #p==0 then l.Visible=false;return end
    local t=table.concat(p," ")
    if l.Text~=t then l.Text=t end
    local px,py=math.floor(sp.X),math.floor(sp.Y)
    l.Position=UDim2.new(0,px,0,py-10)
    l.Visible=true
end
local function updateHighlight(m)
    if not ESP.Enabled or not ESP.ShowHighlight then
        if ESP.Highlights[m] and ESP.Highlights[m].Parent then
            ESP.Highlights[m].Enabled=false
        end
        return
    end
    if not m.Parent then return end
    local hum=m:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health<=0 then
        if ESP.Highlights[m] and ESP.Highlights[m].Parent then
            ESP.Highlights[m].Enabled=false
        end
        return
    end
    local h=ESP.Highlights[m] or createHighlight(m)
    h.Adornee=m
    h.Enabled=true
end
local function clearLabels()
    for m,l in pairs(ESP.Labels) do pcall(function()l:Destroy()end);ESP.Labels[m]=nil end
    for m,h in pairs(ESP.Highlights) do pcall(function()h:Destroy()end);ESP.Highlights[m]=nil end
end
RunService.RenderStepped:Connect(function()
    if not ESP.Enabled then
        for _,l in pairs(ESP.Labels) do if l and l.Parent then l.Visible=false end end
        for _,h in pairs(ESP.Highlights) do if h and h.Parent then h.Enabled=false end end
        return
    end
    local en=getEnemies()
    local set={}
    for _,m in ipairs(en) do set[m]=true;updateLabel(m);updateHighlight(m) end
    for m,l in pairs(ESP.Labels) do
        if not set[m] then pcall(function()l:Destroy()end);ESP.Labels[m]=nil end
    end
    for m,h in pairs(ESP.Highlights) do
        if not set[m] then pcall(function()h:Destroy()end);ESP.Highlights[m]=nil end
    end
end)
local function applyWalk()
    if Walk.Conn then pcall(function()Walk.Conn:Disconnect()end);Walk.Conn=nil end
    local c=LP.Character
    local h=c and c:FindFirstChildOfClass("Humanoid")
    if not Walk.Enabled then
        if h and Walk.OrigWalk then pcall(function()h.WalkSpeed=Walk.OrigWalk end)end
        Walk.OrigWalk=nil
        return
    end
    if h and not Walk.OrigWalk then Walk.OrigWalk=(h.WalkSpeed>0) and h.WalkSpeed or 16 end
    Walk.Conn=RunService.RenderStepped:Connect(function()
        local ch=LP.Character
        if not ch then return end
        local hrp=ch:FindFirstChild("HumanoidRootPart")
        local hu=ch:FindFirstChildOfClass("Humanoid")
        if not hrp or not hu or hu.Health<=0 then return end
        local cam=Workspace.CurrentCamera
        if not cam then return end
        local d=Vector3.zero
        local lv=Vector3.new(cam.CFrame.LookVector.X,0,cam.CFrame.LookVector.Z)
        local rv=Vector3.new(cam.CFrame.RightVector.X,0,cam.CFrame.RightVector.Z)
        if UIS:IsKeyDown(Enum.KeyCode.W) then d=d+lv end
        if UIS:IsKeyDown(Enum.KeyCode.S) then d=d-lv end
        if UIS:IsKeyDown(Enum.KeyCode.D) then d=d+rv end
        if UIS:IsKeyDown(Enum.KeyCode.A) then d=d-rv end
        if d.Magnitude>0 then hrp.AssemblyLinearVelocity=(d.Unit*Walk.Speed)+Vector3.new(0,hrp.AssemblyLinearVelocity.Y,0) end
    end)
end
local function findCustard()
    local r=Workspace:FindFirstChild("game")
    if not r then return nil end
    for _,n in ipairs({"gameCustard","Custards","custards","GameCustard"}) do
        local f=r:FindFirstChild(n)
        if f then return f end
    end
    return nil
end
local function startCustard()
    if Custard.Running then return end
    local f=findCustard()
    if not f then Library:Notify("Custard folder not found",3);return end
    Custard.Running=true
    Custard.Thread=task.spawn(function()
        while Custard.Running do
            local c=LP.Character
            local hrp=c and c:FindFirstChild("HumanoidRootPart")
            if not hrp then break end
            for _,it in ipairs(f:GetDescendants()) do
                if not Custard.Running then break end
                if it:IsA("BasePart") and it.Name:find("Custard") then
                    pcall(function()hrp.CFrame=CFrame.new(it.Position+Vector3.new(0,3,0))end)
                    task.wait(Custard.Delay)
                end
            end
            task.wait(0.5)
        end
        Custard.Running=false
    end)
end
local function stopCustard()
    Custard.Running=false
    if Custard.Thread then pcall(task.cancel,Custard.Thread);Custard.Thread=nil end
end
local function setFullBright(on)
    if on then
        WorldState.Saved={Brightness=Lighting.Brightness,ClockTime=Lighting.ClockTime,Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient,GlobalShadows=Lighting.GlobalShadows,FogEnd=Lighting.FogEnd,FogStart=Lighting.FogStart,FogColor=Lighting.FogColor,ExposureCompensation=Lighting.ExposureCompensation}
        Lighting.Brightness=3
        Lighting.ClockTime=12
        Lighting.Ambient=Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255)
        Lighting.GlobalShadows=false
        Lighting.FogEnd=100000
        Lighting.FogStart=100000
        Lighting.FogColor=Color3.fromRGB(255,255,255)
        Lighting.ExposureCompensation=0.5
    else
        for k,v in pairs(WorldState.Saved) do
            if Lighting[k]~=nil then pcall(function()Lighting[k]=v end)end
        end
    end
end
local function unloadAll()
    _stopping=true
    pcall(stopCustard)
    if Walk.Conn then pcall(function()Walk.Conn:Disconnect()end);Walk.Conn=nil end
    local c=LP.Character
    local h=c and c:FindFirstChildOfClass("Humanoid")
    if h and Walk.OrigWalk then pcall(function()h.WalkSpeed=Walk.OrigWalk end)end
    clearLabels()
    if ESP.Container then pcall(function()ESP.Container:Destroy()end);ESP.Container=nil end
    if WorldState.FullBright then pcall(function()setFullBright(false)end)end
end
Library:OnUnload(unloadAll)
local Window=Library:CreateWindow({Title='Slendytubbies',Center=true,AutoShow=true})
local Tabs={Main=Window:AddTab('Main'),Auto=Window:AddTab('Automation'),World=Window:AddTab('World'),Settings=Window:AddTab('UI Settings')}
local G=Tabs.Main:AddLeftGroupbox('Enemy ESP')
local ESPT=G:AddToggle('SlendyESP',{Text='Enable ESP',Default=false,Callback=function(v)ESP.Enabled=v;if not v then clearLabels()end end})
ESPT:OnChanged(function(v)ESP.Enabled=v;if not v then clearLabels()end end)
local SH=G:AddToggle('SlendyShowHighlight',{Text='Show Highlight',Default=true,Callback=function(v)ESP.ShowHighlight=v end})
SH:OnChanged(function(v)ESP.ShowHighlight=v end)
local NT=G:AddToggle('SlendyShowNames',{Text='Show Names',Default=true,Callback=function(v)ESP.ShowNames=v end})
NT:OnChanged(function(v)ESP.ShowNames=v end)
local DT=G:AddToggle('SlendyShowDist',{Text='Show Distance',Default=true,Callback=function(v)ESP.ShowDistance=v end})
DT:OnChanged(function(v)ESP.ShowDistance=v end)
local HT=G:AddToggle('SlendyShowHP',{Text='Show Health',Default=true,Callback=function(v)ESP.ShowHealth=v end})
HT:OnChanged(function(v)ESP.ShowHealth=v end)
local MD=G:AddSlider('SlendyMaxDist',{Text='Max Distance',Default=5000,Min=100,Max=10000,Rounding=0,Suffix=' studs',Callback=function(v)ESP.MaxDistance=v end})
MD:OnChanged(function(v)ESP.MaxDistance=v end)
local WG=Tabs.Main:AddRightGroupbox('Walk Speed')
local WT=WG:AddToggle('SlendyWalk',{Text='Enable Walk Speed',Default=false,Callback=function(v)Walk.Enabled=v;applyWalk()end})
WT:OnChanged(function(v)Walk.Enabled=v;applyWalk()end)
local WS=WG:AddSlider('SlendyWalkSpeed',{Text='Speed',Default=60,Min=16,Max=500,Rounding=0,Suffix=' studs/s',Callback=function(v)Walk.Speed=v end})
WS:OnChanged(function(v)Walk.Speed=v end)
local CG=Tabs.Auto:AddLeftGroupbox('Auto Custard')
local CT=CG:AddToggle('SlendyCustard',{Text='Auto Collect',Default=false,Callback=function(v)if v then startCustard()else stopCustard()end end})
CT:OnChanged(function(v)if v then startCustard()else stopCustard()end end)
local CD=CG:AddSlider('SlendyCustardDelay',{Text='Delay',Default=0.15,Min=0.02,Max=1,Rounding=2,Suffix='s',Callback=function(v)Custard.Delay=v end})
CD:OnChanged(function(v)Custard.Delay=v end)
local FG=Tabs.World:AddLeftGroupbox('Lighting')
local FB=FG:AddToggle('SlendyFullBright',{Text='Fullbright',Default=false,Callback=function(v)WorldState.FullBright=v;setFullBright(v)end})
FB:OnChanged(function(v)WorldState.FullBright=v;setFullBright(v)end)
local MG=Tabs.Settings:AddLeftGroupbox('Menu')
MG:AddButton('Unload',function()Library:Unload()end)
local MK=MG:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind',{Default='End',NoUI=true,Text='Menu keybind'})
Library.ToggleKeybind=MK
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({'MenuKeybind'})
SaveManager:SetFolder('slendy-esp')
ThemeManager:SetFolder('slendy-esp')
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
LP.CharacterAdded:Connect(function()
    Walk.OrigWalk=nil
    task.wait(0.5)
    if Walk.Enabled then applyWalk()end
end)
