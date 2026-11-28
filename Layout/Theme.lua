-- Library/BreezeUI/Layout/Theme.lua
-- Tokenized design system palette, color converters, and theme registry for BreezeUI.

local theme = {}
theme.__index = theme

local registry = {}
local listeners = {}

local function build_theme(spec)
    local t = {}
    for k, v in pairs(spec) do t[k] = v end
    t["Sidebar.Background"] = t["Sidebar.Background"] or t["Window.Background"]
    t["Background"]         = t["Background"] or t["Window.Background"]
    t["Header"]             = t["Header"] or t["Window.Background"]
    t["Dialog"]             = t["Dialog"] or t["Card.Background"]
    t["Card"]               = t["Card"] or t["Card.Background"]
    t["Border"]             = t["Border"] or t["Window.Border"]
    t["Button"]             = t["Button"] or t["Control.Background"]
    t["Icon"]               = t["Icon"] or t["Text.Secondary"]
    t["Toggle"]             = t["Toggle"] or t["Accent.Green"]
    t["Slider"]             = t["Slider"] or t["Accent.Blue"]
    t["Checkbox"]           = t["Checkbox"] or t["Accent.Blue"]
    t["Primary"]            = t["Primary"] or t["Accent.Blue"]
    t["Accent"]             = t["Accent"] or t["Accent.Blue"]
    t["Text"]               = t["Text"] or t["Text.Title"]
    t["Placeholder"]        = t["Placeholder"] or t["Text.Muted"]
    t["SubText"]            = t["SubText"] or t["Text.Secondary"]
    t["TextSub"]            = t["TextSub"] or t["Text.Secondary"]
    t["Accent.Danger"]      = t["Accent.Danger"] or Color3.fromRGB(239, 68, 68)
    t["Slider.Thumb"]       = t["Slider.Thumb"] or Color3.fromRGB(255, 255, 255)
    t["Toggle.Thumb"]       = t["Toggle.Thumb"] or Color3.fromRGB(255, 255, 255)
    t["Button.Hover"]       = t["Button.Hover"] or t["Control.Hover"]
    t["Button.Background"]  = t["Button.Background"] or t["Control.Background"]
    t["Slider.Track"]       = t["Slider.Track"] or t["Slider.TrackBg"]
    return t
end

-- Canonical WindUI Dark Theme Tokens
local default_tokens = build_theme({
    -- Window Frame
    ["Window.Background"]  = Color3.fromRGB(16, 16, 16),   -- #101010 (WindUI Dark frame)
    ["Window.Border"]      = Color3.fromRGB(36, 36, 42),   -- #24242A (Subtle outline)

    -- Sidebar & Main Content Panel (WindUI Dark: neutral #101010 + soft white alpha blends)
    ["Sidebar.Divider"]    = Color3.fromRGB(30, 30, 32),   -- #1E1E20
    ["PanelBackground"]    = Color3.fromRGB(28, 28, 28),   -- #1C1C1C (5% white over #101010)
    ["ElementBackground"]  = Color3.fromRGB(42, 42, 44),   -- #2A2A2C (WindUI Dark ElementBackground)

    -- Content Card Containers
    ["Card.Background"]    = Color3.fromRGB(24, 24, 27),   -- #18181B
    ["Card.Border"]        = Color3.fromRGB(38, 38, 42),   -- #26262A

    -- Controls & Interactive Elements
    ["Control.Background"] = Color3.fromRGB(48, 48, 52),   -- #303034
    ["Control.Border"]     = Color3.fromRGB(58, 58, 64),   -- #3A3A40
    ["Control.Hover"]      = Color3.fromRGB(54, 54, 60),   -- #36363C
    ["Control.Active"]     = Color3.fromRGB(38, 38, 42),   -- #26262A

    -- Navigation Tabs (WindUI Dark: 7% active / 3% hover white over #101010)
    ["Tab.ActiveBg"]       = Color3.fromRGB(33, 33, 34),   -- #212122
    ["Tab.HoverBg"]        = Color3.fromRGB(23, 23, 24),   -- #171718

    -- Functional Accents
    ["Accent.Blue"]        = Color3.fromRGB(0, 145, 255),  -- #0091FF (WindUI Primary / Sliders)
    ["Accent.Green"]       = Color3.fromRGB(51, 199, 89),  -- #33C759 (WindUI Toggle ON)

    -- macOS Topbar Traffic Lights
    ["Mac.Close"]          = Color3.fromRGB(255, 95, 86),  -- #FF5F56
    ["Mac.Minimize"]       = Color3.fromRGB(255, 189, 46), -- #FFBD2E
    ["Mac.Maximize"]       = Color3.fromRGB(39, 201, 63),  -- #27C93F

    -- Slider Specific
    ["Slider.TrackBg"]     = Color3.fromRGB(54, 54, 62),   -- #36363E (WindUI unfilled track)

    -- Toggle Specific
    ["Toggle.TrackOff"]    = Color3.fromRGB(54, 54, 62),   -- #36363E

    -- Typography & Labels
    ["Text.Title"]         = Color3.fromRGB(255, 255, 255),
    ["Text.Secondary"]     = Color3.fromRGB(161, 161, 170),
    ["Text.Muted"]         = Color3.fromRGB(161, 161, 161),

    -- WindUI Flat Tokens & Direct Aliases
    ["Name"]               = "Dark",
    ["Dialog"]             = Color3.fromRGB(26, 26, 26),   -- #1A1A1A
    ["Button"]             = Color3.fromRGB(82, 82, 91),   -- #52525B
})

-- Built-in Theme Palettes (WindUI 1:1 Colors)
local midnight_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(10, 15, 30),   -- #0a0f1e
    ["Window.Border"]      = Color3.fromRGB(30, 58, 138),  -- #1e3a8a
    ["Sidebar.Divider"]    = Color3.fromRGB(18, 30, 62),
    ["PanelBackground"]    = Color3.fromRGB(16, 22, 42),
    ["ElementBackground"]  = Color3.fromRGB(36, 40, 54),   -- #242836
    ["Card.Background"]    = Color3.fromRGB(12, 30, 66),   -- #0c1e42
    ["Card.Border"]        = Color3.fromRGB(30, 58, 138),
    ["Control.Background"] = Color3.fromRGB(30, 48, 88),
    ["Control.Border"]     = Color3.fromRGB(47, 116, 209),
    ["Control.Hover"]      = Color3.fromRGB(38, 62, 112),
    ["Control.Active"]     = Color3.fromRGB(24, 38, 72),
    ["Tab.ActiveBg"]       = Color3.fromRGB(30, 58, 138),  -- #1e3a8a
    ["Tab.HoverBg"]        = Color3.fromRGB(20, 36, 82),
    ["Accent.Blue"]        = Color3.fromRGB(37, 99, 235),  -- #2563eb
    ["Accent.Green"]       = Color3.fromRGB(51, 199, 89),
    ["Slider.TrackBg"]     = Color3.fromRGB(30, 48, 88),
    ["Toggle.TrackOff"]    = Color3.fromRGB(45, 60, 90),
    ["Text.Title"]         = Color3.fromRGB(219, 234, 254),-- #dbeafe
    ["Text.Secondary"]     = Color3.fromRGB(85, 145, 244), -- #5591f4
    ["Text.Muted"]         = Color3.fromRGB(47, 116, 209), -- #2f74d1
    ["Name"]               = "Midnight",
    ["Header"]             = Color3.fromRGB(12, 30, 66),
    ["Button"]             = Color3.fromRGB(37, 99, 235),
})

