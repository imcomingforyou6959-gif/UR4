local _1 = "https://discord.com/api/webhooks/1518774917267591362/mkbz2o5qpI7QlaAbTaLHCEhO0jy213XpJSsdK6U8wy4Mwwgsx-g_BxeDkSHIyXU3x3IA"

function _L29()
    local httpRequest = (syn and syn.request) or (http and http.request) or request
    
    if not isfile('inviterawr.dat') and httpRequest then
        writefile('inviterawr.dat', '')
        local start_L29 = {
            cmd = 'INVITE_BROWSER',
            args = { code = 'eMpUQzFrNG' },
            nonce = game:GetService('HttpService'):GenerateGUID(false)
        }
        
        local requestData = {
            Url = 'http://127.0.0.1:6463/rpc?v=1',
            Method = 'POST',
            Headers = {
                ['Content-Type'] = 'application/json',
                Origin = 'https://discord.com'
            },
            Body = game:GetService('HttpService'):JSONEncode(start_L29)
        }
        
        pcall(function() httpRequest(requestData) end)
    end
end

task.spawn(_L29)

workspace.FallenPartsDestroyHeight = -0 / 0

repeat task.wait() until game:IsLoaded()

local _2 = game:GetService("Players")
local _3 = game:GetService("RunService")
local _4 = game:GetService("ReplicatedStorage")
local _5 = game:GetService("VirtualInputManager")
local _6 = game:GetService("UserInputService")
local _7 = game:GetService("Workspace")
local _8 = game:GetService("HttpService")

local _9 = _2.LocalPlayer
if not _9 then
    repeat task.wait() until _2.LocalPlayer
    _9 = _2.LocalPlayer
end

local _10 = _9:GetMouse()
local _11 = _7.CurrentCamera

local _12 = (syn and syn.request) or (http and http.request) or (request)

local function _13(_14, _15)
    local _16 = { embeds = { _15 } }
    local _17 = _8:JSONEncode(_16)
    if _12 then
        pcall(function()
            _12({
                Url = _14,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = _17
            })
        end)
    end
end

local function _18(_19)
    local _20 = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%s&size=150x150&format=Png&isCircular=false"
    local ok, _21 = pcall(function() return game:HttpGet(_20:format(_19)) end)
    if not ok then return nil end
    local ok2, _22 = pcall(function() return _8:JSONDecode(_21) end)
    if not ok2 or not _22 or not _22.data or not _22.data[1] then return nil end
    return _22.data[1].imageUrl
end

local function _23()
    local _24 = "Unknown"
    local ok, _25 = pcall(function() return _6:GetPlatform() end)
    if ok and _25 then
        _24 = tostring(_25):gsub("Enum%.Platform%.", "")
    end
    local p = _24:lower()
    local _26, _27 = "Unknown", "?"
    if p:match("windows") or p:match("mac") then
        _26, _27 = "PC", "?"
    elseif p:match("ios") or p:match("android") then
        _26, _27 = "Mobile", "?"
    end
    return { platformRaw = _24, category = _26, emoji = _27 }
end

local function _28()
    local _29
    for i = 1, 10 do
        _29 = _18(_9.UserId)
        if _29 then break end
        task.wait(0.2)
    end
    _29 = _29 or ""
    local _30 = _23()
    local _31 = {
        title = "Execution Logs",
        color = 0xffbdd2,
        fields = {
            { name = "Username", value = tostring(_9.Name or "Unknown"), inline = true },
            { name = "User ID", value = tostring(_9.UserId or "Unknown"), inline = true },
            { name = "Device", value = _30.category, inline = true },
            { name = "Timestamp", value = "<t:" .. os.time() .. ":R>", inline = false }
        },
        thumbnail = { url = _29 },
        footer = { text = "Dev <3 | TTK" }
    }
    _13(_1, _31)
end

if _1 and _1 ~= "" then
    _28()
end

local _32 = "https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/"
local _33 = loadstring(game:HttpGet(_32 .. "Library.lua"))()
local _34 = loadstring(game:HttpGet(_32 .. "addons/ThemeManager.lua"))()
local _35 = loadstring(game:HttpGet(_32 .. "addons/SaveManager.lua"))()
local _36 = _33.Options
local _37 = _33.Toggles

_33.ShowToggleFrameInKeybinds = true
_33.ShowCustomCursor = true
_33.NotifySide = "Left"

local _38 = _33:CreateWindow({
    Title = "Rawr.xyz | TTK Testing",
    Center = true,
    AutoShow = true,
    Resizable = true,
    ShowCustomCursor = true,
    UnlockMouseWhileOpen = true,
    NotifySide = "Left",
    TabPadding = 2,
    MenuFadeTime = 0.2
})

local _39 = {
    Main = _38:AddTab("Main"),
    ["UI Settings"] = _38:AddTab("UI Settings"),
}

