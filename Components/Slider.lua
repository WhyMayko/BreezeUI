-- Library/BreezeUI/Components/Slider.lua
-- 100% WindUI-identical slider component: card container, capsule pill thumb, icons support, and dual layouts.

local ThemeModule = Theme or require("../Layout/Theme")
local IconsModule = Icons or require("../Subsystems/Icons")
local MetricsModule = Metrics or require("../Core/Metrics")

local Slider = {}
Slider.__index = Slider

local function sync_slider_header(self, trackX)
    if not self.HasTitle then return end
    local pos = self.Position
    local size = self.Size
    local valStr = tostring(self.Value)
    local badgeX = trackX - 10
    if self.Badge then
        local bw = MetricsModule.Measure(valStr, 12)
        badgeX = trackX - bw - 16
        self.Badge.Text = valStr
        self.Badge.Position = Vector2.new(badgeX, pos.Y + math.floor((size.Y - 12) * 0.5))
    end
    if self.Label then
        local maxLabelW = math.max(30, badgeX - (pos.X + 14) - 8)
        self.Label.Text = MetricsModule.Fit(self.Text, maxLabelW, 13)
        self.Label.Position = Vector2.new(pos.X + 14, pos.Y + math.floor((size.Y - 13) * 0.5))
    end
end

local function compute_track_rect(pos, size, hasTitle, icons, reqWidth)
    if hasTitle then
        local maxAllowed = math.max(80, math.floor(size.X * 0.48))
        local trackW = reqWidth and math.clamp(reqWidth, 80, maxAllowed) or math.clamp(math.floor(size.X * 0.44), 80, 210)
        local trackX = pos.X + size.X - trackW - 14
        local trackY = pos.Y + math.floor((size.Y - 4) * 0.5)
        return trackX, trackY, trackW
    end

    local padL = 16
    local padR = 16
    if icons and icons.From then padL = 42 end
    if icons and icons.To then padR = 42 end
    local trackW = math.max(60, size.X - padL - padR)
    local trackX = pos.X + padL
    local trackY = pos.Y + math.floor((size.Y - 4) * 0.5)
    return trackX, trackY, trackW
end

