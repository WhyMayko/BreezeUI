# Elements Reference

All elements live inside a `ContentSection` created from a `Tab`:

```lua
local Tab = Section:Tab({
    Title = "Combat",
    Icon = "crosshair",
    IconShape = "Square",
    IconColor = Color3.fromRGB(239, 68, 68),
})

local Card = Tab:Section({
    Title = "Aim & Controls",
    Box = false,      -- true draws a bordered card container
    Opened = true,    -- false creates a collapsible section
})
```

## Controls

### Toggle & Checkbox
```lua
local Tog = Card:AddToggle("AimbotEnabled", { Text = "Aimbot", Default = false, Callback = function(v) end })
Tog:AddKeyPicker("AimbotKey", { Mode = "Hold" }) -- Modes: "Toggle", "Hold", "Always"
Card:AddCheckbox("SilentCheck", { Text = "Silent Aim", Default = false })
```

### Button
```lua
Card:AddButton({
    Text = "Run Action",
    Size = "Default", -- "Small" | "Default" | "Large"
    Justify = "Between", -- "Between" | "Center"
    IconAlign = "Right", -- "Right" | "Left"
    Tags = { { Title = "New", Color = "Blue" } },
    Callback = function() end,
})
```

### Slider
```lua
Card:AddSlider("FOV", { Text = "FOV", Min = 30, Max = 180, Default = 90, Precision = 0 })
Card:AddSlider("Vol", { Wide = true, Min = 0, Max = 100, Default = 70, Icons = { From = "volume-1", To = "volume-2" } })
```

### Dropdown
```lua
Card:AddDropdown("TargetPart", {
    Text = "Target Part",
    Search = true,
    Multi = false,
    AllowNone = true,
    Values = { "Head", { Type = "Divider" }, { Title = "Locked", Locked = true }, "Torso" },
    Default = "Head",
})
```

### Input, Keybind, ColorPicker, Paragraph, Code, ProgressBar, Image
- `Card:AddInput(id, { Text = "...", Placeholder = "...", Numeric = false, Finished = false, ClearTextOnFocus = true })`
- `Card:AddKeybind(id, { Title = "...", Mode = "Toggle", Blacklist = { "Escape" }, Callback = function(state) end })`
- `Card:AddColorPicker(id, { Title = "...", Default = Color3.fromRGB(0, 145, 255), Transparency = 0 })`
- `Card:Paragraph({ Title = "...", Desc = "...", Image = "sparkles", Color = "Blue", Buttons = { ... } })`
- `Card:Code({ Title = "Loader", Code = "print('hello')" })`
- `Card:AddProgressBar(id, { Title = "Progress", Value = { Min = 0, Max = 100, Default = 40 }, Format = "%d / %d", Indeterminate = false })`
- `Card:Image({ Image = "https://...", Height = 44, Radius = 8 })`

## Containers & Dynamic Visibility

- `Card:Group()` — Places child controls side-by-side in a horizontal row.
- `Element:Hide()` / `Element:Show()` / `Element:SetHidden(bool)` — Dynamically hides or shows any element (or pass `Hidden = true` on creation) with automatic section height reflow.
