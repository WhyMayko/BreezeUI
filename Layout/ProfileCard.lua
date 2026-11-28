-- Library/BreezeUI/Layout/ProfileCard.lua
-- WindUI-style sidebar footer player card with click-to-open compact profile info menu.

local PoolModule = Pool or require("../Core/Pool")
local MetricsModule = Metrics or require("../Core/Metrics")
local ThemeModule = Theme or require("./Theme")
local AnimationsModule = Animations or require("../Engine/Animations")

local ProfileCard = {}
ProfileCard.__index = ProfileCard

local function format_uptime(sec)
    sec = math.max(0, math.floor(sec or 0))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function resolve_local_player()
    if not (game and game.GetService) then
        return "Player", "Player", 0
    end
    local lp = game:GetService("Players").LocalPlayer
    if not lp then
        return "Player", "Player", 0
    end
    local uname = tostring(lp.Name or "Player")
    local dname = tostring(lp.DisplayName or uname)
    local uid = tonumber(lp.UserId) or 0
    return dname, uname, uid
end

function ProfileCard.new(sidebar, config)
    local cfg = type(config) == "table" and config or {}
    local enabled = (config ~= false) and (cfg.Enabled ~= false)
    local dname, uname, uid = resolve_local_player()

    local self = setmetatable({
        Sidebar = sidebar,
        Window = sidebar and sidebar.Window,
        Pool = sidebar and sidebar.Pool or PoolModule,
        Enabled = enabled,
        Open = false,
        OpenAnim = 0,
        Hovered = false,
        HoverAnim = 0,
        Height = 48,

        DisplayName = cfg.DisplayName or dname,
        Username = cfg.Username or uname,
        UserId = cfg.UserId or uid,
        Tag = cfg.Tag,
        Fields = type(cfg.Fields) == "table" and cfg.Fields or {},
        ShowUptime = cfg.ShowUptime ~= false,
        ShowFPS = cfg.ShowFPS ~= false,
        ShowDate = cfg.ShowDate ~= false,
        ShowTime = cfg.ShowTime ~= false,
        Callback = type(cfg.Callback) == "function" and cfg.Callback or nil,

        StartClock = os.clock(),
        LastTickSec = -1,
        FpsFrames = 0,
        FpsAccum = 0,
        CurrentFPS = 0,
        AvatarPng = nil,

        CardBg = nil,
        AvatarBg = nil,
        AvatarInitial = nil,
        AvatarImg = nil,
        NameText = nil,
        HandleText = nil,

        PopBg = nil,
        PopBorder = nil,
        PopName = nil,
        PopHandle = nil,
        PopDivider = nil,
        PopTagBg = nil,
        PopTagText = nil,
        PopRows = {},
    }, ProfileCard)

    if self.Enabled then
        self:_initDrawings()
        self:_fetchAvatar()
    end

    return self
end

function ProfileCard:_reg(obj)
    if self.Window and self.Window._drawings and obj then
        table.insert(self.Window._drawings, obj)
    end
end

