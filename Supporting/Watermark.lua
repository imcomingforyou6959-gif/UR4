local httpService = game:GetService('HttpService')

local Watermark = {} do
	Watermark.Library  = nil
	Watermark.Toggle   = nil
	Watermark.Groupbox = nil
	Watermark._Visible = true
	Watermark.Text     = "Rawr.xyz <3 | discord.gg/eMpUQzFrNG"

	function Watermark:SetLibrary(library)
		self.Library = library
	end

	function Watermark:SetText(text)
		if type(text) ~= "string" or text == "" then return end
		self.Text = text
		if self.Library then
			self.Library:SetWatermark(text)
		end
	end

	function Watermark:SetVisible(value)
		self._Visible = value and true or false
		if self.Library then
			self.Library:SetWatermarkVisibility(self._Visible)
		end
	end

	function Watermark:BuildWatermarkSection(tab)
		assert(self.Library, "Watermark:SetLibrary must be called before BuildWatermarkSection")

		local box = tab:AddRightGroupbox('Widgets')
		self.Groupbox = box

		-- apply defaults up front
		self.Library:SetWatermark(self.Text)
		self.Library:SetWatermarkVisibility(true)

		local toggle = box:AddToggle('WatermarkVisible', {
			Text    = 'Watermark',
			Default = true,
		})
		self.Toggle = toggle

		toggle:OnChanged(function(Value)
			Watermark:SetVisible(Value)
		end)

		toggle:AddKeyPicker('WatermarkKeybind', {
			Default         = 'RightShift',
			SyncToggleState = true,
			Mode            = 'Toggle',
			Text            = 'Bind',
			NoUI            = false,
		})

		box:AddInput('WatermarkText', {
			Text        = 'Watermark Text',
			Default     = self.Text,
			Placeholder = 'text',
		})

		Options.WatermarkText:OnChanged(function(v)
			Watermark:SetText(v)
		end)

		if toggle.Value then
			Watermark:SetVisible(true)
		end

		return box
	end

	function Watermark:Unload()
		if self.Library then
			self.Library:SetWatermarkVisibility(false)
		end
	end
end

return Watermark
