# Icons & Custom PNGs

BreezeUI resolves icons across `Notify`, `Dialog`, `Window`, `OpenButton`, `Tab`, `Button`, `Paragraph`, `Slider`, and `Image` through one unified subsystem (`Library.Icons`).

## Supported Sources

| Source | Example | Behavior |
|---|---|---|
| Lucide name | `"bell-ring"`, `"swords"` | Fetches monochrome PNG from repository; auto-swaps to dark assets in `Light` theme. |
| Direct PNG URL | `"https://example.com/item.png"` | Downloads and caches PNG once; preserves full original RGB colors. |
| Roblox Asset ID | `"rbxassetid://123456789"` | Resolves via Roblox thumbnail API, caches PNG, and preserves full original RGB colors. |
| Raw PNG bytes | `"\x89PNG\r\n..."` | Applies synchronously with zero network requests. |
| Registered alias | `"banana"` | Looks up any custom source registered via `AddIcons` or `Register`. |

## Registering Custom Icons

Bind variables or item tables once and reference them by name anywhere in your UI:

```lua
local banana = "rbxassetid://123456789"

Library.Creator.AddIcons({
    banana = banana,
    dragon_sword = "https://example.com/dragon_sword.png",
})

-- Or register individually:
Library.Icons.Register("potion", "https://example.com/potion.png")
```

## Batch Preloading

Warm the cache for multiple item assets at startup. Multiple `rbxassetid://` entries are resolved together in a single thumbnail API request:

```lua
Library.Icons.Preload({
    "rbxassetid://123456789",
    "rbxassetid://987654321",
    "https://example.com/banner.png",
})
```

## API

| Method | Description |
|---|---|
| `Icons.Register(name, source)` | Registers one custom icon alias (`url`, `rbxassetid://`, or raw PNG bytes). |
| `Icons.AddIcons(tbl)` | Batch-registers a `{ name = source }` dictionary (also exposed at `Library.Creator.AddIcons`). |
| `Icons.Preload(names)` | Preloads a list of icon names/URLs/`rbxassetid://` sources into memory cache. |
| `Icons.IsCustom(source)` | Returns `true` for URLs, `rbxassetid://`, raw PNGs, and registered custom aliases. |
| `Icons.ClearCache()` | Clears cached PNGs, in-flight state, custom registrations, and theme subscribers. |
