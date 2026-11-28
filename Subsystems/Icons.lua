-- Library/BreezeUI/Subsystems/Icons.lua
-- Pure white Lucide PNG icon subsystem with memory cache, name normalization, and deduplicated fetch queue.

local Icons = {
    Cache = {},
    InFlight = {},
    DefaultIcon = nil,
    NetworkFetchCount = 0,
    DarkMode = false,
    _subscribers = {},
    RepoBase = "https://raw.githubusercontent.com/WhyMayko/BreezeUI/main/assets/icons/light/",
    DarkRepoBase = "https://raw.githubusercontent.com/WhyMayko/BreezeUI/main/assets/icons/dark/",
    TextureBase = "https://raw.githubusercontent.com/WhyMayko/BreezeUI/main/assets/textures/",
}

local aliases = {
    ["home"] = "home-2-bold",
    ["home-2"] = "home-2-bold",
    ["main"] = "home-2-bold",
    ["grid"] = "layout-grid",
    ["folder-2-bold-duotone"] = "folder",
    ["folder-2"] = "folder",
    ["info-square"] = "info-square-bold",
    ["check-square"] = "check-square-bold",
    ["circle-check"] = "circle-check",
    ["cursor-square"] = "cursor-square-bold",
    ["mouse-pointer-click"] = "mouse-pointer",
    ["pointer"] = "mouse-pointer",
    ["password-minimalistic-input"] = "password-minimalistic-input-bold",
    ["input"] = "password-minimalistic-input-bold",
    ["edit"] = "file-text",
    ["square-transfer-horizontal"] = "square-transfer-horizontal-bold",
    ["sliders"] = "sliders-horizontal",
    ["hamburger-menu"] = "hamburger-menu-bold",
    ["dropdown"] = "list",
    ["bird"] = "bot",
    ["shredder"] = "trash-2",
    ["trash"] = "trash-2",
    ["sunminfill"] = "sun-min",
    ["sunmaxfill"] = "sun-max",
    ["moon"] = "moon",
    ["volume"] = "volume-2",
    ["volumemin"] = "volume-1",
    ["volumemax"] = "volume-2",
    ["target"] = "crosshair",
    ["aim"] = "crosshair",
    ["gear"] = "settings",
    ["cog"] = "settings",
    ["user-circle"] = "user",
    ["discord"] = "message-square",
    ["palette"] = "palette",
    ["paint"] = "palette",
}

function Icons.NormalizeName(rawName)
    if not rawName or type(rawName) ~= "string" or rawName == "" then
        return "box"
    end
    local clean = rawName:lower()
    local colon = clean:find(":")
    if colon then
        clean = clean:sub(colon + 1)
    end
    return aliases[clean] or clean
end

function Icons.ValidatePNG(data)
    if not data or type(data) ~= "string" or #data < 8 then
        return false, "Invalid data length"
    end
    if data:sub(1, 4) ~= "\x89PNG" and data:sub(2, 4) ~= "PNG" and data:sub(1, 4) ~= "PNG_" then
        return false, "Invalid PNG magic header"
    end
    return true
end

function Icons.Validate(data)
    return Icons.ValidatePNG(data)
end

local fetchQueue = {}
local workerRunning = false

local function process_queue()
    if workerRunning then return end
    workerRunning = true
    while #fetchQueue > 0 do
        local item = table.remove(fetchQueue, 1)
        local name = item.Name
        if not Icons.Cache[name] then
            local url = item.Url or (Icons.RepoBase .. name .. ".png")
            local ok, data = pcall(function()
                if game and game.HttpGet then
                    return game:HttpGet(url)
                end
                return nil
            end)
            if ok and data and Icons.ValidatePNG(data) then
                Icons.Cache[name] = data
            end
        end
        local finalData = Icons.Cache[name]
        local waiting = Icons.InFlight[name]
        Icons.InFlight[name] = nil
        if waiting and finalData then
            for _, cb in ipairs(waiting) do
                pcall(cb, finalData)
            end
        end
        if task and task.wait then
            task.wait()
        end
    end
    workerRunning = false
end

function Icons.SetDarkMode(enabled)
    local nextMode = enabled == true
    if Icons.DarkMode == nextMode then return false end
    Icons.DarkMode = nextMode
    -- Refresh all active icon subscribers for the new theme polarity
    local subs = {}
    for _, sub in ipairs(Icons._subscribers) do
        table.insert(subs, sub)
    end
    for _, sub in ipairs(subs) do
        Icons.Get(sub.Name, sub.Callback)
    end
    return true
end

function Icons.Get(rawName, callback, forceLight)
    if not rawName or rawName == "" then
        if callback then callback(Icons.DefaultIcon) end
        return Icons.DefaultIcon
    end

    local isUrl = (rawName:sub(1, 7) == "http://" or rawName:sub(1, 8) == "https://")
    local name = isUrl and rawName or Icons.NormalizeName(rawName)
    local useDark = (not isUrl) and (not forceLight) and Icons.DarkMode
    local cacheKey = isUrl and rawName or ((useDark and "dark:" or "light:") .. name)

    if callback and not isUrl and not forceLight then
        local found = false
        for _, sub in ipairs(Icons._subscribers) do
            if sub.Callback == callback then
                sub.Name = rawName
                found = true
                break
            end
        end
        if not found then
            table.insert(Icons._subscribers, { Name = rawName, Callback = callback })
        end
    end

    if Icons.Cache[cacheKey] then
        local cached = Icons.Cache[cacheKey]
        if callback then callback(cached) end
        return cached
    end

    if Icons.InFlight[cacheKey] then
        if callback then
            table.insert(Icons.InFlight[cacheKey], callback)
        end
        return nil
    end

    Icons.InFlight[cacheKey] = callback and { callback } or {}
    Icons.NetworkFetchCount = Icons.NetworkFetchCount + 1

    local base = useDark and Icons.DarkRepoBase or Icons.RepoBase
    table.insert(fetchQueue, { Name = cacheKey, Url = isUrl and rawName or (base .. name .. ".png") })
    if task and task.spawn then
        task.spawn(function()
            process_queue()
        end)
    else
        process_queue()
    end
    return nil
end

function Icons.GetTexture(name, callback)
    return Icons.Get(Icons.TextureBase .. tostring(name) .. ".png", callback)
end

function Icons.Preload(names)
    if not names or type(names) ~= "table" then return 0 end
    local count = 0
    for _, name in ipairs(names) do
        Icons.Get(name)
        count = count + 1
    end
    return count
end

function Icons.ClearSubscribers()
    Icons._subscribers = {}
end

function Icons.ClearCache()
    Icons.Cache = {}
    Icons.InFlight = {}
    Icons._subscribers = {}
    Icons.NetworkFetchCount = 0
    fetchQueue = {}
    workerRunning = false
end

function Icons.Clear()
    Icons.ClearCache()
end

return Icons
