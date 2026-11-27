# BreezeUI Documentation

Drawing-API UI library for Matcha LuaVM modeled 1:1 after WindUI.

## Getting Started

Load the bundled library directly via `Loader.lua` or `dist/main.lua`:

```lua
local repo = "https://raw.githubusercontent.com/WhyMayko/BreezeUI/main/"
loadstring(game:HttpGet(repo .. "Loader.lua"))()
local Library, ThemeManager, SaveManager = _G.BreezeUI()
```

## Creating a Window

```lua
local Window = Library:CreateWindow({
    Title = "My Script",
    Subtitle = "v1.0",
    Size = Vector2.new(640, 460),
    Theme = "Dark",
})
```

### Window Methods

- `Window:Section({ Title = "Category", Opened = true })` — Creates a collapsible sidebar section.
- `Window:Tag({ Title = "v1.0", Icon = "sparkles", Color = Color3.fromRGB(28, 28, 32), Border = true })` — Adds a topbar tag badge.
- `Window:EditOpenButton({ Title = "Open", Draggable = true })` — Configures the floating toggle pill when minimized.
- `Window:SetTheme(nameOrTable)` — Switches the active theme (`Dark`, `Light`, `Rose`, `Midnight`, `Violet`, etc.).
- `Window:Dialog({ Title = "...", Content = "...", Buttons = { ... } })` — Shows a modal dialog centered on the window.
- `Library:Notify({ Title = "...", Content = "...", Icon = "bell", Duration = 4, Buttons = { ... } })` — Pushes a toast notification.
- `Library:Popup({ Title = "...", Content = "...", Buttons = { ... } })` — Shows a viewport-centered popup.

## Guides

- [Elements Reference](./elements.md)
- [Themes & Configs](./themes-and-configs.md)
