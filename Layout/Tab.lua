-- Library/BreezeUI/Layout/Tab.lua
-- Child navigation tab management, colored badge squares with white PNG icons, responsive resize, clipping & scroll.

local PoolModule = Pool or require("../Core/Pool")
local MetaModule = Meta or require("../Core/Meta")
local GeometryModule = Geometry or require("../Core/Geometry")
local MetricsModule = Metrics or require("../Core/Metrics")
local ThemeModule = Theme or require("./Theme")
local ContentSectionModule = ContentSection or require("./ContentSection")
local AnimationsModule = Animations or require("../Engine/Animations")

local IconsModule = Icons or require("../Subsystems/Icons")

local Tab = {}
Tab.__index = Tab

local str_tab_active = "Tab.ActiveBg"
local str_tab_hover  = "Tab.HoverBg"
local str_txt_title  = "Text.Title"
local str_txt_sec    = "Text.Secondary"

local function get_tab_badge_color(title, icon, customColor)
    if customColor then return customColor end
    local lower = (title or ""):lower()
    local ic = (icon or ""):lower()
    if lower:find("toggle") or ic:find("check") or ic:find("toggle") then
        return Color3.fromRGB(16, 197, 80)
    elseif lower:find("button") or ic:find("cursor") or ic:find("button") then
        return Color3.fromRGB(37, 122, 247)
    elseif lower:find("input") or ic:find("edit") or ic:find("input") then
        return Color3.fromRGB(119, 117, 242)
    elseif lower:find("slider") or ic:find("slider") or ic:find("transfer") then
        return Color3.fromRGB(16, 197, 80)
    elseif lower:find("dropdown") or ic:find("menu") or ic:find("list") then
        return Color3.fromRGB(236, 162, 1)
    elseif lower:find("settings") or ic:find("gear") or ic:find("settings") then
        return Color3.fromRGB(100, 106, 128)
    else
        return Color3.fromRGB(131, 136, 158)
    end
end

function Tab.new(config, window, parentSection)
    local cfg = type(config) == "table" and config or { Title = tostring(config or "Tab") }
    local win = window or (parentSection and parentSection.Sidebar and parentSection.Sidebar.Window)
    local pool = (win and win.Pool) or PoolModule.new(100, MetaModule)
    local topH = win and win.HeaderHeight or 44

    local self = setmetatable({
        Type = "Tab",
        Title = cfg.Title or "Tab",
        Icon = cfg.Icon or "box",
        IconColor = cfg.IconColor,
        IconShape = cfg.IconShape,
        Badge = cfg.Badge,
        BadgeColor = cfg.BadgeColor,

        Window = win,
        ParentSection = parentSection,
        Pool = pool,
        Theme = win and win.Theme,

        -- State flags
        IsActive = false,
        IsHovered = false,
        HoverAnim = 0,
        SidebarVisible = true,
        FilteredOut = false,
        Visible = true,
        Destroyed = false,

        -- Geometry (relative to window)
        RelX = 10,
        RelY = 0,
        Width = (win and win.SidebarWidth or 190) - 20,
        Height = 32,
        Rounding = 8,
        ContentCursorY = topH + 14,
        ScrollY = 0,
        MaxScrollY = 0,

        -- Sidebar Drawing Primitives
        Capsule = nil,
        IconBadge = nil,
        TabIcon = nil,
        IconVisual = nil,
        TitleVisual = nil,
        BadgeBg = nil,
        BadgeText = nil,

        -- Aliases for Test Compatibility
        NavButton = nil,
        TabButton = nil,
        TabText = nil,

        -- Content & Collections
        Sections = {},
        Cards = nil,
        Controls = {},
        Drawings = {},
        _drawings = {},
    }, Tab)

    self.Cards = self.Sections
    self:_initSidebarDrawings()
    return self
end

