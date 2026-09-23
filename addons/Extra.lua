local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();
local HttpService = game:GetService('HttpService');
local UserInputService = InputService;
local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);

ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.Parent = CoreGui;

local Toggles = {};
local Options = {};

getgenv().Toggles = Toggles;
getgenv().Options = Options;

local Library = {
    Registry = {};
    RegistryMap = {};

    HudRegistry = {};

    FontColor = Color3.fromRGB(255, 255, 255);
    MainColor = Color3.fromRGB(28, 28, 28);
    BackgroundColor = Color3.fromRGB(20, 20, 20);
    AccentColor = Color3.fromRGB(0, 85, 255);
    OutlineColor = Color3.fromRGB(50, 50, 50);
    RiskColor = Color3.fromRGB(255, 50, 50),

    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.Code,

    OpenedFrames = {};
    DependencyBoxes = {};

    Signals = {};
    ScreenGui = ScreenGui;
};

local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta

    if RainbowStep >= (1 / 60) then
        RainbowStep = 0

        Hue = Hue + (1 / 400);

        if Hue > 1 then
            Hue = 0;
        end;

        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end
end))

local function GetPlayersString()
    local PlayerList = Players:GetPlayers();

    for i = 1, #PlayerList do
        PlayerList[i] = PlayerList[i].Name;
    end;

    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);

    return PlayerList;
end;

local function GetTeamsString()
    local TeamList = Teams:GetTeams();

    for i = 1, #TeamList do
        TeamList[i] = TeamList[i].Name;
    end;

    table.sort(TeamList, function(str1, str2) return str1 < str2 end);
    
    return TeamList;
end;

function Library:SafeCallback(f, ...)
    if (not f) then
        return;
    end;

    if not Library.NotifyOnError then
        return f(...);
    end;

    local success, event = pcall(f, ...);

    if not success then
        local _, i = event:find(":%d+: ");

        if not i then
            return Library:Notify(event);
        end;

        return Library:Notify(event:sub(i + 1), 3);
    end;
end;

function Library:AttemptSave()
    if Library.SaveManager then
        Library.SaveManager:Save();
    end;
end;

function Library:Create(Class, Properties)
    local _Instance = Class;

    if type(Class) == 'string' then
        _Instance = Instance.new(Class);
    end;

    for Property, Value in next, Properties do
        _Instance[Property] = Value;
    end;

    return _Instance;
end;

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;

    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent = Inst;
    });
end;

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 16;
        TextStrokeTransparency = 0;
    });

    Library:ApplyTextStroke(_Instance);

    Library:AddToRegistry(_Instance, {
        TextColor3 = 'FontColor';
    }, IsHud);

    return Library:Create(_Instance, Properties);
end;

function Library:MakeDraggable(Instance, Cutoff)
    Instance.Active = true;

    Instance.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ObjPos = Vector2.new(
                Mouse.X - Instance.AbsolutePosition.X,
                Mouse.Y - Instance.AbsolutePosition.Y
            );

            if ObjPos.Y > (Cutoff or 40) then
                return;
            end;

            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                Instance.Position = UDim2.new(
                    0,
                    Mouse.X - ObjPos.X + (Instance.Size.X.Offset * Instance.AnchorPoint.X),
                    0,
                    Mouse.Y - ObjPos.Y + (Instance.Size.Y.Offset * Instance.AnchorPoint.Y)
                );

                RenderStepped:Wait();
            end;
        end;
    end)
end;

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14);
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,

        Size = UDim2.fromOffset(X + 5, Y + 4),
        ZIndex = 100,
        Parent = Library.ScreenGui,

        Visible = false,
    })

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(3, 1),
        Size = UDim2.fromOffset(X, Y);
        TextSize = 14;
        Text = InfoStr,
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Tooltip.ZIndex + 1,

        Parent = Tooltip;
    });

    Library:AddToRegistry(Tooltip, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    Library:AddToRegistry(Label, {
        TextColor3 = 'FontColor',
    });

    local IsHovering = false

    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then
            return
        end

        IsHovering = true

        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        Tooltip.Visible = true

        while IsHovering do
            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end
    end)

    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx;

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)

    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = Library[ColorIdx] or ColorIdx;

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)
end;

function Library:MouseIsOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

        if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
            and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

            return true;
        end;
    end;
end;

function Library:IsMouseOverFrame(Frame)
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

        return true;
    end;
end;

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do
        Depbox:Update();
    end;
end;

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end;

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end;

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end;
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1;
    local Data = {
        Instance = Instance;
        Properties = Properties;
        Idx = Idx;
    };

    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;

    if IsHud then
        table.insert(Library.HudRegistry, Data);
    end;
end;

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];

    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx);
            end;
        end;

        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx);
            end;
        end;

        Library.RegistryMap[Instance] = nil;
    end;
end;

function Library:UpdateColorsUsingRegistry()
    -- TODO: Could have an 'active' list of objects
    -- where the active list only contains Visible objects.

    -- IMPL: Could setup .Changed events on the AddToRegistry function
    -- that listens for the 'Visible' propert being changed.
    -- Visible: true => Add to active list, and call UpdateColors function
    -- Visible: false => Remove from active list.

    -- The above would be especially efficient for a rainbow menu color or live color-changing.

    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx];
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end;
    end;
end;

function Library:GiveSignal(Signal)
    -- Only used for signals not attached to library instances, as those should be cleaned up on object destruction by Roblox
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    -- Unload all of the signals
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        Connection:Disconnect()
    end

     -- Call our unload callback, maybe to undo some hooks etc
    if Library.OnUnload then
        Library.OnUnload()
    end

    ScreenGui:Destroy()
end

function Library:OnUnload(Callback)
    Library.OnUnload = Callback
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then
        Library:RemoveFromRegistry(Instance);
    end;
end))

local BaseAddons = {};

do
    local Funcs = {};

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel;
        -- local Container = self.Container;

        assert(Info.Default, 'AddColorPicker: Missing default value.');

        local ColorPicker = {
            Value = Info.Default;
            Transparency = Info.Transparency or 0;
            Type = 'ColorPicker';
            Title = type(Info.Title) == 'string' and Info.Title or 'Color picker',
            Callback = Info.Callback or function(Color) end;
        };

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color3.toHSV(Color);

            ColorPicker.Hue = H;
            ColorPicker.Sat = S;
            ColorPicker.Vib = V;
        end;

        ColorPicker:SetHSVFromRGB(ColorPicker.Value);

        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(0, 28, 0, 14);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        -- Transparency image taken from https://github.com/matas3535/SplixPrivateDrawingLibrary/blob/main/Library.lua cus i'm lazy
        local CheckerFrame = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(0, 27, 0, 13);
            ZIndex = 5;
            Image = 'http://www.roblox.com/asset/?id=12977615774';
            Visible = not not Info.Transparency;
            Parent = DisplayFrame;
        });

        local PickerFrameOuter = Library:Create('Frame', {
            Name = 'Color';
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253);
            Visible = false;
            ZIndex = 15;
            Parent = ScreenGui,
        });

        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18);
        end)

        local PickerFrameInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 16;
            Parent = PickerFrameOuter;
        });

        local Highlight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 4, 0, 25);
            Size = UDim2.new(0, 200, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = SatVibMapOuter;
        });

        local SatVibMap = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Image = 'rbxassetid://4155801252';
            Parent = SatVibMapInner;
        });

        local CursorOuter = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 6, 0, 6);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ImageColor3 = Color3.new(0, 0, 0);
            ZIndex = 19;
            Parent = SatVibMap;
        });

        local CursorInner = Library:Create('ImageLabel', {
            Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
            Position = UDim2.new(0, 1, 0, 1);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ZIndex = 20;
            Parent = CursorOuter;
        })

        local HueSelectorOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 208, 0, 25);
            Size = UDim2.new(0, 15, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local HueSelectorInner = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = HueSelectorOuter;
        });

        local HueCursor = Library:Create('Frame', { 
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = 18;
            Parent = HueSelectorInner;
        });

        local HueBoxOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(4, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            ZIndex = 18,
            Parent = PickerFrameInner;
        });

        local HueBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18,
            Parent = HueBoxOuter;
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = HueBoxInner;
        });

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = 'Hex color',
            Text = '#FFFFFF',
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 20,
            Parent = HueBoxInner;
        });

        Library:ApplyTextStroke(HueBox);

        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), {
            Position = UDim2.new(0.5, 2, 0, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            Parent = PickerFrameInner
        });

        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild('TextBox'), {
            Text = '255, 255, 255',
            PlaceholderText = 'RGB color',
            TextColor3 = Library.FontColor
        });

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;
        
        if Info.Transparency then 
            TransparencyBoxOuter = Library:Create('Frame', {
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromOffset(4, 251);
                Size = UDim2.new(1, -8, 0, 15);
                ZIndex = 19;
                Parent = PickerFrameInner;
            });

            TransparencyBoxInner = Library:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 19;
                Parent = TransparencyBoxOuter;
            });

            Library:AddToRegistry(TransparencyBoxInner, { BorderColor3 = 'OutlineColor' });

            Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                Image = 'http://www.roblox.com/asset/?id=12978095818';
                ZIndex = 20;
                Parent = TransparencyBoxInner;
            });

            TransparencyCursor = Library:Create('Frame', { 
                BackgroundColor3 = Color3.new(1, 1, 1);
                AnchorPoint = Vector2.new(0.5, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(0, 1, 1, 0);
                ZIndex = 21;
                Parent = TransparencyBoxInner;
            });
        end;

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Position = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = 14;
            Text = ColorPicker.Title,--Info.Default;
            TextWrapped = false;
            ZIndex = 16;
            Parent = PickerFrameInner;
        });


        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = Library:Create('Frame', {
                BorderColor3 = Color3.new(),
                ZIndex = 14,

                Visible = false,
                Parent = ScreenGui
            })

            ContextMenu.Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.fromScale(1, 1);
                ZIndex = 15;
                Parent = ContextMenu.Container;
            });

            Library:Create('UIListLayout', {
                Name = 'Layout',
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = ContextMenu.Inner;
            });

            Library:Create('UIPadding', {
                Name = 'Padding',
                PaddingLeft = UDim.new(0, 4),
                Parent = ContextMenu.Inner,
            });

            local function updateMenuPosition()
                ContextMenu.Container.Position = UDim2.fromOffset(
                    (DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4,
                    DisplayFrame.AbsolutePosition.Y + 1
                )
            end

            local function updateMenuSize()
                local menuWidth = 60
                for i, label in next, ContextMenu.Inner:GetChildren() do
                    if label:IsA('TextLabel') then
                        menuWidth = math.max(menuWidth, label.TextBounds.X)
                    end
                end

                ContextMenu.Container.Size = UDim2.fromOffset(
                    menuWidth + 8,
                    ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4
                )
            end

            DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition)
            ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateMenuSize)

            task.spawn(updateMenuPosition)
            task.spawn(updateMenuSize)

            Library:AddToRegistry(ContextMenu.Inner, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            function ContextMenu:Show()
                self.Container.Visible = true
            end

            function ContextMenu:Hide()
                self.Container.Visible = false
            end

            function ContextMenu:AddOption(Str, Callback)
                if type(Callback) ~= 'function' then
                    Callback = function() end
                end

                local Button = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, 0, 0, 15);
                    TextSize = 13;
                    Text = Str;
                    ZIndex = 16;
                    Parent = self.Inner;
                    TextXAlignment = Enum.TextXAlignment.Left,
                });

                Library:OnHighlight(Button, Button, 
                    { TextColor3 = 'AccentColor' },
                    { TextColor3 = 'FontColor' }
                );

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        return
                    end

                    Callback()
                end)
            end

            ContextMenu:AddOption('Copy color', function()
                Library.ColorClipboard = ColorPicker.Value
                Library:Notify('Copied color!', 2)
            end)

            ContextMenu:AddOption('Paste color', function()
                if not Library.ColorClipboard then
                    return Library:Notify('You have not copied a color!', 2)
                end
                ColorPicker:SetValueRGB(Library.ColorClipboard)
            end)


            ContextMenu:AddOption('Copy HEX', function()
                pcall(setclipboard, ColorPicker.Value:ToHex())
                Library:Notify('Copied hex code to clipboard!', 2)
            end)

            ContextMenu:AddOption('Copy RGB', function()
                pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', '))
                Library:Notify('Copied RGB values to clipboard!', 2)
            end)

        end

        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });
        Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

        Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBox, { TextColor3 = 'FontColor', });
        Library:AddToRegistry(HueBox, { TextColor3 = 'FontColor', });

        local SequenceTable = {};

        for Hue = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)));
        end;

        local HueSelectorGradient = Library:Create('UIGradient', {
            Color = ColorSequence.new(SequenceTable);
            Rotation = 90;
            Parent = HueSelectorInner;
        });

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text)
                if success and typeof(result) == 'Color3' then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result)
                end
            end

            ColorPicker:Display()
        end)

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                if r and g and b then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
                end
            end

            ColorPicker:Display()
        end)

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);

            Library:Create(DisplayFrame, {
                BackgroundColor3 = ColorPicker.Value;
                BackgroundTransparency = ColorPicker.Transparency;
                BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            });

            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value;
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0);
            end;

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0);

            HueBox.Text = '#' .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', ')

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value);
        end;

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value)
        end;

        function ColorPicker:Show()
            for Frame, Val in next, Library.OpenedFrames do
                if Frame.Name == 'Color' then
                    Frame.Visible = false;
                    Library.OpenedFrames[Frame] = nil;
                end;
            end;

            PickerFrameOuter.Visible = true;
            Library.OpenedFrames[PickerFrameOuter] = true;
        end;

        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false;
            Library.OpenedFrames[PickerFrameOuter] = nil;
        end;

        function ColorPicker:SetValue(HSV, Transparency)
            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3]);

            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinX = SatVibMap.AbsolutePosition.X;
                    local MaxX = MinX + SatVibMap.AbsoluteSize.X;
                    local MouseX = math.clamp(Mouse.X, MinX, MaxX);

                    local MinY = SatVibMap.AbsolutePosition.Y;
                    local MaxY = MinY + SatVibMap.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX);
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinY = HueSelectorInner.AbsolutePosition.Y;
                    local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        DisplayFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if PickerFrameOuter.Visible then
                    ColorPicker:Hide()
                else
                    ContextMenu:Hide()
                    ColorPicker:Show()
                end;
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ContextMenu:Show()
                ColorPicker:Hide()
            end
        end);

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                        local MinX = TransparencyBoxInner.AbsolutePosition.X;
                        local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X;
                        local MouseX = math.clamp(Mouse.X, MinX, MaxX);

                        ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX));

                        ColorPicker:Display();

                        RenderStepped:Wait();
                    end;

                    Library:AttemptSave();
                end;
            end);
        end;

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ColorPicker:Hide();
                end;

                if not Library:IsMouseOverFrame(ContextMenu.Container) then
                    ContextMenu:Hide()
                end
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:IsMouseOverFrame(ContextMenu.Container) and not Library:IsMouseOverFrame(DisplayFrame) then
                    ContextMenu:Hide()
                end
            end
        end))

        ColorPicker:Display();
        ColorPicker.DisplayFrame = DisplayFrame

        Options[Idx] = ColorPicker;

        return self;
    end;

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self;
        local ToggleLabel = self.TextLabel;
        local Container = self.Container;

        assert(Info.Default, 'AddKeyPicker: Missing default value.');

        local KeyPicker = {
            Value = Info.Default;
            Toggled = false;
            Mode = Info.Mode or 'Toggle'; -- Always, Toggle, Hold
            Type = 'KeyPicker';
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;

            SyncToggleState = Info.SyncToggleState or false;
        };

        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle' }
            Info.Mode = 'Toggle'
        end

        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 28, 0, 15);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        local PickInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 7;
            Parent = PickOuter;
        });

        Library:AddToRegistry(PickInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 13;
            Text = Info.Default;
            TextWrapped = true;
            ZIndex = 8;
            Parent = PickInner;
        });

        local ModeSelectOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
            Size = UDim2.new(0, 60, 0, 45 + 2);
            Visible = false;
            ZIndex = 14;
            Parent = ScreenGui;
        });

        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
        end);

        local ModeSelectInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 15;
            Parent = ModeSelectOuter;
        });

        Library:AddToRegistry(ModeSelectInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ModeSelectInner;
        });

        local ContainerLabel = Library:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left;
            Size = UDim2.new(1, 0, 0, 18);
            TextSize = 13;
            Visible = false;
            ZIndex = 110;
            Parent = Library.KeybindContainer;
        },  true);

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
        local ModeButtons = {};

        for Idx, Mode in next, Modes do
            local ModeButton = {};

            local Label = Library:CreateLabel({
                Active = false;
                Size = UDim2.new(1, 0, 0, 15);
                TextSize = 13;
                Text = Mode;
                ZIndex = 16;
                Parent = ModeSelectInner;
            });

            function ModeButton:Select()
                for _, Button in next, ModeButtons do
                    Button:Deselect();
                end;

                KeyPicker.Mode = Mode;

                Label.TextColor3 = Library.AccentColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor';

                ModeSelectOuter.Visible = false;
            end;

            function ModeButton:Deselect()
                KeyPicker.Mode = nil;

                Label.TextColor3 = Library.FontColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor';
            end;

            Label.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    ModeButton:Select();
                    Library:AttemptSave();
                end;
            end);

            if Mode == KeyPicker.Mode then
                ModeButton:Select();
            end;

            ModeButtons[Mode] = ModeButton;
        end;

        function KeyPicker:Update()
            if Info.NoUI then
                return;
            end;

            local State = KeyPicker:GetState();

            ContainerLabel.Text = string.format('[%s] %s (%s)', KeyPicker.Value, Info.Text, KeyPicker.Mode);

            ContainerLabel.Visible = true;
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;

            Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor';

            local YSize = 0
            local XSize = 0

            for _, Label in next, Library.KeybindContainer:GetChildren() do
                if Label:IsA('TextLabel') and Label.Visible then
                    YSize = YSize + 18;
                    if (Label.TextBounds.X > XSize) then
                        XSize = Label.TextBounds.X
                    end
                end;
            end;

            Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10, 210), 0, YSize + 23)
        end;

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then
                return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then
                    return false;
                end

                local Key = KeyPicker.Value;

                if Key == 'MB1' or Key == 'MB2' or Key == 'MB3' then
                    return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                        or Key == 'MB3' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3);
                else
                    return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]);
                end;
            else
                return KeyPicker.Toggled;
            end;
        end;

        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2];
            DisplayLabel.Text = Key;
            KeyPicker.Value = Key;
            ModeButtons[Mode]:Select();
            KeyPicker:Update();
        end;

        function KeyPicker:OnClick(Callback)
            KeyPicker.Clicked = Callback
        end

        function KeyPicker:OnChanged(Callback)
            KeyPicker.Changed = Callback
            Callback(KeyPicker.Value)
        end

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker)
        end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value)
            end

            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end

        local Picking = false;

        PickOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Picking = true;

                DisplayLabel.Text = '';

                local Break;
                local Text = '';

                task.spawn(function()
                    while (not Break) do
                        if Text == '...' then
                            Text = '';
                        end;

                        Text = Text .. '.';
                        DisplayLabel.Text = Text;

                        wait(0.4);
                    end;
                end);

                wait(0.2);

                local Event;
                Event = InputService.InputBegan:Connect(function(Input)
                    local Key;

                    if Input.UserInputType == Enum.UserInputType.Keyboard then
                        Key = Input.KeyCode.Name;
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Key = 'MB1';
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                        Key = 'MB2';
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton3 then
                        Key = 'MB3';
                    end;

                    if not Key then
                        return;
                    end;

                    Break = true;
                    Picking = false;

                    DisplayLabel.Text = Key;
                    KeyPicker.Value = Key;

                    Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
                    Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)

                    Library:AttemptSave();

                    Event:Disconnect();
                end);
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ModeSelectOuter.Visible = true;
            end;
        end);

                Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (not Picking) then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value;

                    if Key == 'MB1' or Key == 'MB2' or Key == 'MB3' then
                        if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
                        or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2
                        or Key == 'MB3' and Input.UserInputType == Enum.UserInputType.MouseButton3 then
                            KeyPicker.Toggled = not KeyPicker.Toggled
                            KeyPicker:DoClick()
                        end;
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name == Key then
                            KeyPicker.Toggled = not KeyPicker.Toggled;
                            KeyPicker:DoClick()
                        end;
                    end;
                end;

                KeyPicker:Update();
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ModeSelectOuter.Visible = false;
                end;
            end;
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if (not Picking) then
                KeyPicker:Update();
            end;
        end))

        KeyPicker:Update();

        Options[Idx] = KeyPicker;

        return self;
    end;

    BaseAddons.__index = Funcs;
    BaseAddons.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

