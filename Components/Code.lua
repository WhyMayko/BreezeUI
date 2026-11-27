-- Library/BreezeUI/Components/Code.lua
-- WindUI Code viewer block with multiline layout and Copy-to-Clipboard action.

local ThemeModule = Theme or require("../Layout/Theme")
local IconsModule = Icons or require("../Subsystems/Icons")
local MetricsModule = Metrics or require("../Core/Metrics")

local Code = {}
Code.__index = Code

local function split_code_lines(src, maxW, maxLines)
    local out = {}
    local str = tostring(src or "")
    local maxChars = math.max(16, math.floor(maxW / 6.5))
    for raw in (str .. "\n"):gmatch("(.-)\n") do
        if #out >= maxLines then break end
        if #raw > maxChars then
            table.insert(out, string.sub(raw, 1, maxChars - 3) .. "...")
        else
            table.insert(out, raw)
        end
    end
    if #out == 0 then table.insert(out, "") end
    return out
end

function Code.new(section, config)
    local cfg = config or {}
    local codeStr = tostring(cfg.Code or "")
    local lines = split_code_lines(codeStr, 360, 8)
    local headerH = 30
    local bodyH = math.max(28, #lines * 16 + 14)
    local rowH = cfg.Height or (headerH + bodyH)

    local pos, size = section:AllocateControlSlot(false, rowH)

    local self = setmetatable({
        Section = section,
        Title = tostring(cfg.Title or "Code"),
        Code = codeStr,
        CanCopied = cfg.CanCopied ~= false,
        OnCopy = cfg.OnCopy,
        Position = pos,
        Size = size,
        Visible = section.Visible,
        Lines = lines,
        LineDrawings = {},
        CopyRect = { X = 0, Y = 0, W = 0, H = 0 },
        _copyIconData = nil,
    }, Code)

    local pool = section.Pool
    if pool then
        local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

        local bg = pool:Get("Square")
        bg.Position = pos
        bg.Size = size
        bg.Color = ThemeModule.Get("Window.Background", Color3.fromRGB(14, 14, 18))
        bg.Filled = true
        bg.Corner = 10
        bg.ZIndex = 4
        bg.Visible = section.Visible
        self.Visual = bg
        section:_register(bg)

        local border = pool:Get("Square")
        border.Position = pos
        border.Size = size
        border.Color = ThemeModule.Get("Card.Border", Color3.fromRGB(44, 44, 52))
        border.Filled = false
        border.Thickness = 1
        border.Corner = 10
        border.ZIndex = 7
        border.Visible = section.Visible
        self.Border = border
        section:_register(border)

        local hdrBg = pool:Get("Square")
        hdrBg.Position = pos
        hdrBg.Size = Vector2.new(size.X, headerH)
        hdrBg.Color = ThemeModule.Get("Control.Background", Color3.fromRGB(32, 32, 38))
        hdrBg.Filled = true
        hdrBg.Corner = 8
        hdrBg.ZIndex = 5
        hdrBg.Visible = section.Visible
        self.HeaderBg = hdrBg
        section:_register(hdrBg)

        local titleTxt = pool:Get("Text")
        titleTxt.Text = self.Title
        titleTxt.Font = fontUI
        titleTxt.Outline = false
        titleTxt.Size = 12
        titleTxt.Color = ThemeModule.Get("Text.Secondary", Color3.fromRGB(175, 175, 185))
        titleTxt.Position = Vector2.new(pos.X + 12, pos.Y + 8)
        titleTxt.ZIndex = 6
        titleTxt.Visible = section.Visible
        self.TitleText = titleTxt
        section:_register(titleTxt)

        if self.CanCopied then
            local cBg = pool:Get("Square")
            cBg.Filled = true
            cBg.Corner = 5
            cBg.Color = ThemeModule.Get("ElementBackground", Color3.fromRGB(46, 46, 54))
            cBg.ZIndex = 6
            cBg.Visible = section.Visible
            self.CopyBg = cBg
            section:_register(cBg)

            local cTxt = pool:Get("Text")
            cTxt.Text = "Copy"
            cTxt.Font = fontUI
            cTxt.Outline = false
            cTxt.Size = 11
            cTxt.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
            cTxt.ZIndex = 7
            cTxt.Visible = section.Visible
            self.CopyText = cTxt
            section:_register(cTxt)
        end

        for i = 1, 8 do
            local ln = pool:Get("Text")
            ln.Text = lines[i] or ""
            ln.Font = fontUI
            ln.Outline = false
            ln.Size = 12
            ln.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(220, 225, 235))
            ln.Position = Vector2.new(pos.X + 12, pos.Y + headerH + 8 + (i - 1) * 16)
            ln.ZIndex = 5
            ln.Visible = section.Visible and (lines[i] ~= nil)
            self.LineDrawings[i] = ln
            section:_register(ln)
        end
    end

    self:SetPosition(pos, size)
    return self