function Tab:_initSidebarDrawings()
    local pool = self.Pool
    if not pool then return end
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    local cap = pool:Get("Square")
    MetaModule.SetValue(cap, "Filled", true)
    MetaModule.SetValue(cap, "Corner", self.Rounding)
    MetaModule.SetValue(cap, "ZIndex", 4)
    MetaModule.SetVisible(cap, false)
    self.Capsule = cap

    if self.IconShape and self.IconColor then
        local badgeCol = get_tab_badge_color(self.Title, self.Icon, self.IconColor)
        local badgeSquare = pool:Get("Square")
        badgeSquare.Size = Vector2.new(22, 22)
        badgeSquare.Corner = (self.IconShape == "Circle") and 11 or 6
        badgeSquare.Filled = true
        badgeSquare.Color = badgeCol
        badgeSquare.ZIndex = 5
        badgeSquare.Visible = false
        self.IconBadge = badgeSquare
    end

    local icon = pool:Get("Image")
    icon.Size = Vector2.new(14, 14)
    icon.Transparency = 1.0
    icon.ZIndex = 6
    icon.Visible = false
    self.TabIcon = icon
    self.IconVisual = icon

    if self.Icon then
        local forceWhite = (self.IconBadge ~= nil)
        IconsModule.Get(self.Icon, function(pngData)
            if self.TabIcon and pngData then
                self.TabIcon.Data = pngData
            end
        end, forceWhite)
    end

    local txt = pool:Get("Text")
    txt.Size = 13
    txt.Font = fontUI
    txt.Outline = false
    txt.Color = ThemeModule.Get(str_txt_sec)
    txt.ZIndex = 5
    txt.Text = tostring(self.Title)
    self.TitleVisual = txt
    self.NavButton = txt
    self.TabButton = txt
    self.TabText = txt

    if self.Badge then
        local bBg = pool:Get("Square")
        bBg.Filled = true
        bBg.Corner = 3
        bBg.Color = self.BadgeColor or ThemeModule.Get("Accent.Blue")
        bBg.ZIndex = 5
        self.BadgeBg = bBg

        local bTxt = pool:Get("Text")
        bTxt.Size = 11
        bTxt.Font = fontUI
        bTxt.Outline = false
        bTxt.Color = Color3.fromRGB(255, 255, 255)
        bTxt.ZIndex = 6
        bTxt.Text = MetricsModule.FormatBadge(self.Badge)
        self.BadgeText = bTxt
    end

    local win = self.Window
    if win and win._drawings then
        table.insert(win._drawings, self.Capsule)
        if self.IconBadge then table.insert(win._drawings, self.IconBadge) end
        table.insert(win._drawings, self.TabIcon)
        table.insert(win._drawings, self.TitleVisual)
        if self.BadgeBg then table.insert(win._drawings, self.BadgeBg) end
        if self.BadgeText then table.insert(win._drawings, self.BadgeText) end
    end
end

function Tab:UpdateVisualState()
    if not self.SidebarVisible then return end
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    if self.IsActive then
        local activeBg = ThemeModule.Get(str_tab_active)
        local titleCol = ThemeModule.Get(str_txt_title)
        if self.Capsule then
            self.Capsule.Color = activeBg
            self.Capsule.Transparency = 1.0
            self.Capsule.Visible = self.SidebarVisible ~= false
        end
        if self.TitleVisual then
            self.TitleVisual.Color = titleCol
            self.TitleVisual.Font = fontUI
            self.TitleVisual.Outline = false
        end
        if self.TabIcon then
            self.TabIcon.Transparency = 1.0
        end
    elseif self.IsHovered or (self.HoverAnim or 0) > 0.02 then
        local hoverBg = ThemeModule.Get(str_tab_hover)
        local titleCol = ThemeModule.Get(str_txt_title)
        if self.Capsule then
            self.Capsule.Color = hoverBg
            self.Capsule.Transparency = self.HoverAnim or 1.0
            self.Capsule.Visible = self.SidebarVisible ~= false
        end
        if self.TitleVisual then
            self.TitleVisual.Color = titleCol
            self.TitleVisual.Font = fontUI
            self.TitleVisual.Outline = false
        end
        if self.TabIcon then
            self.TabIcon.Transparency = 0.92
        end
    else
        local subCol = ThemeModule.Get(str_txt_sec)
        if self.Capsule then
            self.Capsule.Visible = false
        end
        if self.TitleVisual then
            self.TitleVisual.Color = subCol
            self.TitleVisual.Font = fontUI
            self.TitleVisual.Outline = false
        end
        if self.TabIcon then
            self.TabIcon.Transparency = 0.85
        end
    end
