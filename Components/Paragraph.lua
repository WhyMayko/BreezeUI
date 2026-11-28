-- Library/BreezeUI/Components/Paragraph.lua
-- Multiline WindUI Paragraph card with optional icon/thumbnail, accent tint, and inline action buttons.

local ThemeModule = Theme or require("../Layout/Theme")
local IconsModule = Icons or require("../Subsystems/Icons")
local MetricsModule = Metrics or require("../Core/Metrics")

local Paragraph = {}
Paragraph.__index = Paragraph

local function wrap_lines(text, maxW, fontSize, maxLines)
    local out = {}
    local str = tostring(text or "")
    if str == "" then return out end
    local maxChars = math.max(10, math.floor(maxW / (fontSize * 0.58)))
    for raw in (str .. "\n"):gmatch("(.-)\n") do
        if #out >= maxLines then break end
        if raw == "" then
            table.insert(out, "")
        else
            local cur = ""
            for word in raw:gmatch("%S+") do
                local cand = cur == "" and word or (cur .. " " .. word)
                if #cand <= maxChars then
                    cur = cand
                else
                    if cur ~= "" then
                        table.insert(out, cur)
                        if #out >= maxLines then cur = ""; break end
                    end
                    cur = (#word > maxChars) and (string.sub(word, 1, maxChars - 3) .. "...") or word
                end
            end
            if cur ~= "" and #out < maxLines then
                table.insert(out, cur)
            end
        end
    end
    return out
end

local NAMED_COLORS = {
    Red = Color3.fromRGB(239, 79, 55),
    Blue = Color3.fromRGB(48, 93, 255),
    Green = Color3.fromRGB(34, 197, 94),
    Yellow = Color3.fromRGB(236, 162, 1),
    Purple = Color3.fromRGB(119, 117, 242),
}

function Paragraph.new(section, config)
    local cfg = config or {}
    local desc = cfg.Desc or cfg.Description or cfg.Content or ""
    local buttons = type(cfg.Buttons) == "table" and cfg.Buttons or {}
    local hasImg = cfg.Image ~= nil and cfg.Image ~= ""
    local imgSize = cfg.ImageSize or 40

    local usableW = math.max(160, (section.Size and section.Size.X or 400) - ((section.Padding or 10) * 2))
    local textLeft = hasImg and (imgSize + 12) or 0
    local lines = wrap_lines(desc, usableW - 28 - textLeft, 12, 6)
    local contentH = (#lines > 0) and (#lines * 16 + 4) or 0
    local btnRowH = (#buttons > 0) and 34 or 0
    local rowH = math.max(hasImg and (imgSize + 24) or 44, 24 + 18 + contentH + btnRowH)

    local pos, size = section:AllocateControlSlot(false, rowH)

    local cardColor = ThemeModule.Get("ElementBackground", Color3.fromRGB(42, 42, 44))
    local borderColor = ThemeModule.Get("Window.Border", Color3.fromRGB(46, 46, 54))
    if type(cfg.Color) == "string" and NAMED_COLORS[cfg.Color] then
        borderColor = NAMED_COLORS[cfg.Color]
    elseif type(cfg.Color) == "table" or typeof(cfg.Color) == "Color3" then
        cardColor = cfg.Color
    end

    local self = setmetatable({
        Section = section,
        Title = tostring(cfg.Title or "Paragraph"),
        Desc = tostring(desc),
        Image = cfg.Image,
        ImageSize = imgSize,
        Buttons = buttons,
        Position = pos,
        Size = size,
        Visible = section.Visible,
        Lines = lines,
        LineDrawings = {},
        ButtonSlots = {},
        _imgData = nil,
    }, Paragraph)

    local pool = section.Pool
    if pool then
        local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

        local bg = pool:Get("Square")
        bg.Position = pos
        bg.Size = size
        bg.Color = cardColor
        bg.Filled = true
        bg.Corner = 10
        bg.ZIndex = 4
        bg.Visible = section.Visible
        self.Visual = bg
        section:_register(bg)

        local border = pool:Get("Square")
        border.Position = pos
        border.Size = size
        border.Color = borderColor
        border.Filled = false
        border.Thickness = 1
        border.Corner = 10
        border.ZIndex = 5
        border.Visible = section.Visible
        self.Border = border
        section:_register(border)

        if hasImg then
            local img = pool:Get("Image")
            img.Size = Vector2.new(imgSize, imgSize)
            img.Position = Vector2.new(pos.X + 12, pos.Y + 12)
            img.Rounding = cfg.ImageRounding or 8
            img.Transparency = 1
            img.ZIndex = 5
            img.Visible = false
            self.ImgDrawing = img
            section:_register(img)

            if IconsModule and IconsModule.Get then
                local got = IconsModule.Get(cfg.Image, function(png)
                    self._imgData = png
                    img.Data = png
                    if self.Visible then img.Visible = true end
                end)
                if got then
                    self._imgData = got
                    img.Data = got
                    img.Visible = section.Visible
                end
            end
        end

        local titleTxt = pool:Get("Text")
        titleTxt.Text = self.Title
        titleTxt.Font = fontUI
        titleTxt.Outline = false
        titleTxt.Size = cfg.TextSize or 14
        titleTxt.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
        titleTxt.Position = Vector2.new(pos.X + 14 + textLeft, pos.Y + 11)
        titleTxt.ZIndex = 5
        titleTxt.Visible = section.Visible
        self.TitleText = titleTxt
        section:_register(titleTxt)

        for i = 1, 6 do
            local ln = pool:Get("Text")
            ln.Text = lines[i] or ""
            ln.Font = fontUI
            ln.Outline = false
            ln.Size = 12
            ln.Color = ThemeModule.Get("Text.Secondary", Color3.fromRGB(165, 165, 175))
            ln.Position = Vector2.new(pos.X + 14 + textLeft, pos.Y + 32 + (i - 1) * 16)
            ln.ZIndex = 5
            ln.Visible = section.Visible and (lines[i] ~= nil)
            self.LineDrawings[i] = ln
            section:_register(ln)
        end

        local count = math.min(3, #buttons)
        for bi = 1, count do
            local bBg = pool:Get("Square")
            bBg.Filled = true
            bBg.Corner = 7
            bBg.Color = ThemeModule.Get("Button.Background", Color3.fromRGB(48, 48, 56))
            bBg.ZIndex = 5
            bBg.Visible = section.Visible
            section:_register(bBg)

            local bTxt = pool:Get("Text")
            bTxt.Text = tostring(buttons[bi].Title or "Action")
            bTxt.Font = fontUI
            bTxt.Outline = false
            bTxt.Size = 12
            bTxt.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
            bTxt.ZIndex = 6
            bTxt.Visible = section.Visible
            section:_register(bTxt)

            self.ButtonSlots[bi] = { Bg = bBg, Text = bTxt, Config = buttons[bi], Rect = { X = 0, Y = 0, W = 0, H = 0 } }
        end
    end

    self:SetPosition(pos, size)
    return self
end

function Paragraph:RecalcHeight(width)
    local w = width or (self.Size and self.Size.X) or 380
    local textLeft = (self.ImgDrawing ~= nil) and (self.ImageSize + 12) or 0
    local availW = math.max(100, w - 28 - textLeft)
    local lines = wrap_lines(self.Desc, availW, 12, 6)
    self.Lines = lines
    local contentH = (#lines > 0) and (#lines * 16 + 4) or 0
    local btnRowH = (#self.Buttons > 0) and 34 or 0
    local rowH = math.max((self.ImgDrawing ~= nil) and (self.ImageSize + 24) or 44, 24 + 18 + contentH + btnRowH)
    self.Size = Vector2.new(w, rowH)
    return rowH
end

function Paragraph:SetPosition(pos, size)
    self.Position = pos
    local targetW = (size and size.X) or (self.Size and self.Size.X) or 380
    self:RecalcHeight(targetW)
    local textLeft = (self.ImgDrawing ~= nil) and (self.ImageSize + 12) or 0
    local availW = math.max(100, self.Size.X - 28 - textLeft)

    if self.Visual then
        self.Visual.Position = pos
        self.Visual.Size = self.Size
    end
    if self.Border then
        self.Border.Position = pos
        self.Border.Size = self.Size
    end
    if self.ImgDrawing then
        self.ImgDrawing.Position = Vector2.new(pos.X + 12, pos.Y + 12)
        self.ImgDrawing.Size = Vector2.new(self.ImageSize, self.ImageSize)
    end
    if self.TitleText then
        self.TitleText.Text = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(self.Title, availW, 14) or self.Title
        self.TitleText.Position = Vector2.new(pos.X + 14 + textLeft, pos.Y + 11)
    end
    for i = 1, 6 do
        local ln = self.LineDrawings[i]
        if ln then
            ln.Text = self.Lines[i] or ""
            ln.Position = Vector2.new(pos.X + 14 + textLeft, pos.Y + 32 + (i - 1) * 16)
            ln.Visible = self.Visible and (self.Lines[i] ~= nil)
        end
    end

    local count = #self.ButtonSlots
    if count > 0 then
        local bTop = pos.Y + self.Size.Y - 36
        local rowW = self.Size.X - 28
        local bw = math.floor((rowW - (count - 1) * 8) / count)
        for bi, bSlot in ipairs(self.ButtonSlots) do
            local bx = pos.X + 14 + (bi - 1) * (bw + 8)
            bSlot.Bg.Position = Vector2.new(bx, bTop)
            bSlot.Bg.Size = Vector2.new(bw, 26)
            bSlot.Text.Center = false
            local str = tostring(bSlot.Text.Text or "")
            local ax, ay
            if MetricsModule and MetricsModule.AlignCenter then
                ax, ay = MetricsModule.AlignCenter(bx, bTop, bw, 26, str, 12)
            else
                ax = bx + math.floor((bw - #str * 6.5) * 0.5)
                ay = bTop + math.floor((26 - 12) * 0.5)
            end
            bSlot.Text.Position = Vector2.new(ax, ay)
            bSlot.Rect = { X = bx, Y = bTop, W = bw, H = 26 }
        end
    end
end

function Paragraph:SetVisible(vis)
    self.Visible = vis
    if self.Visual then self.Visual.Visible = vis end
    if self.Border then self.Border.Visible = vis end
    if self.ImgDrawing then self.ImgDrawing.Visible = vis and (self._imgData ~= nil) end
    if self.TitleText then self.TitleText.Visible = vis end
    for i = 1, 6 do
        local ln = self.LineDrawings[i]
        if ln then ln.Visible = vis and (self.Lines[i] ~= nil) end
    end
    for _, bSlot in ipairs(self.ButtonSlots) do
        bSlot.Bg.Visible = vis
        bSlot.Text.Visible = vis
    end
end

function Paragraph:SetTitle(title)
    self.Title = tostring(title or "")
    self:SetPosition(self.Position, self.Size)
end

function Paragraph:SetDesc(desc)
    self.Desc = tostring(desc or "")
    self:SetPosition(self.Position, self.Size)
end
Paragraph.SetContent = Paragraph.SetDesc

function Paragraph:HandleClick(mx, my)
    for _, bSlot in ipairs(self.ButtonSlots) do
        local r = bSlot.Rect
        if bSlot.Bg and bSlot.Bg.Visible and mx >= r.X and mx <= r.X + r.W and my >= r.Y and my <= r.Y + r.H then
            if bSlot.Config.Callback then
                local ok, err = pcall(bSlot.Config.Callback)
                if not ok then
                    assert(false, "Paragraph button callback error: " .. tostring(err) .. "!")
                end
            end
            return true
        end
    end
    return false
end

return Paragraph
