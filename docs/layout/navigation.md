# Navigation & Dynamic Visibility

## Sidebar Sections & Tabs

```lua
local Sec = Window:Section({ Title = "Main", Opened = true })
local Tab = Sec:Tab({
    Title = "Combat",
    Icon = "swords",
    IconColor = Color3.fromRGB(239, 68, 68), -- optional colored badge
    IconShape = "Square",                    -- "Square" or "Circle"
})
```

Collapsed sections automatically highlight their title when the active tab is inside them.

## Content Sections

```lua
local Box = Tab:Section({ Title = "Aimbot", Box = true, Opened = true })
```

Side-by-side columns are supported by sharing a `Group` key:

```lua
local Left = Tab:Section({ Title = "Left", Box = true, Group = "Row1" })
local Right = Tab:Section({ Title = "Right", Box = true, Group = "Row1" })
```

## Dynamic Element Visibility

Every element supports runtime visibility toggling with automatic layout reflow:

```lua
elem:Hide()
elem:Show()
elem:SetHidden(not enabled)
```
