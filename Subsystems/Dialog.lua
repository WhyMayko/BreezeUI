-- Library/BreezeUI/Subsystems/Dialog.lua
-- Reusable modal Dialog and WindUI:Popup subsystem with backdrop blocking and Close confirmation support.

local PoolModule = require("../Core/Pool")
local MetaModule = require("../Core/Meta")
local ThemeModule = require("../Layout/Theme")
local IconsModule = require("./Icons")
local MetricsModule = require("../Core/Metrics")
local ClampingModule = require("../Engine/Clamping")

local Dialog = {
    Active = nil,
    Pool = nil,
    Slot = nil,
    PrevM1 = false,
}

local str_win_bg  = "Window.Background"
local str_border  = "Window.Border"
local str_title   = "Text.Title"
local str_sec     = "Text.Secondary"
local str_primary = "Primary"
local str_ctrl_bg = "Control.Background"
local str_ctrl_hv = "Control.Hover"
local str_card_bg = "Card.Background"

local function ensure_slot()
    if not Dialog.Pool or Dialog.Pool.Destroyed then
        Dialog.Pool = PoolModule.new(nil, MetaModule)
        Dialog.Slot = nil
    end
    if Dialog.Slot then
        return Dialog.Slot
    end

    local pool = Dialog.Pool
    local slot = {
        Backdrop = pool:Get("Square"),
        CardBg = pool:Get("Square"),
        CardBorder = pool:Get("Square"),
        IconImg = pool:Get("Image"),
        TitleText = pool:Get("Text"),
        Lines = {},
        Buttons = {},
    }

    slot.Backdrop.Filled = true
    slot.Backdrop.Color = Color3.fromRGB(0, 0, 0)
    slot.Backdrop.ZIndex = 50
    slot.Backdrop.Visible = false

    slot.CardBg.Filled = true
    slot.CardBg.Corner = 16
    slot.CardBg.ZIndex = 51
    slot.CardBg.Visible = false

    slot.CardBorder.Filled = false
    slot.CardBorder.Thickness = 1
    slot.CardBorder.Corner = 16
    slot.CardBorder.ZIndex = 52
    slot.CardBorder.Visible = false

    slot.IconImg.Size = Vector2.new(22, 22)
    slot.IconImg.ZIndex = 53
    slot.IconImg.Visible = false

    slot.TitleText.Size = 16
    slot.TitleText.ZIndex = 53
    slot.TitleText.Visible = false

    for i = 1, 6 do
        local ln = pool:Get("Text")
        ln.Size = 14
        ln.ZIndex = 53
        ln.Visible = false
        slot.Lines[i] = ln
    end

    for i = 1, 4 do
        local bBg = pool:Get("Square")
        bBg.Filled = true
        bBg.Corner = 9
        bBg.ZIndex = 53
        bBg.Visible = false
        local bBorder = pool:Get("Square")
        bBorder.Filled = false
        bBorder.Thickness = 1
        bBorder.Corner = 9
        bBorder.ZIndex = 54
        bBorder.Visible = false
        local bIcon = pool:Get("Image")
        bIcon.Size = Vector2.new(14, 14)
        bIcon.ZIndex = 55
        bIcon.Visible = false
        local bTxt = pool:Get("Text")
        bTxt.Size = 13
        bTxt.ZIndex = 55
        bTxt.Visible = false
        slot.Buttons[i] = { Bg = bBg, Border = bBorder, Icon = bIcon, Text = bTxt }
    end

    Dialog.Slot = slot
    return slot
end

local function hide_slot()
    local slot = Dialog.Slot
    if not slot then return end
    slot.Backdrop.Visible = false
    slot.CardBg.Visible = false
    slot.CardBorder.Visible = false
    slot.IconImg.Visible = false
    slot.TitleText.Visible = false
    for _, ln in ipairs(slot.Lines) do
        ln.Visible = false
    end
    for _, b in ipairs(slot.Buttons) do
        b.Bg.Visible = false
        b.Border.Visible = false
        b.Icon.Visible = false
        b.Text.Visible = false
    end
end

function Dialog.Show(cfg, window, mode)
    assert(type(cfg) == "table", "Dialog/Popup requires configuration table!")

    if Dialog.Active and Dialog.Active.OnCancel then
        pcall(Dialog.Active.OnCancel)
    end

    local inst = {
        Mode = mode or "Dialog",
        Window = window,
        Title = tostring(cfg.Title or "Dialog"),
        Content = cfg.Content or cfg.Desc or cfg.Description or "",
        Icon = cfg.Icon,
        Width = cfg.Width or (mode == "Popup" and 400 or 330),
        Buttons = type(cfg.Buttons) == "table" and cfg.Buttons or {},
        OnCancel = cfg.OnCancel,
        Opened = true,
        Closing = false,
        AnimT = 0,
        _iconData = nil,
        _buttonIcons = {},
    }

    if inst.Icon then
        inst._iconData = IconsModule.Get(inst.Icon, function(png)
            inst._iconData = png
        end)
    end

    for idx, b in ipairs(inst.Buttons) do
        if b.Icon then
            inst._buttonIcons[idx] = IconsModule.Get(b.Icon, function(png)
                inst._buttonIcons[idx] = png
            end)
        end
    end

    function inst:Open()
        inst.Opened = true
        inst.Closing = false
        Dialog.Active = inst
    end

    function inst:Close()
        if not inst.Opened or inst.Closing then return end
        inst.Closing = true
        inst.Opened = false
    end

    function inst:Destroy()
        if Dialog.Active == inst then
            Dialog.Active = nil
            hide_slot()
        end
        inst.Opened = false
        inst.Closing = false
    end

    Dialog.Active = inst
    ensure_slot()
    return inst
