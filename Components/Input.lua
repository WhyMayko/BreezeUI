-- Library/BreezeUI/Components/Input.lua
-- Responsive WindUI-identical text input with keyboard typing, caret blink, focus outline, Numeric/Finished modes.

local ThemeModule = Theme or require("../Layout/Theme")
local MetricsModule = Metrics or require("../Core/Metrics")

local Input = {}
Input.__index = Input

local function compute_box_width(totalW)
    return math.min(150, math.max(76, math.floor(totalW * 0.40)))
end

function Input.new(section, id, config)
    local cfg = config or {}
    local pos, size = section:AllocateControlSlot(cfg.Half or cfg.Column ~= nil, section.RowHeight or 44)
    local initialVal = cfg.Default or cfg.Value or ""

    local self = setmetatable({
        Section = section,
        Id = id,
        Text = cfg.Text or cfg.Title or id,
        Placeholder = cfg.Placeholder or "Type here...",
        Value = tostring(initialVal),
        Numeric = cfg.Numeric == true,
        Finished = cfg.Finished == true,
        ClearTextOnFocus = cfg.ClearTextOnFocus == true,
        MaxLength = cfg.MaxLength or 256,
        Focused = false,
        Position = pos,
        Size = size,
        Visible = section.Visible,
        Callback = cfg.Callback or function() end,
    }, Input)

    local pool = section.Pool
    if pool then
        local rowBgCol = ThemeModule.Get("ElementBackground")
        local boxBg = ThemeModule.Get("Control.Background")
        local borderCol = ThemeModule.Get("Control.Border")
        local txtCol = ThemeModule.Get("Text.Title")
        local subCol = ThemeModule.Get("Text.Secondary")
        local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

        -- 1. Integrated Row Background
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
        lbl.Color = txtCol
        lbl.Position = Vector2.new(pos.X + 14, pos.Y + math.floor((size.Y - 13) * 0.5))
        lbl.ZIndex = 5
        lbl.Visible = section.Visible
        self.Label = lbl
        section:_register(lbl)

        -- 3. Responsive Input Box Pill + Focus Border
        local boxW = compute_box_width(size.X)
        local boxH = 26
        local boxX = pos.X + size.X - boxW - 14
        local boxY = pos.Y + math.floor((size.Y - boxH) * 0.5)

        local box = pool:Get("Square")
        box.Position = Vector2.new(boxX, boxY)
        box.Size = Vector2.new(boxW, boxH)
        box.Color = boxBg
        box.Filled = true
        box.Corner = 6
        box.ZIndex = 5
        box.Visible = section.Visible
        self.Box = box
        section:_register(box)

        local boxBorder = pool:Get("Square")
        boxBorder.Position = Vector2.new(boxX, boxY)
        boxBorder.Size = Vector2.new(boxW, boxH)
        boxBorder.Color = borderCol
        boxBorder.Filled = false
        boxBorder.Thickness = 1
        boxBorder.Corner = 6
        boxBorder.ZIndex = 5
        boxBorder.Visible = section.Visible
        self.BoxBorder = boxBorder
        section:_register(boxBorder)

        -- 4. Text Display
        local inp = pool:Get("Text")
        inp.Text = #self.Value > 0 and self.Value or self.Placeholder
        inp.Font = fontUI
        inp.Outline = false
        inp.Size = 12
        inp.Color = #self.Value > 0 and txtCol or subCol
        inp.Position = Vector2.new(boxX + 8, boxY + 6)
        inp.ZIndex = 6
        inp.Visible = section.Visible
        self.InputText = inp
        section:_register(inp)
    end

    self:SetPosition(pos, size)
    return self
end

function Input:_refreshDisplay()
    if not self.InputText then return end
    local txtCol = ThemeModule.Get("Text.Title")
    local subCol = ThemeModule.Get("Text.Secondary")
    local boxW = self.Box and self.Box.Size.X or 120
    local maxChars = math.max(4, math.floor((boxW - 16) / 6.2))

    if #self.Value > 0 then
        local view = #self.Value > maxChars and string.sub(self.Value, #self.Value - maxChars + 1) or self.Value
        local caret = (self.Focused and math.floor(os.clock() * 2) % 2 == 0) and "|" or ""
        self.InputText.Text = view .. caret
        self.InputText.Color = txtCol
    elseif self.Focused then
        self.InputText.Text = (math.floor(os.clock() * 2) % 2 == 0) and "|" or ""
        self.InputText.Color = txtCol
    else
        local ph = #self.Placeholder > maxChars and (string.sub(self.Placeholder, 1, maxChars - 2) .. "..") or self.Placeholder
        self.InputText.Text = ph
        self.InputText.Color = subCol
    end

    if self.BoxBorder then
        self.BoxBorder.Color = ThemeModule.Get(self.Focused and "Accent.Blue" or "Control.Border")
    end
