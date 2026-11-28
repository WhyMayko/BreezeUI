-- Library/BreezeUI/Components/Keybind.lua
-- Keybind component supporting both inline Toggle KeyPicker badges and standalone WindUI section rows.

local ThemeModule = Theme or require("../Layout/Theme")
local MetricsModule = Metrics or require("../Core/Metrics")

local Keybind = {}
Keybind.__index = Keybind

local function format_key(k)
    if k == nil then return "?" end
    return MetricsModule.KeyName(k)
end

local function normalize_key(k)
    if k == nil then return nil end
    if type(k) == "number" then return k end
    return MetricsModule.KeyCode(k) or k
end

local function is_blacklisted(blacklist, vk)
    if type(blacklist) ~= "table" then return false end
    local name = format_key(vk):lower()
    for k, v in pairs(blacklist) do
        if type(k) == "number" then
            local target = normalize_key(v)
            if target == vk or tostring(v):lower() == name then
                return true
            end
        elseif v == true then
            local target = normalize_key(k)
            if target == vk or tostring(k):lower() == name then
                return true
            end
        end
    end
    return false
end

function Keybind.new(parent, id, config)
    local cfg = config or {}
    local isStandalone = parent ~= nil and parent.AllocateControlSlot ~= nil
    local sec = isStandalone and parent or (parent and parent.Section)
    local win = (sec and (sec.Window or (sec.ParentTab and sec.ParentTab.Window)))
        or (parent and (parent.Window or (parent.ParentTab and parent.ParentTab.Window)))
    local pool = (sec and sec.Pool) or (parent and parent.Pool) or (win and win.Pool)

    local pos, size
    if isStandalone then
        local desc = cfg.Desc or cfg.Description
        local rowH = (desc and desc ~= "") and 54 or (sec.RowHeight or 44)
        pos, size = sec:AllocateControlSlot(cfg.Half or cfg.Column ~= nil, rowH)
    else
        pos = Vector2.new(0, 0)
        size = Vector2.new(44, 22)
    end

    local keyVal = normalize_key(cfg.Default ~= nil and cfg.Default or cfg.Value)
    local initialVis = false
    if isStandalone then
        initialVis = sec ~= nil and sec.Visible == true
    elseif parent then
        initialVis = parent.Visible == true
    end

    local self = setmetatable({
        Parent = not isStandalone and parent or nil,
        Section = sec,
        Window = win,
        Id = id,
        Standalone = isStandalone,
        Text = cfg.Text or cfg.Title or id,
        Desc = cfg.Desc or cfg.Description,
        Mode = cfg.Mode or "Toggle",
        CanChange = cfg.CanChange ~= false,
        Blacklist = cfg.Blacklist,
        SyncToggleState = cfg.SyncToggleState ~= false,
        Key = keyVal,
        Value = keyVal,
        KeyName = format_key(keyVal),
        Capturing = false,
        ActiveState = (cfg.Mode == "Always"),
        PrevHeld = false,
        Visible = initialVis,
        Callback = cfg.Callback or function() end,
        Changed = cfg.Changed,
        RowBg = nil,
        Label = nil,
        DescLabel = nil,
        BadgeBg = nil,
        BadgeText = nil,
        ModeMenu = nil,
        ModeMenuOpen = false,
        Position = pos,
        Size = size,
    }, Keybind)

    local function measure_text(str, sz)
        return #tostring(str or "") * (sz * 0.58)
    end

    if pool then
        local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1
        local badgeStr = "[" .. self.KeyName .. "]"
        local badgeW = math.max(40, math.floor(measure_text(badgeStr, 11) + 14))
        local badgeH = 22
        local textW = measure_text(badgeStr, 11)

        if isStandalone then
            local rowBg = pool:Get("Square")
            rowBg.Position = pos
            rowBg.Size = size
            rowBg.Color = ThemeModule.Get("ElementBackground")
            rowBg.Filled = true
            rowBg.Corner = 8
            rowBg.ZIndex = 4
            rowBg.Visible = self.Visible
            self.RowBg = rowBg
            sec:_register(rowBg)

            local lbl = pool:Get("Text")
            lbl.Text = self.Text
            lbl.Font = fontUI
            lbl.Outline = false
            lbl.Size = 13
            lbl.Color = ThemeModule.Get("Text.Title")
            local titleY = (self.Desc and self.Desc ~= "") and (pos.Y + 10) or (pos.Y + math.floor((size.Y - 13) * 0.5))
            lbl.Position = Vector2.new(pos.X + 14, titleY)
            lbl.ZIndex = 5
            lbl.Visible = self.Visible
            self.Label = lbl
            sec:_register(lbl)

            if self.Desc and self.Desc ~= "" then
                local dLbl = pool:Get("Text")
                dLbl.Text = self.Desc
                dLbl.Font = fontUI
                dLbl.Outline = false
                dLbl.Size = 11
                dLbl.Color = ThemeModule.Get("Text.Secondary")
                dLbl.Position = Vector2.new(pos.X + 14, pos.Y + 28)
                dLbl.ZIndex = 5
                dLbl.Visible = self.Visible
                self.DescLabel = dLbl
                sec:_register(dLbl)
            end

            local bx = pos.X + size.X - badgeW - 14
            local by = pos.Y + math.floor((size.Y - badgeH) * 0.5)
            local bg = pool:Get("Square")
            bg.Position = Vector2.new(bx, by)
            bg.Size = Vector2.new(badgeW, badgeH)
            bg.Color = ThemeModule.Get("Control.Background")
            bg.Filled = true
            bg.Corner = 5
            bg.ZIndex = 5
            bg.Visible = self.Visible
            self.BadgeBg = bg
            sec:_register(bg)

            local txt = pool:Get("Text")
            txt.Text = badgeStr
            txt.Font = fontUI
            txt.Outline = false
            txt.Center = false
            txt.Size = 11
            txt.Color = ThemeModule.Get("Text.Secondary")
            txt.ZIndex = 6
            txt.Visible = self.Visible
            self.BadgeText = txt
            self:_centerBadgeText(bx, by, badgeW, badgeH)
            sec:_register(txt)
        elseif parent and parent.Position and parent.Size then
            local trackW = parent.Track and parent.Track.Size and parent.Track.Size.X or 42
            local bx = parent.Position.X + parent.Size.X - trackW - badgeW - 22
            local by = parent.Position.Y + math.floor((parent.Size.Y - badgeH) * 0.5)
            self.Position = Vector2.new(bx, by)
            self.Size = Vector2.new(badgeW, badgeH)

            local bg = pool:Get("Square")
            bg.Position = self.Position
            bg.Size = self.Size
            bg.Color = ThemeModule.Get("Control.Background")
            bg.Filled = true
            bg.Corner = 5
            bg.ZIndex = 5
            bg.Visible = self.Visible
            self.BadgeBg = bg

            local txt = pool:Get("Text")
            txt.Text = badgeStr
            txt.Font = fontUI
            txt.Outline = false
            txt.Center = false
            txt.Size = 11
            txt.Color = ThemeModule.Get("Text.Secondary")
            txt.ZIndex = 6
            txt.Visible = self.Visible
            self.BadgeText = txt
            self:_centerBadgeText(bx, by, badgeW, badgeH)

            if sec and sec._register then
                sec:_register(bg)
                sec:_register(txt)
            end
        end
    end

    if win then
        win.Keybinds = win.Keybinds or {}
        table.insert(win.Keybinds, self)
    end

    return self
