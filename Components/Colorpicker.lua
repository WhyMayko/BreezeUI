-- Library/BreezeUI/Components/Colorpicker.lua
-- Interactive HSV + Alpha Colorpicker with PNG overlay maps, Image.Rounding, and WindUI swatch transparency.

local ThemeModule = Theme or require("../Layout/Theme")
local IconsModule = Icons or require("../Subsystems/Icons")
local MetricsModule = Metrics or require("../Core/Metrics")

local Colorpicker = {}
Colorpicker.__index = Colorpicker

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function rgb_to_hsv(col)
    if not col then return 0, 1, 1 end
    local r = tonumber(col.R or col.r) or 1
    local g = tonumber(col.G or col.g) or 1
    local b = tonumber(col.B or col.b) or 1
    if math.max(r, g, b) > 1 then
        r, g, b = r / 255, g / 255, b / 255
    end
    local maxV = math.max(r, g, b)
    local minV = math.min(r, g, b)
    local delta = maxV - minV
    local h = 0
    if delta > 0 then
        if maxV == r then
            h = ((g - b) / delta) % 6
        elseif maxV == g then
            h = ((b - r) / delta) + 2
        else
            h = ((r - g) / delta) + 4
        end
        h = h / 6
        if h < 0 then h = h + 1 end
    end
    local s = maxV > 0 and (delta / maxV) or 0
    return h, s, maxV
end

