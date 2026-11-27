-- Library/BreezeUI/Layout/ContentSection.lua
-- Vertical stacking flow container supporting responsive reflow, viewport clipping, and WindUI + Obsidian compatibility.

local PoolModule = Pool or require("../Core/Pool")
local MetaModule = Meta or require("../Core/Meta")
local GeometryModule = Geometry or require("../Core/Geometry")
local MetricsModule = Metrics or require("../Core/Metrics")
local ThemeModule = Theme or require("./Theme")
local IconsModule = Icons or require("../Subsystems/Icons")

local ToggleModule = Toggle or require("../Components/Toggle")
local SliderModule = Slider or require("../Components/Slider")
local ButtonModule = Button or require("../Components/Button")
local DropdownModule = Dropdown or require("../Components/Dropdown")
local InputModule = Input or require("../Components/Input")
local KeybindModule = Keybind or require("../Components/Keybind")
local ParagraphModule = Paragraph or require("../Components/Paragraph")
local CodeModule = Code or require("../Components/Code")
local ImageModule = Image or require("../Components/Image")
local ProgressBarModule = ProgressBar or require("../Components/ProgressBar")
local ColorpickerModule = Colorpicker or require("../Components/Colorpicker")

local ContentSection = {}
ContentSection.__index = ContentSection

local SKIP_CLIP_KEYS = { Section = true, Parent = true, Window = true, Pool = true, Env = true, Values = true, VisibleItems = true, Config = true, Callback = true }

local function clip_drawing(obj, clipTop, clipBottom)
    if not obj or not obj.Visible or not obj.Position then return end
    local y = obj.Position.Y
    local sz = obj.Size
    local isVec = (type(sz) == "table" or type(sz) == "userdata")
    local h = isVec and (sz.Y or 14) or (type(sz) == "number" and sz or 14)
    if isVec and obj.Filled ~= nil and h >= 24 then
        local vt = math.max(y, clipTop)
        local vb = math.min(y + h, clipBottom)
        local vh = math.max(0, vb - vt)
        obj.Position = Vector2.new(obj.Position.X, vt)
        obj.Size = Vector2.new(sz.X, vh)
        obj.Visible = vh > 4
    else
        obj.Visible = (y >= clipTop + 6) and (y + h <= clipBottom - 6)
    end
end

local function clip_control(tbl, clipTop, clipBottom, visited)
    visited = visited or {}
    if visited[tbl] then return end
    visited[tbl] = true
    for k, v in pairs(tbl) do
        if not SKIP_CLIP_KEYS[k] and (type(v) == "table" or type(v) == "userdata") then
            if v.Position ~= nil and v.Visible ~= nil then
                clip_drawing(v, clipTop, clipBottom)
            elseif type(v) == "table" then
                clip_control(v, clipTop, clipBottom, visited)
            end
        end
    end
end

local function get_theme_color(token, default)
    return ThemeModule.Get(token, default)
end

function ContentSection.new(config, parentTab, window)
    local cfg = type(config) == "table" and config or { Title = tostring(config or "Section") }
    local win = window or (parentTab and parentTab.Window)
    local pool = (win and win.Pool) or (parentTab and parentTab.Pool)
    if not pool and PoolModule then
        pool = PoolModule.new(200, MetaModule)
    end

    local sbWidth = win and win.SidebarWidth or 190
    local topHeight = win and win.HeaderHeight or 44
    local contentX = sbWidth + 14
    local defaultY = topHeight + 14
    local startY = (parentTab and parentTab.ContentCursorY) or defaultY
    local contentW = win and math.max(180, win.Size.X - sbWidth - 28) or 422
    local isBoxed = (cfg.Box == true) or (cfg._forceBox == true)

    -- Expandable/collapsible support: `Opened = false` starts collapsed
    local hasExpandableTitle = (cfg.Title ~= nil and cfg.Title ~= "")
    local expandable = hasExpandableTitle and (cfg.Opened ~= nil)
    local startOpened = (cfg.Opened ~= false)  -- default true

    local self = setmetatable({
        Type = "ContentSection",
        Title = cfg.Title,
        Description = cfg.Description or cfg.Desc,
        TextSize = cfg.TextSize or 13,
        Box = isBoxed,
        Columns = cfg.Columns or 1,
        ParentTab = parentTab,
        Window = win,
        Env = win and win.Env or _G.Library,
        Pool = pool,

        Controls = {},
        Drawings = {},
        _drawings = {},

        -- Relative position to win.Position (base layout without scroll)
        Position = cfg.Position or Vector2.new(contentX, startY),
        BaseRelY = (cfg.Position and cfg.Position.Y) or startY,
        Size = cfg.Size or Vector2.new(contentW, 30),
        Padding = isBoxed and 12 or 0,
        ColGap = 6,
        RowGap = 6,
        RowHeight = 44,
        SliderRowHeight = 46,

        CursorY = 0,
        HeaderHeight = 0,
        LastAllocated = nil,

        Background = nil,
        Border = nil,
        TitleText = nil,
        DescText = nil,
        ChevronImg = nil,  -- expandable chevron icon

        -- Expandable state
        Expandable = expandable,
        IsExpanded = startOpened,

        Visible = parentTab and (parentTab.IsActive == true) or (parentTab == nil),
        Destroyed = false,
    }, ContentSection)

    self:_renderCard()
    self:_renderHeader()
    -- Render chevron after header if expandable
    if expandable and pool then
        local chev = pool:Get("Image")
        chev.Size = Vector2.new(12, 12)
        chev.Transparency = 0.6
        chev.ZIndex = 5
        chev.Visible = false
        self.ChevronImg = chev
        self:_register(chev)
        if IconsModule and IconsModule.Get then
            IconsModule.Get(startOpened and "chevron-down" or "chevron-up", function(png)
                if self.ChevronImg and png then self.ChevronImg.Data = png end
            end)
        end
    end
    -- When collapsed initially, collapse content
    if expandable and not startOpened then
        self.CursorY = 0
    end
    self:_syncTabCursor()

    return self
