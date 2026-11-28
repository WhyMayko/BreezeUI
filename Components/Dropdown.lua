-- Library/BreezeUI/Components/Dropdown.lua
-- Responsive WindUI dropdown with pooled zero-leak popup, viewport clamping/flipping, hover highlight, and System font.

local ThemeModule = Theme or require("../Layout/Theme")
local AnimationsModule = Animations or require("../Engine/Animations")
local IconsModule = Icons or require("../Subsystems/Icons")

local Dropdown = {}
Dropdown.__index = Dropdown

local function compute_box_width(totalW)
    return math.min(140, math.max(76, math.floor(totalW * 0.38)))
end

local function item_label(val)
    if val == nil then return "" end
    if type(val) == "table" then
        if val.Type == "Divider" then return "---" end
        return tostring(val.Title or val.Text or val.Name or "")
    end
    return tostring(val)
end

local function format_display(value, isMulti)
    if isMulti then
        if type(value) ~= "table" then return tostring(value or "") end
        local parts = {}
        for _, v in ipairs(value) do
            table.insert(parts, item_label(v))
        end
        return #parts > 0 and table.concat(parts, ", ") or "None"
    end
    return value ~= nil and item_label(value) or "None"
end

function Dropdown:_resolveDynamicValues()
    if self.SpecialType == "Player" then
        local out = {}
        pcall(function()
            local pls = game:GetService("Players")
            local lp = pls.LocalPlayer
            for _, p in ipairs(pls:GetPlayers()) do
                if not (self.ExcludeLocalPlayer and p == lp) then
                    table.insert(out, p.Name)
                end
            end
        end)
        self.Values = out
    elseif self.SpecialType == "Team" then
        local out = {}
        pcall(function()
            local tms = game:GetService("Teams")
            for _, t in ipairs(tms:GetTeams()) do
                table.insert(out, t.Name)
            end
        end)
        self.Values = out
    end
end

function Dropdown.new(section, id, config)
    local cfg = config or {}
    local pos, size = section:AllocateControlSlot(cfg.Half or cfg.Column ~= nil, section.RowHeight or 44)
    local values = cfg.Values or {}
    local specialType = cfg.SpecialType or ((cfg.Type == "Player" or cfg.Type == "Team") and cfg.Type or nil)

    local self = setmetatable({
        Section = section,
        Id = id,
        Text = cfg.Text or cfg.Title or id,
        Values = values,
        SpecialType = specialType,
        ExcludeLocalPlayer = cfg.ExcludeLocalPlayer == true,
        SearchEnabled = (cfg.SearchBarEnabled == true) or (cfg.AllowSearch == true) or (cfg.Search == true),
        SearchQuery = "",
        AllowNone = cfg.AllowNone == true,
        Multi = cfg.Multi or false,
        Opened = false,
        IsOpen = false,
        Position = pos,
        Size = size,
        Visible = section.Visible,
        Callback = cfg.Callback or function() end,
        Items = {},
        VisibleItems = {},
        PopupBg = nil,
        PopupBorder = nil,
        PopupHoverBg = nil,
        SearchBg = nil,
        SearchText = nil,
        PopupItems = {},
        PopupDividers = {},
        PopupSelectedBgs = {},
        PopupDrawings = {},
        PopupRect = nil,
        HoverIndex = nil,
        ScrollOffset = 0,
        MaxScrollOffset = 0,
        MaxVisibleItems = cfg.MaxVisibleItems or 7,
        IsScrollingPopup = false,
        PopupScrollThumb = nil,
        OpenAnim = 1,
    }, Dropdown)

    self:_resolveDynamicValues()
    local initialVal = cfg.Default or cfg.Value or (self.Multi and {} or self.Values[1] or "")
    if type(initialVal) == "number" and self.Values[initialVal] ~= nil then
        initialVal = self.Values[initialVal]
    end
    self.Value = initialVal

    local pool = section.Pool
    if pool then
        local rowBgCol = ThemeModule.Get("ElementBackground")
        local boxBg = ThemeModule.Get("Control.Background")
        local txtCol = ThemeModule.Get("Text.Title")
        local subCol = ThemeModule.Get("Text.Secondary")
        local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

        -- 1. Integrated Row Background
        local rowBg = pool:Get("Square")
        rowBg.Position = pos
        rowBg.Size = size
        rowBg.Color = rowBgCol
        rowBg.Filled = true
        rowBg.Corner = 8
        rowBg.ZIndex = 4
        rowBg.Visible = section.Visible
        self.RowBg = rowBg
        section:_register(rowBg)

        -- 2. Title Label
        local lbl = pool:Get("Text")
        lbl.Text = self.Text
        lbl.Font = fontUI
        lbl.Outline = false
        lbl.Size = 13
        lbl.Color = txtCol
        lbl.Position = Vector2.new(pos.X + 14, pos.Y + math.floor((size.Y - 13) * 0.5))
        lbl.ZIndex = 5
        lbl.Visible = section.Visible
        self.Label = lbl
        section:_register(lbl)

        -- 3. Responsive Selection Box Pill
        local boxW = compute_box_width(size.X)
        local boxH = 26
        local boxX = pos.X + size.X - boxW - 14
        local boxY = pos.Y + math.floor((size.Y - boxH) * 0.5)

        local box = pool:Get("Square")
        box.Position = Vector2.new(boxX, boxY)
        box.Size = Vector2.new(boxW, boxH)
        box.Color = boxBg
        box.Filled = true
        box.Corner = 6
        box.ZIndex = 5
        box.Visible = section.Visible
        self.Box = box
        section:_register(box)

        -- 4. Value Badge
        local badge = pool:Get("Text")
        local dispText = format_display(self.Value, self.Multi)
        badge.Text = dispText
        badge.Font = fontUI
        badge.Outline = false
        badge.Size = 12
        badge.Color = subCol
        badge.Position = Vector2.new(boxX + 8, boxY + 6)
        badge.ZIndex = 6
        badge.Visible = section.Visible
        self.ValueBadge = badge
        section:_register(badge)

        -- 5. Chevrons Up/Down Icon (WindUI parity)
        local arrow = pool:Get("Image")
        arrow.Size = Vector2.new(13, 13)
        arrow.Position = Vector2.new(boxX + boxW - 19, boxY + 6)
        arrow.Transparency = 0.55
        arrow.ZIndex = 6
        arrow.Visible = section.Visible
        self.Arrow = arrow
        section:_register(arrow)
        IconsModule.Get("chevrons-up-down", function(png)
            if self.Arrow and png then self.Arrow.Data = png end
        end)
    end

    return self
