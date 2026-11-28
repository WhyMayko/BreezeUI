-- Library/BreezeUI/Layout/Sidebar.lua
-- Navigation container with live interactive Search bar, collapsible sections, and layout sync invariant.

local PoolModule = Pool or require("../Core/Pool")
local MetaModule = Meta or require("../Core/Meta")
local GeometryModule = Geometry or require("../Core/Geometry")
local MetricsModule = Metrics or require("../Core/Metrics")
local ThemeModule = Theme or require("./Theme")
local TabModule = Tab or require("./Tab")
local ProfileCardModule = ProfileCard or require("./ProfileCard")
local IconsModule = Icons or require("../Subsystems/Icons")

local Sidebar = {}
Sidebar.__index = Sidebar

local function get_theme_color(token, default)
    return ThemeModule.Get(token, default)
end

-- ============================================================================
-- Section Class (NavigationSection)
-- ============================================================================

local Section = {}
Section.__index = Section

function Section.new(sidebar, config)
    local cfg = type(config) == "table" and config or { Title = tostring(config or "Section") }
    local self = setmetatable({
        Type = "Section",
        Title = cfg.Title or "Section",
        Opened = cfg.Opened ~= false,
        Sidebar = sidebar,
        Tabs = {},
        Height = 26,
        HeaderHeight = 26,
        RelX = 10,
        RelY = 0,
        Visible = true,

        -- Primitives
        Caret = nil,
        TitleText = nil,
    }, Section)

    self:_initDrawings()
    return self
end

function Section:_initDrawings()
    local pool = self.Sidebar.Pool
    if not pool then return end
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    local tri = pool:Get("Image")
    tri.Size = Vector2.new(12, 12)
    tri.Transparency = 0.34
    tri.ZIndex = 4
    tri.Visible = true
    self.Caret = tri
    self:_syncCaretIcon()

    local txt = pool:Get("Text")
    txt.Size = 11
    txt.Font = fontUI
    txt.Outline = false
    txt.Color = get_theme_color("Text.Muted", Color3.fromRGB(120, 120, 130))
    txt.ZIndex = 4
    txt.Visible = true
    self.TitleText = txt

    local win = self.Sidebar.Window
    if win and win._drawings then
        table.insert(win._drawings, self.Caret)
        table.insert(win._drawings, self.TitleText)
    end
end

function Section:_syncCaretIcon()
    if not self.Caret or not IconsModule or not IconsModule.Get then return end
    if not self._caretCb then
        self._caretCb = function(png)
            if self.Caret and png then
                self.Caret.Data = png
            end
        end
    end
    local iconName = self.Opened and "chevron-up" or "chevron-down"
    IconsModule.Get(iconName, self._caretCb)
end

function Section:HasActiveChild()
    local win = self.Sidebar.Window
    local curTab = win and win.ActiveTab
    if not curTab then return false end
    for _, tab in ipairs(self.Tabs) do
        if tab == curTab then return true end
    end
    return false
end

-- Always recalculate positions unconditionally (never skip when minimized/hidden!)
function Section:UpdatePositions(winPos)
    local hx = winPos.X + self.RelX
    local hy = winPos.Y + self.RelY
    local sbW = (self.Sidebar and self.Sidebar.Width or 190) - 20

    local mutedCol = get_theme_color("Text.Muted", Color3.fromRGB(120, 120, 130))
    local titleCol = get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))
    local isHighlighted = (not self.Opened) and self:HasActiveChild()

    if self.Caret then
        self.Caret.Position = Vector2.new(hx + sbW - 16, hy + 7)
        self.Caret.Transparency = isHighlighted and 0.90 or 0.34
    end

    local rawTitle = tostring(self.Title)
    local fitted = MetricsModule and MetricsModule.Fit and MetricsModule.Fit(rawTitle, sbW - 24, 11) or rawTitle

    if self.TitleText then
        self.TitleText.Text = fitted
        self.TitleText.Position = Vector2.new(hx + 6, hy + math.floor((self.Height - 11) * 0.5))
        self.TitleText.Color = isHighlighted and titleCol or mutedCol
    end
