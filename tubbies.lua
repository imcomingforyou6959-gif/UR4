

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local RenderStepped = RunService.RenderStepped
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService('Workspace')
local Lighting = game:GetService('Lighting')

local _40, _ = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Adonis.lua", true))()
end)

local repo = 'https://raw.githubusercontent.com/LionTheGreatRealFrFr/MobileLinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'Slendytubbies',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

local Tabs = {
    Monster = Window:AddTab('Monster ESP'),
    Automation = Window:AddTab('Automation'),
    World = Window:AddTab('World'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- Monster ESP logic
local ESP = {
    Enabled = false,
    ShowName = true,
    ShowDistance = true,
    ShowHighlight = true,
    HighlightColor = Color3.fromRGB(255, 60, 60),
    TextColor = Color3.fromRGB(255, 255, 255),
    MaxDistance = 5000,
    Connections = {},
    Active = {},
}

local function getMonsterContainer()
    local root = Workspace:FindFirstChild('game')
    if root then
        root = root:FindFirstChild('Monsters')
    end
    return root
end

local function isMonster(model)
    if not model or not model:IsA('Model') then return false end
    local container = getMonsterContainer()
    if not container then return false end
    return model.Parent == container
end

local function getNameFor(monster)
    local hum = monster:FindFirstChildOfClass('Humanoid')
    if hum and hum.DisplayName and hum.DisplayName ~= '' then
        return hum.DisplayName
    end
    return monster.Name
end

local function createESP(monster)
    if ESP.Active[monster] then return end

    local billboard = Instance.new('BillboardGui')
    billboard.Name = 'Slendytubbies_ESP'
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.LightInfluence = 0
    billboard.Adornee = monster:FindFirstChild('HumanoidRootPart') or monster:FindFirstChild('Head')
    billboard.Parent = monster

    local label = Instance.new('TextLabel')
    label.Name = 'NameLabel'
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 16
    label.TextColor3 = ESP.TextColor
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Text = getNameFor(monster)
    label.Parent = billboard

    local highlight = Instance.new('Highlight')
    highlight.Name = 'Slendytubbies_Highlight'
    highlight.FillColor = ESP.HighlightColor
    highlight.FillTransparency = 0.6
    highlight.OutlineColor = ESP.HighlightColor
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = monster
    highlight.Parent = monster

    ESP.Active[monster] = {
        Billboard = billboard,
        Label = label,
        Highlight = highlight,
    }
end

local function removeESP(monster)
    local entry = ESP.Active[monster]
    if not entry then return end
    pcall(function() entry.Billboard:Destroy() end)
    pcall(function() entry.Highlight:Destroy() end)
    ESP.Active[monster] = nil
end

local function clearAllESP()
    for monster in pairs(ESP.Active) do
        removeESP(monster)
    end
end

local function refreshAllESP()
    clearAllESP()
    if not ESP.Enabled then return end
    local container = getMonsterContainer()
    if not container then return end
    for _, monster in ipairs(container:GetChildren()) do
        if monster:IsA('Model') then
            createESP(monster)
        end
    end
end

local function updateESPFrame()
    if not ESP.Enabled then return end
    local myChar = LocalPlayer.Character
    local myPos = myChar and myChar:FindFirstChild('HumanoidRootPart')
    myPos = myPos and myPos.Position or Vector3.zero

    for monster, entry in pairs(ESP.Active) do
        if not monster.Parent or not isMonster(monster) then
            removeESP(monster)
        else
            local hrp = monster:FindFirstChild('HumanoidRootPart')
            if hrp then
                entry.Billboard.Adornee = hrp
                local dist = (hrp.Position - myPos).Magnitude

                local parts = {}
                if ESP.ShowName then
                    table.insert(parts, getNameFor(monster))
                end
                if ESP.ShowDistance then
                    table.insert(parts, string.format('[%d]', math.floor(dist)))
                end

                entry.Label.Text = table.concat(parts, ' ')

                if dist > ESP.MaxDistance then
                    entry.Billboard.Enabled = false
                    entry.Highlight.Enabled = false
                else
                    entry.Billboard.Enabled = true
                    entry.Highlight.Enabled = ESP.ShowHighlight
                end
            end
        end
    end
end

task.spawn(function()
    while not getMonsterContainer() do
        task.wait(0.5)
    end
    local container = getMonsterContainer()
    table.insert(ESP.Connections, container.ChildAdded:Connect(function(child)
        if ESP.Enabled and child:IsA('Model') then
            task.defer(function()
                if child.Parent then
                    createESP(child)
                end
            end)
        end
    end))
    table.insert(ESP.Connections, container.ChildRemoved:Connect(function(child)
        if ESP.Active[child] then
            removeESP(child)
        end
    end))
end)

table.insert(ESP.Connections, RenderStepped:Connect(updateESPFrame))

-- Monster esp
local MonsterGroup = Tabs.Monster:AddLeftGroupbox('Monster ESP')

local MonsterESPToggle = MonsterGroup:AddToggle('MonsterESP', {
    Text = 'Enable Monster ESP',
    Default = false,
    Tooltip = 'Draws name labels and highlights on every monster',
})

local MonsterESPNameToggle = MonsterGroup:AddToggle('MonsterESPName', {
    Text = 'Show Name',
    Default = true,
})

local MonsterESPDistToggle = MonsterGroup:AddToggle('MonsterESPDistance', {
    Text = 'Show Distance',
    Default = true,
})

local MonsterESPHighlightToggle = MonsterGroup:AddToggle('MonsterESPHighlight', {
    Text = 'Show Highlight',
    Default = true,
})

local MonsterESPMaxDistSlider = MonsterGroup:AddSlider('MonsterESPMaxDist', {
    Text = 'Max Render Distance',
    Default = 5000,
    Min = 100,
    Max = 10000,
    Rounding = 0,
    Suffix = ' studs',
})

MonsterGroup:AddLabel('Highlight Color'):AddColorPicker('MonsterESPColor', {
    Default = Color3.fromRGB(255, 60, 60),
    Title = 'Highlight Color',
    Callback = function(c)
        ESP.HighlightColor = c
        for _, entry in pairs(ESP.Active) do
            entry.Highlight.FillColor = c
            entry.Highlight.OutlineColor = c
        end
    end,
})

MonsterGroup:AddLabel('Text Color'):AddColorPicker('MonsterESPText', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Text Color',
    Callback = function(c)
        ESP.TextColor = c
        for _, entry in pairs(ESP.Active) do
            entry.Label.TextColor3 = c
        end
    end,
})

-- Automation logic
local Custard = {
    Enabled = false,
    Delay = 0.15,
    Running = false,
    Thread = nil,
    OriginCFrame = nil,
    Collected = 0,
}

local function getCustardContainer()
    local root = Workspace:FindFirstChild('game')
    if not root then return end
    return root:FindFirstChild('gameCustard')
end

local function collectCustards()
    local container = getCustardContainer()
    if not container then return {} end
    local list = {}
    for _, child in ipairs(container:GetChildren()) do
        if child.Name == 'CustardPrefab' or (child:IsA('BasePart') and child.Name:find('Custard')) then
            table.insert(list, child)
        end
    end
    return list
end

local function getMyHRP()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild('HumanoidRootPart')
end

local function teleportToCustard(part)
    if not part or not part.Parent then return false end
    local hrp = getMyHRP()
    if not hrp then return false end

    if not Custard.OriginCFrame then
        Custard.OriginCFrame = hrp.CFrame
    end

    hrp.Anchored = true
    hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, part.Size.Y * 0.5 + 3, 0))
    Custard.Collected = Custard.Collected + 1
    task.wait(Custard.Delay)
    return true
