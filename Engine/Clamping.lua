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