end

function Section:SetVisible(vis)
    self.Visible = vis
    if self.Caret then self.Caret.Visible = vis end
    if self.TitleText then self.TitleText.Visible = vis end

    for _, tab in ipairs(self.Tabs) do
        tab:SetSidebarVisible(vis and (self.Opened or self.Sidebar.SearchQuery ~= ""))
    end
end

function Section:Tab(tabConfig)
    assert(TabModule, "Tab module not available!")
    local tab = TabModule.new(tabConfig, self.Sidebar.Window, self)
    tab.ParentSection = self

    table.insert(self.Tabs, tab)
    table.insert(self.Sidebar.Tabs, tab)
    if self.Sidebar.Window and self.Sidebar.Window.Tabs then
        table.insert(self.Sidebar.Window.Tabs, tab)
    end

    self.Sidebar:RecalculateLayout()

    if self.Sidebar.Window and not self.Sidebar.Window.ActiveTab then
        self.Sidebar.Window:SelectTab(tab)
    end
    return tab
end

function Section:Toggle()
    self.Opened = not self.Opened
    self:_syncCaretIcon()
    self.Sidebar:RecalculateLayout()
end

-- ============================================================================
-- Sidebar Container Class
-- ============================================================================

function Sidebar.new(window, config)
    local cfg = config or {}
    local pool = window and window.Pool

    local self = setmetatable({
        Window = window,
        Pool = pool,
        Theme = window and window.Theme,

        -- Geometry
        RelX = 10,
        RelY = 82,
        Width = cfg.Width or (window and window.SidebarWidth) or 190,

        -- Search state
        SearchFocused = false,
        SearchQuery = "",

        -- Collections
        Items = {},
        Sections = {},
        Tabs = {},

        -- Primitives
        Divider = nil,
        SearchBox = nil,
        SearchBorder = nil,
        SearchIcon = nil,
        SearchText = nil,
        Visible = true,
        Destroyed = false,
    }, Sidebar)

    self:_initDivider()
    self:_initSearchBar()
    if ProfileCardModule then
        self.ProfileCard = ProfileCardModule.new(self, window and window.ProfileConfig)
    end
    return self
end

function Sidebar:_initSearchBar()
    local pool = self.Pool
    if not pool then return end
    local fontUI = (Drawing and Drawing.Fonts and Drawing.Fonts.System) or 1

    local winPos = self.Window and self.Window.Position or Vector2.new(0, 0)
    local sbW = self.Width - 20
    local sbX = winPos.X + 10
    local sbY = winPos.Y + 46

    local box = pool:Get("Square")
    box.Position = Vector2.new(sbX, sbY)
    box.Size = Vector2.new(sbW, 28)
    box.Color = get_theme_color("Dialog", Color3.fromRGB(26, 26, 26))
    box.Filled = true
    box.Corner = 7
    box.ZIndex = 4
    box.Visible = true
    self.SearchBox = box

    local border = pool:Get("Square")
    border.Position = Vector2.new(sbX, sbY)
    border.Size = Vector2.new(sbW, 28)
    border.Color = get_theme_color("Window.Border", Color3.fromRGB(36, 36, 40))
    border.Filled = false
    border.Thickness = 1
    border.Corner = 7
    border.ZIndex = 4
    border.Visible = true
    self.SearchBorder = border

    local ico = pool:Get("Image")
    ico.Position = Vector2.new(sbX + 9, sbY + 8)
    ico.Size = Vector2.new(12, 12)
    ico.Transparency = 0.55
    ico.ZIndex = 5
    ico.Visible = true
    self.SearchIcon = ico
    if IconsModule and IconsModule.Get then
        IconsModule.Get("search", function(png)
            if self.SearchIcon and png then self.SearchIcon.Data = png end
        end)
    end

    local txt = pool:Get("Text")
    txt.Position = Vector2.new(sbX + 27, sbY + 7)
    txt.Text = "Search"
    txt.Font = fontUI
    txt.Outline = false
    txt.Size = 12
    txt.Color = get_theme_color("Text.Muted", Color3.fromRGB(122, 122, 134))
    txt.ZIndex = 5
    txt.Visible = true
    self.SearchText = txt

    if self.Window and self.Window._drawings then
        table.insert(self.Window._drawings, box)
        table.insert(self.Window._drawings, border)
        table.insert(self.Window._drawings, ico)
        table.insert(self.Window._drawings, txt)
    end
