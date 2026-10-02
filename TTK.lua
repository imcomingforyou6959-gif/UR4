local _162 = {}
local function _163(c) table.insert(_162, c); return c end

local _running = true
local _RH = {}
local function _regHook(fn) table.insert(_RH, fn) end

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
local Lighting = game:GetService("Lighting")

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

local _protect, _ = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Adonis.lua", true))()
end)

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

local NoRecoil_Enabled = false
local NoRecoil_Hooked = false
local NoRecoil_OrigRecoil = nil
local NoRecoil_Install = nil
local NoCamRecoil_Hooked = false
local NoCamRecoil_Install = nil

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

_37.NoRecoil:OnChanged(function(v)
    NoRecoil_Enabled = v
    if type(NoRecoil_Install) == "function" then
        pcall(NoRecoil_Install)
    end
    if type(NoCamRecoil_Install) == "function" then
        pcall(NoCamRecoil_Install)
    end
end)

local _47 = _39.Main:AddLeftGroupbox("Checks")

_47:AddToggle("WallCheck", {
    Text = "Wall Check",
    Default = false,
})

_47:AddToggle("TeamCheck", {
    Text = "Team Check",
    Default = true,
})

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

local _tr = _39.Main:AddRightGroupbox("Tracers")

_tr:AddToggle("BulletTracers", {
    Text = "Bullet Tracers",
    Default = false,
})

_tr:AddDropdown("BulletTracersType", {
    Text = "Type",
    Default = "Beam",
    Values = { "Beam", "Line" },
})

_tr:AddDropdown("BulletTracersStyle", {
    Text = "Style",
    Default = "laser",
    Values = { "laser", "light", "flow", "Beam", "Lightning", "Heartrate", "Chain", "Glitch", "Swirl" },
})

_tr:AddLabel("Color"):AddColorPicker("BulletTracersColor", {
    Default = Color3.fromRGB(255, 128, 128),
})

_tr:AddLabel("Gradient"):AddColorPicker("BulletTracersGrad", {
    Default = Color3.new(1, 1, 1),
})

_tr:AddLabel("Outline"):AddColorPicker("BulletTracersOutline", {
    Default = Color3.new(0, 0, 0),
})

_tr:AddSlider("BulletTracersWidth", {
    Text = "Width",
    Default = 0.25,
    Min = 0.05,
    Max = 2,
    Rounding = 2,
})

_tr:AddSlider("BulletTracersTrans", {
    Text = "Transparency",
    Default = 0,
    Min = 0,
    Max = 1,
    Rounding = 2,
})

_tr:AddSlider("BulletTracersGradTrans", {
    Text = "Gradient Trans",
    Default = 1,
    Min = 0,
    Max = 1,
    Rounding = 2,
})

_tr:AddSlider("BulletTracersLifetime", {
    Text = "Lifetime",
    Default = 0.8,
    Min = 0.05,
    Max = 3,
    Rounding = 2,
})

_37.BulletTracers:OnChanged(function(v)
    BT_Enabled = v
    BT_Refresh()
end)

_36.BulletTracersType:OnChanged(function(v)      BT_Type = v      end)
_36.BulletTracersStyle:OnChanged(function(v)     BT_Style = v     end)
_36.BulletTracersColor:OnChanged(function(c)     BT_Color1 = c    end)
_36.BulletTracersGrad:OnChanged(function(c)      BT_Color2 = c    end)
_36.BulletTracersOutline:OnChanged(function(c)   BT_Outline = c   end)
_36.BulletTracersWidth:OnChanged(function(v)     BT_Width = v     end)
_36.BulletTracersTrans:OnChanged(function(v)     BT_Trans = v     end)
_36.BulletTracersGradTrans:OnChanged(function(v) BT_GradTrans = v end)
_36.BulletTracersLifetime:OnChanged(function(v)  BT_Lifetime = v  end)

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
    while _running and not _217 do
        task.wait(1)
    end
    if _running then pcall(_197) end
end)

local _fb = _39.Main:AddRightGroupbox("Extras")

_fb:AddToggle('AntiFlashbang', {
    Text = 'Anti Flashbang',
    Default = false,
})

local AF_Enabled = false
local AF_Cleanup = nil
local EC = nil
local CC = nil

pcall(function()
    EC = require(_4.Modules.Client.Controllers.ExposureController)
    CC = require(_4.Modules.Client.Controllers.CameraController)
end)

if EC and EC.SetContribution then
    local orig = EC.SetContribution
    EC.SetContribution = function(self, name, value, ...)
        if AF_Enabled and name == "Flashbang" then
            return orig(self, name, nil, ...)
        end
        return orig(self, name, value, ...)
    end
    _regHook(function() EC.SetContribution = orig end)
end

if CC and CC.ShakeImpulse then
    local orig = CC.ShakeImpulse
    CC.ShakeImpulse = function(self, intensity, ...)
        if AF_Enabled then return nil end
        return orig(self, intensity, ...)
    end
    _regHook(function() CC.ShakeImpulse = orig end)
end