end

function ContentSection:_syncTabCursor()
    -- When collapsed (Expandable=true, IsExpanded=false), use only HeaderHeight
    local contentH = (self.Expandable and not self.IsExpanded) and 0 or self.CursorY
    local totalH = self.Box and math.max(40, (self.Padding * 2) + contentH) or math.max(0, contentH)
    -- Expandable sections always show at least the header
    if self.Expandable then
        totalH = math.max(self.HeaderHeight + (self.Padding * 2), totalH)
    end
    self.Size = Vector2.new(self.Size.X, totalH)

    if self.Background then
        self.Background.Size = self.Size
    end
    if self.Border then
        self.Border.Size = self.Size
    end

    if self.ParentTab and self.ParentTab.ContentCursorY ~= nil then
        local nextY = self.Position.Y + totalH + (self.Box and 10 or 4)
        if nextY > self.ParentTab.ContentCursorY then
            self.ParentTab.ContentCursorY = nextY
        end
        self.ParentTab._layoutDirty = true
    end
end

function ContentSection:_register(obj)
    if not obj then return end
    table.insert(self.Drawings, obj)
    table.insert(self._drawings, obj)

    if self.ParentTab then
        if self.ParentTab.RegisterDrawing then
            self.ParentTab:RegisterDrawing(obj)
        elseif self.ParentTab.Drawings then
            table.insert(self.ParentTab.Drawings, obj)
        end
        if self.ParentTab._drawings then
            table.insert(self.ParentTab._drawings, obj)
        end
    end

    local win = self.Window or (self.ParentTab and self.ParentTab.Window)
    if win and win._drawings then
        table.insert(win._drawings, obj)
    end
end

function ContentSection:_renderCard()
    local win = self.Window or (self.ParentTab and self.ParentTab.Window)
    local basePos = win and win.Position or Vector2.new(0, 0)
    local absPos = Vector2.new(basePos.X + self.Position.X, basePos.Y + self.Position.Y)

    -- Matcha Transparency is opacity (1 = opaque, 0 = invisible): 0.04 = subtle 4% white overlay, 0.16 = subtle border
    local bgCol = get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))
    local borderCol = get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))

    local bg = self.Pool:Get("Square")
    bg.Position = absPos
    bg.Size = self.Size
    bg.Color = bgCol
    bg.Transparency = 0.04
    bg.Filled = true
    bg.Corner = 10
    bg.ZIndex = 3
    self.Background = bg

    local border = self.Pool:Get("Square")
    border.Position = absPos
    border.Size = self.Size
    border.Color = borderCol
    border.Transparency = 0.16
    border.Filled = false
    border.Thickness = 1
    border.Corner = 10
    border.ZIndex = 3
    self.Border = border

    self.bg = self.Background
    self.border = self.Border

    local isShown = self.Visible and self.Box
    if self.Background then self.Background.Visible = isShown end
    if self.Border then self.Border.Visible = isShown end

    self:_register(self.Background)
    if self.Border then self:_register(self.Border) end
end