local function hsv_to_rgb(h, s, v)
    h = clamp(h or 0, 0, 1) * 6
    s = clamp(s or 0, 0, 1)
    v = clamp(v or 0, 0, 1)
    local i = math.floor(h)
    local f = h - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    local r, g, b
    local m = i % 6
    if m == 0 then r, g, b = v, t, p
    elseif m == 1 then r, g, b = q, v, p
    elseif m == 2 then r, g, b = p, v, t
    elseif m == 3 then r, g, b = p, q, v
    elseif m == 4 then r, g, b = t, p, v
    else r, g, b = v, p, q end
    return Color3.fromRGB(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function rgb_to_hex(col)
    if not col then return "#FFFFFF" end
    local r = math.floor(clamp(tonumber(col.R or col.r) or 1, 0, 1) * 255 + 0.5)
    local g = math.floor(clamp(tonumber(col.G or col.g) or 1, 0, 1) * 255 + 0.5)
    local b = math.floor(clamp(tonumber(col.B or col.b) or 1, 0, 1) * 255 + 0.5)
    return string.format("#%02X%02X%02X", r, g, b)
end

local function get_viewport()
    local cam = workspace and workspace.CurrentCamera
    if cam and cam.ViewportSize and cam.ViewportSize.X > 0 and cam.ViewportSize.Y > 0 then
        return cam.ViewportSize
    end
    return Vector2.new(1920, 1080)
end

function Colorpicker:_syncSwatchVisual()
    local opacity = self.HasAlpha and clamp(1 - (self.Transparency or 0), 0, 1) or 1
    if self.Swatch then
        self.Swatch.Color = self.Value
        self.Swatch.Transparency = opacity
    end
    if self.SwatchGrid then
        self.SwatchGrid.Visible = self.Visible and self.HasAlpha and (self._textures.Grid ~= nil)
    end
end

function Colorpicker.new(section, id, config)
    local cfg = config or {}
    local desc = cfg.Desc or cfg.Description
    local rowH = (desc and desc ~= "") and 52 or 44
    local pos, size = section:AllocateControlSlot(false, rowH)

    local defaultColor = cfg.Default or cfg.Value or Color3.fromRGB(0, 255, 100)
    local h, s, v = rgb_to_hsv(defaultColor)

    local self = setmetatable({
        Section = section,
        Id = id,
        Title = tostring(cfg.Title or cfg.Text or "Colorpicker"),
        Desc = desc,
        Value = defaultColor,
        Hue = h,
        Sat = s,
        Vib = v,
        HasAlpha = cfg.Transparency ~= nil,
        Transparency = clamp(tonumber(cfg.Transparency) or 0, 0, 1),
        Position = pos,
        Size = size,
        Visible = section.Visible,
        IsOpen = false,
        Opened = false,
        DragMode = nil,
        Callback = cfg.Callback or function() end,
        Changed = cfg.Changed,
        PopupDrawings = nil,
        PopupRect = nil,
        _textures = {},
    }, Colorpicker)

    local pool = section.Pool
    if pool then
        local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

        local bg = pool:Get("Square")
        bg.Position = pos
        bg.Size = size
        bg.Color = ThemeModule.Get("ElementBackground")
        bg.Filled = true
        bg.Corner = 8
        bg.ZIndex = 4
        bg.Visible = section.Visible
        self.Visual = bg
        section:_register(bg)

        local titleTxt = pool:Get("Text")
        titleTxt.Text = self.Text or self.Title
        titleTxt.Font = fontUI
        titleTxt.Outline = false
        titleTxt.Size = 13
        titleTxt.Color = ThemeModule.Get("Text.Title")
        titleTxt.ZIndex = 5
        titleTxt.Visible = section.Visible
        self.TitleText = titleTxt
        section:_register(titleTxt)

        if self.Desc and self.Desc ~= "" then
            local dTxt = pool:Get("Text")
            dTxt.Text = self.Desc
            dTxt.Font = fontUI
            dTxt.Outline = false
            dTxt.Size = 11
            dTxt.Color = ThemeModule.Get("Text.Secondary")
            dTxt.ZIndex = 5
            dTxt.Visible = section.Visible
            self.DescText = dTxt
            section:_register(dTxt)
        end

        if self.HasAlpha then
            local swGrid = pool:Get("Image")
            swGrid.Size = Vector2.new(32, 18)
            swGrid.Rounding = 6
            swGrid.Transparency = 0.65
            swGrid.ZIndex = 5
            swGrid.Visible = false
            self.SwatchGrid = swGrid
            section:_register(swGrid)

            local got = IconsModule.GetTexture("transparency-grid", function(png)
                self._textures.Grid = png
                if self.SwatchGrid and png then
                    self.SwatchGrid.Data = png
                    if self.Visible and self.HasAlpha then
                        self.SwatchGrid.Visible = true
                    end
                end
            end)
            if got then
                self._textures.Grid = got
                swGrid.Data = got
                swGrid.Visible = section.Visible
            end
        end

        local sw = pool:Get("Square")
        sw.Size = Vector2.new(32, 18)
        sw.Color = self.Value
        sw.Transparency = self.HasAlpha and clamp(1 - self.Transparency, 0, 1) or 1
        sw.Filled = true
        sw.Corner = 6
        sw.ZIndex = 6
        sw.Visible = section.Visible
        self.Swatch = sw
        section:_register(sw)

        local swBorder = pool:Get("Square")
        swBorder.Size = Vector2.new(32, 18)
        swBorder.Color = ThemeModule.Get("Window.Border")
        swBorder.Filled = false
        swBorder.Thickness = 1
        swBorder.Corner = 6
        swBorder.ZIndex = 7
        swBorder.Visible = section.Visible
        self.SwatchBorder = swBorder
        section:_register(swBorder)
    end

    self:SetPosition(pos, size)
    return self
end

local alpha_cols = 24
local alpha_rows = 2
local alpha_segments = 24

function Colorpicker:_ensurePopup()
    if self.PopupDrawings then return self.PopupDrawings end
    local pool = self.Section and self.Section.Pool
    if not pool then return nil end

    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1
    local pd = {
        Bg = pool:Get("Square"),
        Border = pool:Get("Square"),
        SVBase = pool:Get("Square"),
        SVMap = pool:Get("Image"),
        SVCursor = pool:Get("Square"),
        HueBg = pool:Get("Square"),
        HueImg = pool:Get("Image"),
        HueCursor = pool:Get("Square"),
        AlphaTiles = {},
        AlphaSegments = {},
        AlphaCursor = pool:Get("Square"),
        PreviewGrid = pool:Get("Image"),
        Preview = pool:Get("Square"),
        HexText = pool:Get("Text"),
    }

    pd.Bg.Filled = true
    pd.Bg.Corner = 10
    pd.Bg.ZIndex = 24
    pd.Bg.Visible = false

    pd.Border.Filled = false
    pd.Border.Thickness = 1
    pd.Border.Corner = 10
    pd.Border.ZIndex = 25
    pd.Border.Visible = false

    pd.SVBase.Filled = true
    pd.SVBase.Corner = 8
    pd.SVBase.ZIndex = 25
    pd.SVBase.Visible = false

    pd.SVMap.Rounding = 8
    pd.SVMap.Transparency = 1
    pd.SVMap.Color = Color3.fromRGB(255, 255, 255)
    pd.SVMap.ZIndex = 26
    pd.SVMap.Visible = false

    pd.SVCursor.Filled = false
    pd.SVCursor.Thickness = 2
    pd.SVCursor.Size = Vector2.new(12, 12)
    pd.SVCursor.Corner = 6
    pd.SVCursor.Color = Color3.fromRGB(255, 255, 255)
    pd.SVCursor.ZIndex = 28
    pd.SVCursor.Visible = false

    pd.HueBg.Filled = true
    pd.HueBg.Corner = 6
    pd.HueBg.Color = Color3.fromRGB(255, 0, 0)
    pd.HueBg.ZIndex = 25
    pd.HueBg.Visible = false

    pd.HueImg.Rounding = 6
    pd.HueImg.Transparency = 1
    pd.HueImg.Color = Color3.fromRGB(255, 255, 255)
    pd.HueImg.ZIndex = 26
    pd.HueImg.Visible = false

    pd.HueCursor.Filled = true
    pd.HueCursor.Size = Vector2.new(20, 4)
    pd.HueCursor.Corner = 2
    pd.HueCursor.Color = Color3.fromRGB(255, 255, 255)
    pd.HueCursor.ZIndex = 28
    pd.HueCursor.Visible = false

    for r = 1, alpha_rows do
        for c = 1, alpha_cols do
            local tile = pool:Get("Square")
            tile.Filled = true
            tile.Color = ((r + c) % 2 == 0) and Color3.fromRGB(220, 220, 225) or Color3.fromRGB(130, 130, 140)
            tile.ZIndex = 25
            tile.Visible = false
            table.insert(pd.AlphaTiles, tile)
            self.Section:_register(tile)
        end
    end

    for i = 1, alpha_segments do
        local seg = pool:Get("Square")
        seg.Filled = true
        seg.ZIndex = 26
        seg.Visible = false
        pd.AlphaSegments[i] = seg
        self.Section:_register(seg)
    end

    pd.AlphaCursor.Filled = true
    pd.AlphaCursor.Size = Vector2.new(4, 16)
    pd.AlphaCursor.Corner = 2
    pd.AlphaCursor.Color = Color3.fromRGB(255, 255, 255)
    pd.AlphaCursor.ZIndex = 28
    pd.AlphaCursor.Visible = false

    pd.PreviewGrid.Size = Vector2.new(22, 22)
    pd.PreviewGrid.Rounding = 6
    pd.PreviewGrid.Transparency = 0.65
    pd.PreviewGrid.ZIndex = 25
    pd.PreviewGrid.Visible = false

    pd.Preview.Filled = true
    pd.Preview.Size = Vector2.new(22, 22)
    pd.Preview.Corner = 6
    pd.Preview.ZIndex = 26
    pd.Preview.Visible = false

    pd.HexText.Size = 12
    pd.HexText.Font = fontUI
    pd.HexText.Outline = false
    pd.HexText.ZIndex = 26
    pd.HexText.Visible = false

    for k, d in pairs(pd) do
        if k ~= "AlphaTiles" and k ~= "AlphaSegments" then
            self.Section:_register(d)
        end
    end

    local satData = IconsModule.GetTexture("saturation-map", function(png)
        self._textures.Sat = png
        if self.PopupDrawings and self.PopupDrawings.SVMap and png then
            self.PopupDrawings.SVMap.Data = png
            pd._lastSatData = png
            if self.IsOpen then self.PopupDrawings.SVMap.Visible = true end
        end
    end)
    if satData then
        self._textures.Sat = satData
        pd.SVMap.Data = satData
        pd._lastSatData = satData
    end

    local hueData = IconsModule.GetTexture("hue-bar", function(png)
        self._textures.Hue = png
        if self.PopupDrawings and self.PopupDrawings.HueImg and png then
            self.PopupDrawings.HueImg.Data = png
            pd._lastHueData = png
            if self.IsOpen then
                self.PopupDrawings.HueImg.Visible = true
                self.PopupDrawings.HueBg.Visible = false
            end
        end
    end)
    if hueData then
        self._textures.Hue = hueData
        pd.HueImg.Data = hueData
        pd._lastHueData = hueData
    end

    local gridData = IconsModule.GetTexture("transparency-grid", function(png)
        self._textures.Grid = png
        if self.PopupDrawings and png then
            if self.PopupDrawings.PreviewGrid then
                self.PopupDrawings.PreviewGrid.Data = png
                pd._lastGridData = png
                if self.IsOpen and self.HasAlpha then
                    self.PopupDrawings.PreviewGrid.Visible = true
                end
            end
        end
    end)
    if gridData then
        self._textures.Grid = gridData
        pd.PreviewGrid.Data = gridData
        pd._lastGridData = gridData
    end

    self.PopupDrawings = pd
    return pd
end

function Colorpicker:_syncPopup()
    local pd = self.PopupDrawings
    if not pd or not self.IsOpen then return end

    local vp = get_viewport()
    local popW = 216
    local popH = self.HasAlpha and 248 or 222
    local x = clamp(self.Position.X + self.Size.X - popW, 8, math.max(8, vp.X - popW - 8))
    local y = self.Position.Y + self.Size.Y + 6
    if y + popH > vp.Y - 8 then
        y = math.max(8, self.Position.Y - popH - 6)
    end

    self.PopupRect = {
        X = x, Y = y, W = popW, H = popH,
        SV = { X = x + 12, Y = y + 12, W = 164, H = 164 },
        Hue = { X = x + 186, Y = y + 12, W = 18, H = 164 },
        Alpha = self.HasAlpha and { X = x + 12, Y = y + 186, W = 192, H = 14 } or nil,
    }

    pd.Bg.Position = Vector2.new(x, y)
    pd.Bg.Size = Vector2.new(popW, popH)
    pd.Bg.Color = ThemeModule.Get("Card.Background")
    pd.Bg.Visible = true

    pd.Border.Position = Vector2.new(x, y)
    pd.Border.Size = Vector2.new(popW, popH)
    pd.Border.Color = ThemeModule.Get("Window.Border")
    pd.Border.Visible = true

    local sv = self.PopupRect.SV
    pd.SVBase.Position = Vector2.new(sv.X, sv.Y)
    pd.SVBase.Size = Vector2.new(sv.W, sv.H)
    pd.SVBase.Color = hsv_to_rgb(self.Hue, 1, 1)
    pd.SVBase.Visible = true

    pd.SVMap.Position = Vector2.new(sv.X, sv.Y)
    pd.SVMap.Size = Vector2.new(sv.W, sv.H)
    pd.SVMap.Rounding = 8
    pd.SVMap.Transparency = 1
    if self._textures.Sat and pd._lastSatData ~= self._textures.Sat then
        pd.SVMap.Data = self._textures.Sat
        pd._lastSatData = self._textures.Sat
    end
    pd.SVMap.Visible = self._textures.Sat ~= nil

    pd.SVCursor.Position = Vector2.new(
        clamp(sv.X + math.floor(self.Sat * sv.W - 6), sv.X - 2, sv.X + sv.W - 10),
        clamp(sv.Y + math.floor((1 - self.Vib) * sv.H - 6), sv.Y - 2, sv.Y + sv.H - 10)
    )
    pd.SVCursor.Visible = true

    local hb = self.PopupRect.Hue
    pd.HueBg.Position = Vector2.new(hb.X, hb.Y)
    pd.HueBg.Size = Vector2.new(hb.W, hb.H)
    pd.HueBg.Visible = self._textures.Hue == nil

    pd.HueImg.Position = Vector2.new(hb.X, hb.Y)
    pd.HueImg.Size = Vector2.new(hb.W, hb.H)
    pd.HueImg.Rounding = 6
    pd.HueImg.Transparency = 1
    if self._textures.Hue and pd._lastHueData ~= self._textures.Hue then
        pd.HueImg.Data = self._textures.Hue
        pd._lastHueData = self._textures.Hue
    end
    pd.HueImg.Visible = self._textures.Hue ~= nil

    pd.HueCursor.Position = Vector2.new(hb.X - 1, clamp(hb.Y + math.floor(self.Hue * hb.H - 2), hb.Y, hb.Y + hb.H - 4))
    pd.HueCursor.Visible = true

    if self.PopupRect.Alpha then
        local ab = self.PopupRect.Alpha
        local tileW = math.floor(ab.W / alpha_cols)
        local tileH = math.floor(ab.H / alpha_rows)
        local idx = 1
        for r = 1, alpha_rows do
            for c = 1, alpha_cols do
                local tile = pd.AlphaTiles[idx]
                local tx = ab.X + (c - 1) * tileW
                local ty = ab.Y + (r - 1) * tileH
                local tw = (c == alpha_cols) and (ab.X + ab.W - tx) or tileW
                local th = (r == alpha_rows) and (ab.Y + ab.H - ty) or tileH
                tile.Position = Vector2.new(tx, ty)
                tile.Size = Vector2.new(math.max(1, tw), math.max(1, th))
                tile.Visible = true
                idx = idx + 1
            end
        end

        for i = 1, alpha_segments do
            local seg = pd.AlphaSegments[i]
            local x0 = ab.X + math.floor((i - 1) * ab.W / alpha_segments)
            local x1 = ab.X + math.floor(i * ab.W / alpha_segments)
            seg.Position = Vector2.new(x0, ab.Y)
            seg.Size = Vector2.new(math.max(1, x1 - x0), ab.H)
            seg.Color = self.Value
            seg.Transparency = (i - 1) / (alpha_segments - 1)
            seg.Visible = true
        end

        pd.AlphaCursor.Position = Vector2.new(clamp(ab.X + math.floor((1 - self.Transparency) * ab.W - 2), ab.X, ab.X + ab.W - 4), ab.Y - 1)
        pd.AlphaCursor.Visible = true
    else
        for _, tile in ipairs(pd.AlphaTiles) do tile.Visible = false end
        for _, seg in ipairs(pd.AlphaSegments) do seg.Visible = false end
        pd.AlphaCursor.Visible = false
    end

    local fy = y + popH - 34
    if self._textures.Grid and pd._lastGridData ~= self._textures.Grid then
        pd.PreviewGrid.Data = self._textures.Grid
        pd._lastGridData = self._textures.Grid
    end
    pd.PreviewGrid.Position = Vector2.new(x + 12, fy)
    pd.PreviewGrid.Rounding = 6
    pd.PreviewGrid.Visible = self.HasAlpha and (self._textures.Grid ~= nil)

    pd.Preview.Position = Vector2.new(x + 12, fy)
    pd.Preview.Color = self.Value
    pd.Preview.Transparency = self.HasAlpha and clamp(1 - self.Transparency, 0, 1) or 1
    pd.Preview.Visible = true

    pd.HexText.Text = rgb_to_hex(self.Value)
    pd.HexText.Color = ThemeModule.Get("Text.Title")
    pd.HexText.Position = Vector2.new(x + 42, fy + 4)
    pd.HexText.Visible = true
end

function Colorpicker:_applyHSV()
    self.Value = hsv_to_rgb(self.Hue, self.Sat, self.Vib)
    self:_syncSwatchVisual()
    self:_syncPopup()
    if self.Callback then
        local ok, err = pcall(self.Callback, self.Value, self.Transparency)
        if not ok then
            assert(false, "Colorpicker callback error: " .. tostring(err) .. "!")
        end
    end
    if self.Changed then
        pcall(self.Changed, self.Value, self.Transparency)
    end
end

function Colorpicker:SetValueRGB(col, alpha)
    if not col then return end
    self.Value = col
    self.Hue, self.Sat, self.Vib = rgb_to_hsv(col)
    if alpha ~= nil then
        self.Transparency = clamp(tonumber(alpha) or 0, 0, 1)
    end
    self:_syncSwatchVisual()
    self:_syncPopup()
    if self.Callback then
        pcall(self.Callback, self.Value, self.Transparency)
    end
end
Colorpicker.Set = Colorpicker.SetValueRGB
Colorpicker.SetValue = Colorpicker.SetValueRGB

function Colorpicker:OnChanged(cb)
    self.Changed = cb
    return self
end

function Colorpicker:Open()
    local win = self.Section and (self.Section.Window or (self.Section.ParentTab and self.Section.ParentTab.Window))
    if win then
        if win.OpenDropdown and win.OpenDropdown.Close then win.OpenDropdown:Close() end
        if win.OpenColorpicker and win.OpenColorpicker ~= self and win.OpenColorpicker.Close then
            win.OpenColorpicker:Close()
        end
        win.OpenColorpicker = self
    end
    self.IsOpen = true
    self.Opened = true
    self:_ensurePopup()
    self:_syncPopup()
end

function Colorpicker:Close()
    self.IsOpen = false
    self.Opened = false
    self.DragMode = nil
    local win = self.Section and (self.Section.Window or (self.Section.ParentTab and self.Section.ParentTab.Window))
    if win and win.OpenColorpicker == self then
        win.OpenColorpicker = nil
    end
    if self.PopupDrawings then
        for k, d in pairs(self.PopupDrawings) do
            if k == "AlphaTiles" or k == "AlphaSegments" then
                for _, item in ipairs(d) do item.Visible = false end
            elseif type(d) == "userdata" or (type(d) == "table" and d.Visible ~= nil) then
                d.Visible = false
            end
        end
    end
end

function Colorpicker:Toggle()
    if self.IsOpen then self:Close() else self:Open() end
end

function Colorpicker:Click()
    self:Toggle()
end

function Colorpicker:UpdatePopupInput(mx, my, m1Pressed, m1Clicked)
    if not self.IsOpen or not self.PopupRect then return false end
    local r = self.PopupRect
    local sv = r.SV
    local hb = r.Hue
    local ab = r.Alpha

    if self.DragMode then
        if m1Pressed then
            if self.DragMode == "SV" then
                self.Sat = clamp((mx - sv.X) / sv.W, 0, 1)
                self.Vib = 1 - clamp((my - sv.Y) / sv.H, 0, 1)
                self:_applyHSV()
            elseif self.DragMode == "Hue" then
                self.Hue = clamp((my - hb.Y) / hb.H, 0, 1)
                self:_applyHSV()
            elseif self.DragMode == "Alpha" and ab then
                self.Transparency = 1 - clamp((mx - ab.X) / ab.W, 0, 1)
                self:_applyHSV()
            end
            return true
        else
            self.DragMode = nil
            return true
        end
    end

    local overPopup = mx >= r.X and mx <= r.X + r.W and my >= r.Y and my <= r.Y + r.H
    if not overPopup then
        if m1Clicked then
            self:Close()
        end
        return false
    end

    if m1Clicked then
        if mx >= sv.X and mx <= sv.X + sv.W and my >= sv.Y and my <= sv.Y + sv.H then
            self.DragMode = "SV"
            self.Sat = clamp((mx - sv.X) / sv.W, 0, 1)
            self.Vib = 1 - clamp((my - sv.Y) / sv.H, 0, 1)
            self:_applyHSV()
        elseif mx >= hb.X and mx <= hb.X + hb.W and my >= hb.Y and my <= hb.Y + hb.H then
            self.DragMode = "Hue"
            self.Hue = clamp((my - hb.Y) / hb.H, 0, 1)
            self:_applyHSV()
        elseif ab and mx >= ab.X and mx <= ab.X + ab.W and my >= ab.Y and my <= ab.Y + ab.H then
            self.DragMode = "Alpha"
            self.Transparency = 1 - clamp((mx - ab.X) / ab.W, 0, 1)
            self:_applyHSV()
        end
        return true
    end
    return true
end

function Colorpicker:SetPosition(pos, size)
    self.Position = pos
    self.Size = size or self.Size
    if self.Visual then
        self.Visual.Position = pos
        self.Visual.Size = self.Size
    end
    local maxTextW = math.max(60, self.Size.X - 64)
    if self.TitleText then
        self.TitleText.Text = MetricsModule.Fit(self.Title, maxTextW, 13)
        local ty = (self.Desc and self.Desc ~= "") and (pos.Y + 9) or (pos.Y + math.floor((self.Size.Y - 13) * 0.5))
        self.TitleText.Position = Vector2.new(pos.X + 14, ty)
    end
    if self.DescText then
        self.DescText.Text = MetricsModule.Fit(self.Desc, maxTextW, 11)
        self.DescText.Position = Vector2.new(pos.X + 14, pos.Y + 27)
    end
    local sx = pos.X + self.Size.X - 46
    local sy = pos.Y + math.floor((self.Size.Y - 18) * 0.5)
    if self.SwatchGrid then
        self.SwatchGrid.Position = Vector2.new(sx, sy)
        self.SwatchGrid.Size = Vector2.new(32, 18)
    end
    if self.Swatch then
        self.Swatch.Position = Vector2.new(sx, sy)
        self.Swatch.Size = Vector2.new(32, 18)
    end
    if self.SwatchBorder then
        self.SwatchBorder.Position = Vector2.new(sx, sy)
        self.SwatchBorder.Size = Vector2.new(32, 18)
    end
    if self.IsOpen then self:_syncPopup() end
end

function Colorpicker:SetVisible(vis)
    self.Visible = vis
    if self.Visual then self.Visual.Visible = vis end
    if self.TitleText then self.TitleText.Visible = vis end
    if self.DescText then self.DescText.Visible = vis end
    if self.SwatchGrid then
        self.SwatchGrid.Visible = vis and self.HasAlpha and (self._textures.Grid ~= nil)
    end
    if self.Swatch then self.Swatch.Visible = vis end
    if self.SwatchBorder then self.SwatchBorder.Visible = vis end
    if not vis and self.IsOpen then
        self:Close()
    end
end

function Colorpicker:SetTitle(title)
    self.Title = tostring(title or "")
    if self.TitleText then
        self.TitleText.Text = self.Title
    end
end

function Colorpicker:SetDesc(desc)
    self.Desc = desc ~= nil and tostring(desc) or ""
    if self.DescText then
        self.DescText.Text = self.Desc
    end
end

function Colorpicker:Lock(title)
    self.Locked = true
    if title ~= nil then self.LockedTitle = tostring(title) end
    if self.IsOpen then self:Close() end
    if self.TitleText then
        self.TitleText.Color = ThemeModule.Get("Text.Muted")
    end
end

function Colorpicker:Unlock()
    self.Locked = false
    if self.TitleText then
        self.TitleText.Color = ThemeModule.Get("Text.Title")
    end
end

function Colorpicker:Destroy()
    self:SetVisible(false)
end

return Colorpicker