local slate_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(15, 23, 42),
    ["Window.Border"]      = Color3.fromRGB(51, 65, 85),
    ["Sidebar.Divider"]    = Color3.fromRGB(30, 41, 59),
    ["PanelBackground"]    = Color3.fromRGB(22, 31, 52),
    ["ElementBackground"]  = Color3.fromRGB(38, 50, 72),
    ["Card.Background"]    = Color3.fromRGB(30, 41, 59),
    ["Card.Border"]        = Color3.fromRGB(51, 65, 85),
    ["Control.Background"] = Color3.fromRGB(51, 65, 85),
    ["Control.Border"]     = Color3.fromRGB(71, 85, 105),
    ["Control.Hover"]      = Color3.fromRGB(60, 75, 95),
    ["Control.Active"]     = Color3.fromRGB(40, 55, 75),
    ["Tab.ActiveBg"]       = Color3.fromRGB(65, 80, 100),
    ["Tab.HoverBg"]        = Color3.fromRGB(25, 35, 50),
    ["Accent.Blue"]        = Color3.fromRGB(20, 184, 166),
    ["Accent.Green"]       = Color3.fromRGB(34, 197, 94),
    ["Slider.TrackBg"]     = Color3.fromRGB(51, 65, 85),
    ["Toggle.TrackOff"]    = Color3.fromRGB(60, 75, 95),
    ["Text.Title"]         = Color3.fromRGB(241, 245, 249),
    ["Text.Secondary"]     = Color3.fromRGB(148, 163, 184),
    ["Text.Muted"]         = Color3.fromRGB(100, 116, 139),
    ["Name"]               = "Slate",
    ["Header"]             = Color3.fromRGB(30, 41, 59),
    ["Button"]             = Color3.fromRGB(20, 184, 166),
})

local amber_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(28, 16, 3),    -- #1c1003
    ["Window.Border"]      = Color3.fromRGB(107, 46, 5),   -- #6b2e05
    ["Sidebar.Divider"]    = Color3.fromRGB(69, 26, 3),
    ["PanelBackground"]    = Color3.fromRGB(40, 22, 8),
    ["ElementBackground"]  = Color3.fromRGB(58, 46, 34),   -- #3A2E22
    ["Card.Background"]    = Color3.fromRGB(69, 26, 3),    -- #451a03
    ["Card.Border"]        = Color3.fromRGB(107, 46, 5),
    ["Control.Background"] = Color3.fromRGB(78, 56, 38),
    ["Control.Border"]     = Color3.fromRGB(146, 64, 14),
    ["Control.Hover"]      = Color3.fromRGB(96, 68, 44),
    ["Control.Active"]     = Color3.fromRGB(62, 42, 26),
    ["Tab.ActiveBg"]       = Color3.fromRGB(180, 83, 9),   -- #b45309
    ["Tab.HoverBg"]        = Color3.fromRGB(74, 42, 16),
    ["Accent.Blue"]        = Color3.fromRGB(217, 119, 6),  -- #d97706
    ["Accent.Green"]       = Color3.fromRGB(245, 158, 11), -- #f59e0b
    ["Slider.TrackBg"]     = Color3.fromRGB(78, 56, 38),
    ["Toggle.TrackOff"]    = Color3.fromRGB(78, 56, 38),
    ["Text.Title"]         = Color3.fromRGB(255, 251, 235),-- #fffbeb
    ["Text.Secondary"]     = Color3.fromRGB(251, 191, 36), -- #fbbf24
    ["Text.Muted"]         = Color3.fromRGB(209, 163, 38), -- #d1a326
    ["Name"]               = "Amber",
    ["Header"]             = Color3.fromRGB(69, 26, 3),
    ["Button"]             = Color3.fromRGB(217, 119, 6),
    ["Icon"]               = Color3.fromRGB(245, 158, 11),
    ["Checkbox"]           = Color3.fromRGB(245, 158, 11),
})