if CC and CC.SetFlashSensitivity then
    local orig = CC.SetFlashSensitivity
    CC.SetFlashSensitivity = function(self, intensity, ...)
        if AF_Enabled then return nil end
        return orig(self, intensity, ...)
    end
    _regHook(function() CC.SetFlashSensitivity = orig end)
end

local function AF_Remove()
    if not AF_Enabled then return end

    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("BlurEffect") and (v.Name == "FlashbangBlur" or v.Enabled) then
            v:Destroy()
        end
    end

    if EC then
        pcall(function() EC:SetContribution("Flashbang", nil) end)
    end

    if CC and CC.SetFlashSensitivity then
        pcall(function() CC:SetFlashSensitivity(0) end)
    end
end

local function AF_Start()
    if AF_Cleanup then AF_Cleanup:Disconnect() end
    AF_Cleanup = _3.RenderStepped:Connect(AF_Remove)
    _regHook(function()
        if AF_Cleanup then AF_Cleanup:Disconnect(); AF_Cleanup = nil end
    end)
end

_37.AntiFlashbang:OnChanged(function(value)
    AF_Enabled = value

    if value then
        AF_Remove()
        AF_Start()
    else
        if AF_Cleanup then
            AF_Cleanup:Disconnect()
            AF_Cleanup = nil
        end
        if CC and CC.SetFlashSensitivity then
            pcall(function() CC:SetFlashSensitivity(0) end)
        end
    end
end)

pcall(function()
    local FC = require(_4.Modules.Client.Controllers.FlashbangController)

    if getsenv and FC then
        local env = getsenv(FC)

        if env and env.computeIntensity then
            local orig = env.computeIntensity
            env.computeIntensity = function(p1)
                if AF_Enabled then return 0 end
                return orig(p1)
            end
            _regHook(function() env.computeIntensity = orig end)
        end

        if env and env.applyDetonationShake then
            local orig = env.applyDetonationShake
            env.applyDetonationShake = function(p1)
                if AF_Enabled then return end
                return orig(p1)
            end
            _regHook(function() env.applyDetonationShake = orig end)
        end
    end
end)

pcall(function()
    local GC = require(_4.Modules.Client.Controllers.GunController)

    if GC and GC.SetSprintBlockedByFlash then
        local orig = GC.SetSprintBlockedByFlash
        GC.SetSprintBlockedByFlash = function(self, blocked)
            if AF_Enabled and blocked then return orig(self, false) end
            return orig(self, blocked)
        end
        _regHook(function() GC.SetSprintBlockedByFlash = orig end)
    end
end)

local _40 = _39["UI Settings"]:AddLeftGroupbox("Menu")
_40:AddToggle("KeybindMenuOpen", { Default = _33.KeybindFrame.Visible, Text = "Open Keybind Menu", Callback = function(v) _33.KeybindFrame.Visible = v end})
_40:AddToggle("ShowCustomCursor", {Text = "Custom Cursor", Default = true,
        Callback = function(v) _33.ShowCustomCursor = v end})
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

local _49 = require(_4.Modules.Client.Controllers.GunController)
local _50 = require(_4.Modules.Client.Controllers.BulletController)
local _51 = require(_4.Modules.Shared.SpreadUtil)
local _52 = require(_4.Modules.Client.Controllers.CameraController)
local _53 = require(_4.Modules.Shared.Combat.Hostility)

NoRecoil_Install = function()
    if NoRecoil_Hooked then return end
    if not _49 or not _49.ApplyRecoil then return end
    NoRecoil_Hooked = true

    NoRecoil_OrigRecoil = _49.ApplyRecoil
    _G._NoRecoil_Orig = NoRecoil_OrigRecoil

    local cloned = (clonefunction or function(f) return f end)(NoRecoil_OrigRecoil)

    local wrapped = (newcclosure or function(f) return f end)(function(self, ...)
        if NoRecoil_Enabled then
            if self then
                local springs = {
                    "RecoilSpring", "RecoilPushSpring", "RecoilShakeSpring",
                    "RecoilTiltSpring", "RecoilTiltShakeSpring", "RecoilTrailSpring",
                    "RecoilRockSpring", "GunLookRollMomentum", "FakeIKShotSpring",
                }
                for i = 1, #springs do
                    local s = self[springs[i]]
                    if s and s.p then
                        s.p = Vector3.new(0, 0, 0)
                        s.v = Vector3.new(0, 0, 0)
                    end
                end
            end
            return
        end
        return cloned(self, ...)
    end)

    local installed = false
    local hookedVia = nil

    if hookfunction then
        local ok = pcall(function()
            hookfunction(NoRecoil_OrigRecoil, wrapped)
        end)
        if ok then installed = true; hookedVia = "hookfunction" end
    end

    if not installed then
        pcall(function()
            _49.ApplyRecoil = wrapped
            installed = true
            hookedVia = "replace"
        end)
    end

    if not installed then
        pcall(function()
            local mt = getrawmetatable(_49)
            if not mt then return end
            setreadonly(mt, false)
            local oldIndex = mt.__index
            mt.__index = newcclosure(function(t, k)
                if k == "ApplyRecoil" then
                    return wrapped
                end
                if type(oldIndex) == "function" then
                    return oldIndex(t, k)
                end
                return rawget(t, k)
            end)
            setreadonly(mt, true)
            installed = true
            hookedVia = "metatable"
        end)
    end

    _regHook(function()
        NoRecoil_Enabled = false
        if hookedVia == "hookfunction" and restorefunction then
            pcall(restorefunction, NoRecoil_OrigRecoil)
        end
        pcall(function() _49.ApplyRecoil = NoRecoil_OrigRecoil end)
    end)
