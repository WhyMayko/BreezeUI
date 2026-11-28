-- Library/BreezeUI/Subsystems/Notify.lua
-- Stackable, pooled WindUI + Obsidian V2 notification and progress toast subsystem.

local PoolModule = require("../Core/Pool")
local MetaModule = require("../Core/Meta")
local ThemeModule = require("../Layout/Theme")
local IconsModule = require("./Icons")
local MetricsModule = require("../Core/Metrics")
local ClampingModule = require("../Engine/Clamping")

local Notify = {
    Active = {},
    Slots = {},
    MaxSlots = 8,
    Pool = nil,
    DefaultSide = "Right",
    DefaultAnchor = "Bottom",
    PrevM1 = false,
}

local str_card_bg = "Card.Background"
local str_border  = "Window.Border"
local str_title   = "Text.Title"
local str_sec     = "Text.Secondary"
local str_track   = "Slider.TrackBg"
local str_blue    = "Accent.Blue"
local str_ctrl_bg = "Control.Background"
local str_ctrl_hv = "Control.Hover"

local str_danger  = "Accent.Danger"
local str_green   = "Accent.Green"

local function brighten_col(col, delta)
    return Color3.fromRGB(
        math.min(255, math.floor((col.R or 0) * 255 + delta)),
        math.min(255, math.floor((col.G or 0) * 255 + delta)),
        math.min(255, math.floor((col.B or 0) * 255 + delta))
    )
end

local function resolve_button_style(bCfg, isOver, defaultBg, hoverBg, titleCol, accentCol)
    local fill = bCfg.Color
    local variant = bCfg.Variant
    if type(fill) == "string" then
        variant = fill
        fill = nil
    end
    if not fill and variant then
        if variant == "Danger" or variant == "Red" then
            fill = ThemeModule.Get(str_danger)
        elseif variant == "Success" or variant == "Green" then
            fill = ThemeModule.Get(str_green)
        elseif variant == "Primary" or variant == "Blue" then
            fill = accentCol
        end
    end
    if fill then
        return isOver and brighten_col(fill, 20) or fill, bCfg.TextColor or Color3.fromRGB(255, 255, 255)
    end
    return isOver and hoverBg or defaultBg, bCfg.TextColor or titleCol
end

local function ensure_pool()
    if not Notify.Pool or Notify.Pool.Destroyed then
        Notify.Pool = PoolModule.new(nil, MetaModule)
        Notify.Slots = {}
    end
    return Notify.Pool
end

local function create_slot()
    local pool = ensure_pool()
    local slot = {
        InUse = true,
        Bg = pool:Get("Square"),
        Border = pool:Get("Square"),
        ProgressTrack = pool:Get("Square"),
        ProgressFill = pool:Get("Square"),
        IconBorder = pool:Get("Square"),
        IconImg = pool:Get("Image"),
        CloseImg = pool:Get("Image"),
        TitleText = pool:Get("Text"),
        Lines = {},
        Buttons = {},
    }

    slot.Bg.Filled = true
    slot.Bg.Corner = 12
    slot.Bg.ZIndex = 40
    slot.Bg.Visible = false

    slot.Border.Filled = false
    slot.Border.Thickness = 1
    slot.Border.Corner = 12
    slot.Border.ZIndex = 41
    slot.Border.Visible = false

    slot.ProgressTrack.Filled = true
    slot.ProgressTrack.Corner = 2
    slot.ProgressTrack.ZIndex = 42
    slot.ProgressTrack.Visible = false

    slot.ProgressFill.Filled = true
    slot.ProgressFill.Corner = 2
    slot.ProgressFill.ZIndex = 43
    slot.ProgressFill.Visible = false

    slot.IconBorder.Filled = false
    slot.IconBorder.Thickness = 1
    slot.IconBorder.Corner = 0
    slot.IconBorder.ZIndex = 44
    slot.IconBorder.Visible = false

    slot.IconImg.ZIndex = 43
    slot.IconImg.Size = Vector2.new(22, 22)
    slot.IconImg.Rounding = 0
    slot.IconImg.Visible = false

    slot.CloseImg.ZIndex = 43
    slot.CloseImg.Size = Vector2.new(13, 13)
    slot.CloseImg.Visible = false

    slot.TitleText.Size = 14
    slot.TitleText.ZIndex = 43
    slot.TitleText.Visible = false

    for i = 1, 5 do
        local ln = pool:Get("Text")
        ln.Size = 13
        ln.ZIndex = 43
        ln.Visible = false
        slot.Lines[i] = ln
    end

    for i = 1, 3 do
        local btnBg = pool:Get("Square")
        btnBg.Filled = true
        btnBg.Corner = 6
        btnBg.ZIndex = 43
        btnBg.Visible = false
        local btnTxt = pool:Get("Text")
        btnTxt.Size = 12
        btnTxt.ZIndex = 44
        btnTxt.Visible = false
        slot.Buttons[i] = { Bg = btnBg, Text = btnTxt }
    end

    table.insert(Notify.Slots, slot)
    return slot