function ContentSection:_renderHeader()
    local win = self.Window or (self.ParentTab and self.ParentTab.Window)
    local basePos = win and win.Position or Vector2.new(0, 0)
    local absPos = Vector2.new(basePos.X + self.Position.X, basePos.Y + self.Position.Y)
    local innerX = absPos.X + self.Padding
    local innerY = absPos.Y + self.Padding
    local usableW = self.Size.X - (self.Padding * 2)
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    local currentY = innerY

    if self.Title and self.Title ~= "" then
        local titleObj = self.Pool:Get("Text")
        local fitTitle = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(self.Title, usableW, self.TextSize) or tostring(self.Title)
        titleObj.Text = fitTitle
        titleObj.Size = self.TextSize
        titleObj.Font = fontUI
        titleObj.Outline = false
        titleObj.Color = get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))
        titleObj.Position = Vector2.new(innerX, currentY)
        titleObj.ZIndex = 4
        titleObj.Visible = self.Visible
        self.TitleText = titleObj
        self:_register(titleObj)
        currentY = currentY + math.max(18, self.TextSize + 6)
    end

    if self.Description and self.Description ~= "" then
        local descObj = self.Pool:Get("Text")
        local fitDesc = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(self.Description, usableW, 11) or tostring(self.Description)
        descObj.Text = fitDesc
        descObj.Size = 11
        descObj.Font = fontUI
        descObj.Outline = false
        descObj.Color = get_theme_color("Text.Secondary", Color3.fromRGB(161, 161, 170))
        descObj.Position = Vector2.new(innerX, currentY)
        descObj.ZIndex = 4
        descObj.Visible = self.Visible
        self.DescText = descObj
        self:_register(descObj)
        currentY = currentY + 15
    end

    if (self.Title and self.Title ~= "") or (self.Description and self.Description ~= "") then
        currentY = currentY + 4
    end

    self.HeaderHeight = currentY - innerY
    self.CursorY = self.HeaderHeight
end

function ContentSection:AllocateControlSlot(isHalf, height)
    local h = height or self.RowHeight
    local win = self.Window or (self.ParentTab and self.ParentTab.Window)
    local basePos = win and win.Position or Vector2.new(0, 0)
    local absPos = Vector2.new(basePos.X + self.Position.X, basePos.Y + self.Position.Y)
    local innerX = absPos.X + self.Padding
    local innerY = absPos.Y + self.Padding
    local usableW = math.max(140, self.Size.X - (self.Padding * 2))

    if self._activeGroup then
        local grp = self._activeGroup
        if not grp.RowRelY then
            grp.RowRelY = self.Padding + self.CursorY
        end
        if h > grp.MaxH then
            local extra = (h - grp.MaxH) + (grp.MaxH == 0 and self.RowGap or 0)
            self.CursorY = self.CursorY + extra
            grp.MaxH = h
        end
        local colIdx = #grp.Items + 1
        self.LastAllocated = {
            RelX = self.Padding,
            RelY = grp.RowRelY,
            Width = usableW,
            Height = h,
            _group = grp,
            _colIdx = colIdx,
        }
        self:_syncTabCursor()
        return Vector2.new(innerX, absPos.Y + grp.RowRelY), Vector2.new(usableW, h)
    end

    local slotX = innerX
    local slotY = innerY + self.CursorY
    local slotW = usableW

    self.LastAllocated = {
        RelX = self.Padding,
        RelY = self.Padding + self.CursorY,
        Width = slotW,
        Height = h,
    }

    self.CursorY = self.CursorY + h + self.RowGap
    self:_syncTabCursor()

    return Vector2.new(slotX, slotY), Vector2.new(slotW, h)
end

local function is_ctrl_active(sec, ctrl)
    return ctrl._hidden ~= true
end

function ContentSection:GetDynamicHeight(targetWidth)
    local w = targetWidth or self.Size.X
    local usableW = math.max(140, w - (self.Padding * 2))
    if self.Expandable and not self.IsExpanded then
        local hdrH = self.HeaderHeight or 22
        return self.Box and math.max(40, (self.Padding * 2) + hdrH) or hdrH
    end
    local dynY = self.Padding + (self.HeaderHeight or 0)
    local seenGroups = {}
    for _, ctrl in ipairs(self.Controls) do
        if is_ctrl_active(self, ctrl) then
            if ctrl._group then
                if not seenGroups[ctrl._group] then
                    seenGroups[ctrl._group] = true
                    dynY = dynY + (ctrl._group.MaxH or 44) + self.RowGap
                end
            else
                local ch = (ctrl.RecalcHeight and ctrl:RecalcHeight(usableW)) or (ctrl.Size and ctrl.Size.Y) or 44
                dynY = dynY + ch + self.RowGap
            end
        end
    end
    local cursorPart = math.max(0, dynY - self.Padding)
    return self.Box and math.max(40, (self.Padding * 2) + cursorPart) or cursorPart