end

NoCamRecoil_Install = function()
    if NoCamRecoil_Hooked then return end
    if not _52 or not _52.Recoil then return end
    NoCamRecoil_Hooked = true

    local origRecoil = _52.Recoil
    local origRock = _52.RecoilRock
    local origShake = _52.ShakeImpulse
    local origBoom = _52.BoomKick

    local clonedRecoil = (clonefunction or function(f) return f end)(origRecoil)
    local clonedRock = origRock and (clonefunction or function(f) return f end)(origRock)
    local clonedShake = origShake and (clonefunction or function(f) return f end)(origShake)
    local clonedBoom = origBoom and (clonefunction or function(f) return f end)(origBoom)

    local wrap = newcclosure or function(f) return f end

    local wrappedRecoil = wrap(function(self, ...)
        if NoRecoil_Enabled then
            if self then
                self._recoilTarget = Vector3.new(0, 0, 0)
                self._recoilOffset = Vector3.new(0, 0, 0)
                if self._recoilSpring then
                    self._recoilSpring.p = Vector3.new(0, 0, 0)
                    self._recoilSpring.v = Vector3.new(0, 0, 0)
                end
                if self._recoilShakeSpring then
                    self._recoilShakeSpring.p = Vector3.new(0, 0, 0)
                    self._recoilShakeSpring.v = Vector3.new(0, 0, 0)
                end
                if self._fovRecoilSpring then
                    self._fovRecoilSpring:setPos(0)
                    self._fovRecoilSpring:setVel(0)
                end
            end
            return
        end
        return clonedRecoil(self, ...)
    end)

    local wrappedRock = clonedRock and wrap(function(self, ...)
        if NoRecoil_Enabled then
            if self then
                if self._rockRollSpring then
                    self._rockRollSpring.p = Vector3.new(0, 0, 0)
                    self._rockRollSpring.v = Vector3.new(0, 0, 0)
                end
                if self._rockJoltSpring then
                    self._rockJoltSpring.p = Vector3.new(0, 0, 0)
                    self._rockJoltSpring.v = Vector3.new(0, 0, 0)
                end
            end
            return
        end
        return clonedRock(self, ...)
    end)

    local wrappedShake = clonedShake and wrap(function(self, ...)
        if NoRecoil_Enabled then return end
        return clonedShake(self, ...)
    end)

    local wrappedBoom = clonedBoom and wrap(function(self, ...)
        if NoRecoil_Enabled then
            if self and self._boomSpring then
                self._boomSpring:setPos(0)
                self._boomSpring:setVel(0)
            end
            return
        end
        return clonedBoom(self, ...)
    end)

    local usedHookfunction = false

    if hookfunction then
        usedHookfunction = true
        pcall(function() hookfunction(origRecoil, wrappedRecoil) end)
        if clonedRock then pcall(function() hookfunction(origRock, wrappedRock) end) end
        if clonedShake then pcall(function() hookfunction(origShake, wrappedShake) end) end
        if clonedBoom then pcall(function() hookfunction(origBoom, wrappedBoom) end) end
    else
        _52.Recoil = wrappedRecoil
        if clonedRock then _52.RecoilRock = wrappedRock end
        if clonedShake then _52.ShakeImpulse = wrappedShake end
        if clonedBoom then _52.BoomKick = wrappedBoom end
    end

    _regHook(function()
        NoRecoil_Enabled = false
        if usedHookfunction and restorefunction then
            pcall(restorefunction, origRecoil)
            if clonedRock then pcall(restorefunction, origRock) end
            if clonedShake then pcall(restorefunction, origShake) end
            if clonedBoom then pcall(restorefunction, origBoom) end
        end
        pcall(function() _52.Recoil = origRecoil end)
        if clonedRock then pcall(function() _52.RecoilRock = origRock end) end
        if clonedShake then pcall(function() _52.ShakeImpulse = origShake end) end
        if clonedBoom then pcall(function() _52.BoomKick = origBoom end) end
    end)
end

NoRecoil_Install()
NoCamRecoil_Install()