end

function Sidebar:_initDivider()
    local pool = self.Pool
    if not pool then return end

    local div = pool:Get("Square")
    local winPos = self.Window and self.Window.Position or Vector2.new(0, 0)
    local winSize = self.Window and self.Window.Size or Vector2.new(620, 440)
    local divX = winPos.X + self.Width
    local divY = winPos.Y + 46
    local divH = math.max(0, winSize.Y - 58)
    local divCol = get_theme_color("Sidebar.Divider", Color3.fromRGB(28, 28, 34))

    div.Position = Vector2.new(divX, divY)
    div.Size = Vector2.new(1, divH)
    div.Color = divCol
    div.Filled = true
    div.ZIndex = 2
    div.Visible = false
    self.Divider = div

    if self.Window and self.Window._drawings then
        table.insert(self.Window._drawings, div)
    end
end

function Sidebar:RefreshSearchDisplay()
    if not self.SearchText then return end
    if #self.SearchQuery > 0 then
        local caret = (self.SearchFocused and math.floor(os.clock() * 2) % 2 == 0) and "|" or ""
        self.SearchText.Text = self.SearchQuery .. caret
        self.SearchText.Color = get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))
    elseif self.SearchFocused then
        self.SearchText.Text = (math.floor(os.clock() * 2) % 2 == 0) and "|" or ""
        self.SearchText.Color = get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))
    else
        self.SearchText.Text = "Search"
        self.SearchText.Color = get_theme_color("Text.Muted", Color3.fromRGB(122, 122, 134))
    end

    if self.SearchBorder then
        self.SearchBorder.Color = self.SearchFocused
            and get_theme_color("Accent.Blue", Color3.fromRGB(0, 145, 255))
            or get_theme_color("Window.Border", Color3.fromRGB(40, 40, 48))
    end
end

local function tab_matches_query(tab, q)
    if tostring(tab.Title or ""):lower():find(q, 1, true) then
        return true
    end
    for _, sec in ipairs(tab.Sections or {}) do
        if sec.Title and tostring(sec.Title):lower():find(q, 1, true) then
            return true
        end
        for _, ctrl in ipairs(sec.Controls or {}) do
            local t = ctrl.Text or ctrl.Title
            local d = ctrl.Desc or ctrl.Description
            if (t and tostring(t):lower():find(q, 1, true))
                or (d and tostring(d):lower():find(q, 1, true)) then
                return true
            end
        end
    end
    return false
end

function Sidebar:SetSearchQuery(query)
    self.SearchQuery = tostring(query or "")
    local q = self.SearchQuery:lower()

    for _, tab in ipairs(self.Tabs) do
        if q == "" then
            tab.FilteredOut = false
        else
            tab.FilteredOut = not tab_matches_query(tab, q)
        end
    end

    self:RefreshSearchDisplay()
    self:RecalculateLayout()
end

function Sidebar:FocusSearch()
    self.SearchFocused = true
    if self.Window and self.Window.ClaimInteraction then
        self.Window:ClaimInteraction("SidebarSearch")
    end
    self:RefreshSearchDisplay()
end