end

function Input:SetPosition(pos, size)
    self.Position = pos
    self.Size = size or self.Size

    if self.RowBg then
        self.RowBg.Position = pos
        self.RowBg.Size = self.Size
    end

    local boxW = compute_box_width(self.Size.X)
    local boxH = 26
    local boxX = pos.X + self.Size.X - boxW - 14
    local boxY = pos.Y + math.floor((self.Size.Y - boxH) * 0.5)

    if self.Label then
        self.Label.Text = MetricsModule.Fit(self.Text, math.max(30, boxX - (pos.X + 14) - 8), 13)
        self.Label.Position = Vector2.new(pos.X + 14, pos.Y + math.floor((self.Size.Y - 13) * 0.5))
    end

    if self.Box then
        self.Box.Position = Vector2.new(boxX, boxY)
        self.Box.Size = Vector2.new(boxW, boxH)
    end
    if self.BoxBorder then
        self.BoxBorder.Position = Vector2.new(boxX, boxY)
        self.BoxBorder.Size = Vector2.new(boxW, boxH)
    end
    if self.InputText then
        self.InputText.Position = Vector2.new(boxX + 8, boxY + 6)
    end
    self:_refreshDisplay()
end

function Input:Set(val, skipCallback)
    self.Value = tostring(val or "")
    if #self.Value > self.MaxLength then
        self.Value = string.sub(self.Value, 1, self.MaxLength)
    end

    local lib = self.Section and self.Section.Env
    if lib and lib.Options and rawget(lib.Options, self.Id) == self then
        self.Value = self.Value
    end
    self:_refreshDisplay()
    if not skipCallback then
        pcall(self.Callback, self.Value)
    end
end

function Input:SetTitle(title)
    self.Text = tostring(title or "")
    if self.Position and self.Size then
        self:SetPosition(self.Position, self.Size)
    elseif self.Label then
        self.Label.Text = self.Text
    end
end

function Input:Lock(title)
    self.Locked = true
    if title ~= nil then self.LockedTitle = tostring(title) end
    if self.Focused then self:Blur(false) end
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Muted")
    end
end

function Input:Unlock()
    self.Locked = false
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Title")
    end
end

function Input:ProcessKey(token)
    if not self.Focused or not token then return end
    if token == "enter" then
        self:Blur(true)
        return
    elseif token == "escape" then
        self:Blur(false)
        return
    elseif token == "backspace" then
        if #self.Value > 0 then
            self:Set(string.sub(self.Value, 1, #self.Value - 1), self.Finished)
        end
        return
    elseif token == "clear" then
        self:Set("", self.Finished)
        return
    end

    if self.Numeric then
        if token == "-" and #self.Value == 0 then
            self:Set("-", self.Finished)
        elseif token == "." and not self.Value:find("%.") then
            self:Set(self.Value .. ".", self.Finished)
        elseif token:match("^%d$") then
            self:Set(self.Value .. token, self.Finished)
        end
    elseif #self.Value < self.MaxLength then
        self:Set(self.Value .. token, self.Finished)
    end
end

function Input:Focus()
    if self.Locked then return end
    if self.ClearTextOnFocus and not self.Focused then
        self.Value = ""
    end
    self.Focused = true
    local win = self.Section and (self.Section.Window or (self.Section.ParentTab and self.Section.ParentTab.Window))
    if win then
        if win.FocusedInput and win.FocusedInput ~= self then
            win.FocusedInput:Blur(false)
        end
        win.FocusedInput = self
        if win.ClaimInteraction then
            win:ClaimInteraction("Input_" .. tostring(self.Id))
        end
    end
    self:_refreshDisplay()
end

function Input:Blur(submitCallback)
    local wasFocused = self.Focused
    self.Focused = false
    local win = self.Section and (self.Section.Window or (self.Section.ParentTab and self.Section.ParentTab.Window))
    if win then
        if win.FocusedInput == self then
            win.FocusedInput = nil
        end
        if win.ReleaseInteraction then
            win:ReleaseInteraction("Input_" .. tostring(self.Id))
        end
    end
    self:_refreshDisplay()
    if wasFocused and (submitCallback or self.Finished) then
        pcall(self.Callback, self.Value)
    end
end

function Input:SetVisible(vis)
    self.Visible = vis
    if self.RowBg then self.RowBg.Visible = vis end
    if self.Box then self.Box.Visible = vis end
    if self.BoxBorder then self.BoxBorder.Visible = vis end
    if self.Label then self.Label.Visible = vis end
    if self.InputText then self.InputText.Visible = vis end
    if not vis and self.Focused then
        self:Blur(false)
    end
end

function Input:Destroy()
    self:SetVisible(false)
end

return Input
