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
Window:SetTheme("Light") -- automatically swaps sidebar icons to dark variants
```

## Config Persistence

Pass `Folder = "MyProject"` in `CreateWindow` to isolate configs under `<Folder>/Configs/` and `<Folder>/default_config.txt`:

```lua
Library.Settings.Save("Legit", Library)
Library.Settings.Load("Legit", Library)
Library.Settings.Delete("Legit", Library)
Library.Settings.SetDefault("Legit")
```
