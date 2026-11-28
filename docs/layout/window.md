# Window

## CreateWindow

```lua
local Window = Library:CreateWindow({
    Title = "MyScript",
    Subtitle = "v1.0",
    Icon = "wind",                -- optional Lucide, PNG URL, rbxassetid://, or AddIcons key
    Folder = "MyScript",          -- isolates config files under <Folder>/Configs/
    Size = Vector2.new(640, 460),
    Theme = "Dark",
    SidebarWidth = 190,
    Draggable = true,
    CanResize = true,
    BlockRobloxInput = true,      -- locks game input while UI is open & Roblox is focused
    Profile = { ... },            -- see layout/profile-card.md
})
```

## Methods

| Method | Description |
|---|---|
| `Window:SetVisible(bool)` | Shows or hides the window. |
| `Window:ToggleMinimize()` | Toggles minimized state (shows floating `OpenButton`). |
| `Window:ToggleFullscreen()` | Toggles fullscreen mode (disables drag/resize while active). |
| `Window:SetTheme(nameOrTable)` | Switches active theme (`Dark`, `Light`, `Rainbow`, or registered palette). |
| `Window:SetScale(scale)` | Updates window scale multiplier (`0.5..2.0`). |
| `Window:SetDPIScale(pct)` | Sets window DPI percentage (`50..200`). |
| `Window:SetTransparency(alpha)` | Sets window frame/panel transparency (`0..1`). |
| `Window:SetCornerRadius(r)` | Updates corner radius (`0..32`). |
| `Window:SetBackgroundImage(src)` | Sets an optional background image from Lucide, PNG URL, or `rbxassetid://`. |
| `Window:SetProfile(opts)` | Updates the sidebar `ProfileCard` options at runtime. |
| `Window:Tag({ Title, Icon, Color, Border })` | Adds a topbar badge tag. |
| `Window:EditOpenButton({ Enabled, Title, Icon, IconRounding, Draggable, OnlyIcon, Position, Color })` | Configures the floating pill shown when minimized. |
| `Window:Destroy()` | Closes the window and triggers `Library:_cleanupRuntime()`. |
