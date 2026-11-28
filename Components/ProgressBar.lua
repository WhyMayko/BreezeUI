-- Library/BreezeUI/Components/ProgressBar.lua
-- WindUI ProgressBar component supporting Percent/Value/Fraction display and smooth animated fill.

local ThemeModule = Theme or require("../Layout/Theme")
local MetricsModule = Metrics or require("../Core/Metrics")

local ProgressBar = {}
ProgressBar.__index = ProgressBar

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function format_value(val, minV, maxV, mode, customFmt)
    local ratio = (maxV > minV) and clamp((val - minV) / (maxV - minV), 0, 1) or 0
    if type(customFmt) == "string" and customFmt ~= "" then
        local ok, formatted = pcall(string.format, customFmt, math.floor(val + 0.5), maxV)
        if ok and formatted then return formatted end
    end
    if mode == "Value" then
        return tostring(math.floor(val * 10 + 0.5) / 10)
    elseif mode == "Fraction" then
        return string.format("%s/%s", tostring(math.floor(val + 0.5)), tostring(maxV))
    end
    return string.format("%d%%", math.floor(ratio * 100 + 0.5))
end

function ProgressBar.new(section, id, config)
    local cfg = config or {}
    local valCfg = type(cfg.Value) == "table" and cfg.Value or {}
    local minV = tonumber(valCfg.Min or cfg.Min) or 0
    local maxV = tonumber(valCfg.Max or cfg.Max) or 100
    if minV > maxV then minV, maxV = maxV, minV end

    local defV = tonumber(type(cfg.Value) == "number" and cfg.Value or valCfg.Default or cfg.Default) or minV
    defV = clamp(defV, minV, maxV)

    local desc = cfg.Desc or cfg.Description
    local rowH = (desc and desc ~= "") and 56 or 44
    local pos, size = section:AllocateControlSlot(false, rowH)

    local self = setmetatable({
        Section = section,
        Id = id,
        Title = tostring(cfg.Title or cfg.Text or "Progress"),
        Desc = desc,
        Min = minV,
        Max = maxV,
        Value = defV,
        DisplayValue = defV,
        DisplayMode = cfg.DisplayMode or "Percent",
        Format = cfg.Format,
        ShowValue = cfg.ShowValue ~= false,
        Indeterminate = cfg.Indeterminate == true,
        CustomColor = cfg.Color,
        _animPhase = 0,
        Position = pos,
        Size = size,
        Visible = section.Visible,
    }, ProgressBar)

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
        titleTxt.Text = self.Title
        titleTxt.Font = fontUI
        titleTxt.Outline = false
        titleTxt.Size = 13
        titleTxt.Color = ThemeModule.Get("Text.Title")
        titleTxt.Position = Vector2.new(pos.X + 14, pos.Y + 8)
        titleTxt.ZIndex = 5
        titleTxt.Visible = section.Visible
        self.TitleText = titleTxt
        section:_register(titleTxt)

        if self.ShowValue then
            local valTxt = pool:Get("Text")
            valTxt.Text = format_value(self.Value, self.Min, self.Max, self.DisplayMode, self.Format)
            valTxt.Font = fontUI
            valTxt.Outline = false
            valTxt.Size = 12
            valTxt.Color = ThemeModule.Get("Text.Secondary")
            valTxt.ZIndex = 5
            valTxt.Visible = section.Visible
            self.ValueText = valTxt
            section:_register(valTxt)
        end

        local track = pool:Get("Square")
        track.Filled = true
        track.Corner = 3
        track.Color = ThemeModule.Get("Slider.TrackBg")
        track.ZIndex = 5
        track.Visible = section.Visible
        self.Track = track
        section:_register(track)

        local fill = pool:Get("Square")
        fill.Filled = true
        fill.Corner = 3
        fill.Color = cfg.Color or ThemeModule.Get("Accent.Blue")
        fill.ZIndex = 6
        fill.Visible = section.Visible
        self.FillBar = fill
        section:_register(fill)
    end

    self:SetPosition(pos, size)
    return self
