-- Library/BreezeUI/Subsystems/Icons.lua
-- Pure white Lucide PNG icon subsystem with memory cache, name normalization, and deduplicated fetch queue.

local Icons = {
    Cache = {},
    Custom = {},
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

local function resolve_source(rawName)
    if type(rawName) ~= "string" or rawName == "" then
        return "none", ""
    end
    if Icons.ValidatePNG(rawName) then
        return "raw", rawName, true
    end
    local mapped = Icons.Custom[rawName] or Icons.Custom[rawName:lower()]
    local src = type(mapped) == "string" and mapped or rawName
    local custom = (mapped ~= nil)

    if Icons.ValidatePNG(src) then
        return "raw", src, true
    end
    if src:sub(1, 7) == "file://" then
        return "file", src:sub(8), true
    end
    local rbxId = src:match("^rbxassetid://(%d+)$") or src:match("roblox%.com/asset/%?id=(%d+)")
    if rbxId then
        return "rbx", rbxId, true
    end
    if src:sub(1, 7) == "http://" or src:sub(1, 8) == "https://" then
        return "url", src, true
    end
    if src:sub(-4):lower() == ".png" and isfile and isfile(src) then
        return "file", src, true
    end
    return "lucide", Icons.NormalizeName(src), custom
end

function Icons.Register(name, source)
    assert(type(name) == "string" and name ~= "", "Icons.Register requires a non-empty string name!")
    assert(type(source) == "string" and source ~= "", "Icons.Register requires a PNG source string!")
    Icons.Custom[name] = source
    Icons.Custom[name:lower()] = source
    return Icons
end

function Icons.AddIcons(tbl)
    assert(type(tbl) == "table", "Icons.AddIcons requires a table!")
    for k, v in pairs(tbl) do
        if type(k) == "string" and type(v) == "string" and v ~= "" then
            Icons.Register(k, v)
        end
    end
    return Icons
end

function Icons.IsCustom(rawName)
    local _, _, isCustom = resolve_source(rawName)
    return isCustom == true
end

function Icons.IsInFlight(rawName, forceLight)
    local kind, val = resolve_source(rawName)
    if kind == "none" or kind == "raw" or kind == "file" then return false end
    local cacheKey = kind == "url" and val
        or kind == "rbx" and ("rbx:" .. val)
        or (((not forceLight and Icons.DarkMode) and "dark:" or "light:") .. val)
    return Icons.InFlight[cacheKey] ~= nil
end

local fetchQueue = {}
local workerRunning = false

local function fetch_png_once(item)
    if not (game and game.HttpGet) then return nil end
    local url = item.Url
    if item.RbxId then
        local api = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. item.RbxId .. "&returnPolicy=PlaceHolder&size=150x150&format=Png&isCircular=false"
        local okMeta, body = pcall(function() return game:HttpGet(api) end)
        if not okMeta or type(body) ~= "string" or body == "" then return nil end
        local hsOk, hs = pcall(function() return game:GetService("HttpService") end)
        if not hsOk or not hs then return nil end
        local decOk, decoded = pcall(function() return hs:JSONDecode(body) end)
        local imgUrl = decOk and decoded and decoded.data and decoded.data[1] and decoded.data[1].imageUrl
        if type(imgUrl) ~= "string" or imgUrl == "" then return nil end
        url = imgUrl
    end
    local ok, data = pcall(function() return game:HttpGet(url) end)
    if ok and data and Icons.ValidatePNG(data) then
        return data
    end
    return nil
end

local function process_queue()
    if workerRunning then return end
    workerRunning = true
    while #fetchQueue > 0 do
        local item = table.remove(fetchQueue, 1)
        local name = item.Name
        if not Icons.Cache[name] then
            local data = fetch_png_once(item)
            if not data then
                if task and task.wait then task.wait(0.08) end
                data = fetch_png_once(item)
            end
            if data then
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

function Icons.Get(rawName, callback, forceLight, urgent)
    if not rawName or rawName == "" then
        if callback then callback(Icons.DefaultIcon) end
        return Icons.DefaultIcon
    end

    local kind, val = resolve_source(rawName)
    if kind == "raw" then
        if callback then callback(val) end
        return val
    end
    if kind == "file" then
        if Icons.Cache["file:" .. val] then
            local cached = Icons.Cache["file:" .. val]
            if callback then callback(cached) end
            return cached
        end
        if readfile and (not isfile or isfile(val)) then
            local ok, bytes = pcall(readfile, val)
            if ok and Icons.ValidatePNG(bytes) then
                Icons.Cache["file:" .. val] = bytes
                if callback then callback(bytes) end
                return bytes
            end
        end
        return Icons.DefaultIcon
    end

    local isUrl = (kind == "url")
    local isRbx = (kind == "rbx")
    local useDark = (kind == "lucide") and (not forceLight) and Icons.DarkMode
    local cacheKey = isUrl and val or (isRbx and ("rbx:" .. val) or ((useDark and "dark:" or "light:") .. val))

    if callback and kind == "lucide" and not forceLight then
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
        if urgent then
            for i = 2, #fetchQueue do
                if fetchQueue[i].Name == cacheKey then
                    local item = table.remove(fetchQueue, i)
                    table.insert(fetchQueue, 1, item)
                    break
                end
            end
        end
        return nil
    end

    Icons.InFlight[cacheKey] = callback and { callback } or {}
    Icons.NetworkFetchCount = Icons.NetworkFetchCount + 1

    local base = useDark and Icons.DarkRepoBase or Icons.RepoBase
    local entry = isRbx and { Name = cacheKey, RbxId = val }
        or { Name = cacheKey, Url = isUrl and val or (base .. val .. ".png") }
    if urgent then
        table.insert(fetchQueue, 1, entry)
    else
        table.insert(fetchQueue, entry)
    end
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
    Icons.Custom = {}
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