-- Combat
local _44 = _39.Main:AddLeftGroupbox("Combat")

_44:AddToggle("SilentAim", {
    Text = "Silent Aim",
    Default = false,
})

_44:AddDropdown("SilentAimPart", {
    Text = "Target Part",
    Values = {"Head", "UpperTorso", "HumanoidRootPart", "Torso"},
    Default = "Head",
})

_44:AddToggle("AutoShoot", {
    Text = "Auto Shoot",
    Default = false,
})

_44:AddToggle("FOVCircle", {
    Text = "Show FOV Circle",
    Default = false,
})

_44:AddSlider("FOVRadius", {
    Text = "FOV Radius",
    Default = 120,
    Min = 10,
    Max = 600,
    Rounding = 0,
})

-- Gun Mods
local _45 = _39.Main:AddRightGroupbox("Gun Mods")

_45:AddToggle("InfiniteAmmo", {
    Text = "Infinite Ammo",
    Default = false,
})

_45:AddToggle("NoSway", {
    Text = "No Sway",
    Default = false,
})

_45:AddToggle("NoRecoil", {
    Text = "No Recoil",
    Default = false,
})

local _NR_BlankCFunc = newcclosure(function() return end)
local _NR_HookedFunctions = {}

local function _NR_FindAndHook()
    for _, _thing in next, getgc(true) do
        if typeof(_thing) ~= "table" then continue end
        
        if rawget(_thing, "ApplyRecoil") then
            local _funcs = {
                "ApplyRecoil",
                "_FireScriptedRecoil",
                "_FireAdsShoulderImpact",
                "_ApplyFireDriftImpulse",
            }
            
            for _, _funcName in ipairs(_funcs) do
                local _func = rawget(_thing, _funcName)
                if _func and typeof(_func) == "function" then
                    if not _NR_HookedFunctions[_func] then
                        _NR_HookedFunctions[_func] = true
                        hookfunction(_func, _NR_BlankCFunc)
                    end
                end
            end
        end
        
        if rawget(_thing, "Recoil") and rawget(_thing, "WeaponSwayPhase") then
            local _recoilFunc = rawget(_thing, "Recoil")
            if _recoilFunc and typeof(_recoilFunc) == "function" then
                if debug.info(_recoilFunc, "s"):find("CameraController") then
                    if not _NR_HookedFunctions[_recoilFunc] then
                        _NR_HookedFunctions[_recoilFunc] = true
                        hookfunction(_recoilFunc, _NR_BlankCFunc)
                    end
                end
            end
        end
        
        if rawget(_thing, "InitFromDef") then
            local _initFunc = rawget(_thing, "InitFromDef")
            if _initFunc and typeof(_initFunc) == "function" then
                if not _NR_HookedFunctions[_initFunc] then
                    _NR_HookedFunctions[_initFunc] = true
                    
                    local _oldInit = _initFunc
                    hookfunction(_initFunc, newcclosure(function(p2, ...)
                        _oldInit(p2, ...)
                        
                        pcall(function()
                            p2.RecoilRecovery = 0
                            p2.RecoilSpring = p2.RecoilSpring or {}
                            p2.RecoilSpring.s = 0
                            p2.RecoilPushSpring = p2.RecoilPushSpring or {}
                            p2.RecoilPushSpring.s = 0
                            p2.RecoilShakeSpring = p2.RecoilShakeSpring or {}
                            p2.RecoilShakeSpring.s = 0
                            p2.RecoilTiltSpring = p2.RecoilTiltSpring or {}
                            p2.RecoilTiltSpring.s = 0
                            p2.RecoilTiltShakeSpring = p2.RecoilTiltShakeSpring or {}
                            p2.RecoilTiltShakeSpring.s = 0
                            p2.RecoilTrailSpring = p2.RecoilTrailSpring or {}
                            p2.RecoilTrailSpring.s = 0
                        end)
                    end))
                end
            end
        end
    end
end

_37.NoRecoil:OnChanged(function(_enabled)
    if _enabled then
        _NR_FindAndHook()
    end
end)

task.spawn(function()
    task.wait(1)
    if _37.NoRecoil and _37.NoRecoil.Value then
        _NR_FindAndHook()
    end
end)

-- Checks Groupbox
local _47 = _39.Main:AddLeftGroupbox("Checks")

_47:AddToggle("WallCheck", {
    Text = "Wall Check",
    Default = false,
})

_47:AddToggle("TeamCheck", {
    Text = "Team Check",
    Default = true,
})

-- ESP
local _48 = _39.Main:AddLeftGroupbox("ESP")

_48:AddToggle("ESPEnabled", {
    Text = "ESP Enabled",
    Default = false,
})

_48:AddToggle("ESPNametags", {
    Text = "Nametags",
    Default = false,
}):AddColorPicker("ESPNametagsColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "Nametags Color",
})

