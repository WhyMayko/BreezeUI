# Profile Card & Info Menu

The sidebar footer renders a WindUI-style Player Card with the local player's avatar headshot, `DisplayName`, and `@Username`. Clicking it opens a compact info menu above the card (without duplicating the avatar photo).

## Configuration

Pass `Profile` in `CreateWindow` or update later via `Window:SetProfile(opts)`:

```lua
Profile = {
    Enabled = true,
    Tag = { Text = "Breeze" }, -- omits Color to follow active theme accent
    ShowCreated = true,
    ShowDate = true,
    ShowTime = true,
    ShowUptime = true,
    ShowFPS = true,
    Fields = {
        { Label = "Plan", Value = "Lifetime" },
    },
    Callback = function() end,
}
```

| Option | Default | Description |
|---|---|---|
| `Enabled` | `true` | Pass `Profile = false` or `Enabled = false` to hide. |
| `Tag` | `nil` | Optional pill (`"Text"` or `{ Text = "...", Color = Color3, TextColor = Color3 }`). Omit `Color` to match theme accent. |
| `ShowCreated` | `true` | Account creation date (`DD/MM/YYYY`). |
| `ShowDate` | `true` | Current local date (`DD/MM/YYYY`), updated 1/sec. |
| `ShowTime` | `true` | Current local time (`HH:MM:SS`), updated 1/sec. |
| `ShowUptime` | `true` | Script session uptime (`HH:MM:SS`), updated 1/sec. |
| `ShowFPS` | `true` | Real UI/Matcha tickrate FPS, averaged 1/sec. |
| `Fields` | `{}` | Extra `{ Label, Value }` rows appended at the bottom. |
| `Callback` | `nil` | Optional function called when the card is clicked. |