local red_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(28, 6, 6),    -- #1c0606
    ["Window.Border"]      = Color3.fromRGB(153, 27, 27),  -- #991b1b
    ["Sidebar.Divider"]    = Color3.fromRGB(69, 10, 10),
    ["PanelBackground"]    = Color3.fromRGB(38, 14, 14),
    ["ElementBackground"]  = Color3.fromRGB(50, 34, 33),   -- #322221
    ["Card.Background"]    = Color3.fromRGB(69, 10, 10),   -- #450a0a
    ["Card.Border"]        = Color3.fromRGB(153, 27, 27),
    ["Control.Background"] = Color3.fromRGB(68, 28, 28),
    ["Control.Border"]     = Color3.fromRGB(153, 27, 27),
    ["Control.Hover"]      = Color3.fromRGB(88, 34, 34),
    ["Control.Active"]     = Color3.fromRGB(52, 20, 20),
    ["Tab.ActiveBg"]       = Color3.fromRGB(153, 27, 27),  -- #991b1b
    ["Tab.HoverBg"]        = Color3.fromRGB(69, 16, 16),
    ["Accent.Blue"]        = Color3.fromRGB(220, 38, 38),  -- #dc2626
    ["Accent.Green"]       = Color3.fromRGB(51, 199, 89),
    ["Slider.TrackBg"]     = Color3.fromRGB(68, 28, 28),
    ["Toggle.TrackOff"]    = Color3.fromRGB(78, 32, 32),
    ["Text.Title"]         = Color3.fromRGB(254, 242, 242),-- #fef2f2
    ["Text.Secondary"]     = Color3.fromRGB(239, 68, 68),  -- #ef4444
    ["Text.Muted"]         = Color3.fromRGB(217, 83, 83),  -- #d95353
    ["Name"]               = "Red",
    ["Header"]             = Color3.fromRGB(69, 10, 10),
    ["Button"]             = Color3.fromRGB(220, 38, 38),
    ["Accent"]             = Color3.fromRGB(153, 27, 27),
})

local ruby_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(10, 0, 0),
    ["Window.Border"]      = Color3.fromRGB(69, 10, 10),
    ["Sidebar.Divider"]    = Color3.fromRGB(26, 5, 5),
    ["PanelBackground"]    = Color3.fromRGB(20, 5, 5),
    ["ElementBackground"]  = Color3.fromRGB(40, 12, 12),
    ["Card.Background"]    = Color3.fromRGB(26, 5, 5),
    ["Card.Border"]        = Color3.fromRGB(69, 10, 10),
    ["Control.Background"] = Color3.fromRGB(62, 22, 22),
    ["Control.Border"]     = Color3.fromRGB(90, 30, 30),
    ["Control.Hover"]      = Color3.fromRGB(78, 28, 28),
    ["Control.Active"]     = Color3.fromRGB(30, 5, 5),
    ["Tab.ActiveBg"]       = Color3.fromRGB(60, 15, 15),
    ["Tab.HoverBg"]        = Color3.fromRGB(22, 5, 5),
    ["Accent.Blue"]        = Color3.fromRGB(239, 68, 68),
    ["Accent.Green"]       = Color3.fromRGB(34, 197, 94),
    ["Slider.TrackBg"]     = Color3.fromRGB(40, 10, 10),
    ["Toggle.TrackOff"]    = Color3.fromRGB(60, 15, 15),
    ["Text.Title"]         = Color3.fromRGB(254, 242, 242),
    ["Text.Secondary"]     = Color3.fromRGB(220, 120, 120),
    ["Text.Muted"]         = Color3.fromRGB(165, 70, 70),
    ["Name"]               = "Ruby",
    ["Header"]             = Color3.fromRGB(26, 5, 5),
    ["Button"]             = Color3.fromRGB(239, 68, 68),
    ["Icon"]               = Color3.fromRGB(239, 68, 68),
})

local light_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(228, 230, 235),
    ["Window.Border"]      = Color3.fromRGB(190, 194, 204),
    ["Sidebar.Divider"]    = Color3.fromRGB(205, 208, 216),
    ["PanelBackground"]    = Color3.fromRGB(216, 219, 226),
    ["ElementBackground"]  = Color3.fromRGB(240, 242, 246),
    ["Card.Background"]    = Color3.fromRGB(234, 236, 241),
    ["Card.Border"]        = Color3.fromRGB(196, 200, 210),
    ["Control.Background"] = Color3.fromRGB(210, 213, 222),
    ["Control.Border"]     = Color3.fromRGB(184, 188, 200),
    ["Control.Hover"]      = Color3.fromRGB(198, 202, 212),
    ["Control.Active"]     = Color3.fromRGB(186, 190, 202),
    ["Tab.ActiveBg"]       = Color3.fromRGB(206, 209, 218),
    ["Tab.HoverBg"]        = Color3.fromRGB(218, 220, 228),
    ["Accent.Blue"]        = Color3.fromRGB(0, 122, 255),
    ["Accent.Green"]       = Color3.fromRGB(52, 199, 89),
    ["Slider.TrackBg"]     = Color3.fromRGB(188, 192, 204),
    ["Toggle.TrackOff"]    = Color3.fromRGB(180, 185, 198),
    ["Text.Title"]         = Color3.fromRGB(18, 20, 24),
    ["Text.Secondary"]     = Color3.fromRGB(72, 76, 86),
    ["Text.Muted"]         = Color3.fromRGB(108, 112, 124),
    ["Name"]               = "Light",
    ["Button"]             = Color3.fromRGB(30, 32, 38),
})

local emerald_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(1, 20, 17),    -- #011411
    ["Window.Border"]      = Color3.fromRGB(15, 60, 48),
    ["Sidebar.Divider"]    = Color3.fromRGB(10, 40, 32),
    ["PanelBackground"]    = Color3.fromRGB(8, 30, 25),
    ["ElementBackground"]  = Color3.fromRGB(32, 46, 42),   -- #202E2A
    ["Card.Background"]    = Color3.fromRGB(2, 44, 34),    -- #022c22
    ["Card.Border"]        = Color3.fromRGB(15, 70, 55),
    ["Control.Background"] = Color3.fromRGB(46, 68, 60),
    ["Control.Border"]     = Color3.fromRGB(60, 90, 78),
    ["Control.Hover"]      = Color3.fromRGB(54, 80, 70),
    ["Control.Active"]     = Color3.fromRGB(25, 40, 35),
    ["Tab.ActiveBg"]       = Color3.fromRGB(4, 120, 87),   -- #047857
    ["Tab.HoverBg"]        = Color3.fromRGB(10, 50, 40),
    ["Accent.Blue"]        = Color3.fromRGB(16, 185, 129), -- #10b981
    ["Accent.Green"]       = Color3.fromRGB(5, 150, 105),  -- #059669
    ["Slider.TrackBg"]     = Color3.fromRGB(25, 55, 45),
    ["Toggle.TrackOff"]    = Color3.fromRGB(35, 65, 55),
    ["Text.Title"]         = Color3.fromRGB(236, 253, 245),-- #ecfdf5
    ["Text.Secondary"]     = Color3.fromRGB(16, 185, 129),
    ["Text.Muted"]         = Color3.fromRGB(63, 191, 143), -- #3fbf8f
    ["Name"]               = "Emerald",
    ["Header"]             = Color3.fromRGB(2, 44, 34),
    ["Button"]             = Color3.fromRGB(5, 150, 105),
    ["Accent"]             = Color3.fromRGB(4, 120, 87),
})