end

function Tab:SetHovered(hovered)
    if self.IsHovered ~= hovered then
        self.IsHovered = hovered
        AnimationsModule.Tween("tab_hover_" .. tostring(self), self.HoverAnim or 0, hovered and 1 or 0, 22, function(v)
            self.HoverAnim = v
            self:UpdateVisualState()
        end)
    end
end

-- IMPORTANT: Always update coordinates unconditionally even while minimized or filtered!
function Tab:UpdateSidebarPositions(winPos)
    local tx = winPos.X + self.RelX
    local ty = winPos.Y + self.RelY

    if self.Capsule then
        MetaModule.SetPosition(self.Capsule, tx, ty)
        MetaModule.SetSize(self.Capsule, self.Width, self.Height)
    end

    if self.IconBadge then
        self.IconBadge.Position = Vector2.new(tx + 6, ty + 5)
    end

    if self.TabIcon then
        MetaModule.SetPosition(self.TabIcon, tx + 10, ty + 9)
    end

    local badgeW = 0
    if self.BadgeBg and self.BadgeText then
        local bStr = tostring(self.BadgeText.Text or "")
        badgeW = math.floor(MetricsModule.Measure(bStr, 11) + 10)
        local bX = tx + self.Width - badgeW - 6
        local bY = ty + 8
        self.BadgeBg.Position = Vector2.new(bX, bY)
        self.BadgeBg.Size = Vector2.new(badgeW, 16)
        local ax, ay = MetricsModule.AlignCenter(bX, bY, badgeW, 16, bStr, 11)
        self.BadgeText.Position = Vector2.new(ax, ay)
    end

    if self.TitleVisual then
        local titleX = tx + 36
        local maxTitleW = math.max(30, self.Width - 44 - (badgeW > 0 and (badgeW + 8) or 0))
        local fitted = MetricsModule.Fit(tostring(self.Title), maxTitleW, 13)
        MetaModule.SetText(self.TitleVisual, fitted)
        MetaModule.SetPosition(self.TitleVisual, titleX, ty + 9)
    end

    if self.SidebarVisible then
        self:UpdateVisualState()
    end
end

function Tab:SetSidebarVisible(vis)
    local effective = vis and (not self.FilteredOut)
    self.SidebarVisible = effective
    if not effective then
        if self.Capsule then self.Capsule.Visible = false end
        if self.IconBadge then self.IconBadge.Visible = false end
        if self.TabIcon then self.TabIcon.Visible = false end
        if self.TitleVisual then self.TitleVisual.Visible = false end
        if self.BadgeBg then self.BadgeBg.Visible = false end
        if self.BadgeText then self.BadgeText.Visible = false end
    else
        self:UpdateVisualState()
        if self.IconBadge then self.IconBadge.Visible = true end
        if self.TabIcon then self.TabIcon.Visible = true end
        if self.TitleVisual then self.TitleVisual.Visible = true end
        if self.BadgeBg then self.BadgeBg.Visible = true end
        if self.BadgeText then self.BadgeText.Visible = true end
    end
end

function Tab:GetClipBounds(winPos, winSize)
    local win = self.Window
    local wp = winPos or (win and win.Position) or Vector2.new(0, 0)
    local ws = winSize or (win and win.Size) or Vector2.new(620, 440)
    local topH = (win and win.HeaderHeight) or 44
    -- Align exactly with MainPanelBg bounds: top=py+headerH, bottom=py+sy-8
    local clipTop = wp.Y + topH
    local clipBottom = wp.Y + ws.Y - 8
    return clipTop, clipBottom
end