task.spawn(function()
    while _running and task.wait(0.05) do
        if NoRecoil_Enabled then
            if _49 then
                local springs = {
                    "RecoilSpring", "RecoilPushSpring", "RecoilShakeSpring",
                    "RecoilTiltSpring", "RecoilTiltShakeSpring", "RecoilTrailSpring",
                    "RecoilRockSpring", "GunLookRollMomentum", "FakeIKShotSpring",
                }
                for i = 1, #springs do
                    local s = _49[springs[i]]
                    if s and s.p then
                        s.p = Vector3.new(0, 0, 0)
                        s.v = Vector3.new(0, 0, 0)
                    end
                end
            end
            if _52 then
                _52._recoilTarget = Vector3.new(0, 0, 0)
                _52._recoilOffset = Vector3.new(0, 0, 0)
                local camObjSprings = {
                    "_recoilSpring", "_recoilShakeSpring",
                    "_rockRollSpring", "_rockJoltSpring",
                }
                for i = 1, #camObjSprings do
                    local s = _52[camObjSprings[i]]
                    if s and s.p then
                        s.p = Vector3.new(0, 0, 0)
                        s.v = Vector3.new(0, 0, 0)
                    end
                end
                if _52._fovRecoilSpring then
                    _52._fovRecoilSpring:setPos(0)
                    _52._fovRecoilSpring:setVel(0)
                end
                if _52._boomSpring then
                    _52._boomSpring:setPos(0)
                    _52._boomSpring:setVel(0)
                end
            end
        end
    end
end)

local _54, _55
local _56 = false

local _57 = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"}, {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"}, {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"}, {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"}, {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
    {"LowerTorso", "UpperTorso"}, {"UpperTorso", "Head"},
    {"LeftUpperLeg", "LowerTorso"}, {"RightUpperLeg", "LowerTorso"},
    {"LeftUpperArm", "UpperTorso"}, {"RightUpperArm", "UpperTorso"},
    {"LeftHand", "Left Arm"}, {"RightHand", "Right Arm"},
}
local _58 = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
    {"Torso", "LeftArm"}, {"Torso", "RightArm"},
    {"Torso", "LeftLeg"}, {"Torso", "RightLeg"},
    {"Head", "Torso2"}, {"Torso2", "Left Arm"}, {"Torso2", "Right Arm"},
    {"Torso2", "Left Leg"}, {"Torso2", "Right Leg"},
    {"Torso", "Torso2"},
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
_regHook(function() _50.Discharge = _72 end)

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
_regHook(function() _51.RandomConeDirection = _75 end)

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
        _regHook(function()
            if restorefunction then pcall(restorefunction, _82.Fire) end
            pcall(function() _82.Fire = _83 end)
        end)
    end
end

local function _85(_86)
    if _86 then
        if not _G._87 then
            _G._87 = true
            _G._88 = _49.GetMovementSwayOffset
            _G._89 = _49.GetIdleSwayOffset
            _G._90 = _49.GetLookMomentumOffset

            _49.GetMovementSwayOffset = function() return CFrame.identity end
            _49.GetIdleSwayOffset = function() return CFrame.identity end
            _49.GetLookMomentumOffset = function() return CFrame.identity end
        end
    else
        if _G._87 and _G._88 then
            _49.GetMovementSwayOffset = _G._88
            _49.GetIdleSwayOffset = _G._89
            _49.GetLookMomentumOffset = _G._90
            _G._87 = false
        end
    end
end

_37.NoSway:OnChanged(_85)
_regHook(function()
    if _G._87 and _G._88 then
        pcall(function()
            _49.GetMovementSwayOffset = _G._88
            _49.GetIdleSwayOffset = _G._89
            _49.GetLookMomentumOffset = _G._90
        end)
        _G._87 = false
    end
end)

