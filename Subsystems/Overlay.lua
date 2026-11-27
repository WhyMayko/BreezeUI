-- Library/BreezeUI/Subsystems/Overlay.lua
-- Floating HUD overlays: WindUI OpenButton pill, Obsidian KeybindMenu, and draggable Watermark.

local PoolModule = require("../Core/Pool")
local MetaModule = require("../Core/Meta")
local ThemeModule = require("../Layout/Theme")
local IconsModule = require("./Icons")
local MetricsModule = require("../Core/Metrics")

local Overlay = {
    Pool = nil,
    OpenSlot = nil,
    KeySlot = nil,
    WmSlot = nil,
    PrevM1 = false,
}

local function get_theme(key, fallback)
    if ThemeModule and ThemeModule.Get then
        return ThemeModule.Get(key, fallback)
    end
    return fallback
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function get_viewport()
    local cam = workspace and workspace.CurrentCamera
    if cam and cam.ViewportSize and cam.ViewportSize.X > 0 and cam.ViewportSize.Y > 0 then
        return cam.ViewportSize
    end
    return Vector2.new(1920, 1080)
end

local function ensure_pool()
    if not Overlay.Pool or Overlay.Pool.Destroyed then
        Overlay.Pool = PoolModule.new(nil, MetaModule)
        Overlay.OpenSlot = nil
        Overlay.KeySlot = nil
        Overlay.WmSlot = nil
    end
    return Overlay.Pool
end

local function hide_open_slot()
    local s = Overlay.OpenSlot
    if not s then return end
    s.Bg.Visible = false
    s.Border.Visible = false
    s.DragIcon.Visible = false
    s.Divider.Visible = false
    s.IconImg.Visible = false
    s.TitleText.Visible = false
end

local function ensure_open_slot()
    if Overlay.OpenSlot then return Overlay.OpenSlot end
    local pool = ensure_pool()
    local s = {
        Bg = pool:Get("Square"),
        Border = pool:Get("Square"),
        DragIcon = pool:Get("Image"),
        Divider = pool:Get("Square"),
        IconImg = pool:Get("Image"),
        TitleText = pool:Get("Text"),
    }
    s.Bg.Filled = true
    s.Bg.Corner = 20
    s.Bg.ZIndex = 30
    s.Bg.Visible = false

    s.Border.Filled = false
    s.Border.Thickness = 1.5
    s.Border.Corner = 20
    s.Border.ZIndex = 31
    s.Border.Visible = false

    s.DragIcon.Size = Vector2.new(15, 15)
    s.DragIcon.ZIndex = 32
    s.DragIcon.Visible = false

    s.Divider.Filled = true
    s.Divider.ZIndex = 32
    s.Divider.Visible = false

    s.IconImg.Size = Vector2.new(18, 18)
    s.IconImg.ZIndex = 32
    s.IconImg.Visible = false

    s.TitleText.Size = 14
    s.TitleText.ZIndex = 32
    s.TitleText.Visible = false

    Overlay.OpenSlot = s
    return s
end

local function hide_key_slot()
    local s = Overlay.KeySlot
    if not s then return end
    s.Bg.Visible = false
    s.Border.Visible = false
    s.HeaderText.Visible = false
    s.Divider.Visible = false
    s.EmptyText.Visible = false
    for _, r in ipairs(s.Rows) do
        r.Dot.Visible = false
        r.Name.Visible = false
        r.Key.Visible = false
    end
end