end

local function hide_slot(slot)
    if not slot then return end
    slot.InUse = false
    slot._lastIconData = nil
    slot._lastCloseData = nil
    slot.Bg.Visible = false
    slot.Border.Visible = false
    slot.ProgressTrack.Visible = false
    slot.ProgressFill.Visible = false
    slot.IconImg.Size = Vector2.new(22, 22)
    slot.IconImg.Rounding = 0
    slot.IconImg.Visible = false
    slot.IconBorder.Visible = false
    slot.CloseImg.Visible = false
    slot.TitleText.Visible = false
    for _, ln in ipairs(slot.Lines) do
        ln.Visible = false
    end
    for _, btn in ipairs(slot.Buttons) do
        btn.Bg.Visible = false
        btn.Text.Visible = false
    end
end

local function acquire_slot()
    ensure_pool()
    for _, slot in ipairs(Notify.Slots) do
        if not slot.InUse then
            slot.InUse = true
            return slot
        end
    end
    if #Notify.Slots < Notify.MaxSlots then
        return create_slot()
    end
    return nil
end

local function release_toast(toast, fireDismiss)
    if toast._released then return end
    toast._released = true
    toast.Closed = true
    if toast._slot then
        hide_slot(toast._slot)
        toast._slot = nil
    end
    if fireDismiss and toast._onDismiss then
        local ok, err = pcall(toast._onDismiss)
        if not ok then
            assert(false, "Notify onDismiss error: " .. tostring(err) .. "!")
        end
    end
end