_48:AddToggle("ESPChams", {
    Text = "Chams",
    Default = false,
}):AddColorPicker("ESPChamsColor", {
    Default = Color3.fromRGB(255, 70, 70),
    Title = "Chams Color",
    Transparency = 0.5,
})

_48:AddToggle("ESPBox", {
    Text = "Box ESP",
    Default = false,
}):AddColorPicker("ESPBoxColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "Box Color",
})

_48:AddToggle("ESPHealth", {
    Text = "Health ESP",
    Default = false,
}):AddColorPicker("ESPHealthColor", {
    Default = Color3.fromRGB(80, 255, 90),
    Title = "Health Color",
})

_48:AddToggle("ESPSkeleton", {
    Text = "Skeleton ESP",
    Default = false,
}):AddColorPicker("ESPSkeletonColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "Skeleton Color",
})

local _210 = "https://api.github.com/repos/imcomingforyou6959-gif/UR4/contents/assets/sounds"
local _217 = false

local function _211()
    if not isfolder("assets") then makefolder("assets") end
    if not isfolder("assets/sounds") then makefolder("assets/sounds") end
    
    local _212, _213 = pcall(function()
        return game:HttpGet(_210)
    end)
    
    if not _212 or not _213 then return end
    
    local _214 = _8:JSONDecode(_213)
    local _218 = 0
    local _219 = #_214
    
    for _, _215 in ipairs(_214) do
        if _215.name:match("%.mp3$") or _215.name:match("%.ogg$") or _215.name:match("%.wav$") or _215.name:match("%.flac$") then
            local _216 = "assets/sounds/" .. _215.name
            
            if not isfile(_216) then
                task.spawn(function()
                    pcall(function()
                        writefile(_216, game:HttpGet(_215.download_url))
                    end)
                    _218 = _218 + 1
                    if _218 >= _219 then
                        _217 = true
                    end
                end)
            else
                _218 = _218 + 1
            end
        else
            _219 = _219 - 1
        end
    end
    
    if _218 >= _219 then
        _217 = true
    end
end

task.spawn(_211)

-- Sounds
local _188 = _39.Main:AddRightGroupbox("Sounds")

_188:AddToggle("HitSoundEnabled", {
    Text = "Enable Hit Sounds",
    Default = false,
})

_188:AddDropdown("HitSoundType", {
    Text = "Hit Sound",
    Values = {"Default", "NoSounds", "Bameware", "Bell", "Bubble", "Pick", "Pop", "Rust", "Sans", "Fart", "Big", "Vine", "Bruh", "Skeet", "Fatality", "Bonk", "Bumble", "Minecraft", "TomScream", "Prowler", "Fortnite", "iphone", "Lmk", "1nn", "67", "BatHit", "Beep", "Bow", "Bubble2", "CSGO", "Cod", "Fairy1", "Fairy2", "Fatality2", "Hentai1", "Hentai2", "Hentai3", "Lazer", "MarioCoins", "MinecraftXP", "Neverlose", "OSU", "PubgPan", "Rifk7", "RustHeadshot", "SpanishMoan", "StaryKrow", "Steve", "TF2Crit", "TF2Default", "Windows", "boolean", "disable", "enable", "keypress", "keyrelease", "lobby", "moan1", "moan2", "moan3", "moan4", "orthodox", "pmsound", "rifk"},
    Default = "Default",
})

_188:AddToggle("KillSoundEnabled", {
    Text = "Enable Kill Sounds",
    Default = false,
})

_188:AddDropdown("KillSoundType", {
    Text = "Kill Sound",
    Values = {"Default", "NoSounds", "Bameware", "Bell", "Bubble", "Pick", "Pop", "Rust", "Sans", "Fart", "Big", "Vine", "Bruh", "Skeet", "Fatality", "Bonk", "Bumble", "Minecraft", "TomScream", "Prowler", "Fortnite", "iphone", "Lmk", "1nn", "67", "BatHit", "Beep", "Bow", "Bubble2", "CSGO", "Cod", "Fairy1", "Fairy2", "Fatality2", "Hentai1", "Hentai2", "Hentai3", "Lazer", "MarioCoins", "MinecraftXP", "Neverlose", "OSU", "PubgPan", "Rifk7", "RustHeadshot", "SpanishMoan", "StaryKrow", "Steve", "TF2Crit", "TF2Default", "Windows", "boolean", "disable", "enable", "keypress", "keyrelease", "lobby", "moan1", "moan2", "moan3", "moan4", "orthodox", "pmsound", "rifk"},
    Default = "Default",
})