function Tab:UpdateLayout(winPos, winSize)
    local win = self.Window
    local wp = winPos or (win and win.Position) or Vector2.new(0, 0)
    local ws = winSize or (win and win.Size) or Vector2.new(620, 440)
    local sbW = (win and win.SidebarWidth) or 190
    local topH = (win and win.HeaderHeight) or 44
    local contentX = sbW + 16
    local contentW = math.max(180, ws.X - sbW - 48)

    local startY = topH + 14
    local curY = startY
    local idx = 1
    while idx <= #self.Sections do
        local sec = self.Sections[idx]
        if sec._group then
            local g = sec._group
            local rowSecs = {}
            while idx <= #self.Sections and self.Sections[idx]._group == g do
                table.insert(rowSecs, self.Sections[idx])
                idx = idx + 1
            end
            local count = #rowSecs
            local gap = 10
            local colW = math.max(120, math.floor((contentW - (count - 1) * gap) / count))
            local maxSecH = 0
            for gi, rSec in ipairs(rowSecs) do
                rSec.Position = Vector2.new(contentX + (gi - 1) * (colW + gap), curY)
                rSec._groupWidth = colW
                local secH = rSec.GetDynamicHeight and rSec:GetDynamicHeight(colW)
                    or (rSec.Box and math.max(40, (rSec.Padding * 2) + rSec.CursorY) or math.max(0, rSec.CursorY))
                if secH > maxSecH then maxSecH = secH end
            end
            curY = curY + maxSecH + 10
        else
            sec.Position = Vector2.new(contentX, curY)
            sec._groupWidth = nil
            local secH = sec.GetDynamicHeight and sec:GetDynamicHeight(contentW)
                or (sec.Box and math.max(40, (sec.Padding * 2) + sec.CursorY) or math.max(0, sec.CursorY))
            curY = curY + secH + (sec.Box and 10 or 4)
            idx = idx + 1
        end
    end
    self.ContentCursorY = curY

    local clipTop, clipBottom = self:GetClipBounds(wp, ws)
    local panelH = math.max(60, clipBottom - clipTop)
    local totalContentH = math.max(0, curY - startY)
    self.MaxScrollY = math.max(0, totalContentH - panelH + 10)
    self.ScrollY = math.clamp(self.ScrollY or 0, 0, self.MaxScrollY)

    for _, sec in ipairs(self.Sections) do
        sec:Reflow(wp, sec._groupWidth or contentW, self.ScrollY, clipTop, clipBottom)
    end
end

function Tab:UpdatePosition(contentPos)
    local win = self.Window
    self:UpdateLayout(contentPos, win and win.Size)
end

function Tab:UpdateSize(winSize)
    local win = self.Window
    self:UpdateLayout(win and win.Position, winSize)
end

function Tab:Scroll(deltaY)
    if self.MaxScrollY <= 0 then
        self.ScrollY = 0
        self._targetScrollY = 0
        return
    end
    local base = self._targetScrollY or self.ScrollY or 0
    local nextScroll = math.clamp(base + deltaY, 0, self.MaxScrollY)
    self._targetScrollY = nextScroll
    if nextScroll ~= self.ScrollY then
        AnimationsModule.Tween("tab_scroll_" .. tostring(self), self.ScrollY or 0, nextScroll, 22, function(v)
            self.ScrollY = v
            self:UpdateLayout()
            if self.Window and self.Window._syncScrollbar then
                self.Window:_syncScrollbar()
            end
        end)
    end
end

function Tab:RegisterDrawing(drawingObj)
    if not drawingObj then return end
    table.insert(self.Drawings, drawingObj)
    table.insert(self._drawings, drawingObj)
    return drawingObj
end

function Tab:RegisterControl(control)
    if not control then return end
    table.insert(self.Controls, control)
    return control
end

function Tab:Section(config)
    assert(ContentSectionModule, "ContentSection module not available!")
    local sec = ContentSectionModule.new(config, self, self.Window)
    if type(config) == "table" and config._group then
        sec._group = config._group
    end
    table.insert(self.Sections, sec)
    self._layoutDirty = true
    return sec
end

function Tab:AddSection(config)
    return self:Section(config)
end

function Tab:Card(config)
    local cfg = type(config) == "table" and config or { Title = tostring(config or "Card") }
    cfg._forceBox = true
    return self:Section(cfg)
end