local function ensure_key_slot()
    if Overlay.KeySlot then return Overlay.KeySlot end
    local pool = ensure_pool()
    local s = {
        Bg = pool:Get("Square"),
        Border = pool:Get("Square"),
        HeaderText = pool:Get("Text"),
        Divider = pool:Get("Square"),
        EmptyText = pool:Get("Text"),
        Rows = {},
    }
    s.Bg.Filled = true
    s.Bg.Corner = 10
    s.Bg.ZIndex = 34
    s.Bg.Visible = false

    s.Border.Filled = false
    s.Border.Thickness = 1
    s.Border.Corner = 10
    s.Border.ZIndex = 35
    s.Border.Visible = false

    s.HeaderText.Size = 14
    s.HeaderText.Text = "Keybinds"
    s.HeaderText.ZIndex = 36
    s.HeaderText.Visible = false

    s.Divider.Filled = true
    s.Divider.ZIndex = 36
    s.Divider.Visible = false

    s.EmptyText.Size = 12
    s.EmptyText.Text = "No active keybinds"
    s.EmptyText.ZIndex = 36
    s.EmptyText.Visible = false

    for i = 1, 10 do
        local dot = pool:Get("Square")
        dot.Filled = true
        dot.Corner = 3
        dot.Size = Vector2.new(6, 6)
        dot.ZIndex = 36
        dot.Visible = false
        local nm = pool:Get("Text")
        nm.Size = 13
        nm.ZIndex = 36
        nm.Visible = false
        local ky = pool:Get("Text")
        ky.Size = 12
        ky.ZIndex = 36
        ky.Visible = false
        s.Rows[i] = { Dot = dot, Name = nm, Key = ky }
    end

    Overlay.KeySlot = s
    return s
end

local function hide_wm_slot()
    local s = Overlay.WmSlot
    if not s then return end
    s.Bg.Visible = false
    s.Border.Visible = false
    s.AccentBar.Visible = false
    for _, t in ipairs(s.Tokens) do
        t.Visible = false
    end
end

local function ensure_wm_slot()
    if Overlay.WmSlot then return Overlay.WmSlot end
    local pool = ensure_pool()
    local s = {
        Bg = pool:Get("Square"),
        Border = pool:Get("Square"),
        AccentBar = pool:Get("Square"),
        Tokens = {},
    }
    s.Bg.Filled = true
    s.Bg.Corner = 6
    s.Bg.ZIndex = 37
    s.Bg.Visible = false

    s.Border.Filled = false
    s.Border.Thickness = 1
    s.Border.Corner = 6
    s.Border.ZIndex = 38
    s.Border.Visible = false

    s.AccentBar.Filled = true
    s.AccentBar.Corner = 2
    s.AccentBar.ZIndex = 39
    s.AccentBar.Visible = false

    for i = 1, 8 do
        local t = pool:Get("Text")
        t.Size = 13
        t.ZIndex = 39
        t.Visible = false
        s.Tokens[i] = t
    end

    Overlay.WmSlot = s
    return s
end

local function collect_keybind_rows(window)
    local rows = {}
    if not window or not window.Tabs then return rows end
    for _, tab in ipairs(window.Tabs) do
        local cards = tab.Sections or tab.Cards or {}
        for _, card in ipairs(cards) do
            for _, ctrl in ipairs(card.Controls or {}) do
                if ctrl.KeyPicker and not ctrl.KeyPicker.HideFromKeybindList then
                    local kp = ctrl.KeyPicker
                    table.insert(rows, {
                        Name = tostring(ctrl.Text or ctrl.Title or kp.Text or kp.Id or "Key"),
                        Key = "[" .. tostring(kp.KeyName or "?") .. "]",
                        Mode = kp.Mode or "Toggle",
                        Active = (ctrl.Value == true) or (kp.ActiveState == true),
                    })
                elseif ctrl.Capturing ~= nil and ctrl.KeyName ~= nil and not ctrl.HideFromKeybindList and ctrl.Id ~= "SettingsMinimizeKey" then
                    table.insert(rows, {
                        Name = tostring(ctrl.Text or ctrl.Id or "Key"),
                        Key = "[" .. tostring(ctrl.KeyName or "?") .. "]",
                        Mode = ctrl.Mode or "Toggle",
                        Active = ctrl.ActiveState == true,
                    })
                end
                if #rows >= 10 then return rows end
            end
        end
    end
    return rows
end