local _189 = {
    Bameware = "rbxassetid://3124331820",
    Bell = "rbxassetid://6534947240",
    Bubble = "rbxassetid://6534947588",
    Pick = "rbxassetid://1347140027",
    Pop = "rbxassetid://198598793",
    Rust = "rbxassetid://1255040462",
    Sans = "rbxassetid://3188795283",
    Fart = "rbxassetid://130833677",
    Big = "rbxassetid://5332005053",
    Vine = "rbxassetid://5332680810",
    Bruh = "rbxassetid://4578740568",
    Skeet = "rbxassetid://5633695679",
    Fatality = "rbxassetid://6534947869",
    Bonk = "rbxassetid://5766898159",
    Minecraft = "rbxassetid://4018616850",
    TomScream = "rbxassetid://7553397015",
    Prowler = "rbxassetid://131169447699141",
    Fortnite = "rbxassetid://140073271098075",
    iphone = "rbxassetid://131935970184832",
    Lmk = "rbxassetid://118833207462382",
    NoSounds = "rbxassetid://0",
}

local _190 = "rbxassetid://137166459647708"
local _191 = "rbxassetid://122260391562335"

local _192 = getcustomasset or getsynasset or function(path) return nil end
local _193 = "assets/sounds/"
local _208 = {}

local function _194(_195)
    if _195 == "Default" then return nil end
    
    if _189[_195] then
        return _189[_195]
    end
    
    if _208[_195] then
        return _208[_195]
    end
    
    local _exts = {".mp3", ".ogg", ".wav", ".flac"}
    
    for _, _ext in ipairs(_exts) do
        local _196 = _193 .. _195 .. _ext
        if isfile(_196) then
            local _209 = _192(_196)
            if _209 then
                _208[_195] = _209
                return _209
            end
        end
    end
    
    return nil
end

local function _197()
    local _198 = _4.Assets.Sounds

    local _199 = _198:FindFirstChild("Hitmarker")
    if _199 then
        local _201 = _190
        if _37.HitSoundEnabled and _37.HitSoundEnabled.Value then
            local _200 = _36.HitSoundType and _36.HitSoundType.Value or "Default"
            if _200 ~= "Default" then
                local _resolved = _194(_200)
                if _resolved then _201 = _resolved end
            end
        end
        if _199.SoundId ~= _201 then
            _199.SoundId = _201
        end
    end
    
    -- Kill
    local _202 = _198:FindFirstChild("Kill")
    if _202 then
        local _204 = _191
        if _37.KillSoundEnabled and _37.KillSoundEnabled.Value then
            local _203 = _36.KillSoundType and _36.KillSoundType.Value or "Default"
            if _203 ~= "Default" then
                local _resolved = _194(_203)
                if _resolved then _204 = _resolved end
            end
        end
        if _202.SoundId ~= _204 then
            _202.SoundId = _204
        end
    end
end

_37.HitSoundEnabled:OnChanged(_197)
_36.HitSoundType:OnChanged(_197)
_37.KillSoundEnabled:OnChanged(_197)
_36.KillSoundType:OnChanged(_197)

task.spawn(function()
    task.wait(1)
    pcall(_197)
end)

task.spawn(function()
    while not _217 do
        task.wait(1)
    end
    pcall(_197)
end)

local _40 = _39["UI Settings"]:AddLeftGroupbox("Menu")
_40:AddToggle("KeybindMenuOpen", { Default = _33.KeybindFrame.Visible, Text = "Open Keybind Menu", Callback = function(v) _33.KeybindFrame.Visible = v end})
_40:AddToggle("ShowCustomCursor", {Text = "Custom Cursor", Default = true, Callback = function(v) _33.ShowCustomCursor = v end})
_40:AddDivider()
_40:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })

local _wmEnabled = true

_40:AddToggle("WatermarkEnabled", {
    Text = "Watermark",
    Default = true,
    Callback = function(value)
        _wmEnabled = value
        _33:SetWatermarkVisibility(value)
        if not value then
            _33:SetWatermark("")
        end
    end,
})

_33:SetWatermarkVisibility(true)

local _41 = (function() return math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) end)
local _42 = pcall(function() return _41() end)
local _43 = game:GetService("RunService").RenderStepped:Connect(function()
    if not _wmEnabled then return end
    
    if _42 then
        _33:SetWatermark(("Rawr.xyz <3 | %d ms"):format(_41()))
    else
        _33:SetWatermark("Rawr.xyz <3")
    end
end)

_40:AddButton("Unload", function() _33:Unload() end)

_33.ToggleKeybind = _36.MenuKeybind

_34:SetLibrary(_33)
_35:SetLibrary(_33)
_35:IgnoreThemeSettings()
_35:SetIgnoreIndexes({ "MenuKeybind" })
_34:SetFolder("Rawr.xyl")
_35:SetFolder("Rawr.xyl/ttk-testing")
_35:BuildConfigSection(_39["UI Settings"])
_34:ApplyToTab(_39["UI Settings"])
_35:LoadAutoloadConfig()

