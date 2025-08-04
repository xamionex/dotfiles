local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action
local gpus = wezterm.gui.enumerate_gpus()

-- Utility to extract RGB triplet from kdeglobals
local function get_kde_rgb(section, key)
local cmd = string.format([[awk '/\[%s\]/ {f=1; next} /^\[/ {f=0} f && /^%s=/' ~/.config/kdeglobals]], section, key)
local pipe = io.popen(cmd)
if not pipe then return nil end
    local line = pipe:read("*a")
    pipe:close()
    local r, g, b = line:match("=(%d+),(%d+),(%d+)")
    if r and g and b then
        return string.format("#%02x%02x%02x", tonumber(r), tonumber(g), tonumber(b))
        end
        end

        -- Extract background and accent color from KDE config
        local bg_color     = get_kde_rgb("Colors:Window", "BackgroundNormal") or "#1e1e2e"
        local accent_color = get_kde_rgb("General", "AccentColor") or "#ff5555"

config.term = 'wezterm'

config.colors = {
    foreground = "white",
    background = bg_color,
    cursor_bg = "white",
    selection_bg = accent_color,
--     ansi = { bg_color, accent_color, "#50fa7b", "#f1fa8c", "#bd93f9", "#ff79c6", "#8be9fd", "#f8f8f2" },
--     brights = { "#6272a4", accent_color, "#69ff94", "#ffffa5", "#d6acff", "#ff92df", "#a4ffff", "#ffffff" },
}

-- Removes Window Padding
config.window_padding = {
    top = 0,
    bottom = 0,
    left = 0,
    right = 0,
}

config.initial_cols = 200                  -- width
config.initial_rows = 55                   -- height
config.window_background_opacity = 0.1      -- opacity
config.kde_window_background_blur = true    -- blur effect
--window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.warn_about_missing_glyphs = false

-- Tab bar configuration
config.enable_tab_bar = true
config.use_fancy_tab_bar = false            -- simpler tab style
config.hide_tab_bar_if_only_one_tab = true   -- hide when unnecessary
config.tab_max_width = 32                   -- limit tab width
config.tab_bar_at_bottom = false             -- are you a top or bottom?

--color_scheme = "Builtin Solarized Dark", -- fallback
config.font = wezterm.font("Hack Nerd Font")
config.enable_wayland = true
-- config.prefer_egl = true
-- config.front_end = "OpenGL"
-- config.webgpu_preferred_adapter = gpus[2]
config.inactive_pane_hsb = {
    saturation = 0.9,
    brightness = 0.7,
}
config.font_size = 10.0

