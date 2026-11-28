-- Library/BreezeUI/Subsystems/Settings.lua
-- Native integrated Settings subsystem providing Interface, Behavior, Configuration, and Performance controls.

local ThemeModule = require("../Layout/Theme")

local Settings = {
    Profiles = {},
    _profiles = {},
    _profilesByFolder = {},
    _lastEnv = nil,
    _uiRoot = "BreezeUI",
    _configFolder = "BreezeUI",
}

local function ensure_folder_tree(path)
    if not (isfolder and makefolder) then return end
    local acc = ""
    for part in tostring(path):gmatch("[^\\/]+") do
        acc = (acc == "") and part or (acc .. "/" .. part)
        if not isfolder(acc) then
            makefolder(acc)
        end
    end
end

function Settings.SetFolder(folder)
    if folder == nil or folder == "" then
        Settings._configFolder = Settings._uiRoot
        Settings._defaultConfig = nil
        return Settings._configFolder
    end
    assert(type(folder) == "string", "Invalid folder name: expected string!")
    assert(not folder:find('[<>:"|?*]'), "Invalid folder name: contains illegal filesystem characters!")
    assert(not folder:find("%.%."), "Invalid folder name: '..' is not allowed!")
    local cleaned = folder:gsub("^[/\\]+", ""):gsub("[/\\]+$", ""):gsub("\\", "/")
    assert(cleaned ~= "", "Invalid folder name: cannot be empty!")
    Settings._configFolder = cleaned
    Settings._defaultConfig = nil
    return cleaned
end

function Settings.GetFolder()
    return Settings._configFolder or Settings._uiRoot
end

function Settings._getHttpService()
    local g = game or (_G and _G.game)
    if g and g.GetService then
        local ok, hs = pcall(function() return g:GetService("HttpService") end)
        if ok and hs then return hs end
    end
    local hs = HttpService or (_G and _G.HttpService)
    if hs then return hs end
    assert(false, "HttpService is not available in environment!")
end

function Settings.ValidateProfileName(name)
    if not name or type(name) ~= "string" or name == "" then
        return false, "Invalid profile name: cannot be empty"
    end
    if name:find('[<>:"/\\|?*]') then
        return false, "Invalid profile name: contains illegal filesystem characters"
    end
    if #name > 64 then
        return false, "Invalid profile name: exceeds 64 characters limit"
    end
    return true
end

local function serialize_value(v)
    if (typeof and typeof(v) == "Color3") or (type(v) == "table" and type(v.R) == "number" and type(v.G) == "number" and type(v.B) == "number") then
        return { __color3 = { v.R, v.G, v.B } }
    end
    return v
end

local function deserialize_value(v)
    if type(v) == "table" and type(v.__color3) == "table" and #v.__color3 == 3 and Color3 and Color3.new then
        return Color3.new(v.__color3[1], v.__color3[2], v.__color3[3])
    end
    return v
end

local function resolve_profile_args(arg1, arg2)
    local targetEnv, targetName
    if type(arg1) == "string" then
        targetName = arg1
        targetEnv = type(arg2) == "table" and arg2 or Settings._lastEnv or _G.Library
    elseif type(arg1) == "table" then
        targetEnv = (arg1._rawOptions and arg1) or (arg1.Env and arg1.Env._rawOptions and arg1.Env) or Settings._lastEnv or _G.Library
        targetName = type(arg2) == "string" and arg2 or nil
    end
    local ok, err = Settings.ValidateProfileName(targetName)
    assert(ok, err or "Invalid profile name!")
    return targetEnv, targetName
end