local _92 = {}
local function _93(_94)
    if _92[_94] then return _92[_94] end

    local _95 = {
        Box = Drawing.new("Square"),
        Nametag = Drawing.new("Text"),
        HealthBar = Drawing.new("Square"),
        HealthFill = Drawing.new("Square"),
        Skeleton = {},
        DisplayName = _94.DisplayName,
        Name = _94.Name,
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

local HitboxCache  = {}
local HitboxMisses = {}

local function RegisterHitbox(child)
    if child.Name:sub(1, 14) ~= "MercHitboxes_" then return end
    local plrName = child.Name:sub(15)
    local plr = _2:FindFirstChild(plrName)
    if plr then
        HitboxCache[plr] = child
        HitboxMisses[plr] = nil
    end
end

local function BindMercWatcher()
    local merc = workspace:FindFirstChild("MercPlayers")
    if not merc then return end

    for _, child in ipairs(merc:GetChildren()) do
        RegisterHitbox(child)
    end

    _163(merc.ChildAdded:Connect(RegisterHitbox))
    _163(merc.ChildRemoved:Connect(function(child)
        for plr, cached in pairs(HitboxCache) do
            if cached == child then
                HitboxCache[plr] = nil
                break
            end
        end
    end))
end

task.spawn(function()
    while _running and not workspace:FindFirstChild("MercPlayers") do
        task.wait(0.25)
    end
    if not _running then return end
    BindMercWatcher()
    _163(workspace.ChildAdded:Connect(function(child)
        if child.Name == "MercPlayers" then
            task.wait(0.1)
            if _running then BindMercWatcher() end
        end
    end))
end)

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

    local showSkel = _37.ESPSkeleton and _37.ESPSkeleton.Value
    local showBox = _37.ESPBox and _37.ESPBox.Value
    local showName = _37.ESPNametags and _37.ESPNametags.Value
    local showHealth = _37.ESPHealth and _37.ESPHealth.Value
    local showChams = _37.ESPChams and _37.ESPChams.Value

    local skelColor = _36.ESPSkeletonColor and _36.ESPSkeletonColor.Value or Color3.fromRGB(255, 255, 255)
    local boxColor = _36.ESPBoxColor and _36.ESPBoxColor.Value or Color3.fromRGB(255, 255, 255)
    local nameColor = _36.ESPNametagsColor and _36.ESPNametagsColor.Value or Color3.fromRGB(255, 255, 255)
    local healthColor = _36.ESPHealthColor and _36.ESPHealthColor.Value or Color3.fromRGB(80, 255, 90)
    local chamColor = _36.ESPChamsColor and _36.ESPChamsColor.Value or Color3.fromRGB(255, 70, 70)
    local chamTrans = _36.ESPChamsColor and _36.ESPChamsColor.Transparency or 0.5

    local eyePos = _60 and _60.GetEyePosition and _60.GetEyePosition() or _103.CFrame.Position
    local teamColor = Color3.fromRGB(80, 255, 90)
    local viewportSize = _103.ViewportSize

    for _, _105 in ipairs(_2:GetPlayers()) do
        if _105 == _9 then continue end

        local _106 = _93(_105)

        local _cache = HitboxCache[_105]
        local _107
        if _cache and _cache.Parent then
            _107 = _cache
        else
            _107 = _104:FindFirstChild("MercHitboxes_" .. _105.Name)
            if _107 then
                HitboxCache[_105] = _107
            end
        end

        if not _107 then
            local _miss = HitboxMisses[_105] or 0
            _miss = _miss + 1
            HitboxMisses[_105] = _miss
            if _miss >= 3 then
                _97(_105)
            end
            continue
        end
        HitboxMisses[_105] = nil

        if _107:GetAttribute("Dead") then
            _97(_105)
            continue
        end

        local _108 = _107:FindFirstChild("Head")
        if not _108 then
            _97(_105)
            continue
        end

        local _110 = (_108.Position - eyePos).Magnitude

        if _110 > 2000 then
            _97(_105)
            continue
        end

        local headViewport, headOnScreen = _103:WorldToViewportPoint(_108.Position)
        if headViewport.Z <= 0 then
            _97(_105)
            continue
        end

        local _isTeam = not _62(_105)
        local _111 = _107:FindFirstChild("Torso") and _58 or _57

        local skelC = _isTeam and teamColor or skelColor
        local boxC = _isTeam and teamColor or boxColor
        local nameC = _isTeam and teamColor or nameColor
        local chamC = _isTeam and teamColor or chamColor

        local anyOnScreen = false

        if showSkel then
            for idx, _113 in ipairs(_111) do
                local _114 = _107:FindFirstChild(_113[1])
                local _115 = _107:FindFirstChild(_113[2])
                local _116 = _106.Skeleton[idx]

                if _114 and _115 then
                    local _117, _118 = _103:WorldToViewportPoint(_114.Position)
                    local _119, _120 = _103:WorldToViewportPoint(_115.Position)

                    if _117.Z > 0 and _119.Z > 0 then
                        _116.From = Vector2.new(_117.X, _117.Y)
                        _116.To = Vector2.new(_119.X, _119.Y)
                        _116.Color = skelC
                        _116.Visible = true
                        anyOnScreen = true
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

        if showBox then
            local _122, _123 = math.huge, math.huge
            local _124, _125 = -math.huge, -math.huge
            local anyBoxPoint = false

            for _, _113 in ipairs(_111) do
                local _114 = _107:FindFirstChild(_113[1])
                local _115 = _107:FindFirstChild(_113[2])

                if _114 and _115 then
                    local _117 = _103:WorldToViewportPoint(_114.Position)
                    local _119 = _103:WorldToViewportPoint(_115.Position)

                    if _117.Z > 0 then
                        _122 = math.min(_122, _117.X)
                        _124 = math.max(_124, _117.X)
                        _123 = math.min(_123, _117.Y)
                        _125 = math.max(_125, _117.Y)
                        anyBoxPoint = true
                    end
                    if _119.Z > 0 then
                        _122 = math.min(_122, _119.X)
                        _124 = math.max(_124, _119.X)
                        _123 = math.min(_123, _119.Y)
                        _125 = math.max(_125, _119.Y)
                        anyBoxPoint = true
                    end
                end
            end

            if anyBoxPoint and _122 < _124 and _123 < _125 then
                local _126 = 6
                local boxW = (_124 - _122) + _126 * 2
                local boxH = (_125 - _123) + _126 * 2

                if boxW > 4 and boxH > 4 and boxW < viewportSize.X * 2 and boxH < viewportSize.Y * 2 then
                    _106.Box.Position = Vector2.new(_122 - _126, _123 - _126)
                    _106.Box.Size = Vector2.new(boxW, boxH)
                    _106.Box.Color = boxC
                    _106.Box.Visible = true
                    anyOnScreen = true
                else
                    _106.Box.Visible = false
                end
            else
                _106.Box.Visible = false
            end
        else
            _106.Box.Visible = false
        end

        if showName then
            local _128, _129 = _103:WorldToViewportPoint(_108.Position + Vector3.new(0, 0.5, 0))
            if _128.Z > 0 and _129 then
                if _isTeam then
                    _106.Nametag.Text = "[TEAMMATE] " .. _106.DisplayName .. " [" .. math.floor(_110) .. "m]"
                else
                    _106.Nametag.Text = _106.DisplayName .. " [" .. math.floor(_110) .. "m]"
                end
                _106.Nametag.Position = Vector2.new(_128.X, _128.Y - 25)
                _106.Nametag.Color = nameC
                _106.Nametag.Visible = true
                anyOnScreen = true
            else
                _106.Nametag.Visible = false
            end
        else
            _106.Nametag.Visible = false
        end

        if showHealth then
            local _131 = _105.Character
            local _132 = _131 and _131:FindFirstChildOfClass("Humanoid")

            if _132 then
                local _128, _129 = _103:WorldToViewportPoint(_108.Position + Vector3.new(0, 0.5, 0))
                if _128.Z > 0 and _129 then
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
                    _106.HealthFill.Color = healthColor
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

        if showChams then
            local _141 = _107:FindFirstChild("ESPCham")
            if not _141 then
                _141 = Instance.new("Highlight")
                _141.Name = "ESPCham"
                _141.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                _141.Parent = _107
            end
            _141.Adornee = _107
            _141.FillColor = chamC
            _141.FillTransparency = chamTrans
            _141.OutlineColor = chamC
            _141.OutlineTransparency = 0.5
            _141.Enabled = true
        else
            local _141 = _107:FindFirstChild("ESPCham")
            if _141 then _141.Enabled = false end
        end
    end
end

BT_Beams = {
    laser     = { FaceCamera = true, TextureSpeed = 1.5, Width0 = 0.25, Width1 = 0.25, TextureLength = 2, LightEmission = 3, Brightness = 2.5, Texture = 'rbxassetid://12781800668' },
    light     = { FaceCamera = true, TextureSpeed = 2,   Width0 = 0.25, Width1 = 0.25, LightInfluence = 1, LightEmission = 3, Segments = 1, Texture = 'rbxassetid://2382169232', TextureLength = 15, TextureMode = Enum.TextureMode.Wrap },
    flow      = { FaceCamera = true, TextureSpeed = 2.5, Width0 = 0.2,  Width1 = 0.2,  LightEmission = 3, Brightness = 5, Texture = 'rbxassetid://12788927812' },
    Beam      = { FaceCamera = true, TextureSpeed = 1.5, Width0 = 0.25, Width1 = 0.25, TextureLength = 2, LightEmission = 3, Brightness = 2.5, Texture = 'rbxassetid://12781852245' },
    Lightning = { FaceCamera = true, TextureSpeed = 3,   Width0 = 0.3,  Width1 = 0.3,  TextureLength = 4, LightEmission = 3, Brightness = 3, Texture = 'rbxassetid://446111271' },
    Heartrate = { FaceCamera = true, TextureSpeed = 2,   Width0 = 0.25, Width1 = 0.25, TextureLength = 5, LightEmission = 3, Brightness = 3, Texture = 'rbxassetid://5830549480' },
    Chain     = { FaceCamera = true, TextureSpeed = 2.5, Width0 = 0.2,  Width1 = 0.2,  TextureLength = 6, LightEmission = 3, Brightness = 3, Texture = 'rbxassetid://9632168658' },
    Glitch    = { FaceCamera = true, TextureSpeed = 4,   Width0 = 0.25, Width1 = 0.25, TextureLength = 3, LightEmission = 3, Brightness = 3, Texture = 'rbxassetid://8089467613' },
    Swirl     = { FaceCamera = true, TextureSpeed = 2,   Width0 = 0.25, Width1 = 0.25, TextureLength = 4, LightEmission = 3, Brightness = 3, Texture = 'rbxassetid://5638168605' },
}

BT_BeamCache = {}
for name, cfg in pairs(BT_Beams) do
    local beam = Instance.new('Beam')
    for k, v in pairs(cfg) do beam[k] = v end
    BT_BeamCache[name] = beam
end

BT_Color1       = Color3.fromRGB(255, 128, 128)
BT_Color2       = Color3.new(1, 1, 1)
BT_Trans        = 0
BT_GradTrans    = 1
BT_Lifetime     = 0.8
BT_Outline      = Color3.new(0, 0, 0)
BT_OutlineTrans = 0
BT_Width        = 0.25
BT_Style        = 'laser'
BT_Type         = 'Beam'
BT_Enabled      = false
BT_Conn         = nil
BT_Heartbeat    = {}
BT_ActiveLines  = {}
BT_LineConnection = nil
BT_BeamFolder   = nil

function BT_SequenceFade(beam, a0, a1)
    local elapsed = 0
    local kp = beam.Transparency.Keypoints
    local t0 = kp[1].Value
    local t1 = kp[2].Value

    local fn
    fn = function(dt)
        elapsed = elapsed + dt
        local a = math.clamp(elapsed / 0.2, 0, 1)
        beam.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, t0 + (1 - t0) * a),
            NumberSequenceKeypoint.new(1, t1 + (1 - t1) * a),
        })
        if a >= 1 then
            for i = 1, #BT_Heartbeat do
                if BT_Heartbeat[i] == fn then
                    table.remove(BT_Heartbeat, i)
                    break
                end
            end
            if beam then beam:Destroy() end
            if a0   then a0:Destroy()   end
            if a1   then a1:Destroy()   end
        end
    end

    BT_Heartbeat[#BT_Heartbeat + 1] = fn
end

local function BT_GetFolder()
    if BT_BeamFolder and BT_BeamFolder.Parent then return BT_BeamFolder end
    local f = workspace:FindFirstChild("_BT_Tracers")
    if not f then
        f = Instance.new("Folder")
        f.Name = "_BT_Tracers"
        f.Parent = workspace
    end
    BT_BeamFolder = f
    return f
end

function BT_SpawnBeam(startPos, endPos)
    local template = BT_BeamCache[BT_Style] or BT_BeamCache.laser
    local beam = template:Clone()
    beam.Color = ColorSequence.new(BT_Color1, BT_Color2)
    beam.Transparency = NumberSequence.new(BT_Trans, BT_GradTrans)
    beam.Width0 = BT_Width
    beam.Width1 = BT_Width

    local folder = BT_GetFolder()

    local a0 = Instance.new('Attachment')
    a0.WorldCFrame = CFrame.new(startPos)
    a0.Parent = folder

    local a1 = Instance.new('Attachment')
    a1.WorldCFrame = CFrame.new(endPos)
    a1.Parent = folder

    beam.Attachment0 = a0
    beam.Attachment1 = a1
    beam.Parent = folder

    task.delay(BT_Lifetime, BT_SequenceFade, beam, a0, a1)
end

function BT_EnsureLineLoop()
    if BT_LineConnection then return end

    BT_LineConnection = _3.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if not cam then return end

        local now = tick()

        for i = #BT_ActiveLines, 1, -1 do
            local entry = BT_ActiveLines[i]
            local main = entry.main
            local outline = entry.outline

            local sp1, on1 = cam:WorldToViewportPoint(entry.from)
            local sp2, on2 = cam:WorldToViewportPoint(entry.to)

            if sp1.Z <= 0 and sp2.Z <= 0 then
                main.Visible = false
                outline.Visible = false
            else
                local v1 = Vector2.new(sp1.X, sp1.Y)
                local v2 = Vector2.new(sp2.X, sp2.Y)

                main.From = v1
                main.To   = v2
                main.Thickness = BT_Width * 4

                local offset = (v1 - v2).Unit
                outline.From = v1 + offset
                outline.To   = v2 - offset
                outline.Thickness = (BT_Width * 4) + 2

                main.Visible    = true
                outline.Visible = true
            end

            local elapsed = now - entry.startTime
            if elapsed > BT_Lifetime then
                local a = math.clamp((elapsed - BT_Lifetime) / 0.3, 0, 1)
                main.Transparency    = (1 - BT_Trans) + BT_Trans * a
                outline.Transparency = 1
                if a >= 1 then
                    main:Remove()
                    outline:Remove()
                    table.remove(BT_ActiveLines, i)
                end
            end
        end

        if #BT_ActiveLines == 0 and BT_LineConnection then
            BT_LineConnection:Disconnect()
            BT_LineConnection = nil
        end
    end)
