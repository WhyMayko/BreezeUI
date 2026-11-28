-- Library/BreezeUI/Engine/InputHandler.lua
-- Win32 Virtual-Key keyboard polling, Shift symbol mapping, Backspace hold-repeat, and key-capture engine.
-- Ported cleanly from Obsidian V2's verified input subsystem for Matcha LuaVM.

local InputHandler = {}

local text_chars = {}
for k = 48, 57 do text_chars[k] = string.char(k) end
for k = 65, 90 do text_chars[k] = string.char(k + 32) end
for k = 96, 105 do text_chars[k] = tostring(k - 96) end -- Numpad 0-9

local shift_nums = {
    ["0"] = ")", ["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$",
    ["5"] = "%", ["6"] = "^", ["7"] = "&", ["8"] = "*", ["9"] = "(",
}

local oem_keys = {
    [0xBA] = { ";", ":" },
    [0xBB] = { "=", "+" },
    [0xBC] = { ",", "<" },
    [0xBD] = { "-", "_" },
    [0xBE] = { ".", ">" },
    [0xBF] = { "/", "?" },
    [0xC0] = { "`", "~" },
    [0xDB] = { "[", "{" },
    [0xDC] = { "\\", "|" },
    [0xDD] = { "]", "}" },
    [0xDE] = { "'", '"' },
    [0x6A] = { "*", "*" },
    [0x6B] = { "+", "+" },
    [0x6D] = { "-", "-" },
    [0x6E] = { ".", "." },
    [0x6F] = { "/", "/" },
}

local function rbx_active()
    if type(isrbxactive) == "function" then
        return isrbxactive() == true
    end
    return true
end

function InputHandler.new()
    return setmetatable({
        PrevKeys = {},
        HoldKey = nil,
        HoldStarted = 0,
        HoldLastRepeat = 0,
    }, { __index = InputHandler })
end

function InputHandler:KeyPressed(vk)
    if not rbx_active() then
        return false
    end
    local current = iskeypressed(vk) == true
    local previous = self.PrevKeys[vk] == true
    self.PrevKeys[vk] = current
    return current and not previous
end

function InputHandler:ReadBackspaceRepeat()
    if not rbx_active() then
        return false
    end
    local down = iskeypressed(0x08) == true
    if not down then
        if self.HoldKey == 0x08 then
            self.HoldKey = nil
            self.HoldStarted = 0
            self.HoldLastRepeat = 0
        end
        return false
    end
    local now = os.clock()
    if self.HoldKey ~= 0x08 then
        self.HoldKey = 0x08
        self.HoldStarted = now
        self.HoldLastRepeat = now
        return false
    end
    if (now - self.HoldStarted) >= 0.35 and (now - self.HoldLastRepeat) >= 0.07 then
        self.HoldLastRepeat = now
        return true
    end
    return false
end

function InputHandler:ReadTextInput()
    if not rbx_active() then
        return nil
    end

    if self:KeyPressed(0x1B) then return "escape" end
    if self:KeyPressed(0x0D) then return "enter" end
    if self:KeyPressed(0x08) or self:ReadBackspaceRepeat() then
        if iskeypressed(0x11) then
            return "clear"
        end
        return "backspace"
    end
    if iskeypressed(0x11) and (self:KeyPressed(0x5A) or self:KeyPressed(0x41)) then
        return "clear"
    end
    if self:KeyPressed(0x20) then return " " end

    local shiftHeld = (iskeypressed(0x10) == true) or (iskeypressed(0xA0) == true) or (iskeypressed(0xA1) == true)

    for vk, ch in pairs(text_chars) do
        if self:KeyPressed(vk) then
            if shiftHeld then
                return shift_nums[ch] or string.upper(ch)
            end
            return ch
        end
    end

    for vk, pair in pairs(oem_keys) do
        if self:KeyPressed(vk) then
            return shiftHeld and pair[2] or pair[1]
        end
    end

    return nil
end

function InputHandler:ReadListenKey(m1Clicked, m2Clicked, elapsedSinceStart)
    if not rbx_active() then
        return nil
    end
    if self:KeyPressed(4) then return 4 end
    if self:KeyPressed(5) then return 5 end
    if self:KeyPressed(6) then return 6 end

    if (elapsedSinceStart or 0) > 0.15 then
        if m1Clicked then return 1 end
        if m2Clicked then return 2 end
    end

    -- Check specific modifier keys first so LShift/RShift/LCtrl/RCtrl/LAlt/RAlt resolve cleanly
    for key = 0xA0, 0xA5 do
        if self:KeyPressed(key) then
            return key
        end
    end

    for key = 8, 254 do
        if key ~= 0x10 and key ~= 0x11 and key ~= 0x12 and (key < 0xA0 or key > 0xA5) and self:KeyPressed(key) then
            return key
        end
    end

    for key = 0x10, 0x12 do
        if self:KeyPressed(key) then
            return key
        end
    end
    return nil
end

return InputHandler
