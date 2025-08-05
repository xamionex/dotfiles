local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action
local gpus = wezterm.gui.enumerate_gpus()

config.term = 'wezterm'

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

-- Extract KDE colors with fallbacks
local bg_color     = get_kde_rgb("Colors:Window", "BackgroundNormal") or "#1e1e2e"
local accent_color = get_kde_rgb("General", "AccentColor") or "#ff5555"

-- Simple function to lighten/darken hex color
local function adjust_brightness(hex, factor)
  local r, g, b = hex:match("#(..)(..)(..)")
  r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
  r = math.min(255, math.max(0, math.floor(r * factor)))
  g = math.min(255, math.max(0, math.floor(g * factor)))
  b = math.min(255, math.max(0, math.floor(b * factor)))
  return string.format("#%02x%02x%02x", r, g, b)
end

local inactive_bg = adjust_brightness(bg_color, 0.85)
local hover_bg    = adjust_brightness(bg_color, 1.1)
local fg_normal   = "#cdd6f4"
local fg_subtle   = "#a6adc8"

config.colors = {
  foreground = fg_normal,
  background = bg_color,
  cursor_bg = fg_normal,
  selection_bg = accent_color,

  tab_bar = {
    active_tab = {
      bg_color = accent_color,
      fg_color = "#ffffff", -- Ensure contrast
      intensity = "Bold",
    },
    inactive_tab = {
      bg_color = inactive_bg,
      fg_color = fg_subtle,
    },
    inactive_tab_hover = {
      bg_color = hover_bg,
      fg_color = fg_normal,
    },
    new_tab = {
      bg_color = inactive_bg,
      fg_color = fg_subtle,
    },
    new_tab_hover = {
      bg_color = hover_bg,
      fg_color = fg_normal,
    },
  },
}

-- Removes Window Padding
config.window_padding = {
    top = 0,
    bottom = 0,
    left = 0,
    right = 0,
}

config.initial_cols = 180                               -- Initial Width
config.initial_rows = 50                                -- Initial Height
config.window_background_opacity = 0.75                 -- Opacity of BG
config.kde_window_background_blur = true                -- Blur on KDE only, see wezterm wiki for others
--window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.warn_about_missing_glyphs = false                -- Don't send notifs when missing glyphs

-- Tab bar configuration
config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_max_width = 32                   -- limit tab width
config.tab_bar_at_bottom = false

config.font = wezterm.font("Hack Nerd Font")
config.enable_wayland = true
config.inactive_pane_hsb = {
    saturation = 0.6,
    brightness = 0.6,
}
config.font_size = 10.0

-- Import actions
local act = wezterm.action

config.disable_default_key_bindings = true
config.keys = {
    -- ▒░░ Tab Management ░░▒
    { key = "t", mods = "CTRL", action = act.SpawnTab("CurrentPaneDomain") },                -- New Tab
    { key = "q", mods = "CTRL|SHIFT", action = act.CloseCurrentTab { confirm = true } },     -- Close Tab (safer than closing pane), set to ctrl+shift because of micro doing the same key
    { key = "a", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },                -- Previous Tab
    { key = "d", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(1) },                 -- Next Tab
    { key = "w", mods = "CTRL|SHIFT", action = act.MoveTabRelative(-1) },                    -- Move Tab Left
    { key = "s", mods = "CTRL|SHIFT", action = act.MoveTabRelative(1) },                     -- Move Tab Right

    -- ▒░░ Pane Navigation ░░▒
    { key = "a", mods = "ALT", action = act.ActivatePaneDirection 'Left' },
    { key = "d", mods = "ALT", action = act.ActivatePaneDirection 'Right' },
    { key = "w", mods = "ALT", action = act.ActivatePaneDirection 'Up' },
    { key = "s", mods = "ALT", action = act.ActivatePaneDirection 'Down' },

    -- ▒░░ Pane Splitting ░░▒
    { key = "q", mods = "ALT", action = act.SplitVertical { domain = "CurrentPaneDomain" } },  -- Split Left/Right
    { key = "e", mods = "ALT", action = act.SplitHorizontal { domain = "CurrentPaneDomain" } },-- Split Up/Down

    -- ▒░░ Pane Management ░░▒
    { key = "z", mods = "CTRL|SHIFT|SUPER", action = act.TogglePaneZoomState },               -- Zoom Pane
    { key = "b", mods = "CTRL|SHIFT|SUPER", action = act.RotatePanes "CounterClockwise" },    -- Rotate Panes CCW
    { key = "n", mods = "CTRL|SHIFT|SUPER", action = act.RotatePanes "Clockwise" },           -- Rotate Panes CW

    -- ▒░░ Pane Selection ░░▒
    { key = "p", mods = "CTRL|SHIFT", action = act.PaneSelect },                              -- Interactive Pane Select
    { key = "o", mods = "CTRL|SHIFT", action = act.PaneSelect { mode = "SwapWithActive" } },  -- Swap Panes

    -- ▒░░ Pane Resizing ░░▒
    { key = "LeftArrow",  mods = "CTRL|SHIFT|SUPER", action = act.AdjustPaneSize { "Left", 1 } },
    { key = "RightArrow", mods = "CTRL|SHIFT|SUPER", action = act.AdjustPaneSize { "Right", 1 } },
    { key = "UpArrow",    mods = "CTRL|SHIFT|SUPER", action = act.AdjustPaneSize { "Up", 1 } },
    { key = "DownArrow",  mods = "CTRL|SHIFT|SUPER", action = act.AdjustPaneSize { "Down", 1 } },

    -- ▒░░ Scrolling ░░▒
    { key = "j", mods = "CTRL|SHIFT", action = act.ScrollByPage(1) },     -- Page Down
    { key = "k", mods = "CTRL|SHIFT", action = act.ScrollByPage(-1) },    -- Page Up
    { key = "g", mods = "CTRL|SHIFT", action = act.ScrollToTop },         -- Top
    { key = "e", mods = "CTRL|SHIFT", action = act.ScrollToBottom },      -- Bottom

    -- ▒░░ Misc ░░▒
    { key = "d", mods = "CTRL|SHIFT", action = act.ShowLauncher },        -- Command Palette
    { key = ":", mods = "CTRL|SHIFT", action = act.ClearSelection },      -- Clear Selection
    { key = "Enter", mods = "ALT", action = act.DisableDefaultAssignment } -- Prevent default Alt+Enter behavior
}

config.enable_scroll_bar = true
config.launch_menu = {
    {
        args = { 'btop' },
    },
    {
        args = { 'cmatrix' },
    },
    {
        args = { 'pipes-rs' },
    },
}

local prefer_webgpu = false
-- config.prefer_egl = true
-- config.front_end = "OpenGL"
-- config.webgpu_preferred_adapter = gpus[2]

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
