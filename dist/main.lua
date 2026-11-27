-- Library/BreezeUI/Library.lua
-- Fully self-contained Drawing UI Library for Matcha / Luau
-- Pure single-file architecture: ZERO HTTP recursion, ZERO require dependencies, ZERO setfenv.

local _G = _G or {}
local tick = tick or os.clock
local Vector2 = Vector2
if not Vector2 then
    local v2mt
    local function make_v2(x, y)
        return setmetatable({ X = x or 0, Y = y or 0 }, v2mt)
    end
    v2mt = {
        __add = function(a, b) return make_v2((a.X or 0) + (b.X or 0), (a.Y or 0) + (b.Y or 0)) end,
        __sub = function(a, b) return make_v2((a.X or 0) - (b.X or 0), (a.Y or 0) - (b.Y or 0)) end,
        __mul = function(a, b)
            if type(b) == 'number' then return make_v2((a.X or 0) * b, (a.Y or 0) * b) end
            return make_v2((a.X or 0) * (b.X or 0), (a.Y or 0) * (b.Y or 0))
        end,
    }
    Vector2 = { new = make_v2, zero = make_v2(0, 0) }
end
local Color3 = Color3 or {
    fromRGB = function(r, g, b) return { R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 } end,
    new = function(r, g, b) return { R = r or 0, G = g or 0, B = b or 0 } end,
    fromHex = function(hex)
        hex = tostring(hex or '#FFFFFF'):gsub('#', '')
        local r = tonumber(hex:sub(1, 2), 16) or 255
        local g = tonumber(hex:sub(3, 4), 16) or 255
        local b = tonumber(hex:sub(5, 6), 16) or 255
        return { R = r / 255, G = g / 255, B = b / 255 }
    end,
}

local PoolModule, MetaModule, MetricsModule, GeometryModule, ThemeModule, ClampingModule, DragModule, AnimationsModule, InputHandlerModule, IconsModule, SettingsModule, NotifyModule, DialogModule, OverlayModule, KeybindModule, ButtonModule, SliderModule, DropdownModule, InputModule, ToggleModule, ParagraphModule, CodeModule, ImageModule, ProgressBarModule, ColorpickerModule, ContentSectionModule, TabModule, ProfileCardModule, SidebarModule, WindowModule

local function internal_require(path)
    if type(path) ~= 'string' then return nil end
    local name = path:match('([^/\\]+)%.?l?u?a?$') or path
    if name == 'Toggle' then return ToggleModule
    elseif name == 'Slider' then return SliderModule
    elseif name == 'Button' then return ButtonModule
    elseif name == 'Dropdown' then return DropdownModule
    elseif name == 'Input' then return InputModule
    elseif name == 'Keybind' then return KeybindModule
    elseif name == 'Paragraph' then return ParagraphModule
    elseif name == 'Code' then return CodeModule
    elseif name == 'Image' then return ImageModule
    elseif name == 'ProgressBar' then return ProgressBarModule
    elseif name == 'Colorpicker' then return ColorpickerModule
    elseif name == 'ContentSection' then return ContentSectionModule
    elseif name == 'Tab' then return TabModule
    elseif name == 'Sidebar' then return SidebarModule
    elseif name == 'Window' then return WindowModule
    elseif name == 'Theme' then return ThemeModule
    elseif name == 'Pool' then return PoolModule
    elseif name == 'Meta' then return MetaModule
    elseif name == 'Geometry' then return GeometryModule
    elseif name == 'Metrics' then return MetricsModule
    elseif name == 'Clamping' then return ClampingModule
    elseif name == 'Drag' then return DragModule
    elseif name == 'Animations' then return AnimationsModule
    elseif name == 'InputHandler' then return InputHandlerModule
    elseif name == 'Icons' then return IconsModule
    elseif name == 'Settings' then return SettingsModule
    elseif name == 'Notify' then return NotifyModule
    elseif name == 'Dialog' then return DialogModule
    elseif name == 'Overlay' then return OverlayModule
    end
    return nil
end
local require = internal_require

-- ============================================================================
-- MODULE: Core/Pool.lua
-- ============================================================================
PoolModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Core/Pool.lua
-- Centralized lazy Drawing object pool recycling native primitives across render frames.

local pool = {}
pool.__index = pool

local kinds = { "Square", "Circle", "Line", "Text", "Image", "Triangle", "Quad" }
local valid_kinds = {
    Square = true,
    Circle = true,
    Line = true,
    Text = true,
    Image = true,
    Triangle = true,
    Quad = true,
}

function pool.new(max_per_kind, meta_module)
    local meta = meta_module or Meta
    local self = setmetatable({
        Pool = {
            Square = {},
            Circle = {},
            Line = {},
            Text = {},
            Image = {},
            Triangle = {},
            Quad = {},
        },
        Index = {
            Square = 0,
            Circle = 0,
            Line = 0,
            Text = 0,
            Image = 0,
            Triangle = 0,
            Quad = 0,
        },
        HighWater = {
            Square = 0,
            Circle = 0,
            Line = 0,
            Text = 0,
            Image = 0,
            Triangle = 0,
            Quad = 0,
        },
        MaxPerKind = max_per_kind,
        Meta = meta,
        Destroyed = false,
    }, pool)
    return self
end

function pool:Reset()
    local idx = self.Index
    idx.Square = 0
    idx.Circle = 0
    idx.Line = 0
    idx.Text = 0
    idx.Image = 0
    idx.Triangle = 0
    idx.Quad = 0
end

function pool:Get(kind)
    assert(not self.Destroyed, "Cannot get drawing object from destroyed pool!")
    assert(valid_kinds[kind], "Invalid Drawing kind: " .. tostring(kind) .. "!")

    local next_idx = self.Index[kind] + 1
    local max_cap = self.MaxPerKind
    if max_cap then
        local limit = type(max_cap) == "number" and max_cap or max_cap[kind]
        if limit and next_idx > limit then
            next_idx = 1
        end
    end
    self.Index[kind] = next_idx

    local obj = self.Pool[kind][next_idx]
    if not obj then
        assert(Drawing and Drawing.new, "Drawing library not found in environment!")
        obj = Drawing.new(kind)
        self.Pool[kind][next_idx] = obj
    end

    if kind == "Text" then
        obj.Font = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1
        obj.Outline = false
        obj.Center = false
    end

    if not obj.Visible then
        obj.Visible = true
    end
    local meta = self.Meta
    if meta then
        meta.SetVisible(obj, true)
    end

    if next_idx > self.HighWater[kind] then
        self.HighWater[kind] = next_idx
    end

    return obj
end

function pool:HideUnused()
    local meta = self.Meta
    for i = 1, #kinds do
        local kind = kinds[i]
        local list = self.Pool[kind]
        local used = self.Index[kind]
        local total = #list
        for j = used + 1, total do
            local obj = list[j]
            if obj and obj.Visible then
                obj.Visible = false
                if meta then
                    meta.SetVisible(obj, false)
                end
            end
        end
    end
end

function pool:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true

    local meta = self.Meta
    for i = 1, #kinds do
        local kind = kinds[i]
        local list = self.Pool[kind]
        for j = 1, #list do
            local obj = list[j]
            if obj then
                pcall(function()
                    obj.Visible = false
                    obj:Remove()
                end)
                if meta then
                    meta.Clear(obj)
                end
                list[j] = nil
            end
        end
        self.Pool[kind] = {}
        self.Index[kind] = 0
        self.HighWater[kind] = 0
    end
end

function pool:GetStats()
    local stats = {}
    for i = 1, #kinds do
        local kind = kinds[i]
        stats[kind] = {
            Used = self.Index[kind],
            Allocated = #self.Pool[kind],
            HighWater = self.HighWater[kind],
        }
    end
    return stats
end

-- Aliases for Obsidian / WindUI compatibility
pool._resetPool = pool.Reset
pool._get = pool.Get
pool._hideUnused = pool.HideUnused
pool._destroy = pool.Destroy

return pool

end)()

-- ============================================================================
-- MODULE: Core/Meta.lua
-- ============================================================================
MetaModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Core/Meta.lua
-- Weak-table Drawing property cache eliminating DirectX write overhead and Vector2 GC churn.

local meta = {}
local cache = setmetatable({}, { __mode = "k" })
meta.drawingMeta = cache

function meta.Get(obj)
    if not obj then return nil end
    local entry = cache[obj]
    if not entry then
        entry = {}
        cache[obj] = entry
    end
    return entry
end

function meta.SetPosition(obj, x, y)
    if not obj then return end
    local entry = cache[obj]
    if not entry then
        entry = {}
        cache[obj] = entry
    end
    if entry.x ~= x or entry.y ~= y then
        entry.x = x
        entry.y = y
        entry.positionX = x
        entry.positionY = y
        obj.Position = Vector2.new(x, y)
    end
end

function meta.SetPositionV2(obj, pos)
    if not obj then return end
    local x = pos.X
    local y = pos.Y
    local entry = cache[obj]
    if not entry then
        entry = {}
        cache[obj] = entry
    end
    if entry.x ~= x or entry.y ~= y then
        entry.x = x
        entry.y = y
        entry.positionX = x
        entry.positionY = y
        obj.Position = pos
    end
end

function meta.SetSize(obj, w, h)
    if not obj then return end
    local entry = cache[obj]
    if not entry then
        entry = {}
        cache[obj] = entry
    end
    if entry.w ~= w or entry.h ~= h then
        entry.w = w
        entry.h = h
        entry.sizeX = w
        entry.sizeY = h
        entry.sizeW = w
        entry.sizeH = h
        entry.width = w
        entry.height = h
        obj.Size = Vector2.new(w, h)
    end
end

function meta.SetSizeV2(obj, size)
    if not obj then return end
    local w = size.X
    local h = size.Y
    local entry = cache[obj]
    if not entry then
        entry = {}
        cache[obj] = entry
    end
    if entry.w ~= w or entry.h ~= h then
        entry.w = w
        entry.h = h
        entry.sizeX = w
        entry.sizeY = h
        entry.sizeW = w
        entry.sizeH = h
        entry.width = w
        entry.height = h
        obj.Size = size
    end
end

function meta.SetColor(obj, col)
    if not obj then return end
    local entry = cache[obj]
    if not entry then
        entry = {}
        cache[obj] = entry
    end
    -- Fast path: identical Color3 pointer bypasses RGB extraction
    if entry.color == col then return end
    local r = col.R
    local g = col.G
    local b = col.B
    if entry.r ~= r or entry.g ~= g or entry.b ~= b then
        entry.color = col
        entry.r = r
        entry.g = g
        entry.b = b
        entry.colorR = r
        entry.colorG = g
        entry.colorB = b
        obj.Color = col
    else
        entry.color = col
    end
end

function meta.SetTransparency(obj, trans)
    if not obj then return end
    local entry = cache[obj]
    if not entry then
        entry = {}
        cache[obj] = entry
    end
    if entry.trans ~= trans then
        entry.trans = trans
        obj.Transparency = trans
    end
end

function meta.SetVisible(obj, visible)
    if not obj then return end
    local entry = cache[obj]
    if not entry then
        entry = {}
        cache[obj] = entry
    end
    if entry.visible ~= visible then
        entry.visible = visible
        obj.Visible = visible
    end
end

function meta.SetText(obj, text)
    if not obj then return end
    local entry = cache[obj]
    if not entry then
        entry = {}
        cache[obj] = entry
    end
    if entry.text ~= text then
        entry.text = text
        obj.Text = text
    end
end

function meta.SetLine(obj, fx, fy, tx, ty)
    if not obj then return end
    local entry = cache[obj]
    if not entry then
        entry = {}
        cache[obj] = entry
    end
    if entry.fx ~= fx or entry.fy ~= fy then
        entry.fx = fx
        entry.fy = fy
        obj.From = Vector2.new(fx, fy)
    end
    if entry.tx ~= tx or entry.ty ~= ty then
        entry.tx = tx
        entry.ty = ty
        obj.To = Vector2.new(tx, ty)
    end
end

function meta.SetTriangle(obj, ax, ay, bx, by, cx, cy)
    if not obj then return end
    local entry = cache[obj]
    if not entry then
        entry = {}
        cache[obj] = entry
    end
    if entry.ax ~= ax or entry.ay ~= ay then
        entry.ax = ax
        entry.ay = ay
        obj.PointA = Vector2.new(ax, ay)
    end
    if entry.bx ~= bx or entry.by ~= by then
        entry.bx = bx
        entry.by = by
        obj.PointB = Vector2.new(bx, by)
    end
    if entry.cx ~= cx or entry.cy ~= cy then
        entry.cx = cx
        entry.cy = cy
        obj.PointC = Vector2.new(cx, cy)
    end
end

function meta.SetValue(obj, key, val)
    if not obj then return end
    local entry = cache[obj]
    if not entry then
        entry = {}
        cache[obj] = entry
    end
    if entry[key] ~= val then
        entry[key] = val
        obj[key] = val
    end
end

function meta.Clear(obj)
    if not obj then return end
    cache[obj] = nil
end

return meta

end)()

-- ============================================================================
-- MODULE: Core/Metrics.lua
-- ============================================================================
MetricsModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

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

end)()

-- ============================================================================
-- MODULE: Core/Geometry.lua
-- ============================================================================
GeometryModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Core/Geometry.lua
-- High-level primitive rasterizers using native Square.Corner, hairline borders, and carets.

local geometry = {}

local function round(n)
    return math.floor(n + 0.5)
end

local function get_meta(pool)
    return (pool and pool.Meta) or Meta
end

function geometry.DrawCard(pool, pos, size, bg_col, border_col, corner, zindex)
    local z = zindex or 1
    local c = corner or 0
    local px = round(pos.X)
    local py = round(pos.Y)
    local sx = round(size.X)
    local sy = round(size.Y)

    local meta = get_meta(pool)
    local bg = pool:Get("Square")
    if meta then
        meta.SetPosition(bg, px, py)
        meta.SetSize(bg, sx, sy)
        meta.SetColor(bg, bg_col)
        meta.SetValue(bg, "Filled", true)
        meta.SetValue(bg, "Corner", c)
        meta.SetValue(bg, "ZIndex", z)
        meta.SetVisible(bg, true)
    else
        bg.Position = Vector2.new(px, py)
        bg.Size = Vector2.new(sx, sy)
        bg.Color = bg_col
        bg.Filled = true
        bg.Corner = c
        bg.ZIndex = z
        bg.Visible = true
    end

    local border = nil
    if border_col then
        border = pool:Get("Square")
        if meta then
            meta.SetPosition(border, px, py)
            meta.SetSize(border, sx, sy)
            meta.SetColor(border, border_col)
            meta.SetValue(border, "Filled", false)
            meta.SetValue(border, "Thickness", 1)
            meta.SetValue(border, "Corner", c)
            meta.SetValue(border, "ZIndex", z + 1)
            meta.SetVisible(border, true)
        else
            border.Position = Vector2.new(px, py)
            border.Size = Vector2.new(sx, sy)
            border.Color = border_col
            border.Filled = false
            border.Thickness = 1
            border.Corner = c
            border.ZIndex = z + 1
            border.Visible = true
        end
    end

    return { bg = bg, border = border }
end

function geometry.DrawPill(pool, pos, size, bg_col, zindex)
    local z = zindex or 1
    local px = round(pos.X)
    local py = round(pos.Y)
    local sx = round(size.X)
    local sy = round(size.Y)
    local r = math.floor(math.min(sx, sy) * 0.5)

    local meta = get_meta(pool)
    local pill = pool:Get("Square")
    if meta then
        meta.SetPosition(pill, px, py)
        meta.SetSize(pill, sx, sy)
        meta.SetColor(pill, bg_col)
        meta.SetValue(pill, "Filled", true)
        meta.SetValue(pill, "Corner", r)
        meta.SetValue(pill, "ZIndex", z)
        meta.SetVisible(pill, true)
    else
        pill.Position = Vector2.new(px, py)
        pill.Size = Vector2.new(sx, sy)
        pill.Color = bg_col
        pill.Filled = true
        pill.Corner = r
        pill.ZIndex = z
        pill.Visible = true
    end

    return pill
end

function geometry.DrawCaret(pool, center, direction, size, color, zindex)
    local z = zindex or 1
    local cx = round(center.X)
    local cy = round(center.Y)
    local w = round(size * 0.5)
    local h = round(size * 0.3)

    local ax, ay, bx, by, cx_pt, cy_pt
    if direction == "Down" then
        ax = cx - w
        ay = cy - h
        bx = cx + w
        by = cy - h
        cx_pt = cx
        cy_pt = cy + h
    elseif direction == "Up" then
        ax = cx
        ay = cy - h
        bx = cx + w
        by = cy + h
        cx_pt = cx - w
        cy_pt = cy + h
    elseif direction == "Right" then
        ax = cx - h
        ay = cy - w
        bx = cx + h
        by = cy
        cx_pt = cx - h
        cy_pt = cy + w
    elseif direction == "Left" then
        ax = cx - h
        ay = cy
        bx = cx + h
        by = cy - w
        cx_pt = cx + h
        cy_pt = cy + w
    else
        assert(false, "invalid caret direction: " .. tostring(direction) .. "!")
    end

    local meta = get_meta(pool)
    local tri = pool:Get("Triangle")
    if meta then
        meta.SetTriangle(tri, ax, ay, bx, by, cx_pt, cy_pt)
        meta.SetColor(tri, color)
        meta.SetValue(tri, "Filled", true)
        meta.SetValue(tri, "ZIndex", z)
        meta.SetVisible(tri, true)
    else
        tri.PointA = Vector2.new(ax, ay)
        tri.PointB = Vector2.new(bx, by)
        tri.PointC = Vector2.new(cx_pt, cy_pt)
        tri.Color = color
        tri.Filled = true
        tri.ZIndex = z
        tri.Visible = true
    end

    return tri
end

function geometry.DrawCircle(pool, pos, radius, color, filled, zindex)
    local z = zindex or 1
    local cx = round(pos.X)
    local cy = round(pos.Y)
    local rad = math.max(0, round(radius))
    local is_filled = filled ~= false

    local meta = get_meta(pool)
    local circ = pool:Get("Circle")
    if meta then
        meta.SetPosition(circ, cx, cy)
        meta.SetValue(circ, "Radius", rad)
        meta.SetColor(circ, color)
        meta.SetValue(circ, "Filled", is_filled)
        meta.SetValue(circ, "Thickness", 1)
        meta.SetValue(circ, "NumSides", 24)
        meta.SetValue(circ, "ZIndex", z)
        meta.SetVisible(circ, true)
    else
        circ.Position = Vector2.new(cx, cy)
        circ.Radius = rad
        circ.Color = color
        circ.Filled = is_filled
        circ.Thickness = 1
        circ.NumSides = 24
        circ.ZIndex = z
        circ.Visible = true
    end

    return circ
end

function geometry.GetTextWidth(text, size, scale)
    local metrics = Metrics or MetricsModule
    if metrics then
        return metrics.GetTextWidth(text, size, scale)
    end
    return #tostring(text or "") * ((size or 14) * 0.5)
end

return geometry

end)()

-- ============================================================================
-- MODULE: Layout/Theme.lua
-- ============================================================================
ThemeModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Layout/Theme.lua
-- Tokenized design system palette, color converters, and theme registry for BreezeUI.

local theme = {}
theme.__index = theme

local registry = {}
local listeners = {}

local function build_theme(spec)
    local t = {}
    for k, v in pairs(spec) do t[k] = v end
    t["Sidebar.Background"] = t["Sidebar.Background"] or t["Window.Background"]
    t["Background"]         = t["Background"] or t["Window.Background"]
    t["Header"]             = t["Header"] or t["Window.Background"]
    t["Dialog"]             = t["Dialog"] or t["Card.Background"]
    t["Card"]               = t["Card"] or t["Card.Background"]
    t["Border"]             = t["Border"] or t["Window.Border"]
    t["Button"]             = t["Button"] or t["Control.Background"]
    t["Icon"]               = t["Icon"] or t["Text.Secondary"]
    t["Toggle"]             = t["Toggle"] or t["Accent.Green"]
    t["Slider"]             = t["Slider"] or t["Accent.Blue"]
    t["Checkbox"]           = t["Checkbox"] or t["Accent.Blue"]
    t["Primary"]            = t["Primary"] or t["Accent.Blue"]
    t["Accent"]             = t["Accent"] or t["Accent.Blue"]
    t["Text"]               = t["Text"] or t["Text.Title"]
    t["Placeholder"]        = t["Placeholder"] or t["Text.Muted"]
    t["SubText"]            = t["SubText"] or t["Text.Secondary"]
    t["TextSub"]            = t["TextSub"] or t["Text.Secondary"]
    t["Accent.Danger"]      = t["Accent.Danger"] or Color3.fromRGB(239, 68, 68)
    t["Slider.Thumb"]       = t["Slider.Thumb"] or Color3.fromRGB(255, 255, 255)
    t["Toggle.Thumb"]       = t["Toggle.Thumb"] or Color3.fromRGB(255, 255, 255)
    return t
end

-- Canonical WindUI Dark Theme Tokens
local default_tokens = build_theme({
    -- Window Frame
    ["Window.Background"]  = Color3.fromRGB(16, 16, 16),   -- #101010 (WindUI Dark frame)
    ["Window.Border"]      = Color3.fromRGB(36, 36, 42),   -- #24242A (Subtle outline)

    -- Sidebar & Main Content Panel (WindUI Dark: neutral #101010 + soft white alpha blends)
    ["Sidebar.Divider"]    = Color3.fromRGB(30, 30, 32),   -- #1E1E20
    ["PanelBackground"]    = Color3.fromRGB(28, 28, 28),   -- #1C1C1C (5% white over #101010)
    ["ElementBackground"]  = Color3.fromRGB(42, 42, 44),   -- #2A2A2C (WindUI Dark ElementBackground)

    -- Content Card Containers
    ["Card.Background"]    = Color3.fromRGB(24, 24, 27),   -- #18181B
    ["Card.Border"]        = Color3.fromRGB(38, 38, 42),   -- #26262A

    -- Controls & Interactive Elements
    ["Control.Background"] = Color3.fromRGB(48, 48, 52),   -- #303034
    ["Control.Border"]     = Color3.fromRGB(58, 58, 64),   -- #3A3A40
    ["Control.Hover"]      = Color3.fromRGB(54, 54, 60),   -- #36363C
    ["Control.Active"]     = Color3.fromRGB(38, 38, 42),   -- #26262A

    -- Navigation Tabs (WindUI Dark: 7% active / 3% hover white over #101010)
    ["Tab.ActiveBg"]       = Color3.fromRGB(33, 33, 34),   -- #212122
    ["Tab.HoverBg"]        = Color3.fromRGB(23, 23, 24),   -- #171718

    -- Functional Accents
    ["Accent.Blue"]        = Color3.fromRGB(0, 145, 255),  -- #0091FF (WindUI Primary / Sliders)
    ["Accent.Green"]       = Color3.fromRGB(51, 199, 89),  -- #33C759 (WindUI Toggle ON)

    -- macOS Topbar Traffic Lights
    ["Mac.Close"]          = Color3.fromRGB(255, 95, 86),  -- #FF5F56
    ["Mac.Minimize"]       = Color3.fromRGB(255, 189, 46), -- #FFBD2E
    ["Mac.Maximize"]       = Color3.fromRGB(39, 201, 63),  -- #27C93F

    -- Slider Specific
    ["Slider.TrackBg"]     = Color3.fromRGB(54, 54, 62),   -- #36363E (WindUI unfilled track)

    -- Toggle Specific
    ["Toggle.TrackOff"]    = Color3.fromRGB(54, 54, 62),   -- #36363E

    -- Typography & Labels
    ["Text.Title"]         = Color3.fromRGB(255, 255, 255),
    ["Text.Secondary"]     = Color3.fromRGB(161, 161, 170),
    ["Text.Muted"]         = Color3.fromRGB(161, 161, 161),

    -- WindUI Flat Tokens & Direct Aliases
    ["Name"]               = "Dark",
    ["Dialog"]             = Color3.fromRGB(26, 26, 26),   -- #1A1A1A
    ["Button"]             = Color3.fromRGB(82, 82, 91),   -- #52525B
})

-- Built-in Theme Palettes (WindUI 1:1 Colors)
local midnight_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(10, 15, 30),   -- #0a0f1e
    ["Window.Border"]      = Color3.fromRGB(30, 58, 138),  -- #1e3a8a
    ["Sidebar.Divider"]    = Color3.fromRGB(18, 30, 62),
    ["PanelBackground"]    = Color3.fromRGB(16, 22, 42),
    ["ElementBackground"]  = Color3.fromRGB(36, 40, 54),   -- #242836
    ["Card.Background"]    = Color3.fromRGB(12, 30, 66),   -- #0c1e42
    ["Card.Border"]        = Color3.fromRGB(30, 58, 138),
    ["Control.Background"] = Color3.fromRGB(30, 48, 88),
    ["Control.Border"]     = Color3.fromRGB(47, 116, 209),
    ["Control.Hover"]      = Color3.fromRGB(38, 62, 112),
    ["Control.Active"]     = Color3.fromRGB(24, 38, 72),
    ["Tab.ActiveBg"]       = Color3.fromRGB(30, 58, 138),  -- #1e3a8a
    ["Tab.HoverBg"]        = Color3.fromRGB(20, 36, 82),
    ["Accent.Blue"]        = Color3.fromRGB(37, 99, 235),  -- #2563eb
    ["Accent.Green"]       = Color3.fromRGB(51, 199, 89),
    ["Slider.TrackBg"]     = Color3.fromRGB(30, 48, 88),
    ["Toggle.TrackOff"]    = Color3.fromRGB(45, 60, 90),
    ["Text.Title"]         = Color3.fromRGB(219, 234, 254),-- #dbeafe
    ["Text.Secondary"]     = Color3.fromRGB(85, 145, 244), -- #5591f4
    ["Text.Muted"]         = Color3.fromRGB(47, 116, 209), -- #2f74d1
    ["Name"]               = "Midnight",
    ["Header"]             = Color3.fromRGB(12, 30, 66),
    ["Button"]             = Color3.fromRGB(37, 99, 235),
})

local slate_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(15, 23, 42),
    ["Window.Border"]      = Color3.fromRGB(51, 65, 85),
    ["Sidebar.Divider"]    = Color3.fromRGB(30, 41, 59),
    ["PanelBackground"]    = Color3.fromRGB(22, 31, 52),
    ["ElementBackground"]  = Color3.fromRGB(38, 50, 72),
    ["Card.Background"]    = Color3.fromRGB(30, 41, 59),
    ["Card.Border"]        = Color3.fromRGB(51, 65, 85),
    ["Control.Background"] = Color3.fromRGB(51, 65, 85),
    ["Control.Border"]     = Color3.fromRGB(71, 85, 105),
    ["Control.Hover"]      = Color3.fromRGB(60, 75, 95),
    ["Control.Active"]     = Color3.fromRGB(40, 55, 75),
    ["Tab.ActiveBg"]       = Color3.fromRGB(65, 80, 100),
    ["Tab.HoverBg"]        = Color3.fromRGB(25, 35, 50),
    ["Accent.Blue"]        = Color3.fromRGB(20, 184, 166),
    ["Accent.Green"]       = Color3.fromRGB(34, 197, 94),
    ["Slider.TrackBg"]     = Color3.fromRGB(51, 65, 85),
    ["Toggle.TrackOff"]    = Color3.fromRGB(60, 75, 95),
    ["Text.Title"]         = Color3.fromRGB(241, 245, 249),
    ["Text.Secondary"]     = Color3.fromRGB(148, 163, 184),
    ["Text.Muted"]         = Color3.fromRGB(100, 116, 139),
    ["Name"]               = "Slate",
    ["Header"]             = Color3.fromRGB(30, 41, 59),
    ["Button"]             = Color3.fromRGB(20, 184, 166),
})

local amber_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(28, 16, 3),    -- #1c1003
    ["Window.Border"]      = Color3.fromRGB(107, 46, 5),   -- #6b2e05
    ["Sidebar.Divider"]    = Color3.fromRGB(69, 26, 3),
    ["PanelBackground"]    = Color3.fromRGB(40, 22, 8),
    ["ElementBackground"]  = Color3.fromRGB(58, 46, 34),   -- #3A2E22
    ["Card.Background"]    = Color3.fromRGB(69, 26, 3),    -- #451a03
    ["Card.Border"]        = Color3.fromRGB(107, 46, 5),
    ["Control.Background"] = Color3.fromRGB(78, 56, 38),
    ["Control.Border"]     = Color3.fromRGB(146, 64, 14),
    ["Control.Hover"]      = Color3.fromRGB(96, 68, 44),
    ["Control.Active"]     = Color3.fromRGB(62, 42, 26),
    ["Tab.ActiveBg"]       = Color3.fromRGB(180, 83, 9),   -- #b45309
    ["Tab.HoverBg"]        = Color3.fromRGB(74, 42, 16),
    ["Accent.Blue"]        = Color3.fromRGB(217, 119, 6),  -- #d97706
    ["Accent.Green"]       = Color3.fromRGB(245, 158, 11), -- #f59e0b
    ["Slider.TrackBg"]     = Color3.fromRGB(78, 56, 38),
    ["Toggle.TrackOff"]    = Color3.fromRGB(78, 56, 38),
    ["Text.Title"]         = Color3.fromRGB(255, 251, 235),-- #fffbeb
    ["Text.Secondary"]     = Color3.fromRGB(251, 191, 36), -- #fbbf24
    ["Text.Muted"]         = Color3.fromRGB(209, 163, 38), -- #d1a326
    ["Name"]               = "Amber",
    ["Header"]             = Color3.fromRGB(69, 26, 3),
    ["Button"]             = Color3.fromRGB(217, 119, 6),
    ["Icon"]               = Color3.fromRGB(245, 158, 11),
    ["Checkbox"]           = Color3.fromRGB(245, 158, 11),
})

local red_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(28, 6, 6),    -- #1c0606
    ["Window.Border"]      = Color3.fromRGB(153, 27, 27),  -- #991b1b
    ["Sidebar.Divider"]    = Color3.fromRGB(69, 10, 10),
    ["PanelBackground"]    = Color3.fromRGB(38, 14, 14),
    ["ElementBackground"]  = Color3.fromRGB(50, 34, 33),   -- #322221
    ["Card.Background"]    = Color3.fromRGB(69, 10, 10),   -- #450a0a
    ["Card.Border"]        = Color3.fromRGB(153, 27, 27),
    ["Control.Background"] = Color3.fromRGB(68, 28, 28),
    ["Control.Border"]     = Color3.fromRGB(153, 27, 27),
    ["Control.Hover"]      = Color3.fromRGB(88, 34, 34),
    ["Control.Active"]     = Color3.fromRGB(52, 20, 20),
    ["Tab.ActiveBg"]       = Color3.fromRGB(153, 27, 27),  -- #991b1b
    ["Tab.HoverBg"]        = Color3.fromRGB(69, 16, 16),
    ["Accent.Blue"]        = Color3.fromRGB(220, 38, 38),  -- #dc2626
    ["Accent.Green"]       = Color3.fromRGB(51, 199, 89),
    ["Slider.TrackBg"]     = Color3.fromRGB(68, 28, 28),
    ["Toggle.TrackOff"]    = Color3.fromRGB(78, 32, 32),
    ["Text.Title"]         = Color3.fromRGB(254, 242, 242),-- #fef2f2
    ["Text.Secondary"]     = Color3.fromRGB(239, 68, 68),  -- #ef4444
    ["Text.Muted"]         = Color3.fromRGB(217, 83, 83),  -- #d95353
    ["Name"]               = "Red",
    ["Header"]             = Color3.fromRGB(69, 10, 10),
    ["Button"]             = Color3.fromRGB(220, 38, 38),
    ["Accent"]             = Color3.fromRGB(153, 27, 27),
})

local ruby_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(10, 0, 0),
    ["Window.Border"]      = Color3.fromRGB(69, 10, 10),
    ["Sidebar.Divider"]    = Color3.fromRGB(26, 5, 5),
    ["PanelBackground"]    = Color3.fromRGB(20, 5, 5),
    ["ElementBackground"]  = Color3.fromRGB(40, 12, 12),
    ["Card.Background"]    = Color3.fromRGB(26, 5, 5),
    ["Card.Border"]        = Color3.fromRGB(69, 10, 10),
    ["Control.Background"] = Color3.fromRGB(62, 22, 22),
    ["Control.Border"]     = Color3.fromRGB(90, 30, 30),
    ["Control.Hover"]      = Color3.fromRGB(78, 28, 28),
    ["Control.Active"]     = Color3.fromRGB(30, 5, 5),
    ["Tab.ActiveBg"]       = Color3.fromRGB(60, 15, 15),
    ["Tab.HoverBg"]        = Color3.fromRGB(22, 5, 5),
    ["Accent.Blue"]        = Color3.fromRGB(239, 68, 68),
    ["Accent.Green"]       = Color3.fromRGB(34, 197, 94),
    ["Slider.TrackBg"]     = Color3.fromRGB(40, 10, 10),
    ["Toggle.TrackOff"]    = Color3.fromRGB(60, 15, 15),
    ["Text.Title"]         = Color3.fromRGB(254, 242, 242),
    ["Text.Secondary"]     = Color3.fromRGB(220, 120, 120),
    ["Text.Muted"]         = Color3.fromRGB(165, 70, 70),
    ["Name"]               = "Ruby",
    ["Header"]             = Color3.fromRGB(26, 5, 5),
    ["Button"]             = Color3.fromRGB(239, 68, 68),
    ["Icon"]               = Color3.fromRGB(239, 68, 68),
})

local light_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(228, 230, 235),
    ["Window.Border"]      = Color3.fromRGB(190, 194, 204),
    ["Sidebar.Divider"]    = Color3.fromRGB(205, 208, 216),
    ["PanelBackground"]    = Color3.fromRGB(216, 219, 226),
    ["ElementBackground"]  = Color3.fromRGB(240, 242, 246),
    ["Card.Background"]    = Color3.fromRGB(234, 236, 241),
    ["Card.Border"]        = Color3.fromRGB(196, 200, 210),
    ["Control.Background"] = Color3.fromRGB(210, 213, 222),
    ["Control.Border"]     = Color3.fromRGB(184, 188, 200),
    ["Control.Hover"]      = Color3.fromRGB(198, 202, 212),
    ["Control.Active"]     = Color3.fromRGB(186, 190, 202),
    ["Tab.ActiveBg"]       = Color3.fromRGB(206, 209, 218),
    ["Tab.HoverBg"]        = Color3.fromRGB(218, 220, 228),
    ["Accent.Blue"]        = Color3.fromRGB(0, 122, 255),
    ["Accent.Green"]       = Color3.fromRGB(52, 199, 89),
    ["Slider.TrackBg"]     = Color3.fromRGB(188, 192, 204),
    ["Toggle.TrackOff"]    = Color3.fromRGB(180, 185, 198),
    ["Text.Title"]         = Color3.fromRGB(18, 20, 24),
    ["Text.Secondary"]     = Color3.fromRGB(72, 76, 86),
    ["Text.Muted"]         = Color3.fromRGB(108, 112, 124),
    ["Name"]               = "Light",
    ["Button"]             = Color3.fromRGB(30, 32, 38),
})

local emerald_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(1, 20, 17),    -- #011411
    ["Window.Border"]      = Color3.fromRGB(15, 60, 48),
    ["Sidebar.Divider"]    = Color3.fromRGB(10, 40, 32),
    ["PanelBackground"]    = Color3.fromRGB(8, 30, 25),
    ["ElementBackground"]  = Color3.fromRGB(32, 46, 42),   -- #202E2A
    ["Card.Background"]    = Color3.fromRGB(2, 44, 34),    -- #022c22
    ["Card.Border"]        = Color3.fromRGB(15, 70, 55),
    ["Control.Background"] = Color3.fromRGB(46, 68, 60),
    ["Control.Border"]     = Color3.fromRGB(60, 90, 78),
    ["Control.Hover"]      = Color3.fromRGB(54, 80, 70),
    ["Control.Active"]     = Color3.fromRGB(25, 40, 35),
    ["Tab.ActiveBg"]       = Color3.fromRGB(4, 120, 87),   -- #047857
    ["Tab.HoverBg"]        = Color3.fromRGB(10, 50, 40),
    ["Accent.Blue"]        = Color3.fromRGB(16, 185, 129), -- #10b981
    ["Accent.Green"]       = Color3.fromRGB(5, 150, 105),  -- #059669
    ["Slider.TrackBg"]     = Color3.fromRGB(25, 55, 45),
    ["Toggle.TrackOff"]    = Color3.fromRGB(35, 65, 55),
    ["Text.Title"]         = Color3.fromRGB(236, 253, 245),-- #ecfdf5
    ["Text.Secondary"]     = Color3.fromRGB(16, 185, 129),
    ["Text.Muted"]         = Color3.fromRGB(63, 191, 143), -- #3fbf8f
    ["Name"]               = "Emerald",
    ["Header"]             = Color3.fromRGB(2, 44, 34),
    ["Button"]             = Color3.fromRGB(5, 150, 105),
    ["Accent"]             = Color3.fromRGB(4, 120, 87),
})

local plant_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(10, 27, 15),   -- #0a1b0f
    ["Window.Border"]      = Color3.fromRGB(25, 75, 40),
    ["Sidebar.Divider"]    = Color3.fromRGB(18, 50, 28),
    ["PanelBackground"]    = Color3.fromRGB(16, 36, 22),
    ["ElementBackground"]  = Color3.fromRGB(40, 52, 42),   -- #28342A
    ["Card.Background"]    = Color3.fromRGB(5, 46, 22),    -- #052e16
    ["Card.Border"]        = Color3.fromRGB(30, 90, 50),
    ["Control.Background"] = Color3.fromRGB(54, 76, 58),
    ["Control.Border"]     = Color3.fromRGB(70, 98, 74),
    ["Control.Hover"]      = Color3.fromRGB(64, 90, 68),
    ["Control.Active"]     = Color3.fromRGB(32, 45, 35),
    ["Tab.ActiveBg"]       = Color3.fromRGB(22, 101, 52),  -- #166534
    ["Tab.HoverBg"]        = Color3.fromRGB(15, 60, 32),
    ["Accent.Blue"]        = Color3.fromRGB(74, 222, 128), -- #4ade80
    ["Accent.Green"]       = Color3.fromRGB(22, 163, 74),  -- #16a34a
    ["Slider.TrackBg"]     = Color3.fromRGB(30, 65, 40),
    ["Toggle.TrackOff"]    = Color3.fromRGB(40, 75, 50),
    ["Text.Title"]         = Color3.fromRGB(240, 253, 244),-- #f0fdf4
    ["Text.Secondary"]     = Color3.fromRGB(130, 210, 160),
    ["Text.Muted"]         = Color3.fromRGB(79, 191, 122), -- #4fbf7a
    ["Name"]               = "Plant",
    ["Header"]             = Color3.fromRGB(5, 46, 22),
    ["Button"]             = Color3.fromRGB(22, 163, 74),
    ["Icon"]               = Color3.fromRGB(74, 222, 128),
    ["Accent"]             = Color3.fromRGB(22, 101, 52),
})

local rose_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(31, 3, 8),     -- #1f0308
    ["Window.Border"]      = Color3.fromRGB(85, 15, 35),
    ["Sidebar.Divider"]    = Color3.fromRGB(50, 8, 20),
    ["PanelBackground"]    = Color3.fromRGB(40, 10, 18),
    ["ElementBackground"]  = Color3.fromRGB(56, 30, 35),   -- #381E23
    ["Card.Background"]    = Color3.fromRGB(76, 5, 25),    -- #4c0519
    ["Card.Border"]        = Color3.fromRGB(110, 20, 50),
    ["Control.Background"] = Color3.fromRGB(76, 32, 42),
    ["Control.Border"]     = Color3.fromRGB(110, 40, 58),
    ["Control.Hover"]      = Color3.fromRGB(92, 38, 52),
    ["Control.Active"]     = Color3.fromRGB(56, 24, 34),
    ["Tab.ActiveBg"]       = Color3.fromRGB(190, 24, 93),  -- #be185d
    ["Tab.HoverBg"]        = Color3.fromRGB(65, 12, 30),
    ["Accent.Blue"]        = Color3.fromRGB(251, 113, 133),-- #fb7185
    ["Accent.Green"]       = Color3.fromRGB(51, 199, 89),
    ["Slider.TrackBg"]     = Color3.fromRGB(70, 20, 35),
    ["Toggle.TrackOff"]    = Color3.fromRGB(80, 25, 45),
    ["Text.Title"]         = Color3.fromRGB(253, 242, 248),-- #fdf2f8
    ["Text.Secondary"]     = Color3.fromRGB(251, 113, 133),
    ["Text.Muted"]         = Color3.fromRGB(214, 122, 166),-- #d67aa6
    ["Name"]               = "Rose",
    ["Header"]             = Color3.fromRGB(76, 5, 25),
    ["Button"]             = Color3.fromRGB(233, 95, 116), -- #e95f74
    ["Accent"]             = Color3.fromRGB(190, 24, 93),
})

local violet_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(30, 10, 62),   -- #1e0a3e
    ["Window.Border"]      = Color3.fromRGB(70, 35, 120),
    ["Sidebar.Divider"]    = Color3.fromRGB(45, 18, 85),
    ["PanelBackground"]    = Color3.fromRGB(38, 18, 72),
    ["ElementBackground"]  = Color3.fromRGB(52, 38, 80),   -- #342650
    ["Card.Background"]    = Color3.fromRGB(60, 19, 97),   -- #3c1361
    ["Card.Border"]        = Color3.fromRGB(85, 35, 140),
    ["Control.Background"] = Color3.fromRGB(64, 46, 98),
    ["Control.Border"]     = Color3.fromRGB(80, 55, 125),
    ["Control.Hover"]      = Color3.fromRGB(78, 56, 118),
    ["Control.Active"]     = Color3.fromRGB(46, 32, 74),
    ["Tab.ActiveBg"]       = Color3.fromRGB(109, 40, 217), -- #6d28d9
    ["Tab.HoverBg"]        = Color3.fromRGB(50, 20, 95),
    ["Accent.Blue"]        = Color3.fromRGB(139, 92, 246), -- #8b5cf6
    ["Accent.Green"]       = Color3.fromRGB(51, 199, 89),
    ["Slider.TrackBg"]     = Color3.fromRGB(55, 30, 90),
    ["Toggle.TrackOff"]    = Color3.fromRGB(65, 38, 105),
    ["Text.Title"]         = Color3.fromRGB(250, 245, 255),-- #faf5ff
    ["Text.Secondary"]     = Color3.fromRGB(175, 155, 225),
    ["Text.Muted"]         = Color3.fromRGB(143, 126, 224),-- #8f7ee0
    ["Name"]               = "Violet",
    ["Header"]             = Color3.fromRGB(60, 19, 97),
    ["Button"]             = Color3.fromRGB(124, 58, 237), -- #7c3aed
    ["Icon"]               = Color3.fromRGB(139, 92, 246),
    ["Accent"]             = Color3.fromRGB(109, 40, 217),
})

local sky_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(5, 26, 38),    -- #051a26
    ["Window.Border"]      = Color3.fromRGB(10, 77, 102),
    ["Sidebar.Divider"]    = Color3.fromRGB(8, 45, 60),
    ["PanelBackground"]    = Color3.fromRGB(13, 58, 71),   -- #0d3a47
    ["ElementBackground"]  = Color3.fromRGB(23, 46, 59),   -- #172E3B
    ["Card.Background"]    = Color3.fromRGB(10, 77, 102),  -- #0a4d66
    ["Card.Border"]        = Color3.fromRGB(20, 110, 140),
    ["Control.Background"] = Color3.fromRGB(35, 70, 90),
    ["Control.Border"]     = Color3.fromRGB(45, 90, 115),
    ["Control.Hover"]      = Color3.fromRGB(44, 84, 108),
    ["Control.Active"]     = Color3.fromRGB(18, 38, 48),
    ["Tab.ActiveBg"]       = Color3.fromRGB(0, 168, 204),  -- #00a8cc
    ["Tab.HoverBg"]        = Color3.fromRGB(10, 50, 65),
    ["Accent.Blue"]        = Color3.fromRGB(0, 212, 255),  -- #00d4ff
    ["Accent.Green"]       = Color3.fromRGB(0, 217, 217),  -- #00d9d9
    ["Slider.TrackBg"]     = Color3.fromRGB(20, 60, 80),
    ["Toggle.TrackOff"]    = Color3.fromRGB(25, 70, 90),
    ["Text.Title"]         = Color3.fromRGB(230, 247, 255),-- #e6f7ff
    ["Text.Secondary"]     = Color3.fromRGB(102, 179, 204),-- #66b3cc
    ["Text.Muted"]         = Color3.fromRGB(45, 184, 217), -- #2db8d9
    ["Name"]               = "Sky",
    ["Header"]             = Color3.fromRGB(10, 77, 102),
    ["Button"]             = Color3.fromRGB(0, 168, 204),
    ["Icon"]               = Color3.fromRGB(45, 184, 217),
    ["Placeholder"]        = Color3.fromRGB(102, 179, 204),
})

local indigo_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(15, 10, 46),   -- #0f0a2e
    ["Window.Border"]      = Color3.fromRGB(55, 48, 163),  -- #3730a3
    ["Sidebar.Divider"]    = Color3.fromRGB(30, 27, 75),
    ["PanelBackground"]    = Color3.fromRGB(22, 18, 58),
    ["ElementBackground"]  = Color3.fromRGB(40, 37, 67),   -- #282543
    ["Card.Background"]    = Color3.fromRGB(30, 27, 75),   -- #1e1b4b
    ["Card.Border"]        = Color3.fromRGB(67, 56, 140),
    ["Control.Background"] = Color3.fromRGB(49, 46, 95),
    ["Control.Border"]     = Color3.fromRGB(79, 70, 150),
    ["Control.Hover"]      = Color3.fromRGB(60, 56, 115),
    ["Control.Active"]     = Color3.fromRGB(40, 36, 80),
    ["Tab.ActiveBg"]       = Color3.fromRGB(55, 48, 163),  -- #3730a3
    ["Tab.HoverBg"]        = Color3.fromRGB(40, 36, 90),
    ["Accent.Blue"]        = Color3.fromRGB(79, 70, 229),  -- #4f46e5
    ["Accent.Green"]       = Color3.fromRGB(51, 199, 89),
    ["Slider.TrackBg"]     = Color3.fromRGB(49, 46, 95),
    ["Toggle.TrackOff"]    = Color3.fromRGB(55, 52, 105),
    ["Text.Title"]         = Color3.fromRGB(241, 245, 249),-- #f1f5f9
    ["Text.Secondary"]     = Color3.fromRGB(99, 102, 241), -- #6366f1
    ["Text.Muted"]         = Color3.fromRGB(112, 120, 217),-- #7078d9
    ["Name"]               = "Indigo",
    ["Header"]             = Color3.fromRGB(30, 27, 75),
    ["Button"]             = Color3.fromRGB(79, 70, 229),
    ["Accent"]             = Color3.fromRGB(55, 48, 163),
    ["SubText"]            = Color3.fromRGB(165, 180, 252),
    ["TextSub"]            = Color3.fromRGB(165, 180, 252),
})

local crimson_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(12, 4, 4),    -- #0c0404
    ["Window.Border"]      = Color3.fromRGB(127, 29, 29),
    ["Sidebar.Divider"]    = Color3.fromRGB(48, 12, 12),
    ["PanelBackground"]    = Color3.fromRGB(22, 14, 14),
    ["ElementBackground"]  = Color3.fromRGB(37, 31, 31),   -- #251F1F
    ["Card.Background"]    = Color3.fromRGB(69, 10, 10),   -- #450a0a
    ["Card.Border"]        = Color3.fromRGB(153, 27, 27),
    ["Control.Background"] = Color3.fromRGB(58, 28, 28),
    ["Control.Border"]     = Color3.fromRGB(153, 27, 27),
    ["Control.Hover"]      = Color3.fromRGB(78, 34, 34),
    ["Control.Active"]     = Color3.fromRGB(46, 20, 20),
    ["Tab.ActiveBg"]       = Color3.fromRGB(185, 28, 28),  -- #b91c1c
    ["Tab.HoverBg"]        = Color3.fromRGB(60, 20, 20),
    ["Accent.Blue"]        = Color3.fromRGB(220, 38, 38),  -- #dc2626
    ["Accent.Green"]       = Color3.fromRGB(51, 199, 89),
    ["Slider.TrackBg"]     = Color3.fromRGB(64, 24, 24),
    ["Toggle.TrackOff"]    = Color3.fromRGB(72, 28, 28),
    ["Text.Title"]         = Color3.fromRGB(254, 242, 242),-- #fef2f2
    ["Text.Secondary"]     = Color3.fromRGB(220, 160, 160),
    ["Text.Muted"]         = Color3.fromRGB(111, 117, 123),-- #6f757b
    ["Name"]               = "Crimson",
    ["Header"]             = Color3.fromRGB(69, 10, 10),
    ["Button"]             = Color3.fromRGB(153, 27, 27),  -- #991b1b
    ["Icon"]               = Color3.fromRGB(220, 38, 38),
    ["Accent"]             = Color3.fromRGB(185, 28, 28),
})

local monokai_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(25, 22, 34),   -- #191622
    ["Window.Border"]      = Color3.fromRGB(64, 62, 65),
    ["Sidebar.Divider"]    = Color3.fromRGB(40, 38, 48),
    ["PanelBackground"]    = Color3.fromRGB(34, 31, 43),
    ["ElementBackground"]  = Color3.fromRGB(50, 48, 57),   -- #323039
    ["Card.Background"]    = Color3.fromRGB(30, 30, 30),   -- #1e1e1e
    ["Card.Border"]        = Color3.fromRGB(72, 69, 74),
    ["Control.Background"] = Color3.fromRGB(62, 58, 72),
    ["Control.Border"]     = Color3.fromRGB(91, 89, 92),
    ["Control.Hover"]      = Color3.fromRGB(74, 70, 84),
    ["Control.Active"]     = Color3.fromRGB(48, 45, 56),
    ["Tab.ActiveBg"]       = Color3.fromRGB(74, 70, 84),
    ["Tab.HoverBg"]        = Color3.fromRGB(42, 39, 52),
    ["Accent.Blue"]        = Color3.fromRGB(171, 157, 242),-- #ab9df2
    ["Accent.Green"]       = Color3.fromRGB(169, 220, 118),-- #a9dc76
    ["Accent.Danger"]      = Color3.fromRGB(255, 97, 136),
    ["Slider.TrackBg"]     = Color3.fromRGB(68, 65, 76),
    ["Slider.Thumb"]       = Color3.fromRGB(252, 252, 250),
    ["Toggle.TrackOff"]    = Color3.fromRGB(68, 65, 76),
    ["Toggle.Thumb"]       = Color3.fromRGB(252, 252, 250),
    ["Text.Title"]         = Color3.fromRGB(252, 252, 250),-- #fcfcfa
    ["Text.Secondary"]     = Color3.fromRGB(193, 192, 192),
    ["Text.Muted"]         = Color3.fromRGB(175, 175, 175),-- #afafaf
    ["Name"]               = "Monokai Pro",
    ["Header"]             = Color3.fromRGB(30, 30, 30),
    ["Button"]             = Color3.fromRGB(171, 157, 242),
    ["Icon"]               = Color3.fromRGB(169, 220, 118),
    ["Accent"]             = Color3.fromRGB(252, 152, 103),-- #fc9867
})

local cotton_candy_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(26, 11, 46),   -- #1a0b2e
    ["Window.Border"]      = Color3.fromRGB(88, 56, 110),
    ["Sidebar.Divider"]    = Color3.fromRGB(52, 34, 68),
    ["PanelBackground"]    = Color3.fromRGB(36, 20, 56),
    ["ElementBackground"]  = Color3.fromRGB(49, 38, 67),   -- #312643
    ["Card.Background"]    = Color3.fromRGB(45, 27, 61),   -- #2d1b3d
    ["Card.Border"]        = Color3.fromRGB(108, 72, 135),
    ["Control.Background"] = Color3.fromRGB(60, 44, 80),
    ["Control.Border"]     = Color3.fromRGB(125, 86, 156),
    ["Control.Hover"]      = Color3.fromRGB(76, 56, 98),
    ["Control.Active"]     = Color3.fromRGB(48, 36, 66),
    ["Tab.ActiveBg"]       = Color3.fromRGB(236, 72, 153), -- #ec4899
    ["Tab.HoverBg"]        = Color3.fromRGB(58, 40, 76),
    ["Accent.Blue"]        = Color3.fromRGB(217, 70, 239), -- #d946ef
    ["Accent.Green"]       = Color3.fromRGB(6, 182, 212),  -- #06b6d4
    ["Accent.Danger"]      = Color3.fromRGB(244, 63, 94),
    ["Slider.TrackBg"]     = Color3.fromRGB(66, 48, 88),
    ["Toggle.TrackOff"]    = Color3.fromRGB(72, 54, 96),
    ["Text.Title"]         = Color3.fromRGB(253, 242, 248),-- #fdf2f8
    ["Text.Secondary"]     = Color3.fromRGB(6, 182, 212),
    ["Text.Muted"]         = Color3.fromRGB(138, 95, 211), -- #8a5fd3
    ["Name"]               = "Cotton Candy",
    ["Header"]             = Color3.fromRGB(45, 27, 61),
    ["Button"]             = Color3.fromRGB(217, 70, 239),
    ["Toggle"]             = Color3.fromRGB(51, 199, 89),
    ["Accent"]             = Color3.fromRGB(236, 72, 153),
    ["SubText"]            = Color3.fromRGB(245, 208, 254),
    ["TextSub"]            = Color3.fromRGB(245, 208, 254),
})

local mellowsi_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(28, 16, 2),    -- #1C1002 (WindUI Mellowsi PR #52)
    ["Window.Border"]      = Color3.fromRGB(107, 90, 69),  -- #6B5A45
    ["Sidebar.Divider"]    = Color3.fromRGB(52, 42, 30),   -- #342A1E
    ["PanelBackground"]    = Color3.fromRGB(36, 24, 15),   -- #24180F
    ["ElementBackground"]  = Color3.fromRGB(51, 41, 30),   -- #33291E
    ["Card.Background"]    = Color3.fromRGB(41, 28, 19),   -- #291C13
    ["Card.Border"]        = Color3.fromRGB(107, 90, 69),  -- #6B5A45
    ["Control.Background"] = Color3.fromRGB(70, 56, 41),   -- #463829
    ["Control.Border"]     = Color3.fromRGB(107, 90, 69),  -- #6B5A45
    ["Control.Hover"]      = Color3.fromRGB(68, 55, 40),
    ["Control.Active"]     = Color3.fromRGB(41, 28, 19),
    ["Tab.ActiveBg"]       = Color3.fromRGB(71, 57, 41),   -- #473929
    ["Tab.HoverBg"]        = Color3.fromRGB(58, 46, 32),   -- #3A2E20
    ["Accent.Blue"]        = Color3.fromRGB(201, 162, 77), -- #C9A24D
    ["Accent.Green"]       = Color3.fromRGB(169, 135, 63), -- #a9873f
    ["Slider.TrackBg"]     = Color3.fromRGB(62, 50, 36),
    ["Slider.Thumb"]       = Color3.fromRGB(245, 235, 221),
    ["Toggle.TrackOff"]    = Color3.fromRGB(62, 50, 36),
    ["Toggle.Thumb"]       = Color3.fromRGB(245, 235, 221),
    ["Text.Title"]         = Color3.fromRGB(245, 235, 221),-- #F5EBDD
    ["Text.Secondary"]     = Color3.fromRGB(201, 183, 156),-- #C9B79C
    ["Text.Muted"]         = Color3.fromRGB(156, 138, 115),-- #9C8A73
    ["Name"]               = "Mellowsi",
    ["Header"]             = Color3.fromRGB(41, 28, 19),
    ["Button"]             = Color3.fromRGB(52, 42, 30),
})

local rainbow_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(16, 16, 20),
    ["Window.Border"]      = Color3.fromRGB(58, 58, 72),
    ["Sidebar.Divider"]    = Color3.fromRGB(36, 36, 46),
    ["PanelBackground"]    = Color3.fromRGB(24, 24, 30),
    ["ElementBackground"]  = Color3.fromRGB(36, 36, 46),
    ["Card.Background"]    = Color3.fromRGB(28, 28, 36),
    ["Card.Border"]        = Color3.fromRGB(68, 68, 86),
    ["Control.Background"] = Color3.fromRGB(48, 48, 60),
    ["Control.Border"]     = Color3.fromRGB(82, 82, 102),
    ["Control.Hover"]      = Color3.fromRGB(62, 62, 78),
    ["Control.Active"]     = Color3.fromRGB(40, 40, 50),
    ["Tab.ActiveBg"]       = Color3.fromRGB(139, 92, 246),
    ["Tab.HoverBg"]        = Color3.fromRGB(40, 40, 52),
    ["Accent.Blue"]        = Color3.fromRGB(0, 128, 255),
    ["Accent.Green"]       = Color3.fromRGB(0, 255, 65),
    ["Accent.Danger"]      = Color3.fromRGB(244, 63, 94),
    ["Slider.TrackBg"]     = Color3.fromRGB(56, 56, 70),
    ["Toggle.TrackOff"]    = Color3.fromRGB(60, 60, 74),
    ["Text.Title"]         = Color3.fromRGB(255, 255, 255),
    ["Text.Secondary"]     = Color3.fromRGB(186, 190, 210),
    ["Text.Muted"]         = Color3.fromRGB(0, 255, 128),   -- #00ff80
    ["Name"]               = "Rainbow",
    ["Header"]             = Color3.fromRGB(28, 28, 36),
    ["Button"]             = Color3.fromRGB(0, 128, 255),
    ["Icon"]               = Color3.fromRGB(255, 255, 255),
    ["Accent"]             = Color3.fromRGB(0, 255, 65),
})

-- Register default palettes
registry["Dark"] = default_tokens
registry["Midnight"] = midnight_tokens
registry["Slate"] = slate_tokens
registry["Amber"] = amber_tokens
registry["Ruby"] = ruby_tokens
registry["Red"] = red_tokens
registry["Light"] = light_tokens
registry["Emerald"] = emerald_tokens
registry["Plant"] = plant_tokens
registry["Rose"] = rose_tokens
registry["Violet"] = violet_tokens
registry["Sky"] = sky_tokens
registry["Indigo"] = indigo_tokens
registry["Crimson"] = crimson_tokens
registry["MonokaiPro"] = monokai_tokens
registry["Monokai Pro"] = monokai_tokens
registry["CottonCandy"] = cotton_candy_tokens
registry["Cotton Candy"] = cotton_candy_tokens
registry["Mellowsi"] = mellowsi_tokens
registry["Rainbow"] = rainbow_tokens

theme.DefaultPalette = default_tokens
theme.CurrentPalette = default_tokens
theme.CurrentName = "Dark"

-- Color Helpers
function theme.RGB(r, g, b)
    return Color3.fromRGB(
        math.clamp(math.floor((r or 0) + 0.5), 0, 255),
        math.clamp(math.floor((g or 0) + 0.5), 0, 255),
        math.clamp(math.floor((b or 0) + 0.5), 0, 255)
    )
end

function theme.FromHex(hex)
    local str = tostring(hex or ""):gsub("#", "")
    if #str == 3 then
        local r = tonumber(str:sub(1, 1):rep(2), 16) or 255
        local g = tonumber(str:sub(2, 2):rep(2), 16) or 255
        local b = tonumber(str:sub(3, 3):rep(2), 16) or 255
        return Color3.fromRGB(r, g, b)
    elseif #str == 6 then
        local r = tonumber(str:sub(1, 2), 16) or 255
        local g = tonumber(str:sub(3, 4), 16) or 255
        local b = tonumber(str:sub(5, 6), 16) or 255
        return Color3.fromRGB(r, g, b)
    end
    assert(false, "Invalid hex color format: " .. tostring(hex) .. "!")
end

function theme.ToHex(col)
    local r = math.clamp(math.floor(col.R * 255 + 0.5), 0, 255)
    local g = math.clamp(math.floor(col.G * 255 + 0.5), 0, 255)
    local b = math.clamp(math.floor(col.B * 255 + 0.5), 0, 255)
    return string.format("#%02x%02x%02x", r, g, b)
end

function theme.Lerp(a, b, t)
    local alpha = math.clamp(t or 0, 0, 1)
    return Color3.new(
        a.R + (b.R - a.R) * alpha,
        a.G + (b.G - a.G) * alpha,
        a.B + (b.B - a.B) * alpha
    )
end

-- Token Resolution with Fail-Fast Assertion
function theme.Get(tokenPath, fallback)
    local cur = theme.CurrentPalette
    local val = cur[tokenPath]
    if val ~= nil then return val end

    -- Nested notation support (e.g. "Window.Background")
    if type(tokenPath) == "string" and tokenPath:find("%.") then
        local parts = tokenPath:split(".")
        local node = cur
        for i = 1, #parts do
            if type(node) ~= "table" then
                node = nil
                break
            end
            node = node[parts[i]]
        end
        if node ~= nil then return node end
    end

    -- Fallback to default Dark palette if current palette omitted token
    if cur ~= theme.DefaultPalette then
        local defVal = theme.DefaultPalette[tokenPath]
        if defVal ~= nil then return defVal end
        if type(tokenPath) == "string" and tokenPath:find("%.") then
            local parts = tokenPath:split(".")
            local node = theme.DefaultPalette
            for i = 1, #parts do
                if type(node) ~= "table" then
                    node = nil
                    break
                end
                node = node[parts[i]]
            end
            if node ~= nil then return node end
        end
    end

    if fallback ~= nil then return fallback end
    assert(false, "Unknown theme token: " .. tostring(tokenPath) .. "!")
end

-- Theme Registry & Switching
function theme.Register(name, palette)
    assert(type(name) == "string", "Theme name must be a string!")
    assert(type(palette) == "table", "Theme palette must be a table!")
    registry[name] = palette
    return palette
end

function theme.SetCurrent(nameOrPalette)
    local target
    local name = "Custom"
    if type(nameOrPalette) == "string" then
        target = registry[nameOrPalette]
        assert(target ~= nil, "Theme not registered: " .. tostring(nameOrPalette) .. "!")
        name = nameOrPalette
    elseif type(nameOrPalette) == "table" then
        target = nameOrPalette
        name = nameOrPalette.Name or "Custom"
    else
        assert(false, "Invalid theme argument!")
    end

    theme.CurrentPalette = target
    theme.CurrentName = name

    for callback in pairs(listeners) do
        pcall(callback, target)
    end
    return target
end

function theme.GetCurrent()
    return theme.CurrentPalette
end

function theme.GetTheme(name)
    return registry[name] or theme.DefaultPalette
end

function theme.Subscribe(callback)
    assert(type(callback) == "function", "Callback must be a function!")
    listeners[callback] = true
    return function()
        listeners[callback] = nil
    end
end

-- Metatable delegation for direct index access (e.g. theme.Card, theme.Border)
setmetatable(theme, {
    __index = function(_, k)
        local val = theme.CurrentPalette[k]
        if val ~= nil then return val end
        return theme.DefaultPalette[k]
    end
})

return theme

end)()

-- ============================================================================
-- MODULE: Engine/Clamping.lua
-- ============================================================================
ClampingModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Engine/Clamping.lua
-- Obsidian-style viewport boundary clamping with Roblox topbar inset protection and magnetic snapping.

local Clamping = {
    DefaultSnapThreshold = 16,
    DefaultTopInset = 36,
}

function Clamping.GetViewportSize(customViewport)
    if customViewport and customViewport.X and customViewport.X > 0 and customViewport.Y and customViewport.Y > 0 then
        return customViewport
    end

    local cam = workspace and workspace.CurrentCamera
    if cam and cam.ViewportSize and cam.ViewportSize.X > 0 and cam.ViewportSize.Y > 0 then
        return cam.ViewportSize
    end
    return Vector2.new(800, 600)
end

function Clamping.ClampAndSnap(pos, size, customViewport, customInsetTop)
    local vp = Clamping.GetViewportSize(customViewport)
    local topInset = customInsetTop or Clamping.DefaultTopInset
    local snap = Clamping.DefaultSnapThreshold

    local minX = 0
    local maxX = math.max(0, vp.X - size.X)
    local minY = topInset
    local maxY = math.max(minY, vp.Y - size.Y)

    local targetX = pos.X
    local targetY = pos.Y

    -- Magnetic Edge Snapping
    if math.abs(targetX - minX) <= snap then targetX = minX end
    if math.abs(targetX - maxX) <= snap then targetX = maxX end
    if math.abs(targetY - minY) <= snap then targetY = minY end
    if math.abs(targetY - maxY) <= snap then targetY = maxY end

    -- Rigid Boundary Clamping
    local clampedX = math.clamp(targetX, minX, maxX)
    local clampedY = math.clamp(targetY, minY, maxY)

    return Vector2.new(clampedX, clampedY)
end

return Clamping

end)()

-- ============================================================================
-- MODULE: Engine/Drag.lua
-- ============================================================================
DragModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Engine/Drag.lua
-- Obsidian-style window titlebar dragging with interaction isolation and boundary snapping.

local Clamping = ClampingModule

local Drag = {}
Drag.__index = Drag

function Drag.new(window)
    assert(window ~= nil, "Drag.new requires a window instance!")
    local self = setmetatable({
        Window = window,
        CanDraggable = true,
        IsDragging = false,
        DragStart = Vector2.new(0, 0),
        StartPos = Vector2.new(0, 0),
        HeaderHeight = window.HeaderHeight or 44,
    }, Drag)
    return self
end

function Drag:Set(enabled)
    self.CanDraggable = enabled == true
    if not self.CanDraggable and self.IsDragging then
        self:Stop()
    end
end

function Drag:IsOverHeader(mousePos)
    local win = self.Window
    if not win or not win.Visible or win.Destroyed then return false end
    local pos = win.Position
    local size = win.Size
    local hh = self.HeaderHeight

    return mousePos.X >= pos.X + 70 and mousePos.X <= pos.X + size.X - 10
        and mousePos.Y >= pos.Y and mousePos.Y <= pos.Y + hh
end

function Drag:Update(mousePos, isMouseDown)
    local win = self.Window
    if not win or not win.Visible or win.Destroyed or not self.CanDraggable or win.Draggable == false then
        if self.IsDragging then
            self:Stop()
        end
        return false
    end

    if isMouseDown then
        if not self.IsDragging then
            if self:IsOverHeader(mousePos) then
                if win.CanInteract and win:CanInteract("WindowDrag") then
                    if win.ClaimInteraction then
                        win:ClaimInteraction("WindowDrag")
                    end
                    self.IsDragging = true
                    win.IsDragging = true
                    self.DragStart = mousePos
                    self.StartPos = win.Position
                    return true
                end
            end
        else
            local delta = mousePos - self.DragStart
            local targetPos = self.StartPos + delta
            local clamped = Clamping.ClampAndSnap(targetPos, win.Size)
            win:SetPosition(clamped)
            return true
        end
    else
        if self.IsDragging then
            self:Stop()
        end
    end

    return self.IsDragging
end

function Drag:Stop()
    if self.IsDragging then
        self.IsDragging = false
        if self.Window then
            self.Window.IsDragging = false
            if self.Window.ReleaseInteraction then
                self.Window:ReleaseInteraction("WindowDrag")
            end
        end
    end
end

function Drag:Destroy()
    self:Stop()
    self.Window = nil
end

return Drag

end)()

-- ============================================================================
-- MODULE: Engine/Animations.lua
-- ============================================================================
AnimationsModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Engine/Animations.lua
-- Threadless exponential decay animation engine and adaptive FPS sleep throttling.

local Animations = {
    ActiveAnimations = {},
    _targets = {},
    TargetFPS = 20,
    IdleTimer = 0,
    IdleTimeout = 1.0,
    CurrentFocusedWidget = nil,
}

function Animations.RegisterAnimation(id, animConfig)
    animConfig = animConfig or {}
    Animations.ActiveAnimations[id] = {
        Current = animConfig.Current or 0,
        Target = animConfig.Target or 0,
        Lambda = animConfig.Lambda or 15,
        Epsilon = animConfig.Epsilon or 0.005,
        OnUpdate = animConfig.OnUpdate,
        OnComplete = animConfig.OnComplete,
    }
    Animations.TargetFPS = 60
    Animations.IdleTimer = 0
end

function Animations.Tween(id, current, target, lambda, apply)
    Animations.RegisterAnimation(id, {
        Current = current,
        Target = target,
        Lambda = lambda or 20,
        Epsilon = 0.01,
        OnUpdate = apply,
        OnComplete = function() apply(target) end,
    })
end

function Animations.TweenProp(obj, prop, target, lambda)
    if not obj then return end
    local id = tostring(obj) .. ":" .. prop
    if Animations._targets[id] == target then return end
    Animations._targets[id] = target
    Animations.Tween(id, obj[prop] or target, target, lambda or 20, function(v)
        obj[prop] = v
    end)
end

function Animations.NotifyInput()
    Animations.IdleTimer = 0
    Animations.TargetFPS = 60
end

function Animations.GetActiveAnimationCount()
    local n = 0
    for _ in pairs(Animations.ActiveAnimations) do
        n = n + 1
    end
    return n
end

function Animations.Step(rawDt)
    local dt = math.max(0, rawDt or 0)
    local maxDt = 0.1
    if dt > maxDt then dt = maxDt end

    local activeCount = 0
    for id, anim in pairs(Animations.ActiveAnimations) do
        activeCount = activeCount + 1
        local alpha = 1 - math.exp(-anim.Lambda * dt)
        anim.Current = anim.Current + (anim.Target - anim.Current) * alpha
        if math.abs(anim.Target - anim.Current) <= anim.Epsilon then
            anim.Current = anim.Target
            if anim.OnUpdate then anim.OnUpdate(anim.Current) end
            if anim.OnComplete then anim.OnComplete() end
            Animations.ActiveAnimations[id] = nil
        else
            if anim.OnUpdate then anim.OnUpdate(anim.Current) end
        end
    end

    if activeCount > 0 or Animations.CurrentFocusedWidget then
        Animations.TargetFPS = 60
        Animations.IdleTimer = 0
    else
        Animations.IdleTimer = Animations.IdleTimer + dt
        if Animations.IdleTimer >= Animations.IdleTimeout then
            Animations.TargetFPS = 20
        end
    end
    return activeCount, dt
end

function Animations.Reset()
    Animations.ActiveAnimations = {}
    Animations._targets = {}
    Animations.TargetFPS = 20
    Animations.IdleTimer = Animations.IdleTimeout
    Animations.CurrentFocusedWidget = nil
end

return Animations

end)()

-- ============================================================================
-- MODULE: Engine/InputHandler.lua
-- ============================================================================
InputHandlerModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Engine/InputHandler.lua
-- Win32 Virtual-Key keyboard polling, Shift symbol mapping, Backspace hold-repeat, and key-capture engine.
-- Ported cleanly from Obsidian V2's verified input subsystem for Matcha LuaVM.

local InputHandler = {}

local TEXT_CHARS = {}
for k = 48, 57 do TEXT_CHARS[k] = string.char(k) end
for k = 65, 90 do TEXT_CHARS[k] = string.char(k + 32) end
for k = 96, 105 do TEXT_CHARS[k] = tostring(k - 96) end -- Numpad 0-9

local SHIFT_NUMS = {
    ["0"] = ")", ["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$",
    ["5"] = "%", ["6"] = "^", ["7"] = "&", ["8"] = "*", ["9"] = "(",
}

local OEM_KEYS = {
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

    for vk, ch in pairs(TEXT_CHARS) do
        if self:KeyPressed(vk) then
            if shiftHeld then
                return SHIFT_NUMS[ch] or string.upper(ch)
            end
            return ch
        end
    end

    for vk, pair in pairs(OEM_KEYS) do
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

end)()

-- ============================================================================
-- MODULE: Subsystems/Icons.lua
-- ============================================================================
IconsModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Subsystems/Icons.lua
-- Pure white Lucide PNG icon subsystem with memory cache, name normalization, and deduplicated fetch queue.

local Icons = {
    Cache = {},
    InFlight = {},
    DefaultIcon = nil,
    NetworkFetchCount = 0,
    DarkMode = false,
    _subscribers = {},
    RepoBase = "https://raw.githubusercontent.com/WhyMayko/BreezeUI/main/assets/icons/light/",
    DarkRepoBase = "https://raw.githubusercontent.com/WhyMayko/BreezeUI/main/assets/icons/dark/",
    TextureBase = "https://raw.githubusercontent.com/WhyMayko/BreezeUI/main/assets/textures/",
}

local ALIASES = {
    ["home"] = "home-2-bold",
    ["home-2"] = "home-2-bold",
    ["main"] = "home-2-bold",
    ["grid"] = "layout-grid",
    ["folder-2-bold-duotone"] = "folder",
    ["folder-2"] = "folder",
    ["info-square"] = "info-square-bold",
    ["check-square"] = "check-square-bold",
    ["circle-check"] = "circle-check",
    ["cursor-square"] = "cursor-square-bold",
    ["mouse-pointer-click"] = "mouse-pointer",
    ["pointer"] = "mouse-pointer",
    ["password-minimalistic-input"] = "password-minimalistic-input-bold",
    ["input"] = "password-minimalistic-input-bold",
    ["edit"] = "file-text",
    ["square-transfer-horizontal"] = "square-transfer-horizontal-bold",
    ["sliders"] = "sliders-horizontal",
    ["hamburger-menu"] = "hamburger-menu-bold",
    ["dropdown"] = "list",
    ["bird"] = "bot",
    ["shredder"] = "trash-2",
    ["trash"] = "trash-2",
    ["sunminfill"] = "sun-min",
    ["sunmaxfill"] = "sun-max",
    ["moon"] = "moon",
    ["volume"] = "volume-2",
    ["volumemin"] = "volume-1",
    ["volumemax"] = "volume-2",
    ["target"] = "crosshair",
    ["aim"] = "crosshair",
    ["gear"] = "settings",
    ["cog"] = "settings",
    ["user-circle"] = "user",
    ["discord"] = "message-square",
    ["palette"] = "palette",
    ["paint"] = "palette",
}

function Icons.NormalizeName(rawName)
    if not rawName or type(rawName) ~= "string" or rawName == "" then
        return "box"
    end
    local clean = rawName:lower()
    local colon = clean:find(":")
    if colon then
        clean = clean:sub(colon + 1)
    end
    return ALIASES[clean] or clean
end

function Icons.ValidatePNG(data)
    if not data or type(data) ~= "string" or #data < 8 then
        return false, "Invalid data length"
    end
    if data:sub(1, 4) ~= "\x89PNG" and data:sub(2, 4) ~= "PNG" and data:sub(1, 4) ~= "PNG_" then
        return false, "Invalid PNG magic header"
    end
    return true
end

function Icons.Validate(data)
    return Icons.ValidatePNG(data)
end

local fetchQueue = {}
local workerRunning = false

local function process_queue()
    if workerRunning then return end
    workerRunning = true
    while #fetchQueue > 0 do
        local item = table.remove(fetchQueue, 1)
        local name = item.Name
        if not Icons.Cache[name] then
            local url = item.Url or (Icons.RepoBase .. name .. ".png")
            local ok, data = pcall(function()
                if game and game.HttpGet then
                    return game:HttpGet(url)
                end
                return nil
            end)
            if ok and data and Icons.ValidatePNG(data) then
                Icons.Cache[name] = data
            end
        end
        local finalData = Icons.Cache[name]
        local waiting = Icons.InFlight[name]
        Icons.InFlight[name] = nil
        if waiting and finalData then
            for _, cb in ipairs(waiting) do
                pcall(cb, finalData)
            end
        end
        if task and task.wait then
            task.wait()
        end
    end
    workerRunning = false
end

function Icons.SetDarkMode(enabled)
    local nextMode = enabled == true
    if Icons.DarkMode == nextMode then return false end
    Icons.DarkMode = nextMode
    -- Refresh all active icon subscribers for the new theme polarity
    local subs = {}
    for _, sub in ipairs(Icons._subscribers) do
        table.insert(subs, sub)
    end
    for _, sub in ipairs(subs) do
        Icons.Get(sub.Name, sub.Callback)
    end
    return true
end

function Icons.Get(rawName, callback, forceLight)
    if not rawName or rawName == "" then
        if callback then callback(Icons.DefaultIcon) end
        return Icons.DefaultIcon
    end

    local isUrl = (rawName:sub(1, 7) == "http://" or rawName:sub(1, 8) == "https://")
    local name = isUrl and rawName or Icons.NormalizeName(rawName)
    local useDark = (not isUrl) and (not forceLight) and Icons.DarkMode
    local cacheKey = isUrl and rawName or ((useDark and "dark:" or "light:") .. name)

    if callback and not isUrl and not forceLight then
        local found = false
        for _, sub in ipairs(Icons._subscribers) do
            if sub.Callback == callback then
                sub.Name = rawName
                found = true
                break
            end
        end
        if not found then
            table.insert(Icons._subscribers, { Name = rawName, Callback = callback })
        end
    end

    if Icons.Cache[cacheKey] then
        local cached = Icons.Cache[cacheKey]
        if callback then callback(cached) end
        return cached
    end

    if Icons.InFlight[cacheKey] then
        if callback then
            table.insert(Icons.InFlight[cacheKey], callback)
        end
        return nil
    end

    Icons.InFlight[cacheKey] = callback and { callback } or {}
    Icons.NetworkFetchCount = Icons.NetworkFetchCount + 1

    local base = useDark and Icons.DarkRepoBase or Icons.RepoBase
    table.insert(fetchQueue, { Name = cacheKey, Url = isUrl and rawName or (base .. name .. ".png") })
    if task and task.spawn then
        task.spawn(function()
            process_queue()
        end)
    else
        process_queue()
    end
    return nil
end

function Icons.GetTexture(name, callback)
    return Icons.Get(Icons.TextureBase .. tostring(name) .. ".png", callback)
end

function Icons.Preload(names)
    if not names or type(names) ~= "table" then return 0 end
    local count = 0
    for _, name in ipairs(names) do
        Icons.Get(name)
        count = count + 1
    end
    return count
end

function Icons.ClearSubscribers()
    Icons._subscribers = {}
end

function Icons.ClearCache()
    Icons.Cache = {}
    Icons.InFlight = {}
    Icons._subscribers = {}
    Icons.NetworkFetchCount = 0
    fetchQueue = {}
    workerRunning = false
end

function Icons.Clear()
    Icons.ClearCache()
end

return Icons

end)()

-- ============================================================================
-- MODULE: Subsystems/Settings.lua
-- ============================================================================
SettingsModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Subsystems/Settings.lua
-- Native integrated Settings subsystem providing Interface, Behavior, Configuration, and Performance controls.

local Settings = {
    Profiles = {},
    _profiles = {},
    _profilesByFolder = {},
    _lastEnv = nil,
    _uiRoot = "BreezeUI",
    _configFolder = "BreezeUI",
}

local function ensure_folder_tree(path)
    if not (isfolder and makefolder) then return end
    local acc = ""
    for part in tostring(path):gmatch("[^\\/]+") do
        acc = (acc == "") and part or (acc .. "/" .. part)
        if not isfolder(acc) then
            makefolder(acc)
        end
    end
end

function Settings.SetFolder(folder)
    if folder == nil or folder == "" then
        Settings._configFolder = Settings._uiRoot
        Settings._defaultConfig = nil
        return Settings._configFolder
    end
    assert(type(folder) == "string", "Invalid folder name: expected string!")
    assert(not folder:find('[<>:"|?*]'), "Invalid folder name: contains illegal filesystem characters!")
    assert(not folder:find("%.%."), "Invalid folder name: '..' is not allowed!")
    local cleaned = folder:gsub("^[/\\]+", ""):gsub("[/\\]+$", ""):gsub("\\", "/")
    assert(cleaned ~= "", "Invalid folder name: cannot be empty!")
    Settings._configFolder = cleaned
    Settings._defaultConfig = nil
    return cleaned
end

function Settings.GetFolder()
    return Settings._configFolder or Settings._uiRoot
end

function Settings._getHttpService()
    local g = game or (_G and _G.game)
    if g and g.GetService then
        local ok, hs = pcall(function() return g:GetService("HttpService") end)
        if ok and hs then return hs end
    end
    local hs = HttpService or (_G and _G.HttpService)
    if hs then return hs end
    assert(false, "HttpService is not available in environment!")
end

function Settings.ValidateProfileName(name)
    if not name or type(name) ~= "string" or name == "" then
        return false, "Invalid profile name: cannot be empty"
    end
    if name:find('[<>:"/\\|?*]') then
        return false, "Invalid profile name: contains illegal filesystem characters"
    end
    if #name > 64 then
        return false, "Invalid profile name: exceeds 64 characters limit"
    end
    return true
end

local function serialize_value(v)
    if (typeof and typeof(v) == "Color3") or (type(v) == "table" and type(v.R) == "number" and type(v.G) == "number" and type(v.B) == "number") then
        return { __color3 = { v.R, v.G, v.B } }
    end
    return v
end

local function deserialize_value(v)
    if type(v) == "table" and type(v.__color3) == "table" and #v.__color3 == 3 and Color3 and Color3.new then
        return Color3.new(v.__color3[1], v.__color3[2], v.__color3[3])
    end
    return v
end

function Settings.Save(arg1, arg2)
    local targetEnv, targetName
    if type(arg1) == "string" then
        targetName = arg1
        targetEnv = (type(arg2) == "table" and arg2) or Settings._lastEnv or (type(_G.Library) == "table" and _G.Library)
    elseif type(arg1) == "table" then
        targetEnv = (arg1._rawOptions and arg1) or (arg1.Env and arg1.Env._rawOptions and arg1.Env) or Settings._lastEnv or (type(_G.Library) == "table" and _G.Library)
        targetName = (type(arg2) == "string" and arg2) or (arg1 ~= targetEnv and type(arg1) == "string" and arg1)
    end
    if not targetName and type(arg2) == "string" then
        targetName = arg2
    end

    local ok, err = Settings.ValidateProfileName(targetName)
    assert(ok, err or "Invalid profile name!")

    local dump = { Options = {}, Toggles = {} }
    if targetEnv and targetEnv._rawOptions then
        for k, opt in pairs(targetEnv._rawOptions) do
            if type(k) ~= "string" or k:sub(1, 8) ~= "Settings" then
                dump.Options[k] = serialize_value(opt.Value)
            end
        end
    end
    if targetEnv and targetEnv._rawToggles then
        for k, tog in pairs(targetEnv._rawToggles) do
            if type(k) ~= "string" or k:sub(1, 8) ~= "Settings" then
                dump.Toggles[k] = tog.Value
            end
        end
    end

    local hs = Settings._getHttpService()
    local json = hs:JSONEncode(dump)
    local folder = Settings.GetFolder()
    Settings._profilesByFolder[folder] = Settings._profilesByFolder[folder] or {}
    Settings._profilesByFolder[folder][targetName] = json
    Settings.Profiles[targetName] = json
    Settings._profiles[targetName] = json
    if targetEnv and targetEnv._profiles then
        targetEnv._profiles[targetName] = json
    end

    -- Write to disk if writefile available (uses isolated project Folder)
    pcall(function()
        if writefile then
            ensure_folder_tree(folder .. "/Configs")
            writefile(folder .. "/Configs/" .. targetName .. ".json", json)
        end
    end)

    return true
end

function Settings.Load(arg1, arg2)
    local targetEnv, targetName
    if type(arg1) == "string" then
        targetName = arg1
        targetEnv = (type(arg2) == "table" and arg2) or Settings._lastEnv or (type(_G.Library) == "table" and _G.Library)
    elseif type(arg1) == "table" then
        targetEnv = (arg1._rawOptions and arg1) or (arg1.Env and arg1.Env._rawOptions and arg1.Env) or Settings._lastEnv or (type(_G.Library) == "table" and _G.Library)
        targetName = (type(arg2) == "string" and arg2) or (arg1 ~= targetEnv and type(arg1) == "string" and arg1)
    end
    if not targetName and type(arg2) == "string" then
        targetName = arg2
    end

    local ok, err = Settings.ValidateProfileName(targetName)
    assert(ok, err or "Invalid profile name!")

    local folder = Settings.GetFolder()
    local folderProfiles = Settings._profilesByFolder[folder]
    local json = (folderProfiles and folderProfiles[targetName])
        or (folder == Settings._uiRoot and (Settings.Profiles[targetName] or (targetEnv and targetEnv._profiles and targetEnv._profiles[targetName])))
    if not json then
        pcall(function()
            if readfile and (not isfile or isfile(folder .. "/Configs/" .. targetName .. ".json")) then
                json = readfile(folder .. "/Configs/" .. targetName .. ".json")
            end
        end)
    end

    if not json then
        return false, "Profile not found: " .. tostring(targetName)
    end

    local hs = Settings._getHttpService()
    local decoded = hs:JSONDecode(json)
    if targetEnv then
        if decoded.Options and targetEnv._rawOptions then
            for k, v in pairs(decoded.Options) do
                if targetEnv._rawOptions[k] then targetEnv._rawOptions[k]:Set(deserialize_value(v)) end
            end
        end
        if decoded.Toggles and targetEnv._rawToggles then
            for k, v in pairs(decoded.Toggles) do
                if targetEnv._rawToggles[k] then targetEnv._rawToggles[k]:Set(v) end
            end
        end
    end
    return true
end

function Settings.Delete(arg1, arg2)
    local targetEnv, targetName
    if type(arg1) == "string" then
        targetName = arg1
        targetEnv = (type(arg2) == "table" and arg2) or Settings._lastEnv or (type(_G.Library) == "table" and _G.Library)
    elseif type(arg1) == "table" then
        targetEnv = (arg1._rawOptions and arg1) or (arg1.Env and arg1.Env._rawOptions and arg1.Env) or Settings._lastEnv or (type(_G.Library) == "table" and _G.Library)
        targetName = (type(arg2) == "string" and arg2)
    end
    local ok, err = Settings.ValidateProfileName(targetName)
    assert(ok, err or "Invalid profile name!")

    local folder = Settings.GetFolder()
    if Settings._profilesByFolder[folder] then
        Settings._profilesByFolder[folder][targetName] = nil
    end
    if folder == Settings._uiRoot then
        Settings.Profiles[targetName] = nil
        Settings._profiles[targetName] = nil
        if targetEnv and targetEnv._profiles then
            targetEnv._profiles[targetName] = nil
        end
    end
    if Settings.GetDefault() == targetName then
        Settings.ClearDefault()
    end
    pcall(function()
        local p = folder .. "/Configs/" .. targetName .. ".json"
        if delfile and isfile and isfile(p) then
            delfile(p)
        end
    end)
    return true
end

function Settings.Reset(arg1)
    local targetEnv = (type(arg1) == "table" and ((arg1._rawOptions and arg1) or (arg1.Env and arg1.Env._rawOptions and arg1.Env)))
        or Settings._lastEnv
        or (type(_G.Library) == "table" and _G.Library)

    if not targetEnv then return end
    if targetEnv._initialDefaults and targetEnv._initialDefaults.Options and targetEnv._rawOptions then
        for k, def in pairs(targetEnv._initialDefaults.Options) do
            if (type(k) ~= "string" or k:sub(1, 8) ~= "Settings") and targetEnv._rawOptions[k] then
                targetEnv._rawOptions[k]:Set(def)
            end
        end
    end
    if targetEnv._initialDefaults and targetEnv._initialDefaults.Toggles and targetEnv._rawToggles then
        for k, def in pairs(targetEnv._initialDefaults.Toggles) do
            if (type(k) ~= "string" or k:sub(1, 8) ~= "Settings") and targetEnv._rawToggles[k] then
                targetEnv._rawToggles[k]:Set(def)
            end
        end
    end
end

function Settings.ListConfigs()
    local seen = {}
    local out = {}
    local folder = Settings.GetFolder()
    local folderProfiles = Settings._profilesByFolder[folder] or (folder == Settings._uiRoot and Settings.Profiles) or {}
    for name in pairs(folderProfiles) do
        if type(name) == "string" and name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(out, name)
        end
    end
    pcall(function()
        local cfgDir = folder .. "/Configs"
        if listfiles and (not isfolder or isfolder(cfgDir)) then
            for _, path in ipairs(listfiles(cfgDir)) do
                local name = tostring(path):match("([^\\/]+)%.json$")
                if name and name ~= "" and not seen[name] then
                    seen[name] = true
                    table.insert(out, name)
                end
            end
        end
    end)
    table.sort(out)
    return out
end

function Settings.SetDefault(name)
    local ok, err = Settings.ValidateProfileName(name)
    assert(ok, err or "Invalid profile name!")
    local folder = Settings.GetFolder()
    Settings._defaultConfig = name
    pcall(function()
        if writefile then
            ensure_folder_tree(folder)
            writefile(folder .. "/default_config.txt", name)
        end
    end)
    return true
end

function Settings.GetDefault()
    if Settings._defaultConfig and Settings._defaultConfig ~= "" then
        return Settings._defaultConfig
    end
    local folder = Settings.GetFolder()
    local saved = nil
    pcall(function()
        local p = folder .. "/default_config.txt"
        if readfile and (not isfile or isfile(p)) then
            saved = readfile(p)
        end
    end)
    if type(saved) == "string" and saved ~= "" then
        Settings._defaultConfig = saved
        return saved
    end
    return nil
end

function Settings.ClearDefault()
    Settings._defaultConfig = nil
    local folder = Settings.GetFolder()
    local p = folder .. "/default_config.txt"
    pcall(function()
        if delfile and isfile and isfile(p) then
            delfile(p)
        elseif writefile then
            ensure_folder_tree(folder)
            writefile(p, "")
        end
    end)
    return true
end

function Settings.SaveUI(win)
    if not win or not win.Env then return false end
    local env = win.Env
    local rawOpt = env._rawOptions or {}
    local rawTog = env._rawToggles or {}
    local minKey = rawOpt.SettingsMinimizeKey and rawOpt.SettingsMinimizeKey.Key or false
    local uiData = {
        Theme = (rawOpt.SettingsTheme and rawOpt.SettingsTheme.Value) or win.Theme or "Dark",
        MinimizeKey = minKey,
        InputBlock = (rawTog.SettingsInputBlock and rawTog.SettingsInputBlock.Value) == true,
        KeybindList = (rawTog.SettingsKeybindList and rawTog.SettingsKeybindList.Value) == true,
        NotifySide = (rawOpt.SettingsNotifySide and rawOpt.SettingsNotifySide.Value) or "Right",
    }
    local hs = Settings._getHttpService()
    local json = hs:JSONEncode(uiData)
    Settings._uiPrefs = json
    pcall(function()
        if writefile then
            if isfolder and makefolder then
                if not isfolder("BreezeUI") then makefolder("BreezeUI") end
            end
            writefile("BreezeUI/ui_prefs.json", json)
        end
    end)
    return true
end

function Settings.LoadUI(win)
    if not win or not win.Env then return false end
    local json = Settings._uiPrefs
    if not json then
        pcall(function()
            if readfile and (not isfile or isfile("BreezeUI/ui_prefs.json")) then
                json = readfile("BreezeUI/ui_prefs.json")
            end
        end)
    end
    if not json or json == "" then return false end
    local ok, data = pcall(function() return Settings._getHttpService():JSONDecode(json) end)
    if not ok or type(data) ~= "table" then return false end
    local env = win.Env
    local rawOpt = env._rawOptions or {}
    local rawTog = env._rawToggles or {}
    Settings._loadingUI = true
    if data.Theme then
        if rawOpt.SettingsTheme then rawOpt.SettingsTheme:Set(data.Theme) end
        if win.SetTheme then win:SetTheme(data.Theme) end
    end
    if data.MinimizeKey ~= nil then
        local resolvedMin = (data.MinimizeKey ~= false) and data.MinimizeKey or nil
        if rawOpt.SettingsMinimizeKey then rawOpt.SettingsMinimizeKey:Set(resolvedMin) end
        if win.SetToggleKey then
            win.ToggleKeyMinimizes = true
            win:SetToggleKey(resolvedMin)
        end
    end
    if data.InputBlock ~= nil then
        local blk = data.InputBlock == true
        if rawTog.SettingsInputBlock then rawTog.SettingsInputBlock:Set(blk) end
        if win.SetInputBlocking then win:SetInputBlocking(blk) end
    end
    if data.KeybindList ~= nil then
        local kl = data.KeybindList == true
        if rawTog.SettingsKeybindList then rawTog.SettingsKeybindList:Set(kl) end
        if win.SetKeybindMenuVisible then win:SetKeybindMenuVisible(kl) end
    end
    if data.NotifySide then
        if rawOpt.SettingsNotifySide then rawOpt.SettingsNotifySide:Set(data.NotifySide) end
        if env.SetNotifySide then env:SetNotifySide(data.NotifySide) end
    end
    Settings._loadingUI = false
    return true
end

function Settings.BuildTab(win)
    assert(win ~= nil, "Settings.BuildTab requires a Window instance!")
    if win.Folder and win.Folder ~= "" then
        Settings.SetFolder(win.Folder)
    end
    local tab = win:Tab({ Title = "Settings", Icon = "settings" })

    -- ── Interface ──────────────────────────────────────────────────────────────
    local secIface = tab:Section({ Title = "Interface" })

    local themes = (win.Env and win.Env.GetThemes and win.Env:GetThemes())
        or { "Dark", "Light", "Rose", "Plant", "Red", "Indigo", "Sky", "Violet", "Amber", "Emerald", "Midnight", "Crimson", "MonokaiPro", "CottonCandy", "Mellowsi", "Rainbow", "Slate", "Ruby" }
    secIface:AddDropdown("SettingsTheme", {
        Text             = "Theme",
        Values           = themes,
        SearchBarEnabled = true,
        Default          = (win.Theme and win.Theme ~= "" and win.Theme) or "Dark",
        Callback = function(val)
            if win.SetTheme then win:SetTheme(val) end
            if not Settings._loadingUI then Settings.SaveUI(win) end
        end,
    })

    -- ── Behavior ──────────────────────────────────────────────────────────────
    local secBehav = tab:Section({ Title = "Behavior" })

    win.ToggleKeyMinimizes = true
    local minKb = secBehav:AddKeybind("SettingsMinimizeKey", {
        Title     = "Minimize Key",
        Default   = win.ToggleKey or "F1",
        Blacklist = { 1, 2 },
        Callback  = function(key)
            if win.SetToggleKey then
                win.ToggleKeyMinimizes = true
                win:SetToggleKey(key)
            end
            if not Settings._loadingUI then Settings.SaveUI(win) end
        end,
    })
    if win.SetToggleKey and minKb.Key then
        win:SetToggleKey(minKb.Key)
    end
    minKb.HideFromKeybindList = true

    secBehav:AddToggle("SettingsKeybindList", {
        Text     = "Keybind List",
        Default  = false,
        Callback = function(val)
            if win.SetKeybindMenuVisible then win:SetKeybindMenuVisible(val) end
            if not Settings._loadingUI then Settings.SaveUI(win) end
        end,
    })

    secBehav:AddToggle("SettingsInputBlock", {
        Text     = "Block Roblox Input",
        Default  = false,
        Callback = function(val)
            if win.SetInputBlocking then win:SetInputBlocking(val) end
            if not Settings._loadingUI then Settings.SaveUI(win) end
        end,
    })

    secBehav:AddDropdown("SettingsNotifySide", {
        Text    = "Notify Side",
        Values  = { "Right", "Left" },
        Default = "Right",
        Callback = function(val)
            local lib = win.Env
            if lib and lib.SetNotifySide then
                lib:SetNotifySide(val)
            end
            if not Settings._loadingUI then Settings.SaveUI(win) end
        end,
    })

    -- ── Config ────────────────────────────────────────────────────────────────
    local secConfig = tab:Section({ Title = "Config" })

    secConfig:AddInput("SettingsProfileName", {
        Text        = "Config Name",
        Default     = Settings.GetDefault() or "Default",
        Placeholder = "Enter name...",
    })

    local cfgDrop = secConfig:AddDropdown("SettingsConfigList", {
        Text      = "Configs",
        Values    = Settings.ListConfigs(),
        AllowNone = true,
        Default   = Settings.GetDefault(),
        Callback  = function(val)
            local env = win.Env
            local input = env and env._rawOptions and env._rawOptions.SettingsProfileName
            if input and type(val) == "string" and val ~= "" then
                input:Set(val)
            end
        end,
    })

    local function get_selected_config()
        local env = win.Env
        local input = env and env._rawOptions and env._rawOptions.SettingsProfileName
        local name = input and input.Value or ""
        if name == "" and cfgDrop and type(cfgDrop.Value) == "string" then
            name = cfgDrop.Value
        end
        return (name ~= "" and name) or "Default"
    end

    secConfig:AddButton({
        Text = "Save Config",
        Callback = function()
            local env = win.Env
            local name = get_selected_config()
            local ok, err = pcall(Settings.Save, name, env)
            if ok then
                cfgDrop:Refresh(Settings.ListConfigs())
                if env and env.Notify then
                    env:Notify({ Title = "Config", Content = "Saved '" .. name .. "'.", Icon = "check", Duration = 3 })
                end
            elseif env and env.Notify then
                env:Notify({ Title = "Config", Content = "Save failed: " .. tostring(err), Duration = 4 })
            end
        end,
    })

    secConfig:AddButton({
        Text = "Load Config",
        Callback = function()
            local env = win.Env
            local name = get_selected_config()
            local ok, loadedOrErr = pcall(Settings.Load, name, env)
            if ok and loadedOrErr and env and env.Notify then
                env:Notify({ Title = "Config", Content = "Loaded '" .. name .. "'.", Icon = "check", Duration = 3 })
            elseif env and env.Notify then
                env:Notify({ Title = "Config", Content = "Load failed: " .. tostring(loadedOrErr), Duration = 4 })
            end
        end,
    })

    secConfig:AddButton({
        Text = "Set Default",
        Callback = function()
            local env = win.Env
            local name = get_selected_config()
            local ok, err = pcall(Settings.SetDefault, name)
            if ok and env and env.Notify then
                env:Notify({ Title = "Config", Content = "Default set to '" .. name .. "'.", Icon = "check", Duration = 3 })
            elseif not ok and env and env.Notify then
                env:Notify({ Title = "Config", Content = "Set Default failed: " .. tostring(err), Duration = 4 })
            end
        end,
    })

    secConfig:AddButton({
        Text = "Reset Default",
        Callback = function()
            local env = win.Env
            Settings.ClearDefault()
            Settings.Reset(env)
            if env and env.Notify then
                env:Notify({ Title = "Config", Content = "Default cleared and values reset.", Icon = "check", Duration = 3 })
            end
        end,
    })

    secConfig:AddButton({
        Text = "Delete Config",
        Callback = function()
            local env = win.Env
            local name = get_selected_config()
            local ok, err = pcall(Settings.Delete, name, env)
            if ok then
                cfgDrop:Refresh(Settings.ListConfigs())
                if env and env.Notify then
                    env:Notify({ Title = "Config", Content = "Deleted '" .. name .. "'.", Icon = "trash-2", Duration = 3 })
                end
            elseif env and env.Notify then
                env:Notify({ Title = "Config", Content = "Delete failed: " .. tostring(err), Duration = 4 })
            end
        end,
    })

    -- Auto-load saved default config (if set) and UI auto-saved preferences
    local defCfg = Settings.GetDefault()
    if defCfg then
        pcall(Settings.Load, defCfg, win.Env)
    end
    Settings.LoadUI(win)

    return tab
end

return Settings

end)()

-- ============================================================================
-- MODULE: Subsystems/Notify.lua
-- ============================================================================
NotifyModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Subsystems/Notify.lua
-- Stackable, pooled WindUI + Obsidian V2 notification and progress toast subsystem.

local PoolModule = PoolModule
local MetaModule = MetaModule
local ThemeModule = ThemeModule
local IconsModule = IconsModule
local MetricsModule = MetricsModule

local Notify = {
    Active = {},
    Slots = {},
    MaxSlots = 8,
    Pool = nil,
    DefaultSide = "Right",
    DefaultAnchor = "Bottom",
    PrevM1 = false,
}

local function get_theme(key, fallback)
    if ThemeModule and ThemeModule.Get then
        return ThemeModule.Get(key, fallback)
    end
    return fallback
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function get_viewport()
    local cam = workspace and workspace.CurrentCamera
    if cam and cam.ViewportSize and cam.ViewportSize.X > 0 and cam.ViewportSize.Y > 0 then
        return cam.ViewportSize
    end
    return Vector2.new(1920, 1080)
end

local function wrap_lines(text, maxWidth, fontSize, maxLines)
    local out = {}
    local str = tostring(text or "")
    if str == "" then return out end

    local charW = fontSize * 0.54
    local maxChars = math.max(8, math.floor(maxWidth / charW))

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
                    if #word > maxChars then
                        table.insert(out, string.sub(word, 1, maxChars - 3) .. "...")
                        cur = ""
                    else
                        cur = word
                    end
                end
            end
            if cur ~= "" and #out < maxLines then
                table.insert(out, cur)
            end
        end
    end
    return out
end

local function ensure_pool()
    if not Notify.Pool or Notify.Pool.Destroyed then
        Notify.Pool = PoolModule.new(nil, MetaModule)
        Notify.Slots = {}
    end
    return Notify.Pool
end

local function create_slot()
    local pool = ensure_pool()
    local slot = {
        InUse = true,
        Bg = pool:Get("Square"),
        Border = pool:Get("Square"),
        ProgressTrack = pool:Get("Square"),
        ProgressFill = pool:Get("Square"),
        IconImg = pool:Get("Image"),
        CloseImg = pool:Get("Image"),
        TitleText = pool:Get("Text"),
        Lines = {},
        Buttons = {},
    }

    slot.Bg.Filled = true
    slot.Bg.Corner = 12
    slot.Bg.ZIndex = 40
    slot.Bg.Visible = false

    slot.Border.Filled = false
    slot.Border.Thickness = 1
    slot.Border.Corner = 12
    slot.Border.ZIndex = 41
    slot.Border.Visible = false

    slot.ProgressTrack.Filled = true
    slot.ProgressTrack.Corner = 2
    slot.ProgressTrack.ZIndex = 42
    slot.ProgressTrack.Visible = false

    slot.ProgressFill.Filled = true
    slot.ProgressFill.Corner = 2
    slot.ProgressFill.ZIndex = 43
    slot.ProgressFill.Visible = false

    slot.IconImg.ZIndex = 43
    slot.IconImg.Size = Vector2.new(22, 22)
    slot.IconImg.Visible = false

    slot.CloseImg.ZIndex = 43
    slot.CloseImg.Size = Vector2.new(13, 13)
    slot.CloseImg.Visible = false

    slot.TitleText.Size = 14
    slot.TitleText.ZIndex = 43
    slot.TitleText.Visible = false

    for i = 1, 5 do
        local ln = pool:Get("Text")
        ln.Size = 13
        ln.ZIndex = 43
        ln.Visible = false
        slot.Lines[i] = ln
    end

    for i = 1, 3 do
        local btnBg = pool:Get("Square")
        btnBg.Filled = true
        btnBg.Corner = 6
        btnBg.ZIndex = 43
        btnBg.Visible = false
        local btnTxt = pool:Get("Text")
        btnTxt.Size = 12
        btnTxt.ZIndex = 44
        btnTxt.Visible = false
        slot.Buttons[i] = { Bg = btnBg, Text = btnTxt }
    end

    table.insert(Notify.Slots, slot)
    return slot
end

local function hide_slot(slot)
    if not slot then return end
    slot.InUse = false
    slot._lastIconData = nil
    slot._lastCloseData = nil
    slot.Bg.Visible = false
    slot.Border.Visible = false
    slot.ProgressTrack.Visible = false
    slot.ProgressFill.Visible = false
    slot.IconImg.Visible = false
    slot.CloseImg.Visible = false
    slot.TitleText.Visible = false
    for _, ln in ipairs(slot.Lines) do
        ln.Visible = false
    end
    for _, btn in ipairs(slot.Buttons) do
        btn.Bg.Visible = false
        btn.Text.Visible = false
    end
end

local function acquire_slot()
    ensure_pool()
    for _, slot in ipairs(Notify.Slots) do
        if not slot.InUse then
            slot.InUse = true
            return slot
        end
    end
    if #Notify.Slots < Notify.MaxSlots then
        return create_slot()
    end
    return nil
end

local function release_toast(toast, fireDismiss)
    if toast._released then return end
    toast._released = true
    toast.Closed = true
    if toast._slot then
        hide_slot(toast._slot)
        toast._slot = nil
    end
    if fireDismiss and toast._onDismiss then
        local ok, err = pcall(toast._onDismiss)
        if not ok then
            assert(false, "Notify onDismiss error: " .. tostring(err) .. "!")
        end
    end
end

function Notify.Push(cfg, titleArg, durationArg)
    local title, content, icon, duration, canClose, buttons, side, anchor, accent, sticky

    if type(cfg) == "table" then
        title = cfg.Title or cfg.title
        content = cfg.Content or cfg.Desc or cfg.Description or cfg.Message or cfg.description or ""
        icon = cfg.Icon or cfg.icon
        if cfg.Duration == false then
            sticky = true
            duration = nil
        else
            duration = cfg.Duration or cfg.Time or cfg.duration or 5
        end
        canClose = cfg.CanClose ~= false
        buttons = cfg.Buttons
        side = cfg.Side
        anchor = cfg.Anchor
        accent = cfg.Accent
    else
        content = tostring(cfg or "")
        if type(titleArg) == "number" and durationArg == nil then
            duration = titleArg
            title = "Notice"
        else
            title = tostring(titleArg or "Notice")
            if durationArg == false then
                sticky = true
                duration = nil
            else
                duration = durationArg or 5
            end
        end
        canClose = true
    end

    local now = tick()
    local toast = {
        Title = tostring(title or "Notification"),
        Content = tostring(content or ""),
        Icon = icon,
        Duration = duration,
        Sticky = sticky == true,
        CreatedAt = now,
        ExpiresAt = (duration and duration > 0) and (now + duration) or nil,
        CanClose = canClose,
        Buttons = type(buttons) == "table" and buttons or nil,
        Side = side,
        Anchor = anchor,
        Accent = accent,
        Progress = nil,
        DisplayProgress = 0,
        Closed = false,
        Closing = false,
        SlideT = 0,
        CurrentY = nil,
        _iconData = nil,
        _closeData = nil,
        _onClick = nil,
        _onDismiss = nil,
        _slot = acquire_slot(),
        _released = false,
    }

    if icon and IconsModule and IconsModule.Get then
        toast._iconData = IconsModule.Get(icon, function(png)
            toast._iconData = png
        end)
    end
    if canClose and IconsModule and IconsModule.Get then
        toast._closeData = IconsModule.Get("x", function(png)
            toast._closeData = png
        end)
    end

    local function close_fn()
        if not toast.Closing and not toast._released then
            toast.Closing = true
            toast.Closed = true
        end
    end

    toast.Close = function() close_fn() end
    toast.Destroy = function() close_fn() end
    toast.destroy = function() close_fn() end

    toast.SetTitle = function(a, b)
        local txt = (a == toast) and b or a
        toast.Title = tostring(txt or "")
    end
    toast.setTitle = toast.SetTitle

    toast.SetContent = function(a, b)
        local txt = (a == toast) and b or a
        toast.Content = tostring(txt or "")
    end
    toast.SetMessage = toast.SetContent
    toast.setMessage = toast.SetContent
    toast.setContent = toast.SetContent

    toast.SetProgress = function(a, b)
        local val = (a == toast) and b or a
        toast.Progress = clamp(tonumber(val) or 0, 0, 1)
    end
    toast.setProgress = toast.SetProgress

    toast.OnClick = function(a, b)
        local cb = (a == toast) and b or a
        toast._onClick = cb
        return toast
    end
    toast.onClick = toast.OnClick

    toast.OnDismiss = function(a, b)
        local cb = (a == toast) and b or a
        toast._onDismiss = cb
        return toast
    end
    toast.onDismiss = toast.OnDismiss

    -- Evict oldest if slot pool saturated
    if not toast._slot and #Notify.Active > 0 then
        local oldest = table.remove(Notify.Active, 1)
        release_toast(oldest, false)
        toast._slot = acquire_slot()
    end

    table.insert(Notify.Active, toast)
    return toast
end

function Notify.Progress(title, message, duration)
    local toast = Notify.Push({
        Title = title or "Progress",
        Content = message or "",
        Duration = duration == false and false or (duration or 5),
        CanClose = true,
    })
    toast.Progress = 0
    return toast
end

function Notify.Update(dt, window, mousePos, m1ClickedArg)
    if #Notify.Active == 0 then return false end

    local delta = clamp(dt or 0.016, 0.001, 0.1)
    local now = tick()
    local vp = get_viewport()

    local mx, my = -9999, -9999
    if mousePos then
        mx, my = mousePos.X, mousePos.Y
    elseif type(getmouseposition) == "function" then
        local p = getmouseposition()
        if p then mx, my = p.X, p.Y end
    end

    local m1Clicked = m1ClickedArg
    if m1Clicked == nil then
        local pressed = (type(ismouse1pressed) == "function") and (ismouse1pressed() == true)
        m1Clicked = pressed and not Notify.PrevM1
        Notify.PrevM1 = pressed
    end

    local side = (window and window.NotifySide) or Notify.DefaultSide or "Right"
    local anchor = (window and window.NotifyAnchor) or Notify.DefaultAnchor or "Bottom"
    local cardBg = get_theme("Card.Background", Color3.fromRGB(24, 24, 29))
    local borderCol = get_theme("Window.Border", Color3.fromRGB(46, 46, 54))
    local titleCol = get_theme("Text.Title", Color3.fromRGB(255, 255, 255))
    local descCol = get_theme("Text.Secondary", Color3.fromRGB(165, 165, 175))
    local trackCol = get_theme("Slider.TrackBg", get_theme("Control.Background", Color3.fromRGB(48, 48, 56)))
    local accentCol = (window and window.Accent) or get_theme("Accent.Blue", get_theme("Accent", Color3.fromRGB(59, 130, 246)))
    local btnCol = get_theme("Control.Background", get_theme("Button", Color3.fromRGB(48, 48, 54)))
    local btnHoverCol = get_theme("Control.Hover", Color3.fromRGB(60, 60, 68))

    local cardW = 296
    local padX = 14
    local padY = 12
    local gapY = 10
    local marginX = 20
    local marginY = 22
    local stackOffset = 0
    local consumedClick = false
    local smooth = 1 - math.exp(-14 * delta)

    -- Iterate newest -> oldest so newest sits closest to corner edge
    for i = #Notify.Active, 1, -1 do
        local toast = Notify.Active[i]

        if not toast.Closing and toast.ExpiresAt and now >= toast.ExpiresAt then
            toast.Closing = true
        end

        if toast.Closing then
            toast.SlideT = toast.SlideT + (0 - toast.SlideT) * (1 - math.exp(-16 * delta))
            if toast.SlideT <= 0.02 then
                table.remove(Notify.Active, i)
                release_toast(toast, true)
                continue
            end
        else
            toast.SlideT = toast.SlideT + (1 - toast.SlideT) * smooth
        end

        local slot = toast._slot
        if not slot then
            slot = acquire_slot()
            toast._slot = slot
        end
        if not slot then
            continue
        end

        local toastSide = toast.Side or side
        local toastAnchor = toast.Anchor or anchor
        local hasIcon = toast.Icon ~= nil and toast.Icon ~= ""
        local textLeftOffset = hasIcon and 32 or 0
        local rightPad = toast.CanClose and 22 or 0
        local textW = cardW - padX * 2 - textLeftOffset - rightPad

        local lines = wrap_lines(toast.Content, textW, 13, 5)
        local titleFitted = MetricsModule and MetricsModule.Fit
            and MetricsModule.Fit(toast.Title, textW, 14, 1)
            or toast.Title

        local hasButtons = toast.Buttons and #toast.Buttons > 0
        local btnRowH = hasButtons and 32 or 0
        local contentH = (#lines > 0) and (#lines * 16 + 4) or 0
        local cardH = math.max(58, padY * 2 + 18 + contentH + btnRowH + 8)

        local finalX = toastSide == "Left" and marginX or (vp.X - cardW - marginX)
        local offX = toastSide == "Left" and (-cardW - 24) or (vp.X + 24)
        local x = math.floor(offX + (finalX - offX) * toast.SlideT + 0.5)

        local targetY = toastAnchor == "Top"
            and (marginY + stackOffset)
            or (vp.Y - marginY - stackOffset - cardH)
        if not toast.CurrentY then
            toast.CurrentY = targetY
        else
            toast.CurrentY = toast.CurrentY + (targetY - toast.CurrentY) * smooth
        end
        local y = math.floor(toast.CurrentY + 0.5)
        stackOffset = stackOffset + cardH + gapY

        local alpha = clamp(toast.SlideT, 0, 1)

        -- Card shell
        slot.Bg.Position = Vector2.new(x, y)
        slot.Bg.Size = Vector2.new(cardW, cardH)
        slot.Bg.Color = cardBg
        slot.Bg.Transparency = 0.96 * alpha
        slot.Bg.Visible = true

        slot.Border.Position = Vector2.new(x, y)
        slot.Border.Size = Vector2.new(cardW, cardH)
        slot.Border.Color = borderCol
        slot.Border.Transparency = 0.9 * alpha
        slot.Border.Visible = true

        -- Optional Icon (only assign .Data when changed to avoid Matcha GPU texture flicker)
        if hasIcon and toast._iconData then
            if slot._lastIconData ~= toast._iconData then
                slot.IconImg.Data = toast._iconData
                slot._lastIconData = toast._iconData
            end
            slot.IconImg.Color = titleCol
            slot.IconImg.Position = Vector2.new(x + padX, y + padY)
            slot.IconImg.Transparency = alpha
            slot.IconImg.Visible = true
        else
            slot.IconImg.Visible = false
        end

        -- Close button
        local closeHover = false
        if toast.CanClose then
            local cx = x + cardW - padX - 13
            local cy = y + padY + 1
            closeHover = mx >= cx - 5 and mx <= cx + 18 and my >= cy - 5 and my <= cy + 18
            if toast._closeData then
                if slot._lastCloseData ~= toast._closeData then
                    slot.CloseImg.Data = toast._closeData
                    slot._lastCloseData = toast._closeData
                end
                slot.CloseImg.Color = titleCol
                slot.CloseImg.Position = Vector2.new(cx, cy)
                slot.CloseImg.Transparency = (closeHover and 0.92 or 0.45) * alpha
                slot.CloseImg.Visible = true
            else
                slot.CloseImg.Visible = false
            end
        else
            slot.CloseImg.Visible = false
        end

        -- Title & wrapped lines
        slot.TitleText.Text = titleFitted
        slot.TitleText.Color = titleCol
        slot.TitleText.Position = Vector2.new(x + padX + textLeftOffset, y + padY - 1)
        slot.TitleText.Transparency = alpha
        slot.TitleText.Visible = true

        for li = 1, 5 do
            local ln = slot.Lines[li]
            local str = lines[li]
            if str then
                ln.Text = str
                ln.Color = descCol
                ln.Position = Vector2.new(x + padX + textLeftOffset, y + padY + 18 + (li - 1) * 16)
                ln.Transparency = alpha
                ln.Visible = true
            else
                ln.Visible = false
            end
        end

        -- Optional Buttons row
        local clickedButton = false
        if hasButtons then
            local count = math.min(3, #toast.Buttons)
            local btnTop = y + cardH - 12 - btnRowH + 4
            local availW = cardW - padX * 2
            local bw = math.floor((availW - (count - 1) * 6) / count)
            for bi = 1, 3 do
                local bSlot = slot.Buttons[bi]
                local bCfg = toast.Buttons[bi]
                if bi <= count and bCfg then
                    local bx = x + padX + (bi - 1) * (bw + 6)
                    local bOver = mx >= bx and mx <= bx + bw and my >= btnTop and my <= btnTop + 24
                    bSlot.Bg.Position = Vector2.new(bx, btnTop)
                    bSlot.Bg.Size = Vector2.new(bw, 24)
                    bSlot.Bg.Color = bOver and btnHoverCol or btnCol
                    bSlot.Bg.Transparency = alpha
                    bSlot.Bg.Visible = true

                    local bTitle = tostring(bCfg.Title or bCfg.Text or "Action")
                    bSlot.Text.Text = bTitle
                    bSlot.Text.Color = titleCol
                    bSlot.Text.Center = true
                    bSlot.Text.Position = Vector2.new(bx + math.floor(bw * 0.5), btnTop + 12)
                    bSlot.Text.Transparency = alpha
                    bSlot.Text.Visible = true

                    if bOver and m1Clicked and not consumedClick then
                        consumedClick = true
                        clickedButton = true
                        if bCfg.Callback then
                            pcall(bCfg.Callback)
                        end
                        if bCfg.KeepOpen ~= true then
                            toast:Close()
                        end
                    end
                else
                    bSlot.Bg.Visible = false
                    bSlot.Text.Visible = false
                end
            end
        else
            for bi = 1, 3 do
                slot.Buttons[bi].Bg.Visible = false
                slot.Buttons[bi].Text.Visible = false
            end
        end

        -- Progress / remaining duration bar
        local ratio = nil
        if toast.Progress ~= nil then
            toast.DisplayProgress = toast.DisplayProgress + (toast.Progress - toast.DisplayProgress) * smooth
            ratio = clamp(toast.DisplayProgress, 0, 1)
        elseif toast.ExpiresAt and toast.Duration and toast.Duration > 0 then
            ratio = clamp((toast.ExpiresAt - now) / toast.Duration, 0, 1)
        end

        if ratio ~= nil then
            local barW = cardW - padX * 2
            local barY = y + cardH - 7
            slot.ProgressTrack.Position = Vector2.new(x + padX, barY)
            slot.ProgressTrack.Size = Vector2.new(barW, 3)
            slot.ProgressTrack.Color = trackCol
            slot.ProgressTrack.Transparency = 0.8 * alpha
            slot.ProgressTrack.Visible = true

            local fillW = math.floor(barW * ratio + 0.5)
            if fillW > 0 then
                slot.ProgressFill.Position = Vector2.new(x + padX, barY)
                slot.ProgressFill.Size = Vector2.new(fillW, 3)
                slot.ProgressFill.Color = toast.Accent or accentCol
                slot.ProgressFill.Transparency = alpha
                slot.ProgressFill.Visible = true
            else
                slot.ProgressFill.Visible = false
            end
        else
            slot.ProgressTrack.Visible = false
            slot.ProgressFill.Visible = false
        end

        -- Hit-tests
        if m1Clicked and not consumedClick then
            if closeHover then
                consumedClick = true
                toast:Close()
            elseif not clickedButton then
                local bodyHover = mx >= x and mx <= x + cardW and my >= y and my <= y + cardH
                if bodyHover and toast._onClick then
                    consumedClick = true
                    local ok, err = pcall(toast._onClick)
                    if not ok then
                        assert(false, "Notify onClick error: " .. tostring(err) .. "!")
                    end
                end
            end
        end
    end

    return consumedClick
end

-- Set the preferred screen side for new toasts ("Left" or "Right").
function Notify.SetSide(side)
    assert(side == "Left" or side == "Right", "Notify.SetSide: side must be 'Left' or 'Right'!")
    Notify.DefaultSide = side
end

-- Set the preferred anchor position ("Top" or "Bottom").
function Notify.SetAnchor(anchor)
    assert(anchor == "Top" or anchor == "Bottom", "Notify.SetAnchor: anchor must be 'Top' or 'Bottom'!")
    Notify.DefaultAnchor = anchor
end

function Notify.Destroy()
    for i = #Notify.Active, 1, -1 do
        local toast = Notify.Active[i]
        toast._released = true
        toast._slot = nil
        Notify.Active[i] = nil
    end
    for _, slot in ipairs(Notify.Slots) do
        hide_slot(slot)
    end
    Notify.Slots = {}
    if Notify.Pool and Notify.Pool.Destroy then
        Notify.Pool:Destroy()
        Notify.Pool = nil
    end
end

return Notify

end)()

-- ============================================================================
-- MODULE: Subsystems/Dialog.lua
-- ============================================================================
DialogModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Subsystems/Dialog.lua
-- Reusable modal Dialog and WindUI:Popup subsystem with backdrop blocking and Close confirmation support.

local PoolModule = PoolModule
local MetaModule = MetaModule
local ThemeModule = ThemeModule
local IconsModule = IconsModule
local MetricsModule = MetricsModule

local Dialog = {
    Active = nil,
    Pool = nil,
    Slot = nil,
    PrevM1 = false,
}

local function get_theme(key, fallback)
    if ThemeModule and ThemeModule.Get then
        return ThemeModule.Get(key, fallback)
    end
    return fallback
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function get_viewport()
    local cam = workspace and workspace.CurrentCamera
    if cam and cam.ViewportSize and cam.ViewportSize.X > 0 and cam.ViewportSize.Y > 0 then
        return cam.ViewportSize
    end
    return Vector2.new(1920, 1080)
end

local function wrap_lines(text, maxWidth, fontSize, maxLines)
    local out = {}
    local str = tostring(text or "")
    if str == "" then return out end

    local charW = fontSize * 0.54
    local maxChars = math.max(10, math.floor(maxWidth / charW))

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
                    if #word > maxChars then
                        table.insert(out, string.sub(word, 1, maxChars - 3) .. "...")
                        cur = ""
                    else
                        cur = word
                    end
                end
            end
            if cur ~= "" and #out < maxLines then
                table.insert(out, cur)
            end
        end
    end
    return out
end

local function ensure_slot()
    if not Dialog.Pool or Dialog.Pool.Destroyed then
        Dialog.Pool = PoolModule.new(nil, MetaModule)
        Dialog.Slot = nil
    end
    if Dialog.Slot then
        return Dialog.Slot
    end

    local pool = Dialog.Pool
    local slot = {
        Backdrop = pool:Get("Square"),
        CardBg = pool:Get("Square"),
        CardBorder = pool:Get("Square"),
        IconImg = pool:Get("Image"),
        TitleText = pool:Get("Text"),
        Lines = {},
        Buttons = {},
    }

    slot.Backdrop.Filled = true
    slot.Backdrop.Color = Color3.fromRGB(0, 0, 0)
    slot.Backdrop.ZIndex = 50
    slot.Backdrop.Visible = false

    slot.CardBg.Filled = true
    slot.CardBg.Corner = 16
    slot.CardBg.ZIndex = 51
    slot.CardBg.Visible = false

    slot.CardBorder.Filled = false
    slot.CardBorder.Thickness = 1
    slot.CardBorder.Corner = 16
    slot.CardBorder.ZIndex = 52
    slot.CardBorder.Visible = false

    slot.IconImg.Size = Vector2.new(22, 22)
    slot.IconImg.ZIndex = 53
    slot.IconImg.Visible = false

    slot.TitleText.Size = 16
    slot.TitleText.ZIndex = 53
    slot.TitleText.Visible = false

    for i = 1, 6 do
        local ln = pool:Get("Text")
        ln.Size = 14
        ln.ZIndex = 53
        ln.Visible = false
        slot.Lines[i] = ln
    end

    for i = 1, 4 do
        local bBg = pool:Get("Square")
        bBg.Filled = true
        bBg.Corner = 9
        bBg.ZIndex = 53
        bBg.Visible = false
        local bBorder = pool:Get("Square")
        bBorder.Filled = false
        bBorder.Thickness = 1
        bBorder.Corner = 9
        bBorder.ZIndex = 54
        bBorder.Visible = false
        local bIcon = pool:Get("Image")
        bIcon.Size = Vector2.new(14, 14)
        bIcon.ZIndex = 55
        bIcon.Visible = false
        local bTxt = pool:Get("Text")
        bTxt.Size = 13
        bTxt.ZIndex = 55
        bTxt.Visible = false
        slot.Buttons[i] = { Bg = bBg, Border = bBorder, Icon = bIcon, Text = bTxt }
    end

    Dialog.Slot = slot
    return slot
end

local function hide_slot()
    local slot = Dialog.Slot
    if not slot then return end
    slot.Backdrop.Visible = false
    slot.CardBg.Visible = false
    slot.CardBorder.Visible = false
    slot.IconImg.Visible = false
    slot.TitleText.Visible = false
    for _, ln in ipairs(slot.Lines) do
        ln.Visible = false
    end
    for _, b in ipairs(slot.Buttons) do
        b.Bg.Visible = false
        b.Border.Visible = false
        b.Icon.Visible = false
        b.Text.Visible = false
    end
end

function Dialog.Show(cfg, window, mode)
    assert(type(cfg) == "table", "Dialog/Popup requires configuration table!")

    if Dialog.Active and Dialog.Active.OnCancel then
        pcall(Dialog.Active.OnCancel)
    end

    local inst = {
        Mode = mode or "Dialog",
        Window = window,
        Title = tostring(cfg.Title or "Dialog"),
        Content = cfg.Content or cfg.Desc or cfg.Description or "",
        Icon = cfg.Icon,
        Width = cfg.Width or (mode == "Popup" and 400 or 330),
        Buttons = type(cfg.Buttons) == "table" and cfg.Buttons or {},
        OnCancel = cfg.OnCancel,
        Opened = true,
        Closing = false,
        AnimT = 0,
        _iconData = nil,
        _buttonIcons = {},
    }

    if inst.Icon and IconsModule and IconsModule.Get then
        inst._iconData = IconsModule.Get(inst.Icon, function(png)
            inst._iconData = png
        end)
    end

    for idx, b in ipairs(inst.Buttons) do
        if b.Icon and IconsModule and IconsModule.Get then
            inst._buttonIcons[idx] = IconsModule.Get(b.Icon, function(png)
                inst._buttonIcons[idx] = png
            end)
        end
    end

    function inst:Open()
        inst.Opened = true
        inst.Closing = false
        Dialog.Active = inst
    end

    function inst:Close()
        if not inst.Opened or inst.Closing then return end
        inst.Closing = true
        inst.Opened = false
    end

    function inst:Destroy()
        if Dialog.Active == inst then
            Dialog.Active = nil
            hide_slot()
        end
        inst.Opened = false
        inst.Closing = false
    end

    Dialog.Active = inst
    ensure_slot()
    return inst
end

function Dialog.IsOpen()
    local d = Dialog.Active
    return d ~= nil and (d.Opened or d.Closing)
end

function Dialog.Update(dt, window, mousePos, m1ClickedArg)
    local d = Dialog.Active
    if not d then return false end

    local delta = clamp(dt or 0.016, 0.001, 0.1)
    local smooth = 1 - math.exp(-18 * delta)

    if d.Closing then
        d.AnimT = d.AnimT + (0 - d.AnimT) * smooth
        if d.AnimT <= 0.04 then
            d:Destroy()
            return true
        end
    else
        d.AnimT = d.AnimT + (1 - d.AnimT) * smooth
    end

    local targetWin = d.Window or window
    if targetWin and targetWin.Destroyed then
        d:Destroy()
        return false
    end

    local slot = ensure_slot()
    local vp = get_viewport()

    local mx, my = -9999, -9999
    if mousePos then
        mx, my = mousePos.X, mousePos.Y
    elseif type(getmouseposition) == "function" then
        local p = getmouseposition()
        if p then mx, my = p.X, p.Y end
    end

    local m1Clicked = m1ClickedArg
    if m1Clicked == nil then
        local pressed = (type(ismouse1pressed) == "function") and (ismouse1pressed() == true)
        m1Clicked = pressed and not Dialog.PrevM1
        Dialog.PrevM1 = pressed
    end

    local winVisible = targetWin and targetWin.Visible and not targetWin.Minimized
    local hostX, hostY, hostW, hostH, hostCorner
    if winVisible and d.Mode ~= "Popup" then
        hostX = targetWin.Position.X
        hostY = targetWin.Position.Y
        hostW = targetWin.Size.X
        hostH = targetWin.Size.Y
        hostCorner = targetWin.CornerRadius or 14
    else
        hostX = 0
        hostY = 0
        hostW = vp.X
        hostH = vp.Y
        hostCorner = 0
    end

    local alpha = clamp(d.AnimT, 0, 1)
    local pad = 18
    local cardW = clamp(d.Width, 260, math.max(260, hostW - 32))
    local hasIcon = d.Icon ~= nil and d.Icon ~= ""
    local titleLeft = hasIcon and 32 or 0
    local textW = cardW - pad * 2

    local lines = wrap_lines(d.Content, textW, 14, 6)
    local hasButtons = #d.Buttons > 0
    local contentH = (#lines > 0) and (#lines * 18 + 8) or 0
    local buttonsH = hasButtons and 44 or 0
    local cardH = pad * 2 + 24 + contentH + buttonsH

    local cx = math.floor(hostX + (hostW - cardW) * 0.5 + 0.5)
    local cy = math.floor(hostY + (hostH - cardH) * 0.5 + 0.5)

    local cardBg = get_theme("Window.Background", Color3.fromRGB(20, 20, 24))
    local cardBorder = get_theme("Window.Border", Color3.fromRGB(48, 48, 56))
    local titleCol = get_theme("Text.Title", Color3.fromRGB(255, 255, 255))
    local descCol = get_theme("Text.Secondary", Color3.fromRGB(172, 172, 182))
    local priCol = get_theme("Primary", get_theme("Accent.Blue", Color3.fromRGB(0, 145, 255)))
    local secBtnCol = get_theme("Control.Background", get_theme("Button", Color3.fromRGB(36, 36, 44)))
    local secHoverCol = get_theme("Control.Hover", Color3.fromRGB(48, 48, 58))
    local terBtnCol = get_theme("Card.Background", Color3.fromRGB(24, 24, 29))

    -- Backdrop
    slot.Backdrop.Position = Vector2.new(hostX, hostY)
    slot.Backdrop.Size = Vector2.new(hostW, hostH)
    slot.Backdrop.Corner = hostCorner
    slot.Backdrop.Transparency = 0.62 * alpha
    slot.Backdrop.Visible = true

    -- Dialog card
    slot.CardBg.Position = Vector2.new(cx, cy)
    slot.CardBg.Size = Vector2.new(cardW, cardH)
    slot.CardBg.Color = cardBg
    slot.CardBg.Transparency = alpha
    slot.CardBg.Visible = true

    slot.CardBorder.Position = Vector2.new(cx, cy)
    slot.CardBorder.Size = Vector2.new(cardW, cardH)
    slot.CardBorder.Color = cardBorder
    slot.CardBorder.Transparency = 0.9 * alpha
    slot.CardBorder.Visible = true

    if hasIcon and d._iconData then
        slot.IconImg.Data = d._iconData
        slot.IconImg.Color = titleCol
        slot.IconImg.Position = Vector2.new(cx + pad, cy + pad)
        slot.IconImg.Transparency = alpha
        slot.IconImg.Visible = true
    else
        slot.IconImg.Visible = false
    end

    local titleFitted = MetricsModule and MetricsModule.Fit
        and MetricsModule.Fit(d.Title, textW - titleLeft, 16, 1)
        or d.Title
    slot.TitleText.Text = titleFitted
    slot.TitleText.Color = titleCol
    slot.TitleText.Position = Vector2.new(cx + pad + titleLeft, cy + pad)
    slot.TitleText.Transparency = alpha
    slot.TitleText.Visible = true

    for li = 1, 6 do
        local ln = slot.Lines[li]
        local str = lines[li]
        if str then
            ln.Text = str
            ln.Color = descCol
            ln.Position = Vector2.new(cx + pad, cy + pad + 30 + (li - 1) * 18)
            ln.Transparency = alpha
            ln.Visible = true
        else
            ln.Visible = false
        end
    end

    -- Buttons aligned horizontally at bottom
    if hasButtons then
        local count = math.min(4, #d.Buttons)
        local btnGap = 10
        local btnY = cy + cardH - pad - 34
        local availW = cardW - pad * 2
        local btnW = math.floor((availW - (count - 1) * btnGap) / count)
        local triggered = false

        for bi = 1, 4 do
            local bSlot = slot.Buttons[bi]
            local bCfg = d.Buttons[bi]
            if bi <= count and bCfg then
                local bx = cx + pad + (bi - 1) * (btnW + btnGap)
                local over = mx >= bx and mx <= bx + btnW and my >= btnY and my <= btnY + 34
                local variant = tostring(bCfg.Variant or "Secondary")

                local fillCol = secBtnCol
                local txtCol = titleCol
                local borderVis = false
                if variant == "Primary" then
                    local pr = math.min(255, math.floor((priCol.R or 0) * 255 + (over and 18 or 0)))
                    local pg = math.min(255, math.floor((priCol.G or 0) * 255 + (over and 18 or 0)))
                    local pb = math.min(255, math.floor((priCol.B or 0) * 255 + (over and 18 or 0)))
                    fillCol = Color3.fromRGB(pr, pg, pb)
                    txtCol = Color3.fromRGB(255, 255, 255)
                elseif variant == "Tertiary" then
                    fillCol = over and secBtnCol or terBtnCol
                    txtCol = descCol
                    borderVis = true
                else
                    fillCol = over and secHoverCol or secBtnCol
                    txtCol = titleCol
                    borderVis = true
                end

                bSlot.Bg.Position = Vector2.new(bx, btnY)
                bSlot.Bg.Size = Vector2.new(btnW, 34)
                bSlot.Bg.Color = fillCol
                bSlot.Bg.Transparency = alpha
                bSlot.Bg.Visible = true

                if borderVis then
                    bSlot.Border.Position = Vector2.new(bx, btnY)
                    bSlot.Border.Size = Vector2.new(btnW, 34)
                    bSlot.Border.Color = cardBorder
                    bSlot.Border.Transparency = 0.85 * alpha
                    bSlot.Border.Visible = true
                else
                    bSlot.Border.Visible = false
                end

                local bTitle = tostring(bCfg.Title or bCfg.Text or "OK")
                local hasBIcon = d._buttonIcons[bi] ~= nil
                local txtW = math.floor(#bTitle * 6.8)
                local totalContentW = txtW + (hasBIcon and 20 or 0)
                local startX = bx + math.max(8, math.floor((btnW - totalContentW) * 0.5))

                if hasBIcon then
                    bSlot.Icon.Data = d._buttonIcons[bi]
                    bSlot.Icon.Color = txtCol
                    bSlot.Icon.Position = Vector2.new(startX, btnY + 10)
                    bSlot.Icon.Transparency = alpha
                    bSlot.Icon.Visible = true
                    bSlot.Text.Center = false
                    bSlot.Text.Position = Vector2.new(startX + 18, btnY + 10)
                else
                    bSlot.Icon.Visible = false
                    bSlot.Text.Center = true
                    local bh = (bSlot.Bg.Size and bSlot.Bg.Size.Y) or 34
                    bSlot.Text.Position = Vector2.new(bx + math.floor(btnW * 0.5), btnY + math.floor(bh * 0.5))
                end

                bSlot.Text.Text = bTitle
                bSlot.Text.Color = txtCol
                bSlot.Text.Transparency = alpha
                bSlot.Text.Visible = true

                if over and m1Clicked and not triggered then
                    triggered = true
                    if bCfg.KeepOpen ~= true then
                        d:Close()
                    end
                    if bCfg.Callback then
                        local ok, err = pcall(bCfg.Callback)
                        if not ok then
                            assert(false, "Dialog button callback error: " .. tostring(err) .. "!")
                        end
                    end
                end
            else
                bSlot.Bg.Visible = false
                bSlot.Border.Visible = false
                bSlot.Icon.Visible = false
                bSlot.Text.Visible = false
            end
        end
    else
        for bi = 1, 4 do
            slot.Buttons[bi].Bg.Visible = false
            slot.Buttons[bi].Border.Visible = false
            slot.Buttons[bi].Icon.Visible = false
            slot.Buttons[bi].Text.Visible = false
        end
    end

    -- Modal blocks all underlying window clicks while active
    return true
end

function Dialog.Destroy()
    if Dialog.Active then
        Dialog.Active.Opened = false
        Dialog.Active.Closing = false
        Dialog.Active = nil
    end
    hide_slot()
    Dialog.Slot = nil
    if Dialog.Pool and Dialog.Pool.Destroy then
        Dialog.Pool:Destroy()
        Dialog.Pool = nil
    end
end

return Dialog

end)()

-- ============================================================================
-- MODULE: Subsystems/Overlay.lua
-- ============================================================================
OverlayModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Subsystems/Overlay.lua
-- Floating HUD overlays: WindUI OpenButton pill, Obsidian KeybindMenu, and draggable Watermark.

local PoolModule = PoolModule
local MetaModule = MetaModule
local ThemeModule = ThemeModule
local IconsModule = IconsModule
local MetricsModule = MetricsModule

local Overlay = {
    Pool = nil,
    OpenSlot = nil,
    KeySlot = nil,
    WmSlot = nil,
    PrevM1 = false,
}

local function get_theme(key, fallback)
    if ThemeModule and ThemeModule.Get then
        return ThemeModule.Get(key, fallback)
    end
    return fallback
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function get_viewport()
    local cam = workspace and workspace.CurrentCamera
    if cam and cam.ViewportSize and cam.ViewportSize.X > 0 and cam.ViewportSize.Y > 0 then
        return cam.ViewportSize
    end
    return Vector2.new(1920, 1080)
end

local function ensure_pool()
    if not Overlay.Pool or Overlay.Pool.Destroyed then
        Overlay.Pool = PoolModule.new(nil, MetaModule)
        Overlay.OpenSlot = nil
        Overlay.KeySlot = nil
        Overlay.WmSlot = nil
    end
    return Overlay.Pool
end

local function hide_open_slot()
    local s = Overlay.OpenSlot
    if not s then return end
    s.Bg.Visible = false
    s.Border.Visible = false
    s.DragIcon.Visible = false
    s.Divider.Visible = false
    s.IconImg.Visible = false
    s.TitleText.Visible = false
end

local function ensure_open_slot()
    if Overlay.OpenSlot then return Overlay.OpenSlot end
    local pool = ensure_pool()
    local s = {
        Bg = pool:Get("Square"),
        Border = pool:Get("Square"),
        DragIcon = pool:Get("Image"),
        Divider = pool:Get("Square"),
        IconImg = pool:Get("Image"),
        TitleText = pool:Get("Text"),
    }
    s.Bg.Filled = true
    s.Bg.Corner = 20
    s.Bg.ZIndex = 30
    s.Bg.Visible = false

    s.Border.Filled = false
    s.Border.Thickness = 1.5
    s.Border.Corner = 20
    s.Border.ZIndex = 31
    s.Border.Visible = false

    s.DragIcon.Size = Vector2.new(15, 15)
    s.DragIcon.ZIndex = 32
    s.DragIcon.Visible = false

    s.Divider.Filled = true
    s.Divider.ZIndex = 32
    s.Divider.Visible = false

    s.IconImg.Size = Vector2.new(18, 18)
    s.IconImg.ZIndex = 32
    s.IconImg.Visible = false

    s.TitleText.Size = 14
    s.TitleText.ZIndex = 32
    s.TitleText.Visible = false

    Overlay.OpenSlot = s
    return s
end

local function hide_key_slot()
    local s = Overlay.KeySlot
    if not s then return end
    s.Bg.Visible = false
    s.Border.Visible = false
    s.HeaderText.Visible = false
    s.Divider.Visible = false
    s.EmptyText.Visible = false
    for _, r in ipairs(s.Rows) do
        r.Dot.Visible = false
        r.Name.Visible = false
        r.Key.Visible = false
    end
end

local function ensure_key_slot()
    if Overlay.KeySlot then return Overlay.KeySlot end
    local pool = ensure_pool()
    local s = {
        Bg = pool:Get("Square"),
        Border = pool:Get("Square"),
        HeaderText = pool:Get("Text"),
        Divider = pool:Get("Square"),
        EmptyText = pool:Get("Text"),
        Rows = {},
    }
    s.Bg.Filled = true
    s.Bg.Corner = 10
    s.Bg.ZIndex = 34
    s.Bg.Visible = false

    s.Border.Filled = false
    s.Border.Thickness = 1
    s.Border.Corner = 10
    s.Border.ZIndex = 35
    s.Border.Visible = false

    s.HeaderText.Size = 14
    s.HeaderText.Text = "Keybinds"
    s.HeaderText.ZIndex = 36
    s.HeaderText.Visible = false

    s.Divider.Filled = true
    s.Divider.ZIndex = 36
    s.Divider.Visible = false

    s.EmptyText.Size = 12
    s.EmptyText.Text = "No active keybinds"
    s.EmptyText.ZIndex = 36
    s.EmptyText.Visible = false

    for i = 1, 10 do
        local dot = pool:Get("Square")
        dot.Filled = true
        dot.Corner = 3
        dot.Size = Vector2.new(6, 6)
        dot.ZIndex = 36
        dot.Visible = false
        local nm = pool:Get("Text")
        nm.Size = 13
        nm.ZIndex = 36
        nm.Visible = false
        local ky = pool:Get("Text")
        ky.Size = 12
        ky.ZIndex = 36
        ky.Visible = false
        s.Rows[i] = { Dot = dot, Name = nm, Key = ky }
    end

    Overlay.KeySlot = s
    return s
end

local function hide_wm_slot()
    local s = Overlay.WmSlot
    if not s then return end
    s.Bg.Visible = false
    s.Border.Visible = false
    s.AccentBar.Visible = false
    for _, t in ipairs(s.Tokens) do
        t.Visible = false
    end
end

local function ensure_wm_slot()
    if Overlay.WmSlot then return Overlay.WmSlot end
    local pool = ensure_pool()
    local s = {
        Bg = pool:Get("Square"),
        Border = pool:Get("Square"),
        AccentBar = pool:Get("Square"),
        Tokens = {},
    }
    s.Bg.Filled = true
    s.Bg.Corner = 6
    s.Bg.ZIndex = 37
    s.Bg.Visible = false

    s.Border.Filled = false
    s.Border.Thickness = 1
    s.Border.Corner = 6
    s.Border.ZIndex = 38
    s.Border.Visible = false

    s.AccentBar.Filled = true
    s.AccentBar.Corner = 2
    s.AccentBar.ZIndex = 39
    s.AccentBar.Visible = false

    for i = 1, 8 do
        local t = pool:Get("Text")
        t.Size = 13
        t.ZIndex = 39
        t.Visible = false
        s.Tokens[i] = t
    end

    Overlay.WmSlot = s
    return s
end

local function collect_keybind_rows(window)
    local rows = {}
    if not window or not window.Tabs then return rows end
    for _, tab in ipairs(window.Tabs) do
        local cards = tab.Sections or tab.Cards or {}
        for _, card in ipairs(cards) do
            for _, ctrl in ipairs(card.Controls or {}) do
                if ctrl.KeyPicker and not ctrl.KeyPicker.HideFromKeybindList then
                    local kp = ctrl.KeyPicker
                    table.insert(rows, {
                        Name = tostring(ctrl.Text or ctrl.Title or kp.Text or kp.Id or "Key"),
                        Key = "[" .. tostring(kp.KeyName or "?") .. "]",
                        Mode = kp.Mode or "Toggle",
                        Active = (ctrl.Value == true) or (kp.ActiveState == true),
                    })
                elseif ctrl.Capturing ~= nil and ctrl.KeyName ~= nil and not ctrl.HideFromKeybindList and ctrl.Id ~= "SettingsMinimizeKey" then
                    table.insert(rows, {
                        Name = tostring(ctrl.Text or ctrl.Id or "Key"),
                        Key = "[" .. tostring(ctrl.KeyName or "?") .. "]",
                        Mode = ctrl.Mode or "Toggle",
                        Active = ctrl.ActiveState == true,
                    })
                end
                if #rows >= 10 then return rows end
            end
        end
    end
    return rows
end

local function update_open_button(window, vp, mx, my, m1Pressed, m1Clicked)
    local ob = window.OpenButton
    local shouldShow = (not window.Visible) and ob and ob.Enabled ~= false
    if not shouldShow then
        hide_open_slot()
        return false
    end

    local slot = ensure_open_slot()
    local draggable = ob.Draggable ~= false
    local onlyIcon = ob.OnlyIcon == true
    local titleStr = tostring(ob.Title or window.Title or "Open")
    local iconName = ob.Icon or window.Icon or "wind"

    if ob._dragData == nil and IconsModule and IconsModule.Get then
        ob._dragData = IconsModule.Get("move", function(png) ob._dragData = png end)
    end
    if iconName ~= ob._lastIconName and IconsModule and IconsModule.Get then
        ob._lastIconName = iconName
        ob._iconData = IconsModule.Get(iconName, function(png) ob._iconData = png end)
    end

    local h = 40
    local dragW = draggable and 30 or 0
    local iconW = ob._iconData and 22 or 0
    local textW = onlyIcon and 0 or (MetricsModule and MetricsModule.GetTextWidth
        and math.floor(MetricsModule.GetTextWidth(titleStr, 14, 1) * 1.15 + 0.5)
        or math.floor(#titleStr * 7.6))
    local padX = 14
    local w = math.max(44, dragW + padX + iconW + ((iconW > 0 and textW > 0) and 8 or 0) + textW + padX)

    if not ob.Position then
        ob.Position = Vector2.new(math.floor((vp.X - w) * 0.5), 14)
    end

    local px = clamp(ob.Position.X, 8, math.max(8, vp.X - w - 8))
    local py = clamp(ob.Position.Y, 8, math.max(8, vp.Y - h - 8))

    local consumed = false
    if ob._dragging then
        if m1Pressed then
            px = clamp(mx - ob._dragOffX, 8, math.max(8, vp.X - w - 8))
            py = clamp(my - ob._dragOffY, 8, math.max(8, vp.Y - h - 8))
            ob.Position = Vector2.new(px, py)
        else
            ob._dragging = false
        end
    elseif m1Clicked then
        if draggable and mx >= px and mx <= px + dragW and my >= py and my <= py + h then
            ob._dragging = true
            ob._dragOffX = mx - px
            ob._dragOffY = my - py
            consumed = true
        elseif mx >= px + dragW and mx <= px + w and my >= py and my <= py + h then
            consumed = true
            window:SetVisible(true)
            hide_open_slot()
            return true
        end
    end

    local overBtn = mx >= px + dragW and mx <= px + w and my >= py and my <= py + h
    local bgCol = overBtn and get_theme("Button.Hover", Color3.fromRGB(36, 36, 44))
        or get_theme("Window.Background", Color3.fromRGB(18, 18, 22))
    local borderCol = ob.Color or get_theme("Accent", Color3.fromRGB(80, 175, 255))
    local textCol = get_theme("Text.Title", Color3.fromRGB(255, 255, 255))

    slot.Bg.Position = Vector2.new(px, py)
    slot.Bg.Size = Vector2.new(w, h)
    slot.Bg.Color = bgCol
    slot.Bg.Transparency = 0.92
    slot.Bg.Visible = true

    slot.Border.Position = Vector2.new(px, py)
    slot.Border.Size = Vector2.new(w, h)
    slot.Border.Color = borderCol
    slot.Border.Transparency = 0.88
    slot.Border.Visible = true

    if draggable then
        if ob._dragData then
            slot.DragIcon.Data = ob._dragData
            slot.DragIcon.Color = textCol
            slot.DragIcon.Position = Vector2.new(px + 10, py + 12)
            slot.DragIcon.Transparency = 0.55
            slot.DragIcon.Visible = true
        else
            slot.DragIcon.Visible = false
        end
        slot.Divider.Position = Vector2.new(px + dragW, py + 8)
        slot.Divider.Size = Vector2.new(1, h - 16)
        slot.Divider.Color = get_theme("Window.Border", Color3.fromRGB(52, 52, 60))
        slot.Divider.Transparency = 0.85
        slot.Divider.Visible = true
    else
        slot.DragIcon.Visible = false
        slot.Divider.Visible = false
    end

    local curX = px + dragW + padX
    if ob._iconData then
        slot.IconImg.Data = ob._iconData
        slot.IconImg.Color = textCol
        slot.IconImg.Position = Vector2.new(curX, py + 11)
        slot.IconImg.Transparency = 1
        slot.IconImg.Visible = true
        curX = curX + 24
    else
        slot.IconImg.Visible = false
    end

    if not onlyIcon then
        slot.TitleText.Text = titleStr
        slot.TitleText.Color = textCol
        slot.TitleText.Position = Vector2.new(curX, py + 12)
        slot.TitleText.Visible = true
    else
        slot.TitleText.Visible = false
    end

    return consumed
end

local function update_keybind_menu(window, vp, mx, my, m1Pressed, m1Clicked)
    if not window.ShowKeybindMenu then
        hide_key_slot()
        return false
    end

    local slot = ensure_key_slot()
    local rows = collect_keybind_rows(window)
    local w = window.KeybindMenuWidth or 240
    local headerH = 30
    local rowH = 22
    local h = headerH + 10 + math.max(1, #rows) * rowH + 6

    if window.KeybindMenuX == nil then
        window.KeybindMenuX = 14
        window.KeybindMenuY = math.floor((vp.Y - h) * 0.5)
    end

    local px = clamp(window.KeybindMenuX, 6, math.max(6, vp.X - w - 6))
    local py = clamp(window.KeybindMenuY, 6, math.max(6, vp.Y - h - 6))

    local consumed = false
    if window._kmDragging then
        if m1Pressed then
            px = clamp(mx - window._kmDragOffX, 6, math.max(6, vp.X - w - 6))
            py = clamp(my - window._kmDragOffY, 6, math.max(6, vp.Y - h - 6))
            window.KeybindMenuX, window.KeybindMenuY = px, py
        else
            window._kmDragging = false
        end
    elseif m1Clicked and mx >= px and mx <= px + w and my >= py and my <= py + headerH then
        window._kmDragging = true
        window._kmDragOffX = mx - px
        window._kmDragOffY = my - py
        consumed = true
    end

    local bgCol = get_theme("Window.Background", Color3.fromRGB(18, 18, 22))
    local borderCol = get_theme("Window.Border", Color3.fromRGB(44, 44, 52))
    local titleCol = get_theme("Text.Title", Color3.fromRGB(255, 255, 255))
    local mutedCol = get_theme("Text.Secondary", Color3.fromRGB(160, 160, 170))
    local accentCol = window.Accent or get_theme("Accent", Color3.fromRGB(59, 130, 246))

    slot.Bg.Position = Vector2.new(px, py)
    slot.Bg.Size = Vector2.new(w, h)
    slot.Bg.Color = bgCol
    slot.Bg.Transparency = 0.94
    slot.Bg.Visible = true

    slot.Border.Position = Vector2.new(px, py)
    slot.Border.Size = Vector2.new(w, h)
    slot.Border.Color = borderCol
    slot.Border.Visible = true

    slot.HeaderText.Color = titleCol
    slot.HeaderText.Position = Vector2.new(px + 12, py + 8)
    slot.HeaderText.Visible = true

    slot.Divider.Position = Vector2.new(px + 10, py + headerH)
    slot.Divider.Size = Vector2.new(w - 20, 1)
    slot.Divider.Color = borderCol
    slot.Divider.Visible = true

    if #rows == 0 then
        slot.EmptyText.Color = mutedCol
        slot.EmptyText.Position = Vector2.new(px + 12, py + headerH + 10)
        slot.EmptyText.Visible = true
        for _, r in ipairs(slot.Rows) do
            r.Dot.Visible = false
            r.Name.Visible = false
            r.Key.Visible = false
        end
    else
        slot.EmptyText.Visible = false
        for i = 1, 10 do
            local rSlot = slot.Rows[i]
            local row = rows[i]
            if row then
                local ry = py + headerH + 8 + (i - 1) * rowH
                rSlot.Dot.Position = Vector2.new(px + 12, ry + 5)
                rSlot.Dot.Color = row.Active and accentCol or borderCol
                rSlot.Dot.Visible = true

                rSlot.Name.Text = MetricsModule and MetricsModule.Fit
                    and MetricsModule.Fit(row.Name, w - 82, 13, 1)
                    or row.Name
                rSlot.Name.Color = row.Active and titleCol or mutedCol
                rSlot.Name.Position = Vector2.new(px + 24, ry + 1)
                rSlot.Name.Visible = true

                local kw = math.floor(#row.Key * 6.6)
                rSlot.Key.Text = row.Key
                rSlot.Key.Color = row.Active and accentCol or mutedCol
                rSlot.Key.Position = Vector2.new(px + w - kw - 12, ry + 2)
                rSlot.Key.Visible = true
            else
                rSlot.Dot.Visible = false
                rSlot.Name.Visible = false
                rSlot.Key.Visible = false
            end
        end
    end

    return consumed
end

local function update_watermark(window, vp, mx, my, m1Pressed, m1Clicked)
    local wm = window.Watermark
    if not wm or wm.Visible ~= true or not wm.Text or wm.Text == "" then
        hide_wm_slot()
        return false
    end

    local slot = ensure_wm_slot()
    local pieces = {}
    if wm.Tokens and #wm.Tokens > 1 then
        for i, tok in ipairs(wm.Tokens) do
            table.insert(pieces, { Text = tostring(tok), Accent = (i == 1) })
            if i < #wm.Tokens then
                table.insert(pieces, { Text = " | ", Muted = true })
            end
        end
    else
        table.insert(pieces, { Text = tostring(wm.Text), Accent = false })
    end

    local totalTextW = 0
    for _, p in ipairs(pieces) do
        local pw = math.floor(#p.Text * 7.0)
        p.Width = pw
        totalTextW = totalTextW + pw
    end
    local w = math.max(60, totalTextW + 24)
    local h = 28

    local px = clamp(wm.X or 16, 6, math.max(6, vp.X - w - 6))
    local py = clamp(wm.Y or 16, 6, math.max(6, vp.Y - h - 6))

    local consumed = false
    if wm._dragging then
        if m1Pressed then
            px = clamp(mx - wm._dragOffX, 6, math.max(6, vp.X - w - 6))
            py = clamp(my - wm._dragOffY, 6, math.max(6, vp.Y - h - 6))
            wm.X, wm.Y = px, py
        else
            wm._dragging = false
        end
    elseif m1Clicked and mx >= px and mx <= px + w and my >= py and my <= py + h then
        wm._dragging = true
        wm._dragOffX = mx - px
        wm._dragOffY = my - py
        consumed = true
    end

    local bgCol = get_theme("Window.Background", Color3.fromRGB(18, 18, 22))
    local borderCol = get_theme("Window.Border", Color3.fromRGB(44, 44, 52))
    local titleCol = get_theme("Text.Title", Color3.fromRGB(255, 255, 255))
    local mutedCol = get_theme("Text.Secondary", Color3.fromRGB(160, 160, 170))
    local accentCol = window.Accent or get_theme("Accent", Color3.fromRGB(59, 130, 246))

    slot.Bg.Position = Vector2.new(px, py)
    slot.Bg.Size = Vector2.new(w, h)
    slot.Bg.Color = bgCol
    slot.Bg.Transparency = 0.94
    slot.Bg.Visible = true

    slot.Border.Position = Vector2.new(px, py)
    slot.Border.Size = Vector2.new(w, h)
    slot.Border.Color = borderCol
    slot.Border.Visible = true

    slot.AccentBar.Position = Vector2.new(px + 2, py)
    slot.AccentBar.Size = Vector2.new(w - 4, 2)
    slot.AccentBar.Color = accentCol
    slot.AccentBar.Visible = true

    local curX = px + 12
    for i = 1, 8 do
        local t = slot.Tokens[i]
        local p = pieces[i]
        if p then
            t.Text = p.Text
            t.Color = p.Accent and accentCol or (p.Muted and mutedCol or titleCol)
            t.Position = Vector2.new(curX, py + 7)
            t.Visible = true
            curX = curX + p.Width
        else
            t.Visible = false
        end
    end

    return consumed
end

function Overlay.Update(dt, window, mousePos, m1PressedArg, m1ClickedArg)
    if not window or window.Destroyed then
        hide_open_slot()
        hide_key_slot()
        hide_wm_slot()
        return false
    end

    local vp = get_viewport()
    local mx, my = -9999, -9999
    if mousePos then
        mx, my = mousePos.X, mousePos.Y
    elseif type(getmouseposition) == "function" then
        local p = getmouseposition()
        if p then mx, my = p.X, p.Y end
    end

    local m1Pressed = m1PressedArg
    local m1Clicked = m1ClickedArg
    if m1Pressed == nil then
        m1Pressed = (type(ismouse1pressed) == "function") and (ismouse1pressed() == true)
    end
    if m1Clicked == nil then
        m1Clicked = m1Pressed and not Overlay.PrevM1
        Overlay.PrevM1 = m1Pressed
    end

    local c1 = update_open_button(window, vp, mx, my, m1Pressed, m1Clicked)
    local c2 = update_keybind_menu(window, vp, mx, my, m1Pressed, m1Clicked and not c1)
    local c3 = update_watermark(window, vp, mx, my, m1Pressed, m1Clicked and not c1 and not c2)

    return c1 or c2 or c3
end

local function hide_tooltip_slot()
    local s = Overlay.TooltipSlot
    if not s then return end
    s.Bg.Visible = false
    s.Border.Visible = false
    s.Text.Visible = false
end

local function ensure_tooltip_slot()
    if Overlay.TooltipSlot then return Overlay.TooltipSlot end
    local pool = ensure_pool()
    local s = {
        Bg = pool:Get("Square"),
        Border = pool:Get("Square"),
        Text = pool:Get("Text"),
    }
    s.Bg.Filled = true
    s.Bg.Corner = 6
    s.Bg.ZIndex = 60
    s.Bg.Visible = false

    s.Border.Filled = false
    s.Border.Thickness = 1
    s.Border.Corner = 6
    s.Border.ZIndex = 61
    s.Border.Visible = false

    s.Text.Size = 12
    s.Text.ZIndex = 62
    s.Text.Visible = false

    Overlay.TooltipSlot = s
    return s
end

function Overlay.RenderTooltip(text, mx, my, window)
    if not text or text == "" or (window and window.Destroyed) then
        hide_tooltip_slot()
        return
    end
    local slot = ensure_tooltip_slot()
    local vp = get_viewport()
    local str = tostring(text)
    local tw = math.floor(#str * 6.8)
    local w = math.max(56, tw + 18)
    local h = 24
    local px = clamp((mx or 0) + 14, 6, math.max(6, vp.X - w - 6))
    local py = clamp((my or 0) + 18, 6, math.max(6, vp.Y - h - 6))

    slot.Bg.Position = Vector2.new(px, py)
    slot.Bg.Size = Vector2.new(w, h)
    slot.Bg.Color = get_theme("Card.Background", Color3.fromRGB(22, 22, 28))
    slot.Bg.Visible = true

    slot.Border.Position = Vector2.new(px, py)
    slot.Border.Size = Vector2.new(w, h)
    slot.Border.Color = get_theme("Window.Border", Color3.fromRGB(54, 54, 64))
    slot.Border.Visible = true

    slot.Text.Text = str
    slot.Text.Color = get_theme("Text.Title", Color3.fromRGB(255, 255, 255))
    slot.Text.Position = Vector2.new(px + 9, py + 5)
    slot.Text.Visible = true
end

function Overlay.Destroy()
    hide_open_slot()
    hide_key_slot()
    hide_wm_slot()
    hide_tooltip_slot()
    Overlay.OpenSlot = nil
    Overlay.KeySlot = nil
    Overlay.WmSlot = nil
    Overlay.TooltipSlot = nil
    if Overlay.Pool and Overlay.Pool.Destroy then
        Overlay.Pool:Destroy()
        Overlay.Pool = nil
    end
end

return Overlay

end)()

-- ============================================================================
-- MODULE: Components/Keybind.lua
-- ============================================================================
KeybindModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Components/Keybind.lua
-- Keybind component supporting both inline Toggle KeyPicker badges and standalone WindUI section rows.

local ThemeModule = Theme or ThemeModule

local MetricsModule = Metrics
if not MetricsModule then
    local ok, mod = pcall(function() return MetricsModule end)
    if ok then MetricsModule = mod end
end

local Keybind = {}
Keybind.__index = Keybind

local function format_key(k)
    if k == nil then return "?" end
    if MetricsModule and MetricsModule.KeyName then
        return MetricsModule.KeyName(k)
    end
    return tostring(k)
end

local function normalize_key(k)
    if k == nil then return nil end
    if type(k) == "number" then return k end
    if MetricsModule and MetricsModule.KeyCode then
        return MetricsModule.KeyCode(k) or k
    end
    return k
end

local function is_blacklisted(blacklist, vk)
    if type(blacklist) ~= "table" then return false end
    local name = format_key(vk):lower()
    for k, v in pairs(blacklist) do
        if type(k) == "number" then
            local target = normalize_key(v)
            if target == vk or tostring(v):lower() == name then
                return true
            end
        elseif v == true then
            local target = normalize_key(k)
            if target == vk or tostring(k):lower() == name then
                return true
            end
        end
    end
    return false
end

function Keybind.new(parent, id, config)
    local cfg = config or {}
    local isStandalone = parent ~= nil and parent.AllocateControlSlot ~= nil
    local sec = isStandalone and parent or (parent and parent.Section)
    local win = (sec and (sec.Window or (sec.ParentTab and sec.ParentTab.Window)))
        or (parent and (parent.Window or (parent.ParentTab and parent.ParentTab.Window)))
    local pool = (sec and sec.Pool) or (parent and parent.Pool) or (win and win.Pool)

    local pos, size
    if isStandalone then
        local desc = cfg.Desc or cfg.Description
        local rowH = (desc and desc ~= "") and 54 or (sec.RowHeight or 44)
        pos, size = sec:AllocateControlSlot(cfg.Half or cfg.Column ~= nil, rowH)
    else
        pos = Vector2.new(0, 0)
        size = Vector2.new(44, 22)
    end

    local keyVal = normalize_key(cfg.Default ~= nil and cfg.Default or cfg.Value)
    local initialVis = false
    if isStandalone then
        initialVis = sec ~= nil and sec.Visible == true
    elseif parent then
        initialVis = parent.Visible == true
    end

    local self = setmetatable({
        Parent = not isStandalone and parent or nil,
        Section = sec,
        Window = win,
        Id = id,
        Standalone = isStandalone,
        Text = cfg.Text or cfg.Title or id,
        Desc = cfg.Desc or cfg.Description,
        Mode = cfg.Mode or "Toggle",
        CanChange = cfg.CanChange ~= false,
        Blacklist = cfg.Blacklist,
        SyncToggleState = cfg.SyncToggleState ~= false,
        Key = keyVal,
        Value = keyVal,
        KeyName = format_key(keyVal),
        Capturing = false,
        ActiveState = (cfg.Mode == "Always"),
        PrevHeld = false,
        Visible = initialVis,
        Callback = cfg.Callback or function() end,
        Changed = cfg.Changed,
        RowBg = nil,
        Label = nil,
        DescLabel = nil,
        BadgeBg = nil,
        BadgeText = nil,
        ModeMenu = nil,
        ModeMenuOpen = false,
        Position = pos,
        Size = size,
    }, Keybind)

    local function measure_text(str, sz)
        return #tostring(str or "") * (sz * 0.58)
    end

    if pool then
        local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1
        local badgeStr = "[" .. self.KeyName .. "]"
        local badgeW = math.max(40, math.floor(measure_text(badgeStr, 11) + 14))
        local badgeH = 22
        local textW = measure_text(badgeStr, 11)

        if isStandalone then
            local rowBg = pool:Get("Square")
            rowBg.Position = pos
            rowBg.Size = size
            rowBg.Color = ThemeModule.Get("ElementBackground", Color3.fromRGB(34, 34, 38))
            rowBg.Filled = true
            rowBg.Corner = 8
            rowBg.ZIndex = 4
            rowBg.Visible = self.Visible
            self.RowBg = rowBg
            sec:_register(rowBg)

            local lbl = pool:Get("Text")
            lbl.Text = self.Text
            lbl.Font = fontUI
            lbl.Outline = false
            lbl.Size = 13
            lbl.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
            local titleY = (self.Desc and self.Desc ~= "") and (pos.Y + 10) or (pos.Y + math.floor((size.Y - 13) * 0.5))
            lbl.Position = Vector2.new(pos.X + 14, titleY)
            lbl.ZIndex = 5
            lbl.Visible = self.Visible
            self.Label = lbl
            sec:_register(lbl)

            if self.Desc and self.Desc ~= "" then
                local dLbl = pool:Get("Text")
                dLbl.Text = self.Desc
                dLbl.Font = fontUI
                dLbl.Outline = false
                dLbl.Size = 11
                dLbl.Color = ThemeModule.Get("Text.Secondary", Color3.fromRGB(161, 161, 170))
                dLbl.Position = Vector2.new(pos.X + 14, pos.Y + 28)
                dLbl.ZIndex = 5
                dLbl.Visible = self.Visible
                self.DescLabel = dLbl
                sec:_register(dLbl)
            end

            local bx = pos.X + size.X - badgeW - 14
            local by = pos.Y + math.floor((size.Y - badgeH) * 0.5)
            local bg = pool:Get("Square")
            bg.Position = Vector2.new(bx, by)
            bg.Size = Vector2.new(badgeW, badgeH)
            bg.Color = ThemeModule.Get("Control.Background", Color3.fromRGB(48, 48, 54))
            bg.Filled = true
            bg.Corner = 5
            bg.ZIndex = 5
            bg.Visible = self.Visible
            self.BadgeBg = bg
            sec:_register(bg)

            local txt = pool:Get("Text")
            txt.Text = badgeStr
            txt.Font = fontUI
            txt.Outline = false
            txt.Center = true
            txt.Size = 11
            txt.Color = ThemeModule.Get("Text.Secondary", Color3.fromRGB(161, 161, 170))
            txt.Position = Vector2.new(bx + math.floor(badgeW * 0.5), by + math.floor(badgeH * 0.5))
            txt.ZIndex = 6
            txt.Visible = self.Visible
            self.BadgeText = txt
            sec:_register(txt)
        elseif parent and parent.Position and parent.Size then
            local trackW = parent.Track and parent.Track.Size and parent.Track.Size.X or 42
            local bx = parent.Position.X + parent.Size.X - trackW - badgeW - 22
            local by = parent.Position.Y + math.floor((parent.Size.Y - badgeH) * 0.5)
            self.Position = Vector2.new(bx, by)
            self.Size = Vector2.new(badgeW, badgeH)

            local bg = pool:Get("Square")
            bg.Position = self.Position
            bg.Size = self.Size
            bg.Color = ThemeModule.Get("Control.Background", Color3.fromRGB(48, 48, 54))
            bg.Filled = true
            bg.Corner = 5
            bg.ZIndex = 5
            bg.Visible = self.Visible
            self.BadgeBg = bg

            local txt = pool:Get("Text")
            txt.Text = badgeStr
            txt.Font = fontUI
            txt.Outline = false
            txt.Center = true
            txt.Size = 11
            txt.Color = ThemeModule.Get("Text.Secondary", Color3.fromRGB(161, 161, 170))
            txt.Position = Vector2.new(bx + math.floor(badgeW * 0.5), by + math.floor(badgeH * 0.5))
            txt.ZIndex = 6
            txt.Visible = self.Visible
            self.BadgeText = txt

            if sec and sec._register then
                sec:_register(bg)
                sec:_register(txt)
            end
        end
    end

    if win then
        win.Keybinds = win.Keybinds or {}
        table.insert(win.Keybinds, self)
    end

    return self
end

function Keybind:_centerBadgeText(bx, by, bw, bh)
    if not self.BadgeText then return end
    self.BadgeText.Center = true
    self.BadgeText.Position = Vector2.new(bx + math.floor(bw * 0.5), by + math.floor(bh * 0.5))
end

function Keybind:SetPosition(pos, size)
    self.Position = pos
    if size then self.Size = size end

    local badgeW = self.BadgeBg and self.BadgeBg.Size and self.BadgeBg.Size.X or 40
    local badgeH = 22

    if self.Standalone then
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
        local bx = pos.X + self.Size.X - badgeW - 14
        local by = pos.Y + math.floor((self.Size.Y - badgeH) * 0.5)
        if self.BadgeBg then
            self.BadgeBg.Position = Vector2.new(bx, by)
            self.BadgeBg.Size = Vector2.new(badgeW, badgeH)
        end
        self:_centerBadgeText(bx, by, badgeW, badgeH)
    else
        local bx = pos.X
        local by = pos.Y
        if self.Parent and self.Parent.Position and self.Parent.Size then
            local trackW = self.Parent.Track and self.Parent.Track.Size and self.Parent.Track.Size.X or 42
            bx = self.Parent.Position.X + self.Parent.Size.X - trackW - badgeW - 22
            by = self.Parent.Position.Y + math.floor((self.Parent.Size.Y - badgeH) * 0.5)
            self.Position = Vector2.new(bx, by)
            self.Size = Vector2.new(badgeW, badgeH)
        end
        if self.BadgeBg then
            self.BadgeBg.Position = Vector2.new(bx, by)
            self.BadgeBg.Size = Vector2.new(badgeW, badgeH)
        end
        self:_centerBadgeText(bx, by, badgeW, badgeH)
    end
end

function Keybind:SetVisible(vis)
    self.Visible = vis
    if self.RowBg then self.RowBg.Visible = vis end
    if self.Label then self.Label.Visible = vis end
    if self.DescLabel then self.DescLabel.Visible = vis end
    if self.BadgeBg then self.BadgeBg.Visible = vis end
    if self.BadgeText then self.BadgeText.Visible = vis end
    if not vis and self.ModeMenuOpen then
        self:CloseModeMenu()
    end
end

function Keybind:Set(vk)
    local resolved = normalize_key(vk)
    self.Key = resolved
    self.Value = resolved
    self.KeyName = format_key(resolved)

    local badgeStr = "[" .. self.KeyName .. "]"
    local tw = (MetricsModule and MetricsModule.GetTextWidth and MetricsModule.GetTextWidth(badgeStr, 11)) or (#badgeStr * 5.8)
    local badgeW = math.max(40, math.floor(tw + 14))
    if self.BadgeBg then
        self.BadgeBg.Size = Vector2.new(badgeW, 22)
    end
    if self.BadgeText then
        self.BadgeText.Text = badgeStr
    end
    self:SetPosition(self.Position, self.Size)

    local lib = self.Section and self.Section.Env
    if lib and lib.Options and rawget(lib.Options, self.Id) == self then
        self.Value = resolved
    end
    if self.Changed then
        pcall(self.Changed, resolved)
    end
end
Keybind.SetValue = Keybind.Set

function Keybind:GetState()
    if self.Mode == "Always" then return true end
    return self.ActiveState == true
end

function Keybind:SetMode(mode)
    if mode ~= "Toggle" and mode ~= "Hold" and mode ~= "Always" then return end
    self.Mode = mode
    self.ActiveState = (mode == "Always")
    if self.Parent and self.SyncToggleState and self.Parent.Set then
        self.Parent:Set(self.ActiveState)
    end
    pcall(self.Callback, self.ActiveState)
end

local MODE_LIST = { "Toggle", "Hold", "Always" }

function Keybind:OpenModeMenu()
    if self.Locked then return end
    local win = self.Window or (self.Parent and self.Parent.Section and self.Parent.Section.Window)
    local pool = (self.Section and self.Section.Pool) or (win and win.Pool)
    if not pool then return end

    if win and win.OpenKeybindMenu and win.OpenKeybindMenu ~= self then
        win.OpenKeybindMenu:CloseModeMenu()
    end
    if win then
        win.OpenKeybindMenu = self
    end

    if not self.ModeMenu then
        local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1
        local menu = {
            Bg = pool:Get("Square"),
            Border = pool:Get("Square"),
            Rows = {},
        }
        menu.Bg.Filled = true
        menu.Bg.Corner = 6
        menu.Bg.ZIndex = 30
        menu.Bg.Visible = false

        menu.Border.Filled = false
        menu.Border.Thickness = 1
        menu.Border.Corner = 6
        menu.Border.ZIndex = 31
        menu.Border.Visible = false

        for i = 1, 3 do
            local rBg = pool:Get("Square")
            rBg.Filled = true
            rBg.Corner = 4
            rBg.ZIndex = 31
            rBg.Visible = false
            local rTxt = pool:Get("Text")
            rTxt.Font = fontUI
            rTxt.Outline = false
            rTxt.Size = 12
            rTxt.Text = MODE_LIST[i]
            rTxt.ZIndex = 32
            rTxt.Visible = false
            menu.Rows[i] = { Bg = rBg, Text = rTxt, Mode = MODE_LIST[i], Rect = nil }
        end

        if self.Section and self.Section._register then
            self.Section:_register(menu.Bg)
            self.Section:_register(menu.Border)
            for _, row in ipairs(menu.Rows) do
                self.Section:_register(row.Bg)
                self.Section:_register(row.Text)
            end
        end
        self.ModeMenu = menu
    end

    local bx = self.BadgeBg and self.BadgeBg.Position and self.BadgeBg.Position.X or self.Position.X
    local by = self.BadgeBg and self.BadgeBg.Position and self.BadgeBg.Position.Y or self.Position.Y
    local bw = self.BadgeBg and self.BadgeBg.Size and self.BadgeBg.Size.X or 40
    local bh = 22
    local mw = 84
    local rowH = 22
    local mh = 8 + #MODE_LIST * rowH
    local mx = bx + bw - mw
    local my = by + bh + 4

    local menu = self.ModeMenu
    menu.Rect = { X = mx, Y = my, W = mw, H = mh }
    menu.Bg.Position = Vector2.new(mx, my)
    menu.Bg.Size = Vector2.new(mw, mh)
    menu.Bg.Color = ThemeModule.Get("Card.Background", Color3.fromRGB(24, 24, 27))
    menu.Bg.Visible = true

    menu.Border.Position = Vector2.new(mx, my)
    menu.Border.Size = Vector2.new(mw, mh)
    menu.Border.Color = ThemeModule.Get("Window.Border", Color3.fromRGB(52, 52, 62))
    menu.Border.Visible = true

    for i, row in ipairs(menu.Rows) do
        local rx = mx + 4
        local ry = my + 4 + (i - 1) * rowH
        local rw = mw - 8
        local selected = self.Mode == row.Mode
        row.Rect = { X = rx, Y = ry, W = rw, H = rowH }
        row.Bg.Position = Vector2.new(rx, ry)
        row.Bg.Size = Vector2.new(rw, rowH - 2)
        row.Bg.Color = selected
            and ThemeModule.Get("Tab.ActiveBg", Color3.fromRGB(45, 45, 55))
            or ThemeModule.Get("Card.Background", Color3.fromRGB(24, 24, 27))
        row.Bg.Visible = selected
        row.Text.Position = Vector2.new(rx + 8, ry + 4)
        row.Text.Color = selected
            and ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
            or ThemeModule.Get("Text.Secondary", Color3.fromRGB(161, 161, 170))
        row.Text.Visible = true
    end

    self.ModeMenuOpen = true
end

function Keybind:CloseModeMenu()
    self.ModeMenuOpen = false
    local win = self.Window or (self.Parent and self.Parent.Section and self.Parent.Section.Window)
    if win and win.OpenKeybindMenu == self then
        win.OpenKeybindMenu = nil
    end
    if self.ModeMenu then
        if self.ModeMenu.Bg then self.ModeMenu.Bg.Visible = false end
        if self.ModeMenu.Border then self.ModeMenu.Border.Visible = false end
        for _, row in ipairs(self.ModeMenu.Rows) do
            if row.Bg then row.Bg.Visible = false end
            if row.Text then row.Text.Visible = false end
        end
    end
end

function Keybind:UpdateModeMenu(mx, my, m1Clicked, m2Clicked)
    if not self.ModeMenuOpen or not self.ModeMenu then return false end
    local r = self.ModeMenu.Rect
    if not r then
        self:CloseModeMenu()
        return false
    end
    local overMenu = mx >= r.X and mx <= r.X + r.W and my >= r.Y and my <= r.Y + r.H
    if not overMenu then
        if m1Clicked or m2Clicked then
            self:CloseModeMenu()
        end
        return false
    end
    if m1Clicked then
        for _, row in ipairs(self.ModeMenu.Rows) do
            local rr = row.Rect
            if rr and mx >= rr.X and mx <= rr.X + rr.W and my >= rr.Y and my <= rr.Y + rr.H then
                self:SetMode(row.Mode)
                self:CloseModeMenu()
                return true
            end
        end
    end
    return true
end

function Keybind:StartCapture()
    if self.Locked or not self.CanChange or self.Capturing then return end
    if self.ModeMenuOpen then self:CloseModeMenu() end
    self.Capturing = true
    self.CaptureStarted = os.clock()
    if self.BadgeText then
        self.BadgeText.Text = "[...]"
        self.BadgeText.Color = ThemeModule.Get("Accent.Blue", Color3.fromRGB(0, 145, 255))
        if self.BadgeBg then
            self:_centerBadgeText(self.BadgeBg.Position.X, self.BadgeBg.Position.Y, self.BadgeBg.Size.X, self.BadgeBg.Size.Y)
        end
    end
    local win = self.Window or (self.Parent and self.Parent.Section and self.Parent.Section.Window)
    if win then
        if win.Input and win.Input.PrevKeys then
            for k = 4, 6 do win.Input.PrevKeys[k] = (iskeypressed(k) == true) end
        end
        win.CapturingKeybind = self
        if win.ClaimInteraction then
            win:ClaimInteraction("KeyPicker_" .. tostring(self.Id))
        end
    end
end

function Keybind:CancelCapture()
    self.Capturing = false
    if self.BadgeText then
        self.BadgeText.Text = "[" .. self.KeyName .. "]"
        self.BadgeText.Color = ThemeModule.Get("Text.Secondary", Color3.fromRGB(161, 161, 170))
        if self.BadgeBg then
            self:_centerBadgeText(self.BadgeBg.Position.X, self.BadgeBg.Position.Y, self.BadgeBg.Size.X, self.BadgeBg.Size.Y)
        end
    end
    local win = self.Window or (self.Parent and self.Parent.Section and self.Parent.Section.Window)
    if win then
        if win.CapturingKeybind == self then
            win.CapturingKeybind = nil
        end
        if win.ReleaseInteraction then
            win:ReleaseInteraction("KeyPicker_" .. tostring(self.Id))
        end
    end
end

function Keybind:Clear()
    self:Set(nil)
    self:CancelCapture()
    pcall(self.Callback, nil)
end

function Keybind:ProcessInput(vk)
    if not self.Capturing then return end
    if vk == 27 then
        self:CancelCapture()
        return
    end
    if is_blacklisted(self.Blacklist, vk) then
        return
    end
    local win = self.Window or (self.Parent and self.Parent.Section and self.Parent.Section.Window)
    if win and win.Input and win.Input.PrevKeys then
        win.Input.PrevKeys[vk] = true
    end
    self:Set(vk)
    self:CancelCapture()
    pcall(self.Callback, self.Key)
end

function Keybind:HandleClick(mx, my)
    if self.Locked or not self.CanChange then return false end
    self:StartCapture()
    return true
end

function Keybind:SetTitle(title)
    self.Text = tostring(title or "")
    if self.Label then
        self.Label.Text = self.Text
    end
end

function Keybind:SetDesc(desc)
    self.Desc = desc ~= nil and tostring(desc) or ""
    if self.DescLabel then
        self.DescLabel.Text = self.Desc
    end
end

function Keybind:Lock(title)
    self.Locked = true
    if title ~= nil then self.LockedTitle = tostring(title) end
    if self.Capturing then self:CancelCapture() end
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Muted", Color3.fromRGB(120, 120, 130))
    end
end

function Keybind:Unlock()
    self.Locked = false
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
    end
end

function Keybind:Destroy()
    if self.Capturing then self:CancelCapture() end
    self:SetVisible(false)
end

return Keybind

end)()

-- ============================================================================
-- MODULE: Components/Button.lua
-- ============================================================================
ButtonModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Components/Button.lua
-- WindUI-identical action button with icon support, Justify, Tags badges, color support, and System font.

local ThemeModule = Theme or ThemeModule

local IconsModule = Icons
if not IconsModule then
    local ok, mod = pcall(function() return IconsModule end)
    if ok then IconsModule = mod end
end

local MetricsModule = Metrics
if not MetricsModule then
    local ok, mod = pcall(function() return MetricsModule end)
    if ok then MetricsModule = mod end
end

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
            tb.Label.Center = true
            tb.Label.Position = Vector2.new(tagEndX + math.floor(tagW * 0.5), tagY + math.floor(tagH * 0.5))
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
            self.Label.Center = true
            self.Label.Position = Vector2.new(pos.X + math.floor(size.X * 0.5), hasDesc and (lblY + 6) or (pos.Y + math.floor(size.Y * 0.5)))
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
                tagTxt.Center = true
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

end)()

-- ============================================================================
-- MODULE: Components/Slider.lua
-- ============================================================================
SliderModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Components/Slider.lua
-- 100% WindUI-identical slider component: card container, capsule pill thumb, icons support, and dual layouts.

local ThemeModule = Theme or ThemeModule

local IconsModule = Icons
if not IconsModule then
    local ok, mod = pcall(function() return IconsModule end)
    if ok then IconsModule = mod end
end

local Slider = {}
Slider.__index = Slider

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
        local trackCol = ThemeModule.Get("Slider.TrackBg", Color3.fromRGB(54, 54, 62))
        local fillCol = ThemeModule.Get("Accent.Blue", Color3.fromRGB(0, 145, 255))
        local rowBgCol = ThemeModule.Get("ElementBackground", Color3.fromRGB(34, 34, 38))
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
            lbl.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
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
            badge.Color = ThemeModule.Get("Text.Secondary", Color3.fromRGB(161, 161, 170))
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
                if IconsModule and IconsModule.Get then
                    IconsModule.Get(self.Icons.From, function(png)
                        if self.IconFrom and png then self.IconFrom.Data = png end
                    end)
                end
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
                if IconsModule and IconsModule.Get then
                    IconsModule.Get(self.Icons.To, function(png)
                        if self.IconTo and png then self.IconTo.Data = png end
                    end)
                end
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

    if self.HasTitle then
        if self.Label then
            self.Label.Position = Vector2.new(pos.X + 14, pos.Y + math.floor((self.Size.Y - 13) * 0.5))
        end
        if self.Badge then
            self.Badge.Position = Vector2.new(trackX - 38, pos.Y + math.floor((self.Size.Y - 12) * 0.5))
        end
    end

    if self.IconFrom then
        self.IconFrom.Position = Vector2.new(pos.X + 14, pos.Y + math.floor((self.Size.Y - 16) * 0.5))
    end
    if self.IconTo then
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
        self.Thumb.Position = Vector2.new(trackX + fillW - math.floor(thumbW * 0.5), trackY + 2 - math.floor(thumbH * 0.5))
    end
end

function Slider:Set(val)
    local clamped = math.clamp(val, self.Min, self.Max)
    if self.Step and self.Step > 0 then
        clamped = math.floor(clamped / self.Step + 0.5) * self.Step
        clamped = math.clamp(clamped, self.Min, self.Max)
    end
    if self.Precision and self.Precision >= 0 then
        local factor = 10 ^ self.Precision
        clamped = math.floor(clamped * factor + 0.5) / factor
    end
    self.Value = clamped

    if self.Track and self.FillBar then
        local trackW = self.Track.Size.X
        local trackX = self.Track.Position.X
        local trackY = self.Track.Position.Y
        local r = self.Max - self.Min
        local p = r > 0 and math.clamp((clamped - self.Min) / r, 0, 1) or 0
        local fillW = math.floor(trackW * p)
        self.FillBar.Size = Vector2.new(math.max(fillW, 3), 4)
        if self.Thumb then
            local thumbW = 24
            local thumbH = 14
            self.Thumb.Position = Vector2.new(trackX + fillW - math.floor(thumbW * 0.5), trackY + 2 - math.floor(thumbH * 0.5))
        end
    end

    if self.Badge then
        self.Badge.Text = tostring(clamped)
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
    if self.Label then
        self.Label.Text = self.Text
    end
end

function Slider:Lock(title)
    self.Locked = true
    if title ~= nil then self.LockedTitle = tostring(title) end
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Muted", Color3.fromRGB(120, 120, 130))
    end
end

function Slider:Unlock()
    self.Locked = false
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
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

end)()

-- ============================================================================
-- MODULE: Components/Dropdown.lua
-- ============================================================================
DropdownModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Components/Dropdown.lua
-- Responsive WindUI dropdown with pooled zero-leak popup, viewport clamping/flipping, hover highlight, and System font.

local ThemeModule = Theme or ThemeModule
local AnimationsModule = Animations or AnimationsModule

local IconsModule = Icons
if not IconsModule then
    local ok, mod = pcall(function() return IconsModule end)
    if ok then IconsModule = mod end
end

local Dropdown = {}
Dropdown.__index = Dropdown

local function compute_box_width(totalW)
    return math.min(140, math.max(76, math.floor(totalW * 0.38)))
end

local function item_label(val)
    if val == nil then return "" end
    if type(val) == "table" then
        if val.Type == "Divider" then return "---" end
        return tostring(val.Title or val.Text or val.Name or "")
    end
    return tostring(val)
end

local function format_display(value, isMulti)
    if isMulti then
        if type(value) ~= "table" then return tostring(value or "") end
        local parts = {}
        for _, v in ipairs(value) do
            table.insert(parts, item_label(v))
        end
        return #parts > 0 and table.concat(parts, ", ") or "None"
    end
    return value ~= nil and item_label(value) or "None"
end

function Dropdown:_resolveDynamicValues()
    if self.SpecialType == "Player" then
        local out = {}
        pcall(function()
            local pls = game:GetService("Players")
            local lp = pls.LocalPlayer
            for _, p in ipairs(pls:GetPlayers()) do
                if not (self.ExcludeLocalPlayer and p == lp) then
                    table.insert(out, p.Name)
                end
            end
        end)
        self.Values = out
    elseif self.SpecialType == "Team" then
        local out = {}
        pcall(function()
            local tms = game:GetService("Teams")
            for _, t in ipairs(tms:GetTeams()) do
                table.insert(out, t.Name)
            end
        end)
        self.Values = out
    end
end

function Dropdown.new(section, id, config)
    local cfg = config or {}
    local pos, size = section:AllocateControlSlot(cfg.Half or cfg.Column ~= nil, section.RowHeight or 44)
    local values = cfg.Values or {}
    local specialType = cfg.SpecialType or ((cfg.Type == "Player" or cfg.Type == "Team") and cfg.Type or nil)

    local self = setmetatable({
        Section = section,
        Id = id,
        Text = cfg.Text or cfg.Title or id,
        Values = values,
        SpecialType = specialType,
        ExcludeLocalPlayer = cfg.ExcludeLocalPlayer == true,
        SearchEnabled = (cfg.SearchBarEnabled == true) or (cfg.AllowSearch == true) or (cfg.Search == true),
        SearchQuery = "",
        AllowNone = cfg.AllowNone == true,
        Multi = cfg.Multi or false,
        Opened = false,
        IsOpen = false,
        Position = pos,
        Size = size,
        Visible = section.Visible,
        Callback = cfg.Callback or function() end,
        Items = {},
        VisibleItems = {},
        PopupBg = nil,
        PopupBorder = nil,
        PopupHoverBg = nil,
        SearchBg = nil,
        SearchText = nil,
        PopupItems = {},
        PopupDividers = {},
        PopupSelectedBgs = {},
        PopupDrawings = {},
        PopupRect = nil,
        HoverIndex = nil,
        ScrollOffset = 0,
        MaxScrollOffset = 0,
        MaxVisibleItems = cfg.MaxVisibleItems or 7,
        IsScrollingPopup = false,
        PopupScrollThumb = nil,
        OpenAnim = 1,
    }, Dropdown)

    self:_resolveDynamicValues()
    local initialVal = cfg.Default or cfg.Value or (self.Multi and {} or self.Values[1] or "")
    if type(initialVal) == "number" and self.Values[initialVal] ~= nil then
        initialVal = self.Values[initialVal]
    end
    self.Value = initialVal

    local pool = section.Pool
    if pool then
        local rowBgCol = ThemeModule.Get("ElementBackground", Color3.fromRGB(34, 34, 38))
        local boxBg = ThemeModule.Get("Control.Background", Color3.fromRGB(48, 48, 54))
        local txtCol = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
        local subCol = ThemeModule.Get("Text.Secondary", Color3.fromRGB(161, 161, 170))
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

        -- 3. Responsive Selection Box Pill
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

        -- 4. Value Badge
        local badge = pool:Get("Text")
        local dispText = format_display(self.Value, self.Multi)
        badge.Text = dispText
        badge.Font = fontUI
        badge.Outline = false
        badge.Size = 12
        badge.Color = subCol
        badge.Position = Vector2.new(boxX + 8, boxY + 6)
        badge.ZIndex = 6
        badge.Visible = section.Visible
        self.ValueBadge = badge
        section:_register(badge)

        -- 5. Chevrons Up/Down Icon (WindUI parity)
        local arrow = pool:Get("Image")
        arrow.Size = Vector2.new(13, 13)
        arrow.Position = Vector2.new(boxX + boxW - 19, boxY + 6)
        arrow.Transparency = 0.55
        arrow.ZIndex = 6
        arrow.Visible = section.Visible
        self.Arrow = arrow
        section:_register(arrow)
        if IconsModule and IconsModule.Get then
            IconsModule.Get("chevrons-up-down", function(png)
                if self.Arrow and png then self.Arrow.Data = png end
            end)
        end
    end

    return self
end

function Dropdown:SetPosition(pos, size)
    self.Position = pos
    self.Size = size or self.Size

    if self.RowBg then
        self.RowBg.Position = pos
        self.RowBg.Size = self.Size
    end

    if self.Label then
        self.Label.Position = Vector2.new(pos.X + 14, pos.Y + math.floor((self.Size.Y - 13) * 0.5))
    end

    local boxW = compute_box_width(self.Size.X)
    local boxH = 26
    local boxX = pos.X + self.Size.X - boxW - 14
    local boxY = pos.Y + math.floor((self.Size.Y - boxH) * 0.5)

    if self.Box then
        self.Box.Position = Vector2.new(boxX, boxY)
        self.Box.Size = Vector2.new(boxW, boxH)
    end

    if self.ValueBadge then
        self.ValueBadge.Position = Vector2.new(boxX + 8, boxY + 6)
    end

    if self.Arrow then
        self.Arrow.Position = Vector2.new(boxX + boxW - 19, boxY + 6)
    end

    if self.Opened then
        self:_layoutPopup()
    end
end

function Dropdown:Set(val)
    self.Value = val
    if self.ValueBadge then
        self.ValueBadge.Text = format_display(self.Value, self.Multi)
    end

    local lib = self.Section and self.Section.Env
    if lib and lib.Options and rawget(lib.Options, self.Id) == self then
        self.Value = val
    end
    pcall(self.Callback, val)
end

function Dropdown:SetTitle(title)
    self.Text = tostring(title or "")
    if self.Label then
        self.Label.Text = self.Text
    end
end

function Dropdown:Lock(title)
    self.Locked = true
    if title ~= nil then self.LockedTitle = tostring(title) end
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Muted", Color3.fromRGB(120, 120, 130))
    end
end

function Dropdown:Unlock()
    self.Locked = false
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
    end
end

function Dropdown:Refresh(newValues)
    if newValues ~= nil then
        self.Values = newValues
    else
        self:_resolveDynamicValues()
    end
    if self.Opened then
        self:_layoutPopup()
    end
end

function Dropdown:Select(val)
    if type(val) == "table" and (val.Type == "Divider" or val.Locked == true) then
        return
    end
    if type(val) == "table" and val.Callback then
        pcall(val.Callback, val)
    end
    if self.Multi then
        if type(self.Value) ~= "table" then self.Value = {} end
        local targetKey = item_label(val)
        local exists = false
        for i, v in ipairs(self.Value) do
            if v == val or item_label(v) == targetKey then
                table.remove(self.Value, i)
                exists = true
                break
            end
        end
        if not exists then
            table.insert(self.Value, val)
        end
        self:Set(self.Value)
        if self.Opened then self:_layoutPopup() end
    else
        if self.AllowNone and (self.Value == val or item_label(self.Value) == item_label(val)) then
            self:Set(nil)
        else
            self:Set(val)
        end
        self:Close()
    end
end

function Dropdown:Toggle()
    if self.Opened then
        self:Close()
    else
        self:Open()
    end
end

function Dropdown:_isSelected(val)
    local key = item_label(val)
    if self.Multi and type(self.Value) == "table" then
        for _, v in ipairs(self.Value) do
            if v == val or item_label(v) == key then return true end
        end
        return false
    end
    return self.Value == val or (self.Value ~= nil and item_label(self.Value) == key)
end

function Dropdown:_ensurePopupPrimitives()
    if self.PopupBg then return end
    local pool = self.Section and self.Section.Pool
    if not pool then return end

    local bg = pool:Get("Square")
    bg.Color = ThemeModule.Get("Card.Background", Color3.fromRGB(24, 24, 29))
    bg.Filled = true
    bg.Corner = 8
    bg.ZIndex = 14
    bg.Visible = false
    self.PopupBg = bg

    local border = pool:Get("Square")
    border.Color = ThemeModule.Get("Card.Border", Color3.fromRGB(48, 48, 56))
    border.Filled = false
    border.Thickness = 1
    border.Corner = 8
    border.ZIndex = 15
    border.Visible = false
    self.PopupBorder = border

    local hover = pool:Get("Square")
    hover.Color = ThemeModule.Get("Tab.ActiveBg", Color3.fromRGB(38, 38, 46))
    hover.Filled = true
    hover.Corner = 5
    hover.ZIndex = 15
    hover.Visible = false
    self.PopupHoverBg = hover

    table.insert(self.PopupDrawings, bg)
    table.insert(self.PopupDrawings, border)
    table.insert(self.PopupDrawings, hover)

    if not self.PopupScrollThumb then
        local st = pool:Get("Square")
        st.Color = ThemeModule.Get("Text.Muted", Color3.fromRGB(161, 161, 161))
        st.Filled = true
        st.Corner = 4
        st.Transparency = 0.28
        st.ZIndex = 18
        st.Visible = false
        self.PopupScrollThumb = st
        table.insert(self.PopupDrawings, st)
    end

    if self.SearchEnabled and not self.SearchBg then
        local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1
        local sBg = pool:Get("Square")
        sBg.Color = ThemeModule.Get("Control.Background", ThemeModule.Get("ElementBackground", Color3.fromRGB(48, 48, 52)))
        sBg.Filled = true
        sBg.Corner = 6
        sBg.ZIndex = 16
        sBg.Visible = false
        self.SearchBg = sBg

        local sTxt = pool:Get("Text")
        sTxt.Text = "Search..."
        sTxt.Font = fontUI
        sTxt.Outline = false
        sTxt.Size = 11
        sTxt.Color = ThemeModule.Get("Text.Secondary", Color3.fromRGB(160, 160, 170))
        sTxt.ZIndex = 17
        sTxt.Visible = false
        self.SearchText = sTxt

        table.insert(self.PopupDrawings, sBg)
        table.insert(self.PopupDrawings, sTxt)
    end
end

function Dropdown:RefreshSearchDisplay()
    if not self.SearchText then return end
    local win = self.Section and (self.Section.Window or (self.Section.ParentTab and self.Section.ParentTab.Window))
    local isFocused = (win ~= nil and win.FocusedDropdownSearch == self)
    if #self.SearchQuery > 0 then
        local caret = (isFocused and math.floor(os.clock() * 2) % 2 == 0) and "|" or ""
        self.SearchText.Text = self.SearchQuery .. caret
        self.SearchText.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
    elseif isFocused then
        self.SearchText.Text = (math.floor(os.clock() * 2) % 2 == 0) and "|" or ""
        self.SearchText.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
    else
        self.SearchText.Text = "Search..."
        self.SearchText.Color = ThemeModule.Get("Text.Secondary", Color3.fromRGB(160, 160, 170))
    end
end

function Dropdown:ProcessSearchKey(token)
    if not token then return end
    if token == "backspace" then
        self.SearchQuery = string.sub(self.SearchQuery, 1, math.max(0, #self.SearchQuery - 1))
    elseif token == "clear" then
        self.SearchQuery = ""
    elseif token == "enter" or token == "escape" then
        local win = self.Section and (self.Section.Window or (self.Section.ParentTab and self.Section.ParentTab.Window))
        if win and win.FocusedDropdownSearch == self then
            win.FocusedDropdownSearch = nil
        end
        return
    else
        self.SearchQuery = self.SearchQuery .. tostring(token)
    end
    if self.Opened then
        self.ScrollOffset = 0
        self:_layoutPopup()
    end
end

function Dropdown:_layoutPopup()
    local pool = self.Section and self.Section.Pool
    if not pool or not self.Values or #self.Values == 0 then
        self:Close()
        return
    end
    self:_ensurePopupPrimitives()

    local q = (self.SearchQuery or ""):lower()
    local filtered = {}
    for _, v in ipairs(self.Values) do
        if q == "" then
            table.insert(filtered, v)
        else
            local isDiv = type(v) == "table" and v.Type == "Divider"
            if not isDiv and item_label(v):lower():find(q, 1, true) then
                table.insert(filtered, v)
            end
        end
    end
    self.VisibleItems = filtered

    local win = self.Section and (self.Section.Window or (self.Section.ParentTab and self.Section.ParentTab.Window))
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1
    local maxVis = self.MaxVisibleItems or 7
    local total = #filtered
    local count = math.min(total, maxVis)
    self.MaxScrollOffset = math.max(0, total - count)
    self.ScrollOffset = math.clamp(self.ScrollOffset or 0, 0, self.MaxScrollOffset)
    local hasScroll = self.MaxScrollOffset > 0
    local itemH = 26
    local searchH = self.SearchEnabled and 30 or 0
    local popH = math.max(1, count) * itemH + 8 + searchH
    local boxW = compute_box_width(self.Size.X)
    local popW = math.max(boxW, 152)
    local popX = self.Position.X + self.Size.X - popW - 14
    local popY = self.Position.Y + self.Size.Y + 4

    local maxBoundY = 1040
    local minBoundX, maxBoundX = 8, 1912
    local cam = workspace and workspace.CurrentCamera
    if cam and cam.ViewportSize and cam.ViewportSize.Y > 0 then
        maxBoundY = cam.ViewportSize.Y - 8
        maxBoundX = cam.ViewportSize.X - 8
    end
    if win and win.Position and win.Size then
        minBoundX = win.Position.X + 8
        maxBoundX = math.min(maxBoundX, win.Position.X + win.Size.X - 8)
    end
    if popY + popH > maxBoundY and (self.Position.Y - popH - 4) >= 36 then
        popY = self.Position.Y - popH - 4
    end
    popX = math.clamp(popX, minBoundX, math.max(minBoundX, maxBoundX - popW))
    local anim = self.OpenAnim or 1
    popY = popY - math.floor((1 - anim) * 6 + 0.5)

    local listTop = popY + 4 + searchH
    local searchRect = self.SearchEnabled and { X = popX + 6, Y = popY + 6, W = popW - 12, H = 22 } or nil
    local scrollTrack = nil
    if hasScroll then
        local trackH = count * itemH
        local thumbH = math.max(18, math.floor(trackH * (count / total)))
        local ratio = self.MaxScrollOffset > 0 and (self.ScrollOffset / self.MaxScrollOffset) or 0
        local thumbY = listTop + math.floor(ratio * (trackH - thumbH))
        scrollTrack = { X = popX + popW - 12, Y = listTop, W = 12, H = trackH, ThumbH = thumbH }
        if self.PopupScrollThumb then
            self.PopupScrollThumb.Color = ThemeModule.Get("Text.Muted", Color3.fromRGB(161, 161, 161))
            self.PopupScrollThumb.Position = Vector2.new(popX + popW - 9, thumbY)
            self.PopupScrollThumb.Size = Vector2.new(5, thumbH)
            self.PopupScrollThumb.Visible = true
        end
    elseif self.PopupScrollThumb then
        self.PopupScrollThumb.Visible = false
    end

    self.PopupRect = {
        X = popX, Y = popY, W = popW, H = popH,
        ItemH = itemH, Count = count, ListTop = listTop,
        SearchRect = searchRect, ScrollTrack = scrollTrack,
        ItemRightPad = hasScroll and 10 or 4,
    }

    if self.PopupBg then
        self.PopupBg.Color = ThemeModule.Get("Card.Background", Color3.fromRGB(24, 24, 29))
        self.PopupBg.Position = Vector2.new(popX, popY)
        self.PopupBg.Size = Vector2.new(popW, popH)
        self.PopupBg.Transparency = 0.2 + anim * 0.8
        self.PopupBg.Visible = true
    end
    if self.PopupBorder then
        self.PopupBorder.Color = ThemeModule.Get("Card.Border", Color3.fromRGB(48, 48, 56))
        self.PopupBorder.Position = Vector2.new(popX, popY)
        self.PopupBorder.Size = Vector2.new(popW, popH)
        self.PopupBorder.Transparency = anim
        self.PopupBorder.Visible = true
    end
    if self.SearchBg and self.SearchText and searchRect then
        self.SearchBg.Color = ThemeModule.Get("Control.Background", ThemeModule.Get("ElementBackground", Color3.fromRGB(48, 48, 52)))
        self.SearchBg.Position = Vector2.new(searchRect.X, searchRect.Y)
        self.SearchBg.Size = Vector2.new(searchRect.W, searchRect.H)
        self.SearchBg.Visible = true
        self:RefreshSearchDisplay()
        self.SearchText.Position = Vector2.new(searchRect.X + 8, searchRect.Y + 5)
        self.SearchText.Visible = true
    end

    -- Reuse or grow cached text/divider/selected slots without leaking Pool objects
    for i = 1, count do
        local txt = self.PopupItems[i]
        if not txt then
            txt = pool:Get("Text")
            txt.Font = fontUI
            txt.Outline = false
            txt.Size = 12
            txt.ZIndex = 17
            self.PopupItems[i] = txt
            table.insert(self.PopupDrawings, txt)
        end
        local div = self.PopupDividers[i]
        if not div then
            div = pool:Get("Square")
            div.Filled = true
            div.ZIndex = 16
            div.Visible = false
            self.PopupDividers[i] = div
            table.insert(self.PopupDrawings, div)
        end
        local selBg = self.PopupSelectedBgs[i]
        if not selBg then
            selBg = pool:Get("Square")
            selBg.Filled = true
            selBg.Corner = 5
            selBg.ZIndex = 15
            selBg.Visible = false
            self.PopupSelectedBgs[i] = selBg
            table.insert(self.PopupDrawings, selBg)
        end

        local val = filtered[(self.ScrollOffset or 0) + i]
        local isDiv = type(val) == "table" and val.Type == "Divider"
        local isLock = type(val) == "table" and val.Locked == true
        local rowY = listTop + (i - 1) * itemH
        local rowW = popW - 4 - (hasScroll and 10 or 4)

        if isDiv then
            txt.Visible = false
            selBg.Visible = false
            div.Position = Vector2.new(popX + 10, rowY + math.floor(itemH * 0.5))
            div.Size = Vector2.new(rowW - 12, 1)
            div.Color = ThemeModule.Get("Card.Border", Color3.fromRGB(48, 48, 56))
            div.Visible = true
        else
            div.Visible = false
            local isSel = self:_isSelected(val)
            selBg.Position = Vector2.new(popX + 4, rowY)
            selBg.Size = Vector2.new(rowW, itemH)
            selBg.Color = ThemeModule.Get("Tab.ActiveBg", Color3.fromRGB(38, 38, 46))
            selBg.Visible = isSel

            txt.Text = item_label(val)
            if isLock then
                local cardC = ThemeModule.Get("Card.Background", Color3.fromRGB(24, 24, 29))
                local txtC = ThemeModule.Get("Text.Secondary", Color3.fromRGB(160, 160, 170))
                txt.Color = Color3.new(
                    (txtC.R or 0.5) * 0.45 + (cardC.R or 0.1) * 0.55,
                    (txtC.G or 0.5) * 0.45 + (cardC.G or 0.1) * 0.55,
                    (txtC.B or 0.5) * 0.45 + (cardC.B or 0.1) * 0.55
                )
            elseif isSel then
                txt.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
            else
                txt.Color = ThemeModule.Get("Text.Secondary", Color3.fromRGB(185, 185, 195))
            end
            txt.Position = Vector2.new(popX + 10, rowY + 6)
            txt.Visible = true
        end
    end
    for i = count + 1, #self.PopupItems do
        self.PopupItems[i].Visible = false
        if self.PopupDividers[i] then self.PopupDividers[i].Visible = false end
        if self.PopupSelectedBgs[i] then self.PopupSelectedBgs[i].Visible = false end
    end

    self:SetPopupHover(self.HoverIndex)
end

function Dropdown:Scroll(deltaSteps)
    if not self.Opened or (self.MaxScrollOffset or 0) <= 0 then return end
    local nextOff = math.clamp((self.ScrollOffset or 0) + (deltaSteps or 0), 0, self.MaxScrollOffset)
    if nextOff ~= self.ScrollOffset then
        self.ScrollOffset = nextOff
        self:_layoutPopup()
    end
end

function Dropdown:SetScrollRatio(ratio)
    if not self.Opened or (self.MaxScrollOffset or 0) <= 0 then return end
    local nextOff = math.clamp(math.floor(math.clamp(ratio or 0, 0, 1) * self.MaxScrollOffset + 0.5), 0, self.MaxScrollOffset)
    if nextOff ~= self.ScrollOffset then
        self.ScrollOffset = nextOff
        self:_layoutPopup()
    end
end

function Dropdown:SetPopupHover(idx)
    self.HoverIndex = idx
    if not self.PopupHoverBg then return end
    if self.Opened and idx and self.PopupRect and idx >= 1 and idx <= self.PopupRect.Count then
        local val = self.VisibleItems and self.VisibleItems[(self.ScrollOffset or 0) + idx]
        if type(val) == "table" and (val.Type == "Divider" or val.Locked == true) then
            self.PopupHoverBg.Visible = false
            return
        end
        local r = self.PopupRect
        local listTop = r.ListTop or (r.Y + 4)
        self.PopupHoverBg.Color = ThemeModule.Get("Tab.HoverBg", Color3.fromRGB(30, 30, 36))
        self.PopupHoverBg.Position = Vector2.new(r.X + 4, listTop + (idx - 1) * r.ItemH)
        self.PopupHoverBg.Size = Vector2.new(r.W - 4 - (r.ItemRightPad or 4), r.ItemH)
        self.PopupHoverBg.Visible = true
    else
        self.PopupHoverBg.Visible = false
    end
end

function Dropdown:Open()
    self:_resolveDynamicValues()
    local win = self.Section and (self.Section.Window or (self.Section.ParentTab and self.Section.ParentTab.Window))
    if win and win.OpenDropdown and win.OpenDropdown ~= self then
        win.OpenDropdown:Close()
    end
    self.ScrollOffset = 0
    self.Opened = true
    self.IsOpen = true
    self.OpenAnim = 0
    if win then win.OpenDropdown = self end
    self:_layoutPopup()
    AnimationsModule.Tween("dd_open_" .. tostring(self), 0, 1, 22, function(v)
        if not self.Opened then return end
        self.OpenAnim = v
        self:_layoutPopup()
    end)
end

function Dropdown:Close()
    self.Opened = false
    self.IsOpen = false
    self.HoverIndex = nil
    self.SearchQuery = ""
    self.ScrollOffset = 0
    self.IsScrollingPopup = false
    local win = self.Section and (self.Section.Window or (self.Section.ParentTab and self.Section.ParentTab.Window))
    if win then
        if win.OpenDropdown == self then win.OpenDropdown = nil end
        if win.FocusedDropdownSearch == self then win.FocusedDropdownSearch = nil end
    end
    if self.PopupBg then self.PopupBg.Visible = false end
    if self.PopupBorder then self.PopupBorder.Visible = false end
    if self.PopupHoverBg then self.PopupHoverBg.Visible = false end
    if self.PopupScrollThumb then self.PopupScrollThumb.Visible = false end
    if self.SearchBg then self.SearchBg.Visible = false end
    if self.SearchText then self.SearchText.Visible = false end
    for _, txt in ipairs(self.PopupItems) do
        txt.Visible = false
    end
    for _, div in ipairs(self.PopupDividers or {}) do
        div.Visible = false
    end
    for _, selBg in ipairs(self.PopupSelectedBgs or {}) do
        selBg.Visible = false
    end
end

function Dropdown:SetVisible(vis)
    self.Visible = vis
    if self.RowBg then self.RowBg.Visible = vis end
    if self.Box then self.Box.Visible = vis end
    if self.Label then self.Label.Visible = vis end
    if self.ValueBadge then self.ValueBadge.Visible = vis end
    if self.Arrow then self.Arrow.Visible = vis end
    if not vis and self.Opened then
        self:Close()
    end
end

function Dropdown:Destroy()
    self:SetVisible(false)
end

return Dropdown

end)()

-- ============================================================================
-- MODULE: Components/Input.lua
-- ============================================================================
InputModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Components/Input.lua
-- Responsive WindUI-identical text input with keyboard typing, caret blink, focus outline, Numeric/Finished modes.

local ThemeModule = Theme or ThemeModule

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
        local rowBgCol = ThemeModule.Get("ElementBackground", Color3.fromRGB(34, 34, 38))
        local boxBg = ThemeModule.Get("Control.Background", Color3.fromRGB(48, 48, 54))
        local borderCol = ThemeModule.Get("Control.Border", Color3.fromRGB(58, 58, 66))
        local txtCol = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
        local subCol = ThemeModule.Get("Text.Secondary", Color3.fromRGB(161, 161, 170))
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

    return self
end

function Input:_refreshDisplay()
    if not self.InputText then return end
    local txtCol = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
    local subCol = ThemeModule.Get("Text.Secondary", Color3.fromRGB(161, 161, 170))
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
        self.BoxBorder.Color = self.Focused
            and ThemeModule.Get("Accent.Blue", Color3.fromRGB(0, 145, 255))
            or ThemeModule.Get("Control.Border", Color3.fromRGB(58, 58, 66))
    end
end

function Input:SetPosition(pos, size)
    self.Position = pos
    self.Size = size or self.Size

    if self.RowBg then
        self.RowBg.Position = pos
        self.RowBg.Size = self.Size
    end

    if self.Label then
        self.Label.Position = Vector2.new(pos.X + 14, pos.Y + math.floor((self.Size.Y - 13) * 0.5))
    end

    local boxW = compute_box_width(self.Size.X)
    local boxH = 26
    local boxX = pos.X + self.Size.X - boxW - 14
    local boxY = pos.Y + math.floor((self.Size.Y - boxH) * 0.5)

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
    if self.Label then
        self.Label.Text = self.Text
    end
end

function Input:Lock(title)
    self.Locked = true
    if title ~= nil then self.LockedTitle = tostring(title) end
    if self.Focused then self:Blur(false) end
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Muted", Color3.fromRGB(120, 120, 130))
    end
end

function Input:Unlock()
    self.Locked = false
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
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

end)()

-- ============================================================================
-- MODULE: Components/Toggle.lua
-- ============================================================================
ToggleModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Components/Toggle.lua
-- WindUI-identical switch pill & checkmark checkbox with smooth decay animation and zero residual state bugs.

local Keybind = Keybind or KeybindModule
local ThemeModule = Theme or ThemeModule

local AnimationsModule = Animations
if not AnimationsModule then
    local ok, mod = pcall(function() return AnimationsModule end)
    if ok then AnimationsModule = mod end
end

local IconsModule = Icons
if not IconsModule then
    local ok, mod = pcall(function() return IconsModule end)
    if ok then IconsModule = mod end
end

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
        local offCol = ThemeModule.Get("Toggle.TrackOff", Color3.fromRGB(54, 54, 62))
        local onCol = ThemeModule.Get("Accent.Green", Color3.fromRGB(51, 199, 89))
        local rowBgCol = ThemeModule.Get("ElementBackground", Color3.fromRGB(34, 34, 38))
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
        lbl.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
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
            dLbl.Color = ThemeModule.Get("Text.Secondary", Color3.fromRGB(161, 161, 170))
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
        track.Color = togVal and (isCheck and ThemeModule.Get("Accent.Blue", Color3.fromRGB(0, 145, 255)) or onCol) or offCol
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
            if IconsModule and IconsModule.Get then
                IconsModule.Get("check", function(png)
                    if self.CheckIcon and png then self.CheckIcon.Data = png end
                end)
            end
        else
            local knob = pool:Get("Circle")
            knob.Radius = 7
            knob.Position = Vector2.new(togVal and (trackX + 31) or (trackX + 11), trackY + 11)
            knob.Filled = true
            knob.Color = Color3.fromRGB(255, 255, 255)
            knob.ZIndex = 6
            knob.Visible = false
            self.Knob = knob
            self.VisualKnob = knob
            section:_register(knob)
        end
    end

    return self
end

function Toggle:_applyAnimVisual(progress)
    self.AnimProgress = progress
    local isCheck = self.Type == "Checkbox"
    local offCol = ThemeModule.Get("Toggle.TrackOff", Color3.fromRGB(54, 54, 62))
    local onCol = isCheck
        and ThemeModule.Get("Accent.Blue", Color3.fromRGB(0, 145, 255))
        or ThemeModule.Get("Accent.Green", Color3.fromRGB(51, 199, 89))

    if self.Track then
        self.Track.Color = lerp_color(offCol, onCol, progress)
    end
    if not isCheck and self.Knob and self.Track then
        local tx = self.Track.Position.X
        local ty = self.Track.Position.Y
        local knobX = tx + 11 + (20 * progress)
        self.Knob.Position = Vector2.new(math.floor(knobX + 0.5), ty + 11)
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
        self.CheckIcon.Position = Vector2.new(trackX + 4, trackY + 4)
    end

    if self.Knob then
        local p = self.AnimProgress ~= nil and self.AnimProgress or (self.Value and 1 or 0)
        self.Knob.Position = Vector2.new(math.floor(trackX + 11 + 20 * p + 0.5), trackY + 11)
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

    if AnimationsModule and AnimationsModule.RegisterAnimation and self.Visible then
        AnimationsModule.RegisterAnimation("Toggle_" .. tostring(self), {
            Current = self.AnimProgress or target,
            Target = target,
            Lambda = 20,
            Epsilon = 0.01,
            OnUpdate = function(v)
                self:_applyAnimVisual(v)
            end,
        })
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
        self.Label.Color = ThemeModule.Get("Text.Muted", Color3.fromRGB(120, 120, 130))
    end
end

function Toggle:Unlock()
    self.Locked = false
    if self.Label then
        self.Label.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
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

end)()

-- ============================================================================
-- MODULE: Components/Paragraph.lua
-- ============================================================================
ParagraphModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Components/Paragraph.lua
-- Multiline WindUI Paragraph card with optional icon/thumbnail, accent tint, and inline action buttons.

local ThemeModule = Theme or ThemeModule
local IconsModule = Icons or IconsModule
local MetricsModule = Metrics or MetricsModule

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
            bSlot.Text.Center = true
            bSlot.Text.Position = Vector2.new(bx + math.floor(bw * 0.5), bTop + 13)
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
        if mx >= r.X and mx <= r.X + r.W and my >= r.Y and my <= r.Y + r.H then
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

end)()

-- ============================================================================
-- MODULE: Components/Code.lua
-- ============================================================================
CodeModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Components/Code.lua
-- WindUI Code viewer block with multiline layout and Copy-to-Clipboard action.

local ThemeModule = Theme or ThemeModule
local IconsModule = Icons or IconsModule
local MetricsModule = Metrics or MetricsModule

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

end)()

-- ============================================================================
-- MODULE: Components/Image.lua
-- ============================================================================
ImageModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Components/Image.lua
-- WindUI Image display element supporting aspect ratios, rounded frame, and async PNG fetching.

local ThemeModule = Theme or ThemeModule
local IconsModule = Icons or IconsModule

local ImageBlock = {}
ImageBlock.__index = ImageBlock

local function parse_aspect_height(aspect, width, fallbackH)
    if type(fallbackH) == "number" and fallbackH > 0 then
        return fallbackH
    end
    if type(aspect) == "string" then
        local a, b = aspect:match("(%d+)%s*:%s*(%d+)")
        local nA, nB = tonumber(a), tonumber(b)
        if nA and nB and nA > 0 and nB > 0 then
            return math.clamp(math.floor(width * (nB / nA) + 0.5), 60, 260)
        end
    end
    return 140
end

function ImageBlock.new(section, config)
    local cfg = config or {}
    local usableW = math.max(160, (section.Size and section.Size.X or 400) - ((section.Padding or 10) * 2))
    local rowH = parse_aspect_height(cfg.AspectRatio, usableW, cfg.Height)
    local pos, size = section:AllocateControlSlot(false, rowH)

    local self = setmetatable({
        Section = section,
        Source = cfg.Image or cfg.Url or "",
        AspectRatio = cfg.AspectRatio,
        FixedHeight = cfg.Height,
        Radius = cfg.Radius or 10,
        Position = pos,
        Size = size,
        Visible = section.Visible,
        _imgData = nil,
    }, ImageBlock)

    local pool = section.Pool
    if pool then
        local bg = pool:Get("Square")
        bg.Position = pos
        bg.Size = size
        bg.Color = ThemeModule.Get("ElementBackground", Color3.fromRGB(20, 20, 25))
        bg.Filled = true
        bg.Corner = self.Radius
        bg.ZIndex = 4
        bg.Visible = section.Visible
        self.Visual = bg
        section:_register(bg)

        local border = pool:Get("Square")
        border.Position = pos
        border.Size = size
        border.Color = ThemeModule.Get("Window.Border", Color3.fromRGB(44, 44, 52))
        border.Filled = false
        border.Thickness = 1
        border.Corner = self.Radius
        border.ZIndex = 6
        border.Visible = section.Visible
        self.Border = border
        section:_register(border)

        local img = pool:Get("Image")
        img.Position = pos
        img.Size = size
        img.Rounding = self.Radius
        img.Transparency = 1
        img.ZIndex = 5
        img.Visible = false
        self.ImgDrawing = img
        section:_register(img)

        self:SetImage(self.Source)
    end

    return self
end

function ImageBlock:SetImage(src)
    self.Source = tostring(src or "")
    if self.Source == "" or not self.ImgDrawing then return end

    local function apply_data(data)
        if not data or not self.ImgDrawing then return end
        self._imgData = data
        self.ImgDrawing.Data = data
        self.ImgDrawing.Visible = self.Visible
    end

    if self.Source:sub(1, 8) == "https://" or self.Source:sub(1, 7) == "http://" then
        if IconsModule and IconsModule.Cache and IconsModule.Cache[self.Source] then
            apply_data(IconsModule.Cache[self.Source])
            return
        end
        if task and task.spawn then
            task.spawn(function()
                local ok, data = pcall(function()
                    return game and game.HttpGet and game:HttpGet(self.Source) or nil
                end)
                if ok and data and (data:sub(1, 4) == "\x89PNG" or data:sub(2, 4) == "PNG") then
                    if IconsModule and IconsModule.Cache then
                        IconsModule.Cache[self.Source] = data
                    end
                    apply_data(data)
                end
            end)
        end
    elseif IconsModule and IconsModule.Get then
        local got = IconsModule.Get(self.Source, apply_data)
        if got then apply_data(got) end
    end
end

function ImageBlock:SetPosition(pos, size)
    self.Position = pos
    self.Size = size or self.Size
    if self.Visual then
        self.Visual.Position = pos
        self.Visual.Size = self.Size
    end
    if self.Border then
        self.Border.Position = pos
        self.Border.Size = self.Size
    end
    if self.ImgDrawing then
        self.ImgDrawing.Position = pos
        self.ImgDrawing.Size = self.Size
    end
end

function ImageBlock:SetVisible(vis)
    self.Visible = vis
    if self.Visual then self.Visual.Visible = vis end
    if self.Border then self.Border.Visible = vis end
    if self.ImgDrawing then self.ImgDrawing.Visible = vis and (self._imgData ~= nil) end
end

return ImageBlock

end)()

-- ============================================================================
-- MODULE: Components/ProgressBar.lua
-- ============================================================================
ProgressBarModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Components/ProgressBar.lua
-- WindUI ProgressBar component supporting Percent/Value/Fraction display and smooth animated fill.

local ThemeModule = Theme or ThemeModule
local MetricsModule = Metrics or MetricsModule

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
        bg.Color = ThemeModule.Get("ElementBackground", Color3.fromRGB(42, 42, 44))
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
        titleTxt.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
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
            valTxt.Color = ThemeModule.Get("Text.Secondary", Color3.fromRGB(165, 165, 175))
            valTxt.ZIndex = 5
            valTxt.Visible = section.Visible
            self.ValueText = valTxt
            section:_register(valTxt)
        end

        local track = pool:Get("Square")
        track.Filled = true
        track.Corner = 3
        track.Color = ThemeModule.Get("Slider.Track", Color3.fromRGB(48, 48, 56))
        track.ZIndex = 5
        track.Visible = section.Visible
        self.Track = track
        section:_register(track)

        local fill = pool:Get("Square")
        fill.Filled = true
        fill.Corner = 3
        fill.Color = cfg.Color or ThemeModule.Get("Accent.Blue", Color3.fromRGB(0, 145, 255))
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
        return
    end

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
        local vw = math.floor(#str * 6.8)
        self.ValueText.Position = Vector2.new(self.Position.X + self.Size.X - vw - 14, self.Position.Y + 9)
        self.ValueText.Visible = self.Visible
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
        self.TitleText.Text = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(self.Title, self.Size.X - 80, 13) or self.Title
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

end)()

-- ============================================================================
-- MODULE: Components/Colorpicker.lua
-- ============================================================================
ColorpickerModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Components/Colorpicker.lua
-- Interactive HSV + Alpha Colorpicker with PNG overlay maps, Image.Rounding, and WindUI swatch transparency.

local ThemeModule = Theme or ThemeModule
local IconsModule = Icons or IconsModule
local MetricsModule = Metrics or MetricsModule

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
        bg.Color = ThemeModule.Get("ElementBackground", Color3.fromRGB(42, 42, 44))
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
        titleTxt.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
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
            dTxt.Color = ThemeModule.Get("Text.Secondary", Color3.fromRGB(161, 161, 170))
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

            if IconsModule and IconsModule.GetTexture then
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
        swBorder.Color = ThemeModule.Get("Window.Border", Color3.fromRGB(64, 64, 76))
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

local ALPHA_TILE_COLS = 24
local ALPHA_TILE_ROWS = 2
local ALPHA_SEGMENTS = 24

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

    for r = 1, ALPHA_TILE_ROWS do
        for c = 1, ALPHA_TILE_COLS do
            local tile = pool:Get("Square")
            tile.Filled = true
            tile.Color = ((r + c) % 2 == 0) and Color3.fromRGB(220, 220, 225) or Color3.fromRGB(130, 130, 140)
            tile.ZIndex = 25
            tile.Visible = false
            table.insert(pd.AlphaTiles, tile)
            self.Section:_register(tile)
        end
    end

    for i = 1, ALPHA_SEGMENTS do
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

    if IconsModule and IconsModule.GetTexture then
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
    pd.Bg.Color = ThemeModule.Get("Card.Background", Color3.fromRGB(22, 22, 28))
    pd.Bg.Visible = true

    pd.Border.Position = Vector2.new(x, y)
    pd.Border.Size = Vector2.new(popW, popH)
    pd.Border.Color = ThemeModule.Get("Window.Border", Color3.fromRGB(52, 52, 62))
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
        local tileW = math.floor(ab.W / ALPHA_TILE_COLS)
        local tileH = math.floor(ab.H / ALPHA_TILE_ROWS)
        local idx = 1
        for r = 1, ALPHA_TILE_ROWS do
            for c = 1, ALPHA_TILE_COLS do
                local tile = pd.AlphaTiles[idx]
                local tx = ab.X + (c - 1) * tileW
                local ty = ab.Y + (r - 1) * tileH
                local tw = (c == ALPHA_TILE_COLS) and (ab.X + ab.W - tx) or tileW
                local th = (r == ALPHA_TILE_ROWS) and (ab.Y + ab.H - ty) or tileH
                tile.Position = Vector2.new(tx, ty)
                tile.Size = Vector2.new(math.max(1, tw), math.max(1, th))
                tile.Visible = true
                idx = idx + 1
            end
        end

        for i = 1, ALPHA_SEGMENTS do
            local seg = pd.AlphaSegments[i]
            local x0 = ab.X + math.floor((i - 1) * ab.W / ALPHA_SEGMENTS)
            local x1 = ab.X + math.floor(i * ab.W / ALPHA_SEGMENTS)
            seg.Position = Vector2.new(x0, ab.Y)
            seg.Size = Vector2.new(math.max(1, x1 - x0), ab.H)
            seg.Color = self.Value
            seg.Transparency = (i - 1) / (ALPHA_SEGMENTS - 1)
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
    pd.HexText.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
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
        self.TitleText.Text = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(self.Title, maxTextW, 13) or self.Title
        local ty = (self.Desc and self.Desc ~= "") and (pos.Y + 9) or (pos.Y + math.floor((self.Size.Y - 13) * 0.5))
        self.TitleText.Position = Vector2.new(pos.X + 14, ty)
    end
    if self.DescText then
        self.DescText.Text = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(self.Desc, maxTextW, 11) or self.Desc
        self.DescText.Position = Vector2.new(pos.X + 14, pos.Y + 27)
    end
    local sx = pos.X + self.Size.X - 46
    local sy = pos.Y + math.floor((self.Size.Y - 18) * 0.5)
    if self.SwatchGrid then self.SwatchGrid.Position = Vector2.new(sx, sy) end
    if self.Swatch then self.Swatch.Position = Vector2.new(sx, sy) end
    if self.SwatchBorder then self.SwatchBorder.Position = Vector2.new(sx, sy) end
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
        self.TitleText.Color = ThemeModule.Get("Text.Muted", Color3.fromRGB(120, 120, 130))
    end
end

function Colorpicker:Unlock()
    self.Locked = false
    if self.TitleText then
        self.TitleText.Color = ThemeModule.Get("Text.Title", Color3.fromRGB(255, 255, 255))
    end
end

function Colorpicker:Destroy()
    self:SetVisible(false)
end

return Colorpicker

end)()

-- ============================================================================
-- MODULE: Layout/ContentSection.lua
-- ============================================================================
ContentSectionModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Layout/ContentSection.lua
-- Vertical stacking flow container supporting responsive reflow, viewport clipping, and WindUI + Obsidian compatibility.

local PoolModule = Pool or PoolModule
local MetaModule = Meta or MetaModule
local GeometryModule = Geometry or GeometryModule
local MetricsModule = Metrics or MetricsModule
local ThemeModule = Theme or ThemeModule
local IconsModule = Icons
if not IconsModule then
    local ok, mod = pcall(function() return IconsModule end)
    if ok then IconsModule = mod end
end

local ToggleModule = Toggle or ToggleModule
local SliderModule = Slider or SliderModule
local ButtonModule = Button or ButtonModule
local DropdownModule = Dropdown or DropdownModule
local InputModule = Input or InputModule
local KeybindModule = Keybind or KeybindModule
local ParagraphModule = Paragraph or ParagraphModule
local CodeModule = Code or CodeModule
local ImageModule = Image or ImageModule
local ProgressBarModule = ProgressBar or ProgressBarModule
local ColorpickerModule = Colorpicker or ColorpickerModule

local ContentSection = {}
ContentSection.__index = ContentSection

local function get_theme_color(token, default)
    return ThemeModule.Get(token, default)
end

function ContentSection.new(config, parentTab, window)
    local cfg = type(config) == "table" and config or { Title = tostring(config or "Section") }
    local win = window or (parentTab and parentTab.Window)
    local pool = (win and win.Pool) or (parentTab and parentTab.Pool)
    if not pool and PoolModule then
        pool = PoolModule.new(200, MetaModule)
    end

    local sbWidth = win and win.SidebarWidth or 190
    local topHeight = win and win.HeaderHeight or 44
    local contentX = sbWidth + 14
    local defaultY = topHeight + 14
    local startY = (parentTab and parentTab.ContentCursorY) or defaultY
    local contentW = win and math.max(180, win.Size.X - sbWidth - 28) or 422
    local isBoxed = (cfg.Box == true) or (cfg._forceBox == true)

    -- Expandable/collapsible support: `Opened = false` starts collapsed
    local hasExpandableTitle = (cfg.Title ~= nil and cfg.Title ~= "")
    local expandable = hasExpandableTitle and (cfg.Opened ~= nil)
    local startOpened = (cfg.Opened ~= false)  -- default true

    local self = setmetatable({
        Type = "ContentSection",
        Title = cfg.Title,
        Description = cfg.Description or cfg.Desc,
        TextSize = cfg.TextSize or 13,
        Box = isBoxed,
        Columns = cfg.Columns or 1,
        ParentTab = parentTab,
        Window = win,
        Env = win and win.Env or _G.Library,
        Pool = pool,

        Controls = {},
        Drawings = {},
        _drawings = {},

        -- Relative position to win.Position (base layout without scroll)
        Position = cfg.Position or Vector2.new(contentX, startY),
        BaseRelY = (cfg.Position and cfg.Position.Y) or startY,
        Size = cfg.Size or Vector2.new(contentW, 30),
        Padding = isBoxed and 12 or 0,
        ColGap = 6,
        RowGap = 6,
        RowHeight = 44,
        SliderRowHeight = 46,

        CursorY = 0,
        HeaderHeight = 0,
        LastAllocated = nil,

        Background = nil,
        Border = nil,
        TitleText = nil,
        DescText = nil,
        ChevronImg = nil,  -- expandable chevron icon

        -- Expandable state
        Expandable = expandable,
        IsExpanded = startOpened,

        Visible = parentTab and (parentTab.IsActive == true) or (parentTab == nil),
        Destroyed = false,
    }, ContentSection)

    self:_renderCard()
    self:_renderHeader()
    -- Render chevron after header if expandable
    if expandable and pool then
        local chev = pool:Get("Image")
        chev.Size = Vector2.new(12, 12)
        chev.Transparency = 0.6
        chev.ZIndex = 5
        chev.Visible = false
        self.ChevronImg = chev
        self:_register(chev)
        if IconsModule and IconsModule.Get then
            IconsModule.Get(startOpened and "chevron-down" or "chevron-up", function(png)
                if self.ChevronImg and png then self.ChevronImg.Data = png end
            end)
        end
    end
    -- When collapsed initially, collapse content
    if expandable and not startOpened then
        self.CursorY = 0
    end
    self:_syncTabCursor()

    return self
end

function ContentSection:_syncTabCursor()
    -- When collapsed (Expandable=true, IsExpanded=false), use only HeaderHeight
    local contentH = (self.Expandable and not self.IsExpanded) and 0 or self.CursorY
    local totalH = self.Box and math.max(40, (self.Padding * 2) + contentH) or math.max(0, contentH)
    -- Expandable sections always show at least the header
    if self.Expandable then
        totalH = math.max(self.HeaderHeight + (self.Padding * 2), totalH)
    end
    self.Size = Vector2.new(self.Size.X, totalH)

    if self.Background then
        self.Background.Size = self.Size
    end
    if self.Border then
        self.Border.Size = self.Size
    end

    if self.ParentTab and self.ParentTab.ContentCursorY ~= nil then
        local nextY = self.Position.Y + totalH + (self.Box and 10 or 4)
        if nextY > self.ParentTab.ContentCursorY then
            self.ParentTab.ContentCursorY = nextY
        end
        self.ParentTab._layoutDirty = true
    end
end

function ContentSection:_register(obj)
    if not obj then return end
    table.insert(self.Drawings, obj)
    table.insert(self._drawings, obj)

    if self.ParentTab then
        if self.ParentTab.RegisterDrawing then
            self.ParentTab:RegisterDrawing(obj)
        elseif self.ParentTab.Drawings then
            table.insert(self.ParentTab.Drawings, obj)
        end
        if self.ParentTab._drawings then
            table.insert(self.ParentTab._drawings, obj)
        end
    end

    local win = self.Window or (self.ParentTab and self.ParentTab.Window)
    if win and win._drawings then
        table.insert(win._drawings, obj)
    end
end

function ContentSection:_renderCard()
    local win = self.Window or (self.ParentTab and self.ParentTab.Window)
    local basePos = win and win.Position or Vector2.new(0, 0)
    local absPos = Vector2.new(basePos.X + self.Position.X, basePos.Y + self.Position.Y)

    -- Matcha Transparency is opacity (1 = opaque, 0 = invisible): 0.04 = subtle 4% white overlay, 0.16 = subtle border
    local bgCol = get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))
    local borderCol = get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))

    local bg = self.Pool:Get("Square")
    bg.Position = absPos
    bg.Size = self.Size
    bg.Color = bgCol
    bg.Transparency = 0.04
    bg.Filled = true
    bg.Corner = 10
    bg.ZIndex = 3
    self.Background = bg

    local border = self.Pool:Get("Square")
    border.Position = absPos
    border.Size = self.Size
    border.Color = borderCol
    border.Transparency = 0.16
    border.Filled = false
    border.Thickness = 1
    border.Corner = 10
    border.ZIndex = 3
    self.Border = border

    self.bg = self.Background
    self.border = self.Border

    local isShown = self.Visible and self.Box
    if self.Background then self.Background.Visible = isShown end
    if self.Border then self.Border.Visible = isShown end

    self:_register(self.Background)
    if self.Border then self:_register(self.Border) end
end

function ContentSection:_renderHeader()
    local win = self.Window or (self.ParentTab and self.ParentTab.Window)
    local basePos = win and win.Position or Vector2.new(0, 0)
    local absPos = Vector2.new(basePos.X + self.Position.X, basePos.Y + self.Position.Y)
    local innerX = absPos.X + self.Padding
    local innerY = absPos.Y + self.Padding
    local usableW = self.Size.X - (self.Padding * 2)
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    local currentY = innerY

    if self.Title and self.Title ~= "" then
        local titleObj = self.Pool:Get("Text")
        local fitTitle = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(self.Title, usableW, self.TextSize) or tostring(self.Title)
        titleObj.Text = fitTitle
        titleObj.Size = self.TextSize
        titleObj.Font = fontUI
        titleObj.Outline = false
        titleObj.Color = get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))
        titleObj.Position = Vector2.new(innerX, currentY)
        titleObj.ZIndex = 4
        titleObj.Visible = self.Visible
        self.TitleText = titleObj
        self:_register(titleObj)
        currentY = currentY + math.max(18, self.TextSize + 6)
    end

    if self.Description and self.Description ~= "" then
        local descObj = self.Pool:Get("Text")
        local fitDesc = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(self.Description, usableW, 11) or tostring(self.Description)
        descObj.Text = fitDesc
        descObj.Size = 11
        descObj.Font = fontUI
        descObj.Outline = false
        descObj.Color = get_theme_color("Text.Secondary", Color3.fromRGB(161, 161, 170))
        descObj.Position = Vector2.new(innerX, currentY)
        descObj.ZIndex = 4
        descObj.Visible = self.Visible
        self.DescText = descObj
        self:_register(descObj)
        currentY = currentY + 15
    end

    if (self.Title and self.Title ~= "") or (self.Description and self.Description ~= "") then
        currentY = currentY + 4
    end

    self.HeaderHeight = currentY - innerY
    self.CursorY = self.HeaderHeight
end

function ContentSection:AllocateControlSlot(isHalf, height)
    local h = height or self.RowHeight
    local win = self.Window or (self.ParentTab and self.ParentTab.Window)
    local basePos = win and win.Position or Vector2.new(0, 0)
    local absPos = Vector2.new(basePos.X + self.Position.X, basePos.Y + self.Position.Y)
    local innerX = absPos.X + self.Padding
    local innerY = absPos.Y + self.Padding
    local usableW = math.max(140, self.Size.X - (self.Padding * 2))

    if self._activeGroup then
        local grp = self._activeGroup
        if not grp.RowRelY then
            grp.RowRelY = self.Padding + self.CursorY
        end
        if h > grp.MaxH then
            local extra = (h - grp.MaxH) + (grp.MaxH == 0 and self.RowGap or 0)
            self.CursorY = self.CursorY + extra
            grp.MaxH = h
        end
        local colIdx = #grp.Items + 1
        self.LastAllocated = {
            RelX = self.Padding,
            RelY = grp.RowRelY,
            Width = usableW,
            Height = h,
            _group = grp,
            _colIdx = colIdx,
        }
        self:_syncTabCursor()
        return Vector2.new(innerX, absPos.Y + grp.RowRelY), Vector2.new(usableW, h)
    end

    local slotX = innerX
    local slotY = innerY + self.CursorY
    local slotW = usableW

    self.LastAllocated = {
        RelX = self.Padding,
        RelY = self.Padding + self.CursorY,
        Width = slotW,
        Height = h,
    }

    self.CursorY = self.CursorY + h + self.RowGap
    self:_syncTabCursor()

    return Vector2.new(slotX, slotY), Vector2.new(slotW, h)
end

local function is_ctrl_active(sec, ctrl)
    return ctrl._hidden ~= true
end

function ContentSection:GetDynamicHeight(targetWidth)
    local w = targetWidth or self.Size.X
    local usableW = math.max(140, w - (self.Padding * 2))
    if self.Expandable and not self.IsExpanded then
        local hdrH = self.HeaderHeight or 22
        return self.Box and math.max(40, (self.Padding * 2) + hdrH) or hdrH
    end
    local dynY = self.Padding + (self.HeaderHeight or 0)
    local seenGroups = {}
    for _, ctrl in ipairs(self.Controls) do
        if is_ctrl_active(self, ctrl) then
            if ctrl._group then
                if not seenGroups[ctrl._group] then
                    seenGroups[ctrl._group] = true
                    dynY = dynY + (ctrl._group.MaxH or 44) + self.RowGap
                end
            else
                local ch = (ctrl.RecalcHeight and ctrl:RecalcHeight(usableW)) or (ctrl.Size and ctrl.Size.Y) or 44
                dynY = dynY + ch + self.RowGap
            end
        end
    end
    local cursorPart = math.max(0, dynY - self.Padding)
    return self.Box and math.max(40, (self.Padding * 2) + cursorPart) or cursorPart
end

function ContentSection:Open()
    if not self.Expandable or self.IsExpanded then return end
    self.IsExpanded = true
    if self.ChevronImg and IconsModule and IconsModule.Get then
        IconsModule.Get("chevron-down", function(png)
            if self.ChevronImg and png then self.ChevronImg.Data = png end
        end)
    end
    if self.ParentTab then self.ParentTab._layoutDirty = true end
end

function ContentSection:Close()
    if not self.Expandable or not self.IsExpanded then return end
    self.IsExpanded = false
    if self.ChevronImg and IconsModule and IconsModule.Get then
        IconsModule.Get("chevron-up", function(png)
            if self.ChevronImg and png then self.ChevronImg.Data = png end
        end)
    end
    if self.ParentTab then self.ParentTab._layoutDirty = true end
end

function ContentSection:ToggleExpand()
    if self.IsExpanded then self:Close() else self:Open() end
end

function ContentSection:HandleHeaderClick(mx, my)
    if not self.Expandable or not self._headerRect then return false end
    local r = self._headerRect
    if mx >= r.X and mx <= r.X + r.W and my >= r.Y and my <= r.Y + r.H then
        self:ToggleExpand()
        return true
    end
    return false
end

function ContentSection:Reflow(basePos, newWidth, scrollY, clipTop, clipBottom)
    local scroll = scrollY or 0
    local w = newWidth or self.Size.X
    local dynH = self:GetDynamicHeight(w)
    self.Size = Vector2.new(w, dynH)

    local absPos = Vector2.new(basePos.X + self.Position.X, basePos.Y + self.Position.Y - scroll)
    local innerX = absPos.X + self.Padding
    local innerY = absPos.Y + self.Padding
    local usableW = math.max(140, w - (self.Padding * 2))

    if self.Background then
        self.Background.Position = absPos
        self.Background.Size = self.Size
        local bgVis = self.Visible and self.Box
        if clipTop and clipBottom then
            -- Boxed sections only appear when 100% inside the visible clip bounds
            bgVis = bgVis and (absPos.Y >= clipTop) and (absPos.Y + self.Size.Y <= clipBottom)
        end
        self.Background.Visible = bgVis
    end
    if self.Border then
        self.Border.Position = absPos
        self.Border.Size = self.Size
        self.Border.Visible = self.Background and self.Background.Visible or false
    end

    -- For boxed sections: ALL inner drawings must be hidden when card is fully outside clip
    local boxed = self.Box == true
    -- bgVis here: true = card is at least partially in view (bg visible), nil/false = fully outside
    local bgVis = boxed and (self.Background and self.Background.Visible or false) or nil

    local currentY = innerY
    if self.TitleText then
        self.TitleText.Position = Vector2.new(innerX, currentY)
        if MetricsModule and MetricsModule.Fit then
            self.TitleText.Text = MetricsModule.Fit(self.Title or "", usableW, self.TextSize)
        end
        local tVis = self.Visible
        if boxed then
            tVis = tVis and bgVis
        elseif clipTop and clipBottom then
            tVis = tVis and (currentY >= clipTop) and (currentY + self.TextSize <= clipBottom)
        end
        self.TitleText.Visible = tVis
        currentY = currentY + math.max(18, self.TextSize + 6)
    end
    if self.DescText then
        self.DescText.Position = Vector2.new(innerX, currentY)
        if MetricsModule and MetricsModule.Fit then
            self.DescText.Text = MetricsModule.Fit(self.Description or "", usableW, 11)
        end
        local dVis = self.Visible
        if boxed then
            dVis = dVis and bgVis
        elseif clipTop and clipBottom then
            dVis = dVis and (currentY >= clipTop) and (currentY + 12 <= clipBottom)
        end
        self.DescText.Visible = dVis
    end

    if self.Expandable then
        local hdrH = math.max(20, self.HeaderHeight or 22)
        local hdrVis = self.Visible
        if boxed then
            hdrVis = hdrVis and bgVis
        elseif clipTop and clipBottom then
            hdrVis = hdrVis and (innerY >= clipTop) and (innerY + 14 <= clipBottom)
        end
        self._headerRect = hdrVis and { X = innerX, Y = innerY, W = usableW, H = hdrH } or nil
        if self.ChevronImg then
            self.ChevronImg.Position = Vector2.new(innerX + usableW - 14, innerY + 3)
            self.ChevronImg.Visible = hdrVis
        end
    end

    if self.Expandable and not self.IsExpanded then
        for _, ctrl in ipairs(self.Controls) do
            if ctrl.SetVisible then ctrl:SetVisible(false) else ctrl.Visible = false end
        end
        return
    end

    local dynY = self.Padding + (self.HeaderHeight or 0)
    local groupRowY = {}
    for _, ctrl in ipairs(self.Controls) do
        if not is_ctrl_active(self, ctrl) then
            if ctrl.SetVisible then ctrl:SetVisible(false) else ctrl.Visible = false end
        else
            local ch = (ctrl.Size and ctrl.Size.Y) or 44
            local rowY
            local cX = innerX
            local cW = usableW
            if ctrl._group then
                if not groupRowY[ctrl._group] then
                    groupRowY[ctrl._group] = dynY
                    dynY = dynY + (ctrl._group.MaxH or ch) + self.RowGap
                end
                rowY = absPos.Y + groupRowY[ctrl._group]
                local visCount = 0
                local myIdx = 0
                for _, item in ipairs(ctrl._group.Items) do
                    if is_ctrl_active(self, item) then
                        visCount = visCount + 1
                        if item == ctrl then myIdx = visCount end
                    end
                end
                local count = math.max(1, visCount)
                local gap = ctrl._group.Gap or 8
                cW = math.max(60, math.floor((usableW - (count - 1) * gap) / count))
                cX = innerX + (math.max(1, myIdx) - 1) * (cW + gap)
            else
                rowY = absPos.Y + dynY
                dynY = dynY + ch + self.RowGap
            end
            local cPos = Vector2.new(cX, rowY)
            if ctrl.SetPosition then
                ctrl:SetPosition(cPos, Vector2.new(cW, ch))
            end
            local cVis = self.Visible
            if boxed then
                -- boxed section: control only visible when card intersects clip area
                cVis = cVis and bgVis
            elseif clipTop and clipBottom then
                -- non-boxed: each row must be fully within clip area (no slack)
                cVis = cVis and (rowY >= clipTop) and (rowY + ch <= clipBottom)
            end
            if ctrl.SetVisible then
                ctrl:SetVisible(cVis)
            else
                ctrl.Visible = cVis
            end
        end
    end
end

function ContentSection:SetPosition(basePos)
    if self.ParentTab and self.ParentTab.GetClipBounds then
        local win = self.Window or self.ParentTab.Window
        local clipTop, clipBottom = self.ParentTab:GetClipBounds(basePos, win and win.Size)
        self:Reflow(basePos, self.Size.X, self.ParentTab.ScrollY or 0, clipTop, clipBottom)
    else
        self:Reflow(basePos, self.Size.X, 0)
    end
end

function ContentSection:SetSize(newSize)
    local w = type(newSize) == "table" or type(newSize) == "userdata" and newSize.X or self.Size.X
    local win = self.Window or (self.ParentTab and self.ParentTab.Window)
    local basePos = win and win.Position or Vector2.new(0, 0)
    if self.ParentTab and self.ParentTab.GetClipBounds then
        local clipTop, clipBottom = self.ParentTab:GetClipBounds(basePos, win and win.Size)
        self:Reflow(basePos, w, self.ParentTab.ScrollY or 0, clipTop, clipBottom)
    else
        self:Reflow(basePos, w, 0)
    end
end

function ContentSection:SetVisible(visible)
    self.Visible = visible
    if not visible then
        if self.Background then self.Background.Visible = false end
        if self.Border then self.Border.Visible = false end
        if self.TitleText then self.TitleText.Visible = false end
        if self.DescText then self.DescText.Visible = false end
        if self.ChevronImg then self.ChevronImg.Visible = false end
        for _, ctrl in ipairs(self.Controls) do
            if ctrl.SetVisible then
                ctrl:SetVisible(false)
            else
                ctrl.Visible = false
            end
        end
        return
    end

    local win = self.Window or (self.ParentTab and self.ParentTab.Window)
    local basePos = win and win.Position or Vector2.new(0, 0)
    if self.ParentTab and self.ParentTab.GetClipBounds then
        local clipTop, clipBottom = self.ParentTab:GetClipBounds(basePos, win and win.Size)
        self:Reflow(basePos, self.Size.X, self.ParentTab.ScrollY or 0, clipTop, clipBottom)
    else
        self:Reflow(basePos, self.Size.X, 0)
    end
end

-- ============================================================================
-- Component Constructors (Dual Obsidian & WindUI Compatibility)
-- ============================================================================

local function link_control_state(self, ctrl, id, isOption)
    local win = self.Window or (self.ParentTab and self.ParentTab.Window)
    local lib = win and win.Env or _G.Library
    if lib then
        if isOption and lib.Options then
            rawset(lib.Options, id, ctrl)
            if lib._rawOptions then lib._rawOptions[id] = ctrl end
            if lib._initialDefaults and lib._initialDefaults.Options then
                lib._initialDefaults.Options[id] = ctrl.Value
            end
            if win and win.RegisteredIds and win.RegisteredIds.Options then
                win.RegisteredIds.Options[id] = true
            end
        elseif not isOption and lib.Toggles then
            rawset(lib.Toggles, id, ctrl)
            if lib._rawToggles then lib._rawToggles[id] = ctrl end
            if lib._initialDefaults and lib._initialDefaults.Toggles then
                lib._initialDefaults.Toggles[id] = ctrl.Value
            end
            if win and win.RegisteredIds and win.RegisteredIds.Toggles then
                win.RegisteredIds.Toggles[id] = true
            end
        end
    end
end

local function resolve_unique_id(self, prefix, cfg, isOption)
    local explicit = cfg.Flag or cfg.Id
    if explicit ~= nil then return explicit end
    local base = cfg.Title or cfg.Text or (prefix .. "_" .. tostring(#self.Controls + 1))
    local win = self.Window or (self.ParentTab and self.ParentTab.Window)
    local lib = win and win.Env or _G.Library
    local pool = lib and (isOption and lib._rawOptions or lib._rawToggles)
    if not pool or pool[base] == nil then
        return base
    end
    local idx = 2
    while pool[base .. "_" .. tostring(idx)] ~= nil do
        idx = idx + 1
    end
    return base .. "_" .. tostring(idx)
end

local function sync_lock_overlay(ctrl)
    local lo = ctrl._lockOverlay
    if not lo then return end
    local show = (ctrl.Locked == true) and (ctrl.Visible == true)
    local pos = ctrl.Position
    local size = ctrl.Size
    if pos and size then
        lo.Bg.Position = pos
        lo.Bg.Size = size
        local label = tostring(ctrl.LockedTitle or "Locked")
        lo.Text.Text = label
        local tw = (MetricsModule and MetricsModule.GetTextWidth and MetricsModule.GetTextWidth(label, 13)) or (#label * 6.5)
        local totalW = 16 + 6 + tw
        local sx = pos.X + math.floor((size.X - totalW) * 0.5)
        lo.Icon.Position = Vector2.new(sx, pos.Y + math.floor((size.Y - 16) * 0.5))
        lo.Text.Position = Vector2.new(sx + 22, pos.Y + math.floor((size.Y - 13) * 0.5))
    end
    lo.Bg.Visible = show
    lo.Icon.Visible = show and (lo.IconData ~= nil)
    lo.Text.Visible = show
end

local function ensure_lock_overlay(sec, ctrl)
    if ctrl._lockOverlay or not sec or not sec.Pool then return end
    local pool = sec.Pool
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    local bg = pool:Get("Square")
    bg.Color = Color3.new(0, 0, 0)
    bg.Transparency = 0.75
    bg.Filled = true
    bg.Corner = 8
    bg.ZIndex = 12
    bg.Visible = false
    sec:_register(bg)

    local ico = pool:Get("Image")
    ico.Size = Vector2.new(16, 16)
    ico.Transparency = 0.75
    ico.ZIndex = 13
    ico.Visible = false
    sec:_register(ico)

    local txt = pool:Get("Text")
    txt.Text = tostring(ctrl.LockedTitle or "Locked")
    txt.Font = fontUI
    txt.Outline = false
    txt.Size = 13
    txt.Color = Color3.fromRGB(255, 255, 255)
    txt.ZIndex = 13
    txt.Visible = false
    sec:_register(txt)

    local lo = { Bg = bg, Icon = ico, Text = txt, IconData = nil }
    ctrl._lockOverlay = lo

    if IconsModule and IconsModule.Get then
        local got = IconsModule.Get("lock", function(png)
            lo.IconData = png
            ico.Data = png
            sync_lock_overlay(ctrl)
        end)
        if got then
            lo.IconData = got
            ico.Data = got
        end
    end
end

local function register_control(self, ctrl, cfg)
    local la = self.LastAllocated
    if la then
        ctrl.RelX = la.RelX
        ctrl.RelY = la.RelY
        if la._group then
            ctrl._group = la._group
            ctrl._colIdx = la._colIdx
            table.insert(la._group.Items, ctrl)
        end
    end
    if type(cfg) == "table" and (cfg.Hidden == true or cfg.Visible == false) then
        ctrl._hidden = true
        if ctrl.SetVisible then ctrl:SetVisible(false) else ctrl.Visible = false end
    end
    function ctrl:SetHidden(hidden)
        local nextHidden = hidden == true
        if self._hidden == nextHidden then return end
        self._hidden = nextHidden
        if nextHidden then
            if self.SetVisible then self:SetVisible(false) else self.Visible = false end
        end
        local s = self.Section or self
        if s and s.ParentTab then s.ParentTab._layoutDirty = true end
    end
    function ctrl:Hide()
        self:SetHidden(true)
    end
    function ctrl:Show()
        self:SetHidden(false)
    end
    local origLock = ctrl.Lock
    function ctrl:Lock(title)
        if origLock then origLock(self, title) else
            self.Locked = true
            if title ~= nil then self.LockedTitle = tostring(title) end
        end
        ensure_lock_overlay(self.Section or self, self)
        sync_lock_overlay(self)
    end
    local origUnlock = ctrl.Unlock
    function ctrl:Unlock()
        if origUnlock then origUnlock(self) else
            self.Locked = false
        end
        sync_lock_overlay(self)
    end
    local origSetPos = ctrl.SetPosition
    if origSetPos then
        function ctrl:SetPosition(pos, size)
            origSetPos(self, pos, size)
            sync_lock_overlay(self)
        end
    end
    local origSetVis = ctrl.SetVisible
    if origSetVis then
        function ctrl:SetVisible(vis)
            origSetVis(self, vis)
            sync_lock_overlay(self)
        end
    end
    if not ctrl.SetTitle then
        function ctrl:SetTitle(title)
            self.Title = tostring(title or "")
            self.Text = self.Title
            if self.TitleText then self.TitleText.Text = self.Title end
            if self.Label then self.Label.Text = self.Title end
        end
    end
    if not ctrl.SetDesc then
        function ctrl:SetDesc(desc)
            self.Desc = desc ~= nil and tostring(desc) or ""
            if self.DescText then self.DescText.Text = self.Desc end
            if self.DescLabel then self.DescLabel.Text = self.Desc end
        end
    end
    if not ctrl.Destroy then
        function ctrl:Destroy()
            if self.SetVisible then self:SetVisible(false) else self.Visible = false end
        end
    end
    if type(cfg) == "table" then
        if cfg.LockedTitle ~= nil then ctrl.LockedTitle = tostring(cfg.LockedTitle) end
        if cfg.Tooltip ~= nil then ctrl.Tooltip = tostring(cfg.Tooltip) end
        if cfg.Locked == true then ctrl:Lock(cfg.LockedTitle) end
    end
    table.insert(self.Controls, ctrl)
    return ctrl
end

function ContentSection:AddToggle(id, config)
    assert(id ~= nil, "Toggle requires identifier!")
    local tog = register_control(self, ToggleModule.new(self, id, config), config)
    link_control_state(self, tog, id, false)
    return tog
end

function ContentSection:AddCheckbox(id, config)
    local cfg = type(config) == "table" and config or {}
    cfg.Type = "Checkbox"
    return self:AddToggle(id, cfg)
end

function ContentSection:Toggle(config)
    local cfg = config or {}
    local id = resolve_unique_id(self, "Toggle", cfg, false)
    return self:AddToggle(id, cfg)
end

function ContentSection:AddSlider(id, config)
    assert(id ~= nil, "Slider requires identifier!")
    local sld = register_control(self, SliderModule.new(self, id, config), config)
    link_control_state(self, sld, id, true)
    return sld
end

function ContentSection:Slider(config)
    local cfg = config or {}
    local id = resolve_unique_id(self, "Slider", cfg, true)
    return self:AddSlider(id, cfg)
end

function ContentSection:AddButton(config)
    return register_control(self, ButtonModule.new(self, config), config)
end

function ContentSection:Button(config)
    return self:AddButton(config)
end

function ContentSection:AddDropdown(id, config)
    assert(id ~= nil, "Dropdown requires identifier!")
    local drop = register_control(self, DropdownModule.new(self, id, config), config)
    link_control_state(self, drop, id, true)
    return drop
end

function ContentSection:Dropdown(config)
    local cfg = config or {}
    local id = resolve_unique_id(self, "Dropdown", cfg, true)
    return self:AddDropdown(id, cfg)
end

function ContentSection:AddInput(id, config)
    assert(id ~= nil, "Input requires identifier!")
    local inp = register_control(self, InputModule.new(self, id, config), config)
    link_control_state(self, inp, id, true)
    return inp
end

function ContentSection:AddTextbox(id, config)
    return self:AddInput(id, config)
end

function ContentSection:Input(config)
    local cfg = config or {}
    local id = resolve_unique_id(self, "Input", cfg, true)
    return self:AddInput(id, cfg)
end

function ContentSection:AddKeybind(id, config)
    assert(id ~= nil, "Keybind requires identifier!")
    local kb = register_control(self, KeybindModule.new(self, id, config), config)
    link_control_state(self, kb, id, true)
    return kb
end

function ContentSection:Keybind(config)
    local cfg = config or {}
    local id = resolve_unique_id(self, "Keybind", cfg, true)
    return self:AddKeybind(id, cfg)
end

function ContentSection:Paragraph(config)
    return register_control(self, ParagraphModule.new(self, config), config)
end

function ContentSection:AddLabel(text, config)
    local cfg = type(text) == "table" and text or (type(config) == "table" and config or { Title = tostring(text or "Label") })
    if type(text) == "string" and not cfg.Title then cfg.Title = text end
    return self:Paragraph(cfg)
end

function ContentSection:Code(config)
    return register_control(self, CodeModule.new(self, config), config)
end

function ContentSection:Image(config)
    return register_control(self, ImageModule.new(self, config), config)
end

function ContentSection:AddProgressBar(id, config)
    assert(id ~= nil, "ProgressBar requires identifier!")
    local pb = register_control(self, ProgressBarModule.new(self, id, config), config)
    link_control_state(self, pb, id, true)
    return pb
end

function ContentSection:ProgressBar(config)
    local cfg = config or {}
    local id = resolve_unique_id(self, "ProgressBar", cfg, true)
    return self:AddProgressBar(id, cfg)
end

function ContentSection:AddColorPicker(id, config)
    assert(id ~= nil, "Colorpicker requires identifier!")
    local cp = register_control(self, ColorpickerModule.new(self, id, config), config)
    link_control_state(self, cp, id, true)
    return cp
end
ContentSection.AddColorpicker = ContentSection.AddColorPicker

function ContentSection:Colorpicker(config)
    local cfg = config or {}
    local id = resolve_unique_id(self, "Colorpicker", cfg, true)
    return self:AddColorPicker(id, cfg)
end

function ContentSection:Divider()
    self.CursorY = self.CursorY + 8
    self:_syncTabCursor()
    return self
end

function ContentSection:Space(config)
    if self._activeGroup then return self end
    local height = 6
    if type(config) == "number" then
        height = math.max(2, config)
    elseif type(config) == "table" then
        if config.Height then
            height = math.max(2, tonumber(config.Height) or 6)
        elseif config.Columns then
            height = math.max(2, (tonumber(config.Columns) or 1) * 6)
        end
    end
    self.CursorY = self.CursorY + height
    self:_syncTabCursor()
end

function ContentSection:Section(config)
    if self.ParentTab and self.ParentTab.Section then
        return self.ParentTab:Section(config)
    end
    return self
end

function ContentSection:Group(config)
    local cfg = type(config) == "table" and config or {}
    local grp = {
        ParentSection = self,
        ParentTab = self.ParentTab,
        Items = {},
        Sections = {},
        RowRelY = nil,
        MaxH = 0,
        Gap = cfg.Gap or 8,
    }

    local function with_group(methodName, ...)
        self._activeGroup = grp
        local ok, res = pcall(self[methodName], self, ...)
        self._activeGroup = nil
        assert(ok, res)
        return res
    end

    for _, m in ipairs({
        "Toggle", "AddToggle", "AddCheckbox", "Button", "AddButton",
        "Slider", "AddSlider", "Dropdown", "AddDropdown",
        "Input", "AddInput", "Keybind", "AddKeybind",
        "Paragraph", "Code", "Image", "ProgressBar", "AddProgressBar", "Colorpicker", "AddColorPicker",
    }) do
        grp[m] = function(_, ...)
            return with_group(m, ...)
        end
    end

    function grp:Space() end

    function grp:Section(secCfg)
        local c = type(secCfg) == "table" and secCfg or { Title = tostring(secCfg or "Section") }
        c._group = grp
        local sub = self.ParentTab and self.ParentTab:Section(c) or self.ParentSection:Section(c)
        table.insert(grp.Sections, sub)
        return sub
    end

    return grp
end

function ContentSection:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self:SetVisible(false)

    for _, ctrl in ipairs(self.Controls) do
        if ctrl.Destroy then
            ctrl:Destroy()
        end
    end

    self.Drawings = {}
    self._drawings = {}
    self.Controls = {}
end

return ContentSection

end)()

-- ============================================================================
-- MODULE: Layout/Tab.lua
-- ============================================================================
TabModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Layout/Tab.lua
-- Child navigation tab management, colored badge squares with white PNG icons, responsive resize, clipping & scroll.

local PoolModule = Pool or PoolModule
local MetaModule = Meta or MetaModule
local GeometryModule = Geometry or GeometryModule
local MetricsModule = Metrics or MetricsModule
local ThemeModule = Theme or ThemeModule
local ContentSectionModule = ContentSection or ContentSectionModule
local AnimationsModule = Animations or AnimationsModule

local IconsModule = Icons
if not IconsModule then
    local ok, mod = pcall(function() return IconsModule end)
    if ok then IconsModule = mod end
end

local Tab = {}
Tab.__index = Tab

local function get_theme_color(token, default)
    return ThemeModule.Get(token, default)
end

local function get_tab_badge_color(title, icon, customColor)
    if customColor then return customColor end
    local lower = (title or ""):lower()
    local ic = (icon or ""):lower()
    if lower:find("toggle") or ic:find("check") or ic:find("toggle") then
        return Color3.fromRGB(16, 197, 80)
    elseif lower:find("button") or ic:find("cursor") or ic:find("button") then
        return Color3.fromRGB(37, 122, 247)
    elseif lower:find("input") or ic:find("edit") or ic:find("input") then
        return Color3.fromRGB(119, 117, 242)
    elseif lower:find("slider") or ic:find("slider") or ic:find("transfer") then
        return Color3.fromRGB(16, 197, 80)
    elseif lower:find("dropdown") or ic:find("menu") or ic:find("list") then
        return Color3.fromRGB(236, 162, 1)
    elseif lower:find("settings") or ic:find("gear") or ic:find("settings") then
        return Color3.fromRGB(100, 106, 128)
    else
        return Color3.fromRGB(131, 136, 158)
    end
end

function Tab.new(config, window, parentSection)
    local cfg = type(config) == "table" and config or { Title = tostring(config or "Tab") }
    local win = window or (parentSection and parentSection.Sidebar and parentSection.Sidebar.Window)
    local pool = (win and win.Pool) or (PoolModule and PoolModule.new(100, MetaModule))
    local topH = win and win.HeaderHeight or 44

    local self = setmetatable({
        Type = "Tab",
        Title = cfg.Title or "Tab",
        Icon = cfg.Icon or "box",
        IconColor = cfg.IconColor,
        IconShape = cfg.IconShape,
        Badge = cfg.Badge,
        BadgeColor = cfg.BadgeColor,

        Window = win,
        ParentSection = parentSection,
        Pool = pool,
        Theme = win and win.Theme,

        -- State flags
        IsActive = false,
        IsHovered = false,
        HoverAnim = 0,
        SidebarVisible = true,
        FilteredOut = false,
        Visible = true,
        Destroyed = false,

        -- Geometry (relative to window)
        RelX = 10,
        RelY = 0,
        Width = (win and win.SidebarWidth or 190) - 20,
        Height = 32,
        Rounding = 8,
        ContentCursorY = topH + 14,
        ScrollY = 0,
        MaxScrollY = 0,

        -- Sidebar Drawing Primitives
        Capsule = nil,
        IconBadge = nil,
        TabIcon = nil,
        IconVisual = nil,
        TitleVisual = nil,
        BadgeBg = nil,
        BadgeText = nil,

        -- Aliases for Test Compatibility
        NavButton = nil,
        TabButton = nil,
        TabText = nil,

        -- Content & Collections
        Sections = {},
        Cards = nil,
        Controls = {},
        Drawings = {},
        _drawings = {},
    }, Tab)

    self.Cards = self.Sections
    self:_initSidebarDrawings()
    return self
end

function Tab:_initSidebarDrawings()
    local pool = self.Pool
    if not pool then return end
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    local cap = pool:Get("Square")
    if MetaModule then
        MetaModule.SetValue(cap, "Filled", true)
        MetaModule.SetValue(cap, "Corner", self.Rounding)
        MetaModule.SetValue(cap, "ZIndex", 4)
        MetaModule.SetVisible(cap, false)
    else
        cap.Filled = true
        cap.Corner = self.Rounding
        cap.ZIndex = 4
        cap.Visible = false
    end
    self.Capsule = cap

    if self.IconShape and self.IconColor then
        local badgeCol = get_tab_badge_color(self.Title, self.Icon, self.IconColor)
        local badgeSquare = pool:Get("Square")
        badgeSquare.Size = Vector2.new(22, 22)
        badgeSquare.Corner = (self.IconShape == "Circle") and 11 or 6
        badgeSquare.Filled = true
        badgeSquare.Color = badgeCol
        badgeSquare.ZIndex = 5
        badgeSquare.Visible = false
        self.IconBadge = badgeSquare
    end

    local icon = pool:Get("Image")
    icon.Size = Vector2.new(14, 14)
    icon.Transparency = 1.0
    icon.ZIndex = 6
    icon.Visible = false
    self.TabIcon = icon
    self.IconVisual = icon

    if IconsModule and IconsModule.Get and self.Icon then
        local forceWhite = (self.IconBadge ~= nil)
        IconsModule.Get(self.Icon, function(pngData)
            if self.TabIcon and pngData then
                self.TabIcon.Data = pngData
            end
        end, forceWhite)
    end

    local txt = pool:Get("Text")
    txt.Size = 13
    txt.Font = fontUI
    txt.Outline = false
    txt.Color = get_theme_color("Text.Secondary", Color3.fromRGB(161, 161, 170))
    txt.ZIndex = 5
    txt.Text = tostring(self.Title)
    self.TitleVisual = txt
    self.NavButton = txt
    self.TabButton = txt
    self.TabText = txt

    if self.Badge then
        local bBg = pool:Get("Square")
        bBg.Filled = true
        bBg.Corner = 3
        bBg.Color = self.BadgeColor or get_theme_color("Accent.Blue", Color3.fromRGB(0, 145, 255))
        bBg.ZIndex = 5
        self.BadgeBg = bBg

        local bTxt = pool:Get("Text")
        bTxt.Size = 11
        bTxt.Font = fontUI
        bTxt.Outline = false
        bTxt.Color = Color3.fromRGB(255, 255, 255)
        bTxt.ZIndex = 6
        local fmtBadge = MetricsModule and MetricsModule.FormatBadge and MetricsModule.FormatBadge(self.Badge) or ("[" .. tostring(self.Badge) .. "]")
        bTxt.Text = fmtBadge
        self.BadgeText = bTxt
    end

    local win = self.Window
    if win and win._drawings then
        table.insert(win._drawings, self.Capsule)
        if self.IconBadge then table.insert(win._drawings, self.IconBadge) end
        table.insert(win._drawings, self.TabIcon)
        table.insert(win._drawings, self.TitleVisual)
        if self.BadgeBg then table.insert(win._drawings, self.BadgeBg) end
        if self.BadgeText then table.insert(win._drawings, self.BadgeText) end
    end
end

function Tab:UpdateVisualState()
    if not self.SidebarVisible then return end
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    if self.IsActive then
        local activeBg = get_theme_color("Tab.ActiveBg", Color3.fromRGB(35, 35, 41))
        local titleCol = get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))
        if self.Capsule then
            self.Capsule.Color = activeBg
            self.Capsule.Transparency = 1.0
            self.Capsule.Visible = self.SidebarVisible ~= false
        end
        if self.TitleVisual then
            self.TitleVisual.Color = titleCol
            self.TitleVisual.Font = fontUI
            self.TitleVisual.Outline = false
        end
        if self.TabIcon then
            self.TabIcon.Transparency = 1.0
        end
    elseif self.IsHovered or (self.HoverAnim or 0) > 0.02 then
        local hoverBg = get_theme_color("Tab.HoverBg", Color3.fromRGB(26, 26, 31))
        local titleCol = get_theme_color("Text.Title", Color3.fromRGB(240, 240, 245))
        if self.Capsule then
            self.Capsule.Color = hoverBg
            self.Capsule.Transparency = self.HoverAnim or 1.0
            self.Capsule.Visible = self.SidebarVisible ~= false
        end
        if self.TitleVisual then
            self.TitleVisual.Color = titleCol
            self.TitleVisual.Font = fontUI
            self.TitleVisual.Outline = false
        end
        if self.TabIcon then
            self.TabIcon.Transparency = 0.92
        end
    else
        local subCol = get_theme_color("Text.Secondary", Color3.fromRGB(161, 161, 170))
        if self.Capsule then
            self.Capsule.Visible = false
        end
        if self.TitleVisual then
            self.TitleVisual.Color = subCol
            self.TitleVisual.Font = fontUI
            self.TitleVisual.Outline = false
        end
        if self.TabIcon then
            self.TabIcon.Transparency = 0.85
        end
    end
end

function Tab:SetHovered(hovered)
    if self.IsHovered ~= hovered then
        self.IsHovered = hovered
        AnimationsModule.Tween("tab_hover_" .. tostring(self), self.HoverAnim or 0, hovered and 1 or 0, 22, function(v)
            self.HoverAnim = v
            self:UpdateVisualState()
        end)
    end
end

-- IMPORTANT: Always update coordinates unconditionally even while minimized or filtered!
function Tab:UpdateSidebarPositions(winPos)
    local tx = winPos.X + self.RelX
    local ty = winPos.Y + self.RelY

    if self.Capsule then
        if MetaModule then
            MetaModule.SetPosition(self.Capsule, tx, ty)
            MetaModule.SetSize(self.Capsule, self.Width, self.Height)
        else
            self.Capsule.Position = Vector2.new(tx, ty)
            self.Capsule.Size = Vector2.new(self.Width, self.Height)
        end
    end

    if self.IconBadge then
        self.IconBadge.Position = Vector2.new(tx + 6, ty + 5)
    end

    if self.TabIcon then
        if MetaModule then
            MetaModule.SetPosition(self.TabIcon, tx + 10, ty + 9)
        else
            self.TabIcon.Position = Vector2.new(tx + 10, ty + 9)
        end
    end

    if self.TitleVisual then
        local titleX = tx + 36
        local fitted = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(tostring(self.Title), self.Width - 44, 13) or tostring(self.Title)
        if MetaModule then
            MetaModule.SetText(self.TitleVisual, fitted)
            MetaModule.SetPosition(self.TitleVisual, titleX, ty + 9)
        else
            self.TitleVisual.Text = fitted
            self.TitleVisual.Position = Vector2.new(titleX, ty + 9)
        end
    end

    if self.BadgeBg and self.BadgeText then
        local bStr = self.BadgeText.Text
        local bW = MetricsModule and MetricsModule.GetTextWidth and (MetricsModule.GetTextWidth(bStr, 11) + 8) or (#bStr * 6 + 8)
        local bX = tx + self.Width - bW - 6
        local bY = ty + 8
        self.BadgeBg.Position = Vector2.new(bX, bY)
        self.BadgeBg.Size = Vector2.new(bW, 16)
        self.BadgeText.Position = Vector2.new(bX + 4, bY + 2)
    end

    if self.SidebarVisible then
        self:UpdateVisualState()
    end
end

function Tab:SetSidebarVisible(vis)
    local effective = vis and (not self.FilteredOut)
    self.SidebarVisible = effective
    if not effective then
        if self.Capsule then self.Capsule.Visible = false end
        if self.IconBadge then self.IconBadge.Visible = false end
        if self.TabIcon then self.TabIcon.Visible = false end
        if self.TitleVisual then self.TitleVisual.Visible = false end
        if self.BadgeBg then self.BadgeBg.Visible = false end
        if self.BadgeText then self.BadgeText.Visible = false end
    else
        self:UpdateVisualState()
        if self.IconBadge then self.IconBadge.Visible = true end
        if self.TabIcon then self.TabIcon.Visible = true end
        if self.TitleVisual then self.TitleVisual.Visible = true end
        if self.BadgeBg then self.BadgeBg.Visible = true end
        if self.BadgeText then self.BadgeText.Visible = true end
    end
end

function Tab:GetClipBounds(winPos, winSize)
    local win = self.Window
    local wp = winPos or (win and win.Position) or Vector2.new(0, 0)
    local ws = winSize or (win and win.Size) or Vector2.new(620, 440)
    local topH = (win and win.HeaderHeight) or 44
    -- Align exactly with MainPanelBg bounds: top=py+headerH, bottom=py+sy-8
    local clipTop = wp.Y + topH
    local clipBottom = wp.Y + ws.Y - 8
    return clipTop, clipBottom
end

function Tab:UpdateLayout(winPos, winSize)
    local win = self.Window
    local wp = winPos or (win and win.Position) or Vector2.new(0, 0)
    local ws = winSize or (win and win.Size) or Vector2.new(620, 440)
    local sbW = (win and win.SidebarWidth) or 190
    local topH = (win and win.HeaderHeight) or 44
    local contentX = sbW + 16
    local contentW = math.max(180, ws.X - sbW - 48)

    local startY = topH + 14
    local curY = startY
    local idx = 1
    while idx <= #self.Sections do
        local sec = self.Sections[idx]
        if sec._group then
            local g = sec._group
            local rowSecs = {}
            while idx <= #self.Sections and self.Sections[idx]._group == g do
                table.insert(rowSecs, self.Sections[idx])
                idx = idx + 1
            end
            local count = #rowSecs
            local gap = 10
            local colW = math.max(120, math.floor((contentW - (count - 1) * gap) / count))
            local maxSecH = 0
            for gi, rSec in ipairs(rowSecs) do
                rSec.Position = Vector2.new(contentX + (gi - 1) * (colW + gap), curY)
                rSec._groupWidth = colW
                local secH = rSec.GetDynamicHeight and rSec:GetDynamicHeight(colW)
                    or (rSec.Box and math.max(40, (rSec.Padding * 2) + rSec.CursorY) or math.max(0, rSec.CursorY))
                if secH > maxSecH then maxSecH = secH end
            end
            curY = curY + maxSecH + 10
        else
            sec.Position = Vector2.new(contentX, curY)
            sec._groupWidth = nil
            local secH = sec.GetDynamicHeight and sec:GetDynamicHeight(contentW)
                or (sec.Box and math.max(40, (sec.Padding * 2) + sec.CursorY) or math.max(0, sec.CursorY))
            curY = curY + secH + (sec.Box and 10 or 4)
            idx = idx + 1
        end
    end
    self.ContentCursorY = curY

    local clipTop, clipBottom = self:GetClipBounds(wp, ws)
    local panelH = math.max(60, clipBottom - clipTop)
    local totalContentH = math.max(0, curY - startY)
    self.MaxScrollY = math.max(0, totalContentH - panelH + 10)
    self.ScrollY = math.clamp(self.ScrollY or 0, 0, self.MaxScrollY)

    for _, sec in ipairs(self.Sections) do
        sec:Reflow(wp, sec._groupWidth or contentW, self.ScrollY, clipTop, clipBottom)
    end
end

function Tab:UpdatePosition(contentPos)
    local win = self.Window
    self:UpdateLayout(contentPos, win and win.Size)
end

function Tab:UpdateSize(winSize)
    local win = self.Window
    self:UpdateLayout(win and win.Position, winSize)
end

function Tab:Scroll(deltaY)
    if self.MaxScrollY <= 0 then
        self.ScrollY = 0
        return
    end
    local nextScroll = math.clamp((self.ScrollY or 0) + deltaY, 0, self.MaxScrollY)
    if nextScroll ~= self.ScrollY then
        self.ScrollY = nextScroll
        self:UpdateLayout()
    end
end

function Tab:RegisterDrawing(drawingObj)
    if not drawingObj then return end
    table.insert(self.Drawings, drawingObj)
    table.insert(self._drawings, drawingObj)
    return drawingObj
end

function Tab:RegisterControl(control)
    if not control then return end
    table.insert(self.Controls, control)
    return control
end

function Tab:Section(config)
    assert(ContentSectionModule, "ContentSection module not available!")
    local sec = ContentSectionModule.new(config, self, self.Window)
    if type(config) == "table" and config._group then
        sec._group = config._group
    end
    table.insert(self.Sections, sec)
    self._layoutDirty = true
    return sec
end

function Tab:AddSection(config)
    return self:Section(config)
end

function Tab:Card(config)
    local cfg = type(config) == "table" and config or { Title = tostring(config or "Card") }
    cfg._forceBox = true
    return self:Section(cfg)
end

function Tab:AddCard(config)
    return self:Card(config)
end

function Tab:AddLeftGroupbox(title)
    local cfg = type(title) == "table" and title or { Title = tostring(title or "Section") }
    cfg._forceBox = true
    return self:Section(cfg)
end

function Tab:AddRightGroupbox(title)
    local cfg = type(title) == "table" and title or { Title = tostring(title or "Section") }
    cfg._forceBox = true
    return self:Section(cfg)
end

function Tab:GetDefaultSection()
    if #self.Sections > 0 then
        local last = self.Sections[#self.Sections]
        if not last._group and not last.Box then
            return last
        end
    end
    return self:Section({ Title = "" })
end

for _, methodName in ipairs({
    "Toggle", "AddToggle", "AddCheckbox",
    "Slider", "AddSlider",
    "Button", "AddButton",
    "Dropdown", "AddDropdown",
    "Input", "AddInput",
    "Keybind", "AddKeybind",
    "Group", "Paragraph", "Code", "ProgressBar", "AddProgressBar",
    "Colorpicker", "AddColorPicker",
    "Image", "Divider", "Space",
}) do
    Tab[methodName] = function(self, ...)
        local sec = self:GetDefaultSection()
        return sec[methodName](sec, ...)
    end
end

function Tab:Show(windowPos)
    self.IsActive = true
    self:UpdateVisualState()

    -- IMPORTANT: Do NOT blindly override self.Drawings[i].Visible = true!
    -- Sections and controls own their exact visual state (unchecked checkboxes, clipped overflow, unboxed cards).
    for _, sec in ipairs(self.Sections) do
        sec.Visible = true
    end
    self:UpdateLayout(windowPos, self.Window and self.Window.Size)
end

function Tab:Hide()
    self.IsActive = false
    self:UpdateVisualState()

    for _, sec in ipairs(self.Sections) do
        sec:SetVisible(false)
        for _, c in ipairs(sec.Controls or {}) do
            if c.Focused and c.Blur then c:Blur(false) end
            if c.IsOpen and c.Close then c:Close() end
        end
    end
end

function Tab:Select()
    if self.Window and self.Window.SelectTab then
        self.Window:SelectTab(self)
    end
end

function Tab:SetVisible(visible)
    self.Visible = visible
    self:SetSidebarVisible(visible)
    if visible and self.IsActive then
        self:Show()
    else
        self:Hide()
    end
end

function Tab:UpdateTheme(t)
    self:UpdateVisualState()
    local cardBg = t.Card or get_theme_color("Card.Background", Color3.fromRGB(24, 24, 29))
    local borderCol = t.Border or get_theme_color("Card.Border", Color3.fromRGB(38, 38, 45))
    local elemBg = t.ElementBackground or get_theme_color("ElementBackground", Color3.fromRGB(42, 42, 44))
    local ctrlBg = t["Control.Background"] or get_theme_color("Control.Background", Color3.fromRGB(48, 48, 54))
    local txtTitle = t.Text or get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))
    local txtSub = t["Text.Secondary"] or t.SubText or get_theme_color("Text.Secondary", Color3.fromRGB(161, 161, 170))
    local txtMuted = t["Text.Muted"] or get_theme_color("Text.Muted", Color3.fromRGB(120, 120, 130))
    local accentBlue = t["Accent.Blue"] or t.Accent or get_theme_color("Accent.Blue", Color3.fromRGB(0, 145, 255))
    local sldTrack = t["Slider.TrackBg"] or ctrlBg

    for _, sec in ipairs(self.Sections) do
        -- Boxed collapsible sections use Text.Title at near-full transparency (WindUI SectionBox style)
        if sec.Background then sec.Background.Color = txtTitle end
        if sec.Border then sec.Border.Color = txtTitle end
        if sec.TitleText then sec.TitleText.Color = txtTitle end
        if sec.DescText then sec.DescText.Color = txtSub end

        for _, ctrl in ipairs(sec.Controls or {}) do
            if ctrl.RowBg then ctrl.RowBg.Color = elemBg end
            if ctrl.Visual and not ctrl.CustomColor then
                ctrl.Visual.Color = ctrl.Code and (t.Background or get_theme_color("Window.Background", Color3.fromRGB(14, 14, 18))) or elemBg
            end
            if ctrl.HeaderBg then ctrl.HeaderBg.Color = ctrlBg end
            if ctrl.CopyBg then ctrl.CopyBg.Color = elemBg end
            if ctrl.CopyText then ctrl.CopyText.Color = txtTitle end
            if ctrl.Border then ctrl.Border.Color = borderCol end
            if ctrl.SwatchBorder then ctrl.SwatchBorder.Color = borderCol end
            if ctrl.PopupBg then ctrl.PopupBg.Color = cardBg end
            if ctrl.PopupBorder then ctrl.PopupBorder.Color = borderCol end
            if ctrl.PopupHoverBg then ctrl.PopupHoverBg.Color = get_theme_color("Tab.ActiveBg", ctrlBg) end
            if ctrl.SearchBg then ctrl.SearchBg.Color = elemBg end
            if ctrl.SearchText then
                ctrl.SearchText.Color = (ctrl.SearchQuery and ctrl.SearchQuery ~= "") and txtTitle or txtSub
            end
            if ctrl.PopupDrawings then
                if ctrl.PopupDrawings.Bg then ctrl.PopupDrawings.Bg.Color = cardBg end
                if ctrl.PopupDrawings.Border then ctrl.PopupDrawings.Border.Color = borderCol end
                if ctrl.PopupDrawings.HexText then ctrl.PopupDrawings.HexText.Color = txtTitle end
            end
            if ctrl.ButtonSlots then
                for _, bSlot in ipairs(ctrl.ButtonSlots) do
                    if bSlot.Bg then bSlot.Bg.Color = ctrlBg end
                    if bSlot.Text then bSlot.Text.Color = txtTitle end
                end
            end
            if ctrl.Label then ctrl.Label.Color = ctrl.Locked and txtMuted or txtTitle end
            if ctrl.TitleText then
                ctrl.TitleText.Color = ctrl.Locked and txtMuted or (ctrl.Code and txtSub or txtTitle)
            end
            if ctrl.DescLabel then ctrl.DescLabel.Color = txtSub end
            if ctrl.DescText then ctrl.DescText.Color = txtSub end
            if ctrl.LineDrawings then
                for _, ln in ipairs(ctrl.LineDrawings) do
                    ln.Color = ctrl.Code and txtTitle or txtSub
                end
            end
            if ctrl.Box then ctrl.Box.Color = ctrlBg end
            if ctrl.BoxBorder then ctrl.BoxBorder.Color = ctrl.Focused and accentBlue or borderCol end
            if ctrl.ValueBadge then ctrl.ValueBadge.Color = txtSub end
            if ctrl.Badge then ctrl.Badge.Color = txtSub end
            if ctrl.ValueText then ctrl.ValueText.Color = txtSub end
            if ctrl.BadgeBg then ctrl.BadgeBg.Color = ctrlBg end
            if ctrl.BadgeText and not ctrl.Capturing then ctrl.BadgeText.Color = txtSub end
            if ctrl.KeyPicker then
                local kp = ctrl.KeyPicker
                if kp.BadgeBg then kp.BadgeBg.Color = ctrlBg end
                if kp.BadgeText and not kp.Capturing then kp.BadgeText.Color = txtSub end
                if kp.ModeMenu then
                    if kp.ModeMenu.Bg then kp.ModeMenu.Bg.Color = cardBg end
                    if kp.ModeMenu.Border then kp.ModeMenu.Border.Color = borderCol end
                end
            end
            if ctrl.InputText and ctrl._refreshDisplay then ctrl:_refreshDisplay() end
            if ctrl.Opened and ctrl._layoutPopup then ctrl:_layoutPopup() end
            if ctrl.Track then
                if ctrl._applyAnimVisual then
                    ctrl:_applyAnimVisual(ctrl.AnimProgress or (ctrl.Value and 1 or 0))
                else
                    ctrl.Track.Color = sldTrack
                end
            end
            if ctrl.FillBar and not ctrl._applyAnimVisual then
                ctrl.FillBar.Color = accentBlue
            end
        end
    end
end

function Tab:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self:SetVisible(false)

    for _, sec in ipairs(self.Sections) do
        if sec.Destroy then sec:Destroy() end
    end

    self.Drawings = {}
    self._drawings = {}
    self.Sections = {}
    self.Cards = {}
    self.Controls = {}
end

return Tab

end)()

-- ============================================================================
-- MODULE: Layout/ProfileCard.lua
-- ============================================================================
ProfileCardModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Layout/ProfileCard.lua
-- WindUI-style sidebar footer player card with click-to-open compact profile info menu.

local PoolModule = Pool or PoolModule
local MetricsModule = Metrics or MetricsModule
local ThemeModule = Theme or ThemeModule
local AnimationsModule = Animations or AnimationsModule

local ProfileCard = {}
ProfileCard.__index = ProfileCard

local function get_theme_color(token, default)
    return ThemeModule.Get(token, default)
end

local function format_uptime(sec)
    sec = math.max(0, math.floor(sec or 0))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function resolve_local_player()
    if not (game and game.GetService) then
        return "Player", "Player", 0
    end
    local lp = game:GetService("Players").LocalPlayer
    if not lp then
        return "Player", "Player", 0
    end
    local uname = tostring(lp.Name or "Player")
    local dname = tostring(lp.DisplayName or uname)
    local uid = tonumber(lp.UserId) or 0
    return dname, uname, uid
end

function ProfileCard.new(sidebar, config)
    local cfg = type(config) == "table" and config or {}
    local enabled = (config ~= false) and (cfg.Enabled ~= false)
    local dname, uname, uid = resolve_local_player()

    local self = setmetatable({
        Sidebar = sidebar,
        Window = sidebar and sidebar.Window,
        Pool = sidebar and sidebar.Pool or PoolModule,
        Enabled = enabled,
        Open = false,
        OpenAnim = 0,
        Hovered = false,
        HoverAnim = 0,
        Height = 48,

        DisplayName = cfg.DisplayName or dname,
        Username = cfg.Username or uname,
        UserId = cfg.UserId or uid,
        Tag = cfg.Tag,
        Fields = type(cfg.Fields) == "table" and cfg.Fields or {},
        ShowCreated = cfg.ShowCreated ~= false,
        ShowUptime = cfg.ShowUptime ~= false,
        ShowFPS = cfg.ShowFPS ~= false,
        ShowDate = cfg.ShowDate ~= false,
        ShowTime = cfg.ShowTime ~= false,
        Callback = type(cfg.Callback) == "function" and cfg.Callback or nil,

        CreatedDate = cfg.CreatedDate or (uid > 0 and "Loading..." or "N/A"),
        StartClock = os.clock(),
        LastTickSec = -1,
        FpsFrames = 0,
        FpsAccum = 0,
        CurrentFPS = 0,
        AvatarPng = nil,

        CardBg = nil,
        AvatarBg = nil,
        AvatarInitial = nil,
        AvatarImg = nil,
        NameText = nil,
        HandleText = nil,

        PopBg = nil,
        PopBorder = nil,
        PopName = nil,
        PopHandle = nil,
        PopDivider = nil,
        PopTagBg = nil,
        PopTagText = nil,
        PopRows = {},
    }, ProfileCard)

    if self.Enabled then
        self:_initDrawings()
        self:_fetchRemoteMeta()
    end

    return self
end

function ProfileCard:_reg(obj)
    if self.Window and self.Window._drawings and obj then
        table.insert(self.Window._drawings, obj)
    end
end

function ProfileCard:_initDrawings()
    local pool = self.Pool
    if not pool then return end
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    local bg = pool:Get("Square")
    bg.Filled = true
    bg.Corner = 8
    bg.ZIndex = 4
    bg.Visible = false
    self.CardBg = bg
    self:_reg(bg)

    local avBg = pool:Get("Square")
    avBg.Size = Vector2.new(32, 32)
    avBg.Filled = true
    avBg.Corner = 8
    avBg.ZIndex = 5
    avBg.Visible = true
    self.AvatarBg = avBg
    self:_reg(avBg)

    local avInit = pool:Get("Text")
    avInit.Size = 14
    avInit.Font = fontUI
    avInit.Text = string.upper(string.sub(self.DisplayName, 1, 1))
    avInit.ZIndex = 6
    avInit.Visible = true
    self.AvatarInitial = avInit
    self:_reg(avInit)

    local avImg = pool:Get("Image")
    avImg.Size = Vector2.new(32, 32)
    avImg.ZIndex = 7
    avImg.Visible = false
    self.AvatarImg = avImg
    self:_reg(avImg)

    local nameTxt = pool:Get("Text")
    nameTxt.Size = 13
    nameTxt.Font = fontUI
    nameTxt.ZIndex = 6
    nameTxt.Visible = true
    self.NameText = nameTxt
    self:_reg(nameTxt)

    local handleTxt = pool:Get("Text")
    handleTxt.Size = 11
    handleTxt.Font = fontUI
    handleTxt.ZIndex = 6
    handleTxt.Visible = true
    self.HandleText = handleTxt
    self:_reg(handleTxt)

    -- Compact Profile Info Menu (DisplayName, @Username, optional Tag, Divider, and Info Rows — no duplicate avatar)
    local popBg = pool:Get("Square")
    popBg.Filled = true
    popBg.Corner = 10
    popBg.ZIndex = 30
    popBg.Visible = false
    self.PopBg = popBg
    self:_reg(popBg)

    local popBorder = pool:Get("Square")
    popBorder.Filled = false
    popBorder.Thickness = 1
    popBorder.Corner = 10
    popBorder.ZIndex = 31
    popBorder.Visible = false
    self.PopBorder = popBorder
    self:_reg(popBorder)

    local pName = pool:Get("Text")
    pName.Size = 13
    pName.Font = fontUI
    pName.ZIndex = 32
    pName.Visible = false
    self.PopName = pName
    self:_reg(pName)

    local pHandle = pool:Get("Text")
    pHandle.Size = 11
    pHandle.Font = fontUI
    pHandle.ZIndex = 32
    pHandle.Visible = false
    self.PopHandle = pHandle
    self:_reg(pHandle)

    local pTagBg = pool:Get("Square")
    pTagBg.Filled = true
    pTagBg.Corner = 5
    pTagBg.ZIndex = 31
    pTagBg.Visible = false
    self.PopTagBg = pTagBg
    self:_reg(pTagBg)

    local pTagTxt = pool:Get("Text")
    pTagTxt.Size = 10
    pTagTxt.Font = fontUI
    pTagTxt.ZIndex = 32
    pTagTxt.Visible = false
    self.PopTagText = pTagTxt
    self:_reg(pTagTxt)

    local pDiv = pool:Get("Square")
    pDiv.Filled = true
    pDiv.ZIndex = 31
    pDiv.Visible = false
    self.PopDivider = pDiv
    self:_reg(pDiv)

    self:_rebuildRows()
    self:UpdateTheme(ThemeModule.GetCurrent and ThemeModule.GetCurrent() or {})
end

function ProfileCard:_buildRowSpecs()
    local rows = {}
    if self.ShowCreated then
        table.insert(rows, { Key = "created", Label = "Created", Value = tostring(self.CreatedDate) })
    end
    if self.ShowDate then
        table.insert(rows, { Key = "date", Label = "Date", Value = os.date("%d/%m/%Y") })
    end
    if self.ShowTime then
        table.insert(rows, { Key = "time", Label = "Time", Value = os.date("%H:%M:%S") })
    end
    if self.ShowUptime then
        table.insert(rows, { Key = "uptime", Label = "Uptime", Value = format_uptime(os.clock() - self.StartClock) })
    end
    if self.ShowFPS then
        table.insert(rows, { Key = "fps", Label = "FPS", Value = tostring(self.CurrentFPS) })
    end
    for _, f in ipairs(self.Fields) do
        if f.Label then
            table.insert(rows, { Key = "custom", Label = tostring(f.Label), Value = tostring(f.Value or "") })
        end
    end
    return rows
end

function ProfileCard:_rebuildRows()
    local pool = self.Pool
    if not pool then return end
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    for _, r in ipairs(self.PopRows) do
        if r.LabelDraw then r.LabelDraw.Visible = false end
        if r.ValueDraw then r.ValueDraw.Visible = false end
    end
    self.PopRows = {}

    local specs = self:_buildRowSpecs()
    for _, spec in ipairs(specs) do
        local lDraw = pool:Get("Text")
        lDraw.Size = 11
        lDraw.Font = fontUI
        lDraw.Text = spec.Label
        lDraw.ZIndex = 32
        lDraw.Visible = false
        self:_reg(lDraw)

        local vDraw = pool:Get("Text")
        vDraw.Size = 11
        vDraw.Font = fontUI
        vDraw.Text = spec.Value
        vDraw.ZIndex = 32
        vDraw.Visible = false
        self:_reg(vDraw)

        table.insert(self.PopRows, {
            Key = spec.Key,
            Label = spec.Label,
            Value = spec.Value,
            LabelDraw = lDraw,
            ValueDraw = vDraw,
        })
    end
end

function ProfileCard:_fetchRemoteMeta()
    local uid = self.UserId
    if uid <= 0 or not (game and game.HttpGet) then return end

    task.spawn(function()
        local thumbJson = game:HttpGet("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. tostring(uid) .. "&size=150x150&format=Png&isCircular=false")
        local imgUrl = thumbJson and thumbJson:match('"imageUrl"%s*:%s*"(https://[^"]+)"')
        if imgUrl then
            local png = game:HttpGet(imgUrl)
            if png and #png > 8 and png:sub(1, 4) == "\x89PNG" then
                self.AvatarPng = png
                if self.AvatarImg then self.AvatarImg.Data = png end
                self:UpdateLayout()
            end
        end

        if self.ShowCreated then
            local userJson = game:HttpGet("https://users.roproxy.com/v1/users/" .. tostring(uid))
            local y, m, d = userJson and userJson:match('"created"%s*:%s*"(%d%d%d%d)%-(%d%d)%-(%d%d)')
            self.CreatedDate = (y and m and d) and (d .. "/" .. m .. "/" .. y) or "N/A"
            for _, r in ipairs(self.PopRows) do
                if r.Key == "created" then
                    r.Value = self.CreatedDate
                    if r.ValueDraw then r.ValueDraw.Text = self.CreatedDate end
                end
            end
            self:UpdateLayout()
        end
    end)
end

function ProfileCard:SetProfile(opts)
    assert(type(opts) == "table", "SetProfile requires options table!")
    if opts.Enabled ~= nil then self.Enabled = opts.Enabled == true end
    if opts.DisplayName ~= nil then self.DisplayName = tostring(opts.DisplayName) end
    if opts.Username ~= nil then self.Username = tostring(opts.Username) end
    if opts.Tag ~= nil then self.Tag = opts.Tag end
    if opts.ShowCreated ~= nil then self.ShowCreated = opts.ShowCreated == true end
    if opts.ShowUptime ~= nil then self.ShowUptime = opts.ShowUptime == true end
    if opts.ShowFPS ~= nil then self.ShowFPS = opts.ShowFPS == true end
    if opts.ShowDate ~= nil then self.ShowDate = opts.ShowDate == true end
    if opts.ShowTime ~= nil then self.ShowTime = opts.ShowTime == true end
    if opts.Fields ~= nil then self.Fields = opts.Fields end
    if opts.CreatedDate ~= nil then self.CreatedDate = tostring(opts.CreatedDate) end
    if opts.Callback ~= nil then self.Callback = opts.Callback end
    if self.Enabled then
        self:_rebuildRows()
        self:UpdateTheme(ThemeModule.GetCurrent and ThemeModule.GetCurrent() or {})
        self:UpdateLayout()
    else
        self:SetVisible(false)
    end
end

function ProfileCard:GetCardRect()
    local win = self.Window
    local wp = win and win.Position or Vector2.new(0, 0)
    local ws = win and win.Size or Vector2.new(620, 440)
    local sbW = (self.Sidebar and self.Sidebar.Width or 190) - 20
    local cx = wp.X + 10
    local cy = wp.Y + ws.Y - self.Height - 8
    return cx, cy, sbW, self.Height
end

function ProfileCard:_getTagConfig()
    if type(self.Tag) == "table" and self.Tag.Text and tostring(self.Tag.Text) ~= "" then
        return self.Tag
    elseif type(self.Tag) == "string" and self.Tag ~= "" then
        return { Text = self.Tag }
    end
    return nil
end

function ProfileCard:_animatePopover(opening)
    self.Open = opening
    AnimationsModule.Tween("profile_pop_" .. tostring(self), self.OpenAnim, opening and 1 or 0, opening and 18 or 22, function(v)
        self.OpenAnim = v
        self:UpdateLayout()
    end)
end

function ProfileCard:GetPopoverRect()
    local cx, cy, cw = self:GetCardRect()
    local rowsH = #self.PopRows * 20
    local ph = 48 + (#self.PopRows > 0 and (14 + rowsH) or 0)
    return cx, cy - ph - 6, cw, ph
end

function ProfileCard:UpdateLayout()
    if not self.Enabled or not self.CardBg then return end
    local vis = (self.Sidebar and self.Sidebar.Visible == true) and (self.Window and self.Window.Visible == true) and (not self.Window.Minimized)
    local cx, cy, cw, ch = self:GetCardRect()

    local hoverAlpha = self.Open and 1 or (self.HoverAnim or 0)
    self.CardBg.Position = Vector2.new(cx, cy)
    self.CardBg.Size = Vector2.new(cw, ch)
    self.CardBg.Transparency = hoverAlpha
    self.CardBg.Visible = vis and (self.Open or self.Hovered or hoverAlpha > 0.02)

    local initChar = string.upper(string.sub(self.DisplayName, 1, 1))
    local ix, iy = MetricsModule.AlignCenter(cx + 6, cy + 8, 32, 32, initChar, 14)
    self.AvatarBg.Position = Vector2.new(cx + 6, cy + 8)
    self.AvatarInitial.Position = Vector2.new(ix, iy)
    self.AvatarImg.Position = Vector2.new(cx + 6, cy + 8)
    local hasImg = self.AvatarPng ~= nil
    self.AvatarBg.Visible = vis and not hasImg
    self.AvatarInitial.Visible = vis and not hasImg
    self.AvatarImg.Visible = vis and hasImg

    local textMaxW = math.max(40, cw - 52)
    local fitName = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(self.DisplayName, textMaxW, 13) or self.DisplayName
    local fitHandle = MetricsModule and MetricsModule.Fit and MetricsModule.Fit("@" .. self.Username, textMaxW, 11) or ("@" .. self.Username)

    self.NameText.Text = fitName
    self.NameText.Position = Vector2.new(cx + 46, cy + 9)
    self.NameText.Visible = vis

    self.HandleText.Text = fitHandle
    self.HandleText.Position = Vector2.new(cx + 46, cy + 25)
    self.HandleText.Visible = vis

    -- Popover (exponential slide-up + fade animation)
    local tagCfg = self:_getTagConfig()
    local anim = self.OpenAnim or 0
    local popVis = vis and (self.Open or anim > 0.02)
    local px, py, pw, ph = self:GetPopoverRect()
    py = py + math.floor((1 - anim) * 10 + 0.5)

    self.PopBg.Position = Vector2.new(px, py)
    self.PopBg.Size = Vector2.new(pw, ph)
    self.PopBg.Transparency = 0.15 + anim * 0.85
    self.PopBg.Visible = popVis

    self.PopBorder.Position = Vector2.new(px, py)
    self.PopBorder.Size = Vector2.new(pw, ph)
    self.PopBorder.Transparency = anim
    self.PopBorder.Visible = popVis

    local tagStr = tagCfg and tostring(tagCfg.Text) or ""
    local tagTextW = tagCfg and MetricsModule.Measure(tagStr, 10) or 0
    local tagW = tagCfg and math.max(36, tagTextW + 14) or 0
    local pTextW = math.max(40, pw - (tagCfg and (tagW + 28) or 20))

    self.PopName.Text = MetricsModule.Fit(self.DisplayName, pTextW, 13)
    self.PopName.Position = Vector2.new(px + 10, py + 9)
    self.PopName.Transparency = anim
    self.PopName.Visible = popVis

    self.PopHandle.Text = MetricsModule.Fit("@" .. self.Username, pTextW, 11)
    self.PopHandle.Position = Vector2.new(px + 10, py + 25)
    self.PopHandle.Transparency = anim
    self.PopHandle.Visible = popVis

    if tagCfg then
        local tx = px + pw - tagW - 10
        local ty = py + 13
        local th = 18
        local ax, ay = MetricsModule.AlignCenter(tx, ty, tagW, th, tagStr, 10)
        self.PopTagBg.Position = Vector2.new(tx, ty)
        self.PopTagBg.Size = Vector2.new(tagW, th)
        self.PopTagBg.Transparency = anim
        self.PopTagBg.Visible = popVis

        self.PopTagText.Text = tagStr
        self.PopTagText.Position = Vector2.new(ax, ay)
        self.PopTagText.Transparency = anim
        self.PopTagText.Visible = popVis
    else
        self.PopTagBg.Visible = false
        self.PopTagText.Visible = false
    end

    self.PopDivider.Position = Vector2.new(px + 10, py + 46)
    self.PopDivider.Size = Vector2.new(pw - 20, 1)
    self.PopDivider.Transparency = anim
    self.PopDivider.Visible = popVis and (#self.PopRows > 0)

    local curY = py + 54
    for _, r in ipairs(self.PopRows) do
        local valStr = tostring(r.Value)
        r.LabelDraw.Position = Vector2.new(px + 10, curY)
        r.LabelDraw.Transparency = anim
        r.LabelDraw.Visible = popVis
        r.ValueDraw.Text = valStr
        r.ValueDraw.Position = Vector2.new(MetricsModule.AlignRight(px, pw, valStr, 11, 10), curY)
        r.ValueDraw.Transparency = anim
        r.ValueDraw.Visible = popVis
        curY = curY + 20
    end
end

function ProfileCard:SetVisible(visible)
    if not visible then
        self.Open = false
        self.OpenAnim = 0
    end
    self:UpdateLayout()
end

function ProfileCard:UpdateTheme(t)
    if not self.Enabled or not self.CardBg then return end
    t = t or {}
    local bgCol = self.Open
        and (t["Tab.ActiveBg"] or get_theme_color("Tab.ActiveBg", Color3.fromRGB(33, 33, 34)))
        or (t["Tab.HoverBg"] or get_theme_color("Tab.HoverBg", Color3.fromRGB(23, 23, 24)))
    local borderCol = t["Card.Border"] or t.Border or get_theme_color("Card.Border", Color3.fromRGB(38, 38, 42))
    local ctrlCol = t["Control.Background"] or get_theme_color("Control.Background", Color3.fromRGB(48, 48, 52))
    local titleCol = t["Text.Title"] or get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))
    local mutedCol = t["Text.Muted"] or get_theme_color("Text.Muted", Color3.fromRGB(161, 161, 161))
    local accentCol = t["Accent.Blue"] or get_theme_color("Accent.Blue", Color3.fromRGB(0, 145, 255))

    self.CardBg.Color = bgCol
    self.AvatarBg.Color = ctrlCol
    self.AvatarInitial.Color = titleCol
    self.NameText.Color = titleCol
    self.HandleText.Color = mutedCol

    self.PopBg.Color = t["Card.Background"] or t.Dialog or get_theme_color("Card.Background", Color3.fromRGB(24, 24, 27))
    self.PopBorder.Color = borderCol
    self.PopName.Color = titleCol
    self.PopHandle.Color = mutedCol
    self.PopDivider.Color = t["Sidebar.Divider"] or borderCol

    local tagCfg = self:_getTagConfig()
    self.PopTagBg.Color = (tagCfg and tagCfg.Color) or accentCol
    self.PopTagText.Color = (tagCfg and tagCfg.TextColor) or Color3.fromRGB(255, 255, 255)

    for _, r in ipairs(self.PopRows) do
        r.LabelDraw.Color = mutedCol
        r.ValueDraw.Color = titleCol
    end
end

function ProfileCard:Update(mx, my, m1Clicked, dt)
    if not self.Enabled or not self.CardBg then return false end
    local vis = (self.Sidebar and self.Sidebar.Visible == true) and (self.Window and self.Window.Visible == true) and (not self.Window.Minimized)
    if not vis then return false end

    self.FpsFrames = self.FpsFrames + 1
    self.FpsAccum = self.FpsAccum + (dt or 0.016)

    local elapsed = math.floor(os.clock() - self.StartClock)
    if elapsed ~= self.LastTickSec then
        self.LastTickSec = elapsed
        self.CurrentFPS = math.max(1, math.floor(self.FpsFrames / math.max(0.001, self.FpsAccum) + 0.5))
        self.FpsFrames = 0
        self.FpsAccum = 0

        local px, _, pw = self:GetPopoverRect()
        for _, r in ipairs(self.PopRows) do
            local nextVal
            if r.Key == "uptime" then
                nextVal = format_uptime(elapsed)
            elseif r.Key == "fps" then
                nextVal = tostring(self.CurrentFPS)
            elseif r.Key == "date" then
                nextVal = os.date("%d/%m/%Y")
            elseif r.Key == "time" then
                nextVal = os.date("%H:%M:%S")
            end
            if nextVal then
                r.Value = nextVal
                if self.Open and r.ValueDraw then
                    r.ValueDraw.Text = nextVal
                    r.ValueDraw.Position = Vector2.new(MetricsModule.AlignRight(px, pw, nextVal, 11, 10), r.ValueDraw.Position.Y)
                end
            end
        end
    end

    local cx, cy, cw, ch = self:GetCardRect()
    local overCard = mx >= cx and mx <= cx + cw and my >= cy and my <= cy + ch
    if overCard ~= self.Hovered then
        self.Hovered = overCard
        self:UpdateTheme(ThemeModule.GetCurrent and ThemeModule.GetCurrent() or {})
        AnimationsModule.Tween("profile_hover_" .. tostring(self), self.HoverAnim, overCard and 1 or 0, 22, function(v)
            self.HoverAnim = v
            self:UpdateLayout()
        end)
    end

    if m1Clicked then
        if overCard then
            self:_animatePopover(not self.Open)
            self:UpdateTheme(ThemeModule.GetCurrent and ThemeModule.GetCurrent() or {})
            if self.Callback then
                task.spawn(self.Callback)
            end
            return true
        elseif self.Open then
            local px, py, pw, ph = self:GetPopoverRect()
            local overPop = mx >= px and mx <= px + pw and my >= py and my <= py + ph
            if overPop then
                return true
            end
            self:_animatePopover(false)
            self:UpdateTheme(ThemeModule.GetCurrent and ThemeModule.GetCurrent() or {})
        end
    end
    return false
end

return ProfileCard

end)()

-- ============================================================================
-- MODULE: Layout/Sidebar.lua
-- ============================================================================
SidebarModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Layout/Sidebar.lua
-- Navigation container with live interactive Search bar, collapsible sections, and layout sync invariant.

local PoolModule = Pool or PoolModule
local MetaModule = Meta or MetaModule
local GeometryModule = Geometry or GeometryModule
local MetricsModule = Metrics or MetricsModule
local ThemeModule = Theme or ThemeModule
local TabModule = Tab or TabModule
local ProfileCardModule = ProfileCard or ProfileCardModule

local IconsModule = Icons
if not IconsModule then
    local ok, mod = pcall(function() return IconsModule end)
    if ok then IconsModule = mod end
end

local Sidebar = {}
Sidebar.__index = Sidebar

local function get_theme_color(token, default)
    return ThemeModule.Get(token, default)
end

-- ============================================================================
-- Section Class (NavigationSection)
-- ============================================================================

local Section = {}
Section.__index = Section

function Section.new(sidebar, config)
    local cfg = type(config) == "table" and config or { Title = tostring(config or "Section") }
    local self = setmetatable({
        Type = "Section",
        Title = cfg.Title or "Section",
        Opened = cfg.Opened ~= false,
        Sidebar = sidebar,
        Tabs = {},
        Height = 26,
        HeaderHeight = 26,
        RelX = 10,
        RelY = 0,
        Visible = true,

        -- Primitives
        Caret = nil,
        TitleText = nil,
    }, Section)

    self:_initDrawings()
    return self
end

function Section:_initDrawings()
    local pool = self.Sidebar.Pool
    if not pool then return end
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    local tri = pool:Get("Image")
    tri.Size = Vector2.new(12, 12)
    tri.Transparency = 0.34
    tri.ZIndex = 4
    tri.Visible = true
    self.Caret = tri
    self:_syncCaretIcon()

    local txt = pool:Get("Text")
    txt.Size = 11
    txt.Font = fontUI
    txt.Outline = false
    txt.Color = get_theme_color("Text.Muted", Color3.fromRGB(120, 120, 130))
    txt.ZIndex = 4
    txt.Visible = true
    self.TitleText = txt

    local win = self.Sidebar.Window
    if win and win._drawings then
        table.insert(win._drawings, self.Caret)
        table.insert(win._drawings, self.TitleText)
    end
end

function Section:_syncCaretIcon()
    if not self.Caret or not IconsModule or not IconsModule.Get then return end
    local iconName = self.Opened and "chevron-up" or "chevron-down"
    IconsModule.Get(iconName, function(png)
        if self.Caret and png then
            self.Caret.Data = png
        end
    end)
end

function Section:HasActiveChild()
    local win = self.Sidebar.Window
    local curTab = win and win.ActiveTab
    if not curTab then return false end
    for _, tab in ipairs(self.Tabs) do
        if tab == curTab then return true end
    end
    return false
end

-- Always recalculate positions unconditionally (never skip when minimized/hidden!)
function Section:UpdatePositions(winPos)
    local hx = winPos.X + self.RelX
    local hy = winPos.Y + self.RelY
    local sbW = (self.Sidebar and self.Sidebar.Width or 190) - 20

    local mutedCol = get_theme_color("Text.Muted", Color3.fromRGB(120, 120, 130))
    local titleCol = get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))
    local isHighlighted = (not self.Opened) and self:HasActiveChild()

    if self.Caret then
        self.Caret.Position = Vector2.new(hx + sbW - 16, hy + 7)
        self.Caret.Transparency = isHighlighted and 0.90 or 0.34
    end

    local rawTitle = tostring(self.Title)
    local fitted = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(rawTitle, sbW - 24, 11) or rawTitle

    if self.TitleText then
        self.TitleText.Text = fitted
        self.TitleText.Position = Vector2.new(hx + 6, hy + math.floor((self.Height - 11) * 0.5))
        self.TitleText.Color = isHighlighted and titleCol or mutedCol
    end
end

function Section:SetVisible(vis)
    self.Visible = vis
    if self.Caret then self.Caret.Visible = vis end
    if self.TitleText then self.TitleText.Visible = vis end

    for _, tab in ipairs(self.Tabs) do
        tab:SetSidebarVisible(vis and (self.Opened or self.Sidebar.SearchQuery ~= ""))
    end
end

function Section:Tab(tabConfig)
    assert(TabModule, "Tab module not available!")
    local tab = TabModule.new(tabConfig, self.Sidebar.Window, self)
    tab.ParentSection = self

    table.insert(self.Tabs, tab)
    table.insert(self.Sidebar.Tabs, tab)
    if self.Sidebar.Window and self.Sidebar.Window.Tabs then
        table.insert(self.Sidebar.Window.Tabs, tab)
    end

    self.Sidebar:RecalculateLayout()

    if self.Sidebar.Window and not self.Sidebar.Window.ActiveTab then
        self.Sidebar.Window:SelectTab(tab)
    end
    return tab
end

function Section:Toggle()
    self.Opened = not self.Opened
    self:_syncCaretIcon()
    self.Sidebar:RecalculateLayout()
end

-- ============================================================================
-- Sidebar Container Class
-- ============================================================================

function Sidebar.new(window, config)
    local cfg = config or {}
    local pool = window and window.Pool

    local self = setmetatable({
        Window = window,
        Pool = pool,
        Theme = window and window.Theme,

        -- Geometry
        RelX = 10,
        RelY = 82,
        Width = cfg.Width or (window and window.SidebarWidth) or 190,

        -- Search state
        SearchFocused = false,
        SearchQuery = "",

        -- Collections
        Items = {},
        Sections = {},
        Tabs = {},

        -- Primitives
        Divider = nil,
        SearchBox = nil,
        SearchBorder = nil,
        SearchIcon = nil,
        SearchText = nil,
        Visible = true,
        Destroyed = false,
    }, Sidebar)

    self:_initDivider()
    self:_initSearchBar()
    if ProfileCardModule then
        self.ProfileCard = ProfileCardModule.new(self, window and window.ProfileConfig)
    end
    return self
end

function Sidebar:_initSearchBar()
    local pool = self.Pool
    if not pool then return end
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    local winPos = self.Window and self.Window.Position or Vector2.new(0, 0)
    local sbW = self.Width - 20
    local sbX = winPos.X + 10
    local sbY = winPos.Y + 46

    local box = pool:Get("Square")
    box.Position = Vector2.new(sbX, sbY)
    box.Size = Vector2.new(sbW, 28)
    box.Color = get_theme_color("Dialog", Color3.fromRGB(26, 26, 26))
    box.Filled = true
    box.Corner = 7
    box.ZIndex = 4
    box.Visible = true
    self.SearchBox = box

    local border = pool:Get("Square")
    border.Position = Vector2.new(sbX, sbY)
    border.Size = Vector2.new(sbW, 28)
    border.Color = get_theme_color("Window.Border", Color3.fromRGB(36, 36, 40))
    border.Filled = false
    border.Thickness = 1
    border.Corner = 7
    border.ZIndex = 4
    border.Visible = true
    self.SearchBorder = border

    local ico = pool:Get("Image")
    ico.Position = Vector2.new(sbX + 9, sbY + 8)
    ico.Size = Vector2.new(12, 12)
    ico.Transparency = 0.55
    ico.ZIndex = 5
    ico.Visible = true
    self.SearchIcon = ico
    if IconsModule and IconsModule.Get then
        IconsModule.Get("search", function(png)
            if self.SearchIcon and png then self.SearchIcon.Data = png end
        end)
    end

    local txt = pool:Get("Text")
    txt.Position = Vector2.new(sbX + 27, sbY + 7)
    txt.Text = "Search"
    txt.Font = fontUI
    txt.Outline = false
    txt.Size = 12
    txt.Color = get_theme_color("Text.Muted", Color3.fromRGB(122, 122, 134))
    txt.ZIndex = 5
    txt.Visible = true
    self.SearchText = txt

    if self.Window and self.Window._drawings then
        table.insert(self.Window._drawings, box)
        table.insert(self.Window._drawings, border)
        table.insert(self.Window._drawings, ico)
        table.insert(self.Window._drawings, txt)
    end
end

function Sidebar:_initDivider()
    local pool = self.Pool
    if not pool then return end

    local div = pool:Get("Square")
    local winPos = self.Window and self.Window.Position or Vector2.new(0, 0)
    local winSize = self.Window and self.Window.Size or Vector2.new(620, 440)
    local divX = winPos.X + self.Width
    local divY = winPos.Y + 46
    local divH = math.max(0, winSize.Y - 58)
    local divCol = get_theme_color("Sidebar.Divider", Color3.fromRGB(28, 28, 34))

    div.Position = Vector2.new(divX, divY)
    div.Size = Vector2.new(1, divH)
    div.Color = divCol
    div.Filled = true
    div.ZIndex = 2
    div.Visible = false
    self.Divider = div

    if self.Window and self.Window._drawings then
        table.insert(self.Window._drawings, div)
    end
end

function Sidebar:RefreshSearchDisplay()
    if not self.SearchText then return end
    if #self.SearchQuery > 0 then
        local caret = (self.SearchFocused and math.floor(os.clock() * 2) % 2 == 0) and "|" or ""
        self.SearchText.Text = self.SearchQuery .. caret
        self.SearchText.Color = get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))
    elseif self.SearchFocused then
        self.SearchText.Text = (math.floor(os.clock() * 2) % 2 == 0) and "|" or ""
        self.SearchText.Color = get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))
    else
        self.SearchText.Text = "Search"
        self.SearchText.Color = get_theme_color("Text.Muted", Color3.fromRGB(122, 122, 134))
    end

    if self.SearchBorder then
        self.SearchBorder.Color = self.SearchFocused
            and get_theme_color("Accent.Blue", Color3.fromRGB(0, 145, 255))
            or get_theme_color("Window.Border", Color3.fromRGB(40, 40, 48))
    end
end

local function tab_matches_query(tab, q)
    if tostring(tab.Title or ""):lower():find(q, 1, true) then
        return true
    end
    for _, sec in ipairs(tab.Sections or {}) do
        if sec.Title and tostring(sec.Title):lower():find(q, 1, true) then
            return true
        end
        for _, ctrl in ipairs(sec.Controls or {}) do
            local t = ctrl.Text or ctrl.Title
            local d = ctrl.Desc or ctrl.Description
            if (t and tostring(t):lower():find(q, 1, true))
                or (d and tostring(d):lower():find(q, 1, true)) then
                return true
            end
        end
    end
    return false
end

function Sidebar:SetSearchQuery(query)
    self.SearchQuery = tostring(query or "")
    local q = self.SearchQuery:lower()

    for _, tab in ipairs(self.Tabs) do
        if q == "" then
            tab.FilteredOut = false
        else
            tab.FilteredOut = not tab_matches_query(tab, q)
        end
    end

    self:RefreshSearchDisplay()
    self:RecalculateLayout()
end

function Sidebar:FocusSearch()
    self.SearchFocused = true
    if self.Window and self.Window.ClaimInteraction then
        self.Window:ClaimInteraction("SidebarSearch")
    end
    self:RefreshSearchDisplay()
end

function Sidebar:BlurSearch()
    self.SearchFocused = false
    if self.Window and self.Window.ReleaseInteraction then
        self.Window:ReleaseInteraction("SidebarSearch")
    end
    self:RefreshSearchDisplay()
end

function Sidebar:ProcessSearchKey(token)
    if not self.SearchFocused or not token then return end
    if token == "enter" then
        self:BlurSearch()
    elseif token == "escape" then
        self:SetSearchQuery("")
        self:BlurSearch()
    elseif token == "backspace" then
        if #self.SearchQuery > 0 then
            self:SetSearchQuery(string.sub(self.SearchQuery, 1, #self.SearchQuery - 1))
        end
    elseif token == "clear" then
        self:SetSearchQuery("")
    elseif #self.SearchQuery < 32 then
        self:SetSearchQuery(self.SearchQuery .. token)
    end
end

function Sidebar:RecalculateLayout()
    local curRelY = self.RelY
    local winPos = self.Window and self.Window.Position or Vector2.new(0, 0)
    local winSize = self.Window and self.Window.Size or Vector2.new(620, 440)
    local maxRelY = winSize.Y - ((self.ProfileCard and self.ProfileCard.Enabled) and 64 or 6)
    local isSearching = self.SearchQuery ~= ""

    for _, item in ipairs(self.Items) do
        if item.Type == "Section" then
            local matchingTabs = 0
            for _, tab in ipairs(item.Tabs) do
                if not tab.FilteredOut then
                    matchingTabs = matchingTabs + 1
                end
            end

            if isSearching and matchingTabs == 0 then
                if item.Caret then item.Caret.Visible = false end
                if item.TitleText then item.TitleText.Visible = false end
                for _, tab in ipairs(item.Tabs) do
                    tab:SetSidebarVisible(false)
                end
            else
                item.RelY = curRelY
                item:UpdatePositions(winPos)
                local secFits = self.Visible and (curRelY + item.Height <= maxRelY)
                if item.Caret then item.Caret.Visible = secFits and (#item.Tabs > 0) and not isSearching end
                if item.TitleText then item.TitleText.Visible = secFits end
                curRelY = curRelY + item.Height

                if item.Opened or isSearching then
                    for _, tab in ipairs(item.Tabs) do
                        if not tab.FilteredOut then
                            tab.RelY = curRelY
                            tab:UpdateSidebarPositions(winPos)
                            local fits = self.Visible and (curRelY + tab.Height <= maxRelY)
                            tab:SetSidebarVisible(fits)
                            curRelY = curRelY + tab.Height + 4
                        else
                            tab:SetSidebarVisible(false)
                        end
                    end
                else
                    for _, tab in ipairs(item.Tabs) do
                        tab:SetSidebarVisible(false)
                    end
                end
            end
        elseif item.Type == "Tab" then
            if not item.FilteredOut then
                item.RelY = curRelY
                item:UpdateSidebarPositions(winPos)
                local fits = self.Visible and (curRelY + item.Height <= maxRelY)
                item:SetSidebarVisible(fits)
                curRelY = curRelY + item.Height + 4
            else
                item:SetSidebarVisible(false)
            end
        end
    end
end

function Sidebar:AddSection(config)
    local sec = Section.new(self, config)
    table.insert(self.Items, sec)
    table.insert(self.Sections, sec)
    if self.Window and self.Window.Sections then
        table.insert(self.Window.Sections, sec)
    end
    self:RecalculateLayout()
    return sec
end

function Sidebar:AddTab(config)
    assert(TabModule, "Tab module not available!")
    local tab = TabModule.new(config, self.Window, nil)
    table.insert(self.Items, tab)
    table.insert(self.Tabs, tab)
    if self.Window and self.Window.Tabs then
        table.insert(self.Window.Tabs, tab)
    end
    self:RecalculateLayout()

    if self.Window and not self.Window.ActiveTab then
        self.Window:SelectTab(tab)
    end
    return tab
end

function Sidebar:Tab(config)
    return self:AddTab(config)
end

function Sidebar:SetPosition(pos)
    local winPos = pos or (self.Window and self.Window.Position) or Vector2.new(0, 0)
    local sbX = winPos.X + 10
    local sbY = winPos.Y + 46

    if self.Divider then
        self.Divider.Position = Vector2.new(winPos.X + self.Width, sbY)
    end
    if self.SearchBox then
        self.SearchBox.Position = Vector2.new(sbX, sbY)
    end
    if self.SearchBorder then
        self.SearchBorder.Position = Vector2.new(sbX, sbY)
    end
    if self.SearchIcon then
        self.SearchIcon.Position = Vector2.new(sbX + 9, sbY + 8)
    end
    if self.SearchText then
        self.SearchText.Position = Vector2.new(sbX + 27, sbY + 7)
    end

    self:RecalculateLayout()
    if self.ProfileCard then self.ProfileCard:UpdateLayout() end
end

function Sidebar:SetSize(size)
    local winSize = self.Window and self.Window.Size or Vector2.new(620, 440)
    local divH = math.max(0, winSize.Y - 58)
    local sbW = self.Width - 20

    if self.Divider then
        self.Divider.Size = Vector2.new(1, divH)
    end
    if self.SearchBox then
        self.SearchBox.Size = Vector2.new(sbW, 28)
    end
    if self.SearchBorder then
        self.SearchBorder.Size = Vector2.new(sbW, 28)
    end

    self:RecalculateLayout()
    if self.ProfileCard then self.ProfileCard:UpdateLayout() end
end

function Sidebar:SetVisible(visible)
    self.Visible = visible
    if not visible and self.SearchFocused then
        self:BlurSearch()
    end
    if self.SearchBox then self.SearchBox.Visible = visible end
    if self.SearchBorder then self.SearchBorder.Visible = visible end
    if self.SearchIcon then self.SearchIcon.Visible = visible end
    if self.SearchText then self.SearchText.Visible = visible end

    self:RecalculateLayout()
    if self.ProfileCard then self.ProfileCard:SetVisible(visible) end
end

function Sidebar:UpdateTheme(t)
    local divCol = t["Sidebar.Divider"] or t.Divider or get_theme_color("Sidebar.Divider", Color3.fromRGB(30, 30, 32))
    local boxCol = t.Dialog or get_theme_color("Dialog", Color3.fromRGB(26, 26, 26))
    local borderCol = t.Border or get_theme_color("Window.Border", Color3.fromRGB(36, 36, 40))
    local mutedCol = t["Text.Muted"] or get_theme_color("Text.Muted", Color3.fromRGB(161, 161, 161))
    local titleCol = t["Text.Title"] or get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))
    if self.Divider then
        self.Divider.Color = divCol
    end
    if self.SearchBox then
        self.SearchBox.Color = boxCol
    end
    if self.SearchBorder then
        self.SearchBorder.Color = self.SearchFocused
            and get_theme_color("Accent.Blue", Color3.fromRGB(0, 145, 255))
            or borderCol
    end
    for _, sec in ipairs(self.Sections or {}) do
        if sec.TitleText then
            local isHighlighted = (not sec.Opened) and sec:HasActiveChild()
            sec.TitleText.Color = isHighlighted and titleCol or mutedCol
        end
    end
    self:RefreshSearchDisplay()
    self:RecalculateLayout()
    if self.ProfileCard then self.ProfileCard:UpdateTheme(t) end
end

function Sidebar:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self:SetVisible(false)

    for _, tab in ipairs(self.Tabs) do
        if tab.Destroy then tab:Destroy() end
    end

    self.Items = {}
    self.Sections = {}
    self.Tabs = {}
end

return Sidebar

end)()

-- ============================================================================
-- MODULE: Layout/Window.lua
-- ============================================================================
WindowModule = (function()
    local Pool = PoolModule
    local Meta = MetaModule
    local Metrics = MetricsModule
    local Geometry = GeometryModule
    local Theme = ThemeModule
    local Clamping = ClampingModule
    local Drag = DragModule
    local Animations = AnimationsModule
    local InputHandler = InputHandlerModule
    local Icons = IconsModule
    local Settings = SettingsModule
    local Notify = NotifyModule
    local Dialog = DialogModule
    local Overlay = OverlayModule
    local Keybind = KeybindModule
    local Button = ButtonModule
    local Slider = SliderModule
    local Dropdown = DropdownModule
    local Input = InputModule
    local Toggle = ToggleModule
    local Paragraph = ParagraphModule
    local Code = CodeModule
    local Image = ImageModule
    local ProgressBar = ProgressBarModule
    local Colorpicker = ColorpickerModule
    local ContentSection = ContentSectionModule
    local Tab = TabModule
    local Sidebar = SidebarModule
    local Window = WindowModule

-- Library/BreezeUI/Layout/Window.lua
-- Core Window frame, seamless macOS topbar, ResizeIcon, smart viewport clamping, animations, and unified input loop.

local PoolModule = Pool or PoolModule
local MetaModule = Meta or MetaModule
local GeometryModule = Geometry or GeometryModule
local MetricsModule = Metrics or MetricsModule
local ThemeModule = Theme or ThemeModule
local SidebarModule = Sidebar or SidebarModule
local ClampingModule = Clamping or ClampingModule

local DragModule = Drag
if not DragModule then
    local ok, mod = pcall(function() return DragModule end)
    if ok then DragModule = mod end
end

local AnimationsModule = Animations
if not AnimationsModule then
    local ok, mod = pcall(function() return AnimationsModule end)
    if ok then AnimationsModule = mod end
end

local InputHandlerModule = InputHandler
if not InputHandlerModule then
    local ok, mod = pcall(function() return InputHandlerModule end)
    if ok then InputHandlerModule = mod end
end

local IconsModule = Icons
if not IconsModule then
    local ok, mod = pcall(function() return IconsModule end)
    if ok then IconsModule = mod end
end

local NotifyModule = Notify
if not NotifyModule then
    local ok, mod = pcall(function() return NotifyModule end)
    if ok then NotifyModule = mod end
end

local DialogModule = Dialog
if not DialogModule then
    local ok, mod = pcall(function() return DialogModule end)
    if ok then DialogModule = mod end
end

local OverlayModule = Overlay
if not OverlayModule then
    local ok, mod = pcall(function() return OverlayModule end)
    if ok then OverlayModule = mod end
end

local Window = {}
Window.__index = Window

local UI_STATE_KEY = "breeze_ui_state"
local UI_STATE_RUNNING = "running"
local UI_STATE_UNLOAD = "unload"
local UI_STATE_EMPTY = ""

local function get_theme_color(token, default)
    if ThemeModule and ThemeModule.Get then
        local val = ThemeModule.Get(token)
        if val ~= nil then return val end
    end
    return default
end

local function get_mouse()
    if not game or not game.GetService then return nil end
    local ok, players = pcall(function() return game:GetService("Players") end)
    if ok and players and players.LocalPlayer then
        return players.LocalPlayer:GetMouse()
    end
    return nil
end

local function get_viewport()
    local vp = Vector2.new(1920, 1080)
    pcall(function()
        local cam = workspace and workspace.CurrentCamera
        if cam and cam.ViewportSize and cam.ViewportSize.X > 0 and cam.ViewportSize.Y > 0 then
            vp = cam.ViewportSize
        end
    end)
    return vp
end

function Window.new(config)
    config = config or {}
    assert(config.Title ~= nil and tostring(config.Title) ~= "", "Window config.Title is required!")

    local vp = get_viewport()
    local minSize = config.MinSize or Vector2.new(460, 320)
    local rawSize = config.Size or Vector2.new(640, 460)
    local maxSize = config.MaxSize or Vector2.new(960, 680)
    local safeMaxX = math.max(minSize.X, math.min(maxSize.X, vp.X - 24))
    local safeMaxY = math.max(minSize.Y, math.min(maxSize.Y, vp.Y - 48))

    local resolvedSize = Vector2.new(
        math.clamp(rawSize.X, minSize.X, safeMaxX),
        math.clamp(rawSize.Y, minSize.Y, safeMaxY)
    )

    local initialPos = config.Position
    if not initialPos then
        local cx = math.max(12, math.floor((vp.X - resolvedSize.X) * 0.5))
        local cy = math.max(36, math.floor((vp.Y - resolvedSize.Y) * 0.5))
        initialPos = Vector2.new(cx, cy)
    end

    local themeName = type(config.Theme) == "string" and config.Theme or "Dark"
    local themeTokens = type(config.Theme) == "table" and config.Theme
        or (ThemeModule and ThemeModule.GetTheme and ThemeModule.GetTheme(themeName))
        or (ThemeModule and ThemeModule.DefaultPalette)
        or {}

    local poolInstance = PoolModule and PoolModule.new(350, MetaModule)
    local env = config.Env or (type(_G.Library) == "table" and _G.Library) or nil
    local topbarH = (type(config.Topbar) == "table" and config.Topbar.Height) or 44

    local self = setmetatable({
        Env = env,
        Title = tostring(config.Title),
        Subtitle = config.Subtitle or (config.Author and tostring(config.Author)) or "BreezeUI",
        Folder = config.Folder,
        Icon = config.Icon,
        Position = initialPos,
        Size = resolvedSize,
        BaseSize = resolvedSize,
        MinSize = minSize,
        MaxSize = maxSize,
        CanResize = config.Resizable ~= false,
        SidebarWidth = config.SidebarWidth or 190,
        ProfileConfig = config.Profile,
        CornerRadius = config.CornerRadius or 14,
        Theme = themeName,
        ThemeTokens = themeTokens,
        Scale = config.Scale or ((config.DPIScale or 100) / 100),
        HeaderHeight = topbarH,
        Topbar = config.Topbar or { Height = topbarH, ButtonsType = "Mac" },
        ToggleKey = config.ToggleKey or config.MenuKey,
        IgnoreAlerts = config.IgnoreAlerts == true,
        BlockRobloxInput = (config.BlockRobloxInput == true) or (env and env.BlockRobloxInput == true),
        _lastInputBlocked = false,
        ShowKeybindMenu = (config.ShowKeybindMenu == true) or (env and env.ShowKeybindMenu == true),
        KeybindMenuX = config.KeybindMenuX or (type(config.KeybindMenu) == "table" and config.KeybindMenu.X) or nil,
        KeybindMenuY = config.KeybindMenuY or (type(config.KeybindMenu) == "table" and config.KeybindMenu.Y) or nil,
        KeybindMenuWidth = config.KeybindMenuWidth or (type(config.KeybindMenu) == "table" and config.KeybindMenu.Width) or 240,
        Watermark = {
            Text = (env and env.WatermarkText) or (type(config.Watermark) == "string" and config.Watermark) or "",
            Tokens = (env and env.WatermarkTokens) or nil,
            Visible = (env and env.WatermarkVisible == true) or (type(config.Watermark) == "string" and config.Watermark ~= ""),
            X = 16,
            Y = 16,
        },
        OpenButton = {
            Enabled = config.OpenButton ~= false,
            Title = tostring(config.Title),
            Icon = config.Icon or "wind",
            Draggable = true,
            OnlyIcon = false,
            Position = nil,
            Color = nil,
        },

        -- State flags
        Minimized = false,
        IsMaximized = false,
        PreMaximizeSize = nil,
        PreMaximizePos = nil,
        Visible = true,
        Destroyed = false,
        Running = true,
        FocusedWidget = nil,
        ActiveInteraction = nil,
        FocusedInput = nil,
        OpenDropdown = nil,
        CapturingKeybind = nil,
        IsDragging = false,
        DragStart = Vector2.new(0, 0),
        DragStartPos = Vector2.new(0, 0),
        LastPillClick = -10,
        IsResizing = false,
        ResizeStartMouse = Vector2.new(0, 0),
        ResizeStartSize = Vector2.new(0, 0),
        RegisteredIds = {
            Toggles = {},
            Options = {},
        },

        -- Hierarchy Collections
        Sections = {},
        Tabs = {},
        Keybinds = {},
        ActiveTab = nil,
        Cards = {},
        Tags = {},
        Drawings = {},
        _drawings = {},
        _onOpenCallbacks = {},
        _onCloseCallbacks = {},
        _onDestroyCallbacks = {},
        DisabledTopbarButtons = {},
        BgImage = nil,
        BgImageUrl = nil,
        BgImageTransparency = 0.25,

        -- Core Engine
        Pool = poolInstance,
        Sidebar = nil,
        DragModule = nil,
        Input = InputHandlerModule and InputHandlerModule.new() or nil,

        -- Hardware Input
        Mouse = nil,
        PrevM1 = false,
        RenderConnection = nil,
        ScrollConnection = nil,

        -- Visual Primitives
        FrameBg = nil,
        Background = nil,
        Border = nil,
        HeaderBg = nil,
        MainPanelBg = nil,
        TopbarDivider = nil,
        ScrollTrack = nil,
        ScrollThumb = nil,
        ResizeIcon = nil,

        -- macOS Traffic Lights
        MacClose = nil,
        MacMin = nil,
        MacMax = nil,
        CloseBtn = nil,
        CloseBtnBg = nil,
        CloseBtnIcon = nil,
        MinBtn = nil,
        MinBtnBg = nil,
        MinBtnIcon = nil,
        MaxBtn = nil,
        MaxBtnBg = nil,

        -- Header Branding & Titles
        HeaderIcon = nil,
        Logo = nil,
        TitleText = nil,
        HeaderText = nil,
        SubtitleText = nil,
        TitleOffset = 74,
        TitleEndOffset = 220,

        -- Bottom Drag Pill
        BottomDragPill = nil,
        VerticalDivider = nil,
    }, Window)

    self:_createChrome()
    self.DragModule = DragModule and DragModule.new(self) or nil

    if SidebarModule then
        self.Sidebar = SidebarModule.new(self, { Width = self.SidebarWidth })
        self.VerticalDivider = self.Sidebar.Divider
    end

    pcall(function()
        local runService = game:GetService("RunService")
        if runService and runService.RenderStepped then
            local conn
            conn = runService.RenderStepped:Connect(function(dt)
                self:Update(dt)
            end)
            self.RenderConnection = conn
        end
    end)

    pcall(function()
        local uis = game:GetService("UserInputService")
        if uis and uis.InputChanged then
            local sConn
            sConn = uis.InputChanged:Connect(function(input)
                if not self.Visible or self.Minimized or self.Destroyed then return end
                if input and Enum and Enum.UserInputType and input.UserInputType == Enum.UserInputType.MouseWheel then
                    local delta = input.Position and input.Position.Z or 0
                    if delta ~= 0 then
                        if self.OpenDropdown and self.OpenDropdown.Opened and (self.OpenDropdown.MaxScrollOffset or 0) > 0 then
                            self.OpenDropdown:Scroll(delta > 0 and -1 or 1)
                        elseif self.ActiveTab and self.ActiveTab.Scroll then
                            self.ActiveTab:Scroll(-delta * 28)
                        end
                    end
                end
            end)
            self.ScrollConnection = sConn
        end
    end)

    return self
end

function Window:_createChrome()
    local pool = self.Pool
    if not pool then return end

    local px = self.Position.X
    local py = self.Position.Y
    local sx = self.Size.X
    local sy = self.Size.Y
    local corner = self.CornerRadius
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    local bgCol = self.ThemeTokens.Background or get_theme_color("Window.Background", Color3.fromRGB(16, 16, 18))
    local borderCol = self.ThemeTokens.Border or get_theme_color("Window.Border", Color3.fromRGB(36, 36, 42))
    local panelCol = self.ThemeTokens.PanelBackground or get_theme_color("PanelBackground", Color3.fromRGB(22, 22, 26))
    local textCol = self.ThemeTokens.Text or get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))

    -- 1. Main Window Frame Background & Border
    local bg = pool:Get("Square")
    bg.Position = self.Position
    bg.Size = self.Size
    bg.Color = bgCol
    bg.Filled = true
    bg.Corner = corner
    bg.ZIndex = 1
    bg.Visible = true
    self.FrameBg = bg
    self.Background = bg
    self:_register(bg)

    local b = pool:Get("Square")
    b.Position = self.Position
    b.Size = self.Size
    b.Color = borderCol
    b.Filled = false
    b.Thickness = 1
    b.Corner = corner
    b.ZIndex = 3
    b.Visible = true
    self.Border = b
    self:_register(b)

    -- 2. Right Content MainBar Panel
    local panel = pool:Get("Square")
    panel.Position = Vector2.new(px + self.SidebarWidth + 4, py + self.HeaderHeight)
    panel.Size = Vector2.new(sx - self.SidebarWidth - 12, sy - self.HeaderHeight - 8)
    panel.Color = panelCol
    panel.Filled = true
    panel.Corner = 10
    panel.ZIndex = 2
    panel.Visible = true
    self.MainPanelBg = panel
    self:_register(panel)

    -- 3. Content Scrollbar Track & Thumb (dedicated gutter separated from sections)
    local sTrack = pool:Get("Square")
    sTrack.Position = Vector2.new(px + sx - 22, py + self.HeaderHeight + 10)
    sTrack.Size = Vector2.new(8, 40)
    sTrack.Color = get_theme_color("Control.Background", Color3.fromRGB(48, 48, 52))
    sTrack.Filled = true
    sTrack.Corner = 6
    sTrack.Transparency = 0.45
    sTrack.ZIndex = 7
    sTrack.Visible = false
    self.ScrollTrack = sTrack
    self:_register(sTrack)

    local sThumb = pool:Get("Square")
    sThumb.Position = Vector2.new(px + sx - 22, py + self.HeaderHeight + 10)
    sThumb.Size = Vector2.new(8, 40)
    sThumb.Color = get_theme_color("Text.Muted", Color3.fromRGB(161, 161, 161))
    sThumb.Filled = true
    sThumb.Corner = 6
    sThumb.Transparency = 0.28
    sThumb.ZIndex = 8
    sThumb.Visible = false
    self.ScrollThumb = sThumb
    self:_register(sThumb)

    self.HeaderBg = bg

    -- 4. macOS Traffic Lights
    local closeCol = get_theme_color("Mac.Close", Color3.fromRGB(255, 95, 86))
    local minCol = get_theme_color("Mac.Minimize", Color3.fromRGB(255, 189, 46))
    local maxCol = get_theme_color("Mac.Maximize", Color3.fromRGB(39, 201, 63))

    local macClose = pool:Get("Square")
    macClose.Position = Vector2.new(px + 16, py + 16)
    macClose.Size = Vector2.new(11, 11)
    macClose.Corner = 5.5
    macClose.Filled = true
    macClose.Color = closeCol
    macClose.ZIndex = 4
    macClose.Visible = true
    self.MacClose = macClose
    self.CloseBtn = macClose
    self.CloseBtnBg = macClose
    self:_register(macClose)

    local macMin = pool:Get("Square")
    macMin.Position = Vector2.new(px + 34, py + 16)
    macMin.Size = Vector2.new(11, 11)
    macMin.Corner = 5.5
    macMin.Filled = true
    macMin.Color = minCol
    macMin.ZIndex = 4
    macMin.Visible = true
    self.MacMin = macMin
    self.MinBtn = macMin
    self.MinBtnBg = macMin
    self:_register(macMin)

    local macMax = pool:Get("Square")
    macMax.Position = Vector2.new(px + 52, py + 16)
    macMax.Size = Vector2.new(11, 11)
    macMax.Corner = 5.5
    macMax.Filled = true
    macMax.Color = maxCol
    macMax.ZIndex = 4
    macMax.Visible = true
    self.MacMax = macMax
    self.MaxBtn = macMax
    self.MaxBtnBg = macMax
    self:_register(macMax)

    -- 5. Optional Brand Logo (only shown when config.Icon is explicitly provided)
    local showLogo = self.Icon ~= nil and self.Icon ~= "" and self.Icon ~= false
    local logo = pool:Get("Image")
    logo.Position = Vector2.new(px + 72, py + 14)
    logo.Size = Vector2.new(16, 16)
    logo.Transparency = 1.0
    logo.ZIndex = 4
    logo.Visible = showLogo
    self.HeaderIcon = logo
    self.Logo = logo
    self:_register(logo)

    if showLogo and IconsModule and IconsModule.Get then
        IconsModule.Get(self.Icon, function(pngData)
            if self.HeaderIcon and pngData then
                self.HeaderIcon.Data = pngData
            end
        end)
    end

    -- 6. Window Title (Single clean San Francisco line)
    local titleOffset = showLogo and 94 or 74
    local titleText = pool:Get("Text")
    local maxTitleW = math.max(80, sx - 180)
    local fullTitle = (self.Subtitle and self.Subtitle ~= "" and self.Subtitle ~= "BreezeUI")
        and (self.Title .. "  |  " .. self.Subtitle)
        or tostring(self.Title)
    local fitTitle = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(fullTitle, maxTitleW, 13) or fullTitle
    titleText.Position = Vector2.new(px + titleOffset, py + 15)
    titleText.Text = fitTitle
    titleText.Color = textCol
    titleText.Size = 13
    titleText.Font = fontUI
    titleText.Outline = false
    titleText.ZIndex = 4
    titleText.Visible = true
    self.TitleText = titleText
    self.HeaderText = titleText
    self.TitleOffset = titleOffset
    self.TitleEndOffset = titleOffset + math.floor(#fitTitle * 6.2)
    self:_register(titleText)

    local subText = pool:Get("Text")
    subText.Size = 11
    subText.Font = fontUI
    subText.Outline = false
    subText.Visible = false
    self.SubtitleText = subText

    -- 7. Bottom Drag Pill (Crisp 168x12 anti-aliased PNG matching WindUI BottomDragFrame)
    local pill = pool:Get("Image")
    pill.Position = Vector2.new(px + math.floor((sx - 168) * 0.5), py + sy + 2)
    pill.Size = Vector2.new(168, 12)
    pill.Transparency = 0.25
    pill.ZIndex = 4
    pill.Visible = true
    self.BottomDragPill = pill
    self:_register(pill)

    if IconsModule and IconsModule.Get then
        IconsModule.Get("drag-bar", function(pngData)
            if self.BottomDragPill and pngData then
                self.BottomDragPill.Data = pngData
            end
        end)
    end

    -- 8. Bottom-Right Outside Corner Resize Arc (Concentric 6px outside window corner)
    local resizeIco = pool:Get("Image")
    resizeIco.Position = Vector2.new(px + sx - 28, py + sy - 28)
    resizeIco.Size = Vector2.new(44, 44)
    resizeIco.Transparency = 0.28
    resizeIco.ZIndex = 10
    resizeIco.Visible = self.CanResize
    self.ResizeIcon = resizeIco
    self:_register(resizeIco)

    if IconsModule and IconsModule.Get then
        IconsModule.Get("resize-corner", function(pngData)
            if self.ResizeIcon and pngData then
                self.ResizeIcon.Data = pngData
            end
        end)
    end
end

function Window:_register(obj)
    if not obj then return end
    table.insert(self.Drawings, obj)
    table.insert(self._drawings, obj)
end

function Window:_syncScrollbar()
    if not self.ScrollThumb then return end
    local tab = self.ActiveTab
    if not self.Visible or self.Minimized or not tab or (tab.MaxScrollY or 0) <= 0 then
        self.ScrollThumb.Visible = false
        if self.ScrollTrack then self.ScrollTrack.Visible = false end
        return
    end

    local px = self.Position.X
    local py = self.Position.Y
    local sx = self.Size.X
    local sy = self.Size.Y
    local trackX = px + sx - 22
    local trackTop = py + self.HeaderHeight + 10
    local trackH = math.max(40, sy - self.HeaderHeight - 28)
    local totalH = trackH + tab.MaxScrollY
    local thumbH = math.max(28, math.floor(trackH * (trackH / totalH)))
    local ratio = tab.MaxScrollY > 0 and ((tab.ScrollY or 0) / tab.MaxScrollY) or 0
    local thumbY = trackTop + math.floor(ratio * (trackH - thumbH))

    if self.ScrollTrack then
        self.ScrollTrack.Position = Vector2.new(trackX, trackTop)
        self.ScrollTrack.Size = Vector2.new(8, trackH)
        self.ScrollTrack.Visible = true
    end
    self.ScrollThumb.Position = Vector2.new(trackX, thumbY)
    self.ScrollThumb.Size = Vector2.new(8, thumbH)
    self.ScrollThumb.Visible = true
end

function Window:_syncTagPositions()
    local px = self.Position.X
    local py = self.Position.Y
    local sx = self.Size.X
    for _, tag in ipairs(self.Tags) do
        local relX = math.min((self.TitleEndOffset or 220) + 12, sx - tag.Width - 14)
        tag.RelX = math.max(74, relX)
        local tx = px + tag.RelX
        local ty = py + tag.RelY
        local fitsHeader = (tx + tag.Width <= px + sx - 10)
        if tag.Bg then
            tag.Bg.Position = Vector2.new(tx, ty)
            tag.Bg.Visible = self.Visible and fitsHeader
        end
        if tag.Border then
            tag.Border.Position = Vector2.new(tx, ty)
            tag.Border.Visible = self.Visible and fitsHeader
        end
        if tag.Icon then
            tag.Icon.Position = Vector2.new(tx + 7, ty + 4)
            tag.Icon.Visible = self.Visible and fitsHeader
        end
        if tag.Text then
            tag.Text.Position = Vector2.new(tx + (tag.Icon and 24 or 8), ty + 4)
            tag.Text.Visible = self.Visible and fitsHeader
        end
    end
end

-- ============================================================================
-- Navigation Hierarchy API
-- ============================================================================

function Window:SetProfile(opts)
    if self.Sidebar and self.Sidebar.ProfileCard then
        self.Sidebar.ProfileCard:SetProfile(opts)
    end
end

function Window:Section(config)
    assert(self.Sidebar ~= nil, "Sidebar not initialized on Window!")
    return self.Sidebar:AddSection(config)
end

function Window:Tab(config)
    assert(self.Sidebar ~= nil, "Sidebar not initialized on Window!")
    return self.Sidebar:AddTab(config)
end

function Window:AddTab(config)
    return self:Tab(config)
end

function Window:SelectTab(targetTab)
    assert(targetTab ~= nil, "SelectTab requires target Tab instance!")
    if self.ActiveTab == targetTab then
        return
    end

    if self.OpenDropdown and self.OpenDropdown.Close then
        self.OpenDropdown:Close()
    end
    if self.OpenColorpicker and self.OpenColorpicker.Close then
        self.OpenColorpicker:Close()
    end
    if self.OpenKeybindMenu and self.OpenKeybindMenu.CloseModeMenu then
        self.OpenKeybindMenu:CloseModeMenu()
    end
    if self.CapturingKeybind and self.CapturingKeybind.CancelCapture then
        self.CapturingKeybind:CancelCapture()
    end
    if self.FocusedInput and self.FocusedInput.Blur then
        self.FocusedInput:Blur(false)
    end

    if self.ActiveTab then
        self.ActiveTab:Hide()
    end

    self.ActiveTab = targetTab
    self.CurrentTab = targetTab

    targetTab:Show(self.Position)
    self:_syncScrollbar()

    if self.Sidebar then
        self.Sidebar:RecalculateLayout()
    end
end

-- ============================================================================
-- Position, Size, Minimize, Maximize, Theme & Tags
-- ============================================================================

function Window:SetPosition(newPos)
    self.Position = newPos
    local px = newPos.X
    local py = newPos.Y
    local sx = self.Size.X
    local sy = self.Minimized and self.HeaderHeight or self.Size.Y

    if self.FrameBg then self.FrameBg.Position = newPos end
    if self.BgImage then self.BgImage.Position = newPos end
    if self.Border then self.Border.Position = newPos end
    if self.MainPanelBg then
        self.MainPanelBg.Position = Vector2.new(px + self.SidebarWidth + 4, py + self.HeaderHeight)
    end
    if self.MacClose then self.MacClose.Position = Vector2.new(px + 16, py + 16) end
    if self.MacMin then self.MacMin.Position = Vector2.new(px + 34, py + 16) end
    if self.MacMax then self.MacMax.Position = Vector2.new(px + 52, py + 16) end
    if self.HeaderIcon then self.HeaderIcon.Position = Vector2.new(px + 72, py + 14) end
    if self.TitleText then self.TitleText.Position = Vector2.new(px + (self.TitleOffset or 74), py + 15) end
    if self.BottomDragPill then
        self.BottomDragPill.Position = Vector2.new(px + math.floor((sx - 168) * 0.5), py + sy + 2)
    end
    if self.ResizeIcon then
        self.ResizeIcon.Position = Vector2.new(px + sx - 28, py + sy - 28)
    end

    self:_syncTagPositions()

    if self.Sidebar then
        self.Sidebar:SetPosition(newPos)
    end

    -- Sync ALL tabs so switching tabs after a drag or restore never renders stale coords
    for _, tab in ipairs(self.Tabs) do
        if tab.UpdatePosition then
            tab:UpdatePosition(newPos)
        end
    end

    self:_syncScrollbar()
end

function Window:SetSize(newSize, ignoreMaxClamp)
    local vp = get_viewport()
    local minW = self.MinSize.X
    local minH = self.MinSize.Y
    local capW = ignoreMaxClamp and (vp.X - 24) or math.min(self.MaxSize.X, vp.X - 16)
    local capH = ignoreMaxClamp and (vp.Y - 64) or math.min(self.MaxSize.Y, vp.Y - 40)
    local maxW = math.max(minW, capW)
    local maxH = math.max(minH, capH)

    local clampedW = math.clamp(newSize.X, minW, maxW)
    local clampedH = math.clamp(newSize.Y, minH, maxH)
    self.Size = Vector2.new(clampedW, clampedH)
    if not self._applyingScale and not ignoreMaxClamp then
        local sc = (self.Scale and self.Scale > 0) and self.Scale or 1
        self.BaseSize = Vector2.new(math.floor(clampedW / sc + 0.5), math.floor(clampedH / sc + 0.5))
    end

    local px = self.Position.X
    local py = self.Position.Y
    local sy = self.Minimized and self.HeaderHeight or clampedH

    if self.FrameBg then self.FrameBg.Size = Vector2.new(clampedW, sy) end
    if self.BgImage then self.BgImage.Size = Vector2.new(clampedW, sy) end
    if self.Border then self.Border.Size = Vector2.new(clampedW, sy) end
    if self.MainPanelBg then
        self.MainPanelBg.Size = Vector2.new(clampedW - self.SidebarWidth - 12, math.max(40, sy - self.HeaderHeight - 8))
    end

    local maxTitleW = math.max(60, clampedW - 180)
    local fullTitle = (self.Subtitle and self.Subtitle ~= "" and self.Subtitle ~= "BreezeUI")
        and (self.Title .. "  |  " .. self.Subtitle)
        or tostring(self.Title)
    local fitTitle = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(fullTitle, maxTitleW, 13) or fullTitle
    if self.TitleText then
        self.TitleText.Text = fitTitle
    end
    self.TitleEndOffset = (self.TitleOffset or 74) + math.floor(#fitTitle * 6.2)

    if self.BottomDragPill then
        self.BottomDragPill.Position = Vector2.new(px + math.floor((clampedW - 168) * 0.5), py + sy + 2)
    end
    if self.ResizeIcon then
        self.ResizeIcon.Position = Vector2.new(px + clampedW - 28, py + sy - 28)
    end

    self:_syncTagPositions()

    if self.Sidebar then
        self.Sidebar:SetSize(Vector2.new(self.SidebarWidth, clampedH - 58))
    end

    -- Reflow ALL tabs so resizing updates both active and inactive pages!
    for _, tab in ipairs(self.Tabs) do
        if tab.UpdateSize then
            tab:UpdateSize(self.Size)
        end
    end

    -- Keep window safely clamped inside screen bounds after resize (no magnetic snap on resize/restore)
    if not self.IsMaximized and not ignoreMaxClamp then
        local topInset = ClampingModule and ClampingModule.DefaultTopInset or 36
        local maxX = math.max(0, vp.X - self.Size.X)
        local maxY = math.max(topInset, vp.Y - self.Size.Y)
        local safeX = math.clamp(self.Position.X, 0, maxX)
        local safeY = math.clamp(self.Position.Y, topInset, maxY)
        if safeX ~= self.Position.X or safeY ~= self.Position.Y then
            self:SetPosition(Vector2.new(safeX, safeY))
            return
        end
    end
    self:_syncScrollbar()
end

function Window:ToggleMinimize()
    if self.Destroyed then return end
    self.IsDragging = false
    self.IsResizing = false
    self.IsScrolling = false
    self:ReleaseInteraction("WindowDrag")
    self:ReleaseInteraction("WindowResize")
    self:ReleaseInteraction("WindowScroll")
    self.Minimized = not self.Minimized

    if self.OpenDropdown and self.OpenDropdown.Close then
        self.OpenDropdown:Close()
    end
    if self.OpenColorpicker and self.OpenColorpicker.Close then
        self.OpenColorpicker:Close()
    end
    if self.OpenKeybindMenu and self.OpenKeybindMenu.CloseModeMenu then
        self.OpenKeybindMenu:CloseModeMenu()
    end
    if self.CapturingKeybind and self.CapturingKeybind.CancelCapture then
        self.CapturingKeybind:CancelCapture()
    end
    if self.FocusedInput and self.FocusedInput.Blur then
        self.FocusedInput:Blur(false)
    end

    local isShown = (not self.Minimized) and self.Visible
    if self.FrameBg then
        self.FrameBg.Visible = self.Visible
        self.FrameBg.Size = Vector2.new(self.Size.X, self.Minimized and self.HeaderHeight or self.Size.Y)
    end
    if self.BgImage then
        self.BgImage.Visible = isShown and (self.BgImageUrl ~= nil)
        self.BgImage.Size = Vector2.new(self.Size.X, self.Minimized and self.HeaderHeight or self.Size.Y)
    end
    if self.Border then
        self.Border.Visible = self.Visible
        self.Border.Size = Vector2.new(self.Size.X, self.Minimized and self.HeaderHeight or self.Size.Y)
    end
    if self.MainPanelBg then self.MainPanelBg.Visible = isShown end
    if self.BottomDragPill then self.BottomDragPill.Visible = isShown end
    if self.ResizeIcon then self.ResizeIcon.Visible = isShown and self.CanResize end

    if self.Sidebar then
        self.Sidebar:SetVisible(isShown)
    end

    if self.ActiveTab then
        if not isShown then
            self.ActiveTab:Hide()
        else
            self.ActiveTab:Show(self.Position)
        end
    end

    -- Preserve fullscreen dimensions when unminimizing from a maximized state!
    self:SetPosition(self.Position)
    if not self.Minimized then
        self:SetSize(self.Size, self.IsMaximized)
    end
    self:_updateInputBlock()

    return self.Minimized
end
Window.Minimize = Window.ToggleMinimize
Window.Minimise = Window.ToggleMinimize

function Window:ToggleMaximize()
    if self.Destroyed then return end
    self.IsDragging = false
    self.IsResizing = false
    self:ReleaseInteraction("WindowDrag")
    self:ReleaseInteraction("WindowResize")
    local vp = get_viewport()
    if not self.IsMaximized then
        self.PreMaximizeSize = self.Size
        self.PreMaximizePos = self.Position
        self.PreMaximizeResizable = self.CanResize
        self.IsMaximized = true
        self.CanResize = false
        if self.DragModule and self.DragModule.Set then
            self.DragModule:Set(false)
        end
        if self.Minimized then
            self.Minimized = false
        end
        local targetW = math.max(self.MinSize.X, vp.X - 24)
        local targetH = math.max(self.MinSize.Y, vp.Y - 64)
        self:SetSize(Vector2.new(targetW, targetH), true)
        self:SetPosition(Vector2.new(12, 46))
    else
        self.IsMaximized = false
        self.CanResize = self.PreMaximizeResizable ~= false
        if self.DragModule and self.DragModule.Set then
            self.DragModule:Set(true)
        end
        if self.Minimized then
            self.Minimized = false
        end
        local prevSize = self.PreMaximizeSize or Vector2.new(620, 440)
        local prevPos = self.PreMaximizePos or self.Position
        self:SetPosition(prevPos)
        self:SetSize(prevSize)
    end

    if not self.Minimized then
        self:SetVisible(self.Visible)
    end
    return self.IsMaximized
end
Window.ToggleFullscreen = Window.ToggleMaximize

function Window:SetVisible(visible)
    if self.Destroyed then return end
    local prevVisible = self.Visible
    self.Visible = visible

    if not visible then
        if self.OpenDropdown and self.OpenDropdown.Close then self.OpenDropdown:Close() end
        if self.OpenColorpicker and self.OpenColorpicker.Close then self.OpenColorpicker:Close() end
        if self.OpenKeybindMenu and self.OpenKeybindMenu.CloseModeMenu then self.OpenKeybindMenu:CloseModeMenu() end
        if self.CapturingKeybind and self.CapturingKeybind.CancelCapture then self.CapturingKeybind:CancelCapture() end
        if self.FocusedInput and self.FocusedInput.Blur then self.FocusedInput:Blur(false) end
    end

    local dis = self.DisabledTopbarButtons or {}
    local bodyVis = visible and not self.Minimized
    if self.FrameBg then self.FrameBg.Visible = visible end
    if self.BgImage then self.BgImage.Visible = bodyVis and (self.BgImageUrl ~= nil) end
    if self.Border then self.Border.Visible = visible end
    if self.MainPanelBg then self.MainPanelBg.Visible = bodyVis end
    if self.MacClose then self.MacClose.Visible = visible and not dis.Close end
    if self.MacMin then self.MacMin.Visible = visible and not dis.Minimize end
    if self.MacMax then self.MacMax.Visible = visible and not dis.Maximize end
    if self.HeaderIcon then self.HeaderIcon.Visible = visible and (self.Icon ~= nil and self.Icon ~= "" and self.Icon ~= false) end
    if self.TitleText then self.TitleText.Visible = visible end
    if self.BottomDragPill then self.BottomDragPill.Visible = bodyVis end
    if self.ResizeIcon then self.ResizeIcon.Visible = bodyVis and self.CanResize end

    self:_syncTagPositions()

    if self.Sidebar then
        self.Sidebar:SetVisible(bodyVis)
    end

    if self.ActiveTab then
        if bodyVis then
            self.ActiveTab:Show(self.Position)
        else
            self.ActiveTab:Hide()
        end
    end

    self:_syncScrollbar()
    self:_updateInputBlock()

    if visible and not prevVisible then
        for _, cb in ipairs(self._onOpenCallbacks or {}) do pcall(cb) end
    elseif not visible and prevVisible then
        for _, cb in ipairs(self._onCloseCallbacks or {}) do pcall(cb) end
    end
end

function Window:Toggle()
    self:SetVisible(not self.Visible)
end

function Window:OnOpen(cb)
    if type(cb) == "function" then table.insert(self._onOpenCallbacks, cb) end
end

function Window:OnClose(cb)
    if type(cb) == "function" then table.insert(self._onCloseCallbacks, cb) end
end

function Window:OnDestroy(cb)
    if type(cb) == "function" then table.insert(self._onDestroyCallbacks, cb) end
end

function Window:_refreshTitleText()
    if not self.TitleText then return end
    local maxTitleW = math.max(60, self.Size.X - 180)
    local fullTitle = (self.Subtitle and self.Subtitle ~= "" and self.Subtitle ~= "BreezeUI")
        and (self.Title .. "  |  " .. self.Subtitle)
        or tostring(self.Title)
    local fitTitle = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(fullTitle, maxTitleW, 13) or fullTitle
    self.TitleText.Text = fitTitle
    self.TitleEndOffset = (self.TitleOffset or 74) + math.floor(#fitTitle * 6.2)
    self:_syncTagPositions()
end

function Window:SetTitle(title)
    self.Title = tostring(title or "")
    self:_refreshTitleText()
end

function Window:SetAuthor(author)
    self.Subtitle = tostring(author or "")
    self:_refreshTitleText()
end

function Window:SetIconSize(sz)
    local n = math.clamp(tonumber(sz) or 16, 10, 28)
    if self.HeaderIcon then
        self.HeaderIcon.Size = Vector2.new(n, n)
    end
end

function Window:IsResizable(enabled)
    if enabled ~= nil then
        self.CanResize = enabled == true
        if self.ResizeIcon then
            self.ResizeIcon.Visible = self.Visible and not self.Minimized and self.CanResize
        end
    end
    return self.CanResize
end

function Window:SetToTheCenter()
    local vp = get_viewport()
    local cx = math.max(12, math.floor((vp.X - self.Size.X) * 0.5))
    local cy = math.max(36, math.floor((vp.Y - self.Size.Y) * 0.5))
    self:SetPosition(Vector2.new(cx, cy))
end

function Window:GetUIScale()
    return self.DPIScale or self.Scale or 1.0
end

function Window:LockAll()
    for _, tab in ipairs(self.Tabs) do
        for _, sec in ipairs(tab.Sections or {}) do
            for _, ctrl in ipairs(sec.Controls or {}) do
                if ctrl.Lock then ctrl:Lock() else ctrl.Locked = true end
            end
        end
    end
end

function Window:UnlockAll()
    for _, tab in ipairs(self.Tabs) do
        for _, sec in ipairs(tab.Sections or {}) do
            for _, ctrl in ipairs(sec.Controls or {}) do
                if ctrl.Unlock then ctrl:Unlock() else ctrl.Locked = false end
            end
        end
    end
end

function Window:GetLocked()
    local out = {}
    for _, tab in ipairs(self.Tabs) do
        for _, sec in ipairs(tab.Sections or {}) do
            for _, ctrl in ipairs(sec.Controls or {}) do
                if ctrl.Locked then table.insert(out, ctrl) end
            end
        end
    end
    return out
end

function Window:GetUnlocked()
    local out = {}
    for _, tab in ipairs(self.Tabs) do
        for _, sec in ipairs(tab.Sections or {}) do
            for _, ctrl in ipairs(sec.Controls or {}) do
                if not ctrl.Locked then table.insert(out, ctrl) end
            end
        end
    end
    return out
end

function Window:DisableTopbarButtons(btns)
    local list = type(btns) == "table" and btns or { btns }
    for _, b in ipairs(list) do
        local k = tostring(b):lower()
        if k == "close" or k == "exit" then self.DisabledTopbarButtons.Close = true
        elseif k == "min" or k == "minimize" then self.DisabledTopbarButtons.Minimize = true
        elseif k == "max" or k == "maximize" or k == "fullscreen" then self.DisabledTopbarButtons.Maximize = true end
    end
    if self.MacClose and self.DisabledTopbarButtons.Close then self.MacClose.Visible = false end
    if self.MacMin and self.DisabledTopbarButtons.Minimize then self.MacMin.Visible = false end
    if self.MacMax and self.DisabledTopbarButtons.Maximize then self.MacMax.Visible = false end
end

function Window:SetBackgroundImage(urlOrName)
    self.BgImageUrl = urlOrName
    if not urlOrName or urlOrName == "" then
        if self.BgImage then self.BgImage.Visible = false end
        return
    end
    if not self.BgImage and self.Pool then
        local img = self.Pool:Get("Image")
        img.Position = self.Position
        img.Size = Vector2.new(self.Size.X, self.Minimized and self.HeaderHeight or self.Size.Y)
        img.Transparency = 1 - (self.BgImageTransparency or 0.25)
        img.ZIndex = 1
        img.Visible = self.Visible and not self.Minimized
        self.BgImage = img
        self:_register(img)
    end
    if self.BgImage and IconsModule and IconsModule.Get then
        IconsModule.Get(urlOrName, function(png)
            if self.BgImage and png then
                self.BgImage.Data = png
                self.BgImage.Visible = self.Visible and not self.Minimized
            end
        end)
    end
end

function Window:SetBackgroundImageTransparency(alpha)
    alpha = math.clamp(tonumber(alpha) or 0, 0, 1)
    self.BgImageTransparency = alpha
    if self.BgImage then
        self.BgImage.Transparency = 1 - alpha
    end
end

function Window:SetBackgroundTransparency(alpha)
    self:SetTransparency(alpha)
end

function Window:ToggleTransparency(state)
    local isTransparent = (self.FrameTransparency or 0) > 0.05
    local target = state ~= nil and (state == true) or (not isTransparent)
    self:SetTransparency(target and 0.25 or 0)
end

function Window:SetCurrentConfig(name)
    local sm = (self.Env and self.Env.Settings)
    if sm and sm.Load then
        return sm.Load(name, self.Env)
    end
    return false
end

function Window:Popup(cfg)
    assert(DialogModule and DialogModule.Show, "Dialog subsystem not loaded!")
    return DialogModule.Show(cfg, self, "Popup")
end

function Window:Open()
    self:SetVisible(true)
end

function Window:Close()
    self:SetVisible(false)
end

function Window:_updateInputBlock(rbxFocused)
    local active = (rbxFocused ~= nil) and rbxFocused or ((type(isrbxactive) ~= "function") or (isrbxactive() == true))
    local shouldBlock = active and (self.Visible == true) and (not self.Minimized) and (not self.Destroyed) and (self.BlockRobloxInput == true)
    if shouldBlock == self._lastInputBlocked then return end
    setrobloxinput(not shouldBlock)
    -- Matcha requires a click after toggling setrobloxinput so the Roblox window updates input lock (Obsidian pattern)
    if active then
        task.spawn(function()
            task.wait(0.1)
            mouse1click()
        end)
    end
    self._lastInputBlocked = shouldBlock
end

function Window:SetInputBlocking(enabled)
    self.BlockRobloxInput = (enabled == true)
    self:_updateInputBlock()
end

function Window:EditOpenButton(cfg)
    if type(cfg) ~= "table" then return end
    local ob = self.OpenButton
    if not ob then return end
    if cfg.Enabled ~= nil then ob.Enabled = cfg.Enabled == true end
    if cfg.Title ~= nil then ob.Title = tostring(cfg.Title) end
    if cfg.Icon ~= nil then
        ob.Icon = cfg.Icon
        ob._lastIconName = nil
    end
    if cfg.Draggable ~= nil then ob.Draggable = cfg.Draggable == true end
    if cfg.OnlyIcon ~= nil then ob.OnlyIcon = cfg.OnlyIcon == true end
    if cfg.Position ~= nil then ob.Position = cfg.Position end
    if cfg.Color ~= nil then ob.Color = cfg.Color end
end

function Window:SetWatermark(text)
    if type(text) == "table" then
        self.Watermark.Tokens = text
        self.Watermark.Text = table.concat(text, " | ")
    else
        self.Watermark.Tokens = nil
        self.Watermark.Text = tostring(text or "")
    end
    self.Watermark.Visible = self.Watermark.Text ~= ""
end

function Window:SetWatermarkVisibility(visible)
    self.Watermark.Visible = visible == true
end

function Window:SetKeybindMenuVisible(state)
    self.ShowKeybindMenu = state == true
end

function Window:SetKeybindMenuPosition(x, y)
    self.KeybindMenuX = x
    self.KeybindMenuY = y
end

function Window:SetKeybindMenuWidth(w)
    self.KeybindMenuWidth = tonumber(w) or 240
end

-- Public theme setter: accepts a theme name string or palette table.
-- Calls ThemeModule.SetCurrent so all subscribers see the change, then propagates visuals.
function Window:SetTheme(nameOrPalette)
    if ThemeModule and ThemeModule.SetCurrent then
        ThemeModule.SetCurrent(nameOrPalette)
    end
    local resolved = (type(nameOrPalette) == "table" and nameOrPalette)
        or (ThemeModule and ThemeModule.GetTheme and ThemeModule.GetTheme(nameOrPalette))
        or {}
    self:UpdateTheme(resolved)
end

-- DPI scale: scales window size proportionally (80–200 %).
function Window:SetDPIScale(pct)
    local scale = math.clamp((tonumber(pct) or 100) / 100, 0.5, 2.0)
    self.DPIScale = scale
    self:SetScale(scale)
end

-- Window-level transparency (0 = fully opaque, 1 = fully transparent; Drawing Transparency = opacity = 1 - alpha).
function Window:SetTransparency(alpha)
    alpha = math.clamp(tonumber(alpha) or 0, 0, 1)
    self.FrameTransparency = alpha
    local opacity = 1 - alpha
    if self.FrameBg then self.FrameBg.Transparency = opacity end
    if self.MainPanelBg then self.MainPanelBg.Transparency = opacity end
end

-- Corner radius override for the main frame and panel.
function Window:SetCornerRadius(r)
    r = math.clamp(math.floor(tonumber(r) or 10), 0, 32)
    self.CornerRadius = r
    if self.FrameBg then self.FrameBg.Corner = r end
    if self.Border then self.Border.Corner = r end
    if self.MainPanelBg then self.MainPanelBg.Corner = r end
    if self.ActiveTab then
        self.ActiveTab._layoutDirty = true
    end
end

function Window:UpdateTheme(newTheme)
    local t = type(newTheme) == "table" and newTheme
        or (ThemeModule and ThemeModule.GetTheme and ThemeModule.GetTheme(newTheme))
        or (ThemeModule and ThemeModule.DefaultPalette)
        or {}

    self.Theme = type(newTheme) == "table" and (newTheme.Name or "Custom") or tostring(newTheme)
    self.ThemeTokens = t

    if IconsModule and IconsModule.SetDarkMode then
        IconsModule.SetDarkMode(self.Theme == "Light")
    end

    local bgCol = t.Background or get_theme_color("Window.Background", Color3.fromRGB(16, 16, 18))
    local borderCol = t.Border or get_theme_color("Window.Border", Color3.fromRGB(36, 36, 42))
    local panelCol = t.PanelBackground or get_theme_color("PanelBackground", Color3.fromRGB(22, 22, 26))
    local textCol = t.Text or get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))

    if self.FrameBg then self.FrameBg.Color = bgCol end
    if self.Border then self.Border.Color = borderCol end
    if self.MainPanelBg then self.MainPanelBg.Color = panelCol end
    if self.TitleText then self.TitleText.Color = textCol end
    if self.SubtitleText then
        self.SubtitleText.Color = t["Text.Secondary"] or t.SubText or get_theme_color("Text.Secondary", Color3.fromRGB(161, 161, 170))
    end
    if self.VerticalDivider then
        self.VerticalDivider.Color = t["Sidebar.Divider"] or t.Divider or borderCol
    end
    if self.TopbarDivider then
        self.TopbarDivider.Color = t["Sidebar.Divider"] or t.Divider or borderCol
    end
    if self.ScrollTrack then
        self.ScrollTrack.Color = t["Control.Background"] or get_theme_color("Control.Background", Color3.fromRGB(48, 48, 52))
    end
    if self.ScrollThumb then
        self.ScrollThumb.Color = t["Text.Muted"] or t.Border or get_theme_color("Text.Muted", Color3.fromRGB(161, 161, 161))
    end
    if self.BottomDragPill then
        self.BottomDragPill.Color = t["Control.Hover"] or t.Border or get_theme_color("Control.Hover", Color3.fromRGB(80, 82, 92))
    end

    for _, tag in ipairs(self.Tags or {}) do
        if not tag.CustomColor then
            local isLight = (self.Theme == "Light")
            if tag.Bg then
                tag.Bg.Color = isLight and Color3.fromRGB(52, 52, 58)
                    or (t["Control.Background"] or get_theme_color("Control.Background", Color3.fromRGB(48, 48, 52)))
            end
            if tag.Border then
                tag.Border.Color = isLight and Color3.fromRGB(72, 72, 80) or borderCol
            end
            if tag.Text then
                tag.Text.Color = isLight and Color3.fromRGB(245, 245, 250) or textCol
            end
        end
    end

    if self.Sidebar then
        self.Sidebar:UpdateTheme(t)
    end

    for _, tab in ipairs(self.Tabs) do
        if tab.UpdateTheme then
            tab:UpdateTheme(t)
        end
    end
end

function Window:SetScale(scale)
    scale = math.clamp(tonumber(scale) or 1, 0.5, 2.0)
    self.Scale = scale
    local base = self.BaseSize or self.Size
    self._applyingScale = true
    self:SetSize(Vector2.new(math.floor(base.X * scale + 0.5), math.floor(base.Y * scale + 0.5)))
    self._applyingScale = false
end

function Window:SetUIScale(scale)
    self:SetScale(scale)
end

function Window:SetToggleKey(key)
    if type(key) == "string" and MetricsModule and MetricsModule.KeyCode then
        self.ToggleKey = MetricsModule.KeyCode(key)
    else
        self.ToggleKey = key
    end
end

function Window:SetPanelBackground(enabled)
    if self.MainPanelBg then
        self.MainPanelBg.Visible = enabled ~= false and self.Visible and not self.Minimized
    end
end

function Window:Dialog(cfg)
    assert(DialogModule and DialogModule.Show, "Dialog subsystem not loaded!")
    return DialogModule.Show(cfg, self, "Dialog")
end

function Window:Tag(tagConfig)
    local cfg = type(tagConfig) == "table" and tagConfig or { Title = tostring(tagConfig or "") }
    local pool = self.Pool
    if not pool then return cfg end
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    local px = self.Position.X
    local py = self.Position.Y
    local sx = self.Size.X

    local tagTitle = tostring(cfg.Title or "Tag")
    local hasIcon = cfg.Icon ~= nil and cfg.Icon ~= ""
    local tagW = math.floor(#tagTitle * 6.2) + (hasIcon and 30 or 16)
    local tagH = 22
    local relX = math.min((self.TitleEndOffset or 220) + 12, sx - tagW - 14)
    local relY = 11
    local tagX = px + relX
    local tagY = py + relY

    local isLight = (self.Theme == "Light")
    local tagBgCol = cfg.Color or (isLight and Color3.fromRGB(52, 52, 58) or get_theme_color("Control.Background", Color3.fromRGB(48, 48, 52)))
    local bg = pool:Get("Square")
    bg.Position = Vector2.new(tagX, tagY)
    bg.Size = Vector2.new(tagW, tagH)
    bg.Color = tagBgCol
    bg.Filled = true
    bg.Corner = 11
    bg.ZIndex = 4
    bg.Visible = self.Visible
    self:_register(bg)

    local border = nil
    if cfg.Border ~= false then
        border = pool:Get("Square")
        border.Position = Vector2.new(tagX, tagY)
        border.Size = Vector2.new(tagW, tagH)
        border.Color = isLight and Color3.fromRGB(72, 72, 80) or get_theme_color("Window.Border", Color3.fromRGB(48, 48, 56))
        border.Filled = false
        border.Thickness = 1
        border.Corner = 11
        border.ZIndex = 5
        border.Visible = self.Visible
        self:_register(border)
    end

    local txt = pool:Get("Text")
    txt.Position = Vector2.new(tagX + (hasIcon and 24 or 8), tagY + 4)
    txt.Text = tagTitle
    txt.Font = fontUI
    txt.Outline = false
    txt.Size = 12
    txt.Color = isLight and Color3.fromRGB(245, 245, 250) or get_theme_color("Text.Title", Color3.fromRGB(240, 240, 245))
    txt.ZIndex = 6
    txt.Visible = self.Visible
    self:_register(txt)

    local ico = nil
    if hasIcon then
        ico = pool:Get("Image")
        ico.Position = Vector2.new(tagX + 7, tagY + 4)
        ico.Size = Vector2.new(13, 13)
        ico.ZIndex = 6
        ico.Transparency = 0.9
        ico.Visible = self.Visible
        self:_register(ico)
        if IconsModule and IconsModule.Get then
            IconsModule.Get(cfg.Icon, function(pngData)
                if ico and pngData then ico.Data = pngData end
            end)
        end
    end

    table.insert(self.Tags, {
        RelX = relX,
        RelY = relY,
        Width = tagW,
        Bg = bg,
        Border = border,
        Icon = ico,
        Text = txt,
    })

    return cfg
end

-- ============================================================================
-- Interaction Focus Gate & Clamping
-- ============================================================================

function Window:ClaimInteraction(widgetId)
    if self.FocusedWidget == nil or self.FocusedWidget == widgetId then
        self.FocusedWidget = widgetId
        self.ActiveInteraction = widgetId
        if self.Env and self.Env.ClaimInteraction then
            self.Env:ClaimInteraction(widgetId)
        end
        return true
    end
    return false
end

function Window:ReleaseInteraction(widgetId)
    if self.FocusedWidget == widgetId then
        self.FocusedWidget = nil
        self.ActiveInteraction = nil
        if self.Env and self.Env.ReleaseInteraction then
            self.Env:ReleaseInteraction(widgetId)
        end
    end
end

function Window:CanInteract(widgetId)
    return self.FocusedWidget == nil or self.FocusedWidget == widgetId
end

function Window:ClampAndSnap(pos, size, customViewport, customInsetTop)
    local curSize = size or self.Size
    local vp = customViewport or get_viewport()
    if not vp or vp.X <= 0 or vp.Y <= 0 then
        vp = Vector2.new(1920, 1080)
    end

    local topInsetY = customInsetTop or 36
    local minX = 0
    local maxX = math.max(0, vp.X - curSize.X)
    local minY = topInsetY
    local maxY = math.max(topInsetY, vp.Y - curSize.Y)

    local x = math.clamp(pos.X, minX, maxX)
    local y = math.clamp(pos.Y, minY, maxY)

    local snapThreshold = 16
    if math.abs(x - minX) <= snapThreshold then x = minX end
    if math.abs(x - maxX) <= snapThreshold then x = maxX end
    if math.abs(y - minY) <= snapThreshold then y = minY end
    if math.abs(y - maxY) <= snapThreshold then y = maxY end

    return Vector2.new(x, y)
end

-- ============================================================================
-- Runtime Update, Keyboard Capture, Animations & Destruction
-- ============================================================================

function Window:_getMouse()
    if self.Mouse then return self.Mouse end
    if not self._playersChecked and game and game.GetService then
        self._playersChecked = true
        local ok, players = pcall(game.GetService, game, "Players")
        if ok and players and players.LocalPlayer then
            self.Mouse = players.LocalPlayer:GetMouse()
            if self.Mouse then return self.Mouse end
        end
    end
    if type(getmouseposition) == "function" then
        return getmouseposition()
    end
    return nil
end

function Window:Update(rawDt)
    if self.Destroyed or not self.Running then return end
    local curState = UI.GetValue(UI_STATE_KEY)
    if curState == UI_STATE_UNLOAD or (self._uiStateToken and curState ~= self._uiStateToken) then
        self:Destroy()
        return
    end

    local rbxFocused = (type(isrbxactive) ~= "function") or (isrbxactive() == true)
    local dt = rawDt or 0.016
    if not rbxFocused then
        self._idleDt = (self._idleDt or 0) + dt
        if self._idleDt < (1 / 15) then return end
        dt = self._idleDt
        self._idleDt = 0
    else
        self._idleDt = 0
    end

    if AnimationsModule and AnimationsModule.Step then
        AnimationsModule.Step(dt)
    end

    local m1Pressed = rbxFocused and (type(ismouse1pressed) == "function") and (ismouse1pressed() == true)
    local m2Pressed = rbxFocused and (type(ismouse2pressed) == "function") and (ismouse2pressed() == true)
    local m1Clicked = m1Pressed and not self.PrevM1
    local m2Clicked = m2Pressed and not (self.PrevM2 == true)
    self.PrevM1 = m1Pressed
    self.PrevM2 = m2Pressed

    local mouse = self:_getMouse()
    if NotifyModule and NotifyModule.Update then
        if NotifyModule.Update(dt, self, mouse, m1Clicked) then
            m1Clicked = false
        end
    end

    if DialogModule and DialogModule.Update then
        if DialogModule.Update(dt, self, mouse, m1Clicked) then
            return
        end
    end

    if OverlayModule and OverlayModule.Update then
        if OverlayModule.Update(dt, self, mouse, m1Pressed, m1Clicked) then
            m1Clicked = false
        end
    end

    self:_updateInputBlock(rbxFocused)

    -- ToggleKey visibility / minimize hotkey (only when Roblox is focused)
    if rbxFocused and self.ToggleKey and self.Input and type(self.ToggleKey) == "number" then
        if self.Input:KeyPressed(self.ToggleKey) then
            if self.ToggleKeyMinimizes then
                if not self.Visible then
                    self:SetVisible(true)
                else
                    self:ToggleMinimize()
                end
            else
                self:SetVisible(not self.Visible)
            end
        end
    end

    if not self.Visible then return end

    if self.ActiveTab and self.ActiveTab._layoutDirty and self.ActiveTab.UpdateLayout then
        self.ActiveTab._layoutDirty = false
        self.ActiveTab:UpdateLayout(self.Position, self.Size)
    end

    -- Keybind capture mode or active Keybind listener
    if self.CapturingKeybind and self.Input then
        local elapsed = os.clock() - (self.CapturingKeybind.CaptureStarted or 0)
        -- Hold M1 for >= 1s while capturing clears the keybind back to nil ([?]), matching Obsidian
        if m1Pressed and elapsed >= 1.0 then
            self.CapturingKeybind:Clear()
            return
        end
        local captured = self.Input:ReadListenKey(m1Clicked, m2Clicked, elapsed)
        if captured then
            self.CapturingKeybind:ProcessInput(captured)
        end
        return
    elseif rbxFocused and self.Input and not self.FocusedDropdownSearch and not (self.Sidebar and self.Sidebar.SearchFocused) and not self.FocusedInput then
        for _, kb in ipairs(self.Keybinds or {}) do
            if not kb.Locked and type(kb.Key) == "number" then
                if kb.Mode == "Always" then
                    kb.ActiveState = true
                elseif kb.Mode == "Hold" then
                    local held = (type(iskeypressed) == "function") and (iskeypressed(kb.Key) == true)
                    if held ~= kb.ActiveState then
                        kb.ActiveState = held
                        if kb.Parent and kb.SyncToggleState and kb.Parent.Set then
                            kb.Parent:Set(held)
                        end
                        pcall(kb.Callback, held)
                    end
                elseif self.Input:KeyPressed(kb.Key) then
                    kb.ActiveState = not kb.ActiveState
                    if kb.Parent and kb.SyncToggleState and kb.Parent.Set then
                        kb.Parent:Set(kb.ActiveState)
                    end
                    pcall(kb.Callback, kb.ActiveState)
                end
            end
        end
    end

    -- Keyboard typing into Dropdown Search, Sidebar Search, or focused Input control
    if self.FocusedDropdownSearch then
        if self.FocusedDropdownSearch.RefreshSearchDisplay then
            self.FocusedDropdownSearch:RefreshSearchDisplay()
        end
        if self.Input then
            local token = self.Input:ReadTextInput()
            if token and self.FocusedDropdownSearch then
                self.FocusedDropdownSearch:ProcessSearchKey(token)
            end
        end
    elseif self.Sidebar and self.Sidebar.SearchFocused then
        if self.Input then
            local token = self.Input:ReadTextInput()
            if token then self.Sidebar:ProcessSearchKey(token) end
        end
        self.Sidebar:RefreshSearchDisplay()
    elseif self.FocusedInput then
        if self.Input then
            local token = self.Input:ReadTextInput()
            if token and self.FocusedInput then
                self.FocusedInput:ProcessKey(token)
            end
        end
        if self.FocusedInput then
            self.FocusedInput:_refreshDisplay()
        end
    end

    if not mouse then return end
    local mx = mouse.X
    local my = mouse.Y

    local px = self.Position.X
    local py = self.Position.Y
    local sx = self.Size.X
    local sy = self.Minimized and self.HeaderHeight or self.Size.Y

    -- 1. macOS Traffic Lights Hit-Tests
    local dis = self.DisabledTopbarButtons or {}
    local closeHover = (not dis.Close) and mx >= px + 14 and mx <= px + 29 and my >= py + 14 and my <= py + 29
    if closeHover then
        if self.MacClose then self.MacClose.Color = Color3.fromRGB(230, 75, 68) end
        if m1Clicked then
            if not self.IgnoreAlerts and DialogModule and DialogModule.Show then
                self:Dialog({
                    Title = "Close Window",
                    Content = "Do you want to close this window? You will not be able to open it again.",
                    Buttons = {
                        {
                            Title = "Cancel",
                            Variant = "Secondary",
                            Callback = function() end,
                        },
                        {
                            Title = "Close Window",
                            Variant = "Primary",
                            Callback = function()
                                self:Destroy()
                            end,
                        },
                    },
                })
            else
                self:Destroy()
            end
            return
        end
    else
        if self.MacClose then self.MacClose.Color = get_theme_color("Mac.Close", Color3.fromRGB(255, 95, 86)) end
    end

    local minHover = (not dis.Minimize) and mx >= px + 32 and mx <= px + 47 and my >= py + 14 and my <= py + 29
    if minHover then
        if self.MacMin then self.MacMin.Color = Color3.fromRGB(230, 165, 30) end
        if m1Clicked then
            self:ToggleMinimize()
            return
        end
    else
        if self.MacMin then self.MacMin.Color = get_theme_color("Mac.Minimize", Color3.fromRGB(255, 189, 46)) end
    end

    local maxHover = (not dis.Maximize) and mx >= px + 50 and mx <= px + 65 and my >= py + 14 and my <= py + 29
    if maxHover then
        if self.MacMax then self.MacMax.Color = Color3.fromRGB(28, 175, 50) end
        if m1Clicked then
            self:ToggleMaximize()
            return
        end
    else
        if self.MacMax then self.MacMax.Color = get_theme_color("Mac.Maximize", Color3.fromRGB(39, 201, 63)) end
    end

    -- 2. Bottom-Right Corner Resize Icon & Hit-Test (strictly disabled in Fullscreen & Minimized)
    local canResizeNow = (not self.Minimized) and (not self.IsMaximized) and (self.CanResize == true)
    local rx = px + sx - 18
    local ry = py + sy - 18
    local isResizeArea = canResizeNow and mx >= rx and mx <= px + sx + 16 and my >= ry and my <= py + sy + 16

    if self.ResizeIcon and not self.Minimized then
        AnimationsModule.TweenProp(self.ResizeIcon, "Transparency", (isResizeArea or self.IsResizing) and 0.78 or 0.25)
    end

    if self.IsResizing then
        if m1Pressed and canResizeNow then
            local delta = Vector2.new(mx - self.ResizeStartMouse.X, my - self.ResizeStartMouse.Y)
            local targetSize = Vector2.new(self.ResizeStartSize.X + delta.X, self.ResizeStartSize.Y + delta.Y)
            self:SetSize(targetSize)
        else
            self.IsResizing = false
            self:ReleaseInteraction("WindowResize")
        end
    elseif m1Clicked and isResizeArea and canResizeNow and self:CanInteract("WindowResize") then
        self.IsResizing = true
        self.ResizeStartMouse = Vector2.new(mx, my)
        self.ResizeStartSize = self.Size
        self:ClaimInteraction("WindowResize")
    end

    -- 2b. Scrollbar Thumb Dragging & Track Jump (dedicated 8px pill track)
    if self.ScrollThumb and self.ActiveTab and (self.ActiveTab.MaxScrollY or 0) > 0 and not self.Minimized then
        local trackTop = py + self.HeaderHeight + 10
        local trackH = math.max(40, sy - self.HeaderHeight - 28)
        local thumbH = self.ScrollThumb.Size.Y
        local thumbY = self.ScrollThumb.Position.Y
        local inGutter = mx >= px + sx - 26 and mx <= px + sx - 10
        local overThumb = inGutter and my >= thumbY - 4 and my <= thumbY + thumbH + 4
        local overTrack = inGutter and my >= trackTop and my <= trackTop + trackH
        AnimationsModule.TweenProp(self.ScrollThumb, "Transparency", (overThumb or overTrack or self.IsScrolling) and 0.85 or 0.28)

        if self.IsScrolling then
            if m1Pressed then
                local travel = math.max(1, trackH - thumbH)
                local ratio = math.clamp((my - (self.ScrollDragOffset or 0) - trackTop) / travel, 0, 1)
                self.ActiveTab.ScrollY = math.floor(ratio * self.ActiveTab.MaxScrollY + 0.5)
                self.ActiveTab:UpdateLayout(self.Position, self.Size)
                self:_syncScrollbar()
                return
            else
                self.IsScrolling = false
                self:ReleaseInteraction("WindowScroll")
            end
        elseif m1Clicked and (overThumb or overTrack) and not isResizeArea and self:CanInteract("WindowScroll") then
            self.IsScrolling = true
            if overThumb then
                self.ScrollDragOffset = my - thumbY
            else
                self.ScrollDragOffset = math.floor(thumbH * 0.5)
                local travel = math.max(1, trackH - thumbH)
                local ratio = math.clamp((my - self.ScrollDragOffset - trackTop) / travel, 0, 1)
                self.ActiveTab.ScrollY = math.floor(ratio * self.ActiveTab.MaxScrollY + 0.5)
                self.ActiveTab:UpdateLayout(self.Position, self.Size)
                self:_syncScrollbar()
            end
            self:ClaimInteraction("WindowScroll")
            return
        end
    elseif self.IsScrolling then
        self.IsScrolling = false
        self:ReleaseInteraction("WindowScroll")
    end

    -- 3. Window Dragging (WindUI 1:1: Topbar OR Bottom Drag Pill; disabled in Fullscreen via DragModule:Set(false))
    local canDragNow = (self.Draggable ~= false) and (not self.DragModule or self.DragModule.CanDraggable ~= false)
    local pillX = px + math.floor((sx - 168) * 0.5)
    local isBottomPill = canDragNow and (not self.Minimized) and mx >= pillX - 6 and mx <= pillX + 174 and my >= py + sy and my <= py + sy + 16
    local isHeader = canDragNow and mx >= px + 70 and mx <= px + sx - 10 and my >= py and my <= py + self.HeaderHeight

    if self.BottomDragPill and not self.Minimized then
        AnimationsModule.TweenProp(self.BottomDragPill, "Transparency", (isBottomPill or self.IsDragging) and 0.72 or 0.25)
    end

    if self.IsDragging then
        if m1Pressed and canDragNow then
            local dx = mx - self.DragStart.X
            local dy = my - self.DragStart.Y
            if math.abs(dx) > 3 or math.abs(dy) > 3 then
                self.LastPillClick = -10
            end
            local newPos = self:ClampAndSnap(
                Vector2.new(self.DragStartPos.X + dx, self.DragStartPos.Y + dy),
                Vector2.new(self.Size.X, sy)
            )
            self:SetPosition(newPos)
        else
            self.IsDragging = false
            self:ReleaseInteraction("WindowDrag")
        end
    elseif m1Clicked and (isHeader or isBottomPill) and not isResizeArea and self:CanInteract("WindowDrag") then
        if isBottomPill then
            local now = os.clock()
            if (now - self.LastPillClick) < 0.4 then
                self:SetToTheCenter()
                self.LastPillClick = -10
                return
            end
            self.LastPillClick = now
        end

        self.IsDragging = true
        self.DragStart = Vector2.new(mx, my)
        self.DragStartPos = self.Position
        self:ClaimInteraction("WindowDrag")
    end

    if self.Minimized then return end

    -- 4. Open Colorpicker, Dropdown & Keybind Mode Menu Priority Capture
    if self.OpenKeybindMenu and self.OpenKeybindMenu.ModeMenuOpen then
        if self.OpenKeybindMenu:UpdateModeMenu(mx, my, m1Clicked, m2Clicked) then
            return
        end
    end

    if self.OpenColorpicker and self.OpenColorpicker.IsOpen then
        if self.OpenColorpicker:UpdatePopupInput(mx, my, m1Pressed, m1Clicked) then
            return
        end
    end

    if self.OpenDropdown and self.OpenDropdown.Opened and self.OpenDropdown.PopupRect then
        local dd = self.OpenDropdown
        local r = dd.PopupRect
        local st = r.ScrollTrack
        local overScroll = st and mx >= st.X and mx <= st.X + st.W and my >= st.Y and my <= st.Y + st.H
        if dd.PopupScrollThumb then
            AnimationsModule.TweenProp(dd.PopupScrollThumb, "Transparency", (overScroll or dd.IsScrollingPopup) and 0.85 or 0.28)
        end
        if dd.IsScrollingPopup then
            if m1Pressed and st then
                local travel = math.max(1, st.H - st.ThumbH)
                local ratio = math.clamp((my - st.Y - st.ThumbH * 0.5) / travel, 0, 1)
                dd:SetScrollRatio(ratio)
                return
            else
                dd.IsScrollingPopup = false
            end
        end
        local overPopup = mx >= r.X and mx <= r.X + r.W and my >= r.Y and my <= r.Y + r.H
        if overPopup then
            if st and mx >= st.X and mx <= st.X + st.W and my >= st.Y and my <= st.Y + st.H then
                dd:SetPopupHover(nil)
                if m1Clicked then
                    dd.IsScrollingPopup = true
                    local travel = math.max(1, st.H - st.ThumbH)
                    local ratio = math.clamp((my - st.Y - st.ThumbH * 0.5) / travel, 0, 1)
                    dd:SetScrollRatio(ratio)
                    return
                end
            end
            local sr = r.SearchRect
            if sr and mx >= sr.X and mx <= sr.X + sr.W and my >= sr.Y and my <= sr.Y + sr.H then
                dd:SetPopupHover(nil)
                if m1Clicked then
                    self.FocusedDropdownSearch = dd
                    if dd.RefreshSearchDisplay then dd:RefreshSearchDisplay() end
                    return
                end
            else
                local listTop = r.ListTop or (r.Y + 4)
                local idx = math.floor((my - listTop) / r.ItemH) + 1
                if idx >= 1 and idx <= r.Count then
                    dd:SetPopupHover(idx)
                    if m1Clicked then
                        local realIdx = (dd.ScrollOffset or 0) + idx
                        local chosen = dd.VisibleItems and dd.VisibleItems[realIdx] or dd.Values[realIdx]
                        if chosen then dd:Select(chosen) end
                        return
                    end
                else
                    dd:SetPopupHover(nil)
                end
            end
        else
            dd:SetPopupHover(nil)
            if m1Clicked then
                dd:Close()
            end
        end
    end

    -- 5. Sidebar Search, ProfileCard & Navigation
    if self.Sidebar and self.Sidebar.Visible then
        local sb = self.Sidebar
        if sb.ProfileCard and sb.ProfileCard:Update(mx, my, m1Clicked, dt) then
            return
        end
        local sbx, sby = px + 10, py + 46
        local sbw, sbh = self.SidebarWidth - 20, 28
        local overSearch = mx >= sbx and mx <= sbx + sbw and my >= sby and my <= sby + sbh
        if m1Clicked then
            if overSearch then
                sb:FocusSearch()
            elseif sb.SearchFocused then
                sb:BlurSearch()
            end
        end

        for _, sec in ipairs(sb.Sections or {}) do
            if sec.Visible then
                local hx = px + sec.RelX
                local hy = py + sec.RelY
                local hw = self.SidebarWidth - 20
                local hh = sec.HeaderHeight or 26
                if mx >= hx and mx <= hx + hw and my >= hy and my <= hy + hh then
                    if m1Clicked then
                        sec:Toggle()
                    end
                end
            end
        end

        for _, tab in ipairs(sb.Tabs or {}) do
            if tab.SidebarVisible and (not tab.ParentSection or tab.ParentSection.Opened or sb.SearchQuery ~= "") then
                local tx = px + tab.RelX
                local ty = py + tab.RelY
                local tw = tab.Width or (self.SidebarWidth - 20)
                local th = tab.Height or 32
                local hovered = mx >= tx and mx <= tx + tw and my >= ty and my <= ty + th
                tab:SetHovered(hovered)
                if hovered and m1Clicked then
                    self:SelectTab(tab)
                end
            end
        end
    end

    -- 6. Active Tab Controls, Tooltips & Blurs
    local clickedFocusedInput = false
    local hoverTip = nil
    local activeCards = self.ActiveTab and (self.ActiveTab.Sections or self.ActiveTab.Cards)
    if activeCards then
        for _, card in ipairs(activeCards) do
            if self.Destroyed or not self.Running then return end
            if card.Visible and card.HandleHeaderClick and m1Clicked then
                if card:HandleHeaderClick(mx, my) then
                    if self.Destroyed or not self.Running then return end
                    if self.ActiveTab then
                        self.ActiveTab:UpdateLayout(self.Position, self.Size)
                        self.ActiveTab._layoutDirty = false
                    end
                    self:_syncScrollbar()
                    return
                end
            end
            if card.Visible and card.Controls then
                for _, ctrl in ipairs(card.Controls) do
                    if self.Destroyed or not self.Running then return end
                    if ctrl.Visible and ctrl.Indeterminate and ctrl.Update then
                        ctrl:Update(dt or 0.016)
                    end
                    if ctrl.Visible and ctrl.Position and ctrl.Size then
                        local cx = ctrl.Position.X
                        local cy = ctrl.Position.Y
                        local cw = ctrl.Size.X
                        local ch = ctrl.Size.Y
                        local hovered = mx >= cx and mx <= cx + cw and my >= cy and my <= cy + ch

                        if hovered then
                            if ctrl.Locked then
                                hoverTip = ctrl.LockedTitle or ctrl.Tooltip or "Locked"
                            elseif ctrl.Tooltip then
                                hoverTip = ctrl.Tooltip
                            end
                        end

                        if ctrl._copiedUntil and os.clock() >= ctrl._copiedUntil then
                            ctrl._copiedUntil = nil
                            if ctrl._setCopyLabel then ctrl:_setCopyLabel("Copy") end
                        end

                        if not ctrl.Locked then
                            -- Inline KeyPicker hit-test (M1 = bind key, M2 = Toggle/Hold/Always menu)
                            if ctrl.KeyPicker then
                                local kp = ctrl.KeyPicker
                                local kpx, kpy = kp.Position.X, kp.Position.Y
                                local kpw, kph = kp.Size.X, kp.Size.Y
                                if mx >= kpx and mx <= kpx + kpw and my >= kpy and my <= kpy + kph then
                                    if m1Clicked and kp.StartCapture then
                                        kp:StartCapture()
                                        hovered = false
                                    elseif m2Clicked and kp.OpenModeMenu then
                                        kp:OpenModeMenu()
                                        hovered = false
                                    end
                                end
                            end

                            if ctrl.Track and ctrl.FillBar and ctrl.Drag then
                                local tx = ctrl.Track.Position.X
                                local tw = ctrl.Track.Size.X
                                local trackHover = mx >= tx - 8 and mx <= tx + tw + 8 and my >= cy and my <= cy + ch
                                if ctrl._dragging then
                                    if m1Pressed then
                                        local ratio = math.clamp((mx - tx) / tw, 0, 1)
                                        ctrl:Drag(ratio)
                                    else
                                        ctrl._dragging = false
                                        self:ReleaseInteraction("Slider_" .. tostring(ctrl))
                                    end
                                elseif m1Clicked and trackHover and self:CanInteract("Slider_" .. tostring(ctrl)) then
                                    ctrl._dragging = true
                                    self:ClaimInteraction("Slider_" .. tostring(ctrl))
                                    local ratio = math.clamp((mx - tx) / tw, 0, 1)
                                    ctrl:Drag(ratio)
                                end
                            elseif ctrl.InputText and ctrl.Focus then
                                if hovered and m1Clicked and self:CanInteract("Input_" .. tostring(ctrl)) then
                                    ctrl:Focus()
                                    clickedFocusedInput = true
                                elseif ctrl.Focused and hovered then
                                    clickedFocusedInput = true
                                end
                            elseif ctrl.SwitchPill and ctrl.Click then
                                if hovered and m1Clicked and self:CanInteract("Toggle_" .. tostring(ctrl)) then
                                    if ctrl.KeyPicker and ctrl.KeyPicker.Mode == "Always" then
                                        if not ctrl.Value and ctrl.Set then ctrl:Set(true) end
                                    else
                                        ctrl:Click()
                                    end
                                    if self.Destroyed or not self.Running then return end
                                    if self.ActiveTab then self.ActiveTab._layoutDirty = true end
                                end
                            elseif ctrl.Standalone and ctrl.BadgeBg and ctrl.HandleClick then
                                if hovered and m1Clicked then
                                    ctrl:HandleClick(mx, my)
                                elseif hovered and m2Clicked and ctrl.OpenModeMenu then
                                    ctrl:OpenModeMenu()
                                end
                            elseif ctrl.Visual and ctrl.HandleClick and not ctrl.SwitchPill then
                                if hovered and m1Clicked then
                                    ctrl:HandleClick(mx, my)
                                    if self.Destroyed or not self.Running then return end
                                end
                            elseif ctrl.Visual and ctrl.Click and not ctrl.SwitchPill then
                                if hovered and m1Clicked then
                                    ctrl:Click()
                                    if self.Destroyed or not self.Running then return end
                                    if self.ActiveTab then self.ActiveTab._layoutDirty = true end
                                end
                            elseif ctrl.IsOpen ~= nil and ctrl.Toggle then
                                if hovered and m1Clicked then
                                    ctrl:Toggle()
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if OverlayModule and OverlayModule.RenderTooltip then
        OverlayModule.RenderTooltip((not m1Pressed) and hoverTip or nil, mx, my, self)
    end

    if m1Clicked and self.FocusedInput and not clickedFocusedInput then
        self.FocusedInput:Blur(false)
    end
end

function Window:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self.Running = false
    self.IsDragging = false
    self.IsResizing = false
    self.FocusedWidget = nil
    self.ActiveInteraction = nil
    self.FocusedInput = nil
    self.FocusedDropdownSearch = nil
    self.OpenDropdown = nil
    self.OpenColorpicker = nil
    self.CapturingKeybind = nil
    self.Keybinds = {}
    if IconsModule and IconsModule.ClearSubscribers then
        IconsModule.ClearSubscribers()
    end
    local curState = UI.GetValue(UI_STATE_KEY)
    if curState == UI_STATE_UNLOAD or (self._uiStateToken and curState == self._uiStateToken) then
        UI.SetValue(UI_STATE_KEY, UI_STATE_EMPTY)
    end

    for _, cb in ipairs(self._onDestroyCallbacks or {}) do
        pcall(cb)
    end
    self._onDestroyCallbacks = {}
    self._onOpenCallbacks = {}
    self._onCloseCallbacks = {}

    if self.Env then
        if self.RegisteredIds then
            if self.Env.Toggles and self.RegisteredIds.Toggles then
                for togId in pairs(self.RegisteredIds.Toggles) do
                    rawset(self.Env.Toggles, togId, nil)
                    if self.Env._rawToggles then
                        self.Env._rawToggles[togId] = nil
                    end
                    if self.Env._initialDefaults and self.Env._initialDefaults.Toggles then
                        self.Env._initialDefaults.Toggles[togId] = nil
                    end
                end
            end
            if self.Env.Options and self.RegisteredIds.Options then
                for optId in pairs(self.RegisteredIds.Options) do
                    rawset(self.Env.Options, optId, nil)
                    if self.Env._rawOptions then
                        self.Env._rawOptions[optId] = nil
                    end
                    if self.Env._initialDefaults and self.Env._initialDefaults.Options then
                        self.Env._initialDefaults.Options[optId] = nil
                    end
                end
            end
        end
        if self.Env._activeWindow == self then
            self.Env._activeWindow = nil
        end
        if self.Env._windows then
            for i = #self.Env._windows, 1, -1 do
                if self.Env._windows[i] == self then
                    table.remove(self.Env._windows, i)
                end
            end
        end
    end

    if self.RenderConnection then
        self.RenderConnection:Disconnect()
        self.RenderConnection = nil
    end
    if self.ScrollConnection then
        self.ScrollConnection:Disconnect()
        self.ScrollConnection = nil
    end

    if self.Sidebar and self.Sidebar.Destroy then
        self.Sidebar:Destroy()
    end

    for _, tab in ipairs(self.Tabs or {}) do
        if tab and tab.Destroy then
            tab:Destroy()
        end
    end

    if self.Pool and self.Pool.Destroy then
        self.Pool:Destroy()
        self.Pool = nil
    end

    if (not self.Env or not self.Env._windows or #self.Env._windows == 0) then
        if AnimationsModule and AnimationsModule.Reset then AnimationsModule.Reset() end
        if NotifyModule and NotifyModule.Destroy then NotifyModule.Destroy() end
        if DialogModule and DialogModule.Destroy then DialogModule.Destroy() end
        if OverlayModule and OverlayModule.Destroy then OverlayModule.Destroy() end
    end
    if self._lastInputBlocked then
        setrobloxinput(true)
        self._lastInputBlocked = false
    end

    self.Drawings = {}
    self._drawings = {}
    self.Sections = {}
    self.Tabs = {}
    self.Cards = {}
    self.Tags = {}
    self.ActiveTab = nil
    self.Sidebar = nil
end

return Window

end)()

-- ============================================================================
-- ROOT INIT & PUBLIC EXPORTS
-- ============================================================================
-- Library/BreezeUI/Init.lua
-- Main entry point and public API export for the BreezeUI Drawing UI Library.






local BreezeUI = {}

-- State registries with fail-fast proxies (Rules 2 & 3: single central gate, no silent fallback)
local rawOptions = {}
local rawToggles = {}
local initialDefaults = { Options = {}, Toggles = {} }
local profiles = {}

local OptionsProxy = setmetatable({}, {
    __index = function(tbl, k)
        local raw = rawget(tbl, k)
        if raw ~= nil then return raw end
        if rawOptions[k] ~= nil then return rawOptions[k] end
        assert(false, string.format("Option '%s' not found! (Option does not exist)", tostring(k)))
    end,
    __newindex = function(tbl, k, v)
        if rawOptions[k] ~= nil then
            rawOptions[k]:Set(v)
            return
        end
        local raw = rawget(tbl, k)
        if raw ~= nil and type(raw) == "table" and raw.Set then
            raw:Set(v)
            return
        end
        assert(false, string.format("Cannot assign unregistered Option '%s'!", tostring(k)))
    end
})

local TogglesProxy = setmetatable({}, {
    __index = function(tbl, k)
        local raw = rawget(tbl, k)
        if raw ~= nil then return raw end
        if rawToggles[k] ~= nil then return rawToggles[k] end
        assert(false, string.format("Toggle '%s' not found! (Toggle does not exist)", tostring(k)))
    end,
    __newindex = function(tbl, k, v)
        if rawToggles[k] ~= nil then
            rawToggles[k]:Set(v)
            return
        end
        local raw = rawget(tbl, k)
        if raw ~= nil and type(raw) == "table" and raw.Set then
            raw:Set(v)
            return
        end
        assert(false, string.format("Cannot assign unregistered Toggle '%s'!", tostring(k)))
    end
})

-- Shared properties and submodules
BreezeUI._windows = {}
local prevOrphans = type(_G) == "table" and rawget(_G, "__BreezeUI_OrphanWindows")
if type(prevOrphans) == "table" then
    for _, oldWin in ipairs(prevOrphans) do
        if oldWin and not oldWin.Destroyed and oldWin.Destroy then
            oldWin:Destroy()
        end
    end
end
if type(_G) == "table" and not (table and table.isfrozen and table.isfrozen(_G)) then
    rawset(_G, "__BreezeUI_OrphanWindows", BreezeUI._windows)
end

BreezeUI.Options = OptionsProxy
BreezeUI.Toggles = TogglesProxy
BreezeUI._rawOptions = rawOptions
BreezeUI._rawToggles = rawToggles
BreezeUI._initialDefaults = initialDefaults
BreezeUI._defaults = { options = {}, toggles = {} }
BreezeUI._profiles = profiles

BreezeUI.Pool = PoolModule
BreezeUI.Meta = MetaModule
BreezeUI.Geometry = GeometryModule
BreezeUI.Metrics = MetricsModule
BreezeUI.Theme = ThemeModule
BreezeUI.Window = WindowModule
BreezeUI.Sidebar = SidebarModule
BreezeUI.Tab = TabModule
BreezeUI.ContentSection = ContentSectionModule

BreezeUI.Clamping = ClampingModule
BreezeUI.Drag = DragModule
BreezeUI.Animations = AnimationsModule
BreezeUI.AnimationEngine = AnimationsModule
BreezeUI.InputHandler = InputHandlerModule
BreezeUI.Icons = IconsModule
BreezeUI.IconSubsystem = IconsModule
BreezeUI.Settings = SettingsModule
BreezeUI.NotifySubsystem = NotifyModule
BreezeUI.DialogSubsystem = DialogModule
BreezeUI.OverlaySubsystem = OverlayModule
BreezeUI.ThemeManager = ThemeModule
BreezeUI.SaveManager = SettingsModule
BreezeUI.UnloadCallbacks = {}

BreezeUI.Components = {
    Toggle = ToggleModule,
    Button = ButtonModule,
    Slider = SliderModule,
    Dropdown = DropdownModule,
    Input = InputModule,
    Keybind = KeybindModule,
    Paragraph = ParagraphModule,
    Code = CodeModule,
    Image = ImageModule,
    ProgressBar = ProgressBarModule,
    Colorpicker = ColorpickerModule,
}

BreezeUI.Scale = 1.0
BreezeUI.Version = "1.6.62"
BreezeUI.Creator = { AddIcons = function() end }
BreezeUI.FocusedWidget = nil
BreezeUI.ActiveAnimations = {}
BreezeUI.TargetFPS = 60
BreezeUI.IdleTimer = 0
BreezeUI.IdleTimeout = 1.0
BreezeUI._activeWindow = nil
BreezeUI.Destroyed = false
BreezeUI._destroyed = false

function BreezeUI:Notify(cfg, title, duration)
    if type(cfg) == "table" and not cfg.Side and self._activeWindow and self._activeWindow.NotifySide then
        cfg.Side = self._activeWindow.NotifySide
    end
    return NotifyModule.Push(cfg, title, duration)
end

function BreezeUI:Progress(title, message, duration)
    return NotifyModule.Progress(title, message, duration)
end

function BreezeUI:Update(dt)
    if self._activeWindow and not self._activeWindow.Destroyed then
        self._activeWindow:Update(dt)
    else
        NotifyModule.Update(dt or 0.016, nil)
        DialogModule.Update(dt or 0.016, nil)
    end
end

function BreezeUI:SetWatermark(text)
    if type(text) == "table" then
        self.WatermarkTokens = text
        self.WatermarkText = table.concat(text, " | ")
    else
        self.WatermarkTokens = nil
        self.WatermarkText = tostring(text or "")
    end
    self.WatermarkVisible = self.WatermarkText ~= ""
    if self._activeWindow and self._activeWindow.SetWatermark then
        self._activeWindow:SetWatermark(text)
    end
end

function BreezeUI:SetWatermarkVisibility(visible)
    self.WatermarkVisible = visible == true
    if self._activeWindow and self._activeWindow.SetWatermarkVisibility then
        self._activeWindow:SetWatermarkVisibility(visible)
    end
end

function BreezeUI:SetKeybindMenuVisible(state)
    self.ShowKeybindMenu = state == true
    if self._activeWindow and self._activeWindow.SetKeybindMenuVisible then
        self._activeWindow:SetKeybindMenuVisible(state)
    end
end

function BreezeUI:SetInputBlocking(state)
    self.BlockRobloxInput = state == true
    if self._activeWindow and self._activeWindow.SetInputBlocking then
        self._activeWindow:SetInputBlocking(state)
    end
end

function BreezeUI:Toggle(state)
    local win = self._activeWindow
    if win and not win.Destroyed and win.SetVisible then
        local target = state ~= nil and (state == true) or (not win.Visible)
        win:SetVisible(target)
    end
end

function BreezeUI:OnUnload(cb)
    if type(cb) == "function" then
        table.insert(self.UnloadCallbacks, cb)
    end
end

function BreezeUI:Unload()
    for _, cb in ipairs(self.UnloadCallbacks) do
        pcall(cb)
    end
    self.UnloadCallbacks = {}
    self:Destroy()
end

function BreezeUI:Popup(cfg)
    return DialogModule.Show(cfg, self._activeWindow, "Popup")
end

-- Link lastEnv for Settings
SettingsModule._lastEnv = BreezeUI

-- Interaction Locking API
function BreezeUI:ClaimInteraction(widgetId)
    if self.FocusedWidget == nil or self.FocusedWidget == widgetId then
        self.FocusedWidget = widgetId
        self.TargetFPS = 60
        self.IdleTimer = 0
        AnimationsModule.CurrentFocusedWidget = widgetId
        return true
    end
    return false
end

function BreezeUI:ReleaseInteraction(widgetId)
    if self.FocusedWidget == widgetId then
        self.FocusedWidget = nil
        AnimationsModule.CurrentFocusedWidget = nil
    end
end

function BreezeUI:CanInteract(widgetId)
    return self.FocusedWidget == nil or self.FocusedWidget == widgetId
end

-- Clamping & Snapping API
function BreezeUI:ClampAndSnap(pos, size, customViewport, customInsetTop)
    return ClampingModule.ClampAndSnap(pos, size, customViewport, customInsetTop)
end

-- Animation Delegation API
function BreezeUI:RegisterAnimation(id, animConfig)
    AnimationsModule.RegisterAnimation(id, animConfig)
end

function BreezeUI:NotifyInput()
    AnimationsModule.NotifyInput()
end

function BreezeUI:GetActiveAnimationCount()
    return AnimationsModule.GetActiveAnimationCount()
end

function BreezeUI:StepAnimations(dt)
    return AnimationsModule.Step(dt)
end

-- Theme & Scaling API
function BreezeUI:SetTheme(themeName)
    if ThemeModule and ThemeModule.SetCurrent then
        ThemeModule.SetCurrent(themeName)
    end
    local theme = type(themeName) == "table" and themeName
        or (ThemeModule.GetTheme and ThemeModule.GetTheme(themeName))
        or themeName
    self.CurrentTheme = theme
    for _, win in ipairs(self._windows) do
        if not win.Destroyed and win.UpdateTheme then
            win:UpdateTheme(theme)
        end
    end
end

function BreezeUI:SetScale(scale)
    self.Scale = scale
    for _, win in ipairs(self._windows) do
        if not win.Destroyed and win.SetScale then
            win:SetScale(scale)
        end
    end
end

-- Theme enumeration (includes Light theme with dark icon set)
function BreezeUI:GetThemes()
    return {
        "Dark", "Light", "Rose", "Plant", "Red", "Indigo", "Sky", "Violet",
        "Amber", "Emerald", "Midnight", "Crimson", "MonokaiPro", "CottonCandy",
        "Mellowsi", "Rainbow", "Slate", "Ruby",
    }
end

-- Notify side helper (delegates to NotifyModule)
function BreezeUI:SetNotifySide(side)
    if NotifyModule and NotifyModule.SetSide then
        NotifyModule.SetSide(side)
    end
    if self._activeWindow then
        self._activeWindow.NotifySide = side
    end
end

-- Settings tab builder: creates a fully-wired Settings tab on the given window.
function BreezeUI:SetupSettingsTab(win)
    assert(win and not win.Destroyed, "SetupSettingsTab: window must be a live Window instance!")
    return SettingsModule.BuildTab(win)
end

-- Window Construction
function BreezeUI:CreateWindow(config)
    self.Destroyed = false
    self._destroyed = false

    -- Auto-close previous active window to prevent stacked ghost drawings
    if self._activeWindow and not self._activeWindow.Destroyed then
        self._activeWindow:Destroy()
    end

    -- Cross-VM Matcha UI handshake: overwriting token immediately supersedes any prior running VM (and recovers cleanly from Lua VM resets)
    local uiStateToken = "running:" .. tostring(os.clock()) .. ":" .. tostring(math.random(1000, 9999))
    UI.SetValue("breeze_ui_state", uiStateToken)

    assert(type(config) == "table", "CreateWindow requires configuration table!")
    if config.Folder and config.Folder ~= "" then
        SettingsModule.SetFolder(config.Folder)
    end
    config = config or {}

    config.Env = self
    local win = WindowModule.new(config)
    win._uiStateToken = uiStateToken
    self._activeWindow = win
    table.insert(self._windows, win)
    return win
end

-- Destruction
function BreezeUI:Destroy()
    self.Destroyed = true
    self._destroyed = true
    for _, win in ipairs(self._windows) do
        if win.Destroy then
            win:Destroy()
        end
    end
    self._windows = {}
    self._activeWindow = nil

    for k in pairs(rawOptions) do rawOptions[k] = nil end
    for k in pairs(rawToggles) do rawToggles[k] = nil end

    if AnimationsModule.Reset then
        AnimationsModule.Reset()
    end
    if NotifyModule and NotifyModule.Destroy then
        NotifyModule.Destroy()
    end
    if DialogModule and DialogModule.Destroy then
        DialogModule.Destroy()
    end
    if OverlayModule and OverlayModule.Destroy then
        OverlayModule.Destroy()
    end
    if IconsModule.ClearCache then
        IconsModule.ClearCache()
    end
end

-- Export global library handle for scripts running inside Matcha
pcall(function()
    if _G and not table.isfrozen(_G) then
        _G.BreezeUI = _G.BreezeUI or {}
        _G.BreezeUI["Library.lua"] = BreezeUI
        _G.BreezeUI.Library = BreezeUI
        _G.BreezeUI.ThemeManager = BreezeUI.Theme
        _G.BreezeUI.SaveManager = BreezeUI.Settings
        _G.BreezeUI.Options = BreezeUI.Options
        _G.BreezeUI.Toggles = BreezeUI.Toggles
        _G.BreezeUI.Get = function()
            return BreezeUI, BreezeUI.Theme, BreezeUI.Settings
        end
        setmetatable(_G.BreezeUI, {
            __call = function()
                return BreezeUI, BreezeUI.Theme, BreezeUI.Settings
            end,
            __index = BreezeUI,
        })
        _G.Library = BreezeUI
        _G.WindUI = _G.BreezeUI
    end
end)

return BreezeUI