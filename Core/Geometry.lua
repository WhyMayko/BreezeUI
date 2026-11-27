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
    local metrics = Metrics or require("./Metrics")
    if metrics then
        return metrics.GetTextWidth(text, size, scale)
    end
    return #tostring(text or "") * ((size or 14) * 0.5)
end

return geometry
