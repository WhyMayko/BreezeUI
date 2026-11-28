# Display Elements

## Button

```lua
Group:AddButton({
    Text = "Equip",
    Desc = "Optional subtitle",
    Icon = "play",            -- Lucide, PNG URL, rbxassetid://, AddIcons key, or false
    IconAlign = "Right",      -- "Right" | "Left"
    Justify = "Between",      -- "Between" | "Center"
    Variant = "Success",      -- "Primary" | "Danger" | "Success" (or pass Color = Color3 | "Red" | "Green" | "Blue")
    TextColor = nil,          -- optional override; defaults to white on colored/variant buttons
    Tags = { { Title = "NEW", Color = "Blue" } },
    Locked = false,
    Callback = function() end,
})
```

## Paragraph

```lua
local para = Group:Paragraph({
    Title = "Status",
    Desc = "Ready.",
    Image = "https://example.com/icon.png", -- optional PNG / rbxassetid:// / Lucide
    ImageSize = 36,
    ImageRounding = 8,
    Color = "Red",            -- optional preset or Color3 card/border tint
    Buttons = {
        { Title = "Details", Callback = function() end },
    },
})
para:SetTitle("Updated")
para:SetDesc("Running.")
```

## Code Block

```lua
Group:Code({
    Title = "Loader",
    Code = 'print("hello")',
    CanCopied = true,
    OnCopy = function(code) end,
})
```

## Image

```lua
Group:Image({
    Image = "https://example.com/banner.png", -- or rbxassetid:// / AddIcons key
    AspectRatio = "16:9",     -- or fixed Height = 48
    Radius = 8,
})
```

## ProgressBar

```lua
local bar = Group:ProgressBar({
    Title = "Loading",
    Desc = "Fetching payload...",
    Value = 0,
    Max = 100,
    Indeterminate = false,
    Color = nil,              -- optional Color3 fill override (preserved across themes/Rainbow)
})
bar:SetValue(75)
bar:SetIndeterminate(true)
```