local function update_open_button(window, vp, mx, my, m1Pressed, m1Clicked)
    local ob = window.OpenButton
    local shouldShow = (not window.Visible) and ob and ob.Enabled ~= false
    if not shouldShow then
        hide_open_slot()
        return false
    end

    local slot = ensure_open_slot()
    local draggable = ob.Draggable ~= false
    local onlyIcon = ob.OnlyIcon == true
    local titleStr = tostring(ob.Title or window.Title or "Open")
    local iconName = ob.Icon or window.Icon or "wind"

    if ob._dragData == nil and IconsModule and IconsModule.Get then
        ob._dragData = IconsModule.Get("move", function(png) ob._dragData = png end)
    end
    if iconName ~= ob._lastIconName and IconsModule and IconsModule.Get then
        ob._lastIconName = iconName
        ob._iconData = IconsModule.Get(iconName, function(png) ob._iconData = png end)
    end

    local h = 40
    local dragW = draggable and 30 or 0
    local iconW = ob._iconData and 22 or 0
    local textW = onlyIcon and 0 or (MetricsModule and MetricsModule.GetTextWidth
        and math.floor(MetricsModule.GetTextWidth(titleStr, 14, 1) * 1.15 + 0.5)
        or math.floor(#titleStr * 7.6))
    local padX = 14
    local w = math.max(44, dragW + padX + iconW + ((iconW > 0 and textW > 0) and 8 or 0) + textW + padX)

    if not ob.Position then
        ob.Position = Vector2.new(math.floor((vp.X - w) * 0.5), 14)
    end

    local px = clamp(ob.Position.X, 8, math.max(8, vp.X - w - 8))
    local py = clamp(ob.Position.Y, 8, math.max(8, vp.Y - h - 8))

    local consumed = false
    if ob._dragging then
        if m1Pressed then
            px = clamp(mx - ob._dragOffX, 8, math.max(8, vp.X - w - 8))
            py = clamp(my - ob._dragOffY, 8, math.max(8, vp.Y - h - 8))
            ob.Position = Vector2.new(px, py)
        else
            ob._dragging = false
        end
    elseif m1Clicked then
        if draggable and mx >= px and mx <= px + dragW and my >= py and my <= py + h then
            ob._dragging = true
            ob._dragOffX = mx - px
            ob._dragOffY = my - py
            consumed = true
        elseif mx >= px + dragW and mx <= px + w and my >= py and my <= py + h then
            consumed = true
            window:SetVisible(true)
            hide_open_slot()
            return true
        end
    end

    local overBtn = mx >= px + dragW and mx <= px + w and my >= py and my <= py + h
    local bgCol = overBtn and get_theme("Button.Hover", Color3.fromRGB(36, 36, 44))
        or get_theme("Window.Background", Color3.fromRGB(18, 18, 22))
    local borderCol = ob.Color or get_theme("Accent", Color3.fromRGB(80, 175, 255))
    local textCol = get_theme("Text.Title", Color3.fromRGB(255, 255, 255))

    slot.Bg.Position = Vector2.new(px, py)
    slot.Bg.Size = Vector2.new(w, h)
    slot.Bg.Color = bgCol
    slot.Bg.Transparency = 0.92
    slot.Bg.Visible = true

    slot.Border.Position = Vector2.new(px, py)
    slot.Border.Size = Vector2.new(w, h)
    slot.Border.Color = borderCol
    slot.Border.Transparency = 0.88
    slot.Border.Visible = true

    if draggable then
        if ob._dragData then
            slot.DragIcon.Data = ob._dragData
            slot.DragIcon.Color = textCol
            slot.DragIcon.Position = Vector2.new(px + 10, py + 12)
            slot.DragIcon.Transparency = 0.55
            slot.DragIcon.Visible = true
        else
            slot.DragIcon.Visible = false
        end
        slot.Divider.Position = Vector2.new(px + dragW, py + 8)
        slot.Divider.Size = Vector2.new(1, h - 16)
        slot.Divider.Color = get_theme("Window.Border", Color3.fromRGB(52, 52, 60))
        slot.Divider.Transparency = 0.85
        slot.Divider.Visible = true
    else
        slot.DragIcon.Visible = false
        slot.Divider.Visible = false
    end

    local curX = px + dragW + padX
    if ob._iconData then
        slot.IconImg.Data = ob._iconData
        slot.IconImg.Color = textCol
        slot.IconImg.Position = Vector2.new(curX, py + 11)
        slot.IconImg.Transparency = 1
        slot.IconImg.Visible = true
        curX = curX + 24
    else
        slot.IconImg.Visible = false
    end

    if not onlyIcon then
        slot.TitleText.Text = titleStr
        slot.TitleText.Color = textCol
        slot.TitleText.Position = Vector2.new(curX, py + 12)
        slot.TitleText.Visible = true
    else
        slot.TitleText.Visible = false
    end

    return consumed
end

local function update_keybind_menu(window, vp, mx, my, m1Pressed, m1Clicked)
    if not window.ShowKeybindMenu then
        hide_key_slot()
        return false
    end

    local slot = ensure_key_slot()
    local rows = collect_keybind_rows(window)
    local w = window.KeybindMenuWidth or 240
    local headerH = 30
    local rowH = 22
    local h = headerH + 10 + math.max(1, #rows) * rowH + 6

    if window.KeybindMenuX == nil then
        window.KeybindMenuX = 14
        window.KeybindMenuY = math.floor((vp.Y - h) * 0.5)
    end

    local px = clamp(window.KeybindMenuX, 6, math.max(6, vp.X - w - 6))
    local py = clamp(window.KeybindMenuY, 6, math.max(6, vp.Y - h - 6))

    local consumed = false
    if window._kmDragging then
        if m1Pressed then
            px = clamp(mx - window._kmDragOffX, 6, math.max(6, vp.X - w - 6))
            py = clamp(my - window._kmDragOffY, 6, math.max(6, vp.Y - h - 6))
            window.KeybindMenuX, window.KeybindMenuY = px, py
        else
            window._kmDragging = false
        end
    elseif m1Clicked and mx >= px and mx <= px + w and my >= py and my <= py + headerH then
        window._kmDragging = true
        window._kmDragOffX = mx - px
        window._kmDragOffY = my - py
        consumed = true
    end

    local bgCol = get_theme("Window.Background", Color3.fromRGB(18, 18, 22))
    local borderCol = get_theme("Window.Border", Color3.fromRGB(44, 44, 52))
    local titleCol = get_theme("Text.Title", Color3.fromRGB(255, 255, 255))
    local mutedCol = get_theme("Text.Secondary", Color3.fromRGB(160, 160, 170))
    local accentCol = window.Accent or get_theme("Accent", Color3.fromRGB(59, 130, 246))

    slot.Bg.Position = Vector2.new(px, py)
    slot.Bg.Size = Vector2.new(w, h)
    slot.Bg.Color = bgCol
    slot.Bg.Transparency = 0.94
    slot.Bg.Visible = true

    slot.Border.Position = Vector2.new(px, py)
    slot.Border.Size = Vector2.new(w, h)
    slot.Border.Color = borderCol
    slot.Border.Visible = true

    slot.HeaderText.Color = titleCol
    slot.HeaderText.Position = Vector2.new(px + 12, py + 8)
    slot.HeaderText.Visible = true

    slot.Divider.Position = Vector2.new(px + 10, py + headerH)
    slot.Divider.Size = Vector2.new(w - 20, 1)
    slot.Divider.Color = borderCol
    slot.Divider.Visible = true

    if #rows == 0 then
        slot.EmptyText.Color = mutedCol
        slot.EmptyText.Position = Vector2.new(px + 12, py + headerH + 10)
        slot.EmptyText.Visible = true
        for _, r in ipairs(slot.Rows) do
            r.Dot.Visible = false
            r.Name.Visible = false
            r.Key.Visible = false
        end
    else
        slot.EmptyText.Visible = false
        for i = 1, 10 do
            local rSlot = slot.Rows[i]
            local row = rows[i]
            if row then
                local ry = py + headerH + 8 + (i - 1) * rowH
                rSlot.Dot.Position = Vector2.new(px + 12, ry + 5)
                rSlot.Dot.Color = row.Active and accentCol or borderCol
                rSlot.Dot.Visible = true

                rSlot.Name.Text = MetricsModule and MetricsModule.Fit
                    and MetricsModule.Fit(row.Name, w - 82, 13, 1)
                    or row.Name
                rSlot.Name.Color = row.Active and titleCol or mutedCol
                rSlot.Name.Position = Vector2.new(px + 24, ry + 1)
                rSlot.Name.Visible = true

                local kw = math.floor(#row.Key * 6.6)
                rSlot.Key.Text = row.Key
                rSlot.Key.Color = row.Active and accentCol or mutedCol
                rSlot.Key.Position = Vector2.new(px + w - kw - 12, ry + 2)
                rSlot.Key.Visible = true
            else
                rSlot.Dot.Visible = false
                rSlot.Name.Visible = false
                rSlot.Key.Visible = false
            end
        end
    end

    return consumed
end

local function update_watermark(window, vp, mx, my, m1Pressed, m1Clicked)
    local wm = window.Watermark
    if not wm or wm.Visible ~= true or not wm.Text or wm.Text == "" then
        hide_wm_slot()
        return false
    end

    local slot = ensure_wm_slot()
    local pieces = {}
    if wm.Tokens and #wm.Tokens > 1 then
        for i, tok in ipairs(wm.Tokens) do
            table.insert(pieces, { Text = tostring(tok), Accent = (i == 1) })
            if i < #wm.Tokens then
                table.insert(pieces, { Text = " | ", Muted = true })
            end
        end
    else
        table.insert(pieces, { Text = tostring(wm.Text), Accent = false })
    end

    local totalTextW = 0
    for _, p in ipairs(pieces) do
        local pw = math.floor(#p.Text * 7.0)
        p.Width = pw
        totalTextW = totalTextW + pw
    end
    local w = math.max(60, totalTextW + 24)
    local h = 28

    local px = clamp(wm.X or 16, 6, math.max(6, vp.X - w - 6))
    local py = clamp(wm.Y or 16, 6, math.max(6, vp.Y - h - 6))

    local consumed = false
    if wm._dragging then
        if m1Pressed then
            px = clamp(mx - wm._dragOffX, 6, math.max(6, vp.X - w - 6))
            py = clamp(my - wm._dragOffY, 6, math.max(6, vp.Y - h - 6))
            wm.X, wm.Y = px, py
        else
            wm._dragging = false
        end
    elseif m1Clicked and mx >= px and mx <= px + w and my >= py and my <= py + h then
        wm._dragging = true
        wm._dragOffX = mx - px
        wm._dragOffY = my - py
        consumed = true
    end

    local bgCol = get_theme("Window.Background", Color3.fromRGB(18, 18, 22))
    local borderCol = get_theme("Window.Border", Color3.fromRGB(44, 44, 52))
    local titleCol = get_theme("Text.Title", Color3.fromRGB(255, 255, 255))
    local mutedCol = get_theme("Text.Secondary", Color3.fromRGB(160, 160, 170))
    local accentCol = window.Accent or get_theme("Accent", Color3.fromRGB(59, 130, 246))

    slot.Bg.Position = Vector2.new(px, py)
    slot.Bg.Size = Vector2.new(w, h)
    slot.Bg.Color = bgCol
    slot.Bg.Transparency = 0.94
    slot.Bg.Visible = true

    slot.Border.Position = Vector2.new(px, py)
    slot.Border.Size = Vector2.new(w, h)
    slot.Border.Color = borderCol
    slot.Border.Visible = true

    slot.AccentBar.Position = Vector2.new(px + 2, py)
    slot.AccentBar.Size = Vector2.new(w - 4, 2)
    slot.AccentBar.Color = accentCol
    slot.AccentBar.Visible = true

    local curX = px + 12
    for i = 1, 8 do
        local t = slot.Tokens[i]
        local p = pieces[i]
        if p then
            t.Text = p.Text
            t.Color = p.Accent and accentCol or (p.Muted and mutedCol or titleCol)
            t.Position = Vector2.new(curX, py + 7)
            t.Visible = true
            curX = curX + p.Width
        else
            t.Visible = false
        end
    end

    return consumed
end

function Overlay.Update(dt, window, mousePos, m1PressedArg, m1ClickedArg)
    if not window or window.Destroyed then
        hide_open_slot()
        hide_key_slot()
        hide_wm_slot()
        return false
    end

    local vp = get_viewport()
    local mx, my = -9999, -9999
    if mousePos then
        mx, my = mousePos.X, mousePos.Y
    elseif type(getmouseposition) == "function" then
        local p = getmouseposition()
        if p then mx, my = p.X, p.Y end
    end

    local m1Pressed = m1PressedArg
    local m1Clicked = m1ClickedArg
    if m1Pressed == nil then
        m1Pressed = (type(ismouse1pressed) == "function") and (ismouse1pressed() == true)
    end
    if m1Clicked == nil then
        m1Clicked = m1Pressed and not Overlay.PrevM1
        Overlay.PrevM1 = m1Pressed
    end

    local c1 = update_open_button(window, vp, mx, my, m1Pressed, m1Clicked)
    local c2 = update_keybind_menu(window, vp, mx, my, m1Pressed, m1Clicked and not c1)
    local c3 = update_watermark(window, vp, mx, my, m1Pressed, m1Clicked and not c1 and not c2)

    return c1 or c2 or c3
end

local function hide_tooltip_slot()
    local s = Overlay.TooltipSlot
    if not s then return end
    s.Bg.Visible = false
    s.Border.Visible = false
    s.Text.Visible = false
end

local function ensure_tooltip_slot()
    if Overlay.TooltipSlot then return Overlay.TooltipSlot end
    local pool = ensure_pool()
    local s = {
        Bg = pool:Get("Square"),
        Border = pool:Get("Square"),
        Text = pool:Get("Text"),
    }
    s.Bg.Filled = true
    s.Bg.Corner = 6
    s.Bg.ZIndex = 60
    s.Bg.Visible = false

    s.Border.Filled = false
    s.Border.Thickness = 1
    s.Border.Corner = 6
    s.Border.ZIndex = 61
    s.Border.Visible = false

    s.Text.Size = 12
    s.Text.ZIndex = 62
    s.Text.Visible = false

    Overlay.TooltipSlot = s
    return s
end

function Overlay.RenderTooltip(text, mx, my, window)
    if not text or text == "" or (window and window.Destroyed) then
        hide_tooltip_slot()
        return
    end
    local slot = ensure_tooltip_slot()
    local vp = get_viewport()
    local str = tostring(text)
    local tw = math.floor(#str * 6.8)
    local w = math.max(56, tw + 18)
    local h = 24
    local px = clamp((mx or 0) + 14, 6, math.max(6, vp.X - w - 6))
    local py = clamp((my or 0) + 18, 6, math.max(6, vp.Y - h - 6))

    slot.Bg.Position = Vector2.new(px, py)
    slot.Bg.Size = Vector2.new(w, h)
    slot.Bg.Color = get_theme("Card.Background", Color3.fromRGB(22, 22, 28))
    slot.Bg.Visible = true

    slot.Border.Position = Vector2.new(px, py)
    slot.Border.Size = Vector2.new(w, h)
    slot.Border.Color = get_theme("Window.Border", Color3.fromRGB(54, 54, 64))
    slot.Border.Visible = true

    slot.Text.Text = str
    slot.Text.Color = get_theme("Text.Title", Color3.fromRGB(255, 255, 255))
    slot.Text.Position = Vector2.new(px + 9, py + 5)
    slot.Text.Visible = true
end

function Overlay.Destroy()
    hide_open_slot()
    hide_key_slot()
    hide_wm_slot()
    hide_tooltip_slot()
    Overlay.OpenSlot = nil
    Overlay.KeySlot = nil
    Overlay.WmSlot = nil
    Overlay.TooltipSlot = nil
    if Overlay.Pool and Overlay.Pool.Destroy then
        Overlay.Pool:Destroy()
        Overlay.Pool = nil
    end
end

return Overlay