function ProfileCard:_initDrawings()
    local pool = self.Pool
    if not pool then return end

    local bg = pool:Get("Square")
    bg.Filled = true
    bg.Corner = 8
    bg.ZIndex = 4
    bg.Visible = false
    self.CardBg = bg
    self:_reg(bg)

    local avBg = pool:Get("Square")
    avBg.Size = Vector2.new(32, 32)
    avBg.Filled = true
    avBg.Corner = 8
    avBg.ZIndex = 5
    avBg.Visible = true
    self.AvatarBg = avBg
    self:_reg(avBg)

    local avInit = pool:Get("Text")
    avInit.Size = 14
    avInit.Text = string.upper(string.sub(self.DisplayName, 1, 1))
    avInit.ZIndex = 6
    avInit.Visible = true
    self.AvatarInitial = avInit
    self:_reg(avInit)

    local avImg = pool:Get("Image")
    avImg.Size = Vector2.new(32, 32)
    avImg.ZIndex = 7
    avImg.Visible = false
    self.AvatarImg = avImg
    self:_reg(avImg)

    local nameTxt = pool:Get("Text")
    nameTxt.Size = 13
    nameTxt.ZIndex = 6
    nameTxt.Visible = true
    self.NameText = nameTxt
    self:_reg(nameTxt)

    local handleTxt = pool:Get("Text")
    handleTxt.Size = 11
    handleTxt.ZIndex = 6
    handleTxt.Visible = true
    self.HandleText = handleTxt
    self:_reg(handleTxt)

    -- Compact Profile Info Menu (DisplayName, @Username, optional Tag, Divider, and Info Rows — no duplicate avatar)
    local popBg = pool:Get("Square")
    popBg.Filled = true
    popBg.Corner = 10
    popBg.ZIndex = 30
    popBg.Visible = false
    self.PopBg = popBg
    self:_reg(popBg)

    local popBorder = pool:Get("Square")
    popBorder.Filled = false
    popBorder.Thickness = 1
    popBorder.Corner = 10
    popBorder.ZIndex = 31
    popBorder.Visible = false
    self.PopBorder = popBorder
    self:_reg(popBorder)

    local pName = pool:Get("Text")
    pName.Size = 13
    pName.ZIndex = 32
    pName.Visible = false
    self.PopName = pName
    self:_reg(pName)

    local pHandle = pool:Get("Text")
    pHandle.Size = 11
    pHandle.ZIndex = 32
    pHandle.Visible = false
    self.PopHandle = pHandle
    self:_reg(pHandle)

    local pTagBg = pool:Get("Square")
    pTagBg.Filled = true
    pTagBg.Corner = 5
    pTagBg.ZIndex = 31
    pTagBg.Visible = false
    self.PopTagBg = pTagBg
    self:_reg(pTagBg)

    local pTagTxt = pool:Get("Text")
    pTagTxt.Size = 10
    pTagTxt.ZIndex = 32
    pTagTxt.Visible = false
    self.PopTagText = pTagTxt
    self:_reg(pTagTxt)

    local pDiv = pool:Get("Square")
    pDiv.Filled = true
    pDiv.ZIndex = 31
    pDiv.Visible = false
    self.PopDivider = pDiv
    self:_reg(pDiv)

    self:_rebuildRows()
    self:UpdateTheme(ThemeModule.GetCurrent())
end

function ProfileCard:_buildRowSpecs()
    local rows = {}
    if self.ShowDate then
        table.insert(rows, { Key = "date", Label = "Date", Value = os.date("%d/%m/%Y") })
    end
    if self.ShowTime then
        table.insert(rows, { Key = "time", Label = "Time", Value = os.date("%H:%M:%S") })
    end
    if self.ShowUptime then
        table.insert(rows, { Key = "uptime", Label = "Uptime", Value = format_uptime(os.clock() - self.StartClock) })
    end
    if self.ShowFPS then
        table.insert(rows, { Key = "fps", Label = "FPS", Value = tostring(self.CurrentFPS) })
    end
    for _, f in ipairs(self.Fields) do
        if f.Label then
            table.insert(rows, { Key = "custom", Label = tostring(f.Label), Value = tostring(f.Value or "") })
        end
    end
    return rows
end

function ProfileCard:_rebuildRows()
    local pool = self.Pool
    if not pool then return end

    for _, r in ipairs(self.PopRows) do
        if r.LabelDraw then r.LabelDraw.Visible = false end
        if r.ValueDraw then r.ValueDraw.Visible = false end
    end
    self.PopRows = {}

    local specs = self:_buildRowSpecs()
    for _, spec in ipairs(specs) do
        local lDraw = pool:Get("Text")
        lDraw.Size = 11
        lDraw.Text = spec.Label
        lDraw.ZIndex = 32
        lDraw.Visible = false
        self:_reg(lDraw)

        local vDraw = pool:Get("Text")
        vDraw.Size = 11
        vDraw.Text = spec.Value
        vDraw.ZIndex = 32
        vDraw.Visible = false
        self:_reg(vDraw)

        table.insert(self.PopRows, {
            Key = spec.Key,
            Label = spec.Label,
            Value = spec.Value,
            LabelDraw = lDraw,
            ValueDraw = vDraw,
        })
    end
end