local BaseGroupbox = {};

do
    local Funcs = {};

    function Funcs:AddBlank(Size)
        local Groupbox = self;
        local Container = Groupbox.Container;

        Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, Size);
            ZIndex = 1;
            Parent = Container;
        });
    end;

    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {};

        local Groupbox = self;
        local Container = Groupbox.Container;

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 14;
            Text = Text;
            TextWrapped = DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 4);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TextLabel;
            });
        end

        Label.TextLabel = TextLabel;
        Label.Container = Container;

        function Label:SetText(Text)
            TextLabel.Text = Text

            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end

            Groupbox:Resize();
        end

        if (not DoesWrap) then
            setmetatable(Label, BaseAddons);
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Label;
    end;

    function Funcs:AddButton(...)
        -- TODO: Eventually redo this
        local Button = {};
        local function ProcessButtonParams(Class, Obj, ...)
            local Props = select(1, ...)
            if type(Props) == 'table' then
                Obj.Text = Props.Text
                Obj.Func = Props.Func
                Obj.DoubleClick = Props.DoubleClick
                Obj.Tooltip = Props.Tooltip
            else
                Obj.Text = select(1, ...)
                Obj.Func = select(2, ...)
            end

            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
        end

        ProcessButtonParams('Button', Button, ...)

        local Groupbox = self;
        local Container = Groupbox.Container;

        local function CreateBaseButton(Button)
            local Outer = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -4, 0, 20);
                ZIndex = 5;
            });

            local Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = Outer;
            });

            local Label = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                TextSize = 14;
                Text = Button.Text;
                ZIndex = 6;
                Parent = Inner;
            });

            Library:Create('UIGradient', {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
                });
                Rotation = 90;
                Parent = Inner;
            });

            Library:AddToRegistry(Outer, {
                BorderColor3 = 'Black';
            });

            Library:AddToRegistry(Inner, {
                BackgroundColor3 = 'MainColor';
                BorderColor3 = 'OutlineColor';
            });

            Library:OnHighlight(Outer, Outer,
                { BorderColor3 = 'AccentColor' },
                { BorderColor3 = 'Black' }
            );

            return Outer, Inner, Label
        end

        local function InitEvents(Button)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Instance.new('BindableEvent')
                local connection = event:Once(function(...)

                    if type(validator) == 'function' and validator(...) then
                        bindable:Fire(true)
                    else
                        bindable:Fire(false)
                    end
                end)
                task.delay(timeout, function()
                    connection:disconnect()
                    bindable:Fire(false)
                end)
                return bindable.Event:Wait()
            end

            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame() then
                    return false
                end

                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                    return false
                end

                return true
            end

            Button.Outer.InputBegan:Connect(function(Input)
                if not ValidateClick(Input) then return end
                if Button.Locked then return end

                if Button.DoubleClick then
                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'AccentColor' })

                    Button.Label.TextColor3 = Library.AccentColor
                    Button.Label.Text = 'Are you sure?'
                    Button.Locked = true

                    local clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)

                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'FontColor' })

                    Button.Label.TextColor3 = Library.FontColor
                    Button.Label.Text = Button.Text
                    task.defer(rawset, Button, 'Locked', false)

                    if clicked then
                        Library:SafeCallback(Button.Func)
                    end

                    return
                end

                Library:SafeCallback(Button.Func);
            end)
        end

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container

        InitEvents(Button)

        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then
                Library:AddToolTip(tooltip, self.Outer)
            end
            return self
        end


        function Button:AddButton(...)
            local SubButton = {}

            ProcessButtonParams('SubButton', SubButton, ...)

            self.Outer.Size = UDim2.new(0.5, -2, 0, 20)

            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)

            SubButton.Outer.Position = UDim2.new(1, 3, 0, 0)
            SubButton.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y)
            SubButton.Outer.Parent = self.Outer

            function SubButton:AddTooltip(tooltip)
                if type(tooltip) == 'string' then
                    Library:AddToolTip(tooltip, self.Outer)
                end
                return SubButton
            end

            if type(SubButton.Tooltip) == 'string' then
                SubButton:AddTooltip(SubButton.Tooltip)
            end

            InitEvents(SubButton)
            return SubButton
        end

        if type(Button.Tooltip) == 'string' then
            Button:AddTooltip(Button.Tooltip)
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Button;
    end;

    function Funcs:AddDivider()
        local Groupbox = self;
        local Container = self.Container

        local Divider = {
            Type = 'Divider',
        }

        Groupbox:AddBlank(2);
        local DividerOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 5);
            ZIndex = 5;
            Parent = Container;
        });

        local DividerInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DividerOuter;
        });

        Library:AddToRegistry(DividerOuter, {
            BorderColor3 = 'Black';
        });

        Library:AddToRegistry(DividerInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Groupbox:AddBlank(9);
        Groupbox:Resize();
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Textbox = {
            Value = Info.Default or '';
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Type = 'Input';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local InputLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 15);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        Groupbox:AddBlank(1);

        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        });

        local TextBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = TextBoxOuter;
        });

        Library:AddToRegistry(TextBoxInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:OnHighlight(TextBoxOuter, TextBoxOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, TextBoxOuter)
        end

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = TextBoxInner;
        });

        local Container = Library:Create('Frame', {
            BackgroundTransparency = 1;
            ClipsDescendants = true;

            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);

            ZIndex = 7;
            Parent = TextBoxInner;
        })

        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1;

            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromScale(5, 1),

            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = Info.Placeholder or '';

            Text = Info.Default or '';
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;

            ZIndex = 7;
            Parent = Container;
        });

        Library:ApplyTextStroke(Box);

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength);
            end;

            if Textbox.Numeric then
                if (not tonumber(Text)) and Text:len() > 0 then
                    Text = Textbox.Value
                end
            end

            Textbox.Value = Text;
            Box.Text = Text;

            Library:SafeCallback(Textbox.Callback, Textbox.Value);
            Library:SafeCallback(Textbox.Changed, Textbox.Value);
        end;

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end

                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end);
        end

        -- https://devforum.roblox.com/t/how-to-make-textboxes-follow-current-cursor-position/1368429/6
        -- thank you nicemike40 :)

        local function Update()
            local PADDING = 2
            local reveal = Container.AbsoluteSize.X

            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then
                -- we aren't focused, or we fit so be normal
                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else
                -- we are focused and don't fit, so adjust position
                local cursor = Box.CursorPosition
                if cursor ~= -1 then
                    -- calculate pixel width of text from start to cursor
                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X

                    -- check if we're inside the box with the cursor
                    local currentCursorPos = Box.Position.X.Offset + width

                    -- adjust if necessary
                    if currentCursorPos < PADDING then
                        Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif currentCursorPos > reveal - PADDING - 1 then
                        Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0)
                    end
                end
            end
        end

        task.spawn(Update)

        Box:GetPropertyChangedSignal('Text'):Connect(Update)
        Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update)
        Box.FocusLost:Connect(Update)
        Box.Focused:Connect(Update)

        Library:AddToRegistry(Box, {
            TextColor3 = 'FontColor';
        });

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func;
            Func(Textbox.Value);
        end;

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        Options[Idx] = Textbox;

        return Textbox;
    end;

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Toggle = {
            Value = Info.Default or false;
            Type = 'Toggle';

            Callback = Info.Callback or function(Value) end;
            Addons = {},
            Risky = Info.Risky,
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local ToggleOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 13, 0, 13);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(ToggleOuter, {
            BorderColor3 = 'Black';
        });

        local ToggleInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = ToggleOuter;
        });

        Library:AddToRegistry(ToggleInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(0, 216, 1, 0);
            Position = UDim2.new(1, 6, 0, 0);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = ToggleInner;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 4);
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ToggleLabel;
        });

        local ToggleRegion = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(0, 170, 1, 0);
            ZIndex = 8;
            Parent = ToggleOuter;
        });

        Library:OnHighlight(ToggleRegion, ToggleOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        function Toggle:UpdateColors()
            Toggle:Display();
        end;

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, ToggleRegion)
        end

        function Toggle:Display()
            ToggleInner.BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor;
            ToggleInner.BorderColor3 = Toggle.Value and Library.AccentColorDark or Library.OutlineColor;

            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor';
            Library.RegistryMap[ToggleInner].Properties.BorderColor3 = Toggle.Value and 'AccentColorDark' or 'OutlineColor';
        end;

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func;
            Func(Toggle.Value);
        end;

        function Toggle:SetValue(Bool)
            Bool = (not not Bool);

            Toggle.Value = Bool;
            Toggle:Display();

            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end
            end

            Library:SafeCallback(Toggle.Callback, Toggle.Value);
            Library:SafeCallback(Toggle.Changed, Toggle.Value);
            Library:UpdateDependencyBoxes();
        end;

        ToggleRegion.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value) -- Why was it not like this from the start?
                Library:AttemptSave();
            end;
        end);

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end

        Toggle:Display();
        Groupbox:AddBlank(Info.BlankSize or 5 + 2);
        Groupbox:Resize();

        Toggle.TextLabel = ToggleLabel;
        Toggle.Container = Container;
        setmetatable(Toggle, BaseAddons);

        Toggles[Idx] = Toggle;

        Library:UpdateDependencyBoxes();

        return Toggle;
    end;

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding, 'AddSlider: Missing rounding value.');

        local Slider = {
            Value = Info.Default;
            Min = Info.Min;
            Max = Info.Max;
            Rounding = Info.Rounding;
            MaxSize = 232;
            Type = 'Slider';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end

        local SliderOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 13);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(SliderOuter, {
            BorderColor3 = 'Black';
        });

        local SliderInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = SliderOuter;
        });

        Library:AddToRegistry(SliderInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderColor3 = Library.AccentColorDark;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 7;
            Parent = SliderInner;
        });

        Library:AddToRegistry(Fill, {
            BackgroundColor3 = 'AccentColor';
            BorderColor3 = 'AccentColorDark';
        });

        local HideBorderRight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.new(1, 0, 0, 0);
            Size = UDim2.new(0, 1, 1, 0);
            ZIndex = 8;
            Parent = Fill;
        });

        Library:AddToRegistry(HideBorderRight, {
            BackgroundColor3 = 'AccentColor';
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 14;
            Text = 'Infinite';
            ZIndex = 9;
            Parent = SliderInner;
        });

        Library:OnHighlight(SliderOuter, SliderOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, SliderOuter)
        end

        function Slider:UpdateColors()
            Fill.BackgroundColor3 = Library.AccentColor;
            Fill.BorderColor3 = Library.AccentColorDark;
        end;

        function Slider:Display()
            local Suffix = Info.Suffix or '';

            if Info.Compact then
                DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix
            elseif Info.HideMax then
                DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
            else
                DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix);
            end

            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize));
            Fill.Size = UDim2.new(0, X, 1, 0);

            HideBorderRight.Visible = not (X == Slider.MaxSize or X == 0);
        end;

        function Slider:OnChanged(Func)
            Slider.Changed = Func;
            Func(Slider.Value);
        end;

        local function Round(Value)
            if Slider.Rounding == 0 then
                return math.floor(Value);
            end;


            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
        end;

        function Slider:GetValueFromXOffset(X)
            return Round(Library:MapValue(X, 0, Slider.MaxSize, Slider.Min, Slider.Max));
        end;

        function Slider:SetValue(Str)
            local Num = tonumber(Str);

            if (not Num) then
                return;
            end;

            Num = math.clamp(Num, Slider.Min, Slider.Max);

            Slider.Value = Num;
            Slider:Display();

            Library:SafeCallback(Slider.Callback, Slider.Value);
            Library:SafeCallback(Slider.Changed, Slider.Value);
        end;

        SliderInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                local mPos = Mouse.X;
                local gPos = Fill.Size.X.Offset;
                local Diff = mPos - (Fill.AbsolutePosition.X + gPos);

                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local nMPos = Mouse.X;
                    local nX = math.clamp(gPos + (nMPos - mPos) + Diff, 0, Slider.MaxSize);

                    local nValue = Slider:GetValueFromXOffset(nX);
                    local OldValue = Slider.Value;
                    Slider.Value = nValue;

                    Slider:Display();

                    if nValue ~= OldValue then
                        Library:SafeCallback(Slider.Callback, Slider.Value);
                        Library:SafeCallback(Slider.Changed, Slider.Value);
                    end;

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        Slider:Display();
        Groupbox:AddBlank(Info.BlankSize or 6);
        Groupbox:Resize();

        Options[Idx] = Slider;

        return Slider;
    end;

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString();
            Info.AllowNull = true;
        elseif Info.SpecialType == 'Team' then
            Info.Values = GetTeamsString();
            Info.AllowNull = true;
        end;

        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')

        if (not Info.Text) then
            Info.Compact = true;
        end;

        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {};
            Multi = Info.Multi;
            Type = 'Dropdown';
            SpecialType = Info.SpecialType; -- can be either 'Player' or 'Team'
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local RelativeOffset = 0;

        if not Info.Compact then
            local DropdownLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end

        for _, Element in next, Container:GetChildren() do
            if not Element:IsA('UIListLayout') then
                RelativeOffset = RelativeOffset + Element.Size.Y.Offset;
            end;
        end;

        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(DropdownOuter, {
            BorderColor3 = 'Black';
        });

        local DropdownInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DropdownOuter;
        });

        Library:AddToRegistry(DropdownInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = DropdownInner;
        });

        local DropdownArrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -16, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            Image = 'http://www.roblox.com/asset/?id=6282522798';
            ZIndex = 8;
            Parent = DropdownInner;
        });

        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            TextSize = 14;
            Text = '--';
            TextXAlignment = Enum.TextXAlignment.Left;
            TextWrapped = true;
            ZIndex = 7;
            Parent = DropdownInner;
        });

        Library:OnHighlight(DropdownOuter, DropdownOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, DropdownOuter)
        end

        local MAX_DROPDOWN_ITEMS = 8;

        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            ZIndex = 20;
            Visible = false;
            Parent = ScreenGui;
        });

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1);
        end;

        local function RecalculateListSize(YSize)
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 20 + 2))
        end;

        RecalculateListPosition();
        RecalculateListSize();

        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);

        local ListInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListOuter;
        });

        Library:AddToRegistry(ListInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListInner;

            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',

            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.AccentColor,
        });

        Library:AddToRegistry(Scrolling, {
            ScrollBarImageColor3 = 'AccentColor'
        })

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        });

        function Dropdown:Display()
            local Values = Dropdown.Values;
            local Str = '';

            if Info.Multi then
                for Idx, Value in next, Values do
                    if Dropdown.Value[Value] then
                        Str = Str .. Value .. ', ';
                    end;
                end;

                Str = Str:sub(1, #Str - 2);
            else
                Str = Dropdown.Value or '';
            end;

            ItemList.Text = (Str == '' and '--' or Str);
        end;

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {};

                for Value, Bool in next, Dropdown.Value do
                    table.insert(T, Value);
                end;

                return T;
            else
                return Dropdown.Value and 1 or 0;
            end;
        end;

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values;
            local Buttons = {};

            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA('UIListLayout') then
                    Element:Destroy();
                end;
            end;

            local Count = 0;

            for Idx, Value in next, Values do
                local Table = {};

                Count = Count + 1;

                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Library.OutlineColor;
                    BorderMode = Enum.BorderMode.Middle;
                    Size = UDim2.new(1, -1, 0, 20);
                    ZIndex = 23;
                    Active = true,
                    Parent = Scrolling;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                    BorderColor3 = 'OutlineColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -6, 1, 0);
                    Position = UDim2.new(0, 6, 0, 0);
                    TextSize = 14;
                    Text = Value;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 25;
                    Parent = Button;
                });

                Library:OnHighlight(Button, Button,
                    { BorderColor3 = 'AccentColor', ZIndex = 24 },
                    { BorderColor3 = 'OutlineColor', ZIndex = 23 }
                );

                local Selected;

                if Info.Multi then
                    Selected = Dropdown.Value[Value];
                else
                    Selected = Dropdown.Value == Value;
                end;

                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value];
                    else
                        Selected = Dropdown.Value == Value;
                    end;

                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or Library.FontColor;
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor';
                end;

                ButtonLabel.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local Try = not Selected;

                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value[Value] = true;
                                else
                                    Dropdown.Value[Value] = nil;
                                end;
                            else
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value = Value;
                                else
                                    Dropdown.Value = nil;
                                end;

                                for _, OtherButton in next, Buttons do
                                    OtherButton:UpdateButton();
                                end;
                            end;

                            Table:UpdateButton();
                            Dropdown:Display();

                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);

                            Library:AttemptSave();
                        end;
                    end;
                end);

                Table:UpdateButton();
                Dropdown:Display();

                Buttons[Button] = Table;
            end;

            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20) + 1);

            local Y = math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1;
            RecalculateListSize(Y);
        end;

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues;
            end;

            Dropdown:BuildDropdownList();
        end;

        function Dropdown:OpenDropdown()
            ListOuter.Visible = true;
            Library.OpenedFrames[ListOuter] = true;
            DropdownArrow.Rotation = 180;
        end;

        function Dropdown:CloseDropdown()
            ListOuter.Visible = false;
            Library.OpenedFrames[ListOuter] = nil;
            DropdownArrow.Rotation = 0;
        end;

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func;
            Func(Dropdown.Value);
        end;

        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nTable = {};

                for Value, Bool in next, Val do
                    if table.find(Dropdown.Values, Value) then
                        nTable[Value] = true
                    end;
                end;

                Dropdown.Value = nTable;
            else
                if (not Val) then
                    Dropdown.Value = nil;
                elseif table.find(Dropdown.Values, Val) then
                    Dropdown.Value = Val;
                end;
            end;

            Dropdown:BuildDropdownList();

            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
        end;

        DropdownOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then
                    Dropdown:CloseDropdown();
                else
                    Dropdown:OpenDropdown();
                end;
            end;
        end);

        InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    Dropdown:CloseDropdown();
                end;
            end;
        end);

        Dropdown:BuildDropdownList();
        Dropdown:Display();

        local Defaults = {}

        if type(Info.Default) == 'string' then
            local Idx = table.find(Dropdown.Values, Info.Default)
            if Idx then
                table.insert(Defaults, Idx)
            end
        elseif type(Info.Default) == 'table' then
            for _, Value in next, Info.Default do
                local Idx = table.find(Dropdown.Values, Value)
                if Idx then
                    table.insert(Defaults, Idx)
                end
            end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index];
                end

                if (not Info.Multi) then break end
            end

            Dropdown:BuildDropdownList();
            Dropdown:Display();
        end

        Groupbox:AddBlank(Info.BlankSize or 5);
        Groupbox:Resize();

        Options[Idx] = Dropdown;

        return Dropdown;
    end;

    function Funcs:AddDependencyBox()
        local Depbox = {
            Dependencies = {};
        };
        
        local Groupbox = self;
        local Container = Groupbox.Container;

        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
            Visible = false;
            Parent = Container;
        });

        local Frame = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Visible = true;
            Parent = Holder;
        });

        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Frame;
        });

        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y);
            Groupbox:Resize();
        end;

        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            Depbox:Resize();
        end);

        Holder:GetPropertyChangedSignal('Visible'):Connect(function()
            Depbox:Resize();
        end);

        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1];
                local Value = Dependency[2];

                if Elem.Type == 'Toggle' and Elem.Value ~= Value then
                    Holder.Visible = false;
                    Depbox:Resize();
                    return;
                end;
            end;

            Holder.Visible = true;
            Depbox:Resize();
        end;

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not of type `table`.');
                assert(Dependency[1], 'SetupDependencies: Dependency is missing element argument.');
                assert(Dependency[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.');
            end;

            Depbox.Dependencies = Dependencies;
            Depbox:Update();
        end;

        Depbox.Container = Frame;

        setmetatable(Depbox, BaseGroupbox);

        table.insert(Library.DependencyBoxes, Depbox);

        return Depbox;
    end;

    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

-- < Create other UI elements >
do
    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 0, 0, 40);
        Size = UDim2.new(0, 300, 0, 200);
        ZIndex = 100;
        Parent = ScreenGui;
    });

    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 4);
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.NotificationArea;
    });

    local WatermarkOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 100, 0, -25);
        Size = UDim2.new(0, 213, 0, 20);
        ZIndex = 200;
        Visible = false;
        Parent = ScreenGui;
    });

    local WatermarkInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 201;
        Parent = WatermarkOuter;
    });

    Library:AddToRegistry(WatermarkInner, {
        BorderColor3 = 'AccentColor';
    });

    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 202;
        Parent = WatermarkInner;
    });

    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });

    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });

    local WatermarkLabel = Library:CreateLabel({
        Position = UDim2.new(0, 5, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        TextSize = 14;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 203;
        Parent = InnerFrame;
    });

    Library.Watermark = WatermarkOuter;
    Library.WatermarkText = WatermarkLabel;
    Library:MakeDraggable(Library.Watermark);



    local KeybindOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 10, 0.5, 0);
        Size = UDim2.new(0, 210, 0, 20);
        Visible = false;
        ZIndex = 100;
        Parent = ScreenGui;
    });

    local KeybindInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = KeybindOuter;
    });

    Library:AddToRegistry(KeybindInner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    }, true);

    local ColorFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2);
        ZIndex = 102;
        Parent = KeybindInner;
    });

    Library:AddToRegistry(ColorFrame, {
        BackgroundColor3 = 'AccentColor';
    }, true);

    local KeybindLabel = Library:CreateLabel({
        Size = UDim2.new(1, 0, 0, 20);
        Position = UDim2.fromOffset(5, 2),
        TextXAlignment = Enum.TextXAlignment.Left,

        Text = 'Keybinds';
        ZIndex = 104;
        Parent = KeybindInner;
    });

    local KeybindContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -20);
        Position = UDim2.new(0, 0, 0, 20);
        ZIndex = 1;
        Parent = KeybindInner;
    });

    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = KeybindContainer;
    });

    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 5),
        Parent = KeybindContainer,
    })

    Library.KeybindFrame = KeybindOuter;
    Library.KeybindContainer = KeybindContainer;
    Library:MakeDraggable(KeybindOuter);