end

function Dropdown:SetPosition(pos, size)
    self.Position = pos
    self.Size = size or self.Size

    if self.RowBg then
        self.RowBg.Position = pos
        self.RowBg.Size = self.Size
    end

    if self.Label then
        self.Label.Position = Vector2.new(pos.X + 14, pos.Y + math.floor((self.Size.Y - 13) * 0.5))
    end

    local boxW = compute_box_width(self.Size.X)
    local boxH = 26
    local boxX = pos.X + self.Size.X - boxW - 14
    local boxY = pos.Y + math.floor((self.Size.Y - boxH) * 0.5)

    if self.Box then
        self.Box.Position = Vector2.new(boxX, boxY)
        self.Box.Size = Vector2.new(boxW, boxH)
    end

    if self.ValueBadge then
        self.ValueBadge.Position = Vector2.new(boxX + 8, boxY + 6)
    end

    if self.Arrow then
        self.Arrow.Size = Vector2.new(13, 13)
        self.Arrow.Position = Vector2.new(boxX + boxW - 19, boxY + 6)
    end

    if self.Opened then
        self:_layoutPopup()
    end
end

function Dropdown:Set(val)
    self.Value = val
    if self.ValueBadge then
        self.ValueBadge.Text = format_display(self.Value, self.Multi)
    end

    local lib = self.Section and self.Section.Env
    if lib and lib.Options and rawget(lib.Options, self.Id) == self then
        self.Value = val
    end
    pcall(self.Callback, val)
end

function Dropdown:SetTitle(title)
    self.Text = tostring(title or "")
    if self.Label then
        self.Label.Text = self.Text
    end
end

function Dropdown:Lock(title)
    self.Locked = true
    if title ~= nil then self.LockedTitle = tostring(title) end
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Muted")
    end
end

function Dropdown:Unlock()
    self.Locked = false
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Title")
    end
end

function Dropdown:Refresh(newValues)
    if newValues ~= nil then
        self.Values = newValues
    else
        self:_resolveDynamicValues()
    end
    if self.Opened then
        self:_layoutPopup()
    end
end

