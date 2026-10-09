local httpService = game:GetService('HttpService')

local function sanitizeName(name)
	if type(name) ~= 'string' then return nil end

	name = name:gsub('[<>:"/\\|%?%*%c]', '')
	name = name:match('^%s*(.-)%s*$')

	if name == '' then return nil end
	return name
end

local SaveManager = {} do
	SaveManager.Folder = 'LinoriaLibSettings'
	SaveManager.Ignore = {}
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object) 
				return { type = 'Toggle', idx = idx, value = object.Value } 
			end,
			Load = function(idx, data)
				if Toggles[idx] then 
					Toggles[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = 'Slider', idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = 'Dropdown', idx = idx, value = object.Value, multi = object.Multi } -- fixed typo (was "mutli")
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		ColorPicker = {
			Save = function(idx, object)
				return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
				end
			end,
		},
		KeyPicker = {
			Save = function(idx, object)
				return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue({ data.key, data.mode })
				end
			end,
		},

		Input = {
			Save = function(idx, object)
				return { type = 'Input', idx = idx, text = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] and type(data.text) == 'string' then
					Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder;
		self:BuildFolderTree()
	end

	function SaveManager:GetConfigPath(name)
		return self.Folder .. '/settings/' .. name .. '.json'
	end

	function SaveManager:GetAutoloadPath()
		return self.Folder .. '/settings/autoload.txt'
	end

	function SaveManager:ConfigExists(name)
		name = sanitizeName(name)
		return name ~= nil and isfile(self:GetConfigPath(name))
	end

	function SaveManager:GetAutoloadName()
		local path = self:GetAutoloadPath()
		if not isfile(path) then return nil end

		local ok, content = pcall(readfile, path)
		if not ok then return nil end

		return sanitizeName(content)
	end

	function SaveManager:SetAutoload(name)
		name = sanitizeName(name)
		if not name then
			return false, 'no config file is selected'
		end

		if not isfile(self:GetConfigPath(name)) then
			return false, 'config does not exist'
		end

		local ok, err = pcall(writefile, self:GetAutoloadPath(), name)
		if not ok then
			return false, 'failed to set autoload: ' .. tostring(err)
		end

		if self.AutoloadLabel then
			self.AutoloadLabel:SetText('Current autoload config: ' .. name)
		end

		return true
	end

	function SaveManager:ClearAutoload()
		local path = self:GetAutoloadPath()

		if isfile(path) then
			local ok, err = pcall(delfile, path)
			if not ok then
				return false, 'failed to clear autoload: ' .. tostring(err)
			end
		end

		if self.AutoloadLabel then
			self.AutoloadLabel:SetText('Current autoload config: none')
		end

		return true
	end

	function SaveManager:Save(name)
		name = sanitizeName(name)
		if not name then
			return false, 'no config file is selected'
		end

		local fullPath = self:GetConfigPath(name)

		local data = {
			objects = {}
		}

		for idx, toggle in next, Toggles do
			if self.Ignore[idx] then continue end
			if not self.Parser[toggle.Type] then continue end

			table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
		end

		for idx, option in next, Options do
			if not self.Parser[option.Type] then continue end
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
		end	

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, 'failed to encode data'
		end

		local written, err = pcall(writefile, fullPath, encoded)
		if not written then
			return false, 'failed to write file: ' .. tostring(err)
		end

		return true
	end

	function SaveManager:Load(name)
		name = sanitizeName(name)
		if not name then
			return false, 'no config file is selected'
		end
		
		local file = self:GetConfigPath(name)
		if not isfile(file) then return false, 'invalid file' end

		local readOk, contents = pcall(readfile, file)
		if not readOk then return false, 'failed to read file' end

		local success, decoded = pcall(httpService.JSONDecode, httpService, contents)
		if not success or type(decoded) ~= 'table' or type(decoded.objects) ~= 'table' then
			return false, 'decode error'
		end

		for _, option in next, decoded.objects do
			local parser = self.Parser[option.type]
			if parser and not self.Ignore[option.idx] then
				task.spawn(function()
					-- pcall so one broken entry can't stop the rest of the config from loading
					local ok, err = pcall(parser.Load, option.idx, option)
					if not ok then
						warn(string.format('[SaveManager] failed to load %q: %s', tostring(option.idx), tostring(err)))
					end
				end)
			end
		end

		return true
	end

	function SaveManager:Delete(name)
		name = sanitizeName(name)
		if not name then
			return false, 'no config file is selected'
		end

		local file = self:GetConfigPath(name)
		if not isfile(file) then
			return false, 'config does not exist'
		end

		local success, err = pcall(delfile, file)
		if not success then
			return false, 'failed to delete config: ' .. tostring(err)
		end

		-- if this config was the autoload one, clear it
		if self:GetAutoloadName() == name then
			self:ClearAutoload()
		end

		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", -- themes
			"ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName', -- themes
		})
	end

	function SaveManager:BuildFolderTree()
		local paths = {
			self.Folder,
			self.Folder .. '/themes',
			self.Folder .. '/settings'
		}

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function SaveManager:RefreshConfigList()
		local ok, list = pcall(listfiles, self.Folder .. '/settings')
		if not ok then return {} end

		local out = {}
		for i = 1, #list do
			local name = list[i]:match('([^/\\]+)%.json$')
			if name then
				table.insert(out, name)
			end
		end

		table.sort(out, function(a, b) return a:lower() < b:lower() end)
		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
	end

	function SaveManager:LoadAutoloadConfig()
		local name = self:GetAutoloadName()
		if not name then return end

		-- autoload points at a config that no longer exists, so clean it up
		if not isfile(self:GetConfigPath(name)) then
			self:ClearAutoload()
			return
		end

		local success, err = self:Load(name)
		if not success then
			return self.Library:Notify('Failed to load autoload config: ' .. err)
		end

		self.Library:Notify(string.format('Auto loaded config %q', name))
	end


	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, 'Must set SaveManager.Library')

		local section = tab:AddRightGroupbox('Configuration')

		local function refreshList(select)
			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(select)
		end

		section:AddInput('SaveManager_ConfigName',    { Text = 'Config name' })
		section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })

		section:AddDivider()

		section:AddButton('Create config', function()
			local name = sanitizeName(Options.SaveManager_ConfigName.Value)

			if not name then 
				return self.Library:Notify('Invalid config name (empty)', 2)
			end

			if self:ConfigExists(name) then
				return self.Library:Notify(string.format('Config %q already exists, use "Overwrite config"', name), 3)
			end

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to save config: ' .. err)
			end

			self.Library:Notify(string.format('Created config %q', name))

			refreshList(name) -- select the new config right away
		end):AddButton('Load config', function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load config: ' .. err)
			end

			self.Library:Notify(string.format('Loaded config %q', name))
		end)

		section:AddButton('Overwrite config', function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to overwrite config: ' .. err)
			end

			self.Library:Notify(string.format('Overwrote config %q', name))
		end)

		section:AddButton('Delete config', function()
			local name = Options.SaveManager_ConfigList.Value

			if not name then
				return self.Library:Notify('No config selected', 2)
			end

			local success, err = self:Delete(name)
			if not success then
				return self.Library:Notify('Failed to delete config: ' .. err)
			end

			self.Library:Notify(string.format('Deleted config %q', name))

			refreshList(nil)
		end, true) -- true = double click to prevent accidental deletion

		section:AddButton('Refresh list', function()
			refreshList(nil)
		end)

		section:AddButton('Set as autoload', function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = self:SetAutoload(name)
			if not success then
				return self.Library:Notify('Failed to set autoload: ' .. err)
			end

			self.Library:Notify(string.format('Set %q to auto load', name))
		end):AddButton('Clear autoload', function()
			local success, err = self:ClearAutoload()
			if not success then
				return self.Library:Notify(err)
			end

			self.Library:Notify('Cleared autoload config')
		end)

		self.AutoloadLabel = section:AddLabel('Current autoload config: none', true)

		local autoloadName = self:GetAutoloadName()
		if autoloadName then
			self.AutoloadLabel:SetText('Current autoload config: ' .. autoloadName)
		end

		self:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