end;

function Library:SetWatermarkVisibility(Bool)
    Library.Watermark.Visible = Bool;
end;

function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 14);
    Library.Watermark.Size = UDim2.new(0, X + 15, 0, (Y * 1.5) + 3);
    Library:SetWatermarkVisibility(true)

    Library.WatermarkText.Text = Text;
end;

function Library:Notify(Text, Time)
    local XSize, YSize = Library:GetTextBounds(Text, Library.Font, 14);

    YSize = YSize + 7

    local NotifyOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 100, 0, 10);
        Size = UDim2.new(0, 0, 0, YSize);
        ClipsDescendants = true;
        ZIndex = 100;
        Parent = Library.NotificationArea;
    });

    local NotifyInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = NotifyOuter;
    });

    Library:AddToRegistry(NotifyInner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    }, true);

    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 102;
        Parent = NotifyInner;
    });

    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });

    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });

    local NotifyLabel = Library:CreateLabel({
        Position = UDim2.new(0, 4, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        Text = Text;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextSize = 14;
        ZIndex = 103;
        Parent = InnerFrame;
    });

    local LeftColor = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, -1, 0, -1);
        Size = UDim2.new(0, 3, 1, 2);
        ZIndex = 104;
        Parent = NotifyOuter;
    });

    Library:AddToRegistry(LeftColor, {
        BackgroundColor3 = 'AccentColor';
    }, true);

    pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, XSize + 8 + 4, 0, YSize), 'Out', 'Quad', 0.4, true);

    task.spawn(function()
        wait(Time or 5);

        pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, 0, 0, YSize), 'Out', 'Quad', 0.4, true);

        wait(0.4);

        NotifyOuter:Destroy();
    end);
end;

