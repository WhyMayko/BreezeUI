-- Library/BreezeUI/Init.lua
-- Main entry point and public API export for the BreezeUI Drawing UI Library.

local PoolModule = require("./Core/Pool")
local MetaModule = require("./Core/Meta")
local GeometryModule = require("./Core/Geometry")
local MetricsModule = require("./Core/Metrics")

local ThemeModule = require("./Layout/Theme")
local WindowModule = require("./Layout/Window")
local SidebarModule = require("./Layout/Sidebar")
local TabModule = require("./Layout/Tab")
local ContentSectionModule = require("./Layout/ContentSection")

local ClampingModule = require("./Engine/Clamping")
local DragModule = require("./Engine/Drag")
local AnimationsModule = require("./Engine/Animations")
local InputHandlerModule = require("./Engine/InputHandler")

local IconsModule = require("./Subsystems/Icons")
local SettingsModule = require("./Subsystems/Settings")
local NotifyModule = require("./Subsystems/Notify")
local DialogModule = require("./Subsystems/Dialog")
local OverlayModule = require("./Subsystems/Overlay")

local ToggleModule = require("./Components/Toggle")
local ButtonModule = require("./Components/Button")
local SliderModule = require("./Components/Slider")
local DropdownModule = require("./Components/Dropdown")
local InputModule = require("./Components/Input")
local KeybindModule = require("./Components/Keybind")
local ParagraphModule = require("./Components/Paragraph")
local CodeModule = require("./Components/Code")
local ImageModule = require("./Components/Image")
local ProgressBarModule = require("./Components/ProgressBar")
local ColorpickerModule = require("./Components/Colorpicker")

local BreezeUI = {}

-- State registries with fail-fast proxies (Rules 2 & 3: single central gate, no silent fallback)
local rawOptions = {}
local rawToggles = {}
local initialDefaults = { Options = {}, Toggles = {} }
local profiles = {}

local OptionsProxy = setmetatable({}, {
    __index = function(tbl, k)
        local raw = rawget(tbl, k)
        if raw ~= nil then return raw end
        if rawOptions[k] ~= nil then return rawOptions[k] end
        assert(false, string.format("Option '%s' not found! (Option does not exist)", tostring(k)))
    end,
    __newindex = function(tbl, k, v)
        if rawOptions[k] ~= nil then
            rawOptions[k]:Set(v)
            return
        end
        local raw = rawget(tbl, k)
        if raw ~= nil and type(raw) == "table" and raw.Set then
            raw:Set(v)
            return
        end
        assert(false, string.format("Cannot assign unregistered Option '%s'!", tostring(k)))
    end
})

local TogglesProxy = setmetatable({}, {
    __index = function(tbl, k)
        local raw = rawget(tbl, k)
        if raw ~= nil then return raw end
        if rawToggles[k] ~= nil then return rawToggles[k] end
        assert(false, string.format("Toggle '%s' not found! (Toggle does not exist)", tostring(k)))
    end,
    __newindex = function(tbl, k, v)
        if rawToggles[k] ~= nil then
            rawToggles[k]:Set(v)
            return
        end
        local raw = rawget(tbl, k)
        if raw ~= nil and type(raw) == "table" and raw.Set then
            raw:Set(v)
            return
        end
        assert(false, string.format("Cannot assign unregistered Toggle '%s'!", tostring(k)))
    end
})

-- Shared properties and submodules
BreezeUI._windows = {}
local prevOrphans = type(_G) == "table" and rawget(_G, "__BreezeUI_OrphanWindows")
if type(prevOrphans) == "table" then
    for _, oldWin in ipairs(prevOrphans) do
        if oldWin and not oldWin.Destroyed and oldWin.Destroy then
            oldWin:Destroy()
        end
    end
end
if type(_G) == "table" and not (table and table.isfrozen and table.isfrozen(_G)) then
    rawset(_G, "__BreezeUI_OrphanWindows", BreezeUI._windows)
end

