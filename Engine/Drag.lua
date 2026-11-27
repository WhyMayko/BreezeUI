-- Library/BreezeUI/Engine/Drag.lua
-- Obsidian-style window titlebar dragging with interaction isolation and boundary snapping.

local Clamping = require("./Clamping")

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
