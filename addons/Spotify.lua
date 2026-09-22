local httpService = game:GetService('HttpService')

local Spotify = {} do
	Spotify.Library   = nil
	Spotify.Folder    = 'spotifyforRawr/Spotify'
	Spotify.Instance  = nil
	Spotify.Toggle    = nil
	Spotify.Groupbox  = nil
	Spotify._Visible  = false

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
			print(("removed %d duplicate frame(s) before building."):format(removed))
		end
		if type(self.Library.CreateSpotifyPlayer) ~= "function" then
			error("Library.CreateSpotifyPlayer is missing — is Extra.lua up to date?")
		end
		self.Instance = self.Library:CreateSpotifyPlayer()
		self.Instance:SetVisibility(false)
		getgenv().Spotify = self.Instance
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

		local box = tab:AddRightGroupbox('Widgets')
		self.Groupbox = box

		local toggle = box:AddToggle('SpotifyVisible', {
			Text    = 'Spotify',
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

		box:AddButton('Refresh Player', function()
			if Spotify.Instance and Spotify.Instance.Refresh then
				Spotify.Instance:Refresh()
			end
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
end

return Spotify