function Settings.Save(arg1, arg2)
    local targetEnv, targetName = resolve_profile_args(arg1, arg2)

    local dump = { Options = {}, Toggles = {} }
    if targetEnv and targetEnv._rawOptions then
        for k, opt in pairs(targetEnv._rawOptions) do
            if type(k) ~= "string" or k:sub(1, 8) ~= "Settings" then
                dump.Options[k] = serialize_value(opt.Value)
            end
        end
    end
    if targetEnv and targetEnv._rawToggles then
        for k, tog in pairs(targetEnv._rawToggles) do
            if type(k) ~= "string" or k:sub(1, 8) ~= "Settings" then
                dump.Toggles[k] = tog.Value
            end
        end
    end

    local hs = Settings._getHttpService()
    local json = hs:JSONEncode(dump)
    local folder = Settings.GetFolder()
    Settings._profilesByFolder[folder] = Settings._profilesByFolder[folder] or {}
    Settings._profilesByFolder[folder][targetName] = json
    Settings.Profiles[targetName] = json
    Settings._profiles[targetName] = json
    if targetEnv and targetEnv._profiles then
        targetEnv._profiles[targetName] = json
    end

    -- Write to disk if writefile available (uses isolated project Folder)
    pcall(function()
        if writefile then
            ensure_folder_tree(folder .. "/Configs")
            writefile(folder .. "/Configs/" .. targetName .. ".json", json)
        end
    end)

    return true
end

function Settings.Load(arg1, arg2)
    local targetEnv, targetName = resolve_profile_args(arg1, arg2)

    local folder = Settings.GetFolder()
    local folderProfiles = Settings._profilesByFolder[folder]
    local json = (folderProfiles and folderProfiles[targetName])
        or (folder == Settings._uiRoot and (Settings.Profiles[targetName] or (targetEnv and targetEnv._profiles and targetEnv._profiles[targetName])))
    if not json then
        pcall(function()
            if readfile and (not isfile or isfile(folder .. "/Configs/" .. targetName .. ".json")) then
                json = readfile(folder .. "/Configs/" .. targetName .. ".json")
            end
        end)
    end

    if not json then
        return false, "Profile not found: " .. tostring(targetName)
    end

    local hs = Settings._getHttpService()
    local decoded = hs:JSONDecode(json)
    if targetEnv then
        if decoded.Options and targetEnv._rawOptions then
            for k, v in pairs(decoded.Options) do
                if targetEnv._rawOptions[k] then targetEnv._rawOptions[k]:Set(deserialize_value(v)) end
            end
        end
        if decoded.Toggles and targetEnv._rawToggles then
            for k, v in pairs(decoded.Toggles) do
                if targetEnv._rawToggles[k] then targetEnv._rawToggles[k]:Set(v) end
            end
        end
    end
    return true
end

function Settings.Delete(arg1, arg2)
    local targetEnv, targetName = resolve_profile_args(arg1, arg2)

    local folder = Settings.GetFolder()
    if Settings._profilesByFolder[folder] then
        Settings._profilesByFolder[folder][targetName] = nil
    end
    if folder == Settings._uiRoot then
        Settings.Profiles[targetName] = nil
        Settings._profiles[targetName] = nil
        if targetEnv and targetEnv._profiles then
            targetEnv._profiles[targetName] = nil
        end
    end
    if Settings.GetDefault() == targetName then
        Settings.ClearDefault()
    end
    pcall(function()
        local p = folder .. "/Configs/" .. targetName .. ".json"
        if delfile and isfile and isfile(p) then
            delfile(p)
        end
    end)
    return true
end

function Settings.Reset(arg1)
    local targetEnv = (type(arg1) == "table" and ((arg1._rawOptions and arg1) or (arg1.Env and arg1.Env._rawOptions and arg1.Env)))
        or Settings._lastEnv
        or (type(_G.Library) == "table" and _G.Library)

    if not targetEnv then return end
    if targetEnv._initialDefaults and targetEnv._initialDefaults.Options and targetEnv._rawOptions then
        for k, def in pairs(targetEnv._initialDefaults.Options) do
            if (type(k) ~= "string" or k:sub(1, 8) ~= "Settings") and targetEnv._rawOptions[k] then
                targetEnv._rawOptions[k]:Set(def)
            end
        end
    end
    if targetEnv._initialDefaults and targetEnv._initialDefaults.Toggles and targetEnv._rawToggles then
        for k, def in pairs(targetEnv._initialDefaults.Toggles) do
            if (type(k) ~= "string" or k:sub(1, 8) ~= "Settings") and targetEnv._rawToggles[k] then
                targetEnv._rawToggles[k]:Set(def)
            end
        end
    end
