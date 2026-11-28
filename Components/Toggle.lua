-- Library/BreezeUI/Components/Toggle.lua
-- WindUI-identical switch pill & checkmark checkbox with smooth decay animation and zero residual state bugs.

local Keybind = Keybind or require("./Keybind")
local ThemeModule = Theme or require("../Layout/Theme")
local AnimationsModule = Animations or require("../Engine/Animations")
local IconsModule = Icons or require("../Subsystems/Icons")

local Toggle = {}
Toggle.__index = Toggle

local function lerp_color(c1, c2, t)
    local r1, g1, b1 = c1.R or 0, c1.G or 0, c1.B or 0
    local r2, g2, b2 = c2.R or 0, c2.G or 0, c2.B or 0
    if Color3 and Color3.new then
        return Color3.new(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t)
    end
    return t >= 0.5 and c2 or c1
end

function Toggle.new(section, id, config)
    local cfg = config or {}
    local desc = cfg.Desc or cfg.Description
    local rowH = (desc and desc ~= "") and 54 or 44
    local pos, size = section:AllocateControlSlot(cfg.Half or cfg.Column ~= nil, rowH)

    local togVal = (cfg.Default == true) or (cfg.Value == true)
    local self = setmetatable({
        Section = section,
        Id = id,
        Text = cfg.Text or cfg.Title or id,
        Desc = desc,
        Type = cfg.Type or "Toggle",
        Value = togVal,
        AnimProgress = togVal and 1 or 0,
        Position = pos,
        Size = size,
        Visible = section.Visible,
        Callback = cfg.Callback or function() end,
        KeyPicker = nil,
    }, Toggle)

    local pool = section.Pool
    if pool then
        local offCol = ThemeModule.Get("Toggle.TrackOff")
        local onCol = ThemeModule.Get("Accent.Green")
        local rowBgCol = ThemeModule.Get("ElementBackground")
        local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

        -- 1. Integrated Row Card
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
        lbl.Color = ThemeModule.Get("Text.Title")
        local titleY = (self.Desc and self.Desc ~= "") and (pos.Y + 10) or (pos.Y + math.floor((size.Y - 13) * 0.5))
        lbl.Position = Vector2.new(pos.X + 14, titleY)
        lbl.ZIndex = 5
        lbl.Visible = section.Visible
        self.Label = lbl
        section:_register(lbl)

        -- Optional Description Label
        if self.Desc and self.Desc ~= "" then
            local dLbl = pool:Get("Text")
            dLbl.Text = self.Desc
            dLbl.Font = fontUI
            dLbl.Outline = false
            dLbl.Size = 11
            dLbl.Color = ThemeModule.Get("Text.Secondary")
            dLbl.Position = Vector2.new(pos.X + 14, pos.Y + 28)
            dLbl.ZIndex = 5
            dLbl.Visible = section.Visible
            self.DescLabel = dLbl
            section:_register(dLbl)
        end

        -- 3. Switch Pill Track (42x22px) or Checkbox (24x24px)
        local isCheck = self.Type == "Checkbox"
        local trackW = isCheck and 24 or 42
        local trackH = isCheck and 24 or 22
        local trackX = pos.X + size.X - trackW - 14
        local trackY = pos.Y + math.floor((size.Y - trackH) * 0.5)

        local track = pool:Get("Square")
        track.Position = Vector2.new(trackX, trackY)
        track.Size = Vector2.new(trackW, trackH)
        track.Corner = isCheck and 7 or 11
        track.Filled = true
        track.Color = togVal and (isCheck and ThemeModule.Get("Accent.Blue") or onCol) or offCol
        track.ZIndex = 5
        track.Visible = section.Visible
        self.Track = track
        self.SwitchPill = track
        section:_register(track)

        -- 4. Indicator: Checkmark PNG for Checkbox, Sliding White Circle Knob for Switch Toggle
        if isCheck then
            local checkImg = pool:Get("Image")
            checkImg.Size = Vector2.new(16, 16)
            checkImg.Position = Vector2.new(trackX + 4, trackY + 4)
            checkImg.Transparency = 1.0
            checkImg.ZIndex = 6
            checkImg.Visible = section.Visible and togVal
            self.CheckIcon = checkImg
            section:_register(checkImg)
            IconsModule.Get("check", function(png)
                if self.CheckIcon and png then self.CheckIcon.Data = png end
            end)
        else
            local knob = pool:Get("Square")
            knob.Size = Vector2.new(14, 14)
            knob.Corner = 7
            knob.Position = Vector2.new(togVal and (trackX + 24) or (trackX + 4), trackY + 4)
            knob.Filled = true
            knob.Color = Color3.fromRGB(255, 255, 255)
            knob.ZIndex = 6
            knob.Visible = section.Visible
            self.Knob = knob
            self.VisualKnob = knob
            section:_register(knob)
        end
    end

    return self
end