BreezeUI.Options = OptionsProxy
BreezeUI.Toggles = TogglesProxy
BreezeUI._rawOptions = rawOptions
BreezeUI._rawToggles = rawToggles
BreezeUI._initialDefaults = initialDefaults
BreezeUI._defaults = { options = {}, toggles = {} }
BreezeUI._profiles = profiles

BreezeUI.Pool = PoolModule
BreezeUI.Meta = MetaModule
BreezeUI.Geometry = GeometryModule
BreezeUI.Metrics = MetricsModule
BreezeUI.Theme = ThemeModule
BreezeUI.Window = WindowModule
BreezeUI.Sidebar = SidebarModule
BreezeUI.Tab = TabModule
BreezeUI.ContentSection = ContentSectionModule

BreezeUI.Clamping = ClampingModule
BreezeUI.Drag = DragModule
BreezeUI.Animations = AnimationsModule
BreezeUI.AnimationEngine = AnimationsModule
BreezeUI.InputHandler = InputHandlerModule
BreezeUI.Icons = IconsModule
BreezeUI.IconSubsystem = IconsModule
BreezeUI.Settings = SettingsModule
BreezeUI.NotifySubsystem = NotifyModule
BreezeUI.DialogSubsystem = DialogModule
BreezeUI.OverlaySubsystem = OverlayModule
BreezeUI.ThemeManager = ThemeModule
BreezeUI.SaveManager = SettingsModule
BreezeUI.UnloadCallbacks = {}
BreezeUI._connections = {}
BreezeUI.Unloaded = false

BreezeUI.Components = {
    Toggle = ToggleModule,
    Button = ButtonModule,
    Slider = SliderModule,
    Dropdown = DropdownModule,
    Input = InputModule,
    Keybind = KeybindModule,
    Paragraph = ParagraphModule,
    Code = CodeModule,
    Image = ImageModule,
    ProgressBar = ProgressBarModule,
    Colorpicker = ColorpickerModule,
}

BreezeUI.Scale = 1.0
BreezeUI.Version = "1.6.62"
BreezeUI.Creator = { AddIcons = function() end }
BreezeUI.FocusedWidget = nil
BreezeUI.ActiveAnimations = {}
BreezeUI.TargetFPS = 60
BreezeUI.IdleTimer = 0
BreezeUI.IdleTimeout = 1.0
BreezeUI._activeWindow = nil
BreezeUI.Destroyed = false
BreezeUI._destroyed = false

function BreezeUI:Notify(cfg, title, duration)
    if type(cfg) == "table" and not cfg.Side and self._activeWindow and self._activeWindow.NotifySide then
        cfg.Side = self._activeWindow.NotifySide
    end
    return NotifyModule.Push(cfg, title, duration)
end

function BreezeUI:Progress(title, message, duration)
    return NotifyModule.Progress(title, message, duration)
end

function BreezeUI:Update(dt)
    if self._activeWindow and not self._activeWindow.Destroyed then
        self._activeWindow:Update(dt)
    else
        NotifyModule.Update(dt or 0.016, nil)
        DialogModule.Update(dt or 0.016, nil)
    end
end

function BreezeUI:SetWatermark(text)
    if type(text) == "table" then
        self.WatermarkTokens = text
        self.WatermarkText = table.concat(text, " | ")
    else
        self.WatermarkTokens = nil
        self.WatermarkText = tostring(text or "")
    end
    self.WatermarkVisible = self.WatermarkText ~= ""
    if self._activeWindow and self._activeWindow.SetWatermark then
        self._activeWindow:SetWatermark(text)
    end
end

function BreezeUI:SetWatermarkVisibility(visible)
    self.WatermarkVisible = visible == true
    if self._activeWindow and self._activeWindow.SetWatermarkVisibility then
        self._activeWindow:SetWatermarkVisibility(visible)
    end
end

function BreezeUI:SetKeybindMenuVisible(state)
    self.ShowKeybindMenu = state == true
    if self._activeWindow and self._activeWindow.SetKeybindMenuVisible then
        self._activeWindow:SetKeybindMenuVisible(state)
    end
end

function BreezeUI:SetInputBlocking(state)
    self.BlockRobloxInput = state == true
    if self._activeWindow and self._activeWindow.SetInputBlocking then
        self._activeWindow:SetInputBlocking(state)
    end
