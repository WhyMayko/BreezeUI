# Overlays (Notify, Progress, Dialog, Popup)

## Toast Notification

`Library:Notify` supports theme-matched icons, custom PNG/Roblox item images (`Icon` or `Image`), styled action buttons, custom card colors, and live mutators:

```lua
local banana = "rbxassetid://123456789"

local toast = Library:Notify({
    Title = "Item Dropped",
    Content = "Mythic Banana added to inventory.",
    Image = banana,           -- Lucide name, PNG URL, rbxassetid://, raw PNG, or AddIcons key
    IconSize = 30,            -- 14..40 (default 22)
    IconRounding = 6,
    IconBorderColor = Color3.fromRGB(255, 200, 40),
    BackgroundColor = Color3.fromRGB(28, 22, 14),
    BorderColor = Color3.fromRGB(255, 200, 40),
    TitleColor = Color3.fromRGB(255, 225, 110),
    ContentColor = Color3.fromRGB(225, 220, 200),
    Accent = Color3.fromRGB(255, 200, 40),
    Corner = 14,              -- 0..24 (default 12)
    Width = 340,              -- 220..480 (default 296)
    Duration = 5,             -- pass false for sticky notifications
    Buttons = {
        { Title = "Equip", Variant = "Success", Callback = function() end },
        { Title = "Cancel", Variant = "Danger", Callback = function() end },
    },
})

toast:SetIcon("check")
toast:OnClick(function() end)
toast:OnDismiss(function() end)
```

| Option | Default | Description |
|---|---|---|
| `Icon` / `Image` | `nil` | Icon name, PNG URL, `rbxassetid://`, raw PNG bytes, or `AddIcons` key. |
| `IconSize` | `22` | Clamped to `14..40` px; automatically adjusts toast height and text offset. |
| `IconRounding` | `0` | Corner rounding passed to `Drawing.Image.Rounding`. |
| `IconBorderColor` | `nil` | Optional 1px border color drawn around the icon. |
| `KeepColor` | `true` | Preserves original RGB on custom PNGs across all themes; set `false` to tint with `TitleColor`. |
| `Background` / `BackgroundColor` | theme | Custom card background color. |
| `BorderColor` | theme / `Accent` | Custom card outline color. |
| `TitleColor` / `ContentColor` | theme | Custom title and body text colors. |
| `Corner` / `Width` | `12` / `296` | Card corner radius (`0..24`) and width (`220..480`). |
| `Side` / `Anchor` | window / `"Bottom"` | Override corner placement (`"Left"` / `"Right"`, `"Top"` / `"Bottom"`). |

### Button Styling (`Notify` & `Dialog`)

Buttons accept `Variant` (`"Primary"`, `"Danger"`, `"Success"`, `"Secondary"`, `"Tertiary"`), `Color` (`Color3` or `"Red"` / `"Green"` / `"Blue"` / `"Danger"` / `"Success"`), `TextColor`, `Icon`, `KeepOpen`, and `Callback`.

## Progress Toast

```lua
local toast = Library:Progress("Downloading", "Fetching...", false)
toast:SetProgress(0.5)
toast:SetTitle("Complete")
toast:SetContent("Done.")
toast:SetIcon("check")
toast:Close()
```

## Modal Dialog & Viewport Popup

```lua
Window:Dialog({
    Title = "Confirm",
    Content = "Delete selected config?",
    Image = "trash-2",
    IconRounding = 6,
    Buttons = {
        { Title = "Cancel", Variant = "Secondary", Callback = function() end },
        { Title = "Delete", Variant = "Danger", Callback = function() end },
    },
})

Library:Popup({
    Title = "Notice",
    Content = "Centered viewport modal.",
    Buttons = { { Title = "OK", Variant = "Primary", Callback = function() end } },
})
```
