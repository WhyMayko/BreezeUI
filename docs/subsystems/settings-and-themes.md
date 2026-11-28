# Settings, Themes & Configs

## Built-in Settings Tab

Attach the full Settings tab (Theme selector, Minimize Key `[F1]`, Keybind List, Block Roblox Input, Notify Side, and Config Save/Load/Delete/SetDefault) in one line:

```lua
Library:SetupSettingsTab(Window)
```

## Themes (18 Built-in)

`Dark`, `Light`, `Rose`, `Plant`, `Red`, `Indigo`, `Sky`, `Violet`, `Amber`, `Emerald`, `Midnight`, `Crimson`, `MonokaiPro`, `CottonCandy`, `Mellowsi`, `Rainbow`, `Slate`, `Ruby`.

```lua
local themes = Library:GetThemes()
Window:SetTheme("Light")   -- swaps Lucide icons to dark variants while keeping custom PNG colors
Window:SetTheme("Rainbow") -- runs animated HSV cycling via Theme.StepRainbow at ~33 Hz
```

## Custom Themes & HSV Helpers

Register custom palettes before calling `GetThemes()` or `SetTheme()`:

```lua
local palette = setmetatable({
    Name = "Nord",
    ["Window.Background"] = Color3.fromRGB(46, 52, 64),
    ["Accent.Blue"] = Color3.fromRGB(136, 192, 208),
}, { __index = Library.Theme.DefaultPalette })

Library.Theme.Register("Nord", palette)
Window:SetTheme("Nord")

local col = Library.Theme.HSV(0.55, 0.85, 1)
```

## Config Persistence

Pass `Folder = "MyProject"` in `CreateWindow` to isolate configs under `<Folder>/Configs/` and `<Folder>/default_config.txt`:

```lua
Library.Settings.Save("Legit", Library)
Library.Settings.Load("Legit", Library)
Library.Settings.Delete("Legit", Library)
Library.Settings.SetDefault("Legit")
```