end

function Keybind:_getBadgeRect()
    local bw = self.BadgeBg and self.BadgeBg.Size and self.BadgeBg.Size.X or 40
    local bh = 22
    if self.Standalone then
        local bx = self.Position.X + self.Size.X - bw - 14
        local by = self.Position.Y + math.floor((self.Size.Y - bh) * 0.5)
        return bx, by, bw, bh
    elseif self.Parent and self.Parent.Position and self.Parent.Size then
        local trackW = (self.Parent.Type == "Checkbox") and 24 or 42
        local bx = self.Parent.Position.X + self.Parent.Size.X - trackW - bw - 22
        local by = self.Parent.Position.Y + math.floor((self.Parent.Size.Y - bh) * 0.5)
        return bx, by, bw, bh
    end
    return self.Position.X, self.Position.Y, bw, bh
end

function Keybind:_centerBadgeText(bx, by, bw, bh)
    if not self.BadgeText then return end
    self.BadgeText.Center = false
    local str = tostring(self.BadgeText.Text or "")
    local ax, ay = MetricsModule.AlignCenter(bx, by, bw, bh, str, 11)
    self.BadgeText.Position = Vector2.new(ax, ay)
end

function Keybind:SetPosition(pos, size)
    self.Position = pos
    if size then self.Size = size end

    local badgeW = self.BadgeBg and self.BadgeBg.Size and self.BadgeBg.Size.X or 40
    local badgeH = 22

    if self.Standalone then
        if self.RowBg then
            self.RowBg.Position = pos
            self.RowBg.Size = self.Size
        end
        if self.Label then
            local titleY = (self.Desc and self.Desc ~= "") and (pos.Y + 10) or (pos.Y + math.floor((self.Size.Y - 13) * 0.5))
            self.Label.Position = Vector2.new(pos.X + 14, titleY)
        end
        if self.DescLabel then
            self.DescLabel.Position = Vector2.new(pos.X + 14, pos.Y + 28)
        end
        local bx = pos.X + self.Size.X - badgeW - 14
        local by = pos.Y + math.floor((self.Size.Y - badgeH) * 0.5)
        if self.BadgeBg then
            self.BadgeBg.Position = Vector2.new(bx, by)
            self.BadgeBg.Size = Vector2.new(badgeW, badgeH)
        end
        self:_centerBadgeText(bx, by, badgeW, badgeH)
    else
        local bx = pos.X
        local by = pos.Y
        if self.Parent and self.Parent.Position and self.Parent.Size then
            local trackW = self.Parent.Track and self.Parent.Track.Size and self.Parent.Track.Size.X or 42
            bx = self.Parent.Position.X + self.Parent.Size.X - trackW - badgeW - 22
            by = self.Parent.Position.Y + math.floor((self.Parent.Size.Y - badgeH) * 0.5)
            self.Position = Vector2.new(bx, by)
            self.Size = Vector2.new(badgeW, badgeH)
        end
        if self.BadgeBg then
            self.BadgeBg.Position = Vector2.new(bx, by)
            self.BadgeBg.Size = Vector2.new(badgeW, badgeH)
        end
        self:_centerBadgeText(bx, by, badgeW, badgeH)
    end
