---------------------------
-- Pywal awesome theme --
---------------------------

local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local theme_assets = beautiful.theme_assets
local xresources = beautiful.xresources
local dpi = xresources.apply_dpi

local gears = require("gears")
local themes_path = gears.filesystem.get_themes_dir()

local widgets = require("widgets")
local title_bars = require("title_bars")
local theme = {}

-- Pywal color variables
local pywal_cache_dir = os.getenv("HOME") .. "/.cache/wal"

-- Function to read pywal colors
local function read_pywal_colors()
    local colors_file = pywal_cache_dir .. "/colors"
    local file = io.open(colors_file, "r")

    if not file then
        -- Fallback colors if pywal isn't set up
        return {
            background = "#222222",
            foreground = "#aaaaaa",
            color0 = "#222222",
            color1 = "#ff0000",
            color2 = "#00ff00",
            color3 = "#ffff00",
            color4 = "#0000ff",
            color5 = "#ff00ff",
            color6 = "#00ffff",
            color7 = "#aaaaaa",
            color8 = "#444444",
            color9 = "#ff4444",
            color10 = "#44ff44",
            color11 = "#ffff44",
            color12 = "#4444ff",
            color13 = "#ff44ff",
            color14 = "#44ffff",
            color15 = "#ffffff"
        }
    end

    local colors = {}
    for i = 0, 15 do
        colors[i] = file:read("*l")
    end
    file:close()

    return colors
end

-- Initialize colors from pywal
local pywal_colors = read_pywal_colors()

-- Theme colors using pywal scheme
theme.bg_normal = pywal_colors[0]           -- color0 (background)
theme.bg_focus = pywal_colors[4]            -- color4 (usually blue)
theme.bg_urgent = pywal_colors[1]           -- color1 (usually red)
theme.bg_minimize = pywal_colors[8]         -- color8 (bright black)
theme.bg_systray = theme.bg_normal

theme.fg_normal = pywal_colors[7]            -- color7 (foreground)
theme.fg_focus = pywal_colors[15]            -- color15 (white)
theme.fg_urgent = pywal_colors[15]           -- color15 (white)
theme.fg_minimize = pywal_colors[15]         -- color15 (white)

theme.useless_gap = dpi(0)
theme.border_width = dpi(1)
theme.border_normal = pywal_colors[0]         -- color0
theme.border_focus = pywal_colors[4]          -- color4
theme.border_marked = pywal_colors[1]         -- color1

-- Generate taglist squares:
local taglist_square_size = dpi(4)
theme.taglist_squares_sel = theme_assets.taglist_squares_sel(taglist_square_size, theme.fg_normal)
theme.taglist_squares_unsel = theme_assets.taglist_squares_unsel(taglist_square_size, theme.fg_normal)

-- Taglist colors using pywal
theme.taglist_bg_focus = theme.bg_focus
theme.taglist_fg_focus = theme.fg_focus
theme.taglist_bg_occupied = pywal_colors[2]         -- color2 (usually green)
theme.taglist_fg_occupied = theme.fg_normal
theme.taglist_bg_empty = theme.bg_normal
theme.taglist_fg_empty = pywal_colors[8]         -- color8 (dim foreground)

-- Tasklist colors
theme.tasklist_bg_focus = theme.bg_focus
theme.tasklist_fg_focus = theme.fg_focus
theme.tasklist_bg_normal = theme.bg_normal
theme.tasklist_fg_normal = theme.fg_normal

-- Variables set for theming the menu:
theme.menu_submenu_icon = themes_path .. "default/submenu.png"
theme.menu_height = dpi(15)
theme.menu_width = dpi(100)
theme.menu_bg_normal = theme.bg_normal
theme.menu_fg_normal = theme.fg_normal
theme.menu_bg_focus = theme.bg_focus
theme.menu_fg_focus = theme.fg_focus

-- Titlebar colors using pywal
theme.titlebar_bg_normal = theme.bg_normal
theme.titlebar_fg_normal = theme.fg_normal
theme.titlebar_bg_focus = theme.bg_focus
theme.titlebar_fg_focus = theme.fg_focus

-- Define the image to load
theme.titlebar_close_button_normal = themes_path .. "default/titlebar/close_normal.png"
theme.titlebar_close_button_focus = themes_path .. "default/titlebar/close_focus.png"

theme.titlebar_minimize_button_normal = themes_path .. "default/titlebar/minimize_normal.png"
theme.titlebar_minimize_button_focus = themes_path .. "default/titlebar/minimize_focus.png"