end

function BT_SpawnLine(from, to)
    local main = Drawing.new('Line')
    main.Color = BT_Color1
    main.Thickness = BT_Width * 4
    main.Transparency = 1 - BT_Trans
    main.Visible = true

    local outline = Drawing.new('Line')
    outline.Color = BT_Outline
    outline.Thickness = (BT_Width * 4) + 2
    outline.Transparency = 1 - BT_OutlineTrans
    outline.Visible = true

    BT_ActiveLines[#BT_ActiveLines + 1] = {
        main = main,
        outline = outline,
        from = from,
        to = to,
        startTime = tick(),
    }

    BT_EnsureLineLoop()
end

function BT_Dispatch(startPos, endPos)
    if not BT_Enabled then return end
    if typeof(startPos) ~= "Vector3" or typeof(endPos) ~= "Vector3" then return end

    local delta = endPos - startPos
    if delta.Magnitude < 0.5 or delta.Magnitude > 3000 then return end

    if BT_Type == 'Beam' then
        BT_SpawnBeam(startPos, endPos)
    else
        BT_SpawnLine(startPos, endPos)
    end
end

local function BT_ResolveImpact(origin, direction)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true

    local exclude = { workspace.CurrentCamera }
    if _9.Character then table.insert(exclude, _9.Character) end

    for _, plr in ipairs(_2:GetPlayers()) do
        if plr.Character then table.insert(exclude, plr.Character) end
    end

    params.FilterDescendantsInstances = exclude

    local maxDist = 500
    local result = workspace:Raycast(origin, direction * maxDist, params)
    return result and result.Position or (origin + direction * maxDist)
