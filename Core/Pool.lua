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
    elseif kind == "Image" then
        obj.Rounding = 0
        obj.Color = Color3.fromRGB(255, 255, 255)
    end

    if not obj.Visible then
        obj.Visible = true
    end
    local meta = self.Meta
    if meta then
        if meta.Get then
            local entry = meta.Get(obj)
            if entry then
                entry.Kind = kind
            end
        end
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
