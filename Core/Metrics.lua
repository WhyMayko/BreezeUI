-- Library/BreezeUI/Core/Metrics.lua
-- Pure O(1) Monospace text measurement, truncation, and formatting engine.
-- Eliminates TextBounds and prevents IEEE-754 float residue jitter.

local metrics = {}

local key_names = {
    [1] = "M1", [2] = "M2", [3] = "Cancel", [4] = "M3", [5] = "M4", [6] = "M5",
    [8] = "Back", [9] = "Tab", [12] = "Clear", [13] = "Enter",
    [16] = "Shift", [17] = "Ctrl", [18] = "Alt", [19] = "Pause", [20] = "Caps",
    [27] = "Esc", [32] = "Space", [33] = "PgUp", [34] = "PgDn", [35] = "End", [36] = "Home",
    [37] = "Left", [38] = "Up", [39] = "Right", [40] = "Down",
    [44] = "PrtSc", [45] = "Ins", [46] = "Del",
    [91] = "LWin", [92] = "RWin", [93] = "Apps",
    [106] = "Num*", [107] = "Num+", [109] = "Num-", [110] = "Num.", [111] = "Num/",
    [144] = "NumLk", [145] = "ScrLk",
    [160] = "LShift", [161] = "RShift", [162] = "LCtrl", [163] = "RCtrl", [164] = "LAlt", [165] = "RAlt",
    [186] = ";", [187] = "=", [188] = ",", [189] = "-", [190] = ".", [191] = "/", [192] = "`",
    [219] = "[", [220] = "\\", [221] = "]", [222] = "'",
}

for k = 48, 57 do
    key_names[k] = string.char(k)
end

for k = 65, 90 do
    key_names[k] = string.char(k)
end

for k = 96, 105 do
    key_names[k] = "Num" .. tostring(k - 96)
end

local function resolve_size(size, scale)
    local base = size or 14
    local s = scale or 1
    return math.max(1, math.floor(base * s + 0.5))
end

local CHAR_WIDTHS = {
    ["i"] = 0.21, ["l"] = 0.21, ["j"] = 0.22, ["I"] = 0.23, ["."] = 0.21, [","] = 0.21,
    [":"] = 0.22, [";"] = 0.22, ["!"] = 0.23, ["|"] = 0.23, ["'"] = 0.21, ["`"] = 0.23,
    [" "] = 0.25, ["/"] = 0.29, ["\\"] = 0.29, ["-"] = 0.30, ["("] = 0.28, [")"] = 0.28,
    ["["] = 0.28, ["]"] = 0.28, ["r"] = 0.31, ["t"] = 0.30, ["f"] = 0.29,
    ["c"] = 0.40, ["s"] = 0.40, ["v"] = 0.41, ["x"] = 0.40, ["z"] = 0.40, ["k"] = 0.42, ["y"] = 0.42,
    ["a"] = 0.45, ["b"] = 0.48, ["d"] = 0.48, ["e"] = 0.44, ["g"] = 0.48, ["h"] = 0.47,
    ["n"] = 0.47, ["o"] = 0.48, ["p"] = 0.48, ["q"] = 0.48, ["u"] = 0.47,
    ["w"] = 0.65, ["m"] = 0.70, ["W"] = 0.76, ["M"] = 0.72, ["@"] = 0.74, ["%"] = 0.68,
    ["A"] = 0.54, ["B"] = 0.53, ["C"] = 0.53, ["D"] = 0.56, ["E"] = 0.47, ["F"] = 0.46,
    ["G"] = 0.56, ["H"] = 0.58, ["J"] = 0.37, ["K"] = 0.51, ["L"] = 0.44, ["N"] = 0.58,
    ["O"] = 0.60, ["P"] = 0.49, ["Q"] = 0.60, ["R"] = 0.53, ["S"] = 0.47, ["T"] = 0.47,
    ["U"] = 0.56, ["V"] = 0.53, ["X"] = 0.51, ["Y"] = 0.49, ["Z"] = 0.49,
}

function metrics.Measure(text, size, scale)
    local str = tostring(text or "")
    if str == "" then return 0, resolve_size(size, scale) end
    local s = resolve_size(size, scale)
    local w = 0
    for i = 1, #str do
        local c = str:sub(i, i)
        local ratio = CHAR_WIDTHS[c]
        if not ratio then
            ratio = (c >= "0" and c <= "9") and 0.48 or 0.45
        end
        w = w + s * ratio
    end
    return math.floor(w + 0.5), s
end