end

function Settings.ListConfigs()
    local seen = {}
    local out = {}
    local folder = Settings.GetFolder()
    local folderProfiles = Settings._profilesByFolder[folder] or (folder == Settings._uiRoot and Settings.Profiles) or {}
    for name in pairs(folderProfiles) do
        if type(name) == "string" and name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(out, name)
        end
    end
    pcall(function()
        local cfgDir = folder .. "/Configs"
        if listfiles and (not isfolder or isfolder(cfgDir)) then
            for _, path in ipairs(listfiles(cfgDir)) do
                local name = tostring(path):match("([^\\/]+)%.json$")
                if name and name ~= "" and not seen[name] then
                    seen[name] = true
                    table.insert(out, name)
                end
            end
        end
    end)
    table.sort(out)
    return out
end

function Settings.SetDefault(name)
    local ok, err = Settings.ValidateProfileName(name)
    assert(ok, err or "Invalid profile name!")
    local folder = Settings.GetFolder()
    Settings._defaultConfig = name
    pcall(function()
        if writefile then
            ensure_folder_tree(folder)
            writefile(folder .. "/default_config.txt", name)
        end
    end)
    return true
end

function Settings.GetDefault()
    if Settings._defaultConfig and Settings._defaultConfig ~= "" then
        return Settings._defaultConfig
    end
    local folder = Settings.GetFolder()
    local saved = nil
    pcall(function()
        local p = folder .. "/default_config.txt"
        if readfile and (not isfile or isfile(p)) then
            saved = readfile(p)
        end
    end)
    if type(saved) == "string" and saved ~= "" then
        Settings._defaultConfig = saved
        return saved
    end
    return nil
end

function Settings.ClearDefault()
    Settings._defaultConfig = nil
    local folder = Settings.GetFolder()
    local p = folder .. "/default_config.txt"
    pcall(function()
        if delfile and isfile and isfile(p) then
            delfile(p)
        elseif writefile then
            ensure_folder_tree(folder)
            writefile(p, "")
        end
    end)
    return true
end

function Settings.SaveUI(win)
    if not win or not win.Env then return false end
    local env = win.Env
    local rawOpt = env._rawOptions or {}
    local rawTog = env._rawToggles or {}
    local minKey = rawOpt.SettingsMinimizeKey and rawOpt.SettingsMinimizeKey.Key or false
    local uiData = {
        Theme = (rawOpt.SettingsTheme and rawOpt.SettingsTheme.Value) or win.Theme or "Dark",
        MinimizeKey = minKey,
        InputBlock = (rawTog.SettingsInputBlock and rawTog.SettingsInputBlock.Value) == true,
        KeybindList = (rawTog.SettingsKeybindList and rawTog.SettingsKeybindList.Value) == true,
        NotifySide = (rawOpt.SettingsNotifySide and rawOpt.SettingsNotifySide.Value) or "Right",
    }
    local hs = Settings._getHttpService()
    local json = hs:JSONEncode(uiData)
    Settings._uiPrefs = json
    pcall(function()
        if writefile then
            if isfolder and makefolder then
                if not isfolder("BreezeUI") then makefolder("BreezeUI") end
            end
            writefile("BreezeUI/ui_prefs.json", json)
        end
    end)
    return true
end

