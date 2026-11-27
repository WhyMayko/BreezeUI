# BreezeUI Documentation

## Structure

- **Core**
  - [Lifecycle & Auto-Cleanup](core/lifecycle.md) — `IsLoaded()`, `Unloaded`, `OnUnload()`, `GiveConnection()`, `Connect()`, `Unload()`, and cross-VM `breeze_ui_state`.
- **Layout**
  - [Window](layout/window.md) — `CreateWindow`, visibility, minimize, fullscreen, scale, tags, open button.
  - [Navigation](layout/navigation.md) — `Section`, `Tab`, `ContentSection`, `Show()` / `Hide()` / `SetHidden()`.
  - [Profile Card](layout/profile-card.md) — sidebar footer player card, `Tag`, `Created`, `Date`, `Time`, `Uptime`, `FPS`, `Fields`.
- **Elements**
  - [Inputs](elements/inputs.md) — `Toggle`, `Checkbox`, `Slider`, `Dropdown`, `Input`, `Keybind`, `Colorpicker`.
  - [Display](elements/display.md) — `Button`, `Paragraph`, `Code`, `Image`, `ProgressBar`.
- **Subsystems**
  - [Overlays](subsystems/overlays.md) — `Notify`, `Progress`, `Dialog`, `Popup`.
  - [Settings & Themes](subsystems/settings-and-themes.md) — `SetupSettingsTab`, 18 built-in themes, config Save/Load/Delete.