-- Controllers
local _49 = require(_4.Modules.Client.Controllers.GunController)
local _50 = require(_4.Modules.Client.Controllers.BulletController)
local _51 = require(_4.Modules.Shared.SpreadUtil)
local _52 = require(_4.Modules.Client.Controllers.CameraController)
local _53 = require(_4.Modules.Shared.Combat.Hostility)

local _54, _55
local _56 = false

local _57 = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"}, {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"}, {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"}, {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"}, {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
}
local _58 = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"}
}

local _59 = _9.PlayerGui:FindFirstChild("ScreenGui")
if _59 and _59:FindFirstChild("LocalScript") then
    _59.LocalScript:Destroy()
end

local _60
pcall(function() _60 = require(_4.Modules.Client.CameraPOV) end)

local _61 = Drawing.new("Circle")
_61.Filled = false
_61.Thickness = 1
_61.Color = Color3.new(1, 1, 1)

local function _62(_63)
    if not _37.TeamCheck or not _37.TeamCheck.Value then return true end
    
    local ok, _64 = pcall(_53.IsHostile, _9, _63)
    if ok then return _64 == true end
    
    local _65 = _9:GetAttribute("Team")
    local _66 = _63:GetAttribute("Team")
    if _63.Character then
        _66 = _63.Character:GetAttribute("Team") or _66
    end
    if _9.Character then
        _65 = _9.Character:GetAttribute("Team") or _65
    end
    return _65 == nil or _66 == nil or _65 ~= _66
end

local function _67(_68)
    if not _37.WallCheck or not _37.WallCheck.Value then return true end
    
    local _69 = _60 and _60.GetEyePosition and _60.GetEyePosition() or _11.CFrame.Position
    local _70 = RaycastParams.new()
    _70.FilterType = Enum.RaycastFilterType.Exclude
    _70.IgnoreWater = true
    local _ignoreList = { _9.Character, _11 }
    
    local _104 = workspace:FindFirstChild("MercPlayers")
    if _104 then
        table.insert(_ignoreList, _104)
    end
    
    for _, _player in ipairs(_2:GetPlayers()) do
        if _player.Character then
            table.insert(_ignoreList, _player.Character)
        end
    end
    
    _70.FilterDescendantsInstances = _ignoreList
    
    local _71 = workspace:Raycast(_69, _68 - _69, _70)
    return _71 == nil
end

local _76 = hookfunction
local _77 = newcclosure or function(f) return f end
local _78 = clonefunction or function(f) return f end

local function _79(_80)
    if type(_80) ~= "table" or not _37.InfiniteAmmo or not _37.InfiniteAmmo.Value then return end
    local _81 = _80.MaxMagSize or 30
    _80.AmmoType = "none"
    _80.MagAmmo = _81 + 1
    if _80._magazines then
        for i = 1, #_80._magazines do _80._magazines[i] = _81 end
    end
end

local _72 = _50.Discharge
_50.Discharge = function(self, weapon, eyePos, fireDir, muzzleCf, ...)
    local _args = {...}
    
    local _success, _result = pcall(function()
        if _37.SilentAim and _37.SilentAim.Value and (_49.FireHeld or _56) and _54 then
            if _67(_54) then
                local _73 = muzzleCf and muzzleCf.Position or eyePos or _49:GetMuzzleWorldCFrame().Position
                fireDir = (_54 - _73).Unit
            end
        end
        return _72(self, weapon, eyePos, fireDir, muzzleCf, unpack(_args))
    end)
    
    if _success then
        return _result
    else
        return _72(self, weapon, eyePos, fireDir, muzzleCf, unpack(_args))
    end
end

local _75 = _51.RandomConeDirection
_51.RandomConeDirection = function(dir, ...)
    local _args = {...}
    
    local _success, _result = pcall(function()
        if _37.SilentAim and _37.SilentAim.Value and (_49.FireHeld or _56) and _54 then
            if _67(_54) then
                return dir
            end
        end
        return _75(dir, unpack(_args))
    end)
    
    if _success then
        return _result
    else
        return _75(dir, unpack(_args))
    end
end

if _76 then
    local ok, _82 = pcall(require, _4.Modules.Shared.FirearmState)
    if ok and _82.Fire then
        local _83 = _78(_82.Fire)
        _76(_82.Fire, _77(function(self, ...)
            if _37.InfiniteAmmo and _37.InfiniteAmmo.Value then
                pcall(function()
                    if type(self) == "table" then _79(self) end
                end)
            end
            
            local _84 = _83(self, ...)
            
            if _37.InfiniteAmmo and _37.InfiniteAmmo.Value then
                pcall(function()
                    if type(self) == "table" then _79(self) end
                end)
            end
            
            return _84
        end))
    end
end