function Slider.new(section, id, config)
    local cfg = config or {}
    local rawTitle = cfg.Text or cfg.Title
    local hasTitle = rawTitle ~= nil and rawTitle ~= "" and not cfg.Wide

    local rowH = hasTitle and 44 or 40
    local pos, size = section:AllocateControlSlot(cfg.Half or cfg.Column ~= nil, rowH)

    local rawMin = cfg.Min or (cfg.Value and cfg.Value.Min) or 0
    local rawMax = cfg.Max or (cfg.Value and cfg.Value.Max) or 100
    local minVal = math.min(rawMin, rawMax)
    local maxVal = math.max(rawMin, rawMax)
    local defVal = cfg.Default or (cfg.Value and cfg.Value.Default) or minVal
    local stepVal = cfg.Step or 1
    local precision = cfg.Precision
    if precision == nil then
        precision = (stepVal % 1 ~= 0) and 2 or 0
    end
    local sldVal = math.clamp(defVal, minVal, maxVal)

    local self = setmetatable({
        Section = section,
        Id = id,
        Text = rawTitle or "",
        HasTitle = hasTitle,
        Min = minVal,
        Max = maxVal,
        Step = stepVal,
        Precision = precision,
        Value = sldVal,
        Icons = cfg.Icons,
        ReqWidth = cfg.Width,
        Position = pos,
        Size = size,
        Visible = section.Visible,
        Callback = cfg.Callback or function() end,
    }, Slider)

    local pool = section.Pool
    if pool then
        local trackCol = ThemeModule.Get("Slider.TrackBg")
        local fillCol = ThemeModule.Get("Accent.Blue")
        local rowBgCol = ThemeModule.Get("ElementBackground")
        local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

        -- 1. Integrated Row Card Container
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

        local trackX, trackY, trackW = compute_track_rect(pos, size, hasTitle, self.Icons, self.ReqWidth)

        if hasTitle then
            -- 2. Title Label (Single UI font, zero outline)
            local lbl = pool:Get("Text")
            lbl.Text = self.Text
            lbl.Font = fontUI
            lbl.Outline = false
            lbl.Size = 13
            lbl.Color = ThemeModule.Get("Text.Title")
            lbl.Position = Vector2.new(pos.X + 14, pos.Y + math.floor((size.Y - 13) * 0.5))
            lbl.ZIndex = 5
            lbl.Visible = section.Visible
            self.Label = lbl
            section:_register(lbl)

            -- 3. Value Badge (placed just left of track)
            local badge = pool:Get("Text")
            badge.Text = tostring(self.Value)
            badge.Font = fontUI
            badge.Outline = false
            badge.Size = 12
            badge.Color = ThemeModule.Get("Text.Secondary")
            badge.Position = Vector2.new(trackX - 38, pos.Y + math.floor((size.Y - 12) * 0.5))
            badge.ZIndex = 5
            badge.Visible = section.Visible
            self.Badge = badge
            section:_register(badge)
        end

        -- Optional Slider Icons (From / To, pure white PNG with transparency)
        if self.Icons then
            if self.Icons.From then
                local icoFrom = pool:Get("Image")
                icoFrom.Size = Vector2.new(16, 16)
                icoFrom.Position = Vector2.new(pos.X + 14, pos.Y + math.floor((size.Y - 16) * 0.5))
                icoFrom.Transparency = 0.65
                icoFrom.ZIndex = 5
                icoFrom.Visible = section.Visible
                self.IconFrom = icoFrom
                section:_register(icoFrom)
                IconsModule.Get(self.Icons.From, function(png)
                    if self.IconFrom and png then self.IconFrom.Data = png end
                end)
            end

            if self.Icons.To then
                local icoTo = pool:Get("Image")
                icoTo.Size = Vector2.new(16, 16)
                icoTo.Position = Vector2.new(pos.X + size.X - 30, pos.Y + math.floor((size.Y - 16) * 0.5))
                icoTo.Transparency = 0.85
                icoTo.ZIndex = 5
                icoTo.Visible = section.Visible
                self.IconTo = icoTo
                section:_register(icoTo)
                IconsModule.Get(self.Icons.To, function(png)
                    if self.IconTo and png then self.IconTo.Data = png end
                end)
            end
        end

        -- 4. Track Background (4px sleek WindUI bar)
        local track = pool:Get("Square")
        track.Position = Vector2.new(trackX, trackY)
        track.Size = Vector2.new(trackW, 4)
        track.Color = trackCol
        track.Filled = true
        track.Corner = 2
        track.ZIndex = 5
        track.Visible = section.Visible
        self.Track = track
        section:_register(track)

        -- 5. Fill Bar (4px vibrant WindUI blue #0091FF)
        local range = self.Max - self.Min
        local pct = range > 0 and math.clamp((self.Value - self.Min) / range, 0, 1) or 0
        local fillW = math.floor(trackW * pct)

        local fill = pool:Get("Square")
        fill.Position = Vector2.new(trackX, trackY)
        fill.Size = Vector2.new(math.max(fillW, 3), 4)
        fill.Color = fillCol
        fill.Filled = true
        fill.Corner = 2
        fill.ZIndex = 6
        fill.Visible = section.Visible
        self.FillBar = fill
        section:_register(fill)

        -- 6. Thumb Knob (WindUI White Rounded Capsule Pill: 24x14px, corner 7)
        local thumb = pool:Get("Square")
        local thumbW = 24
        local thumbH = 14
        thumb.Size = Vector2.new(thumbW, thumbH)
        thumb.Position = Vector2.new(trackX + fillW - math.floor(thumbW * 0.5), trackY + 2 - math.floor(thumbH * 0.5))
        thumb.Color = Color3.fromRGB(255, 255, 255)
        thumb.Filled = true
        thumb.Corner = 7
        thumb.ZIndex = 7
        thumb.Visible = section.Visible
        self.Thumb = thumb
        self.VisualKnob = thumb
        section:_register(thumb)
    end

    self:SetPosition(pos, size)
    return self
end

function Slider:SetPosition(pos, size)
    self.Position = pos
    self.Size = size or self.Size

    if self.RowBg then
        self.RowBg.Position = pos
        self.RowBg.Size = self.Size
    end

    local trackX, trackY, trackW = compute_track_rect(pos, self.Size, self.HasTitle, self.Icons, self.ReqWidth)

    sync_slider_header(self, trackX)

    if self.IconFrom then
        self.IconFrom.Size = Vector2.new(16, 16)
        self.IconFrom.Position = Vector2.new(pos.X + 14, pos.Y + math.floor((self.Size.Y - 16) * 0.5))
    end
    if self.IconTo then
        self.IconTo.Size = Vector2.new(16, 16)
        self.IconTo.Position = Vector2.new(pos.X + self.Size.X - 30, pos.Y + math.floor((self.Size.Y - 16) * 0.5))
    end

    if self.Track then
        self.Track.Position = Vector2.new(trackX, trackY)
        self.Track.Size = Vector2.new(trackW, 4)
    end

    local range = self.Max - self.Min
    local pct = range > 0 and math.clamp((self.Value - self.Min) / range, 0, 1) or 0
    local fillW = math.floor(trackW * pct)

    if self.FillBar then
        self.FillBar.Position = Vector2.new(trackX, trackY)
        self.FillBar.Size = Vector2.new(math.max(fillW, 3), 4)
    end

    if self.Thumb then
        local thumbW = 24
        local thumbH = 14
        self.Thumb.Size = Vector2.new(thumbW, thumbH)
        self.Thumb.Position = Vector2.new(trackX + fillW - math.floor(thumbW * 0.5), trackY + 2 - math.floor(thumbH * 0.5))
    end
end

function Slider:Set(val)
    local num = tonumber(val) or self.Min
    local clamped = math.clamp(num, self.Min, self.Max)
    if self.Step and self.Step > 0 then
        clamped = math.floor(clamped / self.Step + 0.5) * self.Step
        clamped = math.clamp(clamped, self.Min, self.Max)
    end
    if self.Precision and self.Precision >= 0 then
        local factor = 10 ^ self.Precision
        clamped = math.floor(clamped * factor + 0.5) / factor
    end
    self.Value = clamped

    if self.Track and self.FillBar and self.Position and self.Size then
        local trackX, trackY, trackW = compute_track_rect(self.Position, self.Size, self.HasTitle, self.Icons, self.ReqWidth)
        self.Track.Position = Vector2.new(trackX, trackY)
        self.Track.Size = Vector2.new(trackW, 4)
        local r = self.Max - self.Min
        local p = r > 0 and math.clamp((clamped - self.Min) / r, 0, 1) or 0
        local fillW = math.floor(trackW * p)
        self.FillBar.Position = Vector2.new(trackX, trackY)
        self.FillBar.Size = Vector2.new(math.max(fillW, 3), 4)
        if self.Thumb then
            local thumbW = 24
            local thumbH = 14
            self.Thumb.Size = Vector2.new(thumbW, thumbH)
            self.Thumb.Position = Vector2.new(trackX + fillW - math.floor(thumbW * 0.5), trackY + 2 - math.floor(thumbH * 0.5))
        end
        sync_slider_header(self, trackX)
    elseif self.Badge then
        self.Badge.Text = tostring(clamped)
    end

    if self.Visible and self._clipTop and self._clipBottom and self.Section and self.Section.ClipControl then
        self.Section.ClipControl(self, self._clipTop, self._clipBottom)
    end

    local lib = self.Section and self.Section.Env
    if lib and lib.Options and rawget(lib.Options, self.Id) == self then
        self.Value = clamped
    end
    pcall(self.Callback, clamped)
end

function Slider:SetTitle(title)
    self.Text = tostring(title or "")
    self.HasTitle = self.Text ~= ""
    if self.Position and self.Size then
        self:SetPosition(self.Position, self.Size)
    elseif self.Label then
        self.Label.Text = self.Text
    end
end

function Slider:Lock(title)
    self.Locked = true
    if title ~= nil then self.LockedTitle = tostring(title) end
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Muted")
    end
end

function Slider:Unlock()
    self.Locked = false
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Title")
    end
end

function Slider:Drag(normX)
    local p = math.clamp(normX, 0, 1)
    local raw = self.Min + (self.Max - self.Min) * p
    self:Set(raw)
end

function Slider:SetVisible(vis)
    self.Visible = vis
    if self.RowBg then self.RowBg.Visible = vis end
    if self.Track then self.Track.Visible = vis end
    if self.FillBar then self.FillBar.Visible = vis end
    if self.Thumb then self.Thumb.Visible = vis end
    if self.Label then self.Label.Visible = vis end
    if self.Badge then self.Badge.Visible = vis end
    if self.IconFrom then self.IconFrom.Visible = vis end
    if self.IconTo then self.IconTo.Visible = vis end
end

function Slider:Destroy()
    self:SetVisible(false)
end

return Slider