local plant_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(10, 27, 15),   -- #0a1b0f
    ["Window.Border"]      = Color3.fromRGB(25, 75, 40),
    ["Sidebar.Divider"]    = Color3.fromRGB(18, 50, 28),
    ["PanelBackground"]    = Color3.fromRGB(16, 36, 22),
    ["ElementBackground"]  = Color3.fromRGB(40, 52, 42),   -- #28342A
    ["Card.Background"]    = Color3.fromRGB(5, 46, 22),    -- #052e16
    ["Card.Border"]        = Color3.fromRGB(30, 90, 50),
    ["Control.Background"] = Color3.fromRGB(54, 76, 58),
    ["Control.Border"]     = Color3.fromRGB(70, 98, 74),
    ["Control.Hover"]      = Color3.fromRGB(64, 90, 68),
    ["Control.Active"]     = Color3.fromRGB(32, 45, 35),
    ["Tab.ActiveBg"]       = Color3.fromRGB(22, 101, 52),  -- #166534
    ["Tab.HoverBg"]        = Color3.fromRGB(15, 60, 32),
    ["Accent.Blue"]        = Color3.fromRGB(74, 222, 128), -- #4ade80
    ["Accent.Green"]       = Color3.fromRGB(22, 163, 74),  -- #16a34a
    ["Slider.TrackBg"]     = Color3.fromRGB(30, 65, 40),
    ["Toggle.TrackOff"]    = Color3.fromRGB(40, 75, 50),
    ["Text.Title"]         = Color3.fromRGB(240, 253, 244),-- #f0fdf4
    ["Text.Secondary"]     = Color3.fromRGB(130, 210, 160),
    ["Text.Muted"]         = Color3.fromRGB(79, 191, 122), -- #4fbf7a
    ["Name"]               = "Plant",
    ["Header"]             = Color3.fromRGB(5, 46, 22),
    ["Button"]             = Color3.fromRGB(22, 163, 74),
    ["Icon"]               = Color3.fromRGB(74, 222, 128),
    ["Accent"]             = Color3.fromRGB(22, 101, 52),
})

local rose_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(31, 3, 8),     -- #1f0308
    ["Window.Border"]      = Color3.fromRGB(85, 15, 35),
    ["Sidebar.Divider"]    = Color3.fromRGB(50, 8, 20),
    ["PanelBackground"]    = Color3.fromRGB(40, 10, 18),
    ["ElementBackground"]  = Color3.fromRGB(56, 30, 35),   -- #381E23
    ["Card.Background"]    = Color3.fromRGB(76, 5, 25),    -- #4c0519
    ["Card.Border"]        = Color3.fromRGB(110, 20, 50),
    ["Control.Background"] = Color3.fromRGB(76, 32, 42),
    ["Control.Border"]     = Color3.fromRGB(110, 40, 58),
    ["Control.Hover"]      = Color3.fromRGB(92, 38, 52),
    ["Control.Active"]     = Color3.fromRGB(56, 24, 34),
    ["Tab.ActiveBg"]       = Color3.fromRGB(190, 24, 93),  -- #be185d
    ["Tab.HoverBg"]        = Color3.fromRGB(65, 12, 30),
    ["Accent.Blue"]        = Color3.fromRGB(251, 113, 133),-- #fb7185
    ["Accent.Green"]       = Color3.fromRGB(51, 199, 89),
    ["Slider.TrackBg"]     = Color3.fromRGB(70, 20, 35),
    ["Toggle.TrackOff"]    = Color3.fromRGB(80, 25, 45),
    ["Text.Title"]         = Color3.fromRGB(253, 242, 248),-- #fdf2f8
    ["Text.Secondary"]     = Color3.fromRGB(251, 113, 133),
    ["Text.Muted"]         = Color3.fromRGB(214, 122, 166),-- #d67aa6
    ["Name"]               = "Rose",
    ["Header"]             = Color3.fromRGB(76, 5, 25),
    ["Button"]             = Color3.fromRGB(233, 95, 116), -- #e95f74
    ["Accent"]             = Color3.fromRGB(190, 24, 93),
})

local violet_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(30, 10, 62),   -- #1e0a3e
    ["Window.Border"]      = Color3.fromRGB(70, 35, 120),
    ["Sidebar.Divider"]    = Color3.fromRGB(45, 18, 85),
    ["PanelBackground"]    = Color3.fromRGB(38, 18, 72),
    ["ElementBackground"]  = Color3.fromRGB(52, 38, 80),   -- #342650
    ["Card.Background"]    = Color3.fromRGB(60, 19, 97),   -- #3c1361
    ["Card.Border"]        = Color3.fromRGB(85, 35, 140),
    ["Control.Background"] = Color3.fromRGB(64, 46, 98),
    ["Control.Border"]     = Color3.fromRGB(80, 55, 125),
    ["Control.Hover"]      = Color3.fromRGB(78, 56, 118),
    ["Control.Active"]     = Color3.fromRGB(46, 32, 74),
    ["Tab.ActiveBg"]       = Color3.fromRGB(109, 40, 217), -- #6d28d9
    ["Tab.HoverBg"]        = Color3.fromRGB(50, 20, 95),
    ["Accent.Blue"]        = Color3.fromRGB(139, 92, 246), -- #8b5cf6
    ["Accent.Green"]       = Color3.fromRGB(51, 199, 89),
    ["Slider.TrackBg"]     = Color3.fromRGB(55, 30, 90),
    ["Toggle.TrackOff"]    = Color3.fromRGB(65, 38, 105),
    ["Text.Title"]         = Color3.fromRGB(250, 245, 255),-- #faf5ff
    ["Text.Secondary"]     = Color3.fromRGB(175, 155, 225),
    ["Text.Muted"]         = Color3.fromRGB(143, 126, 224),-- #8f7ee0
    ["Name"]               = "Violet",
    ["Header"]             = Color3.fromRGB(60, 19, 97),
    ["Button"]             = Color3.fromRGB(124, 58, 237), -- #7c3aed
    ["Icon"]               = Color3.fromRGB(139, 92, 246),
    ["Accent"]             = Color3.fromRGB(109, 40, 217),
})