function Toggle:_applyAnimVisual(progress, palette)
    self.AnimProgress = progress
    local isCheck = self.Type == "Checkbox"
    local offCol = ThemeModule.Resolve(palette, "Toggle.TrackOff")
    local onCol = ThemeModule.Resolve(palette, isCheck and "Accent.Blue" or "Accent.Green")

    if self.Track then
        self.Track.Color = lerp_color(offCol, onCol, progress)
    end
    if not isCheck and self.Knob and self.Position and self.Size then
        local trackX = self.Position.X + self.Size.X - 42 - 14
        local trackY = self.Position.Y + math.floor((self.Size.Y - 22) * 0.5)
        local knobX = trackX + 4 + (20 * progress)
        self.Knob.Size = Vector2.new(14, 14)
        self.Knob.Position = Vector2.new(math.floor(knobX + 0.5), trackY + 4)
        if self.Visible and self._clipTop and self._clipBottom and self.Section and self.Section.ClipControl then
            self.Section.ClipControl(self, self._clipTop, self._clipBottom)
        end
    end
end

function Toggle:SetPosition(pos, size)
    self.Position = pos
    self.Size = size or self.Size

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

    local isCheck = self.Type == "Checkbox"
    local trackW = isCheck and 24 or 42
    local trackH = isCheck and 24 or 22
    local trackX = pos.X + self.Size.X - trackW - 14
    local trackY = pos.Y + math.floor((self.Size.Y - trackH) * 0.5)

    if self.Track then
        self.Track.Position = Vector2.new(trackX, trackY)
        self.Track.Size = Vector2.new(trackW, trackH)
    end

    if self.CheckIcon then
        self.CheckIcon.Size = Vector2.new(16, 16)
        self.CheckIcon.Position = Vector2.new(trackX + 4, trackY + 4)
    end

    if self.Knob then
        local p = self.AnimProgress ~= nil and self.AnimProgress or (self.Value and 1 or 0)
        self.Knob.Size = Vector2.new(14, 14)
        self.Knob.Position = Vector2.new(math.floor(trackX + 4 + 20 * p + 0.5), trackY + 4)
    end

    if self.KeyPicker and self.KeyPicker.SetPosition then
        self.KeyPicker:SetPosition(Vector2.new(trackX - 46, trackY))
    end
end

function Toggle:Set(val)
    local boolVal = val == true
    self.Value = boolVal
    local target = boolVal and 1 or 0

    if self.CheckIcon then
        self.CheckIcon.Visible = self.Visible and boolVal
    end

    if self.Visible then
        AnimationsModule.Tween("Toggle_" .. tostring(self), self.AnimProgress or target, target, 20, function(v)
            self:_applyAnimVisual(v)
        end)
    else
        self:_applyAnimVisual(target)
    end

    local lib = self.Section and self.Section.Env
    if lib and lib.Toggles and rawget(lib.Toggles, self.Id) == self then
        self.Value = boolVal
    end
    if self.Section and self.Section.ParentTab then
        self.Section.ParentTab._layoutDirty = true
    end
    pcall(self.Callback, boolVal)
end

function Toggle:SetTitle(title)
    self.Text = tostring(title or "")
    if self.Label then
        self.Label.Text = self.Text
    end
end

function Toggle:SetDesc(desc)
    self.Desc = desc ~= nil and tostring(desc) or ""
    if self.DescLabel then
        self.DescLabel.Text = self.Desc
    end
end

function Toggle:Lock(title)
    self.Locked = true
    if title ~= nil then self.LockedTitle = tostring(title) end
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Muted")
    end
end

function Toggle:Unlock()
    self.Locked = false
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Title")
    end
end

function Toggle:Click()
    self:Set(not self.Value)
end

function Toggle:SetVisible(vis)
    self.Visible = vis
    if self.RowBg then self.RowBg.Visible = vis end
    if self.Track then self.Track.Visible = vis end
    if self.CheckIcon then
        self.CheckIcon.Visible = vis and (self.Value == true)
    end
    if self.Knob then
        self.Knob.Visible = vis
    end
    if self.Label then self.Label.Visible = vis end
    if self.DescLabel then self.DescLabel.Visible = vis end
    if self.KeyPicker and self.KeyPicker.SetVisible then
        self.KeyPicker:SetVisible(vis)
    end
end

function Toggle:AddKeyPicker(keyId, keyConfig)
    local kp = Keybind.new(self, keyId, keyConfig)
    self.KeyPicker = kp
    if keyId then
        local win = self.Section and (self.Section.Window or (self.Section.ParentTab and self.Section.ParentTab.Window))
        local lib = (win and win.Env) or (self.Section and self.Section.Env) or _G.Library
        if lib and lib.Options then
            rawset(lib.Options, keyId, kp)
            if lib._rawOptions then lib._rawOptions[keyId] = kp end
            if win and win.RegisteredIds and win.RegisteredIds.Options then
                win.RegisteredIds.Options[keyId] = true
            end
        end
    end
    return kp
end

function Toggle:Destroy()
    self:SetVisible(false)
end

return Toggle