end

function BreezeUI:Toggle(state)
    local win = self._activeWindow
    if win and not win.Destroyed and win.SetVisible then
        local target = state ~= nil and (state == true) or (not win.Visible)
        win:SetVisible(target)
    end
end

function BreezeUI:OnUnload(cb)
    if type(cb) == "function" then
        table.insert(self.UnloadCallbacks, cb)
    end
end

function BreezeUI:Unload()
    for _, cb in ipairs(self.UnloadCallbacks) do
        pcall(cb)
    end
    self.UnloadCallbacks = {}
    self:Destroy()
end

function BreezeUI:Popup(cfg)
    return DialogModule.Show(cfg, self._activeWindow, "Popup")
end

-- Link lastEnv for Settings
SettingsModule._lastEnv = BreezeUI

-- Interaction Locking API
function BreezeUI:ClaimInteraction(widgetId)
    if self.FocusedWidget == nil or self.FocusedWidget == widgetId then
        self.FocusedWidget = widgetId
        self.TargetFPS = 60
        self.IdleTimer = 0
        AnimationsModule.CurrentFocusedWidget = widgetId
        return true
    end
    return false
end

function BreezeUI:ReleaseInteraction(widgetId)
    if self.FocusedWidget == widgetId then
        self.FocusedWidget = nil
        AnimationsModule.CurrentFocusedWidget = nil
    end
end

function BreezeUI:CanInteract(widgetId)
    return self.FocusedWidget == nil or self.FocusedWidget == widgetId
end

-- Clamping & Snapping API
function BreezeUI:ClampAndSnap(pos, size, customViewport, customInsetTop)
    return ClampingModule.ClampAndSnap(pos, size, customViewport, customInsetTop)
end

-- Animation Delegation API
function BreezeUI:RegisterAnimation(id, animConfig)
    AnimationsModule.RegisterAnimation(id, animConfig)
end

function BreezeUI:NotifyInput()
    AnimationsModule.NotifyInput()
end

function BreezeUI:GetActiveAnimationCount()
    return AnimationsModule.GetActiveAnimationCount()
end

function BreezeUI:StepAnimations(dt)
    return AnimationsModule.Step(dt)
end

-- Theme & Scaling API
function BreezeUI:SetTheme(themeName)
    ThemeModule.SetCurrent(themeName)
    local theme = type(themeName) == "table" and themeName or ThemeModule.GetTheme(themeName)
    self.CurrentTheme = theme
    for _, win in ipairs(self._windows) do
        if not win.Destroyed and win.UpdateTheme then
            win:UpdateTheme(theme)
        end
    end
end

function BreezeUI:SetScale(scale)
    self.Scale = scale
    for _, win in ipairs(self._windows) do
        if not win.Destroyed and win.SetScale then
            win:SetScale(scale)
        end
    end
end

-- Theme enumeration (includes Light theme with dark icon set)
function BreezeUI:GetThemes()
    return {
        "Dark", "Light", "Rose", "Plant", "Red", "Indigo", "Sky", "Violet",
        "Amber", "Emerald", "Midnight", "Crimson", "MonokaiPro", "CottonCandy",
        "Mellowsi", "Rainbow", "Slate", "Ruby",
    }
end

-- Notify side helper (delegates to NotifyModule)
function BreezeUI:SetNotifySide(side)
    NotifyModule.SetSide(side)
    if self._activeWindow then
        self._activeWindow.NotifySide = side
    end
end

-- Settings tab builder: creates a fully-wired Settings tab on the given window.
function BreezeUI:SetupSettingsTab(win)
    assert(win and not win.Destroyed, "SetupSettingsTab: window must be a live Window instance!")
    return SettingsModule.BuildTab(win)
end

-- Window Construction
local str_ui_state = "breeze_ui_state"
local str_running  = "running:"
local str_unload   = "unload"