local sky_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(5, 26, 38),    -- #051a26
    ["Window.Border"]      = Color3.fromRGB(10, 77, 102),
    ["Sidebar.Divider"]    = Color3.fromRGB(8, 45, 60),
    ["PanelBackground"]    = Color3.fromRGB(13, 58, 71),   -- #0d3a47
    ["ElementBackground"]  = Color3.fromRGB(23, 46, 59),   -- #172E3B
    ["Card.Background"]    = Color3.fromRGB(10, 77, 102),  -- #0a4d66
    ["Card.Border"]        = Color3.fromRGB(20, 110, 140),
    ["Control.Background"] = Color3.fromRGB(35, 70, 90),
    ["Control.Border"]     = Color3.fromRGB(45, 90, 115),
    ["Control.Hover"]      = Color3.fromRGB(44, 84, 108),
    ["Control.Active"]     = Color3.fromRGB(18, 38, 48),
    ["Tab.ActiveBg"]       = Color3.fromRGB(0, 168, 204),  -- #00a8cc
    ["Tab.HoverBg"]        = Color3.fromRGB(10, 50, 65),
    ["Accent.Blue"]        = Color3.fromRGB(0, 212, 255),  -- #00d4ff
    ["Accent.Green"]       = Color3.fromRGB(0, 217, 217),  -- #00d9d9
    ["Slider.TrackBg"]     = Color3.fromRGB(20, 60, 80),
    ["Toggle.TrackOff"]    = Color3.fromRGB(25, 70, 90),
    ["Text.Title"]         = Color3.fromRGB(230, 247, 255),-- #e6f7ff
    ["Text.Secondary"]     = Color3.fromRGB(102, 179, 204),-- #66b3cc
    ["Text.Muted"]         = Color3.fromRGB(45, 184, 217), -- #2db8d9
    ["Name"]               = "Sky",
    ["Header"]             = Color3.fromRGB(10, 77, 102),
    ["Button"]             = Color3.fromRGB(0, 168, 204),
    ["Icon"]               = Color3.fromRGB(45, 184, 217),
    ["Placeholder"]        = Color3.fromRGB(102, 179, 204),
})

local indigo_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(15, 10, 46),   -- #0f0a2e
    ["Window.Border"]      = Color3.fromRGB(55, 48, 163),  -- #3730a3
    ["Sidebar.Divider"]    = Color3.fromRGB(30, 27, 75),
    ["PanelBackground"]    = Color3.fromRGB(22, 18, 58),
    ["ElementBackground"]  = Color3.fromRGB(40, 37, 67),   -- #282543
    ["Card.Background"]    = Color3.fromRGB(30, 27, 75),   -- #1e1b4b
    ["Card.Border"]        = Color3.fromRGB(67, 56, 140),
    ["Control.Background"] = Color3.fromRGB(49, 46, 95),
    ["Control.Border"]     = Color3.fromRGB(79, 70, 150),
    ["Control.Hover"]      = Color3.fromRGB(60, 56, 115),
    ["Control.Active"]     = Color3.fromRGB(40, 36, 80),
    ["Tab.ActiveBg"]       = Color3.fromRGB(55, 48, 163),  -- #3730a3
    ["Tab.HoverBg"]        = Color3.fromRGB(40, 36, 90),
    ["Accent.Blue"]        = Color3.fromRGB(79, 70, 229),  -- #4f46e5
    ["Accent.Green"]       = Color3.fromRGB(51, 199, 89),
    ["Slider.TrackBg"]     = Color3.fromRGB(49, 46, 95),
    ["Toggle.TrackOff"]    = Color3.fromRGB(55, 52, 105),
    ["Text.Title"]         = Color3.fromRGB(241, 245, 249),-- #f1f5f9
    ["Text.Secondary"]     = Color3.fromRGB(99, 102, 241), -- #6366f1
    ["Text.Muted"]         = Color3.fromRGB(112, 120, 217),-- #7078d9
    ["Name"]               = "Indigo",
    ["Header"]             = Color3.fromRGB(30, 27, 75),
    ["Button"]             = Color3.fromRGB(79, 70, 229),
    ["Accent"]             = Color3.fromRGB(55, 48, 163),
    ["SubText"]            = Color3.fromRGB(165, 180, 252),
    ["TextSub"]            = Color3.fromRGB(165, 180, 252),
})