function Tab:AddCard(config)
    return self:Card(config)
end

function Tab:AddLeftGroupbox(title)
    local cfg = type(title) == "table" and title or { Title = tostring(title or "Section") }
    cfg._forceBox = true
    return self:Section(cfg)
end

function Tab:AddRightGroupbox(title)
    local cfg = type(title) == "table" and title or { Title = tostring(title or "Section") }
    cfg._forceBox = true
    return self:Section(cfg)
end

function Tab:GetDefaultSection()
    if #self.Sections > 0 then
        local last = self.Sections[#self.Sections]
        if not last._group and not last.Box then
            return last
        end
    end
    return self:Section({ Title = "" })
end

for _, methodName in ipairs({
    "Toggle", "AddToggle", "AddCheckbox",
    "Slider", "AddSlider",
    "Button", "AddButton",
    "Dropdown", "AddDropdown",
    "Input", "AddInput",
    "Keybind", "AddKeybind",
    "Group", "Paragraph", "Code", "ProgressBar", "AddProgressBar",
    "Colorpicker", "AddColorPicker",
    "Image", "Divider", "Space",
}) do
    Tab[methodName] = function(self, ...)
        local sec = self:GetDefaultSection()
        return sec[methodName](sec, ...)
    end
end

function Tab:Show(windowPos)
    self.IsActive = true
    self:UpdateVisualState()

    -- IMPORTANT: Do NOT blindly override self.Drawings[i].Visible = true!
    -- Sections and controls own their exact visual state (unchecked checkboxes, clipped overflow, unboxed cards).
    for _, sec in ipairs(self.Sections) do
        sec.Visible = true
    end
    self:UpdateLayout(windowPos, self.Window and self.Window.Size)
end

function Tab:Hide()
    self.IsActive = false
    self:UpdateVisualState()

    for _, sec in ipairs(self.Sections) do
        sec:SetVisible(false)
        for _, c in ipairs(sec.Controls or {}) do
            if c.Focused and c.Blur then c:Blur(false) end
            if c.IsOpen and c.Close then c:Close() end
        end
    end
end

function Tab:Select()
    if self.Window and self.Window.SelectTab then
        self.Window:SelectTab(self)
    end
end

function Tab:SetVisible(visible)
    self.Visible = visible
    self:SetSidebarVisible(visible)
    if visible and self.IsActive then
        self:Show()
    else
        self:Hide()
    end
end

function Tab:UpdateTheme(t)
    self:UpdateVisualState()
    local cardBg = ThemeModule.Resolve(t, "Card.Background")
    local borderCol = ThemeModule.Resolve(t, "Card.Border")
    local elemBg = ThemeModule.Resolve(t, "ElementBackground")
    local ctrlBg = ThemeModule.Resolve(t, "Control.Background")
    local txtTitle = ThemeModule.Resolve(t, str_txt_title)
    local txtSub = ThemeModule.Resolve(t, str_txt_sec)
    local txtMuted = ThemeModule.Resolve(t, "Text.Muted")
    local accentBlue = ThemeModule.Resolve(t, "Accent.Blue")
    local sldTrack = ThemeModule.Resolve(t, "Slider.TrackBg")

    for _, sec in ipairs(self.Sections) do
        -- Boxed collapsible sections use Text.Title at near-full transparency (WindUI SectionBox style)
        if sec.Background then sec.Background.Color = txtTitle end
        if sec.Border then sec.Border.Color = txtTitle end
        if sec.TitleText then sec.TitleText.Color = txtTitle end
        if sec.DescText then sec.DescText.Color = txtSub end

        for _, ctrl in ipairs(sec.Controls or {}) do
            if ctrl.RowBg then ctrl.RowBg.Color = elemBg end
            if ctrl.Visual and not ctrl.CustomColor then
                ctrl.Visual.Color = ctrl.Code and ThemeModule.Resolve(t, "Window.Background") or elemBg
            end
            if ctrl.HeaderBg then ctrl.HeaderBg.Color = ctrlBg end
            if ctrl.CopyBg then ctrl.CopyBg.Color = elemBg end
            if ctrl.CopyText then ctrl.CopyText.Color = txtTitle end
            if ctrl.Border then ctrl.Border.Color = borderCol end
            if ctrl.SwatchBorder then ctrl.SwatchBorder.Color = borderCol end
            if ctrl.PopupBg then ctrl.PopupBg.Color = cardBg end
            if ctrl.PopupBorder then ctrl.PopupBorder.Color = borderCol end
            if ctrl.PopupHoverBg then ctrl.PopupHoverBg.Color = ThemeModule.Resolve(t, str_tab_active) end
            if ctrl.SearchBg then ctrl.SearchBg.Color = elemBg end
            if ctrl.SearchText then
                ctrl.SearchText.Color = (ctrl.SearchQuery and ctrl.SearchQuery ~= "") and txtTitle or txtSub
            end
            if ctrl.PopupDrawings then
                if ctrl.PopupDrawings.Bg then ctrl.PopupDrawings.Bg.Color = cardBg end
                if ctrl.PopupDrawings.Border then ctrl.PopupDrawings.Border.Color = borderCol end
                if ctrl.PopupDrawings.HexText then ctrl.PopupDrawings.HexText.Color = txtTitle end
            end
            if ctrl.ButtonSlots then
                for _, bSlot in ipairs(ctrl.ButtonSlots) do
                    if bSlot.Bg then bSlot.Bg.Color = ctrlBg end
                    if bSlot.Text then bSlot.Text.Color = txtTitle end
                end
            end
            if ctrl.Label then ctrl.Label.Color = ctrl.Locked and txtMuted or txtTitle end
            if ctrl.TitleText then
                ctrl.TitleText.Color = ctrl.Locked and txtMuted or (ctrl.Code and txtSub or txtTitle)
            end
            if ctrl.DescLabel then ctrl.DescLabel.Color = txtSub end
            if ctrl.DescText then ctrl.DescText.Color = txtSub end
            if ctrl.LineDrawings then
                for _, ln in ipairs(ctrl.LineDrawings) do
                    ln.Color = ctrl.Code and txtTitle or txtSub
                end
            end
            if ctrl.Box then ctrl.Box.Color = ctrlBg end
            if ctrl.BoxBorder then ctrl.BoxBorder.Color = ctrl.Focused and accentBlue or borderCol end
            if ctrl.ValueBadge then ctrl.ValueBadge.Color = txtSub end
            if ctrl.Badge then ctrl.Badge.Color = txtSub end
            if ctrl.ValueText then ctrl.ValueText.Color = txtSub end
            if ctrl.BadgeBg then ctrl.BadgeBg.Color = ctrlBg end
            if ctrl.BadgeText and not ctrl.Capturing then ctrl.BadgeText.Color = txtSub end
            if ctrl.KeyPicker then
                local kp = ctrl.KeyPicker
                if kp.BadgeBg then kp.BadgeBg.Color = ctrlBg end
                if kp.BadgeText and not kp.Capturing then kp.BadgeText.Color = txtSub end
                if kp.ModeMenu then
                    if kp.ModeMenu.Bg then kp.ModeMenu.Bg.Color = cardBg end
                    if kp.ModeMenu.Border then kp.ModeMenu.Border.Color = borderCol end
                end
            end
            if ctrl.InputText and ctrl._refreshDisplay then ctrl:_refreshDisplay() end
            if ctrl.Opened and ctrl._layoutPopup then ctrl:_layoutPopup() end
            if ctrl.Track then
                if ctrl._applyAnimVisual then
                    ctrl:_applyAnimVisual(ctrl.AnimProgress or (ctrl.Value and 1 or 0))
                else
                    ctrl.Track.Color = sldTrack
                end
            end
            if ctrl.FillBar and not ctrl._applyAnimVisual then
                ctrl.FillBar.Color = accentBlue
            end
        end
    end
end

function Tab:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self:SetVisible(false)

    for _, sec in ipairs(self.Sections) do
        if sec.Destroy then sec:Destroy() end
    end

    self.Drawings = {}
    self._drawings = {}
    self.Sections = {}
    self.Cards = {}
    self.Controls = {}
end

return Tab
