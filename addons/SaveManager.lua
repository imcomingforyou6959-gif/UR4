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
	SaveManager.OnConfigLoaded = nil
	SaveManager.LoadedConfig = nil
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
				return { type = 'Dropdown', idx = idx, value = object.Value, multi = object.Multi }
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

	function SaveManager:SetOnConfigLoaded(fn)
		self.OnConfigLoaded = fn
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

	-- ============ core data helpers ============

	function SaveManager:BuildData()
		local data = { objects = {} }

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

		return data
	end

	function SaveManager:Encode(data)
		local ok, encoded = pcall(httpService.JSONEncode, httpService, data or self:BuildData())
		if not ok then
			return nil, 'failed to encode data'
		end
		return encoded
	end

	function SaveManager:Decode(text)
		if type(text) ~= 'string' then
			return nil, 'nothing to import'
		end

		text = text:match('^%s*(.-)%s*$')
		if text == '' then
			return nil, 'nothing to import'
		end

		local ok, decoded = pcall(httpService.JSONDecode, httpService, text)
		if not ok or type(decoded) ~= 'table' or type(decoded.objects) ~= 'table' then
			return nil, 'invalid config json'
		end

		return decoded
	end

	function SaveManager:ApplyData(decoded, name)
		-- Toggles first so callbacks that gate other options run before those options,
		-- then everything else in its original order.
		local ordered = {}
		for _, option in next, decoded.objects do
			if option.type == 'Toggle' then
				table.insert(ordered, option)
			end
		end
		for _, option in next, decoded.objects do
			if option.type ~= 'Toggle' then
				table.insert(ordered, option)
			end
		end

		for _, option in next, ordered do
			local parser = self.Parser[option.type]
			if parser and not self.Ignore[option.idx] then
				task.spawn(function()
					local ok, err = pcall(parser.Load, option.idx, option)
					if not ok then
						warn(string.format('[SaveManager] failed to load %q: %s', tostring(option.idx), tostring(err)))
					end
				end)
			end
		end

		-- Give all the SetValue callbacks a tick to settle (dropdowns, sliders,
		-- colorpickers can yield internally), then fire the post-load hook.
		task.delay(0.15, function()
			if self.OnConfigLoaded then
				local ok, err = pcall(self.OnConfigLoaded, name)
				if not ok then
					warn(string.format('[SaveManager] OnConfigLoaded errored for %q: %s', tostring(name), tostring(err)))
				end
			end
		end)
	end

	function SaveManager:CopyToClipboard(text)
		local copy = setclipboard or toclipboard or (syn and syn.write_clipboard)
		if not copy then
			return false, 'your executor has no clipboard function'
		end

		local ok, err = pcall(copy, text)
		if not ok then
			return false, tostring(err)
		end

		return true
	end

	-- ============ save / load / delete ============

	function SaveManager:Save(name)
		name = sanitizeName(name)
		if not name then
			return false, 'no config file is selected'
		end

		local encoded, encodeErr = self:Encode()
		if not encoded then
			return false, encodeErr
		end

		local written, err = pcall(writefile, self:GetConfigPath(name), encoded)
		if not written then
			return false, 'failed to write file: ' .. tostring(err)
		end

		self.LoadedConfig = name
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

		local decoded = self:Decode(contents)
		if not decoded then
			return false, 'decode error'
		end

		self:ApplyData(decoded, name)
		self.LoadedConfig = name
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

		if self:GetAutoloadName() == name then
			self:ClearAutoload()
		end

		if self.LoadedConfig == name then
			self.LoadedConfig = nil
		end

		return true
	end

	-- ============ export / import ============

	-- Copies the currently loaded settings to the clipboard. The json carries the
	-- name of the loaded config so Import can recreate it under the same name.
	function SaveManager:Export()
		local data = self:BuildData()
		local name = sanitizeName(self.LoadedConfig) or 'exported'
		data.name = name

		local encoded, encodeErr = self:Encode(data)
		if not encoded then
			return false, encodeErr
		end

		local copied, copyErr = self:CopyToClipboard(encoded)
		if not copied then
			return false, copyErr
		end

		return true, name
	end

	-- Takes pasted json, reads the name inside it and saves it as a real config.
	-- If that name is taken it becomes "name (2)", "name (3)" and so on.
	function SaveManager:Import(text)
		local decoded, err = self:Decode(text)
		if not decoded then return false, err end

		local base = sanitizeName(decoded.name) or 'imported'
		local name = base
		local n = 2

		while isfile(self:GetConfigPath(name)) do
			name = string.format('%s (%d)', base, n)
			n = n + 1
		end

		decoded.name = nil

		local encoded, encodeErr = self:Encode(decoded)
		if not encoded then return false, encodeErr end

		local written, writeErr = pcall(writefile, self:GetConfigPath(name), encoded)
		if not written then
			return false, 'failed to write file: ' .. tostring(writeErr)
		end

		return true, name, name ~= base
	end

	-- ============ misc ============

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor",
			"ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName',
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

			refreshList(name)
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
		end, true)

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

		-- ===== export / import =====
		section:AddDivider()

		section:AddInput('SaveManager_ImportText', { Text = 'Paste config json', Placeholder = 'paste exported json here' })

		section:AddButton('Export', function()
			local ok, result = self:Export()
			if not ok then
				return self.Library:Notify('Failed to export: ' .. tostring(result), 3)
			end

			self.Library:Notify(string.format('Copied %q to clipboard', result), 2)
		end):AddButton('Import', function()
			local text = Options.SaveManager_ImportText.Value

			if type(text) ~= 'string' or text:match('^%s*$') then
				return self.Library:Notify('Paste the config json in the box first', 3)
			end

			local ok, result, renamed = self:Import(text)
			if not ok then
				return self.Library:Notify('Failed to import: ' .. tostring(result), 3)
			end

			Options.SaveManager_ImportText:SetValue('')
			refreshList(result)

			if renamed then
				self.Library:Notify(string.format('Imported as %q (name was taken)', result), 3)
			else
				self.Library:Notify(string.format('Imported config %q', result), 2)
			end
		end)

		self.AutoloadLabel = section:AddLabel('Current autoload config: none', true)

		local autoloadName = self:GetAutoloadName()
		if autoloadName then
			self.AutoloadLabel:SetText('Current autoload config: ' .. autoloadName)
		end

		self:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName', 'SaveManager_ImportText' })
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