function Library:CreateWindow(...)
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.zero }

    if type(...) == 'table' then
        Config = ...;
    else
        Config.Title = Arguments[1]
        Config.AutoShow = Arguments[2] or false;
    end

    if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end

    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end
    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(550, 600) end

    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5)
        Config.Position = UDim2.fromScale(0.5, 0.5)
    end

    local Window = {
        Tabs = {};
    };

    local Outer = Library:Create('Frame', {
        AnchorPoint = Config.AnchorPoint,
        BackgroundColor3 = Color3.new(0, 0, 0);
        BorderSizePixel = 0;
        Position = Config.Position,
        Size = Config.Size,
        Visible = false;
        ZIndex = 1;
        Parent = ScreenGui;
    });

    Library:MakeDraggable(Outer, 25);

    local Inner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 1;
        Parent = Outer;
    });

    Library:AddToRegistry(Inner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'AccentColor';
    });

    local WindowLabel = Library:CreateLabel({
        Position = UDim2.new(0, 7, 0, 0);
        Size = UDim2.new(0, 0, 0, 25);
        Text = Config.Title or '';
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 1;
        Parent = Inner;
    });

    local MainSectionOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8, 0, 25);
        Size = UDim2.new(1, -16, 1, -33);
        ZIndex = 1;
        Parent = Inner;
    });

    Library:AddToRegistry(MainSectionOuter, {
        BackgroundColor3 = 'BackgroundColor';
        BorderColor3 = 'OutlineColor';
    });

    local MainSectionInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Color3.new(0, 0, 0);
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 1;
        Parent = MainSectionOuter;
    });

    Library:AddToRegistry(MainSectionInner, {
        BackgroundColor3 = 'BackgroundColor';
    });

    local TabArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 8, 0, 8);
        Size = UDim2.new(1, -16, 0, 21);
        ZIndex = 1;
        Parent = MainSectionInner;
    });

    local TabListLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding);
        FillDirection = Enum.FillDirection.Horizontal;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = TabArea;
    });

    local TabContainer = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8, 0, 30);
        Size = UDim2.new(1, -16, 1, -38);
        ZIndex = 2;
        Parent = MainSectionInner;
    });
    

    Library:AddToRegistry(TabContainer, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    function Window:SetWindowTitle(Title)
        WindowLabel.Text = Title;
    end;

    function Window:AddTab(Name)
        local Tab = {
            Groupboxes = {};
            Tabboxes = {};
        };

        local TabButtonWidth = Library:GetTextBounds(Name, Library.Font, 16);

        local TabButton = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            Size = UDim2.new(0, TabButtonWidth + 8 + 4, 1, 0);
            ZIndex = 1;
            Parent = TabArea;
        });

        Library:AddToRegistry(TabButton, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        local TabButtonLabel = Library:CreateLabel({
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, -1);
            Text = Name;
            ZIndex = 1;
            Parent = TabButton;
        });

        local Blocker = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 0, 1, 0);
            Size = UDim2.new(1, 0, 0, 1);
            BackgroundTransparency = 1;
            ZIndex = 3;
            Parent = TabButton;
        });

        Library:AddToRegistry(Blocker, {
            BackgroundColor3 = 'MainColor';
        });

        local TabFrame = Library:Create('Frame', {
            Name = 'TabFrame',
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            Visible = false;
            ZIndex = 2;
            Parent = TabContainer;
        });

        local LeftSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 8 - 1, 0, 8 - 1);
            Size = UDim2.new(0.5, -12 + 2, 0, 507 + 2);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = '';
            TopImage = '';
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        });

        local RightSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0.5, 4 + 1, 0, 8 - 1);
            Size = UDim2.new(0.5, -12 + 2, 0, 507 + 2);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = '';
            TopImage = '';
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = LeftSide;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = RightSide;
        });

        for _, Side in next, { LeftSide, RightSide } do
            Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y);
            end);
        end;

        function Tab:ShowTab()
            for _, Tab in next, Window.Tabs do
                Tab:HideTab();
            end;

            Blocker.BackgroundTransparency = 0;
            TabButton.BackgroundColor3 = Library.MainColor;
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'MainColor';
            TabFrame.Visible = true;
        end;

        function Tab:HideTab()
            Blocker.BackgroundTransparency = 1;
            TabButton.BackgroundColor3 = Library.BackgroundColor;
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'BackgroundColor';
            TabFrame.Visible = false;
        end;

        function Tab:SetLayoutOrder(Position)
            TabButton.LayoutOrder = Position;
            TabListLayout:ApplyLayout();
        end;

        function Tab:AddGroupbox(Info)
            local Groupbox = {};

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 507 + 2);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                -- BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 5;
                Parent = BoxInner;
            });

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = 'AccentColor';
            });

            local GroupboxLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 18);
                Position = UDim2.new(0, 4, 0, 2);
                TextSize = 14;
                Text = Info.Name;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 5;
                Parent = BoxInner;
            });

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 4, 0, 20);
                Size = UDim2.new(1, -4, 1, -20);
                ZIndex = 1;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = Container;
            });

            function Groupbox:Resize()
                local Size = 0;

                for _, Element in next, Groupbox.Container:GetChildren() do
                    if (not Element:IsA('UIListLayout')) and Element.Visible then
                        Size = Size + Element.Size.Y.Offset;
                    end;
                end;

                BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
            end;

            Groupbox.Container = Container;
            setmetatable(Groupbox, BaseGroupbox);

            Groupbox:AddBlank(3);
            Groupbox:Resize();

            Tab.Groupboxes[Info.Name] = Groupbox;

            return Groupbox;
        end;

        function Tab:AddLeftGroupbox(Name)
            return Tab:AddGroupbox({ Side = 1; Name = Name; });
        end;

        function Tab:AddRightGroupbox(Name)
            return Tab:AddGroupbox({ Side = 2; Name = Name; });
        end;

        function Tab:AddTabbox(Info)
            local Tabbox = {
                Tabs = {};
            };

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 0);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                -- BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 10;
                Parent = BoxInner;
            });

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = 'AccentColor';
            });

            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 0, 0, 1);
                Size = UDim2.new(1, 0, 0, 18);
                ZIndex = 5;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TabboxButtons;
            });

            function Tabbox:AddTab(Name)
                local Tab = {};

                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Color3.new(0, 0, 0);
                    Size = UDim2.new(0.5, 0, 1, 0);
                    ZIndex = 6;
                    Parent = TabboxButtons;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Size = UDim2.new(1, 0, 1, 0);
                    TextSize = 14;
                    Text = Name;
                    TextXAlignment = Enum.TextXAlignment.Center;
                    ZIndex = 7;
                    Parent = Button;
                });

                local Block = Library:Create('Frame', {
                    BackgroundColor3 = Library.BackgroundColor;
                    BorderSizePixel = 0;
                    Position = UDim2.new(0, 0, 1, 0);
                    Size = UDim2.new(1, 0, 0, 1);
                    Visible = false;
                    ZIndex = 9;
                    Parent = Button;
                });

                Library:AddToRegistry(Block, {
                    BackgroundColor3 = 'BackgroundColor';
                });

                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 4, 0, 20);
                    Size = UDim2.new(1, -4, 1, -20);
                    ZIndex = 1;
                    Visible = false;
                    Parent = BoxInner;
                });

                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical;
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    Parent = Container;
                });

                function Tab:Show()
                    for _, Tab in next, Tabbox.Tabs do
                        Tab:Hide();
                    end;

                    Container.Visible = true;
                    Block.Visible = true;

                    Button.BackgroundColor3 = Library.BackgroundColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor';

                    Tab:Resize();
                end;

                function Tab:Hide()
                    Container.Visible = false;
                    Block.Visible = false;

                    Button.BackgroundColor3 = Library.MainColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'MainColor';
                end;

                function Tab:Resize()
                    local TabCount = 0;

                    for _, Tab in next, Tabbox.Tabs do
                        TabCount = TabCount + 1;
                    end;

                    for _, Button in next, TabboxButtons:GetChildren() do
                        if not Button:IsA('UIListLayout') then
                            Button.Size = UDim2.new(1 / TabCount, 0, 1, 0);
                        end;
                    end;

                    if (not Container.Visible) then
                        return;
                    end;

                    local Size = 0;

                    for _, Element in next, Tab.Container:GetChildren() do
                        if (not Element:IsA('UIListLayout')) and Element.Visible then
                            Size = Size + Element.Size.Y.Offset;
                        end;
                    end;

                    BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
                end;

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                        Tab:Show();
                        Tab:Resize();
                    end;
                end);

                Tab.Container = Container;
                Tabbox.Tabs[Name] = Tab;

                setmetatable(Tab, BaseGroupbox);

                Tab:AddBlank(3);
                Tab:Resize();

                -- Show first tab (number is 2 cus of the UIListLayout that also sits in that instance)
                if #TabboxButtons:GetChildren() == 2 then
                    Tab:Show();
                end;

                return Tab;
            end;

            Tab.Tabboxes[Info.Name or ''] = Tabbox;

            return Tabbox;
        end;

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 1; });
        end;

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 2; });
        end;

        TabButton.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Tab:ShowTab();
            end;
        end);

        -- This was the first tab added, so we show it by default.
        if #TabContainer:GetChildren() == 1 then
            Tab:ShowTab();
        end;

        Window.Tabs[Name] = Tab;
        return Tab;
    end;

    local ModalElement = Library:Create('TextButton', {
        BackgroundTransparency = 1;
        Size = UDim2.new(0, 0, 0, 0);
        Visible = true;
        Text = '';
        Modal = false;
        Parent = ScreenGui;
    });

    local TransparencyCache = {};
    local Toggled = false;
    local Fading = false;

    function Library:Toggle()
        if Fading then
            return;
        end;

        local FadeTime = Config.MenuFadeTime;
        Fading = true;
        Toggled = (not Toggled);
        ModalElement.Modal = Toggled;

        if Toggled then
            -- A bit scuffed, but if we're going from not toggled -> toggled we want to show the frame immediately so that the fade is visible.
            Outer.Visible = true;

            task.spawn(function()
                -- TODO: add cursor fade?
                local State = InputService.MouseIconEnabled;

                local Cursor = Drawing.new('Triangle');
                Cursor.Thickness = 1;
                Cursor.Filled = true;
                Cursor.Visible = true;

                local CursorOutline = Drawing.new('Triangle');
                CursorOutline.Thickness = 1;
                CursorOutline.Filled = false;
                CursorOutline.Color = Color3.new(0, 0, 0);
                CursorOutline.Visible = true;

                while Toggled and ScreenGui.Parent do
                    InputService.MouseIconEnabled = false;

                    local mPos = InputService:GetMouseLocation();

                    Cursor.Color = Library.AccentColor;

                    Cursor.PointA = Vector2.new(mPos.X, mPos.Y);
                    Cursor.PointB = Vector2.new(mPos.X + 16, mPos.Y + 6);
                    Cursor.PointC = Vector2.new(mPos.X + 6, mPos.Y + 16);

                    CursorOutline.PointA = Cursor.PointA;
                    CursorOutline.PointB = Cursor.PointB;
                    CursorOutline.PointC = Cursor.PointC;

                    RenderStepped:Wait();
                end;

                InputService.MouseIconEnabled = State;

                Cursor:Remove();
                CursorOutline:Remove();
            end);
        end;

        for _, Desc in next, Outer:GetDescendants() do
            local Properties = {};

            if Desc:IsA('ImageLabel') then
                table.insert(Properties, 'ImageTransparency');
                table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('TextLabel') or Desc:IsA('TextBox') then
                table.insert(Properties, 'TextTransparency');
            elseif Desc:IsA('Frame') or Desc:IsA('ScrollingFrame') then
                table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('UIStroke') then
                table.insert(Properties, 'Transparency');
            end;

            local Cache = TransparencyCache[Desc];

            if (not Cache) then
                Cache = {};
                TransparencyCache[Desc] = Cache;
            end;

            for _, Prop in next, Properties do
                if not Cache[Prop] then
                    Cache[Prop] = Desc[Prop];
                end;

                if Cache[Prop] == 1 then
                    continue;
                end;

                TweenService:Create(Desc, TweenInfo.new(FadeTime, Enum.EasingStyle.Linear), { [Prop] = Toggled and Cache[Prop] or 1 }):Play();
            end;
        end;

        task.wait(FadeTime);

        Outer.Visible = Toggled;

        Fading = false;
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
            task.spawn(Library.Toggle)
        end
    end))

    if Config.AutoShow then task.spawn(Library.Toggle) end

    Window.Holder = Outer;

    return Window;
end;

local function OnPlayerChange()
    local PlayerList = GetPlayersString();

    for _, Value in next, Options do
        if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then
            Value:SetValues(PlayerList);
        end;
    end;
end;

Players.PlayerAdded:Connect(OnPlayerChange);
Players.PlayerRemoving:Connect(OnPlayerChange);

