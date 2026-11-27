# Overlays (Notify, Progress, Dialog, Popup)

## Toast Notification

```lua
Library:Notify({
    Title = "Saved",
    Content = "Configuration saved.",
    Icon = "check",
    Duration = 3,
    Buttons = {
        { Title = "Undo", Callback = function() end },
    },
})
```

## Progress Toast

```lua
local toast = Library:Progress("Downloading", "Fetching...", false)
toast:SetProgress(0.5)
toast:SetTitle("Complete")
toast:SetContent("Done.")
toast:Close()
```

## Modal Dialog & Viewport Popup

```lua
Window:Dialog({
    Title = "Confirm",
    Content = "Reset all settings?",
    Buttons = {
        { Title = "Cancel", Variant = "Secondary", Callback = function() end },
        { Title = "Confirm", Variant = "Primary", Callback = function() end },
    },
})

Library:Popup({
    Title = "Notice",
    Content = "Centered viewport modal.",
    Buttons = { { Title = "OK", Variant = "Primary", Callback = function() end } },
})
```
