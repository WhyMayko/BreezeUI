# Input Elements & State

All inputs support both Obsidian-style (`AddToggle(id, cfg)`) and WindUI-style (`Toggle(cfg)`) calls. Read values directly via `Library.Toggles[id].Value` and `Library.Options[id].Value`.

## Toggle & Inline KeyPicker

```lua
local tog = Group:AddToggle("Aimbot", {
    Text = "Aimbot",
    Default = false,
    Callback = function(v) end,
})

tog:AddKeyPicker("AimbotKey", {
    Text = "Aimbot",
    Default = nil,          -- nil renders [?]
    Mode = "Hold",          -- "Hold" | "Toggle" | "Always"
    SyncToggleState = true,
})
```

`Checkbox` (`AddCheckbox` / `Checkbox`) uses the same API with `Type = "Checkbox"`.

## Slider

```lua
Group:AddSlider("FOV", {
    Text = "FOV",
    Default = 120,
    Min = 20,
    Max = 400,
    Rounding = 0,
    Suffix = "px",
    Callback = function(v) end,
})
```

## Dropdown

```lua
Group:AddDropdown("TargetPart", {
    Text = "Target Part",
    Values = { "Head", "UpperTorso", "HumanoidRootPart" },
    Default = "Head",
    Multi = false,
    Searchable = false,
    SpecialType = nil,      -- "Player" auto-populates server players
    Callback = function(v) end,
})
```

## Input

```lua
Group:AddInput("ConfigName", {
    Text = "Config Name",
    Default = "",
    Placeholder = "Enter name...",
    Numeric = false,
    Finished = false,
    Callback = function(v) end,
})
```

## Standalone Keybind & Colorpicker

```lua
Group:AddKeybind("MenuKey", { Text = "Menu Key", Default = "F1", Mode = "Toggle" })
tog:AddColorPicker("ESPColor", { Default = Color3.fromRGB(0, 145, 255), Transparency = 0 })
```