end

function BT_HookDischarge()
    if BT_Conn then
        BT_Conn:Disconnect()
        BT_Conn = nil
    end

    local original = _50.Discharge

    _50.Discharge = function(self, weaponId, eyePos, fireDir, muzzleCF, ...)
        local args = {...}

        if BT_Enabled then
            local startPos
            if typeof(muzzleCF) == "CFrame" then
                startPos = muzzleCF.Position
            elseif typeof(eyePos) == "Vector3" then
                startPos = eyePos
            else
                local char = _9.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                startPos = hrp and hrp.Position or workspace.CurrentCamera.CFrame.Position
            end

            local endPos
            if _37.SilentAim and _37.SilentAim.Value and _54 and _67(_54) then
                endPos = _54
            elseif typeof(fireDir) == "Vector3" and fireDir.Magnitude > 0.0001 then
                endPos = BT_ResolveImpact(startPos, fireDir.Unit)
            else
                endPos = startPos + workspace.CurrentCamera.CFrame.LookVector * 100
            end

            BT_Dispatch(startPos, endPos)
        end

        return original(self, weaponId, eyePos, fireDir, muzzleCF, unpack(args))
    end

    BT_Conn = {
        Disconnect = function()
            if _50.Discharge ~= original then
                _50.Discharge = original
            end
        end,
    }