local crimson_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(12, 4, 4),    -- #0c0404
    ["Window.Border"]      = Color3.fromRGB(127, 29, 29),
    ["Sidebar.Divider"]    = Color3.fromRGB(48, 12, 12),
    ["PanelBackground"]    = Color3.fromRGB(22, 14, 14),
    ["ElementBackground"]  = Color3.fromRGB(37, 31, 31),   -- #251F1F
    ["Card.Background"]    = Color3.fromRGB(69, 10, 10),   -- #450a0a
    ["Card.Border"]        = Color3.fromRGB(153, 27, 27),
    ["Control.Background"] = Color3.fromRGB(58, 28, 28),
    ["Control.Border"]     = Color3.fromRGB(153, 27, 27),
    ["Control.Hover"]      = Color3.fromRGB(78, 34, 34),
    ["Control.Active"]     = Color3.fromRGB(46, 20, 20),
    ["Tab.ActiveBg"]       = Color3.fromRGB(185, 28, 28),  -- #b91c1c
    ["Tab.HoverBg"]        = Color3.fromRGB(60, 20, 20),
    ["Accent.Blue"]        = Color3.fromRGB(220, 38, 38),  -- #dc2626
    ["Accent.Green"]       = Color3.fromRGB(51, 199, 89),
    ["Slider.TrackBg"]     = Color3.fromRGB(64, 24, 24),
    ["Toggle.TrackOff"]    = Color3.fromRGB(72, 28, 28),
    ["Text.Title"]         = Color3.fromRGB(254, 242, 242),-- #fef2f2
    ["Text.Secondary"]     = Color3.fromRGB(220, 160, 160),
    ["Text.Muted"]         = Color3.fromRGB(111, 117, 123),-- #6f757b
    ["Name"]               = "Crimson",
    ["Header"]             = Color3.fromRGB(69, 10, 10),
    ["Button"]             = Color3.fromRGB(153, 27, 27),  -- #991b1b
    ["Icon"]               = Color3.fromRGB(220, 38, 38),
    ["Accent"]             = Color3.fromRGB(185, 28, 28),
})

local monokai_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(25, 22, 34),   -- #191622
    ["Window.Border"]      = Color3.fromRGB(64, 62, 65),
    ["Sidebar.Divider"]    = Color3.fromRGB(40, 38, 48),
    ["PanelBackground"]    = Color3.fromRGB(34, 31, 43),
    ["ElementBackground"]  = Color3.fromRGB(50, 48, 57),   -- #323039
    ["Card.Background"]    = Color3.fromRGB(30, 30, 30),   -- #1e1e1e
    ["Card.Border"]        = Color3.fromRGB(72, 69, 74),
    ["Control.Background"] = Color3.fromRGB(62, 58, 72),
    ["Control.Border"]     = Color3.fromRGB(91, 89, 92),
    ["Control.Hover"]      = Color3.fromRGB(74, 70, 84),
    ["Control.Active"]     = Color3.fromRGB(48, 45, 56),
    ["Tab.ActiveBg"]       = Color3.fromRGB(74, 70, 84),
    ["Tab.HoverBg"]        = Color3.fromRGB(42, 39, 52),
    ["Accent.Blue"]        = Color3.fromRGB(171, 157, 242),-- #ab9df2
    ["Accent.Green"]       = Color3.fromRGB(169, 220, 118),-- #a9dc76
    ["Accent.Danger"]      = Color3.fromRGB(255, 97, 136),
    ["Slider.TrackBg"]     = Color3.fromRGB(68, 65, 76),
    ["Slider.Thumb"]       = Color3.fromRGB(252, 252, 250),
    ["Toggle.TrackOff"]    = Color3.fromRGB(68, 65, 76),
    ["Toggle.Thumb"]       = Color3.fromRGB(252, 252, 250),
    ["Text.Title"]         = Color3.fromRGB(252, 252, 250),-- #fcfcfa
    ["Text.Secondary"]     = Color3.fromRGB(193, 192, 192),
    ["Text.Muted"]         = Color3.fromRGB(175, 175, 175),-- #afafaf
    ["Name"]               = "Monokai Pro",
    ["Header"]             = Color3.fromRGB(30, 30, 30),
    ["Button"]             = Color3.fromRGB(171, 157, 242),
    ["Icon"]               = Color3.fromRGB(169, 220, 118),
    ["Accent"]             = Color3.fromRGB(252, 152, 103),-- #fc9867
})

local cotton_candy_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(26, 11, 46),   -- #1a0b2e
    ["Window.Border"]      = Color3.fromRGB(88, 56, 110),
    ["Sidebar.Divider"]    = Color3.fromRGB(52, 34, 68),
    ["PanelBackground"]    = Color3.fromRGB(36, 20, 56),
    ["ElementBackground"]  = Color3.fromRGB(49, 38, 67),   -- #312643
    ["Card.Background"]    = Color3.fromRGB(45, 27, 61),   -- #2d1b3d
    ["Card.Border"]        = Color3.fromRGB(108, 72, 135),
    ["Control.Background"] = Color3.fromRGB(60, 44, 80),
    ["Control.Border"]     = Color3.fromRGB(125, 86, 156),
    ["Control.Hover"]      = Color3.fromRGB(76, 56, 98),
    ["Control.Active"]     = Color3.fromRGB(48, 36, 66),
    ["Tab.ActiveBg"]       = Color3.fromRGB(236, 72, 153), -- #ec4899
    ["Tab.HoverBg"]        = Color3.fromRGB(58, 40, 76),
    ["Accent.Blue"]        = Color3.fromRGB(217, 70, 239), -- #d946ef
    ["Accent.Green"]       = Color3.fromRGB(6, 182, 212),  -- #06b6d4
    ["Accent.Danger"]      = Color3.fromRGB(244, 63, 94),
    ["Slider.TrackBg"]     = Color3.fromRGB(66, 48, 88),
    ["Toggle.TrackOff"]    = Color3.fromRGB(72, 54, 96),
    ["Text.Title"]         = Color3.fromRGB(253, 242, 248),-- #fdf2f8
    ["Text.Secondary"]     = Color3.fromRGB(6, 182, 212),
    ["Text.Muted"]         = Color3.fromRGB(138, 95, 211), -- #8a5fd3
    ["Name"]               = "Cotton Candy",
    ["Header"]             = Color3.fromRGB(45, 27, 61),
    ["Button"]             = Color3.fromRGB(217, 70, 239),
    ["Toggle"]             = Color3.fromRGB(51, 199, 89),
    ["Accent"]             = Color3.fromRGB(236, 72, 153),
    ["SubText"]            = Color3.fromRGB(245, 208, 254),
    ["TextSub"]            = Color3.fromRGB(245, 208, 254),
})