-- Tab key bindings
config.keys = {
    -- Close tab (CTRL+SHIFT+W)
    { key = "w", mods = "CTRL|SHIFT", action = act.CloseCurrentTab{confirm=true} },

    -- New tab (CTRL+SHIFT+T)
    { key = "t", mods = "CTRL|SHIFT", action = act.SpawnTab("CurrentPaneDomain") },

    -- Tab navigation (ALT+AWDS)
    { key = "a", mods = "ALT|SHIFT", action = act.ActivateTabRelative(-1) },  -- Previous tab
    { key = "d", mods = "ALT|SHIFT", action = act.ActivateTabRelative(1) },   -- Next tab
    { key = "w", mods = "ALT|SHIFT", action = act.MoveTabRelative(-1) },      -- Move tab left
    { key = "s", mods = "ALT|SHIFT", action = act.MoveTabRelative(1) },       -- Move tab right
    { key = "a", mods = "ALT", action = act.ActivatePaneDirection 'Left' },  -- Previous tab
    { key = "d", mods = "ALT", action = act.ActivatePaneDirection 'Right' },   -- Next tab
    { key = "w", mods = "ALT", action = act.ActivatePaneDirection 'Up' },      -- Move tab left
    { key = "s", mods = "ALT", action = act.ActivatePaneDirection 'Down' },       -- Move tab right
    { key = 'q', mods = 'ALT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
    { key = 'e', mods = 'ALT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = 'j', mods = 'CTRL|SHIFT', action = act.ScrollByPage(1) },
    { key = 'k', mods = 'CTRL|SHIFT', action = act.ScrollByPage(-1) },
    { key = 'g', mods = 'CTRL|SHIFT', action = act.ScrollToTop },
    { key = 'e', mods = 'CTRL|SHIFT', action = act.ScrollToBottom },
    { key = 'p', mods = 'CTRL|SHIFT|SUPER', action = act.PaneSelect },
    { key = 'o', mods = 'CTRL|SHIFT|SUPER', action = act.PaneSelect { mode = "SwapWithActive" } },
    { key = 'LeftArrow', mods = 'CTRL|SHIFT|SUPER', action = act.AdjustPaneSize { 'Left', 1 } },
    { key = 'RightArrow', mods = 'CTRL|SHIFT|SUPER', action = act.AdjustPaneSize { 'Right', 1 } },
    { key = 'UpArrow', mods = 'CTRL|SHIFT|SUPER', action = act.AdjustPaneSize { 'Up', 1 } },
    { key = 'DownArrow', mods = 'CTRL|SHIFT|SUPER', action = act.AdjustPaneSize { 'Down', 1 } },
    { key = 'z', mods = 'CTRL|SHIFT|SUPER', action = act.TogglePaneZoomState },
    { key = 'b', mods = 'CTRL|SHIFT|SUPER', action = act.RotatePanes 'CounterClockwise' },
    { key = 'n', mods = 'CTRL|SHIFT|SUPER', action = act.RotatePanes 'Clockwise' },
    { key = 'd', mods = 'CTRL|SHIFT', action = act.ShowLauncher },
    { key = ':', mods = 'CTRL|SHIFT', action = act.ClearSelection },
    { key = 'Enter', mods = 'ALT', action = wezterm.action.DisableDefaultAssignment, },
}

--     Optional: Add tab colors matching Catppuccin
-- config.colors = {
--     tab_bar = {
--         active_tab = {
--             bg_color = "#1e1e2e",
--             fg_color = "#cdd6f4",
--         },
--         inactive_tab = {
--             bg_color = "#181825",
--             fg_color = "#6c7086",
--         },
--         inactive_tab_hover = {
--             bg_color = "#313244",
--             fg_color = "#cdd6f4",
--         },
--         new_tab = {
--             bg_color = "#181825",
--             fg_color = "#6c7086",
--         },
--         new_tab_hover = {
--             bg_color = "#313244",
--             fg_color = "#cdd6f4",
--         },
--     }
-- }
-- config.enable_scroll_bar = true
-- config.background = {
--     {
--         source = {
--             Color="#24273a"
--         },
--         height = "100%",
--         width = "100%",
--     },
--     {
--         source = {
--             File = '/home/petar/.config/wezterm/lain.gif',
--         },
--         opacity = 0.02,
--         vertical_align = "Middle",
--         horizontal_align = "Center",
--         height = "1824",
--         width = "2724",
--         repeat_y = "NoRepeat",
--         repeat_x = "NoRepeat",
--     },
-- }
-- config.launch_menu = {
--     {
--         args = { 'btop' },
--     },
--     {
--         args = { 'cmatrix' },
--     },
--     {
--         args = { 'pipes-rs' },
--     },
-- }

local prefer_webgpu = false

--Select WebGpu if Vulkan renderer is available (OpenGL is default)
for _, gpu in ipairs(wezterm.gui.enumerate_gpus()) do
    if prefer_webgpu and gpu.backend == "Vulkan" then
        config.webgpu_preferred_adapter = gpu
        config.front_end = "WebGpu"
        break
        end

        if gpu.backend == "Gl" then
            config.front_end = "OpenGL"
            end
            end

return config