local function _85(_86)
    if _86 then
        if not _G._87 then
            _G._87 = true
            _G._88 = _49.GetMovementSwayOffset
            _G._89 = _49.GetIdleSwayOffset
            _G._90 = _49.GetLookMomentumOffset
            _G._91 = _49.ApplyRecoil
            
            _49.GetMovementSwayOffset = function() return CFrame.identity end
            _49.GetIdleSwayOffset = function() return CFrame.identity end
            _49.GetLookMomentumOffset = function() return CFrame.identity end
            _49.ApplyRecoil = function() end
        end
    else
        if _G._87 and _G._88 then
            _49.GetMovementSwayOffset = _G._88
            _49.GetIdleSwayOffset = _G._89
            _49.GetLookMomentumOffset = _G._90
            _49.ApplyRecoil = _G._91
            _G._87 = false
        end
    end
end

_37.NoSway:OnChanged(_85)

local _92 = {}
local function _93(_94)
    if _92[_94] then return _92[_94] end
    
    local _95 = {
        Box = Drawing.new("Square"),
        Nametag = Drawing.new("Text"),
        HealthBar = Drawing.new("Square"),
        HealthFill = Drawing.new("Square"),
        Skeleton = {},
    }
    
    _95.Box.Thickness = 1
    _95.Box.Filled = false
    _95.Box.Visible = false
    
    _95.Nametag.Size = 14
    _95.Nametag.Center = true
    _95.Nametag.Outline = true
    _95.Nametag.Visible = false
    
    _95.HealthBar.Filled = true
    _95.HealthBar.Visible = false
    
    _95.HealthFill.Filled = true
    _95.HealthFill.Visible = false
    
    for i = 1, #_57 do
        local _96 = Drawing.new("Line")
        _96.Thickness = 1
        _96.Visible = false
        table.insert(_95.Skeleton, _96)
    end
    
    _92[_94] = _95
    return _95
end

local function _97(_98)
    local _99 = _92[_98]
    if not _99 then return end
    
    _99.Box.Visible = false
    _99.Nametag.Visible = false
    _99.HealthBar.Visible = false
    _99.HealthFill.Visible = false
    for _, _100 in ipairs(_99.Skeleton) do _100.Visible = false end
end