function Settings.LoadUI(win)
    if not win or not win.Env then return false end
    local json = Settings._uiPrefs
    if not json then
        pcall(function()
            if readfile and (not isfile or isfile("BreezeUI/ui_prefs.json")) then
                json = readfile("BreezeUI/ui_prefs.json")
            end
        end)
    end
    if not json or json == "" then return false end
    local ok, data = pcall(function() return Settings._getHttpService():JSONDecode(json) end)
    if not ok or type(data) ~= "table" then return false end
    local env = win.Env
    local rawOpt = env._rawOptions or {}
    local rawTog = env._rawToggles or {}
    Settings._loadingUI = true
    pcall(function()
        if data.Theme then
            if rawOpt.SettingsTheme then rawOpt.SettingsTheme:Set(data.Theme) end
            if win.SetTheme then win:SetTheme(data.Theme) end
        end
        if data.MinimizeKey ~= nil then
            local resolvedMin = (data.MinimizeKey ~= false) and data.MinimizeKey or nil
            if rawOpt.SettingsMinimizeKey then rawOpt.SettingsMinimizeKey:Set(resolvedMin) end
            if win.SetToggleKey then
                win.ToggleKeyMinimizes = true
                win:SetToggleKey(resolvedMin)
            end
        end
        if data.InputBlock ~= nil then
            local blk = data.InputBlock == true
            if rawTog.SettingsInputBlock then rawTog.SettingsInputBlock:Set(blk) end
            if win.SetInputBlocking then win:SetInputBlocking(blk) end
        end
        if data.KeybindList ~= nil then
            local kl = data.KeybindList == true
            if rawTog.SettingsKeybindList then rawTog.SettingsKeybindList:Set(kl) end
            if win.SetKeybindMenuVisible then win:SetKeybindMenuVisible(kl) end
        end
        if data.NotifySide then
            if rawOpt.SettingsNotifySide then rawOpt.SettingsNotifySide:Set(data.NotifySide) end
            if env.SetNotifySide then env:SetNotifySide(data.NotifySide) end
        end
    end)
    Settings._loadingUI = false
    return true
end