function Notify.Push(cfg, titleArg, durationArg)
    local title, content, icon, duration, canClose, buttons, side, anchor, accent, sticky
    local iconSize, iconRounding, iconColor, keepColor
    local bgCol, borderCol, titleCol, contentCol, corner, width

    if type(cfg) == "table" then
        title = cfg.Title or cfg.title
        content = cfg.Content or cfg.Desc or cfg.Description or cfg.Message or cfg.description or ""
        icon = cfg.Icon or cfg.icon or cfg.Image or cfg.image
        iconSize = tonumber(cfg.IconSize)
        iconRounding = tonumber(cfg.IconRounding or cfg.ImageRounding)
        iconColor = cfg.IconColor
        keepColor = cfg.KeepColor
        bgCol = cfg.Background or cfg.BackgroundColor
        borderCol = cfg.BorderColor
        titleCol = cfg.TitleColor
        contentCol = cfg.ContentColor or cfg.DescColor
        corner = tonumber(cfg.Corner)
        width = tonumber(cfg.Width)
        if cfg.Duration == false then
            sticky = true
            duration = nil
        else
            duration = cfg.Duration or cfg.Time or cfg.duration or 5
        end
        canClose = cfg.CanClose ~= false
        buttons = cfg.Buttons
        side = cfg.Side
        anchor = cfg.Anchor
        accent = cfg.Accent
    else
        content = tostring(cfg or "")
        if type(titleArg) == "number" and durationArg == nil then
            duration = titleArg
            title = "Notice"
        else
            title = tostring(titleArg or "Notice")
            if durationArg == false then
                sticky = true
                duration = nil
            else
                duration = durationArg or 5
            end
        end
        canClose = true
    end

    local now = tick()
    local resolvedSize = iconSize and math.clamp(math.floor(iconSize + 0.5), 14, 40) or 22
    local toast = {
        Title = tostring(title or "Notification"),
        Content = tostring(content or ""),
        Icon = icon,
        IconSize = resolvedSize,
        IconRounding = iconRounding and math.max(0, math.floor(iconRounding + 0.5)) or 0,
        IconColor = iconColor,
        IconBorderColor = type(cfg) == "table" and cfg.IconBorderColor or nil,
        KeepColor = keepColor,
        BgColor = bgCol,
        BorderColor = borderCol,
        TitleColor = titleCol,
        ContentColor = contentCol,
        Corner = corner and math.clamp(math.floor(corner + 0.5), 0, 24) or 12,
        Width = width and math.clamp(math.floor(width + 0.5), 220, 480) or 296,
        Duration = duration,
        Sticky = sticky == true,
        CreatedAt = now,
        ExpiresAt = (duration and duration > 0) and (now + duration) or nil,
        CanClose = canClose,
        Buttons = type(buttons) == "table" and buttons or nil,
        Side = side,
        Anchor = anchor,
        Accent = accent,
        Progress = nil,
        DisplayProgress = 0,
        Closed = false,
        Closing = false,
        SlideT = 0,
        CurrentY = nil,
        _iconData = nil,
        _iconIsCustom = (type(icon) == "string" and icon ~= "" and IconsModule.IsCustom(icon)) or false,
        _iconRetryAt = now + 0.6,
        _closeData = nil,
        _onClick = nil,
        _onDismiss = nil,
        _slot = acquire_slot(),
        _released = false,
    }

    if icon and icon ~= "" then
        toast._iconData = IconsModule.Get(icon, function(png)
            toast._iconData = png
        end, false, true)
    end
    if canClose then
        toast._closeData = IconsModule.Get("x", function(png)
            toast._closeData = png
        end, false, true)
    end

    local function close_fn()
        if not toast.Closing and not toast._released then
            toast.Closing = true
            toast.Closed = true
        end
    end

    toast.Close = function() close_fn() end
    toast.Destroy = function() close_fn() end
    toast.destroy = function() close_fn() end

    toast.SetTitle = function(a, b)
        local txt = (a == toast) and b or a
        toast.Title = tostring(txt or "")
    end
    toast.setTitle = toast.SetTitle

    toast.SetContent = function(a, b)
        local txt = (a == toast) and b or a
        toast.Content = tostring(txt or "")
    end
    toast.SetMessage = toast.SetContent
    toast.setMessage = toast.SetContent
    toast.setContent = toast.SetContent

    toast.SetIcon = function(a, b)
        local src = (a == toast) and b or a
        toast.Icon = src
        toast._iconData = nil
        toast._iconIsCustom = (type(src) == "string" and src ~= "" and IconsModule.IsCustom(src)) or false
        toast._iconRetryAt = tick() + 0.6
        if src and src ~= "" then
            toast._iconData = IconsModule.Get(src, function(png)
                toast._iconData = png
            end, false, true)
        end
    end
    toast.setIcon = toast.SetIcon

    toast.SetProgress = function(a, b)
        local val = (a == toast) and b or a
        toast.Progress = math.clamp(tonumber(val) or 0, 0, 1)
    end
    toast.setProgress = toast.SetProgress

    toast.OnClick = function(a, b)
        local cb = (a == toast) and b or a
        toast._onClick = cb
        return toast
    end
    toast.onClick = toast.OnClick

    toast.OnDismiss = function(a, b)
        local cb = (a == toast) and b or a
        toast._onDismiss = cb
        return toast
    end
    toast.onDismiss = toast.OnDismiss

    -- Evict oldest if slot pool saturated
    if not toast._slot and #Notify.Active > 0 then
        local oldest = table.remove(Notify.Active, 1)
        release_toast(oldest, false)
        toast._slot = acquire_slot()
    end

    table.insert(Notify.Active, toast)
    return toast
end

function Notify.Progress(title, message, duration)
    local toast = Notify.Push({
        Title = title or "Progress",
        Content = message or "",
        Duration = duration == false and false or (duration or 5),
        CanClose = true,
    })
    toast.Progress = 0
    return toast
end