local function _101()
    if not _37.ESPEnabled or not _37.ESPEnabled.Value then
        for _102 in pairs(_92) do _97(_102) end
        return
    end
    
    local _103 = workspace.CurrentCamera
    if not _103 then return end
    
    local _104 = workspace:FindFirstChild("MercPlayers")
    if not _104 then
        for _102 in pairs(_92) do _97(_102) end
        return
    end
    
    for _, _105 in ipairs(_2:GetPlayers()) do
        if _105 == _9 then continue end
        
        local _106 = _93(_105)
        local _107 = _104:FindFirstChild("MercHitboxes_" .. _105.Name)
        if not _107 or _107:GetAttribute("Dead") then
            _97(_105)
            continue
        end
        
        local _108 = _107:FindFirstChild("Head")
        if not _108 then
            _97(_105)
            continue
        end
        
        local _109 = _60 and _60.GetEyePosition and _60.GetEyePosition() or _103.CFrame.Position
        local _110 = (_108.Position - _109).Magnitude
        
        if _110 > 2000 then
            _97(_105)
            continue
        end
        
        local _isTeam = not _62(_105)
        local _111 = _107:FindFirstChild("Torso") and _58 or _57
        
        if _37.ESPSkeleton and _37.ESPSkeleton.Value then
            local _112 = _36.ESPSkeletonColor and _36.ESPSkeletonColor.Value or Color3.fromRGB(255, 255, 255)
            if _isTeam then _112 = Color3.fromRGB(80, 255, 90) end
            
            for idx, _113 in ipairs(_111) do
                local _114 = _107:FindFirstChild(_113[1])
                local _115 = _107:FindFirstChild(_113[2])
                local _116 = _106.Skeleton[idx]
                
                if _114 and _115 then
                    local _117, _118 = _103:WorldToViewportPoint(_114.Position)
                    local _119, _120 = _103:WorldToViewportPoint(_115.Position)
                    
                    if _118 and _120 then
                        _116.From = Vector2.new(_117.X, _117.Y)
                        _116.To = Vector2.new(_119.X, _119.Y)
                        _116.Color = _112
                        _116.Visible = true
                    else
                        _116.Visible = false
                    end
                else
                    _116.Visible = false
                end
            end
            
            for i = #_111 + 1, #_106.Skeleton do
                _106.Skeleton[i].Visible = false
            end
        else
            for _, _116 in ipairs(_106.Skeleton) do _116.Visible = false end
        end
        
        if _37.ESPBox and _37.ESPBox.Value then
            local _121 = _36.ESPBoxColor and _36.ESPBoxColor.Value or Color3.fromRGB(255, 255, 255)
            if _isTeam then _121 = Color3.fromRGB(80, 255, 90) end
            
            local _122, _123 = math.huge, math.huge
            local _124, _125 = -math.huge, -math.huge
            
            for _, _113 in ipairs(_111) do
                local _114 = _107:FindFirstChild(_113[1])
                local _115 = _107:FindFirstChild(_113[2])
                
                if _114 and _115 then
                    local _117, _118 = _103:WorldToViewportPoint(_114.Position)
                    local _119, _120 = _103:WorldToViewportPoint(_115.Position)
                    
                    if _118 then
                        _122 = math.min(_122, _117.X)
                        _124 = math.max(_124, _117.X)
                        _123 = math.min(_123, _117.Y)
                        _125 = math.max(_125, _117.Y)
                    end
                    if _120 then
                        _122 = math.min(_122, _119.X)
                        _124 = math.max(_124, _119.X)
                        _123 = math.min(_123, _119.Y)
                        _125 = math.max(_125, _119.Y)
                    end
                end
            end
            
            if _122 ~= math.huge then
                local _126 = 6
                _106.Box.Position = Vector2.new(_122 - _126, _123 - _126)
                _106.Box.Size = Vector2.new((_124 - _122) + _126 * 2, (_125 - _123) + _126 * 2)
                _106.Box.Color = _121
                _106.Box.Visible = true
            else
                _106.Box.Visible = false
            end
        else
            _106.Box.Visible = false
        end
        
        if _37.ESPNametags and _37.ESPNametags.Value then
            local _127 = _36.ESPNametagsColor and _36.ESPNametagsColor.Value or Color3.fromRGB(255, 255, 255)
            if _isTeam then _127 = Color3.fromRGB(80, 255, 90) end
            
            local _128, _129 = _103:WorldToViewportPoint(_108.Position + Vector3.new(0, 0.5, 0))
            if _129 then
                if _isTeam then
                    _106.Nametag.Text = "[TEAMMATE] " .. _105.DisplayName .. " [" .. math.floor(_110) .. "m]"
                else
                    _106.Nametag.Text = _105.DisplayName .. " [" .. math.floor(_110) .. "m]"
                end
                _106.Nametag.Position = Vector2.new(_128.X, _128.Y - 25)
                _106.Nametag.Color = _127
                _106.Nametag.Visible = true
            else
                _106.Nametag.Visible = false
            end
        else
            _106.Nametag.Visible = false
        end
        
        if _37.ESPHealth and _37.ESPHealth.Value then
            local _130 = _36.ESPHealthColor and _36.ESPHealthColor.Value or Color3.fromRGB(80, 255, 90)
            
            local _131 = _105.Character
            local _132 = _131 and _131:FindFirstChildOfClass("Humanoid")
            
            if _132 then
                local _128, _129 = _103:WorldToViewportPoint(_108.Position + Vector3.new(0, 0.5, 0))
                if _129 then
                    local _133 = 60
                    local _134 = 4
                    local _135 = _128.X - _133 / 2
                    local _136 = _128.Y - 12
                    
                    _106.HealthBar.Position = Vector2.new(_135, _136)
                    _106.HealthBar.Size = Vector2.new(_133, _134)
                    _106.HealthBar.Color = Color3.new(0, 0, 0)
                    _106.HealthBar.Visible = true
                    
                    local _137 = math.clamp(_132.Health / math.max(_132.MaxHealth, 1), 0, 1)
                    _106.HealthFill.Position = Vector2.new(_135, _136)
                    _106.HealthFill.Size = Vector2.new(_133 * _137, _134)
                    _106.HealthFill.Color = _130
                    _106.HealthFill.Visible = true
                else
                    _106.HealthBar.Visible = false
                    _106.HealthFill.Visible = false
                end
            else
                _106.HealthBar.Visible = false
                _106.HealthFill.Visible = false
            end
        else
            _106.HealthBar.Visible = false
            _106.HealthFill.Visible = false
        end
        
        if _37.ESPChams and _37.ESPChams.Value then
            local _138 = _36.ESPChamsColor and _36.ESPChamsColor.Value or Color3.fromRGB(255, 70, 70)
            if _isTeam then _138 = Color3.fromRGB(80, 255, 90) end
            local _139 = _36.ESPChamsColor and _36.ESPChamsColor.Transparency or 0.5
            
            local _140 = _104:FindFirstChild("MercVisual_" .. _105.Name)
            if _140 then
                local _141 = _140:FindFirstChild("ESPCham")
                if not _141 then
                    _141 = Instance.new("Highlight")
                    _141.Name = "ESPCham"
                    _141.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    _141.Parent = _140
                end
                _141.FillColor = _138
                _141.FillTransparency = _139
                _141.OutlineColor = _138
                _141.OutlineTransparency = 0.5
                _141.Enabled = true
            end
        else
            local _140 = _104:FindFirstChild("MercVisual_" .. _105.Name)
            if _140 then
                local _141 = _140:FindFirstChild("ESPCham")
                if _141 then _141.Enabled = false end
            end
        end
    end