end

function Keybind:SetVisible(vis)
    self.Visible = vis
    if self.RowBg then self.RowBg.Visible = vis end
    if self.Label then self.Label.Visible = vis end
    if self.DescLabel then self.DescLabel.Visible = vis end
    if self.BadgeBg then self.BadgeBg.Visible = vis end
    if self.BadgeText then self.BadgeText.Visible = vis end
    if not vis and self.ModeMenuOpen then
        self:CloseModeMenu()
    end
end

function Keybind:Set(vk)
    local resolved = normalize_key(vk)
    self.Key = resolved
    self.Value = resolved
    self.KeyName = format_key(resolved)

    local badgeStr = "[" .. self.KeyName .. "]"
    local badgeW = math.max(40, MetricsModule.Measure(badgeStr, 11) + 14)
    if self.BadgeBg then
        self.BadgeBg.Size = Vector2.new(badgeW, 22)
    end
    if self.BadgeText then
        self.BadgeText.Text = badgeStr
    end
    self:SetPosition(self.Position, self.Size)

    local lib = self.Section and self.Section.Env
    if lib and lib.Options and rawget(lib.Options, self.Id) == self then
        self.Value = resolved
    end
    if self.Changed then
        pcall(self.Changed, resolved)
    end
end
Keybind.SetValue = Keybind.Set

function Keybind:GetState()
    if self.Mode == "Always" then return true end
    return self.ActiveState == true
end

function Keybind:SetMode(mode)
    if mode ~= "Toggle" and mode ~= "Hold" and mode ~= "Always" then return end
    self.Mode = mode
    self.ActiveState = (mode == "Always")
    if self.Parent and self.SyncToggleState and self.Parent.Set then
        self.Parent:Set(self.ActiveState)
    end
    pcall(self.Callback, self.ActiveState)
end

local mode_list = { "Toggle", "Hold", "Always" }