function ProfileCard:_fetchAvatar()
    local uid = self.UserId
    if uid <= 0 or not (game and game.HttpGet) then return end

    task.spawn(function()
        local thumbJson = game:HttpGet("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. tostring(uid) .. "&size=150x150&format=Png&isCircular=false")
        if self.Window and self.Window.Destroyed then return end
        local imgUrl = thumbJson and thumbJson:match('"imageUrl"%s*:%s*"(https://[^"]+)"')
        if imgUrl then
            local png = game:HttpGet(imgUrl)
            if self.Window and self.Window.Destroyed then return end
            if png and #png > 8 and png:sub(1, 4) == "\x89PNG" then
                self.AvatarPng = png
                if self.AvatarImg then self.AvatarImg.Data = png end
                self:UpdateLayout()
            end
        end
    end)
end

function ProfileCard:SetProfile(opts)
    assert(type(opts) == "table", "SetProfile requires options table!")
    if opts.Enabled ~= nil then self.Enabled = opts.Enabled == true end
    if opts.DisplayName ~= nil then self.DisplayName = tostring(opts.DisplayName) end
    if opts.Username ~= nil then self.Username = tostring(opts.Username) end
    if opts.Tag ~= nil then self.Tag = opts.Tag end
    if opts.ShowUptime ~= nil then self.ShowUptime = opts.ShowUptime == true end
    if opts.ShowFPS ~= nil then self.ShowFPS = opts.ShowFPS == true end
    if opts.ShowDate ~= nil then self.ShowDate = opts.ShowDate == true end
    if opts.ShowTime ~= nil then self.ShowTime = opts.ShowTime == true end
    if opts.Fields ~= nil then self.Fields = opts.Fields end
    if opts.Callback ~= nil then self.Callback = opts.Callback end
    if self.Enabled then
        self:_rebuildRows()
        self:UpdateTheme(ThemeModule.GetCurrent())
        self:UpdateLayout()
    else
        self:SetVisible(false)
    end
end

function ProfileCard:GetCardRect()
    local win = self.Window
    local wp = win and win.Position or Vector2.new(0, 0)
    local ws = win and win.Size or Vector2.new(620, 440)
    local sbW = (self.Sidebar and self.Sidebar.Width or 190) - 20
    local cx = wp.X + 10
    local cy = wp.Y + ws.Y - self.Height - 8
    return cx, cy, sbW, self.Height
end

function ProfileCard:_getTagConfig()
    if type(self.Tag) == "table" and self.Tag.Text and tostring(self.Tag.Text) ~= "" then
        return self.Tag
    elseif type(self.Tag) == "string" and self.Tag ~= "" then
        return { Text = self.Tag }
    end
    return nil
end

function ProfileCard:_animatePopover(opening)
    self.Open = opening
    AnimationsModule.Tween("profile_pop_" .. tostring(self), self.OpenAnim, opening and 1 or 0, opening and 18 or 22, function(v)
        self.OpenAnim = v
        self:UpdateLayout()
    end)
end

function ProfileCard:GetPopoverRect()
    local cx, cy, cw = self:GetCardRect()
    local rowsH = #self.PopRows * 20
    local ph = 48 + (#self.PopRows > 0 and (14 + rowsH) or 0)
    return cx, cy - ph - 6, cw, ph
end

function ProfileCard:UpdateLayout()
    if not self.Enabled or not self.CardBg then return end
    local vis = (self.Sidebar and self.Sidebar.Visible == true) and (self.Window and self.Window.Visible == true) and (not self.Window.Minimized)
    local cx, cy, cw, ch = self:GetCardRect()

    local hoverAlpha = self.Open and 1 or (self.HoverAnim or 0)
    self.CardBg.Position = Vector2.new(cx, cy)
    self.CardBg.Size = Vector2.new(cw, ch)
    self.CardBg.Transparency = hoverAlpha
    self.CardBg.Visible = vis and (self.Open or self.Hovered or hoverAlpha > 0.02)

    local initChar = string.upper(string.sub(self.DisplayName, 1, 1))
    local ix, iy = MetricsModule.AlignCenter(cx + 6, cy + 8, 32, 32, initChar, 14)
    self.AvatarBg.Position = Vector2.new(cx + 6, cy + 8)
    self.AvatarInitial.Position = Vector2.new(ix, iy)
    self.AvatarImg.Position = Vector2.new(cx + 6, cy + 8)
    local hasImg = self.AvatarPng ~= nil
    self.AvatarBg.Visible = vis and not hasImg
    self.AvatarInitial.Visible = vis and not hasImg
    self.AvatarImg.Visible = vis and hasImg

    local textMaxW = math.max(40, cw - 52)
    self.NameText.Text = MetricsModule.Fit(self.DisplayName, textMaxW, 13)
    self.NameText.Position = Vector2.new(cx + 46, cy + 9)
    self.NameText.Visible = vis

    self.HandleText.Text = MetricsModule.Fit("@" .. self.Username, textMaxW, 11)
    self.HandleText.Position = Vector2.new(cx + 46, cy + 25)
    self.HandleText.Visible = vis

    -- Popover (exponential slide-up + fade animation)
    local tagCfg = self:_getTagConfig()
    local anim = self.OpenAnim or 0
    local popVis = vis and (self.Open or anim > 0.02)
    local px, py, pw, ph = self:GetPopoverRect()
    py = py + math.floor((1 - anim) * 10 + 0.5)

    self.PopBg.Position = Vector2.new(px, py)
    self.PopBg.Size = Vector2.new(pw, ph)
    self.PopBg.Transparency = 0.15 + anim * 0.85
    self.PopBg.Visible = popVis

    self.PopBorder.Position = Vector2.new(px, py)
    self.PopBorder.Size = Vector2.new(pw, ph)
    self.PopBorder.Transparency = anim
    self.PopBorder.Visible = popVis

    local tagStr = tagCfg and tostring(tagCfg.Text) or ""
    local tagTextW = tagCfg and MetricsModule.Measure(tagStr, 10) or 0
    local tagW = tagCfg and math.max(36, tagTextW + 14) or 0
    local pTextW = math.max(40, pw - (tagCfg and (tagW + 28) or 20))

    self.PopName.Text = MetricsModule.Fit(self.DisplayName, pTextW, 13)
    self.PopName.Position = Vector2.new(px + 10, py + 9)
    self.PopName.Transparency = anim
    self.PopName.Visible = popVis

    self.PopHandle.Text = MetricsModule.Fit("@" .. self.Username, pTextW, 11)
    self.PopHandle.Position = Vector2.new(px + 10, py + 25)
    self.PopHandle.Transparency = anim
    self.PopHandle.Visible = popVis

    if tagCfg then
        local tx = px + pw - tagW - 10
        local ty = py + 13
        local th = 18
        local ax, ay = MetricsModule.AlignCenter(tx, ty, tagW, th, tagStr, 10)
        self.PopTagBg.Position = Vector2.new(tx, ty)
        self.PopTagBg.Size = Vector2.new(tagW, th)
        self.PopTagBg.Transparency = anim
        self.PopTagBg.Visible = popVis

        self.PopTagText.Text = tagStr
        self.PopTagText.Position = Vector2.new(ax, ay)
        self.PopTagText.Transparency = anim
        self.PopTagText.Visible = popVis
    else
        self.PopTagBg.Visible = false
        self.PopTagText.Visible = false
    end

    self.PopDivider.Position = Vector2.new(px + 10, py + 46)
    self.PopDivider.Size = Vector2.new(pw - 20, 1)
    self.PopDivider.Transparency = anim
    self.PopDivider.Visible = popVis and (#self.PopRows > 0)

    local curY = py + 54
    for _, r in ipairs(self.PopRows) do
        local valStr = tostring(r.Value)
        r.LabelDraw.Position = Vector2.new(px + 10, curY)
        r.LabelDraw.Transparency = anim
        r.LabelDraw.Visible = popVis
        r.ValueDraw.Text = valStr
        r.ValueDraw.Position = Vector2.new(MetricsModule.AlignRight(px, pw, valStr, 11, 10), curY)
        r.ValueDraw.Transparency = anim
        r.ValueDraw.Visible = popVis
        curY = curY + 20
    end
end

function ProfileCard:SetVisible(visible)
    if not visible then
        self.Open = false
        self.OpenAnim = 0
        self.Hovered = false
        self.HoverAnim = 0
    end
    self:UpdateLayout()
end

function ProfileCard:UpdateTheme(t)
    if not self.Enabled or not self.CardBg then return end
    local bgCol = ThemeModule.Resolve(t, self.Open and "Tab.ActiveBg" or "Tab.HoverBg")
    local borderCol = ThemeModule.Resolve(t, "Card.Border")
    local ctrlCol = ThemeModule.Resolve(t, "Control.Background")
    local titleCol = ThemeModule.Resolve(t, "Text.Title")
    local mutedCol = ThemeModule.Resolve(t, "Text.Muted")
    local accentCol = ThemeModule.Resolve(t, "Accent.Blue")

    self.CardBg.Color = bgCol
    self.AvatarBg.Color = ctrlCol
    self.AvatarInitial.Color = titleCol
    self.NameText.Color = titleCol
    self.HandleText.Color = mutedCol

    self.PopBg.Color = ThemeModule.Resolve(t, "Card.Background")
    self.PopBorder.Color = borderCol
    self.PopName.Color = titleCol
    self.PopHandle.Color = mutedCol
    self.PopDivider.Color = ThemeModule.Resolve(t, "Sidebar.Divider")

    local tagCfg = self:_getTagConfig()
    self.PopTagBg.Color = (tagCfg and tagCfg.Color) or accentCol
    self.PopTagText.Color = (tagCfg and tagCfg.TextColor) or Color3.fromRGB(255, 255, 255)

    for _, r in ipairs(self.PopRows) do
        r.LabelDraw.Color = mutedCol
        r.ValueDraw.Color = titleCol
    end
end

function ProfileCard:Update(mx, my, m1Clicked, dt)
    if not self.Enabled or not self.CardBg then return false end
    local vis = (self.Sidebar and self.Sidebar.Visible == true) and (self.Window and self.Window.Visible == true) and (not self.Window.Minimized)
    if not vis then return false end

    self.FpsFrames = self.FpsFrames + 1
    self.FpsAccum = self.FpsAccum + (dt or 0.016)

    local elapsed = math.floor(os.clock() - self.StartClock)
    if elapsed ~= self.LastTickSec then
        self.LastTickSec = elapsed
        self.CurrentFPS = math.max(1, math.floor(self.FpsFrames / math.max(0.001, self.FpsAccum) + 0.5))
        self.FpsFrames = 0
        self.FpsAccum = 0

        local px, _, pw = self:GetPopoverRect()
        for _, r in ipairs(self.PopRows) do
            local nextVal
            if r.Key == "uptime" then
                nextVal = format_uptime(elapsed)
            elseif r.Key == "fps" then
                nextVal = tostring(self.CurrentFPS)
            elseif r.Key == "date" then
                nextVal = os.date("%d/%m/%Y")
            elseif r.Key == "time" then
                nextVal = os.date("%H:%M:%S")
            end
            if nextVal then
                r.Value = nextVal
                if self.Open and r.ValueDraw then
                    r.ValueDraw.Text = nextVal
                    r.ValueDraw.Position = Vector2.new(MetricsModule.AlignRight(px, pw, nextVal, 11, 10), r.ValueDraw.Position.Y)
                end
            end
        end
    end

    local themeTokens = (self.Window and self.Window.ThemeTokens) or ThemeModule.GetCurrent()
    local cx, cy, cw, ch = self:GetCardRect()
    local overCard = mx >= cx and mx <= cx + cw and my >= cy and my <= cy + ch
    if overCard ~= self.Hovered then
        self.Hovered = overCard
        self:UpdateTheme(themeTokens)
        AnimationsModule.Tween("profile_hover_" .. tostring(self), self.HoverAnim, overCard and 1 or 0, 22, function(v)
            self.HoverAnim = v
            self:UpdateLayout()
        end)
    end

    if m1Clicked then
        if overCard then
            self:_animatePopover(not self.Open)
            self:UpdateTheme(themeTokens)
            if self.Callback then
                task.spawn(self.Callback)
            end
            return true
        elseif self.Open then
            local px, py, pw, ph = self:GetPopoverRect()
            local overPop = mx >= px and mx <= px + pw and my >= py and my <= py + ph
            if overPop then
                return true
            end
            self:_animatePopover(false)
            self:UpdateTheme(themeTokens)
        end
    end
    return false
end

return ProfileCard
