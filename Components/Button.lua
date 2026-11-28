-- Library/BreezeUI/Components/Button.lua
-- WindUI-identical action button with icon support, Justify, Tags badges, color support, and System font.

local ThemeModule = Theme or require("../Layout/Theme")
local IconsModule = Icons or require("../Subsystems/Icons")
local MetricsModule = Metrics or require("../Core/Metrics")

local Button = {}
Button.__index = Button

-- WindUI tag color palette
local TAG_COLORS = {
    Blue   = Color3.fromRGB(37, 122, 247),
    Green  = Color3.fromRGB(34, 197, 94),
    Red    = Color3.fromRGB(239, 68, 68),
    Yellow = Color3.fromRGB(234, 179, 8),
    Purple = Color3.fromRGB(168, 85, 247),
    Orange = Color3.fromRGB(249, 115, 22),
    Gray   = Color3.fromRGB(100, 106, 128),
}

local function layout_button(self)
    local pos = self.Position
    local size = self.Size
    local hasDesc = self.Desc and self.Desc ~= ""
    local txtW = (MetricsModule and MetricsModule.GetTextWidth and MetricsModule.GetTextWidth(self.Text, 13)) or math.floor(#self.Text * 6.5)
    local lblY = hasDesc and (pos.Y + 9) or (pos.Y + math.floor((size.Y - 13) * 0.5))
    local icoY = pos.Y + math.floor((size.Y - 16) * 0.5)

    -- Reposition Tags badges from right side (leave room for right-aligned icon if present)
    local hasRightIcon = (self.IconImg ~= nil) and (self.Justify ~= "Center") and (self.IconAlign ~= "Left")
    local tagEndX = pos.X + size.X - (hasRightIcon and 38 or 14)
    if self.TagBadges and #self.TagBadges > 0 then
        local tagH = 18
        for i = #self.TagBadges, 1, -1 do
            local tb = self.TagBadges[i]
            local str = tostring(tb.Label.Text or "")
            local tagTxtW = (MetricsModule and MetricsModule.GetTextWidth and MetricsModule.GetTextWidth(str, 11)) or math.floor(#str * 6.0)
            local tagW = math.max(math.floor(#str * 6.5) + 14, tagTxtW + 14)
            tagEndX = tagEndX - tagW
            local tagY = pos.Y + math.floor((size.Y - tagH) * 0.5)
            tb.Bg.Position = Vector2.new(tagEndX, tagY)
            tb.Bg.Size = Vector2.new(tagW, tagH)
            tb.Label.Center = false
            local ax, ay
            if MetricsModule and MetricsModule.AlignCenter then
                ax, ay = MetricsModule.AlignCenter(tagEndX, tagY, tagW, tagH, str, 11)
            else
                ax = tagEndX + math.floor((tagW - tagTxtW) * 0.5)
                ay = tagY + math.floor((tagH - 11) * 0.5)
            end
            tb.Label.Position = Vector2.new(ax, ay)
            tagEndX = tagEndX - 6
        end
    end

    if self.Justify == "Center" then
        if self.IconImg then
            local startX = pos.X + math.max(14, math.floor((size.X - (txtW + 22)) * 0.5))
            if self.Label then self.Label.Center = false end
            if self.IconAlign == "Left" then
                self.IconImg.Position = Vector2.new(startX, icoY)
                if self.Label then self.Label.Position = Vector2.new(startX + 22, lblY) end
            else
                if self.Label then self.Label.Position = Vector2.new(startX, lblY) end
                self.IconImg.Position = Vector2.new(startX + txtW + 6, icoY)
            end
        elseif self.Label then
            self.Label.Center = false
            local ax = pos.X + math.floor((size.X - txtW) * 0.5)
            if MetricsModule and MetricsModule.AlignCenter then
                ax = MetricsModule.AlignCenter(pos.X, pos.Y, size.X, size.Y, self.Text, 13)
            end
            self.Label.Position = Vector2.new(ax, lblY)
        end
        if self.DescLabel then
            self.DescLabel.Position = Vector2.new(pos.X + 14, pos.Y + 27)
        end
    elseif self.IconImg and self.IconAlign == "Left" then
        self.IconImg.Position = Vector2.new(pos.X + 14, icoY)
        if self.Label then
            self.Label.Center = false
            self.Label.Position = Vector2.new(pos.X + 36, lblY)
        end
        if self.DescLabel then self.DescLabel.Position = Vector2.new(pos.X + 36, pos.Y + 27) end
    else
        if self.Label then
            self.Label.Center = false
            self.Label.Position = Vector2.new(pos.X + 14, lblY)
        end
        if self.DescLabel then self.DescLabel.Position = Vector2.new(pos.X + 14, pos.Y + 27) end
        if self.IconImg then
            self.IconImg.Position = Vector2.new(pos.X + size.X - 30, icoY)
        end
    end
end

function Button.new(section, config)
    local cfg = config or {}
    local desc = cfg.Desc or cfg.Description
    local baseH = (cfg.Size == "Small" and 32) or (cfg.Size == "Large" and 48) or 44
    local rowH = (desc and desc ~= "") and math.max(52, baseH) or baseH
    local pos, size = section:AllocateControlSlot(cfg.Half or cfg.Column ~= nil, rowH)
    local iconOpt = (cfg.Icon == false or cfg.Icon == "") and false or (cfg.Icon or "mouse-pointer-click")

    local self = setmetatable({
        Section = section,
        Text = cfg.Text or cfg.Title or "Button",
        Desc = desc,
        Icon = iconOpt,
        CustomColor = cfg.Color,
        Justify = cfg.Justify or "Between",
        IconAlign = cfg.IconAlign or "Right",
        Position = pos,
        Size = size,
        Visible = section.Visible,
        Callback = cfg.Callback or function() end,
        TagBadges = {},
    }, Button)

    local pool = section.Pool
    if pool then
        local btnBg = self.CustomColor or ThemeModule.Get("ElementBackground", Color3.fromRGB(42, 42, 44))
        local txtCol = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
        local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

        -- 1. Button Surface Card
        local vis = pool:Get("Square")
        vis.Position = pos
        vis.Size = size
        vis.Color = btnBg
        vis.Filled = true
        vis.Corner = 8
        vis.ZIndex = 4
        vis.Visible = section.Visible
        self.Visual = vis
        section:_register(vis)

        -- 2. Button Label Text
        local lbl = pool:Get("Text")
        lbl.Text = self.Text
        lbl.Font = fontUI
        lbl.Outline = false
        lbl.Size = 13
        lbl.Color = txtCol
        lbl.ZIndex = 5
        lbl.Visible = section.Visible
        self.Label = lbl
        section:_register(lbl)

        if self.Desc and self.Desc ~= "" then
            local dLbl = pool:Get("Text")
            dLbl.Text = self.Desc
            dLbl.Font = fontUI
            dLbl.Outline = false
            dLbl.Size = 11
            dLbl.Color = ThemeModule.Get("Text.Secondary", Color3.fromRGB(161, 161, 170))
            dLbl.ZIndex = 5
            dLbl.Visible = section.Visible
            self.DescLabel = dLbl
            section:_register(dLbl)
        end

        if iconOpt ~= false then
            local ico = pool:Get("Image")
            ico.Size = Vector2.new(16, 16)
            ico.Transparency = 0.88
            ico.ZIndex = 5
            ico.Visible = section.Visible
            self.IconImg = ico
            section:_register(ico)
            if IconsModule and IconsModule.Get then
                IconsModule.Get(iconOpt, function(png)
                    if self.IconImg and png then self.IconImg.Data = png end
                end)
            end
        end

        -- 3. Tags badges (WindUI parity: small colored pill badges after title)
        local tags = cfg.Tags or {}
        for _, tagDef in ipairs(tags) do
            local tagTitle = tostring(tagDef.Title or tagDef.Text or "")
            if tagTitle ~= "" then
                local tagColName = tagDef.Color or "Blue"
                local tagCol = TAG_COLORS[tagColName] or TAG_COLORS.Blue
                local tagTxtW = (MetricsModule and MetricsModule.GetTextWidth and MetricsModule.GetTextWidth(tagTitle, 11)) or math.floor(#tagTitle * 6.0)
                local tagW = math.max(math.floor(#tagTitle * 6.5) + 14, tagTxtW + 14)

                local tagBg = pool:Get("Square")
                tagBg.Filled = true
                tagBg.Corner = 5
                tagBg.Color = tagCol
                tagBg.Transparency = 0.92
                tagBg.ZIndex = 6
                tagBg.Size = Vector2.new(tagW, 18)
                tagBg.Visible = section.Visible
                section:_register(tagBg)

                local tagTxt = pool:Get("Text")
                tagTxt.Text = tagTitle
                tagTxt.Font = fontUI
                tagTxt.Outline = false
                tagTxt.Size = 11
                tagTxt.Center = false
                tagTxt.Color = Color3.fromRGB(255, 255, 255)
                tagTxt.ZIndex = 7
                tagTxt.Visible = section.Visible
                section:_register(tagTxt)

                table.insert(self.TagBadges, { Bg = tagBg, Label = tagTxt })
            end
        end

        layout_button(self)
    end

    return self
end

function Button:SetPosition(pos, size)
    self.Position = pos
    self.Size = size or self.Size

    if self.Visual then
        self.Visual.Position = pos
        self.Visual.Size = self.Size
    end

    layout_button(self)
end

function Button:Click()
    pcall(self.Callback)
end

function Button:SetVisible(vis)
    self.Visible = vis
    if self.Visual then self.Visual.Visible = vis end
    if self.Label then self.Label.Visible = vis end
    if self.DescLabel then self.DescLabel.Visible = vis end
    if self.IconImg then self.IconImg.Visible = vis end
    if self.TagBadges then
        for _, tb in ipairs(self.TagBadges) do
            tb.Bg.Visible = vis
            tb.Label.Visible = vis
        end
    end
end

function Button:SetTitle(title)
    self.Text = tostring(title or "")
    if self.Label then
        self.Label.Text = self.Text
    end
    layout_button(self)
end

function Button:SetDesc(desc)
    self.Desc = desc ~= nil and tostring(desc) or ""
    if self.DescLabel then
        self.DescLabel.Text = self.Desc
    end
end

function Button:Lock(title)
    self.Locked = true
    if title ~= nil then self.LockedTitle = tostring(title) end
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Muted", Color3.fromRGB(120, 120, 130))
    end
end

function Button:Unlock()
    self.Locked = false
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
    end
end

function Button:Destroy()
    self:SetVisible(false)
end

return Button