function Dropdown:Select(val)
    if type(val) == "table" and (val.Type == "Divider" or val.Locked == true) then
        return
    end
    if type(val) == "table" and val.Callback then
        pcall(val.Callback, val)
    end
    if self.Multi then
        if type(self.Value) ~= "table" then self.Value = {} end
        local targetKey = item_label(val)
        local exists = false
        for i, v in ipairs(self.Value) do
            if v == val or item_label(v) == targetKey then
                table.remove(self.Value, i)
                exists = true
                break
            end
        end
        if not exists then
            table.insert(self.Value, val)
        end
        self:Set(self.Value)
        if self.Opened then self:_layoutPopup() end
    else
        if self.AllowNone and (self.Value == val or item_label(self.Value) == item_label(val)) then
            self:Set(nil)
        else
            self:Set(val)
        end
        self:Close()
    end
end

function Dropdown:Toggle()
    if self.Opened then
        self:Close()
    else
        self:Open()
    end
end

function Dropdown:_isSelected(val)
    local key = item_label(val)
    if self.Multi and type(self.Value) == "table" then
        for _, v in ipairs(self.Value) do
            if v == val or item_label(v) == key then return true end
        end
        return false
    end
    return self.Value == val or (self.Value ~= nil and item_label(self.Value) == key)
end

function Dropdown:_ensurePopupPrimitives()
    if self.PopupBg then return end
    local pool = self.Section and self.Section.Pool
    if not pool then return end

    local bg = pool:Get("Square")
    bg.Color = ThemeModule.Get("Card.Background")
    bg.Filled = true
    bg.Corner = 8
    bg.ZIndex = 14
    bg.Visible = false
    self.PopupBg = bg

    local border = pool:Get("Square")
    border.Color = ThemeModule.Get("Card.Border")
    border.Filled = false
    border.Thickness = 1
    border.Corner = 8
    border.ZIndex = 15
    border.Visible = false
    self.PopupBorder = border

    local hover = pool:Get("Square")
    hover.Color = ThemeModule.Get("Tab.ActiveBg")
    hover.Filled = true
    hover.Corner = 5
    hover.ZIndex = 15
    hover.Visible = false
    self.PopupHoverBg = hover

    table.insert(self.PopupDrawings, bg)
    table.insert(self.PopupDrawings, border)
    table.insert(self.PopupDrawings, hover)

    if not self.PopupScrollThumb then
        local st = pool:Get("Square")
        st.Color = ThemeModule.Get("Text.Muted")
        st.Filled = true
        st.Corner = 4
        st.Transparency = 0.28
        st.ZIndex = 18
        st.Visible = false
        self.PopupScrollThumb = st
        table.insert(self.PopupDrawings, st)
    end

    if self.SearchEnabled and not self.SearchBg then
        local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1
        local sBg = pool:Get("Square")
        sBg.Color = ThemeModule.Get("Control.Background")
        sBg.Filled = true
        sBg.Corner = 6
        sBg.ZIndex = 16
        sBg.Visible = false
        self.SearchBg = sBg

        local sTxt = pool:Get("Text")
        sTxt.Text = "Search..."
        sTxt.Font = fontUI
        sTxt.Outline = false
        sTxt.Size = 11
        sTxt.Color = ThemeModule.Get("Text.Secondary")
        sTxt.ZIndex = 17
        sTxt.Visible = false
        self.SearchText = sTxt

        table.insert(self.PopupDrawings, sBg)
        table.insert(self.PopupDrawings, sTxt)
    end
end

function Dropdown:RefreshSearchDisplay()
    if not self.SearchText then return end
    local win = self.Section and (self.Section.Window or (self.Section.ParentTab and self.Section.ParentTab.Window))
    local isFocused = (win ~= nil and win.FocusedDropdownSearch == self)
    if #self.SearchQuery > 0 then
        local caret = (isFocused and math.floor(os.clock() * 2) % 2 == 0) and "|" or ""
        self.SearchText.Text = self.SearchQuery .. caret
        self.SearchText.Color = ThemeModule.Get("Text.Title")
    elseif isFocused then
        self.SearchText.Text = (math.floor(os.clock() * 2) % 2 == 0) and "|" or ""
        self.SearchText.Color = ThemeModule.Get("Text.Title")
    else
        self.SearchText.Text = "Search..."
        self.SearchText.Color = ThemeModule.Get("Text.Secondary")
    end
