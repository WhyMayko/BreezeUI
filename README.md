# BreezeUI

Lightweight Drawing-API UI library for **Matcha LuaVM**, designed with a macOS/WindUI aesthetic, 18 built-in themes, smooth exponential animations, and zero `Instance.new` dependencies.

## Quick Start

```lua
local repo = "https://raw.githubusercontent.com/WhyMayko/BreezeUI/main/"
loadstring(game:HttpGet(repo .. "Loader.lua"))()
local Library = _G.BreezeUI()

local Window = Library:CreateWindow({
    Title = "MyScript",
    Subtitle = "v1.0",
    Folder = "MyScript",
    Size = Vector2.new(640, 460),
    Theme = "Dark",
})

local Sec = Window:Section({ Title = "Main", Opened = true })
local Tab = Sec:Tab({ Title = "Features", Icon = "swords" })
local Group = Tab:Section({ Title = "Combat", Box = true })

Group:AddToggle("Enabled", { Text = "Enabled", Default = false }):AddKeyPicker("EnabledKey", {
    Text = "Enabled",
    Mode = "Toggle",
    SyncToggleState = true,
})

Library:SetupSettingsTab(Window)
```

## Documentation

| Category | Guide |
|---|---|
| **Core** | [Lifecycle, Unload & Connections](docs/core/lifecycle.md) |
| **Layout** | [Window API](docs/layout/window.md) · [Navigation & Visibility](docs/layout/navigation.md) · [Profile Card](docs/layout/profile-card.md) |
| **Elements** | [Inputs & State](docs/elements/inputs.md) · [Display Elements](docs/elements/display.md) |
| **Subsystems** | [Notify, Dialog & Popup](docs/subsystems/overlays.md) · [Icons & Custom PNGs](docs/subsystems/icons.md) · [Settings, Themes & Configs](docs/subsystems/settings-and-themes.md) |