end

local function custardLoop()
    while Custard.Running and Custard.Enabled do
        local parts = collectCustards()
        if #parts == 0 then
            task.wait(0.5)
        else
            for _, part in ipairs(parts) do
                if not Custard.Running then break end
                if part and part.Parent then
                    teleportToCustard(part)
                end
            end
        end
        task.wait(0.1)
    end
end

local function startCustard()
    if Custard.Running then return end
    local hrp = getMyHRP()
    if not hrp then return end
    Custard.OriginCFrame = hrp.CFrame
    Custard.Running = true
    Custard.Collected = 0
    Custard.Thread = task.spawn(function()
        pcall(custardLoop)
        Custard.Running = false
    end)
end

local function stopCustard()
    Custard.Running = false
    Custard.Thread = nil
    local hrp = getMyHRP()
    if hrp then
        pcall(function()
            if Custard.OriginCFrame then
                hrp.Anchored = true
                hrp.CFrame = Custard.OriginCFrame
            end
            hrp.Anchored = false
        end)
    end
end

-- Automation UI
local AutomationGroup = Tabs.Automation:AddLeftGroupbox('Auto Custard')

local AutoCustardToggle = AutomationGroup:AddToggle('AutoCustard', {
    Text = 'Auto Custard',
    Default = false,
    Tooltip = 'Teleports to le custard',
})

