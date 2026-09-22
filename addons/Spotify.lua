local Spotify = {}
Spotify.Library      = nil
Spotify.Folder       = 'spotifyforRawr/Spotify'
Spotify.Instance     = nil
Spotify.Toggle       = nil
Spotify.Keybind      = nil
Spotify.Groupbox     = nil
Spotify._Visible     = false

local function FindSpotifyRoots(Library)
    local found = {}
    local roots = {}

    if Library and Library.ScreenGui then
        table.insert(roots, Library.ScreenGui)
    end
    local coreGui = game:GetService("CoreGui")
    for _, g in ipairs(coreGui:GetChildren()) do
        if g:IsA("ScreenGui") then
            table.insert(roots, g)
        end
    end

    for _, root in ipairs(roots) do
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("Frame")
                and d.ClipsDescendants
                and d.ZIndex == 50
                and d:FindFirstChildOfClass("UIStroke") ~= nil
            then
                local sz = d.AbsoluteSize
                if math.abs(sz.X - 248) < 4 or math.abs(sz.X - 540) < 4 then
                    table.insert(found, d)
                end
            end
        end
    end
    return found
end

function Spotify:PruneDuplicates(keepNewest)
    local roots = FindSpotifyRoots(self.Library)
    if #roots <= 1 then return 0 end

    local keep = keepNewest and roots[#roots] or nil
    local removed = 0
    for _, r in ipairs(roots) do
        if r ~= keep and r.Parent then
            r:Destroy()
            removed = removed + 1
        end
    end
    return removed
end

function Spotify:Ensure()
    if self.Instance then return self.Instance end

    local removed = self:PruneDuplicates(false)
    if removed > 0 then
        print(("[Spotify] Pruned %d duplicate frame(s) before building."):format(removed))
    end

    if type(self.Library.CreateSpotifyPlayer) ~= "function" then
        error("[Spotify] Library.CreateSpotifyPlayer is missing — is Extra.lua up to date?")
    end

    print("[Spotify] Building player…")
    self.Instance = self.Library:CreateSpotifyPlayer()
    self.Instance:SetVisibility(false)

    getgenv().Spotify = self.Instance
    print("[Spotify] Player created ✓")
    return self.Instance
end

function Spotify:SetVisible(value)
    self._Visible = value and true or false

    if self._Visible then
        local inst = self:Ensure()
        local removed = self:PruneDuplicates(true)
        if removed > 0 then
            print(("[Spotify] Removed %d duplicate frame(s)."):format(removed))
        end
        if inst.SetVisibility then inst:SetVisibility(true) end
    else
        if self.Instance and self.Instance.SetVisibility then
            self.Instance:SetVisibility(false)
        end
    end
end

function Spotify:SetLibrary(library)
    self.Library = library
end

function Spotify:SetFolder(folder)
    self.Folder = folder
    if not isfolder(folder) then makefolder(folder) end
end

function Spotify:BuildSpotifySection(tab)
    assert(self.Library, "Spotify:SetLibrary must be called before BuildSpotifySection")

    local box = tab:AddRightGroupbox('Spotify')
    self.Groupbox = box
    local toggle = box:AddToggle('SpotifyVisible', {
        Text    = 'Show Spotify Player',
        Default = false,
    })
    self.Toggle = toggle

    toggle:OnChanged(function(Value)
        Spotify:SetVisible(Value)
    end)

    toggle:AddKeyPicker('SpotifyKeybind', {
        Default         = 'RightShift',
        SyncToggleState = true,
        Mode            = 'Toggle',
        Text            = 'Bind',
        NoUI            = false,
    })
    self.Keybind = toggle

    box:AddButton('Show / Hide', function()
        toggle:SetValue(not toggle.Value)
    end)

    box:AddButton('Refresh Now', function()
        if Spotify.Instance and Spotify.Instance.Refresh then
            Spotify.Instance:Refresh()
        end
    end)

    box:AddButton('Remove Duplicates', function()
        local removed = Spotify:PruneDuplicates(true)
        self.Library:Notify(("Removed %d duplicate(s)"):format(removed), 3)
    end)

    box:AddButton('Destroy Player', function()
        if Spotify.Instance and Spotify.Instance.SetVisibility then
            Spotify.Instance:SetVisibility(false)
        end
        local removed = Spotify:PruneDuplicates(false)
        print(("[Spotify] Destroyed %d frame(s)."):format(removed))
        Spotify.Instance = nil
        getgenv().Spotify = nil
        toggle:SetValue(false)
    end)

    if toggle.Value then
        Spotify:SetVisible(true)
    end

    return box
end

function Spotify:Unload()
    if self.Instance and self.Instance.SetVisibility then
        self.Instance:SetVisibility(false)
    end
    self:PruneDuplicates(false)
    self.Instance = nil
    getgenv().Spotify = nil
end

getgenv().Spotify = getgenv().Spotify or {}

return Spotify
