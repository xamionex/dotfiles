local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action
local gpus = wezterm.gui.enumerate_gpus()

config.term = 'wezterm'

-- Utility to extract RGB triplet (decimal or hex) from kdeglobals
local function get_kde_rgb(section, key)
  local cmd = string.format(
    [[awk '/\[%s\]/ {f=1; next} /^\[/ {f=0} f && /^%s=/' ~/.config/kdeglobals]],
    section, key
  )
  local pipe = io.popen(cmd)
  if not pipe then return nil end
  local line = pipe:read("*a"):gsub("%s+", "") -- remove whitespace
  pipe:close()

  -- Match decimal triplet: R,G,B
  local r, g, b = line:match("=(%d+),(%d+),(%d+)")
  if r and g and b then
    return string.format("#%02x%02x%02x", tonumber(r), tonumber(g), tonumber(b))
  end

  -- Match hex: #RRGGBB or RRGGBB
  local hex = line:match("=#+(%x%x%x%x%x%x)") or line:match("=(%x%x%x%x%x%x)")
  if hex then
    return "#" .. hex:lower()
  end

  return nil
end

-- Utility to extract color from ~/.config/wezterm/theme (check example file to make your own)
local function get_wezterm_theme_color(section, key)
  local theme_file = os.getenv("HOME") .. "/.config/wezterm/theme"
  local file = io.open(theme_file, "r")
  if not file then return nil end

  local current_section
  for line in file:lines() do
    local s = line:match("^%s*%[(.-)%]%s*$")
    if s then
      current_section = s
    else
      local k, v = line:match("^%s*([%w_]+)%s*=%s*(%S+)%s*$")
      if k and v and current_section == section and k == key then
        file:close()
        return v
      end
    end
  end

  file:close()
  return nil
end

-- Simple function to lighten/darken hex color
local function adjust_brightness(hex, factor)
  local r, g, b = hex:match("#(..)(..)(..)")
  r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
  r = math.min(255, math.max(0, math.floor(r * factor)))
  g = math.min(255, math.max(0, math.floor(g * factor)))
  b = math.min(255, math.max(0, math.floor(b * factor)))
  return string.format("#%02x%02x%02x", r, g, b)
end

-- General fallback resolver
local function resolve_color(section, key, static_fallback)
  return get_kde_rgb(section, key)
      or get_wezterm_theme_color(section, key)
      or static_fallback
end

-- Extract colors with layered fallbacks
local fg_normal    = resolve_color("Colors:Window", "ForegroundNormal",   "#cdd6f4")
local fg_subtle    = resolve_color("Colors:Window", "ForegroundInactive", "#a6adc8")
local bg_color     = resolve_color("Colors:Window", "BackgroundNormal",   "#000000")
local accent_color = resolve_color("General",       "AccentColor",        "#AAAAAA")

-- Derived colors
local inactive_bg = adjust_brightness(bg_color, 0.85)
local hover_bg    = adjust_brightness(bg_color, 1.1)

