-- Library/BreezeUI/Components/Image.lua
-- WindUI Image display element supporting aspect ratios, rounded frame, and async PNG fetching.

local ThemeModule = Theme or require("../Layout/Theme")
local IconsModule = Icons or require("../Subsystems/Icons")

local ImageBlock = {}
ImageBlock.__index = ImageBlock

local function parse_aspect_height(aspect, width, fallbackH)
    if type(fallbackH) == "number" and fallbackH > 0 then
        return fallbackH
    end
    if type(aspect) == "string" then
        local a, b = aspect:match("(%d+)%s*:%s*(%d+)")
        local nA, nB = tonumber(a), tonumber(b)
        if nA and nB and nA > 0 and nB > 0 then
            return math.clamp(math.floor(width * (nB / nA) + 0.5), 60, 260)
        end
    end
    return 140
end

function ImageBlock.new(section, config)
    local cfg = config or {}
    local usableW = math.max(160, (section.Size and section.Size.X or 400) - ((section.Padding or 10) * 2))
    local rowH = parse_aspect_height(cfg.AspectRatio, usableW, cfg.Height)
    local pos, size = section:AllocateControlSlot(false, rowH)

    local self = setmetatable({
        Section = section,
        Source = cfg.Image or cfg.Url or "",
        AspectRatio = cfg.AspectRatio,
        FixedHeight = cfg.Height,
        Radius = cfg.Radius or 10,
        Position = pos,
        Size = size,
        Visible = section.Visible,
        _imgData = nil,
    }, ImageBlock)

    local pool = section.Pool
    if pool then
        local bg = pool:Get("Square")
        bg.Position = pos
        bg.Size = size
        bg.Color = ThemeModule.Get("ElementBackground")
        bg.Filled = true
        bg.Corner = self.Radius
        bg.ZIndex = 4
        bg.Visible = section.Visible
        self.Visual = bg
        section:_register(bg)

        local border = pool:Get("Square")
        border.Position = pos
        border.Size = size
        border.Color = ThemeModule.Get("Window.Border")
        border.Filled = false
        border.Thickness = 1
        border.Corner = self.Radius
        border.ZIndex = 6
        border.Visible = section.Visible
        self.Border = border
        section:_register(border)

        local img = pool:Get("Image")
        img.Position = pos
        img.Size = size
        img.Rounding = self.Radius
        img.Transparency = 1
        img.ZIndex = 5
        img.Visible = false
        self.ImgDrawing = img
        section:_register(img)

        self:SetImage(self.Source)
    end

    return self
end

function ImageBlock:SetImage(src)
    self.Source = tostring(src or "")
    if self.Source == "" or not self.ImgDrawing then return end

    local function apply_data(data)
        if not data or not self.ImgDrawing or (self.Section and self.Section.Destroyed) then return end
        self._imgData = data
        self.ImgDrawing.Data = data
        self.ImgDrawing.Visible = self.Visible
    end

    if self.Source:sub(1, 8) == "https://" or self.Source:sub(1, 7) == "http://" then
        if IconsModule.Cache[self.Source] then
            apply_data(IconsModule.Cache[self.Source])
            return
        end
        if task and task.spawn then
            task.spawn(function()
                local ok, data = pcall(function()
                    return game and game.HttpGet and game:HttpGet(self.Source) or nil
                end)
                if ok and data and (data:sub(1, 4) == "\x89PNG" or data:sub(2, 4) == "PNG") then
                    IconsModule.Cache[self.Source] = data
                    apply_data(data)
                end
            end)
        end
    else
        local got = IconsModule.Get(self.Source, apply_data)
        if got then apply_data(got) end
    end
end

function ImageBlock:RecalcHeight(width)
    local w = width or (self.Size and self.Size.X) or 380
    local h = parse_aspect_height(self.AspectRatio, w, self.FixedHeight)
    self.Size = Vector2.new(w, h)
    return h
end

function ImageBlock:SetPosition(pos, size)
    self.Position = pos
    self.Size = size or self.Size
    if self.Visual then
        self.Visual.Position = pos
        self.Visual.Size = self.Size
    end
    if self.Border then
        self.Border.Position = pos
        self.Border.Size = self.Size
    end
    if self.ImgDrawing then
        self.ImgDrawing.Position = pos
        self.ImgDrawing.Size = self.Size
    end
end

function ImageBlock:SetVisible(vis)
    self.Visible = vis
    if self.Visual then self.Visual.Visible = vis end
    if self.Border then self.Border.Visible = vis end
    if self.ImgDrawing then self.ImgDrawing.Visible = vis and (self._imgData ~= nil) end
end

return ImageBlock