function Keybind:OpenModeMenu()
    if self.Locked then return end
    local win = self.Window or (self.Parent and self.Parent.Section and self.Parent.Section.Window)
    local pool = (self.Section and self.Section.Pool) or (win and win.Pool)
    if not pool then return end

    if win and win.OpenKeybindMenu and win.OpenKeybindMenu ~= self then
        win.OpenKeybindMenu:CloseModeMenu()
    end
    if win then
        win.OpenKeybindMenu = self
    end

    if not self.ModeMenu then
        local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1
        local menu = {
            Bg = pool:Get("Square"),
            Border = pool:Get("Square"),
            Rows = {},
        }
        menu.Bg.Filled = true
        menu.Bg.Corner = 6
        menu.Bg.ZIndex = 30
        menu.Bg.Visible = false

        menu.Border.Filled = false
        menu.Border.Thickness = 1
        menu.Border.Corner = 6
        menu.Border.ZIndex = 31
        menu.Border.Visible = false

        for i = 1, 3 do
            local rBg = pool:Get("Square")
            rBg.Filled = true
            rBg.Corner = 4
            rBg.ZIndex = 31
            rBg.Visible = false
            local rTxt = pool:Get("Text")
            rTxt.Font = fontUI
            rTxt.Outline = false
            rTxt.Size = 12
            rTxt.Text = mode_list[i]
            rTxt.ZIndex = 32
            rTxt.Visible = false
            menu.Rows[i] = { Bg = rBg, Text = rTxt, Mode = mode_list[i], Rect = nil }
        end

        if self.Section and self.Section._register then
            self.Section:_register(menu.Bg)
            self.Section:_register(menu.Border)
            for _, row in ipairs(menu.Rows) do
                self.Section:_register(row.Bg)
                self.Section:_register(row.Text)
            end
        end
        self.ModeMenu = menu
    end

    local bx, by, bw, bh = self:_getBadgeRect()
    local mw = 84
    local rowH = 22
    local mh = 8 + #mode_list * rowH
    local mx = bx + bw - mw
    local my = by + bh + 4
    local cam = workspace and workspace.CurrentCamera
    if cam and cam.ViewportSize and cam.ViewportSize.X > 0 and cam.ViewportSize.Y > 0 then
        local vp = cam.ViewportSize
        mx = math.clamp(mx, 8, math.max(8, vp.X - mw - 8))
        if my + mh > vp.Y - 8 and (by - mh - 4) >= 8 then
            my = by - mh - 4
        end
    end

    local menu = self.ModeMenu
    menu.Rect = { X = mx, Y = my, W = mw, H = mh }
    menu.Bg.Position = Vector2.new(mx, my)
    menu.Bg.Size = Vector2.new(mw, mh)
    menu.Bg.Color = ThemeModule.Get("Card.Background")
    menu.Bg.Visible = true

    menu.Border.Position = Vector2.new(mx, my)
    menu.Border.Size = Vector2.new(mw, mh)
    menu.Border.Color = ThemeModule.Get("Window.Border")
    menu.Border.Visible = true

    for i, row in ipairs(menu.Rows) do
        local rx = mx + 4
        local ry = my + 4 + (i - 1) * rowH
        local rw = mw - 8
        local selected = self.Mode == row.Mode
        row.Rect = { X = rx, Y = ry, W = rw, H = rowH }
        row.Bg.Position = Vector2.new(rx, ry)
        row.Bg.Size = Vector2.new(rw, rowH - 2)
        row.Bg.Color = ThemeModule.Get(selected and "Tab.ActiveBg" or "Card.Background")
        row.Bg.Visible = selected
        row.Text.Position = Vector2.new(rx + 8, ry + 4)
        row.Text.Color = ThemeModule.Get(selected and "Text.Title" or "Text.Secondary")
        row.Text.Visible = true
    end

    self.ModeMenuOpen = true
end

function Keybind:CloseModeMenu()
    self.ModeMenuOpen = false
    local win = self.Window or (self.Parent and self.Parent.Section and self.Parent.Section.Window)
    if win and win.OpenKeybindMenu == self then
        win.OpenKeybindMenu = nil
    end
    if self.ModeMenu then
        if self.ModeMenu.Bg then self.ModeMenu.Bg.Visible = false end
        if self.ModeMenu.Border then self.ModeMenu.Border.Visible = false end
        for _, row in ipairs(self.ModeMenu.Rows) do
            if row.Bg then row.Bg.Visible = false end
            if row.Text then row.Text.Visible = false end
        end
    end
end