end

function Dialog.IsOpen()
    local d = Dialog.Active
    return d ~= nil and (d.Opened or d.Closing)
end

function Dialog.Update(dt, window, mousePos, m1ClickedArg)
    local d = Dialog.Active
    if not d then return false end

    local delta = math.clamp(dt or 0.016, 0.001, 0.1)
    local smooth = 1 - math.exp(-18 * delta)

    if d.Closing then
        d.AnimT = d.AnimT + (0 - d.AnimT) * smooth
        if d.AnimT <= 0.04 then
            d:Destroy()
            return true
        end
    else
        d.AnimT = d.AnimT + (1 - d.AnimT) * smooth
    end

    local targetWin = d.Window or window
    if targetWin and targetWin.Destroyed then
        d:Destroy()
        return false
    end

    local slot = ensure_slot()
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
        m1Clicked = pressed and not Dialog.PrevM1
        Dialog.PrevM1 = pressed
    end

    local winVisible = targetWin and targetWin.Visible and not targetWin.Minimized
    local hostX, hostY, hostW, hostH, hostCorner
    if winVisible and d.Mode ~= "Popup" then
        hostX = targetWin.Position.X
        hostY = targetWin.Position.Y
        hostW = targetWin.Size.X
        hostH = targetWin.Size.Y
        hostCorner = targetWin.CornerRadius or 14
    else
        hostX = 0
        hostY = 0
        hostW = vp.X
        hostH = vp.Y
        hostCorner = 0
    end

    local alpha = math.clamp(d.AnimT, 0, 1)
    local pad = 18
    local cardW = math.clamp(d.Width, 260, math.max(260, hostW - 32))
    local hasIcon = d.Icon ~= nil and d.Icon ~= ""
    local titleLeft = hasIcon and 32 or 0
    local textW = cardW - pad * 2

    local lines = MetricsModule.WrapLines(d.Content, textW, 14, 6)
    local hasButtons = #d.Buttons > 0
    local contentH = (#lines > 0) and (#lines * 18 + 8) or 0
    local buttonsH = hasButtons and 44 or 0
    local cardH = pad * 2 + 24 + contentH + buttonsH

    local cx = math.floor(hostX + (hostW - cardW) * 0.5 + 0.5)
    local cy = math.floor(hostY + (hostH - cardH) * 0.5 + 0.5)

    local cardBg = ThemeModule.Get(str_win_bg)
    local cardBorder = ThemeModule.Get(str_border)
    local titleCol = ThemeModule.Get(str_title)
    local descCol = ThemeModule.Get(str_sec)
    local priCol = ThemeModule.Get(str_primary)
    local secBtnCol = ThemeModule.Get(str_ctrl_bg)
    local secHoverCol = ThemeModule.Get(str_ctrl_hv)
    local terBtnCol = ThemeModule.Get(str_card_bg)

    -- Backdrop
    slot.Backdrop.Position = Vector2.new(hostX, hostY)
    slot.Backdrop.Size = Vector2.new(hostW, hostH)
    slot.Backdrop.Corner = hostCorner
    slot.Backdrop.Transparency = 0.62 * alpha
    slot.Backdrop.Visible = true

    -- Dialog card
    slot.CardBg.Position = Vector2.new(cx, cy)
    slot.CardBg.Size = Vector2.new(cardW, cardH)
    slot.CardBg.Color = cardBg
    slot.CardBg.Transparency = alpha
    slot.CardBg.Visible = true

    slot.CardBorder.Position = Vector2.new(cx, cy)
    slot.CardBorder.Size = Vector2.new(cardW, cardH)
    slot.CardBorder.Color = cardBorder
    slot.CardBorder.Transparency = 0.9 * alpha
    slot.CardBorder.Visible = true

    if hasIcon and d._iconData then
        slot.IconImg.Data = d._iconData
        slot.IconImg.Color = titleCol
        slot.IconImg.Position = Vector2.new(cx + pad, cy + pad)
        slot.IconImg.Transparency = alpha
        slot.IconImg.Visible = true
    else
        slot.IconImg.Visible = false
    end

    local titleFitted = MetricsModule.Fit(d.Title, textW - titleLeft, 16, 1)
    slot.TitleText.Text = titleFitted
    slot.TitleText.Color = titleCol
    slot.TitleText.Position = Vector2.new(cx + pad + titleLeft, cy + pad)
    slot.TitleText.Transparency = alpha
    slot.TitleText.Visible = true

    for li = 1, 6 do
        local ln = slot.Lines[li]
        local str = lines[li]
        if str then
            ln.Text = str
            ln.Color = descCol
            ln.Position = Vector2.new(cx + pad, cy + pad + 30 + (li - 1) * 18)
            ln.Transparency = alpha
            ln.Visible = true
        else
            ln.Visible = false
        end
    end

    -- Buttons aligned horizontally at bottom
    if hasButtons then
        local count = math.min(4, #d.Buttons)
        local btnGap = 10
        local btnY = cy + cardH - pad - 34
        local availW = cardW - pad * 2
        local btnW = math.floor((availW - (count - 1) * btnGap) / count)
        local triggered = false

        for bi = 1, 4 do
            local bSlot = slot.Buttons[bi]
            local bCfg = d.Buttons[bi]
            if bi <= count and bCfg then
                local bx = cx + pad + (bi - 1) * (btnW + btnGap)
                local over = mx >= bx and mx <= bx + btnW and my >= btnY and my <= btnY + 34
                local variant = tostring(bCfg.Variant or "Secondary")

                local fillCol = secBtnCol
                local txtCol = titleCol
                local borderVis = false
                if variant == "Primary" then
                    local pr = math.min(255, math.floor((priCol.R or 0) * 255 + (over and 18 or 0)))
                    local pg = math.min(255, math.floor((priCol.G or 0) * 255 + (over and 18 or 0)))
                    local pb = math.min(255, math.floor((priCol.B or 0) * 255 + (over and 18 or 0)))
                    fillCol = Color3.fromRGB(pr, pg, pb)
                    txtCol = Color3.fromRGB(255, 255, 255)
                elseif variant == "Tertiary" then
                    fillCol = over and secBtnCol or terBtnCol
                    txtCol = descCol
                    borderVis = true
                else
                    fillCol = over and secHoverCol or secBtnCol
                    txtCol = titleCol
                    borderVis = true
                end

                bSlot.Bg.Position = Vector2.new(bx, btnY)
                bSlot.Bg.Size = Vector2.new(btnW, 34)
                bSlot.Bg.Color = fillCol
                bSlot.Bg.Transparency = alpha
                bSlot.Bg.Visible = true

                if borderVis then
                    bSlot.Border.Position = Vector2.new(bx, btnY)
                    bSlot.Border.Size = Vector2.new(btnW, 34)
                    bSlot.Border.Color = cardBorder
                    bSlot.Border.Transparency = 0.85 * alpha
                    bSlot.Border.Visible = true
                else
                    bSlot.Border.Visible = false
                end

                local bTitle = tostring(bCfg.Title or bCfg.Text or "OK")
                local hasBIcon = d._buttonIcons[bi] ~= nil
                local txtW = MetricsModule.Measure(bTitle, 13)
                local totalContentW = txtW + (hasBIcon and 20 or 0)
                local startX = bx + math.max(8, math.floor((btnW - totalContentW) * 0.5))

                if hasBIcon then
                    bSlot.Icon.Data = d._buttonIcons[bi]
                    bSlot.Icon.Color = txtCol
                    bSlot.Icon.Position = Vector2.new(startX, btnY + 10)
                    bSlot.Icon.Transparency = alpha
                    bSlot.Icon.Visible = true
                    bSlot.Text.Center = false
                    bSlot.Text.Position = Vector2.new(startX + 18, btnY + 10)
                else
                    bSlot.Icon.Visible = false
                    bSlot.Text.Center = false
                    local bh = (bSlot.Bg.Size and bSlot.Bg.Size.Y) or 34
                    local ax, ay = MetricsModule.AlignCenter(bx, btnY, btnW, bh, bTitle, 13)
                    bSlot.Text.Position = Vector2.new(ax, ay)
                end

                bSlot.Text.Text = bTitle
                bSlot.Text.Color = txtCol
                bSlot.Text.Transparency = alpha
                bSlot.Text.Visible = true

                if over and m1Clicked and not triggered then
                    triggered = true
                    if bCfg.KeepOpen ~= true then
                        d:Close()
                    end
                    if bCfg.Callback then
                        local ok, err = pcall(bCfg.Callback)
                        if not ok then
                            assert(false, "Dialog button callback error: " .. tostring(err) .. "!")
                        end
                    end
                end
            else
                bSlot.Bg.Visible = false
                bSlot.Border.Visible = false
                bSlot.Icon.Visible = false
                bSlot.Text.Visible = false
            end
        end
    else
        for bi = 1, 4 do
            slot.Buttons[bi].Bg.Visible = false
            slot.Buttons[bi].Border.Visible = false
            slot.Buttons[bi].Icon.Visible = false
            slot.Buttons[bi].Text.Visible = false
        end
    end

    -- Modal blocks all underlying window clicks while active
    return true
end

function Dialog.Destroy()
    if Dialog.Active then
        Dialog.Active.Opened = false
        Dialog.Active.Closing = false
        Dialog.Active = nil
    end
    hide_slot()
    Dialog.Slot = nil
    if Dialog.Pool and Dialog.Pool.Destroy then
        Dialog.Pool:Destroy()
        Dialog.Pool = nil
    end
end

return Dialog