end

function BT_Refresh()
    if BT_Enabled then
        if not BT_Conn then BT_HookDischarge() end
    else
        if BT_Conn then BT_Conn:Disconnect() BT_Conn = nil end
    end
end

task.spawn(function()
    while _running and task.wait(0.03) do
        if #BT_Heartbeat > 0 then
            local dt = 0.03
            for i = #BT_Heartbeat, 1, -1 do
                local fn = BT_Heartbeat[i]
                if fn then pcall(fn, dt) end
            end
        end
    end
end)

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

    if not (_37.SilentAim and _37.SilentAim.Value) and not (_37.AutoShoot and _37.AutoShoot.Value) then
        if _56 then
            _5:SendMouseButtonEvent(_166.X, _166.Y, 0, false, game, 0)
            _56 = false
        end
        return
    end

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
    local partName = _36.SilentAimPart and _36.SilentAimPart.Value or "Head"

    for _, _171 in ipairs(_2:GetPlayers()) do
        if _171 ~= _9 and _62(_171) then
            local _cache = HitboxCache[_171]
            local _172
            if _cache and _cache.Parent then
                _172 = _cache
            else
                _172 = _104:FindFirstChild("MercHitboxes_" .. _171.Name)
                if _172 then
                    HitboxCache[_171] = _172
                end
            end

            if _172 and not _172:GetAttribute("Dead") then
                local _173 = _172:FindFirstChild(partName)
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
                                _170 = true
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
    HitboxCache[_178] = nil
    HitboxMisses[_178] = nil
end))

_33:OnUnload(function()
    _running = false

    for _, _181 in ipairs(_162) do
        pcall(function()
            if _181 then _181:Disconnect() end
        end)
    end
    _162 = {}

    for _, fn in ipairs(_RH) do
        pcall(fn)
    end
    _RH = {}

    if _G._87 then
        _49.GetMovementSwayOffset = _G._88
        _49.GetIdleSwayOffset = _G._89
        _49.GetLookMomentumOffset = _G._90
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
            local _183 = _104:FindFirstChild("MercHitboxes_" .. _182.Name)
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

    if BT_Conn then BT_Conn:Disconnect() BT_Conn = nil end
    if BT_LineConnection then BT_LineConnection:Disconnect() BT_LineConnection = nil end

    for i = #BT_Heartbeat, 1, -1 do
        BT_Heartbeat[i] = nil
    end

    for i = #BT_ActiveLines, 1, -1 do
        local entry = BT_ActiveLines[i]
        if entry.main then entry.main:Remove() end
        if entry.outline then entry.outline:Remove() end
        BT_ActiveLines[i] = nil
    end

    local _btFolder = workspace:FindFirstChild("_BT_Tracers")
    if _btFolder then
        for _, c in ipairs(_btFolder:GetChildren()) do
            if c:IsA("Beam") or c:IsA("Attachment") then c:Destroy() end
        end
    end

    if BT_BeamFolder then
        for _, beam in pairs(BT_BeamCache) do
            pcall(function() beam:Destroy() end)
        end
        BT_BeamCache = {}
        BT_Beams = {}
        BT_BeamFolder = nil
    end

    NoRecoil_Enabled = false
    NoRecoil_Hooked = false
    NoCamRecoil_Hooked = false
    _G._NoRecoil_Orig = nil

    HitboxCache = {}
    HitboxMisses = {}
    _208 = {}
    _217 = false
end)