function Sidebar:BlurSearch()
    self.SearchFocused = false
    if self.Window and self.Window.ReleaseInteraction then
        self.Window:ReleaseInteraction("SidebarSearch")
    end
    self:RefreshSearchDisplay()
end

function Sidebar:ProcessSearchKey(token)
    if not self.SearchFocused or not token then return end
    if token == "enter" then
        self:BlurSearch()
    elseif token == "escape" then
        self:SetSearchQuery("")
        self:BlurSearch()
    elseif token == "backspace" then
        if #self.SearchQuery > 0 then
            self:SetSearchQuery(string.sub(self.SearchQuery, 1, #self.SearchQuery - 1))
        end
    elseif token == "clear" then
        self:SetSearchQuery("")
    elseif #self.SearchQuery < 32 then
        self:SetSearchQuery(self.SearchQuery .. token)
    end
end

function Sidebar:RecalculateLayout()
    local curRelY = self.RelY
    local winPos = self.Window and self.Window.Position or Vector2.new(0, 0)
    local winSize = self.Window and self.Window.Size or Vector2.new(620, 440)
    local maxRelY = winSize.Y - ((self.ProfileCard and self.ProfileCard.Enabled) and 64 or 6)
    local isSearching = self.SearchQuery ~= ""

    for _, item in ipairs(self.Items) do
        if item.Type == "Section" then
            local matchingTabs = 0
            for _, tab in ipairs(item.Tabs) do
                if not tab.FilteredOut then
                    matchingTabs = matchingTabs + 1
                end
            end

            if isSearching and matchingTabs == 0 then
                if item.Caret then item.Caret.Visible = false end
                if item.TitleText then item.TitleText.Visible = false end
                for _, tab in ipairs(item.Tabs) do
                    tab:SetSidebarVisible(false)
                end
            else
                item.RelY = curRelY
                item:UpdatePositions(winPos)
                local secFits = self.Visible and (curRelY + item.Height <= maxRelY)
                if item.Caret then item.Caret.Visible = secFits and (#item.Tabs > 0) and not isSearching end
                if item.TitleText then item.TitleText.Visible = secFits end
                curRelY = curRelY + item.Height

                if item.Opened or isSearching then
                    for _, tab in ipairs(item.Tabs) do
                        if not tab.FilteredOut then
                            tab.RelY = curRelY
                            tab:UpdateSidebarPositions(winPos)
                            local fits = self.Visible and (curRelY + tab.Height <= maxRelY)
                            tab:SetSidebarVisible(fits)
                            curRelY = curRelY + tab.Height + 4
                        else
                            tab:SetSidebarVisible(false)
                        end
                    end
                else
                    for _, tab in ipairs(item.Tabs) do
                        tab:SetSidebarVisible(false)
                    end
                end
            end
        elseif item.Type == "Tab" then
            if not item.FilteredOut then
                item.RelY = curRelY
                item:UpdateSidebarPositions(winPos)
                local fits = self.Visible and (curRelY + item.Height <= maxRelY)
                item:SetSidebarVisible(fits)
                curRelY = curRelY + item.Height + 4
            else
                item:SetSidebarVisible(false)
            end
        end
    end
end

function Sidebar:AddSection(config)
    local sec = Section.new(self, config)
    table.insert(self.Items, sec)
    table.insert(self.Sections, sec)
    if self.Window and self.Window.Sections then
        table.insert(self.Window.Sections, sec)
    end
    self:RecalculateLayout()
    return sec
end

function Sidebar:AddTab(config)
    assert(TabModule, "Tab module not available!")
    local tab = TabModule.new(config, self.Window, nil)
    table.insert(self.Items, tab)
    table.insert(self.Tabs, tab)
    if self.Window and self.Window.Tabs then
        table.insert(self.Window.Tabs, tab)
    end
    self:RecalculateLayout()

    if self.Window and not self.Window.ActiveTab then
        self.Window:SelectTab(tab)
    end
    return tab
end

function Sidebar:Tab(config)
    return self:AddTab(config)
end

function Sidebar:SetPosition(pos)
    local winPos = pos or (self.Window and self.Window.Position) or Vector2.new(0, 0)
    local sbX = winPos.X + 10
    local sbY = winPos.Y + 46

    if self.Divider then
        self.Divider.Position = Vector2.new(winPos.X + self.Width, sbY)
    end
    if self.SearchBox then
        self.SearchBox.Position = Vector2.new(sbX, sbY)
    end
    if self.SearchBorder then
        self.SearchBorder.Position = Vector2.new(sbX, sbY)
    end
    if self.SearchIcon then
        self.SearchIcon.Position = Vector2.new(sbX + 9, sbY + 8)
    end
    if self.SearchText then
        self.SearchText.Position = Vector2.new(sbX + 27, sbY + 7)
    end

    self:RecalculateLayout()
    if self.ProfileCard then self.ProfileCard:UpdateLayout() end
end

function Sidebar:SetSize(size)
    local winSize = self.Window and self.Window.Size or Vector2.new(620, 440)
    local divH = math.max(0, winSize.Y - 58)
    local sbW = self.Width - 20

    if self.Divider then
        self.Divider.Size = Vector2.new(1, divH)
    end
    if self.SearchBox then
        self.SearchBox.Size = Vector2.new(sbW, 28)
    end
    if self.SearchBorder then
        self.SearchBorder.Size = Vector2.new(sbW, 28)
    end

    self:RecalculateLayout()
    if self.ProfileCard then self.ProfileCard:UpdateLayout() end
end

function Sidebar:SetVisible(visible)
    self.Visible = visible
    if not visible and self.SearchFocused then
        self:BlurSearch()
    end
    if not visible and self.Divider then self.Divider.Visible = false end
    if self.SearchBox then self.SearchBox.Visible = visible end
    if self.SearchBorder then self.SearchBorder.Visible = visible end
    if self.SearchIcon then self.SearchIcon.Visible = visible end
    if self.SearchText then self.SearchText.Visible = visible end

    self:RecalculateLayout()
    if self.ProfileCard then self.ProfileCard:SetVisible(visible) end
end

function Sidebar:UpdateTheme(t)
    local divCol = t["Sidebar.Divider"] or t.Divider or get_theme_color("Sidebar.Divider", Color3.fromRGB(30, 30, 32))
    local boxCol = t.Dialog or get_theme_color("Dialog", Color3.fromRGB(26, 26, 26))
    local borderCol = t.Border or get_theme_color("Window.Border", Color3.fromRGB(36, 36, 40))
    local mutedCol = t["Text.Muted"] or get_theme_color("Text.Muted", Color3.fromRGB(161, 161, 161))
    local titleCol = t["Text.Title"] or get_theme_color("Text.Title", Color3.fromRGB(255, 255, 255))
    if self.Divider then
        self.Divider.Color = divCol
    end
    if self.SearchBox then
        self.SearchBox.Color = boxCol
    end
    if self.SearchBorder then
        self.SearchBorder.Color = self.SearchFocused
            and get_theme_color("Accent.Blue", Color3.fromRGB(0, 145, 255))
            or borderCol
    end
    for _, sec in ipairs(self.Sections or {}) do
        if sec.TitleText then
            local isHighlighted = (not sec.Opened) and sec:HasActiveChild()
            sec.TitleText.Color = isHighlighted and titleCol or mutedCol
        end
    end
    self:RefreshSearchDisplay()
    self:RecalculateLayout()
    if self.ProfileCard then self.ProfileCard:UpdateTheme(t) end
end

function Sidebar:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self:SetVisible(false)

    for _, tab in ipairs(self.Tabs) do
        if tab.Destroy then tab:Destroy() end
    end

    self.Items = {}
    self.Sections = {}
    self.Tabs = {}
end

return Sidebar