end

function Dropdown:ProcessSearchKey(token)
    if not token then return end
    if token == "backspace" then
        self.SearchQuery = string.sub(self.SearchQuery, 1, math.max(0, #self.SearchQuery - 1))
    elseif token == "clear" then
        self.SearchQuery = ""
    elseif token == "enter" or token == "escape" then
        local win = self.Section and (self.Section.Window or (self.Section.ParentTab and self.Section.ParentTab.Window))
        if win and win.FocusedDropdownSearch == self then
            win.FocusedDropdownSearch = nil
        end
        return
    else
        self.SearchQuery = self.SearchQuery .. tostring(token)
    end
    if self.Opened then
        self.ScrollOffset = 0
        self:_layoutPopup()
    end
end

function Dropdown:_layoutPopup()
    local pool = self.Section and self.Section.Pool
    if not pool or not self.Values or #self.Values == 0 then
        self:Close()
        return
    end
    self:_ensurePopupPrimitives()

    local q = (self.SearchQuery or ""):lower()
    local filtered = {}
    for _, v in ipairs(self.Values) do
        if q == "" then
            table.insert(filtered, v)
        else
            local isDiv = type(v) == "table" and v.Type == "Divider"
            if not isDiv and item_label(v):lower():find(q, 1, true) then
                table.insert(filtered, v)
            end
        end
    end
    self.VisibleItems = filtered

    local win = self.Section and (self.Section.Window or (self.Section.ParentTab and self.Section.ParentTab.Window))
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1
    local maxVis = self.MaxVisibleItems or 7
    local total = #filtered
    local count = math.min(total, maxVis)
    self.MaxScrollOffset = math.max(0, total - count)
    self.ScrollOffset = math.clamp(self.ScrollOffset or 0, 0, self.MaxScrollOffset)
    local hasScroll = self.MaxScrollOffset > 0
    local itemH = 26
    local searchH = self.SearchEnabled and 30 or 0
    local popH = math.max(1, count) * itemH + 8 + searchH
    local boxW = compute_box_width(self.Size.X)
    local popW = math.max(boxW, 152)
    local popX = self.Position.X + self.Size.X - popW - 14
    local popY = self.Position.Y + self.Size.Y + 4

    local maxBoundY = 1040
    local minBoundX, maxBoundX = 8, 1912
    local cam = workspace and workspace.CurrentCamera
    if cam and cam.ViewportSize and cam.ViewportSize.Y > 0 then
        maxBoundY = cam.ViewportSize.Y - 8
        maxBoundX = cam.ViewportSize.X - 8
    end
    if win and win.Position and win.Size then
        minBoundX = win.Position.X + 8
        maxBoundX = math.min(maxBoundX, win.Position.X + win.Size.X - 8)
    end
    if popY + popH > maxBoundY and (self.Position.Y - popH - 4) >= 36 then
        popY = self.Position.Y - popH - 4
    end
    popX = math.clamp(popX, minBoundX, math.max(minBoundX, maxBoundX - popW))
    local anim = self.OpenAnim or 1
    popY = popY - math.floor((1 - anim) * 6 + 0.5)

    local listTop = popY + 4 + searchH
    local searchRect = self.SearchEnabled and { X = popX + 6, Y = popY + 6, W = popW - 12, H = 22 } or nil
    local scrollTrack = nil
    if hasScroll then
        local trackH = count * itemH
        local thumbH = math.max(18, math.floor(trackH * (count / total)))
        local ratio = self.MaxScrollOffset > 0 and (self.ScrollOffset / self.MaxScrollOffset) or 0
        local thumbY = listTop + math.floor(ratio * (trackH - thumbH))
        scrollTrack = { X = popX + popW - 12, Y = listTop, W = 12, H = trackH, ThumbH = thumbH }
        if self.PopupScrollThumb then
            self.PopupScrollThumb.Color = ThemeModule.Get("Text.Muted")
            self.PopupScrollThumb.Position = Vector2.new(popX + popW - 9, thumbY)
            self.PopupScrollThumb.Size = Vector2.new(5, thumbH)
            self.PopupScrollThumb.Visible = true
        end
    elseif self.PopupScrollThumb then
        self.PopupScrollThumb.Visible = false
    end

    self.PopupRect = {
        X = popX, Y = popY, W = popW, H = popH,
        ItemH = itemH, Count = count, ListTop = listTop,
        SearchRect = searchRect, ScrollTrack = scrollTrack,
        ItemRightPad = hasScroll and 10 or 4,
    }

    if self.PopupBg then
        self.PopupBg.Color = ThemeModule.Get("Card.Background")
        self.PopupBg.Position = Vector2.new(popX, popY)
        self.PopupBg.Size = Vector2.new(popW, popH)
        self.PopupBg.Transparency = 0.2 + anim * 0.8
        self.PopupBg.Visible = true
    end
    if self.PopupBorder then
        self.PopupBorder.Color = ThemeModule.Get("Card.Border")
        self.PopupBorder.Position = Vector2.new(popX, popY)
        self.PopupBorder.Size = Vector2.new(popW, popH)
        self.PopupBorder.Transparency = anim
        self.PopupBorder.Visible = true
    end
    if self.SearchBg and self.SearchText and searchRect then
        self.SearchBg.Color = ThemeModule.Get("Control.Background")
        self.SearchBg.Position = Vector2.new(searchRect.X, searchRect.Y)
        self.SearchBg.Size = Vector2.new(searchRect.W, searchRect.H)
        self.SearchBg.Visible = true
        self:RefreshSearchDisplay()
        self.SearchText.Position = Vector2.new(searchRect.X + 8, searchRect.Y + 5)
        self.SearchText.Visible = true
    end

    -- Reuse or grow cached text/divider/selected slots without leaking Pool objects
    for i = 1, count do
        local txt = self.PopupItems[i]
        if not txt then
            txt = pool:Get("Text")
            txt.Font = fontUI
            txt.Outline = false
            txt.Size = 12
            txt.ZIndex = 17
            self.PopupItems[i] = txt
            table.insert(self.PopupDrawings, txt)
        end
        local div = self.PopupDividers[i]
        if not div then
            div = pool:Get("Square")
            div.Filled = true
            div.ZIndex = 16
            div.Visible = false
            self.PopupDividers[i] = div
            table.insert(self.PopupDrawings, div)
        end
        local selBg = self.PopupSelectedBgs[i]
        if not selBg then
            selBg = pool:Get("Square")
            selBg.Filled = true
            selBg.Corner = 5
            selBg.ZIndex = 15
            selBg.Visible = false
            self.PopupSelectedBgs[i] = selBg
            table.insert(self.PopupDrawings, selBg)
        end

        local val = filtered[(self.ScrollOffset or 0) + i]
        local isDiv = type(val) == "table" and val.Type == "Divider"
        local isLock = type(val) == "table" and val.Locked == true
        local rowY = listTop + (i - 1) * itemH
        local rowW = popW - 4 - (hasScroll and 10 or 4)

        if isDiv then
            txt.Visible = false
            selBg.Visible = false
            div.Position = Vector2.new(popX + 10, rowY + math.floor(itemH * 0.5))
            div.Size = Vector2.new(rowW - 12, 1)
            div.Color = ThemeModule.Get("Card.Border")
            div.Visible = true
        else
            div.Visible = false
            local isSel = self:_isSelected(val)
            selBg.Position = Vector2.new(popX + 4, rowY)
            selBg.Size = Vector2.new(rowW, itemH)
            selBg.Color = ThemeModule.Get("Tab.ActiveBg")
            selBg.Visible = isSel

            txt.Text = item_label(val)
            if isLock then
                local cardC = ThemeModule.Get("Card.Background")
                local txtC = ThemeModule.Get("Text.Secondary")
                txt.Color = Color3.new(
                    (txtC.R or 0.5) * 0.45 + (cardC.R or 0.1) * 0.55,
                    (txtC.G or 0.5) * 0.45 + (cardC.G or 0.1) * 0.55,
                    (txtC.B or 0.5) * 0.45 + (cardC.B or 0.1) * 0.55
                )
            elseif isSel then
                txt.Color = ThemeModule.Get("Text.Title")
            else
                txt.Color = ThemeModule.Get("Text.Secondary")
            end
            txt.Position = Vector2.new(popX + 10, rowY + 6)
            txt.Visible = true
        end
    end
    for i = count + 1, #self.PopupItems do
        self.PopupItems[i].Visible = false
        if self.PopupDividers[i] then self.PopupDividers[i].Visible = false end
        if self.PopupSelectedBgs[i] then self.PopupSelectedBgs[i].Visible = false end
    end

    self:SetPopupHover(self.HoverIndex)
end

function Dropdown:Scroll(deltaSteps)
    if not self.Opened or (self.MaxScrollOffset or 0) <= 0 then return end
    local nextOff = math.clamp((self.ScrollOffset or 0) + (deltaSteps or 0), 0, self.MaxScrollOffset)
    if nextOff ~= self.ScrollOffset then
        self.ScrollOffset = nextOff
        self:_layoutPopup()
    end
end

function Dropdown:SetScrollRatio(ratio)
    if not self.Opened or (self.MaxScrollOffset or 0) <= 0 then return end
    local nextOff = math.clamp(math.floor(math.clamp(ratio or 0, 0, 1) * self.MaxScrollOffset + 0.5), 0, self.MaxScrollOffset)
    if nextOff ~= self.ScrollOffset then
        self.ScrollOffset = nextOff
        self:_layoutPopup()
    end
end

function Dropdown:SetPopupHover(idx)
    self.HoverIndex = idx
    if not self.PopupHoverBg then return end
    if self.Opened and idx and self.PopupRect and idx >= 1 and idx <= self.PopupRect.Count then
        local val = self.VisibleItems and self.VisibleItems[(self.ScrollOffset or 0) + idx]
        if type(val) == "table" and (val.Type == "Divider" or val.Locked == true) then
            self.PopupHoverBg.Visible = false
            return
        end
        local r = self.PopupRect
        local listTop = r.ListTop or (r.Y + 4)
        self.PopupHoverBg.Color = ThemeModule.Get("Tab.HoverBg")
        self.PopupHoverBg.Position = Vector2.new(r.X + 4, listTop + (idx - 1) * r.ItemH)
        self.PopupHoverBg.Size = Vector2.new(r.W - 4 - (r.ItemRightPad or 4), r.ItemH)
        self.PopupHoverBg.Visible = true
    else
        self.PopupHoverBg.Visible = false
    end
end

function Dropdown:Open()
    self:_resolveDynamicValues()
    local win = self.Section and (self.Section.Window or (self.Section.ParentTab and self.Section.ParentTab.Window))
    if win and win.OpenDropdown and win.OpenDropdown ~= self then
        win.OpenDropdown:Close()
    end
    self.ScrollOffset = 0
    self.Opened = true
    self.IsOpen = true
    self.OpenAnim = 0
    if win then win.OpenDropdown = self end
    self:_layoutPopup()
    AnimationsModule.Tween("dd_open_" .. tostring(self), 0, 1, 22, function(v)
        if not self.Opened then return end
        self.OpenAnim = v
        self:_layoutPopup()
    end)
end

function Dropdown:Close()
    self.Opened = false
    self.IsOpen = false
    self.HoverIndex = nil
    self.SearchQuery = ""
    self.ScrollOffset = 0
    self.IsScrollingPopup = false
    local win = self.Section and (self.Section.Window or (self.Section.ParentTab and self.Section.ParentTab.Window))
    if win then
        if win.OpenDropdown == self then win.OpenDropdown = nil end
        if win.FocusedDropdownSearch == self then win.FocusedDropdownSearch = nil end
    end
    if self.PopupBg then self.PopupBg.Visible = false end
    if self.PopupBorder then self.PopupBorder.Visible = false end
    if self.PopupHoverBg then self.PopupHoverBg.Visible = false end
    if self.PopupScrollThumb then self.PopupScrollThumb.Visible = false end
    if self.SearchBg then self.SearchBg.Visible = false end
    if self.SearchText then self.SearchText.Visible = false end
    for _, txt in ipairs(self.PopupItems) do
        txt.Visible = false
    end
    for _, div in ipairs(self.PopupDividers or {}) do
        div.Visible = false
    end
    for _, selBg in ipairs(self.PopupSelectedBgs or {}) do
        selBg.Visible = false
    end
end

function Dropdown:SetVisible(vis)
    self.Visible = vis
    if self.RowBg then self.RowBg.Visible = vis end
    if self.Box then self.Box.Visible = vis end
    if self.Label then self.Label.Visible = vis end
    if self.ValueBadge then self.ValueBadge.Visible = vis end
    if self.Arrow then self.Arrow.Visible = vis end
    if not vis and self.Opened then
        self:Close()
    end
end

function Dropdown:Destroy()
    self:SetVisible(false)
end

return Dropdown
