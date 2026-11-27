# Lifecycle, Unload & Auto-Cleanup

BreezeUI tracks window state, external script connections, and unload callbacks so nothing lingers in the Lua VM after closing or reloading.

## Status Helpers

| API | Description |
|---|---|
| `Library.Unloaded` | `false` while active; `true` after `Unload()` / `Destroy()` or window close. |
| `Library:IsLoaded()` | Returns `true` only when not unloaded, active window is alive, and `breeze_ui_state` matches the window token. |
| `Library:OnUnload(fn)` | Registers a cleanup callback executed automatically on unload. |
| `Library:GiveConnection(conn)` | Registers any `RBXScriptConnection` so it disconnects automatically on unload. |
| `Library:Connect(signal, fn)` | Connects `signal:Connect(...)`, gates execution with `Library:IsLoaded()`, and registers it for auto-disconnect. |
| `Library:Unload()` | Destroys all windows, disconnects all tracked connections, runs `OnUnload` callbacks, and clears pools/caches. |

## Recommended Script Pattern

```lua
local RunService = game:GetService("RunService")

Library:Connect(RunService.RenderStepped, function(dt)
    if Library.Toggles.Enabled.Value then
        -- feature loop
    end
end)

Library:OnUnload(function()
    -- restore any modified game values here
end)
```

For `task.spawn` loops, gate with `while Library:IsLoaded() do ... end`:

```lua
task.spawn(function()
    while Library:IsLoaded() do
        task.wait(0.25)
    end
end)
```

## Cross-VM Unload (`breeze_ui_state`)

`CreateWindow` writes a unique token (`running:<clock>:<rand>`) to Matcha's native `UI.SetValue("breeze_ui_state", token)`.
- Re-running a script overwrites the token; any older running window detects the mismatch on its next tick and self-destructs without blocking the new instance.
- Any external script can force-unload BreezeUI via `UI.SetValue("breeze_ui_state", "unload")`.
