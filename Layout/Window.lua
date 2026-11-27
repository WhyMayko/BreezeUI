-- Library/BreezeUI/Layout/Window.lua
-- Core Window frame, seamless macOS topbar, ResizeIcon, smart viewport clamping, animations, and unified input loop.

local PoolModule = Pool or require("../Core/Pool")
local MetaModule = Meta or require("../Core/Meta")
local GeometryModule = Geometry or require("../Core/Geometry")
local MetricsModule = Metrics or require("../Core/Metrics")
local ThemeModule = Theme or require("./Theme")
local SidebarModule = Sidebar or require("./Sidebar")
local ClampingModule = Clamping or require("../Engine/Clamping")

local DragModule = Drag
if not DragModule then
    local ok, mod = pcall(function() return require("../Engine/Drag") end)
    if ok then DragModule = mod end
end

local AnimationsModule = Animations
if not AnimationsModule then
    local ok, mod = pcall(function() return require("../Engine/Animations") end)
    if ok then AnimationsModule = mod end
end

local InputHandlerModule = InputHandler
if not InputHandlerModule then
    local ok, mod = pcall(function() return require("../Engine/InputHandler") end)
    if ok then InputHandlerModule = mod end
end

local IconsModule = Icons
if not IconsModule then
    local ok, mod = pcall(function() return require("../Subsystems/Icons") end)
    if ok then IconsModule = mod end
end

local NotifyModule = Notify
if not NotifyModule then
    local ok, mod = pcall(function() return require("../Subsystems/Notify") end)
    if ok then NotifyModule = mod end
end

local DialogModule = Dialog
if not DialogModule then
    local ok, mod = pcall(function() return require("../Subsystems/Dialog") end)
    if ok then DialogModule = mod end
end

local OverlayModule = Overlay
if not OverlayModule then
    local ok, mod = pcall(function() return require("../Subsystems/Overlay") end)
    if ok then OverlayModule = mod end
end

local Window = {}
Window.__index = Window

local UI_STATE_KEY = "breeze_ui_state"
local UI_STATE_RUNNING = "running"
local UI_STATE_UNLOAD = "unload"
local UI_STATE_EMPTY = ""

local function get_theme_color(token, default)
    if ThemeModule and ThemeModule.Get then
        local val = ThemeModule.Get(token)
        if val ~= nil then return val end
    end
    return default
end

local function get_mouse()
    if not game or not game.GetService then return nil end
    local ok, players = pcall(function() return game:GetService("Players") end)
    if ok and players and players.LocalPlayer then
        return players.LocalPlayer:GetMouse()
    end
    return nil
end

local function get_viewport()
    local vp = Vector2.new(1920, 1080)
    pcall(function()
        local cam = workspace and workspace.CurrentCamera
        if cam and cam.ViewportSize and cam.ViewportSize.X > 0 and cam.ViewportSize.Y > 0 then
            vp = cam.ViewportSize
        end
    end)
    return vp
end

function Window.new(config)
    config = config or {}
    assert(config.Title ~= nil and tostring(config.Title) ~= "", "Window config.Title is required!")

    local vp = get_viewport()
    local minSize = config.MinSize or Vector2.new(460, 320)
    local rawSize = config.Size or Vector2.new(640, 460)
    local maxSize = config.MaxSize or Vector2.new(960, 680)
    local safeMaxX = math.max(minSize.X, math.min(maxSize.X, vp.X - 24))
    local safeMaxY = math.max(minSize.Y, math.min(maxSize.Y, vp.Y - 48))

    local resolvedSize = Vector2.new(
        math.clamp(rawSize.X, minSize.X, safeMaxX),
        math.clamp(rawSize.Y, minSize.Y, safeMaxY)
    )

    local initialPos = config.Position
    if not initialPos then
        local cx = math.max(12, math.floor((vp.X - resolvedSize.X) * 0.5))
        local cy = math.max(36, math.floor((vp.Y - resolvedSize.Y) * 0.5))
        initialPos = Vector2.new(cx, cy)
    end

    local themeName = type(config.Theme) == "string" and config.Theme or "Dark"
    local themeTokens = type(config.Theme) == "table" and config.Theme
        or (ThemeModule and ThemeModule.GetTheme and ThemeModule.GetTheme(themeName))
        or (ThemeModule and ThemeModule.DefaultPalette)
        or {}

    local poolInstance = PoolModule and PoolModule.new(350, MetaModule)
    local env = config.Env or (type(_G.Library) == "table" and _G.Library) or nil
    local topbarH = (type(config.Topbar) == "table" and config.Topbar.Height) or 44

    local self = setmetatable({
        Env = env,
        Title = tostring(config.Title),
        Subtitle = config.Subtitle or (config.Author and tostring(config.Author)) or "BreezeUI",
        Folder = config.Folder,
        Icon = config.Icon,
        Position = initialPos,
        Size = resolvedSize,
        BaseSize = resolvedSize,
        MinSize = minSize,
        MaxSize = maxSize,
        CanResize = config.Resizable ~= false,
        SidebarWidth = config.SidebarWidth or 190,
        ProfileConfig = config.Profile,
        CornerRadius = config.CornerRadius or 14,
        Theme = themeName,
        ThemeTokens = themeTokens,
        Scale = config.Scale or ((config.DPIScale or 100) / 100),
        HeaderHeight = topbarH,
        Topbar = config.Topbar or { Height = topbarH, ButtonsType = "Mac" },
        ToggleKey = config.ToggleKey or config.MenuKey,
        IgnoreAlerts = config.IgnoreAlerts == true,
        BlockRobloxInput = (config.BlockRobloxInput == true) or (env and env.BlockRobloxInput == true),
        _lastInputBlocked = false,
        ShowKeybindMenu = (config.ShowKeybindMenu == true) or (env and env.ShowKeybindMenu == true),
        KeybindMenuX = config.KeybindMenuX or (type(config.KeybindMenu) == "table" and config.KeybindMenu.X) or nil,
        KeybindMenuY = config.KeybindMenuY or (type(config.KeybindMenu) == "table" and config.KeybindMenu.Y) or nil,
        KeybindMenuWidth = config.KeybindMenuWidth or (type(config.KeybindMenu) == "table" and config.KeybindMenu.Width) or 240,
        Watermark = {
            Text = (env and env.WatermarkText) or (type(config.Watermark) == "string" and config.Watermark) or "",
            Tokens = (env and env.WatermarkTokens) or nil,
            Visible = (env and env.WatermarkVisible == true) or (type(config.Watermark) == "string" and config.Watermark ~= ""),
            X = 16,
            Y = 16,
        },
        OpenButton = {
            Enabled = config.OpenButton ~= false,
            Title = tostring(config.Title),
            Icon = config.Icon or "wind",
            Draggable = true,
            OnlyIcon = false,
            Position = nil,
            Color = nil,
        },

        -- State flags
        Minimized = false,
        IsMaximized = false,
        PreMaximizeSize = nil,
        PreMaximizePos = nil,
        Visible = true,
        Destroyed = false,
        Running = true,
        FocusedWidget = nil,
        ActiveInteraction = nil,
        FocusedInput = nil,
        OpenDropdown = nil,
        CapturingKeybind = nil,
        IsDragging = false,
        DragStart = Vector2.new(0, 0),
        DragStartPos = Vector2.new(0, 0),
        LastPillClick = -10,
        IsResizing = false,
        ResizeStartMouse = Vector2.new(0, 0),
        ResizeStartSize = Vector2.new(0, 0),
        RegisteredIds = {
            Toggles = {},
            Options = {},
        },

        -- Hierarchy Collections
        Sections = {},
        Tabs = {},
        Keybinds = {},
        ActiveTab = nil,
        Cards = {},
        Tags = {},
        Drawings = {},
        _drawings = {},
        _onOpenCallbacks = {},
        _onCloseCallbacks = {},
        _onDestroyCallbacks = {},
        DisabledTopbarButtons = {},
        BgImage = nil,
        BgImageUrl = nil,
        BgImageTransparency = 0.25,

        -- Core Engine
        Pool = poolInstance,
        Sidebar = nil,
        DragModule = nil,
        Input = InputHandlerModule and InputHandlerModule.new() or nil,

        -- Hardware Input
        Mouse = nil,
        PrevM1 = false,
        RenderConnection = nil,
        ScrollConnection = nil,

        -- Visual Primitives
        FrameBg = nil,
        Background = nil,
        Border = nil,
        HeaderBg = nil,
        MainPanelBg = nil,
        TopbarDivider = nil,
        ScrollTrack = nil,
        ScrollThumb = nil,
        ResizeIcon = nil,

        -- macOS Traffic Lights
        MacClose = nil,
        MacMin = nil,
        MacMax = nil,
        CloseBtn = nil,
        CloseBtnBg = nil,
        CloseBtnIcon = nil,
        MinBtn = nil,
        MinBtnBg = nil,
        MinBtnIcon = nil,
        MaxBtn = nil,
        MaxBtnBg = nil,

        -- Header Branding & Titles
        HeaderIcon = nil,
        Logo = nil,
        TitleText = nil,
        HeaderText = nil,
        SubtitleText = nil,
        TitleOffset = 74,
        TitleEndOffset = 220,

        -- Bottom Drag Pill
        BottomDragPill = nil,
        VerticalDivider = nil,
    }, Window)

    self:_createChrome()
    self.DragModule = DragModule and DragModule.new(self) or nil

    if SidebarModule then
        self.Sidebar = SidebarModule.new(self, { Width = self.SidebarWidth })
        self.VerticalDivider = self.Sidebar.Divider
    end

    pcall(function()
        local runService = game:GetService("RunService")
        if runService and runService.RenderStepped then
            local conn
            conn = runService.RenderStepped:Connect(function(dt)
                self:Update(dt)
            end)
            self.RenderConnection = conn
        end
    end)

    pcall(function()
        local uis = game:GetService("UserInputService")
        if uis and uis.InputChanged then
            local sConn
            sConn = uis.InputChanged:Connect(function(input)
                if not self.Visible or self.Minimized or self.Destroyed then return end
                if input and Enum and Enum.UserInputType and input.UserInputType == Enum.UserInputType.MouseWheel then
                    local delta = input.Position and input.Position.Z or 0
                    if delta ~= 0 then
                        if self.OpenDropdown and self.OpenDropdown.Opened and (self.OpenDropdown.MaxScrollOffset or 0) > 0 then
                            self.OpenDropdown:Scroll(delta > 0 and -1 or 1)
                        elseif self.ActiveTab and self.ActiveTab.Scroll then
                            self.ActiveTab:Scroll(-delta * 28)
                        end
                    end
                end
            end)
            self.ScrollConnection = sConn
        end
    end)

    return self
