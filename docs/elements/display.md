# Display Elements

## Button

```lua
Group:AddButton({
    Text = "Execute",
    Icon = "play",
    Justify = "Between", -- "Between" | "Center"
    Locked = false,
    Callback = function() end,
})
```

## Paragraph

```lua
local para = Group:Paragraph({
    Title = "Status",
    Desc = "Ready.",
})
para:SetTitle("Updated")
para:SetDesc("Running.")
```

## Code Block

```lua
Group:Code({
    Title = "Loader",
    Code = 'print("hello")',
})
```

## Image

```lua
Group:Image({
    Image = "https://example.com/banner.png",
    Height = 48,
    Radius = 8,
})
```

## ProgressBar

```lua
local bar = Group:ProgressBar({
    Title = "Loading",
    Value = 0,
    Max = 100,
})
bar:SetValue(75)
```