function BreezeUI:CreateWindow(config)
    -- Auto-close previous active window first so _cleanupRuntime does not clobber the new session state
    if self._activeWindow and not self._activeWindow.Destroyed then
        self._activeWindow:Destroy()
    end

    self.Unloaded = false
    self.Destroyed = false
    self._destroyed = false
    self._connections = self._connections or {}
    self.UnloadCallbacks = self.UnloadCallbacks or {}

    -- Cross-VM Matcha UI handshake: overwriting token immediately supersedes any prior running VM (and recovers cleanly from Lua VM resets)
    local uiStateToken = str_running .. tostring(os.clock()) .. ":" .. tostring(math.random(1000, 9999))
    UI.SetValue(str_ui_state, uiStateToken)

    assert(type(config) == "table", "CreateWindow requires configuration table!")
    if config.Folder and config.Folder ~= "" then
        SettingsModule.SetFolder(config.Folder)
    end

    config.Env = self
    local win = WindowModule.new(config)
    win._uiStateToken = uiStateToken
    self._activeWindow = win
    table.insert(self._windows, win)
    return win
end

function BreezeUI:IsLoaded()
    if self.Unloaded or self.Destroyed then return false end
    local win = self._activeWindow
    if not win or win.Destroyed then return false end
    local cur = UI and UI.GetValue and UI.GetValue(str_ui_state)
    if cur == str_unload or (win._uiStateToken and cur ~= nil and cur ~= "" and cur ~= win._uiStateToken) then
        return false
    end
    return true
end

function BreezeUI:OnUnload(cb)
    assert(type(cb) == "function", "OnUnload requires callback function!")
    table.insert(self.UnloadCallbacks, cb)
end

function BreezeUI:GiveConnection(conn)
    if conn then table.insert(self._connections, conn) end
    return conn
end

function BreezeUI:Connect(signal, fn)
    assert(signal and signal.Connect and type(fn) == "function", "Connect requires signal and callback!")
    local conn
    conn = signal:Connect(function(...)
        if not self:IsLoaded() then return end
        fn(...)
    end)
    return self:GiveConnection(conn)
end

function BreezeUI:_cleanupRuntime()
    if self.Unloaded then return end
    self.Unloaded = true
    self.Destroyed = true
    self._destroyed = true

    for _, conn in ipairs(self._connections) do
        if conn and conn.Disconnect then
            conn:Disconnect()
        end
    end
    self._connections = {}

    local cbs = self.UnloadCallbacks
    self.UnloadCallbacks = {}
    for _, cb in ipairs(cbs) do
        pcall(cb)
    end
end

-- Destruction
function BreezeUI:Destroy()
    self:_cleanupRuntime()
    for _, win in ipairs(self._windows) do
        if win.Destroy and not win.Destroyed then
            win:Destroy()
        end
    end
    self._windows = {}
    self._activeWindow = nil

    for k in pairs(rawOptions) do rawOptions[k] = nil end
    for k in pairs(rawToggles) do rawToggles[k] = nil end

    AnimationsModule.Reset()
    NotifyModule.Destroy()
    DialogModule.Destroy()
    OverlayModule.Destroy()
    IconsModule.ClearCache()
end

function BreezeUI:Unload()
    self:Destroy()
end

-- Export global library handle for scripts running inside Matcha
pcall(function()
    if _G and not table.isfrozen(_G) then
        _G.BreezeUI = _G.BreezeUI or {}
        _G.BreezeUI["Library.lua"] = BreezeUI
        _G.BreezeUI.Library = BreezeUI
        _G.BreezeUI.ThemeManager = BreezeUI.Theme
        _G.BreezeUI.SaveManager = BreezeUI.Settings
        _G.BreezeUI.Options = BreezeUI.Options
        _G.BreezeUI.Toggles = BreezeUI.Toggles
        _G.BreezeUI.Get = function()
            return BreezeUI, BreezeUI.Theme, BreezeUI.Settings
        end
        setmetatable(_G.BreezeUI, {
            __call = function()
                return BreezeUI, BreezeUI.Theme, BreezeUI.Settings
            end,
            __index = BreezeUI,
        })
        _G.Library = BreezeUI
        _G.WindUI = _G.BreezeUI
    end
end)

return BreezeUI
