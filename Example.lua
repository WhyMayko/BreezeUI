-- Library/BreezeUI/Example.lua
-- Complete BreezeUI Showcase covering Elements, Notify, Dialog/Popup, and Settings.

local repo = "https://raw.githubusercontent.com/WhyMayko/BreezeUI/main/"

local Library, ThemeManager, SaveManager
if _G.BreezeUI and _G.BreezeUI.Library then
    Library, ThemeManager, SaveManager = _G.BreezeUI.Library, _G.BreezeUI.ThemeManager, _G.BreezeUI.SaveManager
else
    loadstring(game:HttpGet(repo .. "Loader.lua"))()
    Library, ThemeManager, SaveManager = _G.BreezeUI()
end

local function BuildShowcase(customLib)
    local Lib = customLib or Library
    assert(Lib, "BreezeUI library instance could not be loaded!")

    local Window = Lib:CreateWindow({
        Title = "BreezeUI",
        Subtitle = "Showcase",
        Size = Vector2.new(640, 460),
        Theme = "Dark",
        Profile = {
            Enabled = true,
            Tag = { Text = "Breeze" },
            ShowCreated = true,
            ShowFPS = true,
            ShowUptime = true,
            ShowDate = true,
            ShowTime = true,
        },
    })

    Window:EditOpenButton({
        Title = "Open BreezeUI",
        Draggable = true,
    })

    -- ========================================================================
    -- 1. SECTION: ELEMENTS (Toggles, Sliders, Inputs, Dropdowns, Groups)
    -- ========================================================================
    local SecElements = Window:Section({ Title = "Elements", Opened = true })

    local TabOverview = SecElements:Tab({
        Title = "Overview",
        Icon = "home",
        IconShape = "Square",
        IconColor = Color3.fromRGB(37, 122, 247),
    })
    local CardGroup = TabOverview:Section({ Title = "Group & Dependencies" })
    local grp = CardGroup:Group()
    grp:Button({
        Title = "Notify Toast",
        Justify = "Center",
        Callback = function()
            Lib:Notify({ Title = "BreezeUI", Content = "Notification working cleanly!", Icon = "bell-ring", Duration = 4 })
        end,
    })
    grp:Button({
        Title = "Open Popup",
        Justify = "Center",
        Color = Color3.fromRGB(37, 122, 247),
        Callback = function()
            Lib:Popup({
                Title = "BreezeUI Popup",
                Content = "Centered popup notice.",
                Buttons = {
                    { Title = "OK", Variant = "Primary", Callback = function() end },
                },
            })
        end,
    })
    local extraSlider = CardGroup:AddSlider("ExtraPower", {
        Text = "Extra Power",
        Min = 1,
        Max = 100,
        Default = 50,
        Precision = 0,
        Hidden = true,
    })
    CardGroup:AddDropdown("DynamicMode", {
        Text = "Mode",
        Values = { "Standard", "Custom" },
        Default = "Standard",
        Callback = function(val)
            if val == "Custom" then
                extraSlider:Show()
            else
                extraSlider:Hide()
            end
        end,
    })

    local TabCombat = SecElements:Tab({
        Title = "Combat",
        Icon = "crosshair",
        IconShape = "Square",
        IconColor = Color3.fromRGB(239, 68, 68),
    })
    local CardAim = TabCombat:Section({ Title = "Aim & Controls" })
    local TogAim = CardAim:AddToggle("AimbotEnabled", { Text = "Aimbot", Default = false })
    TogAim:AddKeyPicker("AimbotKey", { Mode = "Hold" })
    CardAim:AddCheckbox("SilentCheck", { Text = "Silent Aim (Checkbox)", Default = false })
    CardAim:AddSlider("AimFOV", { Text = "FOV", Min = 30, Max = 180, Default = 90, Precision = 0 })
    CardAim:AddDropdown("AimTargetPart", {
        Text = "Target Part",
        Values = { "Head", "Torso", "HumanoidRootPart" },
        Default = "Head",
    })
    CardAim:AddDropdown("EspFilters", {
        Text = "Filters (Multi)",
        Values = { "Box", "Tracer", "Name", "Distance" },
        Multi = true,
        AllowNone = true,
    })
    CardAim:AddColorPicker("EspColor", {
        Title = "Highlight Color",
        Default = Color3.fromRGB(0, 145, 255),
        Transparency = 0,
    })

    local TabMisc = SecElements:Tab({
        Title = "Misc",
        Icon = "zap",
        IconShape = "Square",
        IconColor = Color3.fromRGB(234, 179, 8),
    })
    local CardMisc = TabMisc:Section({ Title = "Paragraph, Code & Progress" })
    CardMisc:Paragraph({
        Title = "BreezeUI Info",
        Desc = "Drawing-API library with Theme, Config, Dialog, and Notification subsystems.",
        Image = "sparkles",
        Color = "Blue",
        Buttons = {
            { Title = "Ping", Callback = function()
                Lib:Notify({ Title = "Paragraph", Content = "Inline button clicked!", Icon = "sparkles", Duration = 2 })
            end },
        },
    })
    CardMisc:Code({
        Title = "BreezeUI Loader",
        Code = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/WhyMayko/BreezeUI/main/Loader.lua"))()',
    })
    local pb = CardMisc:AddProgressBar("DemoProgress", {
        Title = "Task Progress",
        Value = { Min = 0, Max = 100, Default = 40 },
        Format = "%d / %d",
    })
    CardMisc:AddProgressBar("IndetProgress", {
        Title = "Syncing State",
        Indeterminate = true,
    })
    CardMisc:AddButton({
        Text = "Step Progress (+20%)",
        Size = "Small",
        IconAlign = "Left",
        Tags = { { Title = "New", Color = "Blue" } },
        Callback = function()
            local nextV = (pb.Value >= 100) and 0 or math.min(100, pb.Value + 20)
            pb:Set(nextV)
        end,
    })
    CardMisc:AddSlider("WideVolume", {
        Wide = true,
        Min = 0,
        Max = 100,
        Default = 70,
        Icons = { From = "volume-1", To = "volume-2" },
    })
    CardMisc:AddInput("DemoTextInput", {
        Text = "Custom Label",
        Placeholder = "Type here...",
        ClearTextOnFocus = true,
    })
    CardMisc:AddInput("DemoNumInput", {
        Text = "Numeric (Finished)",
        Default = "100",
        Numeric = true,
        Finished = true,
    })
    CardMisc:AddKeybind("StandaloneBind", {
        Title = "Standalone Keybind",
        Mode = "Toggle",
        Blacklist = { "Escape" },
        Callback = function(state)
            Lib:Notify({ Title = "Keybind", Content = "State: " .. tostring(state), Duration = 2 })
        end,
    })
    CardMisc:AddDropdown("SearchDrop", {
        Text = "Search & Rich Items",
        Search = true,
        Values = {
            "Alpha",
            "Beta",
            { Type = "Divider" },
            { Title = "Locked Item", Locked = true },
            "Gamma",
        },
        Default = "Alpha",
    })
    CardMisc:AddDropdown("PlayerDrop", {
        Text = "Players",
        SpecialType = "Player",
    })
    CardMisc:Image({
        Image = "https://raw.githubusercontent.com/WhyMayko/BreezeUI/main/assets/textures/hue-bar.png",
        Height = 44,
        Radius = 8,
    })
    CardMisc:Button({
        Title = "Locked Action",
        Desc = "Cannot be pressed while locked",
        Locked = true,
    })
    CardMisc:Toggle({
        Title = "Locked Toggle",
        Locked = true,
    })

    local CollapsibleCard = TabMisc:Section({ Title = "Collapsible Section", Box = true, Opened = false })
    CollapsibleCard:AddToggle("ColToggle", { Text = "Inside Collapsible", Default = false })
    CollapsibleCard:AddButton({ Text = "Collapsible Action", Callback = function()
        Lib:Notify({ Title = "Section", Content = "Expanded section clicked!", Duration = 2 })
    end })

    -- ========================================================================
    -- 2. SECTION: NOTIFY & DIALOGS
    -- ========================================================================
    local SecTools = Window:Section({ Title = "Subsystems", Opened = false })
    local TabTools = SecTools:Tab({ Title = "Notify & Dialog", Icon = "bell" })
    local CardNotif = TabTools:Section({ Title = "Tests" })
    CardNotif:AddButton({
        Text = "Notify w/ Buttons",
        Callback = function()
            Lib:Notify({
                Title = "Action Toast",
                Content = "Click Accept to fire callback.",
                Icon = "bell",
                Duration = 7,
                Buttons = {
                    { Title = "Accept", Callback = function()
                        Lib:Notify({ Title = "Accepted", Content = "Callback executed.", Icon = "check", Duration = 2.5 })
                    end },
                    { Title = "Ignore", Callback = function() end },
                },
            })
        end,
    })
    CardNotif:AddButton({
        Text = "Progress Notification",
        Callback = function()
            local toast = Lib:Progress("Downloading", "Fetching presets...", false)
            if toast and task and task.spawn and task.wait then
                task.spawn(function()
                    for step = 1, 10 do
                        if toast.Closed then return end
                        toast:SetProgress(step / 10)
                        toast:SetContent("Fetching presets... " .. tostring(step * 10) .. "%")
                        task.wait(0.25)
                    end
                    toast:SetTitle("Complete")
                    toast:SetContent("Presets loaded.")
                    task.wait(1.0)
                    toast:Close()
                end)
            end
        end,
    })
    CardNotif:AddButton({
        Text = "Confirm Dialog",
        Callback = function()
            Window:Dialog({
                Title = "Reset Check",
                Content = "Modal backdrop blocks clicks behind dialog.",
                Buttons = {
                    { Title = "Cancel", Variant = "Secondary", Callback = function() end },
                    { Title = "Confirm", Variant = "Primary", Callback = function()
                        Lib:Notify({ Title = "Dialog", Content = "Confirmed!", Icon = "check", Duration = 2.5 })
                    end },
                },
            })
        end,
    })
    CardNotif:AddButton({
        Text = "Toggle Fullscreen",
        Callback = function() Window:ToggleFullscreen() end,
    })

    -- ========================================================================
    -- 3. NATIVE SETTINGS TAB (18 Themes, UI Scale, Keybind, InputBlock, Configs)
    -- ========================================================================
    if Lib.Settings and Lib.Settings.BuildTab then
        Lib.Settings.BuildTab(Window)
    end

    return Window
end

local Example = setmetatable({
    Build = BuildShowcase,
}, {
    __call = function(_, customLib)
        return BuildShowcase(customLib)
    end,
})

if game and game.HttpGet then
    BuildShowcase()
end

return Example