config.colors = {
  foreground = fg_normal,
  background = bg_color,
  cursor_bg = fg_normal,
  selection_bg = accent_color,

  tab_bar = {
    active_tab = {
      bg_color = bg_color,
      fg_color = fg_normal,
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
config.hide_tab_bar_if_only_one_tab = false
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
    -- Tab Management
    { key = "t", mods = "ALT", action = act.SpawnTab("CurrentPaneDomain") },                 -- New Tab
    { key = "q", mods = "ALT", action = act.CloseCurrentPane { confirm = false } },          -- Close Pane, not ctrl+q because micro uses ctrl+q
    { key = "a", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },                -- Previous Tab
    { key = "d", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(1) },                 -- Next Tab
    { key = "w", mods = "CTRL|SHIFT", action = act.MoveTabRelative(-1) },                    -- Move Tab Left
    { key = "s", mods = "CTRL|SHIFT", action = act.MoveTabRelative(1) },                     -- Move Tab Right

    -- Pane Navigation
    { key = "a", mods = "ALT", action = act.ActivatePaneDirection 'Left' },
    { key = "d", mods = "ALT", action = act.ActivatePaneDirection 'Right' },
    { key = "w", mods = "ALT", action = act.ActivatePaneDirection 'Up' },
    { key = "s", mods = "ALT", action = act.ActivatePaneDirection 'Down' },

    -- Pane Splitting
    { key = "r", mods = "CTRL|SHIFT", action = act.SplitVertical { domain = "CurrentPaneDomain" } },  -- Split Left/Right
    { key = "f", mods = "CTRL|SHIFT", action = act.SplitHorizontal { domain = "CurrentPaneDomain" } },-- Split Up/Down

    -- Pane Management
    { key = "z", mods = "CTRL|SHIFT|SUPER", action = act.TogglePaneZoomState },               -- Zoom Pane
    { key = "b", mods = "CTRL|SHIFT|SUPER", action = act.RotatePanes "CounterClockwise" },    -- Rotate Panes CCW
    { key = "n", mods = "CTRL|SHIFT|SUPER", action = act.RotatePanes "Clockwise" },           -- Rotate Panes CW

    -- Pane Selection
    { key = "p", mods = "CTRL|SHIFT", action = act.PaneSelect },                              -- Interactive Pane Select
    { key = "o", mods = "CTRL|SHIFT", action = act.PaneSelect { mode = "SwapWithActive" } },  -- Swap Panes

    -- Pane Resizing
    { key = "a", mods = "SHIFT|ALT", action = act.AdjustPaneSize { "Left", 1 } },
    { key = "d", mods = "SHIFT|ALT", action = act.AdjustPaneSize { "Right", 1 } },
    { key = "w", mods = "SHIFT|ALT", action = act.AdjustPaneSize { "Up", 1 } },
    { key = "s", mods = "SHIFT|ALT", action = act.AdjustPaneSize { "Down", 1 } },

    -- Scrolling
    { key = "j", mods = "CTRL|SHIFT", action = act.ScrollByPage(1) },     -- Page Down
    { key = "k", mods = "CTRL|SHIFT", action = act.ScrollByPage(-1) },    -- Page Up
    { key = "g", mods = "CTRL|SHIFT", action = act.ScrollToTop },         -- Top
    { key = "e", mods = "CTRL|SHIFT", action = act.ScrollToBottom },      -- Bottom

    -- Misc
    { key = "d", mods = "CTRL|SHIFT", action = act.ShowLauncher },        -- Command Palette
    { key = ":", mods = "CTRL|SHIFT", action = act.ClearSelection },      -- Clear Selection

    -- Clipboard copy/paste
    { key = "c", mods = "SUPER", action = act.CopyTo "Clipboard" },
    { key = "v", mods = "SUPER", action = act.PasteFrom "Clipboard" },
    { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo "Clipboard" },
    { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom "Clipboard" },
    { key = "Insert", mods = "CTRL", action = act.CopyTo "PrimarySelection" },
    { key = "Insert", mods = "SHIFT", action = act.PasteFrom "PrimarySelection" },

    -- Window management
    { key = "m", mods = "SUPER", action = act.Hide },
    { key = "h", mods = "SUPER", action = act.HideApplication }, -- macOS only
    { key = "n", mods = "SUPER", action = act.SpawnWindow },
    { key = "n", mods = "CTRL|SHIFT", action = act.SpawnWindow },
    --{ key = "Enter", mods = "ALT", action = act.ToggleFullScreen },

    -- Font size
    { key = "-", mods = "SUPER", action = act.DecreaseFontSize },
    { key = "-", mods = "CTRL", action = act.DecreaseFontSize },
    { key = "=", mods = "SUPER", action = act.IncreaseFontSize },
    { key = "=", mods = "CTRL", action = act.IncreaseFontSize },
    { key = "0", mods = "SUPER", action = act.ResetFontSize },
    { key = "0", mods = "CTRL", action = act.ResetFontSize },

    -- Tabs
    { key = "t", mods = "SUPER", action = act.SpawnTab "CurrentPaneDomain" },
    { key = "t", mods = "CTRL|SHIFT", action = act.SpawnTab "CurrentPaneDomain" },
    { key = "T", mods = "SUPER|SHIFT", action = act.SpawnTab "DefaultDomain" },
    { key = "w", mods = "SUPER", action = act.CloseCurrentTab { confirm = false } },
    { key = "w", mods = "CTRL|SHIFT", action = act.CloseCurrentTab { confirm = false } },

    -- Activate tab
    { key = "1", mods = "SUPER", action = act.ActivateTab(0) },
    { key = "2", mods = "SUPER", action = act.ActivateTab(1) },
    { key = "3", mods = "SUPER", action = act.ActivateTab(2) },
    { key = "4", mods = "SUPER", action = act.ActivateTab(3) },
    { key = "5", mods = "SUPER", action = act.ActivateTab(4) },
    { key = "6", mods = "SUPER", action = act.ActivateTab(5) },
    { key = "7", mods = "SUPER", action = act.ActivateTab(6) },
    { key = "8", mods = "SUPER", action = act.ActivateTab(7) },
    { key = "9", mods = "SUPER", action = act.ActivateTab(-1) },
    { key = "1", mods = "CTRL|SHIFT", action = act.ActivateTab(0) },
    { key = "2", mods = "CTRL|SHIFT", action = act.ActivateTab(1) },
    { key = "3", mods = "CTRL|SHIFT", action = act.ActivateTab(2) },
    { key = "4", mods = "CTRL|SHIFT", action = act.ActivateTab(3) },
    { key = "5", mods = "CTRL|SHIFT", action = act.ActivateTab(4) },
    { key = "6", mods = "CTRL|SHIFT", action = act.ActivateTab(5) },
    { key = "7", mods = "CTRL|SHIFT", action = act.ActivateTab(6) },
    { key = "8", mods = "CTRL|SHIFT", action = act.ActivateTab(7) },
    { key = "9", mods = "CTRL|SHIFT", action = act.ActivateTab(-1) },

    -- Navigate tabs
    { key = "[", mods = "SUPER|SHIFT", action = act.ActivateTabRelative(-1) },
    { key = "]", mods = "SUPER|SHIFT", action = act.ActivateTabRelative(1) },
    { key = "Tab", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
    { key = "Tab", mods = "CTRL", action = act.ActivateTabRelative(1) },
    { key = "PageUp", mods = "CTRL", action = act.ActivateTabRelative(-1) },
    { key = "PageDown", mods = "CTRL", action = act.ActivateTabRelative(1) },

    -- Move tabs
    { key = "PageUp", mods = "CTRL|SHIFT", action = act.MoveTabRelative(-1) },
    { key = "PageDown", mods = "CTRL|SHIFT", action = act.MoveTabRelative(1) },

    -- Scroll
    { key = "PageUp", mods = "SHIFT", action = act.ScrollByPage(-1) },
    { key = "PageDown", mods = "SHIFT", action = act.ScrollByPage(1) },

    -- Misc
    { key = "r", mods = "SUPER", action = act.ReloadConfiguration },
    --{ key = "R", mods = "CTRL|SHIFT", action = act.ReloadConfiguration },
    { key = "k", mods = "SUPER", action = act.ClearScrollback "ScrollbackOnly" },
    { key = "K", mods = "CTRL|SHIFT", action = act.ClearScrollback "ScrollbackOnly" },
    { key = "L", mods = "CTRL|SHIFT", action = act.ShowDebugOverlay },
    { key = "P", mods = "CTRL|SHIFT", action = act.ActivateCommandPalette },
    { key = "U", mods = "CTRL|SHIFT", action = act.CharSelect },
    { key = "f", mods = "SUPER", action = act.Search { CaseSensitiveString = "" } },
    --{ key = "F", mods = "CTRL|SHIFT", action = act.Search { CaseSensitiveString = "" } },
    { key = "X", mods = "CTRL|SHIFT", action = act.ActivateCopyMode },
    { key = "Space", mods = "CTRL|SHIFT", action = act.QuickSelect },

    -- Pane zoom
    { key = "Z", mods = "CTRL|SHIFT", action = act.TogglePaneZoomState },
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

-- PLUGINS ----------------------------------------------------
-- TABBAR
local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
tabline.setup({
  options = {
    icons_enabled = true,
    theme_overrides = {
      normal_mode = {
        a = { fg = bg_color, bg = accent_color },
        b = { fg = accent_color, bg = inactive_bg },
        c = { fg = fg_normal, bg = bg_color },
      },
      copy_mode = {
        a = { fg = bg_color, bg = accent_color },
        b = { fg = accent_color, bg = inactive_bg },
        c = { fg = fg_normal, bg = bg_color },
      },
      search_mode = {
        a = { fg = bg_color, bg = accent_color },
        b = { fg = accent_color, bg = inactive_bg },
        c = { fg = fg_normal, bg = bg_color },
      },
      window_mode = {
        a = { fg = bg_color, bg = accent_color },
        b = { fg = accent_color, bg = inactive_bg },
        c = { fg = fg_normal, bg = bg_color },
      },
      tab = {
        active =   { fg = bg_color, bg = accent_color },
        inactive = { fg = accent_color, bg = inactive_bg },
        inactive_hover = { fg = fg_normal, bg = bg_color },
      }
    },
    tabs_enabled = true,
    section_separators = {
      left = wezterm.nerdfonts.pl_left_hard_divider,
      right = wezterm.nerdfonts.pl_right_hard_divider,
    },
    component_separators = {
      left = wezterm.nerdfonts.pl_left_soft_divider,
      right = wezterm.nerdfonts.pl_right_soft_divider,
    },
    tab_separators = {
      left = wezterm.nerdfonts.pl_left_hard_divider,
      right = wezterm.nerdfonts.pl_right_hard_divider,
    },
  },
  sections = {
    tabline_a = { 'mode' },
    tabline_b = { 'workspace' },
    tabline_c = { ' ' },
    tab_active = {
      'index',
      { 'parent', padding = 0 },
      '/',
      { 'cwd', padding = { left = 0, right = 1 } },
      { 'zoomed', padding = 0 },
    },
    tab_inactive = { 'index', { 'process', padding = { left = 0, right = 1 } } },
    tabline_x = { 'ram', 'cpu' },
    tabline_y = { 'datetime', 'battery' },
    tabline_z = { 'domain' },
  },
  extensions = {},
})

return config