end

function ProgressBar:_syncVisual()
    local barX = self.Position.X + 14
    local barY = self.Position.Y + self.Size.Y - 14
    local barW = math.max(40, self.Size.X - 28)

    if self.Track then
        self.Track.Position = Vector2.new(barX, barY)
        self.Track.Size = Vector2.new(barW, 6)
    end
    if self.Indeterminate then
        if self.FillBar then
            local segW = math.max(16, math.floor(barW * 0.32))
            local travel = math.max(0, barW - segW)
            local t = 0.5 - 0.5 * math.cos((self._animPhase or 0) * math.pi * 2)
            local offset = math.floor(travel * t + 0.5)
            self.FillBar.Position = Vector2.new(barX + offset, barY)
            self.FillBar.Size = Vector2.new(segW, 6)
            self.FillBar.Visible = self.Visible
        end
        if self.ValueText then
            self.ValueText.Visible = false
        end
    else
        local ratio = (self.Max > self.Min) and clamp((self.DisplayValue - self.Min) / (self.Max - self.Min), 0, 1) or 0
        if self.FillBar then
            local fillW = math.floor(barW * ratio + 0.5)
            self.FillBar.Position = Vector2.new(barX, barY)
            self.FillBar.Size = Vector2.new(math.max(1, fillW), 6)
            self.FillBar.Visible = self.Visible and fillW > 0
        end
        if self.ValueText then
            local str = format_value(self.Value, self.Min, self.Max, self.DisplayMode, self.Format)
            self.ValueText.Text = str
            local vw = MetricsModule.Measure(str, 12)
            self.ValueText.Position = Vector2.new(self.Position.X + self.Size.X - vw - 14, self.Position.Y + 9)
            self.ValueText.Visible = self.Visible
        end
    end
    if self.Visible and self._clipTop and self._clipBottom and self.Section and self.Section.ClipControl then
        self.Section.ClipControl(self, self._clipTop, self._clipBottom)
    end
end

function ProgressBar:Update(dt)
    if not self.Indeterminate or not self.Visible then return end
    self._animPhase = ((self._animPhase or 0) + (dt or 0.016) * 0.65) % 1
    self:_syncVisual()
end

function ProgressBar:SetIndeterminate(enabled)
    self.Indeterminate = enabled == true
    self:_syncVisual()
end

function ProgressBar:SetValue(val)
    self.Value = clamp(tonumber(val) or self.Min, self.Min, self.Max)
    self.DisplayValue = self.Value
    self:_syncVisual()
end
ProgressBar.Set = ProgressBar.SetValue

function ProgressBar:SetPosition(pos, size)
    self.Position = pos
    self.Size = size or self.Size
    if self.Visual then
        self.Visual.Position = pos
        self.Visual.Size = self.Size
    end
    if self.TitleText then
        self.TitleText.Text = MetricsModule.Fit(self.Title, self.Size.X - 80, 13)
        self.TitleText.Position = Vector2.new(pos.X + 14, pos.Y + 8)
    end
    self:_syncVisual()
end

function ProgressBar:SetVisible(vis)
    self.Visible = vis
    if self.Visual then self.Visual.Visible = vis end
    if self.TitleText then self.TitleText.Visible = vis end
    if self.ValueText then self.ValueText.Visible = vis and not self.Indeterminate end
    if self.Track then self.Track.Visible = vis end
    if self.FillBar then
        if self.Indeterminate then
            self.FillBar.Visible = vis
        else
            local ratio = (self.Max > self.Min) and clamp((self.DisplayValue - self.Min) / (self.Max - self.Min), 0, 1) or 0
            self.FillBar.Visible = vis and math.floor(math.max(40, self.Size.X - 28) * ratio + 0.5) > 0
        end
    end
end

return ProgressBar