end

function ContentSection:Open()
    if not self.Expandable or self.IsExpanded then return end
    self.IsExpanded = true
    if self.ChevronImg and IconsModule and IconsModule.Get then
        IconsModule.Get("chevron-down", function(png)
            if self.ChevronImg and png then self.ChevronImg.Data = png end
        end)
    end
    if self.ParentTab then self.ParentTab._layoutDirty = true end
end

function ContentSection:Close()
    if not self.Expandable or not self.IsExpanded then return end
    self.IsExpanded = false
    if self.ChevronImg and IconsModule and IconsModule.Get then
        IconsModule.Get("chevron-up", function(png)
            if self.ChevronImg and png then self.ChevronImg.Data = png end
        end)
    end
    if self.ParentTab then self.ParentTab._layoutDirty = true end
end

function ContentSection:ToggleExpand()
    if self.IsExpanded then self:Close() else self:Open() end
end

function ContentSection:HandleHeaderClick(mx, my)
    if not self.Expandable or not self._headerRect then return false end
    local r = self._headerRect
    if mx >= r.X and mx <= r.X + r.W and my >= r.Y and my <= r.Y + r.H then
        self:ToggleExpand()
        return true
    end
    return false
end

function ContentSection:Reflow(basePos, newWidth, scrollY, clipTop, clipBottom)
    local scroll = scrollY or 0
    local w = newWidth or self.Size.X
    local dynH = self:GetDynamicHeight(w)
    self.Size = Vector2.new(w, dynH)

    local absPos = Vector2.new(basePos.X + self.Position.X, basePos.Y + self.Position.Y - scroll)
    local innerX = absPos.X + self.Padding
    local innerY = absPos.Y + self.Padding
    local usableW = math.max(140, w - (self.Padding * 2))

    local visTop = absPos.Y
    local visBot = absPos.Y + self.Size.Y
    if clipTop and clipBottom then
        visTop = math.max(visTop, clipTop)
        visBot = math.min(visBot, clipBottom)
    end
    local visH = math.max(0, visBot - visTop)
    local bgVis = self.Visible and self.Box and (visH > 4)
    if self.Background then
        self.Background.Position = Vector2.new(absPos.X, visTop)
        self.Background.Size = Vector2.new(self.Size.X, visH)
        self.Background.Visible = bgVis
    end
    if self.Border then
        self.Border.Position = Vector2.new(absPos.X, visTop)
        self.Border.Size = Vector2.new(self.Size.X, visH)
        self.Border.Visible = bgVis
    end

    local currentY = innerY
    if self.TitleText then
        self.TitleText.Position = Vector2.new(innerX, currentY)
        if MetricsModule and MetricsModule.Fit then
            self.TitleText.Text = MetricsModule.Fit(self.Title or "", usableW, self.TextSize)
        end
        local tVis = self.Visible
        if clipTop and clipBottom then
            tVis = tVis and (currentY >= clipTop + 6) and (currentY + self.TextSize <= clipBottom - 6)
        end
        self.TitleText.Visible = tVis
        currentY = currentY + math.max(18, self.TextSize + 6)
    end
    if self.DescText then
        self.DescText.Position = Vector2.new(innerX, currentY)
        if MetricsModule and MetricsModule.Fit then
            self.DescText.Text = MetricsModule.Fit(self.Description or "", usableW, 11)
        end
        local dVis = self.Visible
        if clipTop and clipBottom then
            dVis = dVis and (currentY >= clipTop + 6) and (currentY + 12 <= clipBottom - 6)
        end
        self.DescText.Visible = dVis
    end

    if self.Expandable then
        local hdrH = math.max(20, self.HeaderHeight or 22)
        local hdrVis = self.Visible
        if clipTop and clipBottom then
            hdrVis = hdrVis and (innerY >= clipTop + 6) and (innerY + 14 <= clipBottom - 6)
        end
        self._headerRect = hdrVis and { X = innerX, Y = innerY, W = usableW, H = hdrH } or nil
        if self.ChevronImg then
            self.ChevronImg.Position = Vector2.new(innerX + usableW - 14, innerY + 3)
            self.ChevronImg.Visible = hdrVis
        end
    end

    if self.Expandable and not self.IsExpanded then
        for _, ctrl in ipairs(self.Controls) do
            if ctrl.SetVisible then ctrl:SetVisible(false) else ctrl.Visible = false end
        end
        return
    end

    local dynY = self.Padding + (self.HeaderHeight or 0)
    local groupRowY = {}
    for _, ctrl in ipairs(self.Controls) do
        if not is_ctrl_active(self, ctrl) then
            if ctrl.SetVisible then ctrl:SetVisible(false) else ctrl.Visible = false end
        else
            local ch = (ctrl.Size and ctrl.Size.Y) or 44
            local rowY
            local cX = innerX
            local cW = usableW
            if ctrl._group then
                if not groupRowY[ctrl._group] then
                    groupRowY[ctrl._group] = dynY
                    dynY = dynY + (ctrl._group.MaxH or ch) + self.RowGap
                end
                rowY = absPos.Y + groupRowY[ctrl._group]
                local visCount = 0
                local myIdx = 0
                for _, item in ipairs(ctrl._group.Items) do
                    if is_ctrl_active(self, item) then
                        visCount = visCount + 1
                        if item == ctrl then myIdx = visCount end
                    end
                end
                local count = math.max(1, visCount)
                local gap = ctrl._group.Gap or 8
                cW = math.max(60, math.floor((usableW - (count - 1) * gap) / count))
                cX = innerX + (math.max(1, myIdx) - 1) * (cW + gap)
            else
                rowY = absPos.Y + dynY
                dynY = dynY + ch + self.RowGap
            end
            local cPos = Vector2.new(cX, rowY)
            if ctrl.SetPosition then
                ctrl:SetPosition(cPos, Vector2.new(cW, ch))
            end
            local visTop = clipTop and math.max(rowY, clipTop) or rowY
            local visBot = clipBottom and math.min(rowY + ch, clipBottom) or (rowY + ch)
            local partIn = self.Visible and (visBot - visTop > 4)
            local fullIn = self.Visible and ((not clipTop) or (rowY >= clipTop and rowY + ch <= clipBottom))
            if ctrl.SetVisible then
                ctrl:SetVisible(partIn)
            else
                ctrl.Visible = partIn
            end
            if partIn and not fullIn and clipTop and clipBottom then
                clip_control(ctrl, clipTop, clipBottom)
            end
        end
    end