theme.titlebar_ontop_button_normal_inactive = themes_path .. "default/titlebar/ontop_normal_inactive.png"
theme.titlebar_ontop_button_focus_inactive = themes_path .. "default/titlebar/ontop_focus_inactive.png"
theme.titlebar_ontop_button_normal_active = themes_path .. "default/titlebar/ontop_normal_active.png"
theme.titlebar_ontop_button_focus_active = themes_path .. "default/titlebar/ontop_focus_active.png"

theme.titlebar_sticky_button_normal_inactive = themes_path .. "default/titlebar/sticky_normal_inactive.png"
theme.titlebar_sticky_button_focus_inactive = themes_path .. "default/titlebar/sticky_focus_inactive.png"
theme.titlebar_sticky_button_normal_active = themes_path .. "default/titlebar/sticky_normal_active.png"
theme.titlebar_sticky_button_focus_active = themes_path .. "default/titlebar/sticky_focus_active.png"

theme.titlebar_floating_button_normal_inactive = themes_path .. "default/titlebar/floating_normal_inactive.png"
theme.titlebar_floating_button_focus_inactive = themes_path .. "default/titlebar/floating_focus_inactive.png"
theme.titlebar_floating_button_normal_active = themes_path .. "default/titlebar/floating_normal_active.png"
theme.titlebar_floating_button_focus_active = themes_path .. "default/titlebar/floating_focus_active.png"

theme.titlebar_maximized_button_normal_inactive = themes_path .. "default/titlebar/maximized_normal_inactive.png"
theme.titlebar_maximized_button_focus_inactive = themes_path .. "default/titlebar/maximized_focus_inactive.png"
theme.titlebar_maximized_button_normal_active = themes_path .. "default/titlebar/maximized_normal_active.png"
theme.titlebar_maximized_button_focus_active = themes_path .. "default/titlebar/maximized_focus_active.png"

-- Layout icons
theme.layout_fairh = themes_path .. "default/layouts/fairhw.png"
theme.layout_fairv = themes_path .. "default/layouts/fairvw.png"
theme.layout_floating = themes_path .. "default/layouts/floatingw.png"
theme.layout_magnifier = themes_path .. "default/layouts/magnifierw.png"
theme.layout_max = themes_path .. "default/layouts/maxw.png"
theme.layout_fullscreen = themes_path .. "default/layouts/fullscreenw.png"
theme.layout_tilebottom = themes_path .. "default/layouts/tilebottomw.png"
theme.layout_tileleft = themes_path .. "default/layouts/tileleftw.png"
theme.layout_tile = themes_path .. "default/layouts/tilew.png"
theme.layout_tiletop = themes_path .. "default/layouts/tiletopw.png"
theme.layout_spiral = themes_path .. "default/layouts/spiralw.png"
theme.layout_dwindle = themes_path .. "default/layouts/dwindlew.png"
theme.layout_cornernw = themes_path .. "default/layouts/cornernww.png"
theme.layout_cornerne = themes_path .. "default/layouts/cornernew.png"
theme.layout_cornersw = themes_path .. "default/layouts/cornersww.png"
theme.layout_cornerse = themes_path .. "default/layouts/cornersew.png"

-- Generate Awesome icon:
theme.awesome_icon = theme_assets.awesome_icon(theme.menu_height, theme.bg_focus, theme.fg_focus)

-- Define the icon theme for application icons. If not set then the icons
-- from /usr/share/icons and /usr/share/icons/hicolor will be used.
theme.icon_theme = nil

-- Function to update theme when pywal colors change
function theme.update_pywal_colors()
    local new_colors = read_pywal_colors()

    -- Update theme colors
    theme.bg_normal = new_colors[0]
    theme.bg_focus = new_colors[4]
    theme.bg_urgent = new_colors[1]
    theme.bg_minimize = new_colors[8]
    theme.bg_systray = theme.bg_normal

    theme.fg_normal = new_colors[7]
    theme.fg_focus = new_colors[15]
    theme.fg_urgent = new_colors[15]
    theme.fg_minimize = new_colors[15]

    theme.border_normal = new_colors[0]
    theme.border_focus = new_colors[4]
    theme.border_marked = new_colors[1]

    -- Update taglist colors
    theme.taglist_bg_focus = theme.bg_focus
    theme.taglist_fg_focus = theme.fg_focus
    theme.taglist_bg_occupied = new_colors[2]
    theme.taglist_fg_occupied = theme.fg_normal
    theme.taglist_bg_empty = theme.bg_normal
    theme.taglist_fg_empty = new_colors[8]

    -- Re-apply the theme
    beautiful.init(gears.filesystem.get_configuration_dir() .. "theme.lua")

    -- Update all clients' border colors
    for _, c in ipairs(client.get()) do
        if c.valid then
            if c == client.focus then
                c.border_color = theme.border_focus
            else
                c.border_color = theme.border_normal
            end
        end
    end

    widgets.recolor()
    title_bars.refresh_all()
end

return theme