function Settings.BuildTab(win)
    assert(win ~= nil, "Settings.BuildTab requires a Window instance!")
    if win.Folder and win.Folder ~= "" then
        Settings.SetFolder(win.Folder)
    end
    local tab = win:Tab({ Title = "Settings", Icon = "settings" })

    -- ── Interface ──────────────────────────────────────────────────────────────
    local secIface = tab:Section({ Title = "Interface" })

    local themes = (win.Env and win.Env.GetThemes and win.Env:GetThemes()) or ThemeModule.GetThemes()
    secIface:AddDropdown("SettingsTheme", {
        Text             = "Theme",
        Values           = themes,
        SearchBarEnabled = true,
        Default          = (win.Theme and win.Theme ~= "" and win.Theme) or "Dark",
        Callback = function(val)
            if win.SetTheme then win:SetTheme(val) end
            if not Settings._loadingUI then Settings.SaveUI(win) end
        end,
    })

    -- ── Behavior ──────────────────────────────────────────────────────────────
    local secBehav = tab:Section({ Title = "Behavior" })

    win.ToggleKeyMinimizes = true
    local minKb = secBehav:AddKeybind("SettingsMinimizeKey", {
        Title     = "Minimize Key",
        Default   = win.ToggleKey or "F1",
        Blacklist = { 1, 2 },
        Callback  = function(key)
            if win.SetToggleKey then
                win.ToggleKeyMinimizes = true
                win:SetToggleKey(key)
            end
            if not Settings._loadingUI then Settings.SaveUI(win) end
        end,
    })
    if win.SetToggleKey and minKb.Key then
        win:SetToggleKey(minKb.Key)
    end
    minKb.HideFromKeybindList = true

    secBehav:AddToggle("SettingsKeybindList", {
        Text     = "Keybind List",
        Default  = false,
        Callback = function(val)
            if win.SetKeybindMenuVisible then win:SetKeybindMenuVisible(val) end
            if not Settings._loadingUI then Settings.SaveUI(win) end
        end,
    })

    secBehav:AddToggle("SettingsInputBlock", {
        Text     = "Block Roblox Input",
        Default  = false,
        Callback = function(val)
            if win.SetInputBlocking then win:SetInputBlocking(val) end
            if not Settings._loadingUI then Settings.SaveUI(win) end
        end,
    })

    secBehav:AddDropdown("SettingsNotifySide", {
        Text    = "Notify Side",
        Values  = { "Right", "Left" },
        Default = "Right",
        Callback = function(val)
            local lib = win.Env
            if lib and lib.SetNotifySide then
                lib:SetNotifySide(val)
            end
            if not Settings._loadingUI then Settings.SaveUI(win) end
        end,
    })

    -- ── Config ────────────────────────────────────────────────────────────────
    local secConfig = tab:Section({ Title = "Config" })

    secConfig:AddInput("SettingsProfileName", {
        Text        = "Config Name",
        Default     = Settings.GetDefault() or "Default",
        Placeholder = "Enter name...",
    })

    local cfgDrop = secConfig:AddDropdown("SettingsConfigList", {
        Text      = "Configs",
        Values    = Settings.ListConfigs(),
        AllowNone = true,
        Default   = Settings.GetDefault(),
        Callback  = function(val)
            local env = win.Env
            local input = env and env._rawOptions and env._rawOptions.SettingsProfileName
            if input and type(val) == "string" and val ~= "" then
                input:Set(val)
            end
        end,
    })

    local function get_selected_config()
        local env = win.Env
        local input = env and env._rawOptions and env._rawOptions.SettingsProfileName
        local name = input and input.Value or ""
        if name == "" and cfgDrop and type(cfgDrop.Value) == "string" then
            name = cfgDrop.Value
        end
        return (name ~= "" and name) or "Default"
    end

    secConfig:AddButton({
        Text = "Save Config",
        Callback = function()
            local env = win.Env
            local name = get_selected_config()
            local ok, err = pcall(Settings.Save, name, env)
            if ok then
                cfgDrop:Refresh(Settings.ListConfigs())
                if env and env.Notify then
                    env:Notify({ Title = "Config", Content = "Saved '" .. name .. "'.", Icon = "check", Duration = 3 })
                end
            elseif env and env.Notify then
                env:Notify({ Title = "Config", Content = "Save failed: " .. tostring(err), Duration = 4 })
            end
        end,
    })

    secConfig:AddButton({
        Text = "Load Config",
        Callback = function()
            local env = win.Env
            local name = get_selected_config()
            local ok, loadedOrErr = pcall(Settings.Load, name, env)
            if ok and loadedOrErr and env and env.Notify then
                env:Notify({ Title = "Config", Content = "Loaded '" .. name .. "'.", Icon = "check", Duration = 3 })
            elseif env and env.Notify then
                env:Notify({ Title = "Config", Content = "Load failed: " .. tostring(loadedOrErr), Duration = 4 })
            end
        end,
    })

    secConfig:AddButton({
        Text = "Set Default",
        Callback = function()
            local env = win.Env
            local name = get_selected_config()
            local ok, err = pcall(Settings.SetDefault, name)
            if ok and env and env.Notify then
                env:Notify({ Title = "Config", Content = "Default set to '" .. name .. "'.", Icon = "check", Duration = 3 })
            elseif not ok and env and env.Notify then
                env:Notify({ Title = "Config", Content = "Set Default failed: " .. tostring(err), Duration = 4 })
            end
        end,
    })

    secConfig:AddButton({
        Text = "Reset Default",
        Callback = function()
            local env = win.Env
            Settings.ClearDefault()
            Settings.Reset(env)
            if env and env.Notify then
                env:Notify({ Title = "Config", Content = "Default cleared and values reset.", Icon = "check", Duration = 3 })
            end
        end,
    })

    secConfig:AddButton({
        Text = "Delete Config",
        Callback = function()
            local env = win.Env
            local name = get_selected_config()
            local ok, err = pcall(Settings.Delete, name, env)
            if ok then
                cfgDrop:Refresh(Settings.ListConfigs())
                if env and env.Notify then
                    env:Notify({ Title = "Config", Content = "Deleted '" .. name .. "'.", Icon = "trash-2", Duration = 3 })
                end
            elseif env and env.Notify then
                env:Notify({ Title = "Config", Content = "Delete failed: " .. tostring(err), Duration = 4 })
            end
        end,
    })

    -- Auto-load saved default config (if set) and UI auto-saved preferences
    local defCfg = Settings.GetDefault()
    if defCfg then
        pcall(Settings.Load, defCfg, win.Env)
    end
    Settings.LoadUI(win)

    return tab
end

return Settings