local mellowsi_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(28, 16, 2),    -- #1C1002 (WindUI Mellowsi PR #52)
    ["Window.Border"]      = Color3.fromRGB(107, 90, 69),  -- #6B5A45
    ["Sidebar.Divider"]    = Color3.fromRGB(52, 42, 30),   -- #342A1E
    ["PanelBackground"]    = Color3.fromRGB(36, 24, 15),   -- #24180F
    ["ElementBackground"]  = Color3.fromRGB(51, 41, 30),   -- #33291E
    ["Card.Background"]    = Color3.fromRGB(41, 28, 19),   -- #291C13
    ["Card.Border"]        = Color3.fromRGB(107, 90, 69),  -- #6B5A45
    ["Control.Background"] = Color3.fromRGB(70, 56, 41),   -- #463829
    ["Control.Border"]     = Color3.fromRGB(107, 90, 69),  -- #6B5A45
    ["Control.Hover"]      = Color3.fromRGB(68, 55, 40),
    ["Control.Active"]     = Color3.fromRGB(41, 28, 19),
    ["Tab.ActiveBg"]       = Color3.fromRGB(71, 57, 41),   -- #473929
    ["Tab.HoverBg"]        = Color3.fromRGB(58, 46, 32),   -- #3A2E20
    ["Accent.Blue"]        = Color3.fromRGB(201, 162, 77), -- #C9A24D
    ["Accent.Green"]       = Color3.fromRGB(169, 135, 63), -- #a9873f
    ["Slider.TrackBg"]     = Color3.fromRGB(62, 50, 36),
    ["Slider.Thumb"]       = Color3.fromRGB(245, 235, 221),
    ["Toggle.TrackOff"]    = Color3.fromRGB(62, 50, 36),
    ["Toggle.Thumb"]       = Color3.fromRGB(245, 235, 221),
    ["Text.Title"]         = Color3.fromRGB(245, 235, 221),-- #F5EBDD
    ["Text.Secondary"]     = Color3.fromRGB(201, 183, 156),-- #C9B79C
    ["Text.Muted"]         = Color3.fromRGB(156, 138, 115),-- #9C8A73
    ["Name"]               = "Mellowsi",
    ["Header"]             = Color3.fromRGB(41, 28, 19),
    ["Button"]             = Color3.fromRGB(52, 42, 30),
})

local rainbow_tokens = build_theme({
    ["Window.Background"]  = Color3.fromRGB(16, 16, 20),
    ["Window.Border"]      = Color3.fromRGB(58, 58, 72),
    ["Sidebar.Divider"]    = Color3.fromRGB(36, 36, 46),
    ["PanelBackground"]    = Color3.fromRGB(24, 24, 30),
    ["ElementBackground"]  = Color3.fromRGB(36, 36, 46),
    ["Card.Background"]    = Color3.fromRGB(28, 28, 36),
    ["Card.Border"]        = Color3.fromRGB(68, 68, 86),
    ["Control.Background"] = Color3.fromRGB(48, 48, 60),
    ["Control.Border"]     = Color3.fromRGB(82, 82, 102),
    ["Control.Hover"]      = Color3.fromRGB(62, 62, 78),
    ["Control.Active"]     = Color3.fromRGB(40, 40, 50),
    ["Tab.ActiveBg"]       = Color3.fromRGB(139, 92, 246),
    ["Tab.HoverBg"]        = Color3.fromRGB(40, 40, 52),
    ["Accent.Blue"]        = Color3.fromRGB(0, 128, 255),
    ["Accent.Green"]       = Color3.fromRGB(0, 255, 65),
    ["Accent.Danger"]      = Color3.fromRGB(244, 63, 94),
    ["Slider.TrackBg"]     = Color3.fromRGB(56, 56, 70),
    ["Toggle.TrackOff"]    = Color3.fromRGB(60, 60, 74),
    ["Text.Title"]         = Color3.fromRGB(255, 255, 255),
    ["Text.Secondary"]     = Color3.fromRGB(186, 190, 210),
    ["Text.Muted"]         = Color3.fromRGB(0, 255, 128),   -- #00ff80
    ["Name"]               = "Rainbow",
    ["Header"]             = Color3.fromRGB(28, 28, 36),
    ["Button"]             = Color3.fromRGB(0, 128, 255),
    ["Icon"]               = Color3.fromRGB(255, 255, 255),
    ["Accent"]             = Color3.fromRGB(0, 255, 65),
})

-- Register default palettes
registry["Dark"] = default_tokens
registry["Midnight"] = midnight_tokens
registry["Slate"] = slate_tokens
registry["Amber"] = amber_tokens
registry["Ruby"] = ruby_tokens
registry["Red"] = red_tokens
registry["Light"] = light_tokens
registry["Emerald"] = emerald_tokens
registry["Plant"] = plant_tokens
registry["Rose"] = rose_tokens
registry["Violet"] = violet_tokens
registry["Sky"] = sky_tokens
registry["Indigo"] = indigo_tokens
registry["Crimson"] = crimson_tokens
registry["MonokaiPro"] = monokai_tokens
registry["Monokai Pro"] = monokai_tokens
registry["CottonCandy"] = cotton_candy_tokens
registry["Cotton Candy"] = cotton_candy_tokens
registry["Mellowsi"] = mellowsi_tokens
registry["Rainbow"] = rainbow_tokens

theme.DefaultPalette = default_tokens
theme.CurrentPalette = default_tokens
theme.CurrentName = "Dark"

local rainbow_hue = 0