function metrics.AlignRight(boxX, boxW, text, size, pad, scale)
    local w = metrics.Measure(text, size, scale)
    return boxX + boxW - (pad or 0) - w
end

function metrics.AlignCenter(boxX, boxY, boxW, boxH, text, size, scale)
    local w, h = metrics.Measure(text, size, scale)
    return boxX + math.floor((boxW - w) * 0.5), boxY + math.floor((boxH - h) * 0.5)
end

function metrics.GetTextWidth(text, size, scale)
    local str = tostring(text or "")
    if str == "" then return 0 end
    local resolved = resolve_size(size, scale)
    return #str * (resolved * 0.5)
end

function metrics.GetTextHeight(size, scale)
    return resolve_size(size, scale)
end

function metrics.Fit(text, max_width, size, scale)
    local str = tostring(text or "")
    if str == "" or not max_width or max_width <= 0 then
        return ""
    end
    local resolved = resolve_size(size, scale)
    local char_w = resolved * 0.5
    local max_chars = math.floor(max_width / char_w)

    if #str <= max_chars then
        return str
    end
    if max_chars < 3 then
        return ""
    end
    return string.sub(str, 1, max_chars - 3) .. "..."
end

function metrics.FormatNumber(value, precision)
    if precision == false then
        return tostring(value or 0)
    end
    local decimals = tonumber(precision) or 0
    local val = tonumber(value) or 0

    if decimals <= 0 then
        return tostring(math.floor(val + 0.5))
    end

    local mult = 10 ^ decimals
    local num = math.floor(val * mult + 0.5) / mult
    local str = tostring(num)
    local dot = string.find(str, "%.")

    if not dot then
        return str .. "." .. string.rep("0", decimals)
    end

    local dec_len = #str - dot
    if dec_len < decimals then
        return str .. string.rep("0", decimals - dec_len)
    elseif dec_len > decimals then
        return string.sub(str, 1, dot + decimals)
    end

    return str
end

function metrics.FormatBadge(text)
    return "[" .. tostring(text or "") .. "]"
end

function metrics.KeyName(key)
    if key == nil then return "None" end
    if type(key) == "string" and not tonumber(key) then
        return key
    end
    local num = tonumber(key)
    if not num or num < 1 or num > 255 then return "None" end
    if num >= 112 and num <= 135 then
        return "F" .. tostring(num - 111)
    end
    return key_names[num] or string.format("0x%02X", num)
end

local reverse_keys = {}
for vk, name in pairs(key_names) do
    reverse_keys[name:lower()] = vk
end
for n = 1, 24 do
    reverse_keys["f" .. n] = 111 + n
end
reverse_keys["mb1"] = 1
reverse_keys["mousebutton1"] = 1
reverse_keys["mb2"] = 2
reverse_keys["mousebutton2"] = 2
reverse_keys["mb3"] = 4
reverse_keys["mousebutton3"] = 4
reverse_keys["leftshift"] = 160
reverse_keys["rightshift"] = 161
reverse_keys["leftcontrol"] = 162
reverse_keys["rightcontrol"] = 163
reverse_keys["leftalt"] = 164
reverse_keys["rightalt"] = 165
reverse_keys["backspace"] = 8
reverse_keys["return"] = 13

function metrics.KeyCode(key)
    if key == nil then return nil end
    if type(key) == "number" then return key end
    if type(key) == "string" then
        local num = tonumber(key)
        if num then return num end
        local lower = key:lower()
        if lower == "none" or lower == "" or lower == "?" then return nil end
        return reverse_keys[lower]
    end
    return nil
end

function metrics.FormatKeybind(key, label, mode)
    local name = metrics.KeyName(key)
    local text = "[" .. name .. "]"
    if label and label ~= "" then
        text = text .. " " .. tostring(label)
    end
    if mode and mode ~= "" then
        text = text .. " (" .. tostring(mode) .. ")"
    end
    return text
end

function metrics.Align(x, y, w, h, text_w, text_h, align_x, align_y, margin)
    local m = margin or 0
    local ax = align_x or "Left"
    local ay = align_y or "Center"

    local tx = x + m
    if ax == "Center" then
        tx = x + math.floor((w - text_w) * 0.5)
    elseif ax == "Right" then
        tx = x + w - text_w - m
    end

    local ty = y + m
    if ay == "Center" then
        ty = y + math.floor((h - text_h) * 0.5)
    elseif ay == "Bottom" then
        ty = y + h - text_h - m
    end

    return tx, ty
end

return metrics