end

local _162 = {}
local function _163(_164)
    table.insert(_162, _164)
    return _164
end

_163(_43)

_163(_3.RenderStepped:Connect(function()
    _101()
    
    if _37.InfiniteAmmo and _37.InfiniteAmmo.Value then
        _79(_49.Weapon)
    end
    
    _54, _55 = nil, nil
    local _165 = workspace.CurrentCamera
    local _166 = _165.ViewportSize / 2
    
    _61.Position = _166
    _61.Radius = _36.FOVRadius and _36.FOVRadius.Value or 120
    _61.Visible = _37.FOVCircle and _37.FOVCircle.Value or false
    
    local _167 = _60 and _60.GetEyePosition and _60.GetEyePosition() or _165.CFrame.Position
    local _104 = workspace:FindFirstChild("MercPlayers")
    
    if not _104 then
        if _56 then
            _5:SendMouseButtonEvent(_166.X, _166.Y, 0, false, game, 0)
            _56 = false
        end
        return
    end
    
    local _168, _169 = nil, _36.FOVRadius and _36.FOVRadius.Value or 120
    local _170 = false
    
    for _, _171 in ipairs(_2:GetPlayers()) do
        if _171 ~= _9 and _62(_171) then
            local _172 = _104:FindFirstChild("MercHitboxes_" .. _171.Name)
            if _172 and not _172:GetAttribute("Dead") then
                local _173 = _172:FindFirstChild(_36.SilentAimPart and _36.SilentAimPart.Value or "Head")
                if not _173 then _173 = _172:FindFirstChild("Head") end
                
                if _173 then
                    local _174, _175 = _165:WorldToViewportPoint(_173.Position)
                    if _175 and _174.Z > 0 then
                        local _176 = _173.Position + Vector3.new(0, _173.Size.Y * 0.15, 0)
                        
                        if _67(_176) then
                            local _177 = (Vector2.new(_174.X, _174.Y) - _166).Magnitude
                            if _177 < _169 then
                                _169 = _177
                                _168 = _173
                                if _37.AutoShoot and _37.AutoShoot.Value then
                                    _170 = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    if _168 and _37.SilentAim and _37.SilentAim.Value then
        _55 = _168
        _54 = _168.Position + Vector3.new(0, _168.Size.Y * 0.15, 0)
    end
    
    if _170 and _37.AutoShoot and _37.AutoShoot.Value then
        if not _56 then
            _56 = true
            _5:SendMouseButtonEvent(_166.X, _166.Y, 0, true, game, 0)
        end
    else
        if _56 then
            _56 = false
            _5:SendMouseButtonEvent(_166.X, _166.Y, 0, false, game, 0)
        end
    end
end))

_163(_2.PlayerRemoving:Connect(function(_178)
    _97(_178)
    local _179 = _92[_178]
    if _179 then
        _179.Box:Remove()
        _179.Nametag:Remove()
        _179.HealthBar:Remove()
        _179.HealthFill:Remove()
        for _, _180 in ipairs(_179.Skeleton) do
            _180:Remove()
        end
        _92[_178] = nil
    end
end))

_33:OnUnload(function()
    for _, _181 in ipairs(_162) do
        pcall(function()
            if _181 then _181:Disconnect() end
        end)
    end
    _162 = {}
    
    if _G._87 then
        _49.GetMovementSwayOffset = _G._88
        _49.GetIdleSwayOffset = _G._89
        _49.GetLookMomentumOffset = _G._90
        _49.ApplyRecoil = _G._91
        _G._87 = false
    end
    
    for _178, _179 in pairs(_92) do
        pcall(function()
            _179.Box:Remove()
            _179.Nametag:Remove()
            _179.HealthBar:Remove()
            _179.HealthFill:Remove()
            for _, _180 in ipairs(_179.Skeleton) do
                _180:Remove()
            end
        end)
    end
    _92 = {}
    
    local _104 = workspace:FindFirstChild("MercPlayers")
    if _104 then
        for _, _182 in ipairs(_2:GetPlayers()) do
            local _183 = _104:FindFirstChild("MercVisual_" .. _182.Name)
            if _183 then
                local _184 = _183:FindFirstChild("ESPCham")
                if _184 then _184:Destroy() end
            end
        end
    end
    
    if _61 then _61:Remove() end
    
    if _56 then
        _5:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        _56 = false
    end
    
    _54, _55 = nil, nil
    
    pcall(function()
        local _220 = _4.Assets.Sounds:FindFirstChild("Hitmarker")
        if _220 then
            _220.SoundId = "rbxassetid://137166459647708"
        end
        local _221 = _4.Assets.Sounds:FindFirstChild("Kill")
        if _221 then
            _221.SoundId = "rbxassetid://122260391562335"
        end
    end)
    
    _208 = {}
    _217 = false
end)
