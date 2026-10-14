local WatermarkToggle = {} do
    WatermarkToggle.Library = nil
    WatermarkToggle.Tab     = nil
    WatermarkToggle.Groupbox = nil
    WatermarkToggle.Toggle  = nil

    function WatermarkToggle:SetLibrary(library)
        self.Library = library
    end

    function WatermarkToggle:BuildWatermarkSection(tab)
        assert(self.Library, "WatermarkToggle:SetLibrary must be called before BuildWatermarkSection")

        local box = tab:AddRightGroupbox('Widgets')
        self.Groupbox = box

        -- Set the initial watermark text once
        self.Library:SetWatermark("Rawr.xyz <3 | discord.gg/eMpUQzFrNG")
        self.Library:SetWatermarkVisibility(true)

        local toggle = box:AddToggle('Watermark', {
            Text    = 'Watermark',
            Default = true,
            Searchable = true,
        })
        self.Toggle = toggle

        toggle:OnChanged(function(v)
            self.Library:SetWatermarkVisibility(v)
        end)

        if toggle.Value then
            self.Library:SetWatermarkVisibility(true)
        end

        return box
    end

    function WatermarkToggle:Unload()
        if self.Library then
            self.Library:SetWatermarkVisibility(false)
        end
    end
end

return WatermarkToggle
