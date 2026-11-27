-- Library/BreezeUI/Loader.lua
-- Fast single-request entry point for BreezeUI Drawing UI Library.

local Loader = {}
Loader.Repo = "https://raw.githubusercontent.com/WhyMayko/BreezeUI/main/"

_G.BreezeUI = _G.BreezeUI or {}

function Loader:Load()
    if _G.BreezeUI.Library then
        return _G.BreezeUI.Library, _G.BreezeUI.ThemeManager, _G.BreezeUI.SaveManager
    end

    local url = Loader.Repo .. "Library.lua"
    local source = game:HttpGet(url)
    assert(type(source) == "string" and source ~= "", "Loader.lua failed to download Library.lua from " .. url .. "!")

    local chunk = assert(loadstring(source, "=Library.lua"), "Loader.lua failed to compile Library.lua!")
    chunk()

    local lib = _G.BreezeUI.Library
    assert(type(lib) == "table", "Loader.lua: Library instance not found after executing Library.lua!")
    return lib, _G.BreezeUI.ThemeManager, _G.BreezeUI.SaveManager
end

_G.BreezeUI["Loader.lua"] = Loader
_G.BreezeUI.Loader = Loader
_G.BreezeUI.Get = function()
    if not _G.BreezeUI.Library then
        Loader:Load()
    end
    return _G.BreezeUI.Library, _G.BreezeUI.ThemeManager, _G.BreezeUI.SaveManager
end

setmetatable(_G.BreezeUI, {
    __call = function()
        if not _G.BreezeUI.Library then
            Loader:Load()
        end
        return _G.BreezeUI.Library, _G.BreezeUI.ThemeManager, _G.BreezeUI.SaveManager
    end,
})

if game and game.HttpGet then
    Loader:Load()
end

return _G.BreezeUI