end

function Code:SetPosition(pos, size)
    self.Position = pos
    self.Size = size or self.Size
    self.Lines = split_code_lines(self.Code, math.max(120, self.Size.X - 24), 8)

    if self.Visual then
        self.Visual.Position = pos
        self.Visual.Size = self.Size
    end
    if self.Border then
        self.Border.Position = pos
        self.Border.Size = self.Size
    end
    if self.HeaderBg then
        self.HeaderBg.Position = pos
        self.HeaderBg.Size = Vector2.new(self.Size.X, 30)
    end
    if self.TitleText then
        self.TitleText.Text = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(self.Title, self.Size.X - 90, 12) or self.Title
        self.TitleText.Position = Vector2.new(pos.X + 12, pos.Y + 8)
    end
    if self.CopyBg and self.CopyText then
        local cw, ch = 54, 20
        local cx = pos.X + self.Size.X - cw - 8
        local cy = pos.Y + 5
        self.CopyBg.Position = Vector2.new(cx, cy)
        self.CopyBg.Size = Vector2.new(cw, ch)
        self.CopyText.Center = true
        self.CopyText.Position = Vector2.new(cx + math.floor(cw * 0.5), cy + math.floor(ch * 0.5))
        self.CopyRect = { X = cx, Y = cy, W = cw, H = ch }
    end
    for i = 1, 8 do
        local ln = self.LineDrawings[i]
        if ln then
            ln.Text = self.Lines[i] or ""
            ln.Position = Vector2.new(pos.X + 12, pos.Y + 38 + (i - 1) * 16)
            ln.Visible = self.Visible and (self.Lines[i] ~= nil)
        end
    end
end

function Code:SetVisible(vis)
    self.Visible = vis
    if self.Visual then self.Visual.Visible = vis end
    if self.Border then self.Border.Visible = vis end
    if self.HeaderBg then self.HeaderBg.Visible = vis end
    if self.TitleText then self.TitleText.Visible = vis end
    if self.CopyBg then self.CopyBg.Visible = vis end
    if self.CopyText then self.CopyText.Visible = vis end
    for i = 1, 8 do
        local ln = self.LineDrawings[i]
        if ln then ln.Visible = vis and (self.Lines[i] ~= nil) end
    end
end

function Code:SetCode(newCode)
    self.Code = tostring(newCode or "")
    self:SetPosition(self.Position, self.Size)
end
Code.Set = Code.SetCode

function Code:_setCopyLabel(labelStr)
    if not self.CopyText then return end
    self.CopyText.Text = labelStr
    self.CopyText.Center = true
    local r = self.CopyRect
    if r and r.W > 0 then
        self.CopyText.Position = Vector2.new(r.X + math.floor(r.W * 0.5), r.Y + math.floor(r.H * 0.5))
    end
end

function Code:HandleClick(mx, my)
    if not self.CanCopied then return false end
    local r = self.CopyRect
    if mx >= r.X and mx <= r.X + r.W and my >= r.Y and my <= r.Y + r.H then
        pcall(function()
            if type(setclipboard) == "function" then setclipboard(self.Code) end
            if type(toclipboard) == "function" then toclipboard(self.Code) end
        end)
        self._copiedUntil = os.clock() + 1.5
        self:_setCopyLabel("Copied")
        if self.OnCopy then
            local ok, err = pcall(self.OnCopy, self.Code)
            if not ok then
                assert(false, "Code OnCopy error: " .. tostring(err) .. "!")
            end
        end
        return true
    end
    return false
end

return Code