end

function Window:_createChrome()
    local pool = self.Pool
    if not pool then return end

    local px = self.Position.X
    local py = self.Position.Y
    local sx = self.Size.X
    local sy = self.Size.Y
    local corner = self.CornerRadius
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    local bgCol = self.ThemeTokens.Background or get_theme_color("Window.Background", Color3.fromRGB(16, 16, 18))
    local borderCol = self.ThemeTokens.Border or get_theme_color("Window.Border", Color3.fromRGB(36, 36, 42))
    local panelCol = self.ThemeTokens.PanelBackground or get_theme_color("PanelBackground", Color3.fromRGB(22, 22, 26))
    local textCol = self.ThemeTokens.Text or get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))

    -- 1. Main Window Frame Background & Border
    local bg = pool:Get("Square")
    bg.Position = self.Position
    bg.Size = self.Size
    bg.Color = bgCol
    bg.Filled = true
    bg.Corner = corner
    bg.ZIndex = 1
    bg.Visible = true
    self.FrameBg = bg
    self.Background = bg
    self:_register(bg)

    local b = pool:Get("Square")
    b.Position = self.Position
    b.Size = self.Size
    b.Color = borderCol
    b.Filled = false
    b.Thickness = 1
    b.Corner = corner
    b.ZIndex = 3
    b.Visible = true
    self.Border = b
    self:_register(b)

    -- 2. Right Content MainBar Panel
    local panel = pool:Get("Square")
    panel.Position = Vector2.new(px + self.SidebarWidth + 4, py + self.HeaderHeight)
    panel.Size = Vector2.new(sx - self.SidebarWidth - 12, sy - self.HeaderHeight - 8)
    panel.Color = panelCol
    panel.Filled = true
    panel.Corner = 10
    panel.ZIndex = 2
    panel.Visible = true
    self.MainPanelBg = panel
    self:_register(panel)

    -- 3. Content Scrollbar Track & Thumb (dedicated gutter separated from sections)
    local sTrack = pool:Get("Square")
    sTrack.Position = Vector2.new(px + sx - 22, py + self.HeaderHeight + 10)
    sTrack.Size = Vector2.new(8, 40)
    sTrack.Color = get_theme_color("Control.Background", Color3.fromRGB(48, 48, 52))
    sTrack.Filled = true
    sTrack.Corner = 4
    sTrack.Transparency = 0.45
    sTrack.ZIndex = 7
    sTrack.Visible = false
    self.ScrollTrack = sTrack
    self:_register(sTrack)

    local sThumb = pool:Get("Square")
    sThumb.Position = Vector2.new(px + sx - 22, py + self.HeaderHeight + 10)
    sThumb.Size = Vector2.new(8, 40)
    sThumb.Color = get_theme_color("Text.Muted", Color3.fromRGB(161, 161, 161))
    sThumb.Filled = true
    sThumb.Corner = 4
    sThumb.Transparency = 0.28
    sThumb.ZIndex = 8
    sThumb.Visible = false
    self.ScrollThumb = sThumb
    self:_register(sThumb)

    self.HeaderBg = bg

    -- 4. macOS Traffic Lights
    local closeCol = get_theme_color("Mac.Close", Color3.fromRGB(255, 95, 86))
    local minCol = get_theme_color("Mac.Minimize", Color3.fromRGB(255, 189, 46))
    local maxCol = get_theme_color("Mac.Maximize", Color3.fromRGB(39, 201, 63))

    local macClose = pool:Get("Square")
    macClose.Position = Vector2.new(px + 16, py + 16)
    macClose.Size = Vector2.new(11, 11)
    macClose.Corner = 5.5
    macClose.Filled = true
    macClose.Color = closeCol
    macClose.ZIndex = 4
    macClose.Visible = true
    self.MacClose = macClose
    self.CloseBtn = macClose
    self.CloseBtnBg = macClose
    self:_register(macClose)

    local macMin = pool:Get("Square")
    macMin.Position = Vector2.new(px + 34, py + 16)
    macMin.Size = Vector2.new(11, 11)
    macMin.Corner = 5.5
    macMin.Filled = true
    macMin.Color = minCol
    macMin.ZIndex = 4
    macMin.Visible = true
    self.MacMin = macMin
    self.MinBtn = macMin
    self.MinBtnBg = macMin
    self:_register(macMin)

    local macMax = pool:Get("Square")
    macMax.Position = Vector2.new(px + 52, py + 16)
    macMax.Size = Vector2.new(11, 11)
    macMax.Corner = 5.5
    macMax.Filled = true
    macMax.Color = maxCol
    macMax.ZIndex = 4
    macMax.Visible = true
    self.MacMax = macMax
    self.MaxBtn = macMax
    self.MaxBtnBg = macMax
    self:_register(macMax)

    -- 5. Optional Brand Logo (only shown when config.Icon is explicitly provided)
    local showLogo = self.Icon ~= nil and self.Icon ~= "" and self.Icon ~= false
    local logo = pool:Get("Image")
    logo.Position = Vector2.new(px + 72, py + 14)
    logo.Size = Vector2.new(16, 16)
    logo.Transparency = 1.0
    logo.ZIndex = 4
    logo.Visible = showLogo
    self.HeaderIcon = logo
    self.Logo = logo
    self:_register(logo)

    if showLogo and IconsModule and IconsModule.Get then
        IconsModule.Get(self.Icon, function(pngData)
            if self.HeaderIcon and pngData then
                self.HeaderIcon.Data = pngData
            end
        end)
    end

    -- 6. Window Title (Single clean San Francisco line)
    local titleOffset = showLogo and 94 or 74
    local titleText = pool:Get("Text")
    local maxTitleW = math.max(80, sx - 180)
    local fullTitle = (self.Subtitle and self.Subtitle ~= "" and self.Subtitle ~= "BreezeUI")
        and (self.Title .. "  |  " .. self.Subtitle)
        or tostring(self.Title)
    local fitTitle = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(fullTitle, maxTitleW, 13) or fullTitle
    titleText.Position = Vector2.new(px + titleOffset, py + 15)
    titleText.Text = fitTitle
    titleText.Color = textCol
    titleText.Size = 13
    titleText.Font = fontUI
    titleText.Outline = false
    titleText.ZIndex = 4
    titleText.Visible = true
    self.TitleText = titleText
    self.HeaderText = titleText
    self.TitleOffset = titleOffset
    self.TitleEndOffset = titleOffset + math.floor(#fitTitle * 6.2)
    self:_register(titleText)

    local subText = pool:Get("Text")
    subText.Size = 11
    subText.Font = fontUI
    subText.Outline = false
    subText.Visible = false
    self.SubtitleText = subText

    -- 7. Bottom Drag Pill (Crisp 168x12 anti-aliased PNG matching WindUI BottomDragFrame)
    local pill = pool:Get("Image")
    pill.Position = Vector2.new(px + math.floor((sx - 168) * 0.5), py + sy + 2)
    pill.Size = Vector2.new(168, 12)
    pill.Transparency = 0.25
    pill.ZIndex = 4
    pill.Visible = true
    self.BottomDragPill = pill
    self:_register(pill)

    if IconsModule and IconsModule.Get then
        IconsModule.Get("drag-bar", function(pngData)
            if self.BottomDragPill and pngData then
                self.BottomDragPill.Data = pngData
            end
        end)
    end

    -- 8. Bottom-Right Outside Corner Resize Arc (Concentric 6px outside window corner)
    local resizeIco = pool:Get("Image")
    resizeIco.Position = Vector2.new(px + sx - 28, py + sy - 28)
    resizeIco.Size = Vector2.new(44, 44)
    resizeIco.Transparency = 0.28
    resizeIco.ZIndex = 10
    resizeIco.Visible = self.CanResize
    self.ResizeIcon = resizeIco
    self:_register(resizeIco)

    if IconsModule and IconsModule.Get then
        IconsModule.Get("resize-corner", function(pngData)
            if self.ResizeIcon and pngData then
                self.ResizeIcon.Data = pngData
            end
        end)
    end
end

function Window:_register(obj)
    if not obj then return end
    table.insert(self.Drawings, obj)
    table.insert(self._drawings, obj)
end

function Window:_syncScrollbar()
    if not self.ScrollThumb then return end
    local tab = self.ActiveTab
    if not self.Visible or self.Minimized or not tab or (tab.MaxScrollY or 0) <= 0 then
        self.ScrollThumb.Visible = false
        if self.ScrollTrack then self.ScrollTrack.Visible = false end
        return
    end

    local px = self.Position.X
    local py = self.Position.Y
    local sx = self.Size.X
    local sy = self.Size.Y
    local trackX = px + sx - 22
    local trackTop = py + self.HeaderHeight + 10
    local trackH = math.max(40, sy - self.HeaderHeight - 28)
    local totalH = trackH + tab.MaxScrollY
    local thumbH = math.max(28, math.floor(trackH * (trackH / totalH)))
    local ratio = tab.MaxScrollY > 0 and ((tab.ScrollY or 0) / tab.MaxScrollY) or 0
    local thumbY = trackTop + math.floor(ratio * (trackH - thumbH))

    if self.ScrollTrack then
        self.ScrollTrack.Position = Vector2.new(trackX, trackTop)
        self.ScrollTrack.Size = Vector2.new(8, trackH)
        self.ScrollTrack.Visible = true
    end
    self.ScrollThumb.Position = Vector2.new(trackX, thumbY)
    self.ScrollThumb.Size = Vector2.new(8, thumbH)
    self.ScrollThumb.Visible = true
end

function Window:_syncTagPositions()
    local px = self.Position.X
    local py = self.Position.Y
    local sx = self.Size.X
    for _, tag in ipairs(self.Tags) do
        local relX = math.min((self.TitleEndOffset or 220) + 12, sx - tag.Width - 14)
        tag.RelX = math.max(74, relX)
        local tx = px + tag.RelX
        local ty = py + tag.RelY
        local fitsHeader = (tx + tag.Width <= px + sx - 10)
        if tag.Bg then
            tag.Bg.Position = Vector2.new(tx, ty)
            tag.Bg.Visible = self.Visible and fitsHeader
        end
        if tag.Border then
            tag.Border.Position = Vector2.new(tx, ty)
            tag.Border.Visible = self.Visible and fitsHeader
        end
        if tag.Icon then
            tag.Icon.Position = Vector2.new(tx + 7, ty + 4)
            tag.Icon.Visible = self.Visible and fitsHeader
        end
        if tag.Text then
            tag.Text.Position = Vector2.new(tx + (tag.Icon and 24 or 8), ty + 4)
            tag.Text.Visible = self.Visible and fitsHeader
        end
    end
end

-- ============================================================================
-- Navigation Hierarchy API
-- ============================================================================

function Window:SetProfile(opts)
    if self.Sidebar and self.Sidebar.ProfileCard then
        self.Sidebar.ProfileCard:SetProfile(opts)
    end
end

function Window:Section(config)
    assert(self.Sidebar ~= nil, "Sidebar not initialized on Window!")
    return self.Sidebar:AddSection(config)
end

function Window:Tab(config)
    assert(self.Sidebar ~= nil, "Sidebar not initialized on Window!")
    return self.Sidebar:AddTab(config)
end

function Window:AddTab(config)
    return self:Tab(config)
end

function Window:SelectTab(targetTab)
    assert(targetTab ~= nil, "SelectTab requires target Tab instance!")
    if self.ActiveTab == targetTab then
        return
    end

    if self.OpenDropdown and self.OpenDropdown.Close then
        self.OpenDropdown:Close()
    end
    if self.OpenColorpicker and self.OpenColorpicker.Close then
        self.OpenColorpicker:Close()
    end
    if self.OpenKeybindMenu and self.OpenKeybindMenu.CloseModeMenu then
        self.OpenKeybindMenu:CloseModeMenu()
    end
    if self.CapturingKeybind and self.CapturingKeybind.CancelCapture then
        self.CapturingKeybind:CancelCapture()
    end
    if self.FocusedInput and self.FocusedInput.Blur then
        self.FocusedInput:Blur(false)
    end

    if self.ActiveTab then
        self.ActiveTab:Hide()
    end

    self.ActiveTab = targetTab
    self.CurrentTab = targetTab

    targetTab:Show(self.Position)
    self:_syncScrollbar()

    if self.Sidebar then
        self.Sidebar:RecalculateLayout()
    end
end

-- ============================================================================
-- Position, Size, Minimize, Maximize, Theme & Tags
-- ============================================================================

function Window:SetPosition(newPos)
    self.Position = newPos
    local px = newPos.X
    local py = newPos.Y
    local sx = self.Size.X
    local sy = self.Minimized and self.HeaderHeight or self.Size.Y

    if self.FrameBg then self.FrameBg.Position = newPos end
    if self.BgImage then self.BgImage.Position = newPos end
    if self.Border then self.Border.Position = newPos end
    if self.MainPanelBg then
        self.MainPanelBg.Position = Vector2.new(px + self.SidebarWidth + 4, py + self.HeaderHeight)
    end
    if self.MacClose then self.MacClose.Position = Vector2.new(px + 16, py + 16) end
    if self.MacMin then self.MacMin.Position = Vector2.new(px + 34, py + 16) end
    if self.MacMax then self.MacMax.Position = Vector2.new(px + 52, py + 16) end
    if self.HeaderIcon then self.HeaderIcon.Position = Vector2.new(px + 72, py + 14) end
    if self.TitleText then self.TitleText.Position = Vector2.new(px + (self.TitleOffset or 74), py + 15) end
    if self.BottomDragPill then
        self.BottomDragPill.Position = Vector2.new(px + math.floor((sx - 168) * 0.5), py + sy + 2)
    end
    if self.ResizeIcon then
        self.ResizeIcon.Position = Vector2.new(px + sx - 28, py + sy - 28)
    end

    self:_syncTagPositions()

    if self.Sidebar then
        self.Sidebar:SetPosition(newPos)
    end

    -- Sync ALL tabs so switching tabs after a drag or restore never renders stale coords
    for _, tab in ipairs(self.Tabs) do
        if tab.UpdatePosition then
            tab:UpdatePosition(newPos)
        end
    end

    self:_syncScrollbar()
end

function Window:SetSize(newSize, ignoreMaxClamp)
    local vp = get_viewport()
    local minW = self.MinSize.X
    local minH = self.MinSize.Y
    local capW = ignoreMaxClamp and (vp.X - 24) or math.min(self.MaxSize.X, vp.X - 16)
    local capH = ignoreMaxClamp and (vp.Y - 64) or math.min(self.MaxSize.Y, vp.Y - 40)
    local maxW = math.max(minW, capW)
    local maxH = math.max(minH, capH)

    local clampedW = math.clamp(newSize.X, minW, maxW)
    local clampedH = math.clamp(newSize.Y, minH, maxH)
    self.Size = Vector2.new(clampedW, clampedH)
    if not self._applyingScale and not ignoreMaxClamp then
        local sc = (self.Scale and self.Scale > 0) and self.Scale or 1
        self.BaseSize = Vector2.new(math.floor(clampedW / sc + 0.5), math.floor(clampedH / sc + 0.5))
    end

    local px = self.Position.X
    local py = self.Position.Y
    local sy = self.Minimized and self.HeaderHeight or clampedH

    if self.FrameBg then self.FrameBg.Size = Vector2.new(clampedW, sy) end
    if self.BgImage then self.BgImage.Size = Vector2.new(clampedW, sy) end
    if self.Border then self.Border.Size = Vector2.new(clampedW, sy) end
    if self.MainPanelBg then
        self.MainPanelBg.Size = Vector2.new(clampedW - self.SidebarWidth - 12, math.max(40, sy - self.HeaderHeight - 8))
    end

    local maxTitleW = math.max(60, clampedW - 180)
    local fullTitle = (self.Subtitle and self.Subtitle ~= "" and self.Subtitle ~= "BreezeUI")
        and (self.Title .. "  |  " .. self.Subtitle)
        or tostring(self.Title)
    local fitTitle = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(fullTitle, maxTitleW, 13) or fullTitle
    if self.TitleText then
        self.TitleText.Text = fitTitle
    end
    self.TitleEndOffset = (self.TitleOffset or 74) + math.floor(#fitTitle * 6.2)

    if self.BottomDragPill then
        self.BottomDragPill.Position = Vector2.new(px + math.floor((clampedW - 168) * 0.5), py + sy + 2)
    end
    if self.ResizeIcon then
        self.ResizeIcon.Position = Vector2.new(px + clampedW - 28, py + sy - 28)
    end

    self:_syncTagPositions()

    if self.Sidebar then
        self.Sidebar:SetSize(Vector2.new(self.SidebarWidth, clampedH - 58))
    end

    -- Reflow ALL tabs so resizing updates both active and inactive pages!
    for _, tab in ipairs(self.Tabs) do
        if tab.UpdateSize then
            tab:UpdateSize(self.Size)
        end
    end

    -- Keep window safely clamped inside screen bounds after resize (no magnetic snap on resize/restore)
    if not self.IsMaximized and not ignoreMaxClamp then
        local topInset = ClampingModule and ClampingModule.DefaultTopInset or 36
        local maxX = math.max(0, vp.X - self.Size.X)
        local maxY = math.max(topInset, vp.Y - self.Size.Y)
        local safeX = math.clamp(self.Position.X, 0, maxX)
        local safeY = math.clamp(self.Position.Y, topInset, maxY)
        if safeX ~= self.Position.X or safeY ~= self.Position.Y then
            self:SetPosition(Vector2.new(safeX, safeY))
            return
        end
    end
    self:_syncScrollbar()
end

function Window:ToggleMinimize()
    if self.Destroyed then return end
    self.IsDragging = false
    self.IsResizing = false
    self.IsScrolling = false
    self:ReleaseInteraction("WindowDrag")
    self:ReleaseInteraction("WindowResize")
    self:ReleaseInteraction("WindowScroll")
    self.Minimized = not self.Minimized

    if self.OpenDropdown and self.OpenDropdown.Close then
        self.OpenDropdown:Close()
    end
    if self.OpenColorpicker and self.OpenColorpicker.Close then
        self.OpenColorpicker:Close()
    end
    if self.OpenKeybindMenu and self.OpenKeybindMenu.CloseModeMenu then
        self.OpenKeybindMenu:CloseModeMenu()
    end
    if self.CapturingKeybind and self.CapturingKeybind.CancelCapture then
        self.CapturingKeybind:CancelCapture()
    end
    if self.FocusedInput and self.FocusedInput.Blur then
        self.FocusedInput:Blur(false)
    end

    local isShown = (not self.Minimized) and self.Visible
    if self.FrameBg then
        self.FrameBg.Visible = self.Visible
        self.FrameBg.Size = Vector2.new(self.Size.X, self.Minimized and self.HeaderHeight or self.Size.Y)
    end
    if self.BgImage then
        self.BgImage.Visible = isShown and (self.BgImageUrl ~= nil)
        self.BgImage.Size = Vector2.new(self.Size.X, self.Minimized and self.HeaderHeight or self.Size.Y)
    end
    if self.Border then
        self.Border.Visible = self.Visible
        self.Border.Size = Vector2.new(self.Size.X, self.Minimized and self.HeaderHeight or self.Size.Y)
    end
    if self.MainPanelBg then self.MainPanelBg.Visible = isShown end
    if self.BottomDragPill then self.BottomDragPill.Visible = isShown end
    if self.ResizeIcon then self.ResizeIcon.Visible = isShown and self.CanResize end

    if self.Sidebar then
        self.Sidebar:SetVisible(isShown)
    end

    if self.ActiveTab then
        if not isShown then
            self.ActiveTab:Hide()
        else
            self.ActiveTab:Show(self.Position)
        end
    end

    -- Preserve fullscreen dimensions when unminimizing from a maximized state!
    self:SetPosition(self.Position)
    if not self.Minimized then
        self:SetSize(self.Size, self.IsMaximized)
    end
    self:_updateInputBlock()

    return self.Minimized
end
Window.Minimize = Window.ToggleMinimize
Window.Minimise = Window.ToggleMinimize

function Window:ToggleMaximize()
    if self.Destroyed then return end
    self.IsDragging = false
    self.IsResizing = false
    self:ReleaseInteraction("WindowDrag")
    self:ReleaseInteraction("WindowResize")
    local vp = get_viewport()
    if not self.IsMaximized then
        self.PreMaximizeSize = self.Size
        self.PreMaximizePos = self.Position
        self.PreMaximizeResizable = self.CanResize
        self.IsMaximized = true
        self.CanResize = false
        if self.DragModule and self.DragModule.Set then
            self.DragModule:Set(false)
        end
        if self.Minimized then
            self.Minimized = false
        end
        local targetW = math.max(self.MinSize.X, vp.X - 24)
        local targetH = math.max(self.MinSize.Y, vp.Y - 64)
        self:SetSize(Vector2.new(targetW, targetH), true)
        self:SetPosition(Vector2.new(12, 46))
    else
        self.IsMaximized = false
        self.CanResize = self.PreMaximizeResizable ~= false
        if self.DragModule and self.DragModule.Set then
            self.DragModule:Set(true)
        end
        if self.Minimized then
            self.Minimized = false
        end
        local prevSize = self.PreMaximizeSize or Vector2.new(620, 440)
        local prevPos = self.PreMaximizePos or self.Position
        self:SetPosition(prevPos)
        self:SetSize(prevSize)
    end

    if not self.Minimized then
        self:SetVisible(self.Visible)
    end
    return self.IsMaximized
end
Window.ToggleFullscreen = Window.ToggleMaximize

function Window:SetVisible(visible)
    if self.Destroyed then return end
    local prevVisible = self.Visible
    self.Visible = visible

    if not visible then
        if self.OpenDropdown and self.OpenDropdown.Close then self.OpenDropdown:Close() end
        if self.OpenColorpicker and self.OpenColorpicker.Close then self.OpenColorpicker:Close() end
        if self.OpenKeybindMenu and self.OpenKeybindMenu.CloseModeMenu then self.OpenKeybindMenu:CloseModeMenu() end
        if self.CapturingKeybind and self.CapturingKeybind.CancelCapture then self.CapturingKeybind:CancelCapture() end
        if self.FocusedInput and self.FocusedInput.Blur then self.FocusedInput:Blur(false) end
    end

    local dis = self.DisabledTopbarButtons or {}
    local bodyVis = visible and not self.Minimized
    if self.FrameBg then self.FrameBg.Visible = visible end
    if self.BgImage then self.BgImage.Visible = bodyVis and (self.BgImageUrl ~= nil) end
    if self.Border then self.Border.Visible = visible end
    if self.MainPanelBg then self.MainPanelBg.Visible = bodyVis end
    if self.MacClose then self.MacClose.Visible = visible and not dis.Close end
    if self.MacMin then self.MacMin.Visible = visible and not dis.Minimize end
    if self.MacMax then self.MacMax.Visible = visible and not dis.Maximize end
    if self.HeaderIcon then self.HeaderIcon.Visible = visible and (self.Icon ~= nil and self.Icon ~= "" and self.Icon ~= false) end
    if self.TitleText then self.TitleText.Visible = visible end
    if self.BottomDragPill then self.BottomDragPill.Visible = bodyVis end
    if self.ResizeIcon then self.ResizeIcon.Visible = bodyVis and self.CanResize end

    self:_syncTagPositions()

    if self.Sidebar then
        self.Sidebar:SetVisible(bodyVis)
    end

    if self.ActiveTab then
        if bodyVis then
            self.ActiveTab:Show(self.Position)
        else
            self.ActiveTab:Hide()
        end
    end

    self:_syncScrollbar()
    self:_updateInputBlock()

    if visible and not prevVisible then
        for _, cb in ipairs(self._onOpenCallbacks or {}) do pcall(cb) end
    elseif not visible and prevVisible then
        for _, cb in ipairs(self._onCloseCallbacks or {}) do pcall(cb) end
    end
end

function Window:Toggle()
    self:SetVisible(not self.Visible)
end

function Window:OnOpen(cb)
    if type(cb) == "function" then table.insert(self._onOpenCallbacks, cb) end
end

function Window:OnClose(cb)
    if type(cb) == "function" then table.insert(self._onCloseCallbacks, cb) end
end

function Window:OnDestroy(cb)
    if type(cb) == "function" then table.insert(self._onDestroyCallbacks, cb) end
end

function Window:_refreshTitleText()
    if not self.TitleText then return end
    local maxTitleW = math.max(60, self.Size.X - 180)
    local fullTitle = (self.Subtitle and self.Subtitle ~= "" and self.Subtitle ~= "BreezeUI")
        and (self.Title .. "  |  " .. self.Subtitle)
        or tostring(self.Title)
    local fitTitle = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(fullTitle, maxTitleW, 13) or fullTitle
    self.TitleText.Text = fitTitle
    self.TitleEndOffset = (self.TitleOffset or 74) + math.floor(#fitTitle * 6.2)
    self:_syncTagPositions()
end

function Window:SetTitle(title)
    self.Title = tostring(title or "")
    self:_refreshTitleText()
end

function Window:SetAuthor(author)
    self.Subtitle = tostring(author or "")
    self:_refreshTitleText()
end

function Window:SetIconSize(sz)
    local n = math.clamp(tonumber(sz) or 16, 10, 28)
    if self.HeaderIcon then
        self.HeaderIcon.Size = Vector2.new(n, n)
    end
end

function Window:IsResizable(enabled)
    if enabled ~= nil then
        self.CanResize = enabled == true
        if self.ResizeIcon then
            self.ResizeIcon.Visible = self.Visible and not self.Minimized and self.CanResize
        end
    end
    return self.CanResize
end

function Window:SetToTheCenter()
    local vp = get_viewport()
    local cx = math.max(12, math.floor((vp.X - self.Size.X) * 0.5))
    local cy = math.max(36, math.floor((vp.Y - self.Size.Y) * 0.5))
    self:SetPosition(Vector2.new(cx, cy))
end

function Window:GetUIScale()
    return self.DPIScale or self.Scale or 1.0
end

function Window:LockAll()
    for _, tab in ipairs(self.Tabs) do
        for _, sec in ipairs(tab.Sections or {}) do
            for _, ctrl in ipairs(sec.Controls or {}) do
                if ctrl.Lock then ctrl:Lock() else ctrl.Locked = true end
            end
        end
    end
end

function Window:UnlockAll()
    for _, tab in ipairs(self.Tabs) do
        for _, sec in ipairs(tab.Sections or {}) do
            for _, ctrl in ipairs(sec.Controls or {}) do
                if ctrl.Unlock then ctrl:Unlock() else ctrl.Locked = false end
            end
        end
    end
end

function Window:GetLocked()
    local out = {}
    for _, tab in ipairs(self.Tabs) do
        for _, sec in ipairs(tab.Sections or {}) do
            for _, ctrl in ipairs(sec.Controls or {}) do
                if ctrl.Locked then table.insert(out, ctrl) end
            end
        end
    end
    return out
end

function Window:GetUnlocked()
    local out = {}
    for _, tab in ipairs(self.Tabs) do
        for _, sec in ipairs(tab.Sections or {}) do
            for _, ctrl in ipairs(sec.Controls or {}) do
                if not ctrl.Locked then table.insert(out, ctrl) end
            end
        end
    end
    return out
end

function Window:DisableTopbarButtons(btns)
    local list = type(btns) == "table" and btns or { btns }
    for _, b in ipairs(list) do
        local k = tostring(b):lower()
        if k == "close" or k == "exit" then self.DisabledTopbarButtons.Close = true
        elseif k == "min" or k == "minimize" then self.DisabledTopbarButtons.Minimize = true
        elseif k == "max" or k == "maximize" or k == "fullscreen" then self.DisabledTopbarButtons.Maximize = true end
    end
    if self.MacClose and self.DisabledTopbarButtons.Close then self.MacClose.Visible = false end
    if self.MacMin and self.DisabledTopbarButtons.Minimize then self.MacMin.Visible = false end
    if self.MacMax and self.DisabledTopbarButtons.Maximize then self.MacMax.Visible = false end
end

function Window:SetBackgroundImage(urlOrName)
    self.BgImageUrl = urlOrName
    if not urlOrName or urlOrName == "" then
        if self.BgImage then self.BgImage.Visible = false end
        return
    end
    if not self.BgImage and self.Pool then
        local img = self.Pool:Get("Image")
        img.Position = self.Position
        img.Size = Vector2.new(self.Size.X, self.Minimized and self.HeaderHeight or self.Size.Y)
        img.Transparency = 1 - (self.BgImageTransparency or 0.25)
        img.ZIndex = 1
        img.Visible = self.Visible and not self.Minimized
        self.BgImage = img
        self:_register(img)
    end
    if self.BgImage and IconsModule and IconsModule.Get then
        IconsModule.Get(urlOrName, function(png)
            if self.BgImage and png then
                self.BgImage.Data = png
                self.BgImage.Visible = self.Visible and not self.Minimized
            end
        end)
    end
end

function Window:SetBackgroundImageTransparency(alpha)
    alpha = math.clamp(tonumber(alpha) or 0, 0, 1)
    self.BgImageTransparency = alpha
    if self.BgImage then
        self.BgImage.Transparency = 1 - alpha
    end
end

function Window:SetBackgroundTransparency(alpha)
    self:SetTransparency(alpha)
end

function Window:ToggleTransparency(state)
    local isTransparent = (self.FrameTransparency or 0) > 0.05
    local target = state ~= nil and (state == true) or (not isTransparent)
    self:SetTransparency(target and 0.25 or 0)
end

function Window:SetCurrentConfig(name)
    local sm = (self.Env and self.Env.Settings)
    if sm and sm.Load then
        return sm.Load(name, self.Env)
    end
    return false
end

function Window:Popup(cfg)
    assert(DialogModule and DialogModule.Show, "Dialog subsystem not loaded!")
    return DialogModule.Show(cfg, self, "Popup")
end

function Window:Open()
    self:SetVisible(true)
end

function Window:Close()
    self:SetVisible(false)
end

function Window:_updateInputBlock(rbxFocused)
    local active = (rbxFocused ~= nil) and rbxFocused or ((type(isrbxactive) ~= "function") or (isrbxactive() == true))
    local shouldBlock = active and (self.Visible == true) and (not self.Minimized) and (not self.Destroyed) and (self.BlockRobloxInput == true)
    if shouldBlock == self._lastInputBlocked then return end
    setrobloxinput(not shouldBlock)
    -- Matcha requires a click after toggling setrobloxinput so the Roblox window updates input lock (Obsidian pattern)
    if active then
        task.spawn(function()
            task.wait(0.1)
            mouse1click()
        end)
    end
    self._lastInputBlocked = shouldBlock
end

function Window:SetInputBlocking(enabled)
    self.BlockRobloxInput = (enabled == true)
    self:_updateInputBlock()
end

function Window:EditOpenButton(cfg)
    if type(cfg) ~= "table" then return end
    local ob = self.OpenButton
    if not ob then return end
    if cfg.Enabled ~= nil then ob.Enabled = cfg.Enabled == true end
    if cfg.Title ~= nil then ob.Title = tostring(cfg.Title) end
    if cfg.Icon ~= nil then
        ob.Icon = cfg.Icon
        ob._lastIconName = nil
    end
    if cfg.Draggable ~= nil then ob.Draggable = cfg.Draggable == true end
    if cfg.OnlyIcon ~= nil then ob.OnlyIcon = cfg.OnlyIcon == true end
    if cfg.Position ~= nil then ob.Position = cfg.Position end
    if cfg.Color ~= nil then ob.Color = cfg.Color end
end

function Window:SetWatermark(text)
    if type(text) == "table" then
        self.Watermark.Tokens = text
        self.Watermark.Text = table.concat(text, " | ")
    else
        self.Watermark.Tokens = nil
        self.Watermark.Text = tostring(text or "")
    end
    self.Watermark.Visible = self.Watermark.Text ~= ""
end

function Window:SetWatermarkVisibility(visible)
    self.Watermark.Visible = visible == true
end

function Window:SetKeybindMenuVisible(state)
    self.ShowKeybindMenu = state == true
end

function Window:SetKeybindMenuPosition(x, y)
    self.KeybindMenuX = x
    self.KeybindMenuY = y
end

function Window:SetKeybindMenuWidth(w)
    self.KeybindMenuWidth = tonumber(w) or 240
end

-- Public theme setter: accepts a theme name string or palette table.
-- Calls ThemeModule.SetCurrent so all subscribers see the change, then propagates visuals.
function Window:SetTheme(nameOrPalette)
    if ThemeModule and ThemeModule.SetCurrent then
        ThemeModule.SetCurrent(nameOrPalette)
    end
    local resolved = (type(nameOrPalette) == "table" and nameOrPalette)
        or (ThemeModule and ThemeModule.GetTheme and ThemeModule.GetTheme(nameOrPalette))
        or {}
    self:UpdateTheme(resolved)
end

-- DPI scale: scales window size proportionally (80–200 %).
function Window:SetDPIScale(pct)
    local scale = math.clamp((tonumber(pct) or 100) / 100, 0.5, 2.0)
    self.DPIScale = scale
    self:SetScale(scale)
end

-- Window-level transparency (0 = fully opaque, 1 = fully transparent; Drawing Transparency = opacity = 1 - alpha).
function Window:SetTransparency(alpha)
    alpha = math.clamp(tonumber(alpha) or 0, 0, 1)
    self.FrameTransparency = alpha
    local opacity = 1 - alpha
    if self.FrameBg then self.FrameBg.Transparency = opacity end
    if self.MainPanelBg then self.MainPanelBg.Transparency = opacity end
end

-- Corner radius override for the main frame and panel.
function Window:SetCornerRadius(r)
    r = math.clamp(math.floor(tonumber(r) or 10), 0, 32)
    self.CornerRadius = r
    if self.FrameBg then self.FrameBg.Corner = r end
    if self.Border then self.Border.Corner = r end
    if self.MainPanelBg then self.MainPanelBg.Corner = r end
    if self.ActiveTab then
        self.ActiveTab._layoutDirty = true
    end
end

function Window:UpdateTheme(newTheme)
    local t = type(newTheme) == "table" and newTheme
        or (ThemeModule and ThemeModule.GetTheme and ThemeModule.GetTheme(newTheme))
        or (ThemeModule and ThemeModule.DefaultPalette)
        or {}

    self.Theme = type(newTheme) == "table" and (newTheme.Name or "Custom") or tostring(newTheme)
    self.ThemeTokens = t

    if IconsModule and IconsModule.SetDarkMode then
        IconsModule.SetDarkMode(self.Theme == "Light")
    end

    local bgCol = t.Background or get_theme_color("Window.Background", Color3.fromRGB(16, 16, 18))
    local borderCol = t.Border or get_theme_color("Window.Border", Color3.fromRGB(36, 36, 42))
    local panelCol = t.PanelBackground or get_theme_color("PanelBackground", Color3.fromRGB(22, 22, 26))
    local textCol = t.Text or get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))

    if self.FrameBg then self.FrameBg.Color = bgCol end
    if self.Border then self.Border.Color = borderCol end
    if self.MainPanelBg then self.MainPanelBg.Color = panelCol end
    if self.TitleText then self.TitleText.Color = textCol end
    if self.SubtitleText then
        self.SubtitleText.Color = t["Text.Secondary"] or t.SubText or get_theme_color("Text.Secondary", Color3.fromRGB(161, 161, 170))
    end
    if self.VerticalDivider then
        self.VerticalDivider.Color = t["Sidebar.Divider"] or t.Divider or borderCol
    end
    if self.TopbarDivider then
        self.TopbarDivider.Color = t["Sidebar.Divider"] or t.Divider or borderCol
    end
    if self.ScrollTrack then
        self.ScrollTrack.Color = t["Control.Background"] or get_theme_color("Control.Background", Color3.fromRGB(48, 48, 52))
    end
    if self.ScrollThumb then
        self.ScrollThumb.Color = t["Text.Muted"] or t.Border or get_theme_color("Text.Muted", Color3.fromRGB(161, 161, 161))
    end
    if self.BottomDragPill then
        self.BottomDragPill.Color = t["Control.Hover"] or t.Border or get_theme_color("Control.Hover", Color3.fromRGB(80, 82, 92))
    end

    for _, tag in ipairs(self.Tags or {}) do
        if not tag.CustomColor then
            local isLight = (self.Theme == "Light")
            if tag.Bg then
                tag.Bg.Color = isLight and Color3.fromRGB(52, 52, 58)
                    or (t["Control.Background"] or get_theme_color("Control.Background", Color3.fromRGB(48, 48, 52)))
            end
            if tag.Border then
                tag.Border.Color = isLight and Color3.fromRGB(72, 72, 80) or borderCol
            end
            if tag.Text then
                tag.Text.Color = isLight and Color3.fromRGB(245, 245, 250) or textCol
            end
        end
    end

    if self.Sidebar then
        self.Sidebar:UpdateTheme(t)
    end

    for _, tab in ipairs(self.Tabs) do
        if tab.UpdateTheme then
            tab:UpdateTheme(t)
        end
    end
end

function Window:SetScale(scale)
    scale = math.clamp(tonumber(scale) or 1, 0.5, 2.0)
    self.Scale = scale
    local base = self.BaseSize or self.Size
    self._applyingScale = true
    self:SetSize(Vector2.new(math.floor(base.X * scale + 0.5), math.floor(base.Y * scale + 0.5)))
    self._applyingScale = false
end

function Window:SetUIScale(scale)
    self:SetScale(scale)
end

function Window:SetToggleKey(key)
    if type(key) == "string" and MetricsModule and MetricsModule.KeyCode then
        self.ToggleKey = MetricsModule.KeyCode(key)
    else
        self.ToggleKey = key
    end
end

function Window:SetPanelBackground(enabled)
    if self.MainPanelBg then
        self.MainPanelBg.Visible = enabled ~= false and self.Visible and not self.Minimized
    end
end

function Window:Dialog(cfg)
    assert(DialogModule and DialogModule.Show, "Dialog subsystem not loaded!")
    return DialogModule.Show(cfg, self, "Dialog")
end

function Window:Tag(tagConfig)
    local cfg = type(tagConfig) == "table" and tagConfig or { Title = tostring(tagConfig or "") }
    local pool = self.Pool
    if not pool then return cfg end
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    local px = self.Position.X
    local py = self.Position.Y
    local sx = self.Size.X

    local tagTitle = tostring(cfg.Title or "Tag")
    local hasIcon = cfg.Icon ~= nil and cfg.Icon ~= ""
    local tagW = math.floor(#tagTitle * 6.2) + (hasIcon and 30 or 16)
    local tagH = 22
    local relX = math.min((self.TitleEndOffset or 220) + 12, sx - tagW - 14)
    local relY = 11
    local tagX = px + relX
    local tagY = py + relY

    local isLight = (self.Theme == "Light")
    local tagBgCol = cfg.Color or (isLight and Color3.fromRGB(52, 52, 58) or get_theme_color("Control.Background", Color3.fromRGB(48, 48, 52)))
    local bg = pool:Get("Square")
    bg.Position = Vector2.new(tagX, tagY)
    bg.Size = Vector2.new(tagW, tagH)
    bg.Color = tagBgCol
    bg.Filled = true
    bg.Corner = 11
    bg.ZIndex = 4
    bg.Visible = self.Visible
    self:_register(bg)

    local border = nil
    if cfg.Border ~= false then
        border = pool:Get("Square")
        border.Position = Vector2.new(tagX, tagY)
        border.Size = Vector2.new(tagW, tagH)
        border.Color = isLight and Color3.fromRGB(72, 72, 80) or get_theme_color("Window.Border", Color3.fromRGB(48, 48, 56))
        border.Filled = false
        border.Thickness = 1
        border.Corner = 11
        border.ZIndex = 5
        border.Visible = self.Visible
        self:_register(border)
    end

    local txt = pool:Get("Text")
    txt.Position = Vector2.new(tagX + (hasIcon and 24 or 8), tagY + 4)
    txt.Text = tagTitle
    txt.Font = fontUI
    txt.Outline = false
    txt.Size = 12
    txt.Color = isLight and Color3.fromRGB(245, 245, 250) or get_theme_color("Text.Title", Color3.fromRGB(240, 240, 245))
    txt.ZIndex = 6
    txt.Visible = self.Visible
    self:_register(txt)

    local ico = nil
    if hasIcon then
        ico = pool:Get("Image")
        ico.Position = Vector2.new(tagX + 7, tagY + 4)
        ico.Size = Vector2.new(13, 13)
        ico.ZIndex = 6
        ico.Transparency = 0.9
        ico.Visible = self.Visible
        self:_register(ico)
        if IconsModule and IconsModule.Get then
            IconsModule.Get(cfg.Icon, function(pngData)
                if ico and pngData then ico.Data = pngData end
            end)
        end
    end

    table.insert(self.Tags, {
        RelX = relX,
        RelY = relY,
        Width = tagW,
        Bg = bg,
        Border = border,
        Icon = ico,
        Text = txt,
    })

    return cfg
end

-- ============================================================================
-- Interaction Focus Gate & Clamping
-- ============================================================================

function Window:ClaimInteraction(widgetId)
    if self.FocusedWidget == nil or self.FocusedWidget == widgetId then
        self.FocusedWidget = widgetId
        self.ActiveInteraction = widgetId
        if self.Env and self.Env.ClaimInteraction then
            self.Env:ClaimInteraction(widgetId)
        end
        return true
    end
    return false
end

function Window:ReleaseInteraction(widgetId)
    if self.FocusedWidget == widgetId then
        self.FocusedWidget = nil
        self.ActiveInteraction = nil
        if self.Env and self.Env.ReleaseInteraction then
            self.Env:ReleaseInteraction(widgetId)
        end
    end
end

function Window:CanInteract(widgetId)
    return self.FocusedWidget == nil or self.FocusedWidget == widgetId
end

function Window:ClampAndSnap(pos, size, customViewport, customInsetTop)
    local curSize = size or self.Size
    local vp = customViewport or get_viewport()
    if not vp or vp.X <= 0 or vp.Y <= 0 then
        vp = Vector2.new(1920, 1080)
    end

    local topInsetY = customInsetTop or 36
    local minX = 0
    local maxX = math.max(0, vp.X - curSize.X)
    local minY = topInsetY
    local maxY = math.max(topInsetY, vp.Y - curSize.Y)

    local x = math.clamp(pos.X, minX, maxX)
    local y = math.clamp(pos.Y, minY, maxY)

    local snapThreshold = 16
    if math.abs(x - minX) <= snapThreshold then x = minX end
    if math.abs(x - maxX) <= snapThreshold then x = maxX end
    if math.abs(y - minY) <= snapThreshold then y = minY end
    if math.abs(y - maxY) <= snapThreshold then y = maxY end

    return Vector2.new(x, y)
end

-- ============================================================================
-- Runtime Update, Keyboard Capture, Animations & Destruction
-- ============================================================================

function Window:_getMouse()
    if self.Mouse then return self.Mouse end
    if not self._playersChecked and game and game.GetService then
        self._playersChecked = true
        local ok, players = pcall(game.GetService, game, "Players")
        if ok and players and players.LocalPlayer then
            self.Mouse = players.LocalPlayer:GetMouse()
            if self.Mouse then return self.Mouse end
        end
    end
    if type(getmouseposition) == "function" then
        return getmouseposition()
    end
    return nil
end

function Window:Update(rawDt)
    if self.Destroyed or not self.Running then return end
    local curState = UI.GetValue(UI_STATE_KEY)
    if curState == UI_STATE_UNLOAD or (self._uiStateToken and curState ~= self._uiStateToken) then
        self:Destroy()
        return
    end

    local rbxFocused = (type(isrbxactive) ~= "function") or (isrbxactive() == true)
    local dt = rawDt or 0.016
    if not rbxFocused then
        self._idleDt = (self._idleDt or 0) + dt
        if self._idleDt < (1 / 15) then return end
        dt = self._idleDt
        self._idleDt = 0
    else
        self._idleDt = 0
    end

    if AnimationsModule and AnimationsModule.Step then
        AnimationsModule.Step(dt)
    end

    local m1Pressed = rbxFocused and (type(ismouse1pressed) == "function") and (ismouse1pressed() == true)
    local m2Pressed = rbxFocused and (type(ismouse2pressed) == "function") and (ismouse2pressed() == true)
    local m1Clicked = m1Pressed and not self.PrevM1
    local m2Clicked = m2Pressed and not (self.PrevM2 == true)
    self.PrevM1 = m1Pressed
    self.PrevM2 = m2Pressed

    local mouse = self:_getMouse()
    if NotifyModule and NotifyModule.Update then
        if NotifyModule.Update(dt, self, mouse, m1Clicked) then
            m1Clicked = false
        end
    end

    if DialogModule and DialogModule.Update then
        if DialogModule.Update(dt, self, mouse, m1Clicked) then
            return
        end
    end

    if OverlayModule and OverlayModule.Update then
        if OverlayModule.Update(dt, self, mouse, m1Pressed, m1Clicked) then
            m1Clicked = false
        end
    end

    self:_updateInputBlock(rbxFocused)

    -- ToggleKey visibility / minimize hotkey (only when Roblox is focused)
    if rbxFocused and self.ToggleKey and self.Input and type(self.ToggleKey) == "number" then
        if self.Input:KeyPressed(self.ToggleKey) then
            if self.ToggleKeyMinimizes then
                if not self.Visible then
                    self:SetVisible(true)
                else
                    self:ToggleMinimize()
                end
            else
                self:SetVisible(not self.Visible)
            end
        end
    end

    if not self.Visible then return end

    if self.ActiveTab and self.ActiveTab._layoutDirty and self.ActiveTab.UpdateLayout then
        self.ActiveTab._layoutDirty = false
        self.ActiveTab:UpdateLayout(self.Position, self.Size)
    end

    -- Keybind capture mode or active Keybind listener
    if self.CapturingKeybind and self.Input then
        local elapsed = os.clock() - (self.CapturingKeybind.CaptureStarted or 0)
        -- Hold M1 for >= 1s while capturing clears the keybind back to nil ([?]), matching Obsidian
        if m1Pressed and elapsed >= 1.0 then
            self.CapturingKeybind:Clear()
            return
        end
        local captured = self.Input:ReadListenKey(m1Clicked, m2Clicked, elapsed)
        if captured then
            self.CapturingKeybind:ProcessInput(captured)
        end
        return
    elseif rbxFocused and self.Input and not self.FocusedDropdownSearch and not (self.Sidebar and self.Sidebar.SearchFocused) and not self.FocusedInput then
        for _, kb in ipairs(self.Keybinds or {}) do
            if not kb.Locked and type(kb.Key) == "number" then
                if kb.Mode == "Always" then
                    kb.ActiveState = true
                elseif kb.Mode == "Hold" then
                    local held = (type(iskeypressed) == "function") and (iskeypressed(kb.Key) == true)
                    if held ~= kb.ActiveState then
                        kb.ActiveState = held
                        if kb.Parent and kb.SyncToggleState and kb.Parent.Set then
                            kb.Parent:Set(held)
                        end
                        pcall(kb.Callback, held)
                    end
                elseif self.Input:KeyPressed(kb.Key) then
                    kb.ActiveState = not kb.ActiveState
                    if kb.Parent and kb.SyncToggleState and kb.Parent.Set then
                        kb.Parent:Set(kb.ActiveState)
                    end
                    pcall(kb.Callback, kb.ActiveState)
                end
            end
        end
    end

    -- Keyboard typing into Dropdown Search, Sidebar Search, or focused Input control
    if self.FocusedDropdownSearch then
        if self.FocusedDropdownSearch.RefreshSearchDisplay then
            self.FocusedDropdownSearch:RefreshSearchDisplay()
        end
        if self.Input then
            local token = self.Input:ReadTextInput()
            if token and self.FocusedDropdownSearch then
                self.FocusedDropdownSearch:ProcessSearchKey(token)
            end
        end
    elseif self.Sidebar and self.Sidebar.SearchFocused then
        if self.Input then
            local token = self.Input:ReadTextInput()
            if token then self.Sidebar:ProcessSearchKey(token) end
        end
        self.Sidebar:RefreshSearchDisplay()
    elseif self.FocusedInput then
        if self.Input then
            local token = self.Input:ReadTextInput()
            if token and self.FocusedInput then
                self.FocusedInput:ProcessKey(token)
            end
        end
        if self.FocusedInput then
            self.FocusedInput:_refreshDisplay()
        end
    end

    if not mouse then return end
    local mx = mouse.X
    local my = mouse.Y

    local px = self.Position.X
    local py = self.Position.Y
    local sx = self.Size.X
    local sy = self.Minimized and self.HeaderHeight or self.Size.Y

    -- 1. macOS Traffic Lights Hit-Tests
    local dis = self.DisabledTopbarButtons or {}
    local closeHover = (not dis.Close) and mx >= px + 14 and mx <= px + 29 and my >= py + 14 and my <= py + 29
    if closeHover then
        if self.MacClose then self.MacClose.Color = Color3.fromRGB(230, 75, 68) end
        if m1Clicked then
            if not self.IgnoreAlerts and DialogModule and DialogModule.Show then
                self:Dialog({
                    Title = "Close Window",
                    Content = "Do you want to close this window? You will not be able to open it again.",
                    Buttons = {
                        {
                            Title = "Cancel",
                            Variant = "Secondary",
                            Callback = function() end,
                        },
                        {
                            Title = "Close Window",
                            Variant = "Primary",
                            Callback = function()
                                self:Destroy()
                            end,
                        },
                    },
                })
            else
                self:Destroy()
            end
            return
        end
    else
        if self.MacClose then self.MacClose.Color = get_theme_color("Mac.Close", Color3.fromRGB(255, 95, 86)) end
    end

    local minHover = (not dis.Minimize) and mx >= px + 32 and mx <= px + 47 and my >= py + 14 and my <= py + 29
    if minHover then
        if self.MacMin then self.MacMin.Color = Color3.fromRGB(230, 165, 30) end
        if m1Clicked then
            self:ToggleMinimize()
            return
        end
    else
        if self.MacMin then self.MacMin.Color = get_theme_color("Mac.Minimize", Color3.fromRGB(255, 189, 46)) end
    end

    local maxHover = (not dis.Maximize) and mx >= px + 50 and mx <= px + 65 and my >= py + 14 and my <= py + 29
    if maxHover then
        if self.MacMax then self.MacMax.Color = Color3.fromRGB(28, 175, 50) end
        if m1Clicked then
            self:ToggleMaximize()
            return
        end
    else
        if self.MacMax then self.MacMax.Color = get_theme_color("Mac.Maximize", Color3.fromRGB(39, 201, 63)) end
    end

    -- 2. Bottom-Right Corner Resize Icon & Hit-Test (strictly disabled in Fullscreen & Minimized)
    local canResizeNow = (not self.Minimized) and (not self.IsMaximized) and (self.CanResize == true)
    local rx = px + sx - 18
    local ry = py + sy - 18
    local isResizeArea = canResizeNow and mx >= rx and mx <= px + sx + 16 and my >= ry and my <= py + sy + 16

    if self.ResizeIcon and not self.Minimized then
        self.ResizeIcon.Transparency = (isResizeArea or self.IsResizing) and 0.78 or 0.25
    end

    if self.IsResizing then
        if m1Pressed and canResizeNow then
            local delta = Vector2.new(mx - self.ResizeStartMouse.X, my - self.ResizeStartMouse.Y)
            local targetSize = Vector2.new(self.ResizeStartSize.X + delta.X, self.ResizeStartSize.Y + delta.Y)
            self:SetSize(targetSize)
        else
            self.IsResizing = false
            self:ReleaseInteraction("WindowResize")
        end
    elseif m1Clicked and isResizeArea and canResizeNow and self:CanInteract("WindowResize") then
        self.IsResizing = true
        self.ResizeStartMouse = Vector2.new(mx, my)
        self.ResizeStartSize = self.Size
        self:ClaimInteraction("WindowResize")
    end

    -- 2b. Scrollbar Thumb Dragging & Track Jump (dedicated 8px pill track)
    if self.ScrollThumb and self.ActiveTab and (self.ActiveTab.MaxScrollY or 0) > 0 and not self.Minimized then
        local trackTop = py + self.HeaderHeight + 10
        local trackH = math.max(40, sy - self.HeaderHeight - 28)
        local thumbH = self.ScrollThumb.Size.Y
        local thumbY = self.ScrollThumb.Position.Y
        local inGutter = mx >= px + sx - 26 and mx <= px + sx - 10
        local overThumb = inGutter and my >= thumbY - 4 and my <= thumbY + thumbH + 4
        local overTrack = inGutter and my >= trackTop and my <= trackTop + trackH
        self.ScrollThumb.Transparency = (overThumb or overTrack or self.IsScrolling) and 0.85 or 0.28

        if self.IsScrolling then
            if m1Pressed then
                local travel = math.max(1, trackH - thumbH)
                local ratio = math.clamp((my - (self.ScrollDragOffset or 0) - trackTop) / travel, 0, 1)
                self.ActiveTab.ScrollY = math.floor(ratio * self.ActiveTab.MaxScrollY + 0.5)
                self.ActiveTab:UpdateLayout(self.Position, self.Size)
                self:_syncScrollbar()
                return
            else
                self.IsScrolling = false
                self:ReleaseInteraction("WindowScroll")
            end
        elseif m1Clicked and (overThumb or overTrack) and not isResizeArea and self:CanInteract("WindowScroll") then
            self.IsScrolling = true
            if overThumb then
                self.ScrollDragOffset = my - thumbY
            else
                self.ScrollDragOffset = math.floor(thumbH * 0.5)
                local travel = math.max(1, trackH - thumbH)
                local ratio = math.clamp((my - self.ScrollDragOffset - trackTop) / travel, 0, 1)
                self.ActiveTab.ScrollY = math.floor(ratio * self.ActiveTab.MaxScrollY + 0.5)
                self.ActiveTab:UpdateLayout(self.Position, self.Size)
                self:_syncScrollbar()
            end
            self:ClaimInteraction("WindowScroll")
            return
        end
    elseif self.IsScrolling then
        self.IsScrolling = false
        self:ReleaseInteraction("WindowScroll")
    end

    -- 3. Window Dragging (WindUI 1:1: Topbar OR Bottom Drag Pill; disabled in Fullscreen via DragModule:Set(false))
    local canDragNow = (self.Draggable ~= false) and (not self.DragModule or self.DragModule.CanDraggable ~= false)
    local pillX = px + math.floor((sx - 168) * 0.5)
    local isBottomPill = canDragNow and (not self.Minimized) and mx >= pillX - 6 and mx <= pillX + 174 and my >= py + sy and my <= py + sy + 16
    local isHeader = canDragNow and mx >= px + 70 and mx <= px + sx - 10 and my >= py and my <= py + self.HeaderHeight

    if self.BottomDragPill and not self.Minimized then
        self.BottomDragPill.Transparency = (isBottomPill or self.IsDragging) and 0.72 or 0.25
    end

    if self.IsDragging then
        if m1Pressed and canDragNow then
            local dx = mx - self.DragStart.X
            local dy = my - self.DragStart.Y
            if math.abs(dx) > 3 or math.abs(dy) > 3 then
                self.LastPillClick = -10
            end
            local newPos = self:ClampAndSnap(
                Vector2.new(self.DragStartPos.X + dx, self.DragStartPos.Y + dy),
                Vector2.new(self.Size.X, sy)
            )
            self:SetPosition(newPos)
        else
            self.IsDragging = false
            self:ReleaseInteraction("WindowDrag")
        end
    elseif m1Clicked and (isHeader or isBottomPill) and not isResizeArea and self:CanInteract("WindowDrag") then
        if isBottomPill then
            local now = os.clock()
            if (now - self.LastPillClick) < 0.4 then
                self:SetToTheCenter()
                self.LastPillClick = -10
                return
            end
            self.LastPillClick = now
        end

        self.IsDragging = true
        self.DragStart = Vector2.new(mx, my)
        self.DragStartPos = self.Position
        self:ClaimInteraction("WindowDrag")
    end

    if self.Minimized then return end

    -- 4. Open Colorpicker, Dropdown & Keybind Mode Menu Priority Capture
    if self.OpenKeybindMenu and self.OpenKeybindMenu.ModeMenuOpen then
        if self.OpenKeybindMenu:UpdateModeMenu(mx, my, m1Clicked, m2Clicked) then
            return
        end
    end

    if self.OpenColorpicker and self.OpenColorpicker.IsOpen then
        if self.OpenColorpicker:UpdatePopupInput(mx, my, m1Pressed, m1Clicked) then
            return
        end
    end

    if self.OpenDropdown and self.OpenDropdown.Opened and self.OpenDropdown.PopupRect then
        local dd = self.OpenDropdown
        local r = dd.PopupRect
        local st = r.ScrollTrack
        local overScroll = st and mx >= st.X and mx <= st.X + st.W and my >= st.Y and my <= st.Y + st.H
        if dd.PopupScrollThumb then
            dd.PopupScrollThumb.Transparency = (overScroll or dd.IsScrollingPopup) and 0.85 or 0.28
        end
        if dd.IsScrollingPopup then
            if m1Pressed and st then
                local travel = math.max(1, st.H - st.ThumbH)
                local ratio = math.clamp((my - st.Y - st.ThumbH * 0.5) / travel, 0, 1)
                dd:SetScrollRatio(ratio)
                return
            else
                dd.IsScrollingPopup = false
            end
        end
        local overPopup = mx >= r.X and mx <= r.X + r.W and my >= r.Y and my <= r.Y + r.H
        if overPopup then
            if st and mx >= st.X and mx <= st.X + st.W and my >= st.Y and my <= st.Y + st.H then
                dd:SetPopupHover(nil)
                if m1Clicked then
                    dd.IsScrollingPopup = true
                    local travel = math.max(1, st.H - st.ThumbH)
                    local ratio = math.clamp((my - st.Y - st.ThumbH * 0.5) / travel, 0, 1)
                    dd:SetScrollRatio(ratio)
                    return
                end
            end
            local sr = r.SearchRect
            if sr and mx >= sr.X and mx <= sr.X + sr.W and my >= sr.Y and my <= sr.Y + sr.H then
                dd:SetPopupHover(nil)
                if m1Clicked then
                    self.FocusedDropdownSearch = dd
                    if dd.RefreshSearchDisplay then dd:RefreshSearchDisplay() end
                    return
                end
            else
                local listTop = r.ListTop or (r.Y + 4)
                local idx = math.floor((my - listTop) / r.ItemH) + 1
                if idx >= 1 and idx <= r.Count then
                    dd:SetPopupHover(idx)
                    if m1Clicked then
                        local realIdx = (dd.ScrollOffset or 0) + idx
                        local chosen = dd.VisibleItems and dd.VisibleItems[realIdx] or dd.Values[realIdx]
                        if chosen then dd:Select(chosen) end
                        return
                    end
                else
                    dd:SetPopupHover(nil)
                end
            end
        else
            dd:SetPopupHover(nil)
            if m1Clicked then
                dd:Close()
            end
        end
    end

    -- 5. Sidebar Search, ProfileCard & Navigation
    if self.Sidebar and self.Sidebar.Visible then
        local sb = self.Sidebar
        if sb.ProfileCard and sb.ProfileCard:Update(mx, my, m1Clicked, dt) then
            return
        end
        local sbx, sby = px + 10, py + 46
        local sbw, sbh = self.SidebarWidth - 20, 28
        local overSearch = mx >= sbx and mx <= sbx + sbw and my >= sby and my <= sby + sbh
        if m1Clicked then
            if overSearch then
                sb:FocusSearch()
            elseif sb.SearchFocused then
                sb:BlurSearch()
            end
        end

        for _, sec in ipairs(sb.Sections or {}) do
            if sec.Visible then
                local hx = px + sec.RelX
                local hy = py + sec.RelY
                local hw = self.SidebarWidth - 20
                local hh = sec.HeaderHeight or 26
                if mx >= hx and mx <= hx + hw and my >= hy and my <= hy + hh then
                    if m1Clicked then
                        sec:Toggle()
                    end
                end
            end
        end

        for _, tab in ipairs(sb.Tabs or {}) do
            if tab.SidebarVisible and (not tab.ParentSection or tab.ParentSection.Opened or sb.SearchQuery ~= "") then
                local tx = px + tab.RelX
                local ty = py + tab.RelY
                local tw = tab.Width or (self.SidebarWidth - 20)
                local th = tab.Height or 32
                local hovered = mx >= tx and mx <= tx + tw and my >= ty and my <= ty + th
                tab:SetHovered(hovered)
                if hovered and m1Clicked then
                    self:SelectTab(tab)
                end
            end
        end
    end

    -- 6. Active Tab Controls, Tooltips & Blurs
    local clickedFocusedInput = false
    local hoverTip = nil
    local activeCards = self.ActiveTab and (self.ActiveTab.Sections or self.ActiveTab.Cards)
    if activeCards then
        for _, card in ipairs(activeCards) do
            if self.Destroyed or not self.Running then return end
            if card.Visible and card.HandleHeaderClick and m1Clicked then
                if card:HandleHeaderClick(mx, my) then
                    if self.Destroyed or not self.Running then return end
                    if self.ActiveTab then
                        self.ActiveTab:UpdateLayout(self.Position, self.Size)
                        self.ActiveTab._layoutDirty = false
                    end
                    self:_syncScrollbar()
                    return
                end
            end
            if card.Visible and card.Controls then
                for _, ctrl in ipairs(card.Controls) do
                    if self.Destroyed or not self.Running then return end
                    if ctrl.Visible and ctrl.Indeterminate and ctrl.Update then
                        ctrl:Update(dt or 0.016)
                    end
                    if ctrl.Visible and ctrl.Position and ctrl.Size then
                        local cx = ctrl.Position.X
                        local cy = ctrl.Position.Y
                        local cw = ctrl.Size.X
                        local ch = ctrl.Size.Y
                        local hovered = mx >= cx and mx <= cx + cw and my >= cy and my <= cy + ch

                        if hovered then
                            if ctrl.Locked then
                                hoverTip = ctrl.LockedTitle or ctrl.Tooltip or "Locked"
                            elseif ctrl.Tooltip then
                                hoverTip = ctrl.Tooltip
                            end
                        end

                        if ctrl._copiedUntil and os.clock() >= ctrl._copiedUntil then
                            ctrl._copiedUntil = nil
                            if ctrl._setCopyLabel then ctrl:_setCopyLabel("Copy") end
                        end

                        if not ctrl.Locked then
                            -- Inline KeyPicker hit-test (M1 = bind key, M2 = Toggle/Hold/Always menu)
                            if ctrl.KeyPicker then
                                local kp = ctrl.KeyPicker
                                local kpx, kpy = kp.Position.X, kp.Position.Y
                                local kpw, kph = kp.Size.X, kp.Size.Y
                                if mx >= kpx and mx <= kpx + kpw and my >= kpy and my <= kpy + kph then
                                    if m1Clicked and kp.StartCapture then
                                        kp:StartCapture()
                                        hovered = false
                                    elseif m2Clicked and kp.OpenModeMenu then
                                        kp:OpenModeMenu()
                                        hovered = false
                                    end
                                end
                            end

                            if ctrl.Track and ctrl.FillBar and ctrl.Drag then
                                local tx = ctrl.Track.Position.X
                                local tw = ctrl.Track.Size.X
                                local trackHover = mx >= tx - 8 and mx <= tx + tw + 8 and my >= cy and my <= cy + ch
                                if ctrl._dragging then
                                    if m1Pressed then
                                        local ratio = math.clamp((mx - tx) / tw, 0, 1)
                                        ctrl:Drag(ratio)
                                    else
                                        ctrl._dragging = false
                                        self:ReleaseInteraction("Slider_" .. tostring(ctrl))
                                    end
                                elseif m1Clicked and trackHover and self:CanInteract("Slider_" .. tostring(ctrl)) then
                                    ctrl._dragging = true
                                    self:ClaimInteraction("Slider_" .. tostring(ctrl))
                                    local ratio = math.clamp((mx - tx) / tw, 0, 1)
                                    ctrl:Drag(ratio)
                                end
                            elseif ctrl.InputText and ctrl.Focus then
                                if hovered and m1Clicked and self:CanInteract("Input_" .. tostring(ctrl)) then
                                    ctrl:Focus()
                                    clickedFocusedInput = true
                                elseif ctrl.Focused and hovered then
                                    clickedFocusedInput = true
                                end
                            elseif ctrl.SwitchPill and ctrl.Click then
                                if hovered and m1Clicked and self:CanInteract("Toggle_" .. tostring(ctrl)) then
                                    if ctrl.KeyPicker and ctrl.KeyPicker.Mode == "Always" then
                                        if not ctrl.Value and ctrl.Set then ctrl:Set(true) end
                                    else
                                        ctrl:Click()
                                    end
                                    if self.Destroyed or not self.Running then return end
                                    if self.ActiveTab then self.ActiveTab._layoutDirty = true end
                                end
                            elseif ctrl.Standalone and ctrl.BadgeBg and ctrl.HandleClick then
                                if hovered and m1Clicked then
                                    ctrl:HandleClick(mx, my)
                                elseif hovered and m2Clicked and ctrl.OpenModeMenu then
                                    ctrl:OpenModeMenu()
                                end
                            elseif ctrl.Visual and ctrl.HandleClick and not ctrl.SwitchPill then
                                if hovered and m1Clicked then
                                    ctrl:HandleClick(mx, my)
                                    if self.Destroyed or not self.Running then return end
                                end
                            elseif ctrl.Visual and ctrl.Click and not ctrl.SwitchPill then
                                if hovered and m1Clicked then
                                    ctrl:Click()
                                    if self.Destroyed or not self.Running then return end
                                    if self.ActiveTab then self.ActiveTab._layoutDirty = true end
                                end
                            elseif ctrl.IsOpen ~= nil and ctrl.Toggle then
                                if hovered and m1Clicked then
                                    ctrl:Toggle()
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if OverlayModule and OverlayModule.RenderTooltip then
        OverlayModule.RenderTooltip((not m1Pressed) and hoverTip or nil, mx, my, self)
    end

    if m1Clicked and self.FocusedInput and not clickedFocusedInput then
        self.FocusedInput:Blur(false)
    end
end

function Window:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self.Running = false
    self.IsDragging = false
    self.IsResizing = false
    self.FocusedWidget = nil
    self.ActiveInteraction = nil
    self.FocusedInput = nil
    self.FocusedDropdownSearch = nil
    self.OpenDropdown = nil
    self.OpenColorpicker = nil
    self.CapturingKeybind = nil
    self.Keybinds = {}
    if IconsModule and IconsModule.ClearSubscribers then
        IconsModule.ClearSubscribers()
    end
    local curState = UI.GetValue(UI_STATE_KEY)
    if curState == UI_STATE_UNLOAD or (self._uiStateToken and curState == self._uiStateToken) then
        UI.SetValue(UI_STATE_KEY, UI_STATE_EMPTY)
    end

    for _, cb in ipairs(self._onDestroyCallbacks or {}) do
        pcall(cb)
    end
    self._onDestroyCallbacks = {}
    self._onOpenCallbacks = {}
    self._onCloseCallbacks = {}

    if self.Env then
        if self.RegisteredIds then
            if self.Env.Toggles and self.RegisteredIds.Toggles then
                for togId in pairs(self.RegisteredIds.Toggles) do
                    rawset(self.Env.Toggles, togId, nil)
                    if self.Env._rawToggles then
                        self.Env._rawToggles[togId] = nil
                    end
                    if self.Env._initialDefaults and self.Env._initialDefaults.Toggles then
                        self.Env._initialDefaults.Toggles[togId] = nil
                    end
                end
            end
            if self.Env.Options and self.RegisteredIds.Options then
                for optId in pairs(self.RegisteredIds.Options) do
                    rawset(self.Env.Options, optId, nil)
                    if self.Env._rawOptions then
                        self.Env._rawOptions[optId] = nil
                    end
                    if self.Env._initialDefaults and self.Env._initialDefaults.Options then
                        self.Env._initialDefaults.Options[optId] = nil
                    end
                end
            end
        end
        if self.Env._activeWindow == self then
            self.Env._activeWindow = nil
        end
        if self.Env._windows then
            for i = #self.Env._windows, 1, -1 do
                if self.Env._windows[i] == self then
                    table.remove(self.Env._windows, i)
                end
            end
        end
    end

    if self.RenderConnection then
        self.RenderConnection:Disconnect()
        self.RenderConnection = nil
    end
    if self.ScrollConnection then
        self.ScrollConnection:Disconnect()
        self.ScrollConnection = nil
    end

    if self.Sidebar and self.Sidebar.Destroy then
        self.Sidebar:Destroy()
    end

    for _, tab in ipairs(self.Tabs or {}) do
        if tab and tab.Destroy then
            tab:Destroy()
        end
    end

    if self.Pool and self.Pool.Destroy then
        self.Pool:Destroy()
        self.Pool = nil
    end

    if (not self.Env or not self.Env._windows or #self.Env._windows == 0) then
        if AnimationsModule and AnimationsModule.Reset then AnimationsModule.Reset() end
        if NotifyModule and NotifyModule.Destroy then NotifyModule.Destroy() end
        if DialogModule and DialogModule.Destroy then DialogModule.Destroy() end
        if OverlayModule and OverlayModule.Destroy then OverlayModule.Destroy() end
    end
    if self._lastInputBlocked then
        setrobloxinput(true)
        self._lastInputBlocked = false
    end

    self.Drawings = {}
    self._drawings = {}
    self.Sections = {}
    self.Tabs = {}
    self.Cards = {}
    self.Tags = {}
    self.ActiveTab = nil
    self.Sidebar = nil
end

return Window