function Keybind:UpdateModeMenu(mx, my, m1Clicked, m2Clicked)
    if not self.ModeMenuOpen or not self.ModeMenu then return false end
    local r = self.ModeMenu.Rect
    if not r then
        self:CloseModeMenu()
        return false
    end
    local overMenu = mx >= r.X and mx <= r.X + r.W and my >= r.Y and my <= r.Y + r.H
    if not overMenu then
        if m1Clicked or m2Clicked then
            self:CloseModeMenu()
        end
        return false
    end
    if m1Clicked then
        for _, row in ipairs(self.ModeMenu.Rows) do
            local rr = row.Rect
            if rr and mx >= rr.X and mx <= rr.X + rr.W and my >= rr.Y and my <= rr.Y + rr.H then
                self:SetMode(row.Mode)
                self:CloseModeMenu()
                return true
            end
        end
    end
    return true
end

function Keybind:StartCapture()
    if self.Locked or not self.CanChange or self.Capturing then return end
    if self.ModeMenuOpen then self:CloseModeMenu() end
    self.Capturing = true
    self.CaptureStarted = os.clock()
    if self.BadgeText then
        self.BadgeText.Text = "[...]"
        self.BadgeText.Color = ThemeModule.Get("Accent.Blue")
        local bx, by, bw, bh = self:_getBadgeRect()
        self:_centerBadgeText(bx, by, bw, bh)
        if self.Visible and self._clipTop and self._clipBottom and self.Section and self.Section.ClipControl then
            self.Section.ClipControl(self, self._clipTop, self._clipBottom)
        end
    end
    local win = self.Window or (self.Parent and self.Parent.Section and self.Parent.Section.Window)
    if win then
        if win.Input and win.Input.PrevKeys then
            for k = 4, 6 do win.Input.PrevKeys[k] = (iskeypressed(k) == true) end
        end
        win.CapturingKeybind = self
        if win.ClaimInteraction then
            win:ClaimInteraction("KeyPicker_" .. tostring(self.Id))
        end
    end
end

function Keybind:CancelCapture()
    self.Capturing = false
    if self.BadgeText then
        self.BadgeText.Text = "[" .. self.KeyName .. "]"
        self.BadgeText.Color = ThemeModule.Get("Text.Secondary")
        local bx, by, bw, bh = self:_getBadgeRect()
        self:_centerBadgeText(bx, by, bw, bh)
        if self.Visible and self._clipTop and self._clipBottom and self.Section and self.Section.ClipControl then
            self.Section.ClipControl(self, self._clipTop, self._clipBottom)
        end
    end
    local win = self.Window or (self.Parent and self.Parent.Section and self.Parent.Section.Window)
    if win then
        if win.CapturingKeybind == self then
            win.CapturingKeybind = nil
        end
        if win.ReleaseInteraction then
            win:ReleaseInteraction("KeyPicker_" .. tostring(self.Id))
        end
    end
end

function Keybind:Clear()
    self:Set(nil)
    self:CancelCapture()
    pcall(self.Callback, nil)
end

function Keybind:ProcessInput(vk)
    if not self.Capturing then return end
    if vk == 27 then
        self:CancelCapture()
        return
    end
    if is_blacklisted(self.Blacklist, vk) then
        return
    end
    local win = self.Window or (self.Parent and self.Parent.Section and self.Parent.Section.Window)
    if win and win.Input and win.Input.PrevKeys then
        win.Input.PrevKeys[vk] = true
    end
    self:Set(vk)
    self:CancelCapture()
    pcall(self.Callback, self.Key)
end

function Keybind:HandleClick(mx, my)
    if self.Locked or not self.CanChange then return false end
    self:StartCapture()
    return true
end

function Keybind:SetTitle(title)
    self.Text = tostring(title or "")
    if self.Label then
        self.Label.Text = self.Text
    end
end

function Keybind:SetDesc(desc)
    self.Desc = desc ~= nil and tostring(desc) or ""
    if self.DescLabel then
        self.DescLabel.Text = self.Desc
    end
end

function Keybind:Lock(title)
    self.Locked = true
    if title ~= nil then self.LockedTitle = tostring(title) end
    if self.Capturing then self:CancelCapture() end
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Muted")
    end
end

function Keybind:Unlock()
    self.Locked = false
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Title")
    end
end

function Keybind:Destroy()
    if self.Capturing then self:CancelCapture() end
    self:SetVisible(false)
end

return Keybind