function theme.HSV(h, s, v)
    local hue = (tonumber(h) or 0) % 1
    local sat = math.clamp(tonumber(s) or 1, 0, 1)
    local val = math.clamp(tonumber(v) or 1, 0, 1)
    local scaled = hue * 6
    local i = math.floor(scaled)
    local f = scaled - i
    local p = val * (1 - sat)
    local q = val * (1 - f * sat)
    local t = val * (1 - (1 - f) * sat)
    local r, g, b
    if i == 0 then r, g, b = val, t, p
    elseif i == 1 then r, g, b = q, val, p
    elseif i == 2 then r, g, b = p, val, t
    elseif i == 3 then r, g, b = p, q, val
    elseif i == 4 then r, g, b = t, p, val
    else r, g, b = val, p, q end
    return Color3.fromRGB(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

function theme.StepRainbow(dt, speed)
    rainbow_hue = (rainbow_hue + (tonumber(dt) or 0.016) * (tonumber(speed) or 0.18)) % 1
    local primary = theme.HSV(rainbow_hue, 0.85, 1)
    local secondary = theme.HSV((rainbow_hue + 0.12) % 1, 0.85, 0.96)
    local tabBg = theme.HSV(rainbow_hue, 0.55, 0.36)
    local border = theme.HSV(rainbow_hue, 0.45, 0.38)
    local muted = theme.HSV((rainbow_hue + 0.25) % 1, 0.65, 0.88)

    rainbow_tokens["Accent.Blue"] = primary
    rainbow_tokens["Slider"] = primary
    rainbow_tokens["Checkbox"] = primary
    rainbow_tokens["Primary"] = primary
    rainbow_tokens["Button"] = primary
    rainbow_tokens["Accent"] = primary
    rainbow_tokens["Accent.Green"] = secondary
    rainbow_tokens["Toggle"] = secondary
    rainbow_tokens["Tab.ActiveBg"] = tabBg
    rainbow_tokens["Window.Border"] = border
    rainbow_tokens["Text.Muted"] = muted
    return rainbow_tokens
end

-- Color Helpers
function theme.RGB(r, g, b)
    return Color3.fromRGB(
        math.clamp(math.floor((r or 0) + 0.5), 0, 255),
        math.clamp(math.floor((g or 0) + 0.5), 0, 255),
        math.clamp(math.floor((b or 0) + 0.5), 0, 255)
    )
end

function theme.FromHex(hex)
    local str = tostring(hex or ""):gsub("#", "")
    if #str == 3 then
        local r = tonumber(str:sub(1, 1):rep(2), 16) or 255
        local g = tonumber(str:sub(2, 2):rep(2), 16) or 255
        local b = tonumber(str:sub(3, 3):rep(2), 16) or 255
        return Color3.fromRGB(r, g, b)
    elseif #str == 6 then
        local r = tonumber(str:sub(1, 2), 16) or 255
        local g = tonumber(str:sub(3, 4), 16) or 255
        local b = tonumber(str:sub(5, 6), 16) or 255
        return Color3.fromRGB(r, g, b)
    end
    assert(false, "Invalid hex color format: " .. tostring(hex) .. "!")
end

function theme.ToHex(col)
    local r = math.clamp(math.floor(col.R * 255 + 0.5), 0, 255)
    local g = math.clamp(math.floor(col.G * 255 + 0.5), 0, 255)
    local b = math.clamp(math.floor(col.B * 255 + 0.5), 0, 255)
    return string.format("#%02x%02x%02x", r, g, b)
end

function theme.Lerp(a, b, t)
    local alpha = math.clamp(t or 0, 0, 1)
    return Color3.new(
        a.R + (b.R - a.R) * alpha,
        a.G + (b.G - a.G) * alpha,
        a.B + (b.B - a.B) * alpha
    )
end

-- Token Resolution with Fail-Fast Assertion
function theme.Get(tokenPath, fallback)
    local cur = theme.CurrentPalette
    local val = cur[tokenPath]
    if val ~= nil then return val end

    -- Nested notation support (e.g. "Window.Background")
    if type(tokenPath) == "string" and tokenPath:find("%.") then
        local parts = tokenPath:split(".")
        local node = cur
        for i = 1, #parts do
            if type(node) ~= "table" then
                node = nil
                break
            end
            node = node[parts[i]]
        end
        if node ~= nil then return node end
    end

    -- Fallback to default Dark palette if current palette omitted token
    if cur ~= theme.DefaultPalette then
        local defVal = theme.DefaultPalette[tokenPath]
        if defVal ~= nil then return defVal end
        if type(tokenPath) == "string" and tokenPath:find("%.") then
            local parts = tokenPath:split(".")
            local node = theme.DefaultPalette
            for i = 1, #parts do
                if type(node) ~= "table" then
                    node = nil
                    break
                end
                node = node[parts[i]]
            end
            if node ~= nil then return node end
        end
    end

    if fallback ~= nil then return fallback end
    assert(false, "Unknown theme token: " .. tostring(tokenPath) .. "!")
end

function theme.Resolve(palette, token)
    if palette then
        local val = palette[token]
        if val ~= nil then return val end
    end
    return theme.Get(token)
end

-- Theme Registry & Switching
function theme.Register(name, palette)
    assert(type(name) == "string", "Theme name must be a string!")
    assert(type(palette) == "table", "Theme palette must be a table!")
    registry[name] = palette
    return palette
end

function theme.SetCurrent(nameOrPalette)
    local target
    local name = "Custom"
    if type(nameOrPalette) == "string" then
        target = registry[nameOrPalette]
        assert(target ~= nil, "Theme not registered: " .. tostring(nameOrPalette) .. "!")
        name = nameOrPalette
    elseif type(nameOrPalette) == "table" then
        target = nameOrPalette
        name = nameOrPalette.Name or "Custom"
    else
        assert(false, "Invalid theme argument!")
    end

    theme.CurrentPalette = target
    theme.CurrentName = name

    for callback in pairs(listeners) do
        pcall(callback, target)
    end
    return target
end

function theme.GetCurrent()
    return theme.CurrentPalette
end

function theme.GetTheme(name)
    return registry[name] or theme.DefaultPalette
end

function theme.Subscribe(callback)
    assert(type(callback) == "function", "Callback must be a function!")
    listeners[callback] = true
    return function()
        listeners[callback] = nil
    end
end

-- Metatable delegation for direct index access (e.g. theme.Card, theme.Border)
setmetatable(theme, {
    __index = function(_, k)
        local val = theme.CurrentPalette[k]
        if val ~= nil then return val end
        return theme.DefaultPalette[k]
    end
})

return theme
