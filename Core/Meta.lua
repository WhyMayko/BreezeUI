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