end

function ContentSection:SetPosition(basePos)
    if self.ParentTab and self.ParentTab.GetClipBounds then
        local win = self.Window or self.ParentTab.Window
        local clipTop, clipBottom = self.ParentTab:GetClipBounds(basePos, win and win.Size)
        self:Reflow(basePos, self.Size.X, self.ParentTab.ScrollY or 0, clipTop, clipBottom)
    else
        self:Reflow(basePos, self.Size.X, 0)
    end
end

function ContentSection:SetSize(newSize)
    local w = type(newSize) == "table" or type(newSize) == "userdata" and newSize.X or self.Size.X
    local win = self.Window or (self.ParentTab and self.ParentTab.Window)
    local basePos = win and win.Position or Vector2.new(0, 0)
    if self.ParentTab and self.ParentTab.GetClipBounds then
        local clipTop, clipBottom = self.ParentTab:GetClipBounds(basePos, win and win.Size)
        self:Reflow(basePos, w, self.ParentTab.ScrollY or 0, clipTop, clipBottom)
    else
        self:Reflow(basePos, w, 0)
    end
end

function ContentSection:SetVisible(visible)
    self.Visible = visible
    if not visible then
        if self.Background then self.Background.Visible = false end
        if self.Border then self.Border.Visible = false end
        if self.TitleText then self.TitleText.Visible = false end
        if self.DescText then self.DescText.Visible = false end
        if self.ChevronImg then self.ChevronImg.Visible = false end
        for _, ctrl in ipairs(self.Controls) do
            if ctrl.SetVisible then
                ctrl:SetVisible(false)
            else
                ctrl.Visible = false
            end
        end
        return
    end

    local win = self.Window or (self.ParentTab and self.ParentTab.Window)
    local basePos = win and win.Position or Vector2.new(0, 0)
    if self.ParentTab and self.ParentTab.GetClipBounds then
        local clipTop, clipBottom = self.ParentTab:GetClipBounds(basePos, win and win.Size)
        self:Reflow(basePos, self.Size.X, self.ParentTab.ScrollY or 0, clipTop, clipBottom)
    else
        self:Reflow(basePos, self.Size.X, 0)
    end
end

-- ============================================================================
-- Component Constructors (Dual Obsidian & WindUI Compatibility)
-- ============================================================================

