# Themes & Configs

## Built-in Settings Tab

Attach the native Settings tab (Themes, DPI Scale, Toggle Key, Input Block, Keybind List, and Config Profiles) to any window:

```lua
Library.Settings.BuildTab(Window)
```

## Themes

Available built-in palettes:
`Dark`, `Midnight`, `Rose`, `Violet`, `Sky`, `Indigo`, `Crimson`, `MonokaiPro`, `CottonCandy`, `Mellowsi`, `Rainbow`, `Light`, and more.

Programmatic switch:
```lua
Window:SetTheme("Rose")
```

## Config Persistence API (`Library.Settings` / `SaveManager`)

Pass `Folder = "GalaxHub"` in `CreateWindow` (or call `Settings.SetFolder("GalaxHub")`) to isolate project configs under `<Folder>/Configs/` and `<Folder>/default_config.txt`.
Global UI preferences (Theme, Minimize Key, Keybind List, Input Block, Notify Side) **always** use the fixed default path `BreezeUI/ui_prefs.json` regardless of `Folder`.

- `Settings.SetFolder(folder)` / `Settings.GetFolder()` — Sets or reads the project folder for config profiles (defaults to `"BreezeUI"`).
- `Settings.Save(name)` — Saves all registered `Toggles` and `Options` (excluding `Settings*` internal keys) into `<Folder>/Configs/<name>.json`.
- `Settings.Load(name)` — Restores saved values and updates all controls.
- `Settings.ListConfigs()` — Returns all saved profile names in the active `Folder`.
- `Settings.SetDefault(name)` — Marks a profile to auto-load on startup (`<Folder>/default_config.txt`).
- `Settings.GetDefault()` — Returns the current default profile name or `nil`.
- `Settings.ClearDefault()` — Clears the auto-load default profile.
- `Settings.Delete(name)` — Deletes a saved profile from the active `Folder`.
- `Settings.Reset()` — Restores initial defaults recorded at element registration.