function Library:CreateSpotifyPlayer()
    local Spotify = {}

    local InputService      = UserInputService
    local UserInputService  = UserInputService
    local Players           = game:GetService("Players")
    local RunService        = game:GetService("RunService")

    local Request = request
        or http_request
        or (syn and syn.request)
        or (getgenv and getgenv().http and getgenv().http.request)
    local GetCustomAsset = getcustomasset or getsynasset

    local SpotifyFolder = (Library.Directory or "spotifyforRawr") .. "/Spotify"
    local CacheFolder   = SpotifyFolder .. "/Cache"
    local TokenPath     = (Library.Directory or "spotifyforRawr") .. "/token.txt"
    local PlaceholderImage = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    local PollInterval  = 1

    if not isfolder(SpotifyFolder) then makefolder(SpotifyFolder) end
    if not isfolder(CacheFolder)   then makefolder(CacheFolder)   end

    local ThemeInactiveText = Color3.fromRGB(180, 180, 180)
    local SKIP_ASSET_ID = "rbxassetid://9607545497"

    local Connections = {}
    local Destroyed = false

    local function Connect(signal, callback)
        local conn = signal:Connect(callback)
        table.insert(Connections, conn)
        return conn
    end

    local function New(Class, Props, RegProps, Hud)
        local inst = Library:Create(Class, Props)
        if RegProps then Library:AddToRegistry(inst, RegProps, Hud) end
        return inst
    end

    local function Tween(inst, Props, Info)
        if not inst or not inst.Parent then return end
        TweenService:Create(
            inst,
            Info or TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            Props
        ):Play()
    end

    local function ReadToken()
        if not isfile(TokenPath) then writefile(TokenPath, "") return "" end
        return (readfile(TokenPath):gsub("^%s*(.-)%s*$", "%1"))
    end

    local function DecodeTokenConfig(RawToken)
        local Clean = (RawToken or ""):gsub("^%s*(.-)%s*$", "%1")
        if Clean == "" then
            return { Raw="", AccessToken="", RefreshToken="", ClientId="", ClientSecret="", ExpiresAt=0 }
        end
        if Clean:sub(1,1) ~= "{" then
            return { Raw=Clean, AccessToken=Clean, RefreshToken="", ClientId="", ClientSecret="", ExpiresAt=math.huge }
        end
        local ok, parsed = pcall(HttpService.JSONDecode, HttpService, Clean)
        if not ok or type(parsed) ~= "table" then
            return { Raw=Clean, AccessToken="", RefreshToken="", ClientId="", ClientSecret="", ExpiresAt=0 }
        end
        return {
            Raw = Clean,
            AccessToken  = tostring(parsed.access_token  or parsed.token or ""):gsub("^%s*(.-)%s*$","%1"),
            RefreshToken = tostring(parsed.refresh_token or ""):gsub("^%s*(.-)%s*$","%1"),
            ClientId     = tostring(parsed.client_id     or ""):gsub("^%s*(.-)%s*$","%1"),
            ClientSecret = tostring(parsed.client_secret or ""):gsub("^%s*(.-)%s*$","%1"),
            ExpiresAt    = tonumber(parsed.expires_at) or 0,
        }
    end

    local function EncodeTokenConfig(Config)
        if not Config then return "" end
        if (Config.RefreshToken or "") == "" then return Config.AccessToken or "" end
        local ok, enc = pcall(HttpService.JSONEncode, HttpService, {
            access_token=Config.AccessToken or "", refresh_token=Config.RefreshToken or "",
            client_id=Config.ClientId or "", client_secret=Config.ClientSecret or "",
            expires_at=math.floor(tonumber(Config.ExpiresAt) or 0),
        })
        return ok and enc or ""
    end

    local function WriteToken(ConfigOrToken)
        if type(ConfigOrToken) == "table" then
            writefile(TokenPath, EncodeTokenConfig(ConfigOrToken))
        else
            writefile(TokenPath, ConfigOrToken or "")
        end
    end

    local TokenConfig = DecodeTokenConfig(ReadToken())
    local Token = TokenConfig.AccessToken

    local CollapsedSize = UDim2.new(0, 248, 0, 88)
    local ExpandedSize  = UDim2.new(0, 540, 0, 250)
    local ResultButtons = {}
    local SearchResults = {}
    local SearchTrackResults = {}
    local SearchAlbumBrowse
    local CurrentTrack
    local IsExpanded = false
    local Seeking = false
    local SearchRequestId = 0
    local SearchDelay = 0.25
    local IsVisible = true
    local CustomPosition
    local LastKnownPlaying = false
    local CoverSpin = 0
    local SkippingTo = false

    local LyricsCache           = {}
    local CurrentLyrics         = {}
    local CurrentLyricsSynced   = false
    local CurrentLyricsTrackId  = nil
    local CurrentLyricsLoading  = false
    local CurrentHighlightIndex = 0
    local SidebarTab            = "queue"
    local LyricsRequestId       = 0
    local LyricsRenderGen       = 0

    local ContextMenuFrame      = nil
    local ContextMenuTrack      = nil

    local PlayUri
    local AddToQueue
    local RefreshSoon

    local Items = {}
    local Icons = {}
    local QueueRows = {}

    local function CreateControlButton(Key, Parent, Image, FrameSize, IconSize, IconOffsetY)
        local btn = New("TextButton", {
            Name="\0", Parent=Parent,
            Size=UDim2.new(0, FrameSize, 0, 20),
            BorderSizePixel=0, AutoButtonColor=false,
            BackgroundTransparency=1, Text="",
        })
        Items[Key] = btn
        Icons[Key] = New("ImageLabel", {
            Name="\0", Parent=btn,
            AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.new(0.5,0,0.5,IconOffsetY or 0),
            Size=UDim2.new(0,IconSize,0,IconSize),
            BorderSizePixel=0, BackgroundTransparency=1,
            Image=Image, ImageColor3=Library.FontColor,
        })
    end

    if Library.ScreenGui and Library.ScreenGui.ZIndexBehavior == Enum.ZIndexBehavior.Global then
        Library.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    end

    Items["SpotifyPlayer"] = New("Frame", {
        Name="\0", Parent=Library.ScreenGui,
        Position=UDim2.new(0, 30, 0, 240),
        Size=CollapsedSize, BorderSizePixel=0,
        BackgroundColor3=Library.MainColor,
        ClipsDescendants=true,
        ZIndex = 50,
    }, { BackgroundColor3='MainColor' })
    Library:MakeDraggable(Items["SpotifyPlayer"])

    New("UIStroke", { Name="\0", Parent=Items["SpotifyPlayer"],
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border, LineJoinMode=Enum.LineJoinMode.Miter,
        Color=Library.Black, Thickness=1 }, { Color='Black' })
    New("UIStroke", { Name="\0", Parent=Items["SpotifyPlayer"],
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border, LineJoinMode=Enum.LineJoinMode.Miter,
        Color=Library.OutlineColor, Thickness=1, BorderOffset=UDim.new(0,1) }, { Color='OutlineColor' })

    Items["InnerBacking"] = New("Frame", {
        Name="\0", Parent=Items["SpotifyPlayer"],
        Position=UDim2.new(0,1,0,1), Size=UDim2.new(1,-2,1,-2),
        BorderSizePixel=0, BackgroundColor3=Library.BackgroundColor,
        ZIndex=0,
    }, { BackgroundColor3='BackgroundColor' })

    Items["AccentLiner"] = New("Frame", {
        Name="\0", Parent=Items["SpotifyPlayer"],
        Size=UDim2.new(1,0,0,2), BorderSizePixel=0,
        BackgroundColor3=Library.AccentColor,
        ZIndex=2,
    }, { BackgroundColor3='AccentColor' })

    Items["SearchBackground"] = New("Frame", {
        Name="\0", Parent=Items["SpotifyPlayer"],
        Position=UDim2.new(0, 10, 0, -40),
        Size=UDim2.new(0, 250, 0, 24),
        BorderSizePixel=0, BackgroundColor3=Library.BackgroundColor,
        ZIndex=1,
    }, { BackgroundColor3='BackgroundColor' })

    New("UIStroke", { Name="\0", Parent=Items["SearchBackground"],
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border, LineJoinMode=Enum.LineJoinMode.Miter,
        Color=Library.OutlineColor, Thickness=1, BorderOffset=UDim.new(0,1) }, { Color='OutlineColor' })

    Items["SearchInput"] = New("TextBox", {
        Name="\0", Font=Library.Font, TextSize=14,
        Parent=Items["SearchBackground"],
        AnchorPoint=Vector2.new(0,0.5),
        PlaceholderColor3=ThemeInactiveText,
        PlaceholderText="Search songs, artists, albums",
        Size=UDim2.new(1,-12,0,15),
        TextColor3=Library.FontColor, Text="",
        BackgroundTransparency=1,
        TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.new(0,6,0.5,-1),
        ClearTextOnFocus=false, BorderSizePixel=0,
        ZIndex=2,
    }, { TextColor3='FontColor' })

    Items["SearchResults"] = New("ScrollingFrame", {
        Name="\0", Parent=Items["SpotifyPlayer"],
        Position=UDim2.new(0, 10, 0, -170),
        Size=UDim2.new(0, 250, 0, 128),
        BorderSizePixel=0, CanvasSize=UDim2.new(),
        AutomaticCanvasSize=Enum.AutomaticSize.Y,
        ScrollingDirection=Enum.ScrollingDirection.Y,
        ScrollBarThickness=0,
        BackgroundColor3=Library.MainColor,
        ZIndex=1,
    }, { BackgroundColor3='MainColor' })

    New("UIStroke", { Name="\0", Parent=Items["SearchResults"],
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border, LineJoinMode=Enum.LineJoinMode.Miter,
        Color=Library.OutlineColor, Thickness=1, BorderOffset=UDim.new(0,1) }, { Color='OutlineColor' })

    New("UIListLayout", { Name="\0", Parent=Items["SearchResults"],
        SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4),
        HorizontalAlignment=Enum.HorizontalAlignment.Center })

    for Index = 1, 8 do
        local Row = {}
        Row.Frame = New("Frame", {
            Name="\0", Parent=Items["SearchResults"],
            Size=UDim2.new(1,-8,0,42),
            BorderSizePixel=0, BackgroundTransparency=1,
            BackgroundColor3=Library.MainColor, Visible=false,
            ZIndex=2,
        })
        Row.Divider = New("Frame", {
            Name="\0", Parent=Row.Frame,
            AnchorPoint=Vector2.new(0.5,1),
            Position=UDim2.new(0.5,0,1,-1),
            Size=UDim2.new(1,-22,0,1), BorderSizePixel=0,
            BackgroundColor3=Library.OutlineColor,
            ZIndex=2,
        }, { BackgroundColor3='OutlineColor' })
        Row.Cover = New("ImageLabel", {
            Name="\0", Parent=Row.Frame,
            Image=PlaceholderImage, BackgroundTransparency=1,
            ScaleType=Enum.ScaleType.Crop,
            Size=UDim2.new(0,34,0,34),
            Position=UDim2.new(0,4,0,4), BorderSizePixel=0,
            ZIndex=2,
        })
        Row.Title = New("TextLabel", {
            Name="\0", Font=Library.Font, TextSize=14,
            Parent=Row.Frame, TextColor3=Library.FontColor,
            Text="", BackgroundTransparency=1,
            TextXAlignment=Enum.TextXAlignment.Left,
            Position=UDim2.new(0,44,0,4),
            Size=UDim2.new(1,-48,0,17),
            BorderSizePixel=0, TextTruncate=Enum.TextTruncate.AtEnd,
            ZIndex=2,
        }, { TextColor3='FontColor' })
        Row.Album = New("TextLabel", {
            Name="\0", Font=Library.Font, TextSize=14,
            Parent=Row.Frame, TextColor3=ThemeInactiveText,
            Text="", BackgroundTransparency=1,
            TextXAlignment=Enum.TextXAlignment.Left,
            Position=UDim2.new(0,44,0,22),
            Size=UDim2.new(1,-48,0,16),
            BorderSizePixel=0, TextTruncate=Enum.TextTruncate.AtEnd,
            ZIndex=2,
        })
        Row.Button = New("TextButton", {
            Name="\0", Parent=Row.Frame,
            Size=UDim2.new(1,0,1,0),
            BorderSizePixel=0, BackgroundTransparency=1, Text="",
            ZIndex=3,
        })
        ResultButtons[Index] = Row
    end

    Items["LyricsFrame"] = New("Frame", {
        Name="\0", Parent=Items["SpotifyPlayer"],
        Position=UDim2.new(1,10,0,10),
        Size=UDim2.new(0,260,0,146),
        BorderSizePixel=0, BackgroundColor3=Library.MainColor,
        ZIndex=1,
    }, { BackgroundColor3='MainColor' })

    New("UIStroke", { Name="\0", Parent=Items["LyricsFrame"],
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border, LineJoinMode=Enum.LineJoinMode.Miter,
        Color=Library.OutlineColor, Thickness=1, BorderOffset=UDim.new(0,1) }, { Color='OutlineColor' })

    Items["QueueTab"] = New("TextButton", {
        Name="\0", Font=Library.Font, TextSize=14,
        Parent=Items["LyricsFrame"], TextColor3=Library.AccentColor,
        Text="Queue", BackgroundTransparency=1, AutoButtonColor=false,
        TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.new(0,8,0,6),
        Size=UDim2.new(0.5,-8,0,14), BorderSizePixel=0,
        ZIndex=2,
    }, { TextColor3='AccentColor' })

    Items["LyricsTab"] = New("TextButton", {
        Name="\0", Font=Library.Font, TextSize=14,
        Parent=Items["LyricsFrame"], TextColor3=ThemeInactiveText,
        Text="Lyrics", BackgroundTransparency=1, AutoButtonColor=false,
        TextXAlignment=Enum.TextXAlignment.Right,
        Position=UDim2.new(0.5,0,0,6),
        Size=UDim2.new(0.5,-8,0,14), BorderSizePixel=0,
        ZIndex=2,
    })

    Items["QueueScroll"] = New("ScrollingFrame", {
        Name="\0", Parent=Items["LyricsFrame"],
        Position=UDim2.new(0,8,0,24),
        Size=UDim2.new(1,-16,1,-32),
        BorderSizePixel=0, BackgroundTransparency=1,
        CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
        ScrollingDirection=Enum.ScrollingDirection.Y,
        ScrollBarThickness=1,
        ScrollBarImageColor3=Library.OutlineColor,
        ZIndex=2,
    }, { ScrollBarImageColor3='OutlineColor' })

    New("UIListLayout", { Name="\0", Parent=Items["QueueScroll"],
        SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,2),
        HorizontalAlignment=Enum.HorizontalAlignment.Center })

    Items["QueueEmpty"] = New("TextLabel", {
        Name="\0", Font=Library.Font, TextSize=14,
        Parent=Items["QueueScroll"], TextColor3=ThemeInactiveText,
        Text="Nothing is currently playing.",
        BackgroundTransparency=1,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Top,
        Size=UDim2.new(1,-8,0,20),
        BorderSizePixel=0, TextWrapped=true, RichText=true,
        ZIndex=2,
    })

    for Index = 1, 12 do
        local Row = {}
        Row.Frame = New("Frame", {
            Name="\0", Parent=Items["QueueScroll"],
            Size=UDim2.new(1,-8,0,38),
            BorderSizePixel=0, BackgroundTransparency=1,
            BackgroundColor3=Library.MainColor, Visible=false,
            ZIndex=2,
        })
        Row.Cover = New("ImageLabel", {
            Name="\0", Parent=Row.Frame,
            Image=PlaceholderImage, BackgroundTransparency=1,
            ScaleType=Enum.ScaleType.Crop,
            Size=UDim2.new(0,30,0,30),
            Position=UDim2.new(0,4,0,4), BorderSizePixel=0,
            ZIndex=2,
        })
        New("UICorner", { Name="\0", Parent=Row.Cover, CornerRadius=UDim.new(0,3) })
        Row.Title = New("TextLabel", {
            Name="\0", Font=Library.Font, TextSize=14,
            Parent=Row.Frame, TextColor3=Library.FontColor,
            Text="", BackgroundTransparency=1,
            TextXAlignment=Enum.TextXAlignment.Left,
            Position=UDim2.new(0,40,0,2),
            Size=UDim2.new(1,-44,0,17),
            BorderSizePixel=0, TextTruncate=Enum.TextTruncate.AtEnd,
            ZIndex=2,
        }, { TextColor3='FontColor' })
        Row.Artist = New("TextLabel", {
            Name="\0", Font=Library.Font, TextSize=14,
            Parent=Row.Frame, TextColor3=ThemeInactiveText,
            Text="", BackgroundTransparency=1,
            TextXAlignment=Enum.TextXAlignment.Left,
            Position=UDim2.new(0,40,0,19),
            Size=UDim2.new(1,-44,0,16),
            BorderSizePixel=0, TextTruncate=Enum.TextTruncate.AtEnd,
            ZIndex=2,
        })
        Row.Button = New("TextButton", {
            Name="\0", Parent=Row.Frame,
            Size=UDim2.new(1,0,1,0),
            BorderSizePixel=0, BackgroundTransparency=1, Text="",
            ZIndex=3,
        })
        Connect(Row.Button.MouseEnter, function()
            if Row.Frame.Visible then
                Tween(Row.Frame, { BackgroundTransparency = 0.85, BackgroundColor3 = Library.AccentColor }, TweenInfo.new(0.1))
            end
        end)
        Connect(Row.Button.MouseLeave, function()
            Tween(Row.Frame, { BackgroundTransparency = 1 }, TweenInfo.new(0.1))
        end)
        Connect(Row.Button.MouseButton1Click, function()
            if not Row.Frame.Visible then return end
            if SkippingTo then return end
            local t = Row.Track
            if not t or not t.Uri or t.Uri == "" then return end
            SkippingTo = true
            task.spawn(function()
                pcall(function()
                    local d = MakeRequest("me/player")
                    local contextUri = nil
                    if type(d) == "table" and type(d.context) == "table" then
                        contextUri = d.context.uri
                    end
                    if contextUri and contextUri ~= "" then
                        MakeRequest("me/player/play", "PUT", true, {
                            context_uri = contextUri,
                            offset = { uri = t.Uri },
                            position_ms = 0,
                        })
                    else
                        PlayUri(t.Uri)
                    end
                end)
                task.wait(0.7)
                SkippingTo = false
                Spotify:Refresh()
            end)
        end)
        Row.Track = nil
        Row.Index = Index
        QueueRows[Index] = Row
    end

    Items["LyricsScroll"] = New("ScrollingFrame", {
        Name="\0", Parent=Items["LyricsFrame"],
        Position=UDim2.new(0,8,0,24),
        Size=UDim2.new(1,-16,1,-32),
        BorderSizePixel=0, BackgroundTransparency=1,
        CanvasSize=UDim2.new(), ScrollBarThickness=1,
        ScrollBarImageColor3=Library.OutlineColor,
        Visible=false,
        ZIndex=2,
    }, { ScrollBarImageColor3='OutlineColor' })

    Items["LyricsText"] = New("TextLabel", {
        Name="\0", Font=Library.Font, TextSize=14,
        Parent=Items["LyricsScroll"], TextColor3=ThemeInactiveText,
        Text="Expand the player to load lyrics.",
        BackgroundTransparency=1,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Top,
        Size=UDim2.new(1,-8,0,0),
        BorderSizePixel=0, TextWrapped=true, RichText=true,
        ZIndex=2,
    })

    Items["PlayerArea"] = New("Frame", {
        Name="\0", Parent=Items["SpotifyPlayer"],
        BackgroundTransparency=1,
        Position=UDim2.new(0,10,0,10),
        Size=UDim2.new(1,-20,0,68),
        BorderSizePixel=0,
        ZIndex=2,
    })

    Items["CoverFrame"] = New("Frame", {
        Name="\0", Parent=Items["PlayerArea"],
        Position=UDim2.new(0,0,0,5),
        Size=UDim2.new(0,60,0,60),
        BorderSizePixel=0,
        BackgroundTransparency=1,
        ZIndex=3,
    })

    local CoverMask = New("Frame", {
        Name="\0", Parent=Items["CoverFrame"],
        Size=UDim2.new(1,0,1,0), BorderSizePixel=0,
        BackgroundTransparency=1, ClipsDescendants=true,
        ZIndex=3,
    })

    Items["Cover"] = New("ImageLabel", {
        Name="\0", Parent=CoverMask,
        AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.new(0.5,0,0.5,0),
        Image=PlaceholderImage, BackgroundTransparency=1,
        ScaleType=Enum.ScaleType.Crop,
        Size=UDim2.new(1,0,1,0), BorderSizePixel=0,
        Rotation=0,
        ZIndex=3,
    })
    New("UICorner", { Name="\0", Parent=Items["Cover"], CornerRadius=UDim.new(0.5,0) })

    Items["Info"] = New("Frame", {
        Name="\0", Parent=Items["PlayerArea"],
        BackgroundTransparency=1,
        Position=UDim2.new(0,68,0,2),
        Size=UDim2.new(1,-186,0,53),
        BorderSizePixel=0,
        ZIndex=3,
    })
    New("UIListLayout", { Name="\0", Parent=Items["Info"],
        SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,2) })

    Items["Title"] = New("TextLabel", {
        Name="\0", Font=Library.Font, TextSize=14, Parent=Items["Info"],
        TextColor3=Library.FontColor, Text="Spotify", BackgroundTransparency=1,
        TextXAlignment=Enum.TextXAlignment.Left,
        Size=UDim2.new(1,0,0,17), BorderSizePixel=0, TextTruncate=Enum.TextTruncate.AtEnd,
        ZIndex=3,
    }, { TextColor3='FontColor' })
    Items["Artist"] = New("TextLabel", {
        Name="\0", Font=Library.Font, TextSize=14, Parent=Items["Info"],
        TextColor3=ThemeInactiveText, Text="No track detected", BackgroundTransparency=1,
        TextXAlignment=Enum.TextXAlignment.Left,
        Size=UDim2.new(1,0,0,16), BorderSizePixel=0, TextTruncate=Enum.TextTruncate.AtEnd,
        ZIndex=3,
    })
    Items["Album"] = New("TextLabel", {
        Name="\0", Font=Library.Font, TextSize=14, Parent=Items["Info"],
        TextColor3=ThemeInactiveText, Text="Waiting for Spotify", BackgroundTransparency=1,
        TextXAlignment=Enum.TextXAlignment.Left,
        Size=UDim2.new(1,0,0,16), BorderSizePixel=0, TextTruncate=Enum.TextTruncate.AtEnd,
        ZIndex=3,
    })

    Items["ProgressFrame"] = New("Frame", {
        Name="\0", Parent=Items["SpotifyPlayer"],
        Position=UDim2.new(0,0,1,-3), Size=UDim2.new(1,0,0,3),
        BorderSizePixel=0, BackgroundColor3=Library.BackgroundColor,
        ZIndex=3,
    }, { BackgroundColor3='BackgroundColor' })

    Items["ProgressFill"] = New("Frame", {
        Name="\0", Parent=Items["ProgressFrame"],
        Size=UDim2.new(0,0,1,0), BorderSizePixel=0,
        BackgroundColor3=Library.AccentColor,
        ZIndex=3,
    }, { BackgroundColor3='AccentColor' })

    Items["ProgressHitbox"] = New("TextButton", {
        Name="\0", Parent=Items["SpotifyPlayer"],
        Position=UDim2.new(0,0,1,-14), Size=UDim2.new(1,0,0,14),
        BackgroundTransparency=1, BorderSizePixel=0, Text="",
        ZIndex=4,
    })

    Items["Time"] = New("TextLabel", {
        Name="\0", Font=Library.Font, TextSize=14, Parent=Items["PlayerArea"],
        TextColor3=ThemeInactiveText, Text="0:00 / 0:00", BackgroundTransparency=1,
        TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.new(0,68,0,58), Size=UDim2.new(0,90,0,12),
        BorderSizePixel=0,
        ZIndex=3,
    })

    Items["Controls"] = New("Frame", {
        Name="\0", Parent=Items["PlayerArea"], BackgroundTransparency=1,
        AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-6,0.5,0),
        Size=UDim2.new(0,132,0,24), BorderSizePixel=0,
        ZIndex=3,
    })
    New("UIListLayout", { Name="\0", Parent=Items["Controls"],
        FillDirection=Enum.FillDirection.Horizontal,
        HorizontalAlignment=Enum.HorizontalAlignment.Center,
        SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4) })

    CreateControlButton("Shuffle",   Items["Controls"], "rbxassetid://9607545176", 12, 12, 0)
    CreateControlButton("Previous",  Items["Controls"], SKIP_ASSET_ID,            16, 16, 0)
    CreateControlButton("PlayPause", Items["Controls"], "rbxassetid://9622475855", 20, 20, 0)
    CreateControlButton("Skip",      Items["Controls"], SKIP_ASSET_ID,            16, 16, 0)
    CreateControlButton("Repeat",    Items["Controls"], "rbxassetid://9607545605", 12, 12, 0)

    if Icons["Previous"] then
        Icons["Previous"].Rotation = 180
    end

    Items["ExpandButton"] = New("ImageButton", {
        Name="\0", Parent=Items["SpotifyPlayer"],
        AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-8,0,8),
        Size=UDim2.new(0,14,0,14), BorderSizePixel=0, AutoButtonColor=false,
        Image="rbxassetid://9607545497", Rotation=0,
        ImageColor3=Library.FontColor, BackgroundTransparency=1,
        ZIndex=4,
    }, { ImageColor3='FontColor' })

    local function CloseContextMenu()
        if ContextMenuFrame then
            ContextMenuFrame:Destroy()
            ContextMenuFrame = nil
        end
        ContextMenuTrack = nil
    end

    local function EnsureContextMenu()
        if ContextMenuFrame and ContextMenuFrame.Parent then return ContextMenuFrame end

        ContextMenuFrame = New("Frame", {
            Name="\0", Parent=Library.ScreenGui,
            BackgroundColor3=Library.MainColor,
            BackgroundTransparency=0,
            BorderSizePixel=0,
            Size=UDim2.new(0, 160, 0, 0),
            AutomaticSize=Enum.AutomaticSize.Y,
            Visible=false,
            ZIndex=200,
        }, { BackgroundColor3='MainColor' })
        New("UIStroke", { Name="\0", Parent=ContextMenuFrame,
            ApplyStrokeMode=Enum.ApplyStrokeMode.Border, LineJoinMode=Enum.LineJoinMode.Miter,
            Color=Library.Black, Thickness=1 }, { Color='Black' })
        New("UIStroke", { Name="\0", Parent=ContextMenuFrame,
            ApplyStrokeMode=Enum.ApplyStrokeMode.Border, LineJoinMode=Enum.LineJoinMode.Miter,
            Color=Library.OutlineColor, Thickness=1, BorderOffset=UDim.new(0,1) }, { Color='OutlineColor' })

        New("UIListLayout", { Name="\0", Parent=ContextMenuFrame,
            SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,0) })
        New("UIPadding", { Name="\0", Parent=ContextMenuFrame,
            PaddingTop=UDim.new(0,4), PaddingBottom=UDim.new(0,4) })

        return ContextMenuFrame
    end

    local function AddContextOption(text, callback, isDestructive)
        local menu = EnsureContextMenu()

        local btn = New("TextButton", {
            Name="\0", Parent=menu,
            Size=UDim2.new(1,0,0,26), BorderSizePixel=0,
            BackgroundTransparency=1, AutoButtonColor=false,
            Font=Library.Font, TextSize=14,
            TextColor3=isDestructive and Color3.fromRGB(230,90,90) or Library.FontColor,
            TextXAlignment=Enum.TextXAlignment.Left,
            Text=text,
        })
        New("UIPadding", { Name="\0", Parent=btn, PaddingLeft=UDim.new(0,10) })

        Connect(btn.MouseEnter, function()
            Tween(btn, { BackgroundTransparency = 0.7, BackgroundColor3 = Library.AccentColor }, TweenInfo.new(0.1))
        end)
        Connect(btn.MouseLeave, function()
            Tween(btn, { BackgroundTransparency = 1 }, TweenInfo.new(0.1))
        end)

        Connect(btn.MouseButton1Click, function()
            local track = ContextMenuTrack
            CloseContextMenu()
            if callback and track then callback(track) end
        end)
    end

    local function ShowContextMenu(track, mouseX, mouseY)
        CloseContextMenu()
        ContextMenuTrack = track

        EnsureContextMenu()
        ContextMenuFrame.Visible = true

        AddContextOption("Play now", function(t)
            if t.Uri and t.Uri ~= "" then
                PlayUri(t.Uri)
                RefreshSoon()
            end
        end)
        AddContextOption("Add to queue", function(t)
            if t.Uri and t.Uri ~= "" then
                AddToQueue(t.Uri)
                Library:Notify("Added to queue", 2)
                RefreshSoon()
            end
        end)

        local viewport = workspace.CurrentCamera.ViewportSize
        local menuSize = ContextMenuFrame.AbsoluteSize
        local x = math.clamp(mouseX, 8, viewport.X - menuSize.X - 8)
        local y = math.clamp(mouseY, 8, viewport.Y - menuSize.Y - 8)
        ContextMenuFrame.Position = UDim2.new(0, x, 0, y)
    end

    Connect(InputService.InputBegan, function(input)
        local ut = input.UserInputType
        if ut ~= Enum.UserInputType.MouseButton1
            and ut ~= Enum.UserInputType.MouseButton2
            and ut ~= Enum.UserInputType.Touch then return end
        if not ContextMenuFrame or not ContextMenuFrame.Visible then return end
        local mx, my = input.Position.X, input.Position.Y
        local pos  = ContextMenuFrame.AbsolutePosition
        local size = ContextMenuFrame.AbsoluteSize
        if mx < pos.X or mx > pos.X + size.X
            or my < pos.Y or my > pos.Y + size.Y then
            CloseContextMenu()
        end
    end)

    local function FormatTime(ms)
        local total = math.max(math.floor((ms or 0) / 1000), 0)
        return string.format("%d:%02d", math.floor(total/60), total % 60)
    end

    local function SetProgress(current, total, instant)
        local safeTotal = math.max(total or 0, 1)
        local alpha = math.clamp((current or 0) / safeTotal, 0, 1)
        if instant then
            Items["ProgressFill"].Size = UDim2.new(alpha, 0, 1, 0)
        else
            Tween(Items["ProgressFill"], { Size = UDim2.new(alpha, 0, 1, 0) })
        end
        Items["Time"].Text = FormatTime(current) .. " / " .. FormatTime(total)
    end

    local function SetControlState(data)
        local shuffleOn = data and data.Shuffle
        local repeatOn  = data and data.RepeatState and data.RepeatState ~= "off"
        Icons["Shuffle"].ImageColor3   = shuffleOn and Library.AccentColor or Library.FontColor
        Icons["Repeat"].ImageColor3    = repeatOn  and Library.AccentColor or Library.FontColor

        local playing
        if data == nil then
            playing = false
        elseif data.IsPlaying ~= LastKnownPlaying then
            playing = LastKnownPlaying
        else
            playing = data.IsPlaying == true
        end

        Icons["PlayPause"].Image = playing
            and "rbxassetid://9607545382"
            or  "rbxassetid://9622475855"
    end

    local function SetQueueDisplay(current, tracks, emptyText)
        local count = 0
        if type(tracks) == "table" then
            for _, t in ipairs(tracks) do
                if count >= #QueueRows then break end
                count = count + 1
                local row = QueueRows[count]
                row.Frame.Visible = true
                row.Cover.Image   = t.Cover or PlaceholderImage
                row.Title.Text    = t.Title or "Unknown track"
                row.Artist.Text   = t.Artist or "Unknown artist"
                row.Track         = t
            end
        end
        for i = count + 1, #QueueRows do
            QueueRows[i].Frame.Visible = false
            QueueRows[i].Track = nil
        end
        if count == 0 then
            Items["QueueEmpty"].Visible = true
            Items["QueueEmpty"].Text = emptyText or "No upcoming tracks."
        else
            Items["QueueEmpty"].Visible = false
        end
    end

    local function ParseLRC(lrcText)
        if not lrcText or lrcText == "" then return {} end
        local lines = {}
        for raw in lrcText:gmatch("[^\r\n]+") do
            local minutes, seconds, hundredths, text = raw:match("^%[(%d+):(%d+)%.(%d+)%]%s*(.*)$")
            if not minutes then
                minutes, seconds, text = raw:match("^%[(%d+):(%d+)%]%s*(.*)$")
                hundredths = "0"
            end
            if minutes and seconds and text and text ~= "" then
                local timeMs = (tonumber(minutes) * 60 + tonumber(seconds)) * 1000
                    + tonumber(hundredths or 0) * 10
                table.insert(lines, { Time = timeMs, Text = text })
            end
        end
        table.sort(lines, function(a, b) return a.Time < b.Time end)
        return lines
    end

    local function GetLyrics(trackName, artistName, albumName, durationMs)
        if not Request or not trackName or not artistName then return nil end
        if trackName == "Unknown track" or artistName == "Unknown artist" then return nil end

        local primaryArtist = artistName:match("^([^,]+)") or artistName
        primaryArtist = primaryArtist:gsub("^%s*(.-)%s*$", "%1")

        local durationSec = durationMs and math.floor(durationMs / 1000) or nil

        local function buildUrl(includeAlbum, includeDuration)
            local url = "https://lrclib.net/api/get?"
                .. "track_name=" .. HttpService:UrlEncode(trackName)
                .. "&artist_name=" .. HttpService:UrlEncode(primaryArtist)
            if includeAlbum and albumName and albumName ~= "" and albumName ~= "Unknown album" then
                url = url .. "&album_name=" .. HttpService:UrlEncode(albumName)
            end
            if includeDuration and durationSec then
                url = url .. "&duration=" .. tostring(durationSec)
            end
            return url
        end

        local function tryGet(url)
            local ok, resp = pcall(Request, {
                Url = url,
                Method = "GET",
                Headers = {
                    ["User-Agent"] = "rawr baby (https://github.com/imcomingforyou6959-gif/UR4)",
                    ["Accept"] = "application/json",
                },
            })
            if not ok or not resp or resp.StatusCode ~= 200 or not resp.Body or resp.Body == "" then
                return nil
            end
            local dok, decoded = pcall(HttpService.JSONDecode, HttpService, resp.Body)
            if not dok or type(decoded) ~= "table" then return nil end
            return decoded
        end

        local decoded = tryGet(buildUrl(true, true))
            or tryGet(buildUrl(true, false))
            or tryGet(buildUrl(false, true))
            or tryGet(buildUrl(false, false))

        if not decoded then return nil end

        if decoded.instrumental then
            return { Instrumental = true, Plain = "", Synced = "", HasSynced = false }
        end

        local synced = decoded.syncedLyrics or ""
        local plain  = decoded.plainLyrics  or ""
        if synced == "" and plain == "" then return nil end

        return {
            Plain = plain,
            Synced = synced,
            HasSynced = synced ~= "",
            Instrumental = false,
        }
    end

    local function ResizeLyricsCanvas()
        local availX = Items["LyricsScroll"].AbsoluteSize.X
        if availX <= 0 then return end
        local w = math.max(availX - 8, 1)
        local h = math.max(Items["LyricsText"].TextBounds.Y + 8, 1)
        Items["LyricsText"].Size = UDim2.new(0, w, 0, h)
        Items["LyricsScroll"].CanvasSize = UDim2.new(0, 0, 0, h)
    end

    local function RenderLyrics(activeIndex)
        if not CurrentLyrics or #CurrentLyrics == 0 then return end

        local accent = Library.AccentColor
        local accentHex = string.format("#%02X%02X%02X",
            math.floor(accent.R * 255),
            math.floor(accent.G * 255),
            math.floor(accent.B * 255))

        local buf = {}
        for i, line in ipairs(CurrentLyrics) do
            if i == activeIndex then
                buf[#buf+1] = string.format(
                    "<font color=\"%s\"><b>%s</b></font>",
                    accentHex, line.Text
                )
            else
                buf[#buf+1] = line.Text
            end
        end
        Items["LyricsText"].Text = table.concat(buf, "\n")
        ResizeLyricsCanvas()
    end

    local function ScrollToActiveLine(activeIndex, myGen)
        task.spawn(function()
            task.wait()
            task.wait()

            if Destroyed then return end
            if myGen and myGen ~= LyricsRenderGen then return end
            if not CurrentLyricsSynced or #CurrentLyrics == 0 then return end
            if SidebarTab ~= "lyrics" then return end

            local scroll    = Items["LyricsScroll"]
            local label     = Items["LyricsText"]
            if not scroll or not scroll.Parent or not label or not label.Parent then return end

            local viewportH = scroll.AbsoluteSize.Y
            if viewportH <= 0 then return end

            local totalH     = label.TextBounds.Y
            local totalLines = #CurrentLyrics
            if totalH <= 0 or totalLines <= 0 then return end

            local lineHeight = totalH / totalLines
            local lineCenter = (activeIndex - 0.5) * lineHeight

            local targetY   = lineCenter - viewportH * 0.35
            local maxScroll = math.max(totalH - viewportH, 0)
            targetY = math.clamp(targetY, 0, maxScroll)

            if math.abs(targetY - scroll.CanvasPosition.Y) < 2 then return end

            Tween(scroll, {
                CanvasPosition = Vector2.new(0, targetY),
            }, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
        end)
    end

    local function UpdateLyricsHighlight(currentMs)
        if not CurrentLyricsSynced or #CurrentLyrics == 0 then return end

        local activeIndex = 1
        for i, line in ipairs(CurrentLyrics) do
            if line.Time <= currentMs then
                activeIndex = i
            else
                break
            end
        end

        if activeIndex ~= CurrentHighlightIndex then
            CurrentHighlightIndex = activeIndex
            LyricsRenderGen = LyricsRenderGen + 1
            local myGen = LyricsRenderGen
            RenderLyrics(activeIndex)
            ScrollToActiveLine(activeIndex, myGen)
        end
    end

    local function SetLyricsEmpty(text)
        CurrentLyrics = {}
        CurrentLyricsSynced = false
        CurrentHighlightIndex = 0
        Items["LyricsText"].Text = text
        Items["LyricsText"].TextColor3 = ThemeInactiveText
        local availX = Items["LyricsScroll"].AbsoluteSize.X
        if availX > 0 then
            local w = math.max(availX - 8, 1)
            local h = math.max(Items["LyricsText"].TextBounds.Y + 8, 1)
            Items["LyricsText"].Size = UDim2.new(0, w, 0, h)
            Items["LyricsScroll"].CanvasSize = UDim2.new(0, 0, 0, h)
        else
            Items["LyricsScroll"].CanvasSize = UDim2.new(0, 0, 0, 24)
        end
        Items["LyricsScroll"].CanvasPosition = Vector2.new()
    end

    local function SetLyricsPlain(plain)
        CurrentLyrics = {}
        CurrentLyricsSynced = false
        CurrentHighlightIndex = 0
        Items["LyricsText"].Text = plain
        Items["LyricsText"].TextColor3 = ThemeInactiveText
        ResizeLyricsCanvas()
        Items["LyricsScroll"].CanvasPosition = Vector2.new()
    end

    local function LoadLyricsForTrack(track)
        if not track or not track.TrackId then return end

        local cached = LyricsCache[track.TrackId]
        if cached then
            LyricsRequestId = LyricsRequestId + 1
            CurrentLyricsLoading = false
            if cached.Instrumental then
                SetLyricsEmpty("Instrumental track — no lyrics.")
                return
            end
            if cached.HasSynced then
                CurrentLyrics = cached.Parsed or {}
                CurrentLyricsSynced = true
                CurrentHighlightIndex = 0
                RenderLyrics(1)
                local gen = LyricsRenderGen + 1
                LyricsRenderGen = gen
                if track.Progress then
                    local ms = track.Progress
                    local idx = 1
                    for i, line in ipairs(CurrentLyrics) do
                        if line.Time <= ms then idx = i else break end
                    end
                    CurrentHighlightIndex = idx
                    RenderLyrics(idx)
                    ScrollToActiveLine(idx, gen)
                end
            else
                SetLyricsPlain(cached.Plain ~= "" and cached.Plain or "No lyrics available.")
            end
            return
        end

        LyricsRequestId = LyricsRequestId + 1
        local myId = LyricsRequestId
        CurrentLyricsLoading = true
        SetLyricsEmpty("Loading lyrics…")

        task.spawn(function()
            local result = GetLyrics(track.Title, track.Artist, track.Album, track.Duration)
            if myId ~= LyricsRequestId then return end
            CurrentLyricsLoading = false

            if Destroyed then return end
            if not CurrentTrack or CurrentTrack.TrackId ~= track.TrackId then return end

            if not result then
                LyricsCache[track.TrackId] = { Plain = "", Synced = "", Parsed = {}, HasSynced = false, Instrumental = false }
                SetLyricsEmpty("No lyrics found for this track.")
                return
            end

            if result.Instrumental then
                LyricsCache[track.TrackId] = { Instrumental = true, Parsed = {}, HasSynced = false, Plain = "", Synced = "" }
                SetLyricsEmpty("Instrumental track — no lyrics.")
                return
            end

            local parsed = result.HasSynced and ParseLRC(result.Synced) or {}
            LyricsCache[track.TrackId] = {
                Plain = result.Plain,
                Synced = result.Synced,
                Parsed = parsed,
                HasSynced = result.HasSynced,
                Instrumental = false,
            }

            if result.HasSynced then
                CurrentLyrics = parsed
                CurrentLyricsSynced = true
                CurrentHighlightIndex = 0
                Items["LyricsText"].TextColor3 = Library.FontColor
                RenderLyrics(1)
                local gen = LyricsRenderGen + 1
                LyricsRenderGen = gen
                if CurrentTrack and CurrentTrack.Progress then
                    local ms = CurrentTrack.Progress
                    local idx = 1
                    for i, line in ipairs(CurrentLyrics) do
                        if line.Time <= ms then idx = i else break end
                    end
                    CurrentHighlightIndex = idx
                    RenderLyrics(idx)
                    ScrollToActiveLine(idx, gen)
                end
            else
                SetLyricsPlain(result.Plain ~= "" and result.Plain or "No lyrics available.")
            end
        end)
    end

    local function SetSidebarTab(name)
        SidebarTab = name
        local isQueue = name == "queue"
        Items["QueueTab"].TextColor3  = isQueue and Library.AccentColor or ThemeInactiveText
        Items["LyricsTab"].TextColor3 = (not isQueue) and Library.AccentColor or ThemeInactiveText
        Items["QueueScroll"].Visible  = isQueue
        Items["LyricsScroll"].Visible = not isQueue

        if not isQueue then
            if CurrentTrack and not CurrentLyricsLoading then
                if CurrentLyricsTrackId ~= CurrentTrack.TrackId or #CurrentLyrics == 0 then
                    LoadLyricsForTrack(CurrentTrack)
                elseif CurrentLyricsSynced then
                    local gen = LyricsRenderGen + 1
                    LyricsRenderGen = gen
                    if CurrentTrack.Progress then
                        local ms = CurrentTrack.Progress
                        local idx = 1
                        for i, line in ipairs(CurrentLyrics) do
                            if line.Time <= ms then idx = i else break end
                        end
                        CurrentHighlightIndex = idx
                        RenderLyrics(idx)
                        ScrollToActiveLine(idx, gen)
                    end
                end
            end
        end
    end

    local function SetDisplay(data, emptyText)
        if not data then
            CurrentTrack = nil
            LastKnownPlaying = false
            CurrentLyrics = {}
            CurrentLyricsSynced = false
            CurrentLyricsTrackId = nil
            CurrentHighlightIndex = 0
            Items["Title"].Text   = "Spotify"
            Items["Artist"].Text  = "No track detected"
            Items["Album"].Text   = emptyText or "Nothing is currently playing"
            Items["Cover"].Image  = PlaceholderImage
            Items["Cover"].Rotation = 0
            SetLyricsEmpty("Nothing is currently playing.")
            SetControlState(nil)
            SetQueueDisplay(nil, nil, "Nothing is currently playing.")
            SetProgress(0, 0, true)
            return
        end

        local trackChanged = (data.TrackId ~= CurrentLyricsTrackId)
        CurrentTrack = data
        LastKnownPlaying = data.IsPlaying == true
        Items["Title"].Text  = data.Title
        Items["Artist"].Text = data.Artist
        Items["Album"].Text  = data.Album

        local newCover = data.Cover or PlaceholderImage
        if Items["Cover"].Image ~= newCover then
            Items["Cover"].Image = newCover
            Items["Cover"].Rotation = 0
        end

        SetControlState(data)
        if not Seeking then
            SetProgress(data.Progress, data.Duration, true)
        end

        if trackChanged then
            CurrentLyricsTrackId = data.TrackId
            CurrentLyrics = {}
            CurrentLyricsSynced = false
            CurrentHighlightIndex = 0
            if SidebarTab == "lyrics" then
                LoadLyricsForTrack(data)
            end
        end
    end

    local function RefreshAccessToken()
        if not Request or TokenConfig.RefreshToken == "" then return false end
        if TokenConfig.ClientId == "" or TokenConfig.ClientSecret == "" then return false end
        local body = table.concat({
            "grant_type=refresh_token",
            "refresh_token=" .. HttpService:UrlEncode(TokenConfig.RefreshToken),
            "client_id=" .. HttpService:UrlEncode(TokenConfig.ClientId),
            "client_secret=" .. HttpService:UrlEncode(TokenConfig.ClientSecret),
        }, "&")
        local ok, resp = pcall(Request, {
            Url = "https://accounts.spotify.com/api/token",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
            Body = body,
        })
        if not ok or not resp or resp.StatusCode ~= 200 or not resp.Body or resp.Body == "" then return false end
        local dok, payload = pcall(HttpService.JSONDecode, HttpService, resp.Body)
        if not dok or type(payload) ~= "table" or not payload.access_token then return false end
        TokenConfig.AccessToken = tostring(payload.access_token)
        TokenConfig.ExpiresAt   = tick() + math.max((tonumber(payload.expires_in) or 3600) - 30, 0)
        if payload.refresh_token and payload.refresh_token ~= "" then
            TokenConfig.RefreshToken = tostring(payload.refresh_token)
        end
        Token = TokenConfig.AccessToken
        WriteToken(TokenConfig)
        return true
    end

    local function EnsureAccessToken()
        if TokenConfig.RefreshToken == "" then
            Token = TokenConfig.AccessToken
            return Token ~= ""
        end
        if TokenConfig.AccessToken ~= "" and tick() < (TokenConfig.ExpiresAt or 0) then
            Token = TokenConfig.AccessToken
            return true
        end
        return RefreshAccessToken()
    end

    local function MakeRequest(url, method, retryOnAuth, body)
        if Destroyed then return nil end
        if not Request or not EnsureAccessToken() or Token == "" then return nil end
        local reqBody = body
        if type(body) == "table" then
            local eok, enc = pcall(HttpService.JSONEncode, HttpService, body)
            if not eok then return nil end
            reqBody = enc
        end
        local ok, resp = pcall(Request, {
            Url = "https://api.spotify.com/v1/" .. url,
            Method = method or "GET",
            Headers = {
                ["Authorization"] = "Bearer " .. Token,
                ["Content-Type"]  = "application/json",
            },
            Body = reqBody,
        })
        if not ok or not resp then return nil end
        if resp.StatusCode == 401 and retryOnAuth ~= false and TokenConfig.RefreshToken ~= "" and RefreshAccessToken() then
            return MakeRequest(url, method, false, body)
        end
        if resp.StatusCode < 200 or resp.StatusCode >= 300 then return nil end
        if not resp.Body or resp.Body == "" then return true end
        local dok, decoded = pcall(HttpService.JSONDecode, HttpService, resp.Body)
        return dok and decoded or nil
    end

    local function CacheImage(id, url)
        if Destroyed then return PlaceholderImage end
        if not GetCustomAsset or not id or not url or url == "" then return PlaceholderImage end
        local safe = tostring(id):gsub("[^%w_%-]", "_")
        local path = CacheFolder .. "/" .. safe .. ".png"
        if not isfile(path) then
            pcall(function() writefile(path, game:HttpGet(url)) end)
        end
        if isfile(path) then
            local aok, asset = pcall(GetCustomAsset, path)
            if aok then return asset end
        end
        return PlaceholderImage
    end

    local function GetCurrentTrack()
        local d = MakeRequest("me/player")
        if not d or not d.item then return nil end
        local artists = {}
        for _, a in d.item.artists or {} do table.insert(artists, a.name) end
        local coverUrl = d.item.album and d.item.album.images and d.item.album.images[2] and d.item.album.images[2].url
        return {
            Title = d.item.name or "Unknown track",
            Artist = #artists > 0 and table.concat(artists, ", ") or "Unknown artist",
            Album = d.item.album and d.item.album.name or "Unknown album",
            TrackId = d.item.id or "",
            Progress = d.progress_ms or 0,
            Duration = d.item.duration_ms or 0,
            Cover = CacheImage(d.item.album and d.item.album.id or d.item.id, coverUrl),
            Device = d.device and d.device.name or "none",
            IsPlaying = d.is_playing == true,
            Shuffle = d.shuffle_state == true,
            RepeatState = tostring(d.repeat_state or "off"),
            Uri = d.item.uri or "",
            UpdatedAt = tick(),
        }
    end

    local function GetQueue()
        local d = MakeRequest("me/player/queue")
        local out = {}
        if not d or type(d.queue) ~= "table" then return out end
        for _, t in d.queue do
            local artists = {}
            for _, a in t.artists or {} do table.insert(artists, a.name) end
            local coverUrl = t.album and t.album.images and t.album.images[3] and t.album.images[3].url
                or t.album and t.album.images and t.album.images[2] and t.album.images[2].url
            table.insert(out, {
                Title = t.name or "Unknown track",
                Artist = #artists > 0 and table.concat(artists, ", ") or "Unknown artist",
                Album = t.album and t.album.name or "Unknown album",
                AlbumId = t.album and t.album.id or "",
                Uri = t.uri or "",
                Cover = CacheImage(t.album and t.album.id or t.id, coverUrl),
            })
        end
        return out
    end

    local function SearchTracks(q)
        local d = MakeRequest("search?type=track&limit=8&q=" .. HttpService:UrlEncode(q))
        local out = {}
        if not d or not d.tracks or not d.tracks.items then return out end
        for _, t in d.tracks.items do
            local artists = {}
            local coverUrl = t.album and t.album.images and t.album.images[3] and t.album.images[3].url
                or t.album and t.album.images and t.album.images[2] and t.album.images[2].url
            for _, a in t.artists or {} do table.insert(artists, a.name) end
            table.insert(out, {
                Title = t.name or "Unknown track",
                Artist = #artists > 0 and table.concat(artists, ", ") or "Unknown artist",
                Album = t.album and t.album.name or "Unknown album",
                AlbumId = t.album and t.album.id or "",
                Uri = t.uri or "",
                Cover = CacheImage(t.album and t.album.id or t.id, coverUrl),
            })
        end
        return out
    end

    local function GetAlbumTracks(albumId)
        local out = {}
        if not albumId or albumId == "" then return out end
        local d = MakeRequest("albums/" .. albumId)
        if not d or type(d) ~= "table" or type(d.tracks) ~= "table" or type(d.tracks.items) ~= "table" then
            return out
        end
        local coverUrl = d.images and d.images[3] and d.images[3].url
            or d.images and d.images[2] and d.images[2].url
            or d.images and d.images[1] and d.images[1].url
        for _, t in d.tracks.items do
            local artists = {}
            for _, a in t.artists or {} do table.insert(artists, a.name) end
            table.insert(out, {
                Title = t.name or "Unknown track",
                Artist = #artists > 0 and table.concat(artists, ", ") or "Unknown artist",
                Album = d.name or "Unknown album",
                AlbumId = albumId,
                Uri = t.uri or "",
                Cover = CacheImage(albumId, coverUrl),
                IsAlbumTrack = true,
            })
            if #out >= 7 then break end
        end
        return out
    end

    local function Previous() return MakeRequest("me/player/previous", "POST", true, {}) end
    local function Next()     return MakeRequest("me/player/next",     "POST", true, {}) end

    local function Resume()
        local pos = 0
        if CurrentTrack and CurrentTrack.Progress and CurrentTrack.Duration and CurrentTrack.Duration > 0 then
            pos = math.max(math.floor(CurrentTrack.Progress), 0)
        end
        return MakeRequest("me/player/play", "PUT", true, { position_ms = pos })
    end

    local function Pause()    return MakeRequest("me/player/pause",    "PUT",  true, {}) end
    local function Shuffle(e) return MakeRequest("me/player/shuffle?state=" .. tostring(e), "PUT", true, {}) end
    local function Repeat(e)  return MakeRequest("me/player/repeat?state=" .. (e and "context" or "off"), "PUT", true, {}) end
    local function Seek(ms)   return MakeRequest("me/player/seek?position_ms=" .. math.max(math.floor(ms or 0), 0), "PUT", true, {}) end

    function PlayUri(uri)
        if not uri or uri == "" then return nil end
        return MakeRequest("me/player/play", "PUT", true, { uris = { uri } })
    end

    function AddToQueue(uri)
        if not uri or uri == "" then return nil end
        return MakeRequest(
            "me/player/queue?uri=" .. HttpService:UrlEncode(uri),
            "POST", true, {}
        )
    end

    local function UpdateResults()
        for i, btn in ResultButtons do
            local r = SearchResults[i]
            if r then
                btn.Frame.Visible     = true
                btn.Cover.Image       = r.Cover or PlaceholderImage
                btn.Title.Text        = r.Title
                if r.IsBack then
                    btn.Album.Text = r.Album or "Return to search results"
                elseif r.IsAlbumTrack then
                    btn.Album.Text = r.Artist
                else
                    btn.Album.Text = r.Album
                end
            else
                btn.Frame.Visible = false
                btn.Cover.Image   = PlaceholderImage
                btn.Title.Text    = ""
                btn.Album.Text    = ""
            end
        end
    end

    local LastEmptyTokenNotification = 0
    local function NotifyEmptyToken()
        if Token ~= "" or TokenConfig.RefreshToken ~= "" then return end
        local now = tick()
        if now - LastEmptyTokenNotification < 1 then return end
        LastEmptyTokenNotification = now
        Library:Notify("Empty Spotify Token :(", 3)
    end

    local function ApplyVisibility()
        Items["SpotifyPlayer"].Visible = IsVisible
        if IsVisible then NotifyEmptyToken() end
    end

    local function AlignAboveKeybindList()
        local frame = Library.KeybindFrame
        if not frame then return end
        local kp = frame.AbsolutePosition
        local sh = Items["SpotifyPlayer"].AbsoluteSize.Y
        Items["SpotifyPlayer"].AnchorPoint = Vector2.new(0, 0)
        Items["SpotifyPlayer"].Position = UDim2.new(0, kp.X, 0, kp.Y - sh - 5)
    end

    local function SetExpanded(bool, instant)
        IsExpanded = bool
        local player = Items["SpotifyPlayer"]
        local info = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

        local playerAreaPos = bool and UDim2.new(0, 10, 1, -78) or UDim2.new(0, 10, 0, 10)
        local searchPos     = bool and UDim2.new(0, 10, 0, 10)  or UDim2.new(0, 10, 0, -40)
        local resultsPos    = bool and UDim2.new(0, 10, 0, 42)  or UDim2.new(0, 10, 0, -170)
        local lyricsPos     = bool and UDim2.new(0, 270, 0, 10) or UDim2.new(1, 10, 0, 10)
        local expandRot     = bool and 90 or 0

        if instant then
            player.Size = bool and ExpandedSize or CollapsedSize
            Items["PlayerArea"].Position = playerAreaPos
            Items["SearchBackground"].Position = searchPos
            Items["SearchResults"].Position = resultsPos
            Items["LyricsFrame"].Position = lyricsPos
            Items["ExpandButton"].Rotation = expandRot
        else
            Tween(player, { Size = bool and ExpandedSize or CollapsedSize }, info)
            Tween(Items["PlayerArea"],      { Position = playerAreaPos }, info)
            Tween(Items["SearchBackground"],{ Position = searchPos },    info)
            Tween(Items["SearchResults"],   { Position = resultsPos },   info)
            Tween(Items["LyricsFrame"],     { Position = lyricsPos },    info)
            Tween(Items["ExpandButton"],    { Rotation = expandRot },    info)
        end
        Spotify:Center()

        if bool and SidebarTab == "lyrics" and CurrentTrack then
            if CurrentLyricsTrackId == CurrentTrack.TrackId and #CurrentLyrics == 0 and not CurrentLyricsLoading then
                LoadLyricsForTrack(CurrentTrack)
            end
        end
    end

    local function RunSearch(query)
        local trimmed = (query or ""):gsub("^%s*(.-)%s*$", "%1")
        SearchAlbumBrowse = nil
        if trimmed == "" then
            SearchTrackResults = {}
            SearchResults = {}
            UpdateResults()
            return
        end
        SearchTrackResults = SearchTracks(trimmed)
        SearchResults = SearchTrackResults
        UpdateResults()
    end

    local function QueueSearch(query)
        SearchRequestId = SearchRequestId + 1
        local id = SearchRequestId
        task.delay(SearchDelay, function()
            if Destroyed then return end
            if id ~= SearchRequestId then return end
            RunSearch(query)
        end)
    end

    function RefreshSoon()
        task.delay(0.35, function()
            if Destroyed then return end
            if SkippingTo then return end
            if Library and Items["SpotifyPlayer"] and Items["SpotifyPlayer"].Parent then
                Spotify:Refresh()
            end
        end)
    end

    local function SetSeekingFromInput(input)
        if not CurrentTrack or not CurrentTrack.Duration or CurrentTrack.Duration <= 0 then return end
        local bar = Items["ProgressFrame"]
        local x = input.Position and input.Position.X or UserInputService:GetMouseLocation().X
        local alpha = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local pos = math.floor(CurrentTrack.Duration * alpha)
        CurrentTrack.Progress = pos
        CurrentTrack.UpdatedAt = tick()
        SetProgress(pos, CurrentTrack.Duration, true)
    end

    local function Cleanup()
        if Destroyed then return end
        Destroyed = true
        SkippingTo = false

        for _, conn in ipairs(Connections) do
            pcall(function() conn:Disconnect() end)
        end
        Connections = {}

        if ContextMenuFrame then
            pcall(function() ContextMenuFrame:Destroy() end)
            ContextMenuFrame = nil
        end

        if Items["SpotifyPlayer"] then
            pcall(function() Items["SpotifyPlayer"]:Destroy() end)
        end

        CurrentTrack = nil
        CurrentLyrics = {}
        CurrentLyricsSynced = false
        SearchResults = {}
        SearchTrackResults = {}
        QueueRows = {}
        ResultButtons = {}
        Items = {}
        Icons = {}
    end

    function Spotify:SetVisibility(b) IsVisible = b ApplyVisibility() end
    function Spotify:Center()
        task.wait()
        if Destroyed then return end
        if CustomPosition then
            Items["SpotifyPlayer"].AnchorPoint = Vector2.new(0, 0)
            Items["SpotifyPlayer"].Position = CustomPosition
            return
        end
        AlignAboveKeybindList()
    end
    function Spotify:SetPosition(pos)
        CustomPosition = pos
        Items["SpotifyPlayer"].AnchorPoint = Vector2.new(0, 0)
        Items["SpotifyPlayer"].Position = pos
    end
    function Spotify:GetBounds()
        return Items["SpotifyPlayer"].AbsolutePosition, Items["SpotifyPlayer"].AbsoluteSize
    end
    function Spotify:SetToken(newToken)
        TokenConfig = DecodeTokenConfig(newToken)
        Token = TokenConfig.AccessToken
        WriteToken(TokenConfig)
        Spotify:Refresh()
    end
    function Spotify:Destroy()
        Cleanup()
    end

    function Spotify:Refresh()
        if Destroyed then return false end
        if not Request then SetDisplay(nil, "Executor request API unavailable") return false end
        if Token == "" and TokenConfig.RefreshToken == "" then
            SetDisplay(nil, "Add a token or refresh config to " .. TokenPath)
            return false
        end
        if TokenConfig.RefreshToken ~= "" and (TokenConfig.ClientId == "" or TokenConfig.ClientSecret == "") then
            SetDisplay(nil, "token.txt needs client_id and client_secret")
            return false
        end
        if not EnsureAccessToken() then SetDisplay(nil, "Could not refresh Spotify token") return false end

        local track = GetCurrentTrack()
        if not track then
            local me = MakeRequest("me")
            if me == nil then
                SetDisplay(nil, "Invalid token in " .. TokenPath)
                return false
            end
        end
        SetDisplay(track, "Nothing is currently playing")
        SetQueueDisplay(track, GetQueue(), "No upcoming tracks.")
        return track ~= nil
    end

    for i, btn in ResultButtons do
        Connect(btn.Button.MouseButton1Click, function()
            local r = SearchResults[i]
            if not r then return end
            if r.IsBack then
                SearchAlbumBrowse = nil
                SearchResults = SearchTrackResults
                UpdateResults()
                return
            end
            if r.IsAlbumTrack then
                PlayUri(r.Uri)
                RefreshSoon()
                return
            end
            SearchAlbumBrowse = r.AlbumId
            SearchResults = GetAlbumTracks(r.AlbumId)
            if #SearchResults > 0 then
                table.insert(SearchResults, 1, {
                    Title = "< Back",
                    Album = r.Album or "Back to results",
                    Cover = r.Cover,
                    IsBack = true,
                })
            end
            UpdateResults()
        end)

        Connect(btn.Button.MouseButton2Click, function()
            local r = SearchResults[i]
            if not r then return end
            if r.IsBack then return end
            local mouse = UserInputService:GetMouseLocation()
            ShowContextMenu(r, mouse.X, mouse.Y)
        end)
    end

    Connect(Items["SearchInput"].FocusLost, function(enter)
        if enter then
            SearchRequestId = SearchRequestId + 1
            RunSearch(Items["SearchInput"].Text)
        end
    end)
    Connect(Items["SearchInput"]:GetPropertyChangedSignal("Text"), function()
        QueueSearch(Items["SearchInput"].Text)
    end)

    Connect(Items["QueueTab"].MouseButton1Click, function()
        SetSidebarTab("queue")
    end)

    Connect(Items["LyricsTab"].MouseButton1Click, function()
        SetSidebarTab("lyrics")
    end)

    Connect(Items["ExpandButton"].MouseButton1Click, function()
        SetExpanded(not IsExpanded)
    end)

    Connect(Items["PlayPause"].MouseButton1Click, function()
        if LastKnownPlaying then
            LastKnownPlaying = false
            if CurrentTrack then CurrentTrack.IsPlaying = false end
            Pause()
        else
            LastKnownPlaying = true
            if CurrentTrack then CurrentTrack.IsPlaying = true end
            Resume()
        end
        if Icons["PlayPause"] then
            Icons["PlayPause"].Image = LastKnownPlaying
                and "rbxassetid://9607545382"
                or  "rbxassetid://9622475855"
        end
        RefreshSoon()
    end)

    Connect(Items["Shuffle"].MouseButton1Click, function()
        Shuffle(not (CurrentTrack and CurrentTrack.Shuffle))
        RefreshSoon()
    end)

    Connect(Items["Previous"].MouseButton1Click, function()
        Previous()
        if Icons["Previous"] then
            Tween(Icons["Previous"], { ImageColor3 = Library.AccentColor }, TweenInfo.new(0.1))
            task.delay(0.25, function()
                if Destroyed then return end
                if Icons["Previous"] then
                    Tween(Icons["Previous"], { ImageColor3 = Library.FontColor }, TweenInfo.new(0.2))
                end
            end)
        end
        RefreshSoon()
    end)

    Connect(Items["Skip"].MouseButton1Click, function()
        Next()
        if Icons["Skip"] then
            Tween(Icons["Skip"], { ImageColor3 = Library.AccentColor }, TweenInfo.new(0.1))
            task.delay(0.25, function()
                if Destroyed then return end
                if Icons["Skip"] then
                    Tween(Icons["Skip"], { ImageColor3 = Library.FontColor }, TweenInfo.new(0.2))
                end
            end)
        end
        RefreshSoon()
    end)

    Connect(Items["Repeat"].MouseButton1Click, function()
        local on = CurrentTrack and CurrentTrack.RepeatState and CurrentTrack.RepeatState ~= "off"
        Repeat(not on)
        RefreshSoon()
    end)

    Connect(Items["ProgressHitbox"].InputBegan, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        Seeking = true
        SetSeekingFromInput(input)
    end)

    Connect(InputService.InputChanged, function(input)
        if not Seeking then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            SetSeekingFromInput(input)
        end
    end)

    Connect(InputService.InputEnded, function(input)
        if not Seeking then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        Seeking = false
        if CurrentTrack then
            Seek(CurrentTrack.Progress)
            RefreshSoon()
        end
    end)

    Connect(Items["SpotifyPlayer"].InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            CustomPosition = Items["SpotifyPlayer"].Position
        end
    end)

    Connect(Items["QueueScroll"]:GetPropertyChangedSignal("AbsoluteSize"), function()
        if Destroyed then return end
        if Items["LyricsScroll"].Visible then
            ResizeLyricsCanvas()
        end
    end)

    task.spawn(function()
        while not Destroyed and Library and Items["SpotifyPlayer"] and Items["SpotifyPlayer"].Parent do
            if not SkippingTo then
                Spotify:Refresh()
            end
            task.wait(PollInterval)
        end
    end)

    task.spawn(function()
        while not Destroyed and Library and Items["SpotifyPlayer"] and Items["SpotifyPlayer"].Parent do
            if Seeking and CurrentTrack then
                SetSeekingFromInput({ Position = UserInputService:GetMouseLocation() })
            end
            if CurrentTrack and CurrentTrack.IsPlaying and not Seeking then
                local p = math.min(CurrentTrack.Progress + ((tick() - CurrentTrack.UpdatedAt) * 1000),
                                   CurrentTrack.Duration)
                SetProgress(p, CurrentTrack.Duration, true)
                if SidebarTab == "lyrics" and CurrentLyricsSynced and #CurrentLyrics > 0 then
                    UpdateLyricsHighlight(p)
                end
            end
            task.wait(0.1)
        end
    end)

    task.spawn(function()
        while not Destroyed and Library and Items["SpotifyPlayer"] and Items["SpotifyPlayer"].Parent do
            if CurrentTrack and LastKnownPlaying then
                CoverSpin = (CoverSpin + 0.8) % 360
                if Items["Cover"] and Items["Cover"].Parent then
                    Items["Cover"].Rotation = CoverSpin
                end
            end
            task.wait(0.03)
        end
    end)

    task.spawn(function()
        while not Destroyed and Library and Items["SpotifyPlayer"] and Items["SpotifyPlayer"].Parent do
            task.wait(1)
        end
        if not Destroyed then
            Cleanup()
        end
    end)

    if Library.ScreenGui then
        Connect(Library.ScreenGui.Destroying, Cleanup)
    end

    if typeof(game.BindToClose) == "function" then
        pcall(function() game:BindToClose(Cleanup) end)
    end

    UpdateResults()
    SetSidebarTab("queue")
    SetExpanded(false, true)
    Spotify:Center()
    return Spotify
end

Library.Directory = "spotifyforRawr"
getgenv().Library = Library
return Library