local function link_control_state(self, ctrl, id, isOption)
    local win = self.Window or (self.ParentTab and self.ParentTab.Window)
    local lib = win and win.Env or _G.Library
    if lib then
        if isOption and lib.Options then
            rawset(lib.Options, id, ctrl)
            if lib._rawOptions then lib._rawOptions[id] = ctrl end
            if lib._initialDefaults and lib._initialDefaults.Options then
                lib._initialDefaults.Options[id] = ctrl.Value
            end
            if win and win.RegisteredIds and win.RegisteredIds.Options then
                win.RegisteredIds.Options[id] = true
            end
        elseif not isOption and lib.Toggles then
            rawset(lib.Toggles, id, ctrl)
            if lib._rawToggles then lib._rawToggles[id] = ctrl end
            if lib._initialDefaults and lib._initialDefaults.Toggles then
                lib._initialDefaults.Toggles[id] = ctrl.Value
            end
            if win and win.RegisteredIds and win.RegisteredIds.Toggles then
                win.RegisteredIds.Toggles[id] = true
            end
        end
    end
end

local function resolve_unique_id(self, prefix, cfg, isOption)
    local explicit = cfg.Flag or cfg.Id
    if explicit ~= nil then return explicit end
    local base = cfg.Title or cfg.Text or (prefix .. "_" .. tostring(#self.Controls + 1))
    local win = self.Window or (self.ParentTab and self.ParentTab.Window)
    local lib = win and win.Env or _G.Library
    local pool = lib and (isOption and lib._rawOptions or lib._rawToggles)
    if not pool or pool[base] == nil then
        return base
    end
    local idx = 2
    while pool[base .. "_" .. tostring(idx)] ~= nil do
        idx = idx + 1
    end
    return base .. "_" .. tostring(idx)
end

local function sync_lock_overlay(ctrl)
    local lo = ctrl._lockOverlay
    if not lo then return end
    local show = (ctrl.Locked == true) and (ctrl.Visible == true)
    local pos = ctrl.Position
    local size = ctrl.Size
    if pos and size then
        lo.Bg.Position = pos
        lo.Bg.Size = size
        local label = tostring(ctrl.LockedTitle or "Locked")
        lo.Text.Text = label
        local tw = (MetricsModule and MetricsModule.GetTextWidth and MetricsModule.GetTextWidth(label, 13)) or (#label * 6.5)
        local totalW = 16 + 6 + tw
        local sx = pos.X + math.floor((size.X - totalW) * 0.5)
        lo.Icon.Position = Vector2.new(sx, pos.Y + math.floor((size.Y - 16) * 0.5))
        lo.Text.Position = Vector2.new(sx + 22, pos.Y + math.floor((size.Y - 13) * 0.5))
    end
    lo.Bg.Visible = show
    lo.Icon.Visible = show and (lo.IconData ~= nil)
    lo.Text.Visible = show
end

local function ensure_lock_overlay(sec, ctrl)
    if ctrl._lockOverlay or not sec or not sec.Pool then return end
    local pool = sec.Pool
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    local bg = pool:Get("Square")
    bg.Color = Color3.new(0, 0, 0)
    bg.Transparency = 0.75
    bg.Filled = true
    bg.Corner = 8
    bg.ZIndex = 12
    bg.Visible = false
    sec:_register(bg)

    local ico = pool:Get("Image")
    ico.Size = Vector2.new(16, 16)
    ico.Transparency = 0.75
    ico.ZIndex = 13
    ico.Visible = false
    sec:_register(ico)

    local txt = pool:Get("Text")
    txt.Text = tostring(ctrl.LockedTitle or "Locked")
    txt.Font = fontUI
    txt.Outline = false
    txt.Size = 13
    txt.Color = Color3.fromRGB(255, 255, 255)
    txt.ZIndex = 13
    txt.Visible = false
    sec:_register(txt)

    local lo = { Bg = bg, Icon = ico, Text = txt, IconData = nil }
    ctrl._lockOverlay = lo

    if IconsModule and IconsModule.Get then
        local got = IconsModule.Get("lock", function(png)
            lo.IconData = png
            ico.Data = png
            sync_lock_overlay(ctrl)
        end)
        if got then
            lo.IconData = got
            ico.Data = got
        end
    end
end

local function register_control(self, ctrl, cfg)
    local la = self.LastAllocated
    if la then
        ctrl.RelX = la.RelX
        ctrl.RelY = la.RelY
        if la._group then
            ctrl._group = la._group
            ctrl._colIdx = la._colIdx
            table.insert(la._group.Items, ctrl)
        end
    end
    if type(cfg) == "table" and (cfg.Hidden == true or cfg.Visible == false) then
        ctrl._hidden = true
        if ctrl.SetVisible then ctrl:SetVisible(false) else ctrl.Visible = false end
    end
    function ctrl:SetHidden(hidden)
        local nextHidden = hidden == true
        if self._hidden == nextHidden then return end
        self._hidden = nextHidden
        if nextHidden then
            if self.SetVisible then self:SetVisible(false) else self.Visible = false end
        end
        local s = self.Section or self
        if s and s.ParentTab then s.ParentTab._layoutDirty = true end
    end
    function ctrl:Hide()
        self:SetHidden(true)
    end
    function ctrl:Show()
        self:SetHidden(false)
    end
    local origLock = ctrl.Lock
    function ctrl:Lock(title)
        if origLock then origLock(self, title) else
            self.Locked = true
            if title ~= nil then self.LockedTitle = tostring(title) end
        end
        ensure_lock_overlay(self.Section or self, self)
        sync_lock_overlay(self)
    end
    local origUnlock = ctrl.Unlock
    function ctrl:Unlock()
        if origUnlock then origUnlock(self) else
            self.Locked = false
        end
        sync_lock_overlay(self)
    end
    local origSetPos = ctrl.SetPosition
    if origSetPos then
        function ctrl:SetPosition(pos, size)
            origSetPos(self, pos, size)
            sync_lock_overlay(self)
        end
    end
    local origSetVis = ctrl.SetVisible
    if origSetVis then
        function ctrl:SetVisible(vis)
            origSetVis(self, vis)
            sync_lock_overlay(self)
        end
    end
    if not ctrl.SetTitle then
        function ctrl:SetTitle(title)
            self.Title = tostring(title or "")
            self.Text = self.Title
            if self.TitleText then self.TitleText.Text = self.Title end
            if self.Label then self.Label.Text = self.Title end
        end
    end
    if not ctrl.SetDesc then
        function ctrl:SetDesc(desc)
            self.Desc = desc ~= nil and tostring(desc) or ""
            if self.DescText then self.DescText.Text = self.Desc end
            if self.DescLabel then self.DescLabel.Text = self.Desc end
        end
    end
    if not ctrl.Destroy then
        function ctrl:Destroy()
            if self.SetVisible then self:SetVisible(false) else self.Visible = false end
        end
    end
    if type(cfg) == "table" then
        if cfg.LockedTitle ~= nil then ctrl.LockedTitle = tostring(cfg.LockedTitle) end
        if cfg.Tooltip ~= nil then ctrl.Tooltip = tostring(cfg.Tooltip) end
        if cfg.Locked == true then ctrl:Lock(cfg.LockedTitle) end
    end
    table.insert(self.Controls, ctrl)
    return ctrl
end

function ContentSection:AddToggle(id, config)
    assert(id ~= nil, "Toggle requires identifier!")
    local tog = register_control(self, ToggleModule.new(self, id, config), config)
    link_control_state(self, tog, id, false)
    return tog
end

function ContentSection:AddCheckbox(id, config)
    local cfg = type(config) == "table" and config or {}
    cfg.Type = "Checkbox"
    return self:AddToggle(id, cfg)
end

function ContentSection:Toggle(config)
    local cfg = config or {}
    local id = resolve_unique_id(self, "Toggle", cfg, false)
    return self:AddToggle(id, cfg)
end

function ContentSection:AddSlider(id, config)
    assert(id ~= nil, "Slider requires identifier!")
    local sld = register_control(self, SliderModule.new(self, id, config), config)
    link_control_state(self, sld, id, true)
    return sld
end

function ContentSection:Slider(config)
    local cfg = config or {}
    local id = resolve_unique_id(self, "Slider", cfg, true)
    return self:AddSlider(id, cfg)
end

function ContentSection:AddButton(config)
    return register_control(self, ButtonModule.new(self, config), config)
end

function ContentSection:Button(config)
    return self:AddButton(config)
end

function ContentSection:AddDropdown(id, config)
    assert(id ~= nil, "Dropdown requires identifier!")
    local drop = register_control(self, DropdownModule.new(self, id, config), config)
    link_control_state(self, drop, id, true)
    return drop
end

function ContentSection:Dropdown(config)
    local cfg = config or {}
    local id = resolve_unique_id(self, "Dropdown", cfg, true)
    return self:AddDropdown(id, cfg)
end

function ContentSection:AddInput(id, config)
    assert(id ~= nil, "Input requires identifier!")
    local inp = register_control(self, InputModule.new(self, id, config), config)
    link_control_state(self, inp, id, true)
    return inp
end

function ContentSection:AddTextbox(id, config)
    return self:AddInput(id, config)
end

function ContentSection:Input(config)
    local cfg = config or {}
    local id = resolve_unique_id(self, "Input", cfg, true)
    return self:AddInput(id, cfg)
end

function ContentSection:AddKeybind(id, config)
    assert(id ~= nil, "Keybind requires identifier!")
    local kb = register_control(self, KeybindModule.new(self, id, config), config)
    link_control_state(self, kb, id, true)
    return kb
end

function ContentSection:Keybind(config)
    local cfg = config or {}
    local id = resolve_unique_id(self, "Keybind", cfg, true)
    return self:AddKeybind(id, cfg)
end

function ContentSection:Paragraph(config)
    return register_control(self, ParagraphModule.new(self, config), config)
end

function ContentSection:AddLabel(text, config)
    local cfg = type(text) == "table" and text or (type(config) == "table" and config or { Title = tostring(text or "Label") })
    if type(text) == "string" and not cfg.Title then cfg.Title = text end
    return self:Paragraph(cfg)
end

function ContentSection:Code(config)
    return register_control(self, CodeModule.new(self, config), config)
end

function ContentSection:Image(config)
    return register_control(self, ImageModule.new(self, config), config)
end

function ContentSection:AddProgressBar(id, config)
    assert(id ~= nil, "ProgressBar requires identifier!")
    local pb = register_control(self, ProgressBarModule.new(self, id, config), config)
    link_control_state(self, pb, id, true)
    return pb
end

function ContentSection:ProgressBar(config)
    local cfg = config or {}
    local id = resolve_unique_id(self, "ProgressBar", cfg, true)
    return self:AddProgressBar(id, cfg)
end

function ContentSection:AddColorPicker(id, config)
    assert(id ~= nil, "Colorpicker requires identifier!")
    local cp = register_control(self, ColorpickerModule.new(self, id, config), config)
    link_control_state(self, cp, id, true)
    return cp
end
ContentSection.AddColorpicker = ContentSection.AddColorPicker

function ContentSection:Colorpicker(config)
    local cfg = config or {}
    local id = resolve_unique_id(self, "Colorpicker", cfg, true)
    return self:AddColorPicker(id, cfg)
end

function ContentSection:Divider()
    self.CursorY = self.CursorY + 8
    self:_syncTabCursor()
    return self
end

function ContentSection:Space(config)
    if self._activeGroup then return self end
    local height = 6
    if type(config) == "number" then
        height = math.max(2, config)
    elseif type(config) == "table" then
        if config.Height then
            height = math.max(2, tonumber(config.Height) or 6)
        elseif config.Columns then
            height = math.max(2, (tonumber(config.Columns) or 1) * 6)
        end
    end
    self.CursorY = self.CursorY + height
    self:_syncTabCursor()
end

function ContentSection:Section(config)
    if self.ParentTab and self.ParentTab.Section then
        return self.ParentTab:Section(config)
    end
    return self
end

function ContentSection:Group(config)
    local cfg = type(config) == "table" and config or {}
    local grp = {
        ParentSection = self,
        ParentTab = self.ParentTab,
        Items = {},
        Sections = {},
        RowRelY = nil,
        MaxH = 0,
        Gap = cfg.Gap or 8,
    }

    local function with_group(methodName, ...)
        self._activeGroup = grp
        local ok, res = pcall(self[methodName], self, ...)
        self._activeGroup = nil
        assert(ok, res)
        return res
    end

    for _, m in ipairs({
        "Toggle", "AddToggle", "AddCheckbox", "Button", "AddButton",
        "Slider", "AddSlider", "Dropdown", "AddDropdown",
        "Input", "AddInput", "Keybind", "AddKeybind",
        "Paragraph", "Code", "Image", "ProgressBar", "AddProgressBar", "Colorpicker", "AddColorPicker",
    }) do
        grp[m] = function(_, ...)
            return with_group(m, ...)
        end
    end

    function grp:Space() end

    function grp:Section(secCfg)
        local c = type(secCfg) == "table" and secCfg or { Title = tostring(secCfg or "Section") }
        c._group = grp
        local sub = self.ParentTab and self.ParentTab:Section(c) or self.ParentSection:Section(c)
        table.insert(grp.Sections, sub)
        return sub
    end

    return grp
end

function ContentSection:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self:SetVisible(false)

    for _, ctrl in ipairs(self.Controls) do
        if ctrl.Destroy then
            ctrl:Destroy()
        end
    end

    self.Drawings = {}
    self._drawings = {}
    self.Controls = {}
end

return ContentSection
