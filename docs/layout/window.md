# Window

## CreateWindow

```lua
local Window = Library:CreateWindow({
    Title = "MyScript",
    Subtitle = "v1.0",
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
| `Window:SetTheme(nameOrTable)` | Switches active theme (`Dark`, `Light`, `Rose`, `Midnight`, etc.). |
| `Window:SetScale(scale)` | Updates UI DPI scale. |
| `Window:SetProfile(opts)` | Updates the sidebar `ProfileCard` options at runtime. |
| `Window:Tag({ Title, Icon, Color, Border })` | Adds a topbar badge tag. |
| `Window:EditOpenButton({ Enabled, Title, Icon, Draggable })` | Configures the floating pill shown when minimized. |
| `Window:Destroy()` | Closes the window and triggers `Library:_cleanupRuntime()`. |