function Notify.Update(dt, window, mousePos, m1ClickedArg)
    if #Notify.Active == 0 then return false end

    local delta = math.clamp(dt or 0.016, 0.001, 0.1)
    local now = tick()
    local vp = ClampingModule.GetViewportSize()

    local mx, my = -9999, -9999
    if mousePos then
        mx, my = mousePos.X, mousePos.Y
    elseif type(getmouseposition) == "function" then
        local p = getmouseposition()
        if p then mx, my = p.X, p.Y end
    end

    local m1Clicked = m1ClickedArg
    if m1Clicked == nil then
        local pressed = (type(ismouse1pressed) == "function") and (ismouse1pressed() == true)
        m1Clicked = pressed and not Notify.PrevM1
        Notify.PrevM1 = pressed
    end

    local side = (window and window.NotifySide) or Notify.DefaultSide or "Right"
    local anchor = (window and window.NotifyAnchor) or Notify.DefaultAnchor or "Bottom"
    local cardBg = ThemeModule.Get(str_card_bg)
    local borderCol = ThemeModule.Get(str_border)
    local titleCol = ThemeModule.Get(str_title)
    local descCol = ThemeModule.Get(str_sec)
    local trackCol = ThemeModule.Get(str_track)
    local accentCol = (window and window.Accent) or ThemeModule.Get(str_blue)
    local btnCol = ThemeModule.Get(str_ctrl_bg)
    local btnHoverCol = ThemeModule.Get(str_ctrl_hv)

    local cardW = 296
    local padX = 14
    local padY = 12
    local gapY = 10
    local marginX = 20
    local marginY = 22
    local stackOffset = 0
    local consumedClick = false
    local smooth = 1 - math.exp(-14 * delta)

    -- Iterate newest -> oldest so newest sits closest to corner edge
    for i = #Notify.Active, 1, -1 do
        local toast = Notify.Active[i]

        if not toast.Closing and toast.ExpiresAt and now >= toast.ExpiresAt then
            toast.Closing = true
        end

        if toast.Closing then
            toast.SlideT = toast.SlideT + (0 - toast.SlideT) * (1 - math.exp(-16 * delta))
            if toast.SlideT <= 0.02 then
                table.remove(Notify.Active, i)
                release_toast(toast, true)
                continue
            end
        else
            toast.SlideT = toast.SlideT + (1 - toast.SlideT) * smooth
        end

        local slot = toast._slot
        if not slot then
            slot = acquire_slot()
            toast._slot = slot
        end
        if not slot then
            continue
        end

        local toastSide = toast.Side or side
        local toastAnchor = toast.Anchor or anchor
        local toastW = toast.Width or cardW
        local hasIcon = toast.Icon ~= nil and toast.Icon ~= ""
        local iconSize = toast.IconSize or 22
        local textLeftOffset = hasIcon and (iconSize + 10) or 0
        local rightPad = toast.CanClose and 22 or 0
        local textW = toastW - padX * 2 - textLeftOffset - rightPad

        if hasIcon and not toast._iconData and not IconsModule.IsInFlight(toast.Icon) and now >= (toast._iconRetryAt or 0) then
            toast._iconRetryAt = now + 1.0
            toast._iconData = IconsModule.Get(toast.Icon, function(png)
                toast._iconData = png
            end, false, true)
        end

        local lines = MetricsModule.WrapLines(toast.Content, textW, 13, 5)
        local titleFitted = MetricsModule.Fit(toast.Title, textW, 14, 1)

        local hasButtons = toast.Buttons and #toast.Buttons > 0
        local btnRowH = hasButtons and 32 or 0
        local contentH = (#lines > 0) and (#lines * 16 + 4) or 0
        local minIconH = hasIcon and (iconSize + padY * 2 + 8) or 58
        local cardH = math.max(minIconH, padY * 2 + 18 + contentH + btnRowH + 8)

        local finalX = toastSide == "Left" and marginX or (vp.X - toastW - marginX)
        local offX = toastSide == "Left" and (-toastW - 24) or (vp.X + 24)
        local x = math.floor(offX + (finalX - offX) * toast.SlideT + 0.5)

        local targetY = toastAnchor == "Top"
            and (marginY + stackOffset)
            or (vp.Y - marginY - stackOffset - cardH)
        if not toast.CurrentY then
            toast.CurrentY = targetY
        else
            toast.CurrentY = toast.CurrentY + (targetY - toast.CurrentY) * smooth
        end
        local y = math.floor(toast.CurrentY + 0.5)
        stackOffset = stackOffset + cardH + gapY

        local alpha = math.clamp(toast.SlideT, 0, 1)
        local tBgCol = toast.BgColor or cardBg
        local tBorderCol = toast.BorderColor or toast.Accent or borderCol
        local tTitleCol = toast.TitleColor or titleCol
        local tDescCol = toast.ContentColor or descCol

        -- Card shell
        slot.Bg.Position = Vector2.new(x, y)
        slot.Bg.Size = Vector2.new(toastW, cardH)
        slot.Bg.Corner = toast.Corner or 12
        slot.Bg.Color = tBgCol
        slot.Bg.Transparency = 0.96 * alpha
        slot.Bg.Visible = true

        slot.Border.Position = Vector2.new(x, y)
        slot.Border.Size = Vector2.new(toastW, cardH)
        slot.Border.Corner = toast.Corner or 12
        slot.Border.Color = tBorderCol
        slot.Border.Transparency = 0.9 * alpha
        slot.Border.Visible = true

        -- Optional Icon (only assign .Data when changed; preserve original RGB on custom PNGs)
        if hasIcon and toast._iconData then
            if slot._lastIconData ~= toast._iconData then
                slot.IconImg.Data = toast._iconData
                slot._lastIconData = toast._iconData
            end
            local keepCol = (toast.KeepColor ~= false) and toast._iconIsCustom
            slot.IconImg.Color = toast.IconColor or (keepCol and Color3.fromRGB(255, 255, 255) or tTitleCol)
            slot.IconImg.Size = Vector2.new(iconSize, iconSize)
            slot.IconImg.Rounding = toast.IconRounding or 0
            slot.IconImg.Position = Vector2.new(x + padX, y + padY)
            slot.IconImg.Transparency = alpha
            slot.IconImg.Visible = true
            if toast.IconBorderColor then
                slot.IconBorder.Position = Vector2.new(x + padX - 1, y + padY - 1)
                slot.IconBorder.Size = Vector2.new(iconSize + 2, iconSize + 2)
                slot.IconBorder.Corner = toast.IconRounding or 0
                slot.IconBorder.Color = toast.IconBorderColor
                slot.IconBorder.Transparency = alpha
                slot.IconBorder.Visible = true
            else
                slot.IconBorder.Visible = false
            end
        else
            slot.IconImg.Visible = false
            slot.IconBorder.Visible = false
        end

        -- Close button
        local closeHover = false
        if toast.CanClose then
            local cx = x + toastW - padX - 13
            local cy = y + padY + 1
            closeHover = mx >= cx - 5 and mx <= cx + 18 and my >= cy - 5 and my <= cy + 18
            if toast._closeData then
                if slot._lastCloseData ~= toast._closeData then
                    slot.CloseImg.Data = toast._closeData
                    slot._lastCloseData = toast._closeData
                end
                slot.CloseImg.Color = tTitleCol
                slot.CloseImg.Position = Vector2.new(cx, cy)
                slot.CloseImg.Transparency = (closeHover and 0.92 or 0.45) * alpha
                slot.CloseImg.Visible = true
            else
                slot.CloseImg.Visible = false
            end
        else
            slot.CloseImg.Visible = false
        end

        -- Title & wrapped lines
        slot.TitleText.Text = titleFitted
        slot.TitleText.Color = tTitleCol
        slot.TitleText.Position = Vector2.new(x + padX + textLeftOffset, y + padY - 1)
        slot.TitleText.Transparency = alpha
        slot.TitleText.Visible = true

        for li = 1, 5 do
            local ln = slot.Lines[li]
            local str = lines[li]
            if str then
                ln.Text = str
                ln.Color = tDescCol
                ln.Position = Vector2.new(x + padX + textLeftOffset, y + padY + 18 + (li - 1) * 16)
                ln.Transparency = alpha
                ln.Visible = true
            else
                ln.Visible = false
            end
        end

        -- Optional Buttons row
        local clickedButton = false
        if hasButtons then
            local count = math.min(3, #toast.Buttons)
            local btnTop = y + cardH - 12 - btnRowH + 4
            local availW = toastW - padX * 2
            local bw = math.floor((availW - (count - 1) * 6) / count)
            for bi = 1, 3 do
                local bSlot = slot.Buttons[bi]
                local bCfg = toast.Buttons[bi]
                if bi <= count and bCfg then
                    local bx = x + padX + (bi - 1) * (bw + 6)
                    local bOver = mx >= bx and mx <= bx + bw and my >= btnTop and my <= btnTop + 24
                    local bBgCol, bTxtCol = resolve_button_style(bCfg, bOver, btnCol, btnHoverCol, tTitleCol, accentCol)
                    bSlot.Bg.Position = Vector2.new(bx, btnTop)
                    bSlot.Bg.Size = Vector2.new(bw, 24)
                    bSlot.Bg.Color = bBgCol
                    bSlot.Bg.Transparency = alpha
                    bSlot.Bg.Visible = true

                    local bTitle = tostring(bCfg.Title or bCfg.Text or "Action")
                    bSlot.Text.Text = bTitle
                    bSlot.Text.Color = bTxtCol
                    bSlot.Text.Center = false
                    local ax, ay = MetricsModule.AlignCenter(bx, btnTop, bw, 24, bTitle, 11)
                    bSlot.Text.Position = Vector2.new(ax, ay)
                    bSlot.Text.Transparency = alpha
                    bSlot.Text.Visible = true

                    if bOver and m1Clicked and not consumedClick then
                        consumedClick = true
                        clickedButton = true
                        if bCfg.Callback then
                            pcall(bCfg.Callback)
                        end
                        if bCfg.KeepOpen ~= true then
                            toast:Close()
                        end
                    end
                else
                    bSlot.Bg.Visible = false
                    bSlot.Text.Visible = false
                end
            end
        else
            for bi = 1, 3 do
                slot.Buttons[bi].Bg.Visible = false
                slot.Buttons[bi].Text.Visible = false
            end
        end

        -- Progress / remaining duration bar
        local ratio = nil
        if toast.Progress ~= nil then
            toast.DisplayProgress = toast.DisplayProgress + (toast.Progress - toast.DisplayProgress) * smooth
            ratio = math.clamp(toast.DisplayProgress, 0, 1)
        elseif toast.ExpiresAt and toast.Duration and toast.Duration > 0 then
            ratio = math.clamp((toast.ExpiresAt - now) / toast.Duration, 0, 1)
        end

        if ratio ~= nil then
            local barW = toastW - padX * 2
            local barY = y + cardH - 7
            slot.ProgressTrack.Position = Vector2.new(x + padX, barY)
            slot.ProgressTrack.Size = Vector2.new(barW, 3)
            slot.ProgressTrack.Color = trackCol
            slot.ProgressTrack.Transparency = 0.8 * alpha
            slot.ProgressTrack.Visible = true

            local fillW = math.floor(barW * ratio + 0.5)
            if fillW > 0 then
                slot.ProgressFill.Position = Vector2.new(x + padX, barY)
                slot.ProgressFill.Size = Vector2.new(fillW, 3)
                slot.ProgressFill.Color = toast.Accent or accentCol
                slot.ProgressFill.Transparency = alpha
                slot.ProgressFill.Visible = true
            else
                slot.ProgressFill.Visible = false
            end
        else
            slot.ProgressTrack.Visible = false
            slot.ProgressFill.Visible = false
        end

        -- Hit-tests
        if m1Clicked and not consumedClick then
            if closeHover then
                consumedClick = true
                toast:Close()
            elseif not clickedButton then
                local bodyHover = mx >= x and mx <= x + toastW and my >= y and my <= y + cardH
                if bodyHover and toast._onClick then
                    consumedClick = true
                    local ok, err = pcall(toast._onClick)
                    if not ok then
                        assert(false, "Notify onClick error: " .. tostring(err) .. "!")
                    end
                end
            end
        end
    end

    return consumedClick
end

-- Set the preferred screen side for new toasts ("Left" or "Right").
function Notify.SetSide(side)
    assert(side == "Left" or side == "Right", "Notify.SetSide: side must be 'Left' or 'Right'!")
    Notify.DefaultSide = side
end

-- Set the preferred anchor position ("Top" or "Bottom").
function Notify.SetAnchor(anchor)
    assert(anchor == "Top" or anchor == "Bottom", "Notify.SetAnchor: anchor must be 'Top' or 'Bottom'!")
    Notify.DefaultAnchor = anchor
end

function Notify.Destroy()
    for i = #Notify.Active, 1, -1 do
        local toast = Notify.Active[i]
        toast._released = true
        toast._slot = nil
        Notify.Active[i] = nil
    end
    for _, slot in ipairs(Notify.Slots) do
        hide_slot(slot)
    end
    Notify.Slots = {}
    if Notify.Pool and Notify.Pool.Destroy then
        Notify.Pool:Destroy()
        Notify.Pool = nil
    end
end

return Notify