local CustardDelaySlider = AutomationGroup:AddSlider('CustardDelay', {
    Text = 'Delay per Custard',
    Default = 0.15,
    Min = 0.02,
    Max = 1,
    Rounding = 2,
    Suffix = 's',
})

local custardStatus = AutomationGroup:AddLabel('Collected: 0')

task.spawn(function()
    while true do
        task.wait(0.25)
        custardStatus:SetText(string.format(
            'Collected: %d | Running: %s',
            Custard.Collected,
            Custard.Running and 'Yes' or 'No'
        ))
    end
end)

-- World logic
local worldState = {
    FullBright = false,
    SavedClock = Lighting.ClockTime,
    SavedBrightness = Lighting.Brightness,
    SavedAmbient = Lighting.Ambient,
    SavedOutdoorAmbient = Lighting.OutdoorAmbient,
    SavedGlobalShadows = Lighting.GlobalShadows,
    SavedFogEnd = Lighting.FogEnd,
}

local function setFullBright(enabled)
    if enabled then
        worldState.SavedClock = Lighting.ClockTime
        worldState.SavedBrightness = Lighting.Brightness
        worldState.SavedAmbient = Lighting.Ambient
        worldState.SavedOutdoorAmbient = Lighting.OutdoorAmbient
        worldState.SavedGlobalShadows = Lighting.GlobalShadows
        worldState.SavedFogEnd = Lighting.FogEnd

        Lighting.ClockTime = 12
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
    else
        Lighting.ClockTime = worldState.SavedClock
        Lighting.Brightness = worldState.SavedBrightness
        Lighting.Ambient = worldState.SavedAmbient
        Lighting.OutdoorAmbient = worldState.SavedOutdoorAmbient
        Lighting.GlobalShadows = worldState.SavedGlobalShadows
        Lighting.FogEnd = worldState.SavedFogEnd
    end
end

-- World UI
local WorldGroup = Tabs.World:AddLeftGroupbox('Lighting')

local FullBrightToggle = WorldGroup:AddToggle('FullBright', {
    Text = 'Fullbright',
    Default = false,
    Tooltip = 'Removes fog and shadows, brightens everything',
})

local TimeSlider = WorldGroup:AddSlider('TimeSlider', {
    Text = 'Time of Day',
    Default = 12,
    Min = 0,
    Max = 24,
    Rounding = 1,
})

local like6767hahah = Tabs['UI Settings']:AddLeftGroupbox('Menu')

like6767hahah:AddButton('Unload', function()
    stopCustard()
    Library:Unload()
end)

local MenuKeybind = like6767hahah:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
    Default = 'End',
    NoUI = true,
    Text = 'Menu keybind',
})

Library.ToggleKeybind = MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
SaveManager:SetFolder('SlendytubbiesScript')
ThemeManager:SetFolder('SlendytubbiesScript')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])
SaveManager:LoadAutoloadConfig()

-- Wiring
MonsterESPToggle:OnChanged(function()
    ESP.Enabled = MonsterESPToggle.Value
    refreshAllESP()
end)

MonsterESPNameToggle:OnChanged(function()
    ESP.ShowName = MonsterESPNameToggle.Value
end)

MonsterESPDistToggle:OnChanged(function()
    ESP.ShowDistance = MonsterESPDistToggle.Value
end)

MonsterESPHighlightToggle:OnChanged(function()
    ESP.ShowHighlight = MonsterESPHighlightToggle.Value
    for _, entry in pairs(ESP.Active) do
        entry.Highlight.Enabled = ESP.ShowHighlight
    end
end)

MonsterESPMaxDistSlider:OnChanged(function()
    ESP.MaxDistance = MonsterESPMaxDistSlider.Value
end)

AutoCustardToggle:OnChanged(function()
    Custard.Enabled = AutoCustardToggle.Value
    if Custard.Enabled then
        startCustard()
    else
        stopCustard()
    end
end)

CustardDelaySlider:OnChanged(function()
    Custard.Delay = CustardDelaySlider.Value
end)

FullBrightToggle:OnChanged(function()
    worldState.FullBright = FullBrightToggle.Value
    setFullBright(worldState.FullBright)
end)

TimeSlider:OnChanged(function()
    if not worldState.FullBright then
        Lighting.ClockTime = TimeSlider.Value
    end
end)

Library:OnUnload(function()
    stopCustard()
    clearAllESP()
    for _, conn in ipairs(ESP.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    if worldState.FullBright then
        setFullBright(false)
    end
    Library.Unloaded = true
end)
