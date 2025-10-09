-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

local variables = require("variables")

-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
local widgets = require("widgets")
-- Theme handling library
local beautiful = require("beautiful")
local wallpaper = require("wallpaper")
-- Notification library
local dpi = require("beautiful.xresources").apply_dpi
local naughty = require("naughty")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:
require("awful.hotkeys_popup.keys")

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
  naughty.notify({
    preset = naughty.config.presets.critical,
    title = "Oops, there were errors during startup!",
    text = awesome.startup_errors,
  })
end

-- Handle runtime errors after startup
do
  local in_error = false
  awesome.connect_signal("debug::error", function(err)
    -- Make sure we don't go into an endless error loop
    if in_error then
      return
    end
    in_error = true

    naughty.notify({
      preset = naughty.config.presets.critical,
      title = "Oops, an error happened!",
      text = tostring(err),
    })
    in_error = false
  end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, font and wallpapers.
--beautiful.init(gears.filesystem.get_themes_dir() .. "default/theme.lua")
beautiful.init(gears.filesystem.get_configuration_dir() .. "theme.lua")
--beautiful.wallpaper = os.getenv("HOME") .. "/Pictures/Wallpapers/127848848(106630500)_横图-miku初音.jpg"
--beautiful.wallpaper = os.getenv("HOME") .. "/Pictures/Wallpapers/123101575(593960)_キサキ_1.jpg"
--beautiful.wallpaper = os.getenv("HOME") .. "/Pictures/Wallpapers/Wallpaper-Zelda.jpg"

naughty.config.defaults.width = dpi(600)
local notif_height = dpi(130)
naughty.config.defaults.height = notif_height
naughty.config.defaults.icon_size = notif_height * 0.9

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
  awful.layout.suit.tile,
  --awful.layout.suit.tile.left,
  awful.layout.suit.max,
  --awful.layout.suit.tile.top,
  awful.layout.suit.fair,
  --awful.layout.suit.fair.horizontal,
  --awful.layout.suit.spiral.dwindle,
  awful.layout.suit.max.fullscreen,
  --awful.layout.suit.magnifier,
  --awful.layout.suit.corner.nw,
  awful.layout.suit.tile.bottom,
  ----awful.layout.suit.floating,
  --awful.layout.suit.spiral,
  -- awful.layout.suit.corner.ne,
  -- awful.layout.suit.corner.sw,
  -- awful.layout.suit.corner.se,
}
-- }}}

local function toggle_fake_screen()
  local focused = awful.screen.focused()
  local fake = focused.fake_screen

  local foc_geo = focused.geometry
  local fake_geo = fake.geometry

  focused:fake_resize(fake_geo.x, fake_geo.y, fake_geo.width, fake_geo.height)
  fake:fake_resize(foc_geo.x, foc_geo.y, foc_geo.width, foc_geo.height)

  --focused:swap(fake)

  local delta_x = fake_geo.x - foc_geo.x
  local delta_y = fake_geo.y - foc_geo.y

  for _, c in ipairs(fake.all_clients) do
    --Fix for messed up coordinates after resizing screen
    if c.maximized or c.maximized_horizontal or c.maximized_vertical then
      c.x = c.x + delta_x
      c.y = c.y + delta_y
    end
  end

  awful.screen.focus(fake)
end

-- Keyboard map indicator and switcher
mykeyboardlayout = awful.widget.keyboardlayout()

-- Function to get current volume as string
local function notify_volume()
  -- Use a shell command to get volume
  awful.spawn.easy_async_with_shell("wpctl get-volume @DEFAULT_AUDIO_SINK@", function(stdout)
    -- wpctl outputs like: "Volume: 0.50 [50%]"
    -- Extract the percentage part using Lua pattern matching
    local volume = stdout:match("(%d?%.?%d+)")
    local muted = stdout:match(".*(%[MUTED%])") or ""
    if volume then
      local percent = math.floor(tonumber(volume) * 100)
      naughty.notify({
        preset = naughty.config.presets.info,
        title = "Volume is set to:",
        text = percent .. "% " .. muted,
      })
      --else
      --    naughty.notify({
      --        preset = naughty.config.presets.critical,
      --        title = "Error",
      --        text = "Could not get volume",
      --    })
    end
  end)
end

-- {{{ Key bindings
globalkeys = gears.table.join(
  awful.key({ modkey }, "s", hotkeys_popup.show_help, { description = "show help", group = "awesome" }),
  awful.key({ modkey }, "Left", awful.tag.viewprev, { description = "view previous", group = "tag" }),
  awful.key({ modkey }, "Right", awful.tag.viewnext, { description = "view next", group = "tag" }),
  awful.key({ modkey }, "Escape", awful.tag.history.restore, { description = "go back", group = "tag" }),
  awful.key({ modkey }, "j", function()
    awful.client.focus.byidx(1)
  end, { description = "focus next by index", group = "client" }),
  awful.key({ modkey }, "k", function()
    awful.client.focus.byidx(-1)
  end, { description = "focus previous by index", group = "client" }),
  awful.key({ modkey }, "w", function()
    mymainmenu:show()
  end, { description = "show main menu", group = "awesome" }),

  -- Layout manipulation
  awful.key({ modkey, "Shift" }, "j", function()
    awful.client.swap.byidx(1)
  end, { description = "swap with next client by index", group = "client" }),
  awful.key({ modkey, "Shift" }, "k", function()
    awful.client.swap.byidx(-1)
  end, { description = "swap with previous client by index", group = "client" }),
  awful.key({ modkey, "Control" }, "j", function()
    awful.screen.focus_relative(1)
  end, { description = "focus the next screen", group = "screen" }),
  awful.key({ modkey, "Control" }, "k", function()
    awful.screen.focus_relative(-1)
  end, { description = "focus the previous screen", group = "screen" }),
  awful.key({ modkey }, "u", awful.client.urgent.jumpto, { description = "jump to urgent client", group = "client" }),
  awful.key({ modkey }, "Tab", function()
    awful.client.focus.history.previous()
    if client.focus then
      client.focus:raise()
    end
  end, { description = "go back", group = "client" }),

  awful.key({}, "Print", function()
    awful.spawn("screenshot.sh")
  end, { description = "take screenshot", group = "launcher" }),

  awful.key({ "Shift" }, "Print", function()
    awful.spawn("screenshot.sh -f")
  end, { description = "take screenshot", group = "launcher" }),

  -- Standard program
  awful.key({ modkey }, "Return", function()
    awful.spawn(variables.terminal)
  end, { description = "open a terminal", group = "launcher" }),
  awful.key({ modkey, "Control" }, "r", awesome.restart, { description = "reload awesome", group = "awesome" }),
  awful.key({ modkey, "Shift" }, "q", awesome.quit, { description = "quit awesome", group = "awesome" }),
  awful.key({ modkey }, "l", function()
    awful.tag.incmwfact(0.05)
  end, { description = "increase master width factor", group = "layout" }),
  awful.key({ modkey }, "h", function()
    awful.tag.incmwfact(-0.05)
  end, { description = "decrease master width factor", group = "layout" }),
  awful.key({ modkey, "Shift" }, "h", function()
    awful.tag.incnmaster(1, nil, true)
  end, { description = "increase the number of master clients", group = "layout" }),
  awful.key({ modkey, "Shift" }, "l", function()
    awful.tag.incnmaster(-1, nil, true)
  end, { description = "decrease the number of master clients", group = "layout" }),
  awful.key({ modkey, "Control" }, "h", function()
    awful.tag.incncol(1, nil, true)
  end, { description = "increase the number of columns", group = "layout" }),
  awful.key({ modkey, "Control" }, "l", function()
    awful.tag.incncol(-1, nil, true)
  end, { description = "decrease the number of columns", group = "layout" }),
  awful.key({ modkey }, "space", function()
    awful.layout.inc(1)
  end, { description = "select next", group = "layout" }),
  awful.key({ modkey, "Shift" }, "space", function()
    awful.layout.inc(-1)
  end, { description = "select previous", group = "layout" }),
  awful.key({ modkey }, "c", function()
    local tag = awful.screen.focused().selected_tags
    awful.tag.setmwfact(0.5, tag[1])
    awful.tag.setnmaster(1, tag[1])
    awful.tag.setncol(1, tag[1])
  end, { description = "reset layout settings", group = "layout" }),

  awful.key({ modkey, "Control" }, "n", function()
    local c = awful.client.restore()
    -- Focus restored client
    if c then
      c:emit_signal("request::activate", "key.unminimize", { raise = true })
    end
  end, { description = "restore minimized", group = "client" }),

  -- Prompt
  awful.key({ modkey }, "r", function()
    --awful.screen.focused().mypromptbox:run()
    awful.spawn("rofi -show run")
  end, { description = "run prompt", group = "launcher" }),
  awful.key({ modkey, "Shift" }, "r", function()
    awful.spawn("rofi -show drun")
  end, { description = "desktop run prompt", group = "launcher" }),

  awful.key({ modkey }, "v", function()
    awful.spawn("rofi -modi \"clipboard:greenclip print\" -show clipboard -run-command '{cmd}'")
  end, { description = "clipboard prompt", group = "launcher" }),
  awful.key({ modkey, "Shift" }, "v", function()
    awful.spawn("rofi -modi emoji -show emoji")
  end, { description = "emoji prompt", group = "launcher" }),

  awful.key({ modkey }, "x", function()
    awful.prompt.run({
      prompt = "Run Lua code: ",
      textbox = awful.screen.focused().mypromptbox.widget,
      exe_callback = awful.util.eval,
      history_path = awful.util.get_cache_dir() .. "/history_eval",
    })
  end, { description = "lua execute prompt", group = "awesome" }),
  -- Menubar
  awful.key({ modkey }, "p", function()
    menubar.show()
  end, { description = "show the menubar", group = "launcher" }),

  awful.key({}, "XF86AudioRaiseVolume", function()
    awful.spawn("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+")
    notify_volume()
  end, { description = "Raise Volume by 1", group = "music" }),
  awful.key({}, "XF86AudioLowerVolume", function()
    awful.spawn("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-")
    notify_volume()
  end, { description = "Lower Volume by 1", group = "music" }),
  awful.key({}, "XF86AudioMute", function()
    awful.spawn("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
    notify_volume()
  end, { description = "Lower Volume by 1", group = "music" }),

  awful.key({}, "XF86AudioNext", function()
    awful.spawn({ "mpc", "next" })
  end, { description = "Play next track", group = "music" }),
  awful.key({}, "XF86AudioPrev", function()
    awful.spawn("mpc prev")
  end, { description = "Play previous track", group = "music" }),
  awful.key({}, "XF86AudioPlay", function()
    awful.spawn("mpc toggle")
  end, { description = "Toggle music playing", group = "music" })

--awful.key({ modkey }, "d", function()
--	toggle_fake_screen()
--end, { description = "toggle fake screen", group = "screen" })
)

clientkeys = gears.table.join(
  awful.key({ modkey }, "f", function(c)
    c.fullscreen = not c.fullscreen
    c:raise()
  end, { description = "toggle fullscreen", group = "client" }),
  awful.key({ modkey }, "q", function(c)
    c:kill()
  end, { description = "close", group = "client" }),
  awful.key(
    { modkey, "Control" },
    "space",
    awful.client.floating.toggle,
    { description = "toggle floating", group = "client" }
  ),
  awful.key({ modkey, "Control" }, "Return", function(c)
    c:swap(awful.client.getmaster())
  end, { description = "move to master", group = "client" }),
  awful.key({ modkey }, "o", function(c)
    c:move_to_screen(c.screen.index + 1)
  end, { description = "move to next screen", group = "client" }),
  awful.key({ modkey, "Shift" }, "o", function(c)
    c:move_to_screen(c.screen.index - 1)
  end, { description = "move to prev screen", group = "client" }),
  awful.key({ modkey }, "t", function(c)
    c.ontop = not c.ontop
  end, { description = "toggle keep on top", group = "client" }),
  awful.key({ modkey }, "n", function(c)
    -- The client currently has the input focus, so it cannot be
    -- minimized, since minimized clients can't have the focus.
    c.minimized = true
  end, { description = "minimize", group = "client" }),
  awful.key({ modkey }, "m", function(c)
    c.maximized = not c.maximized
    c:raise()
  end, { description = "(un)maximize", group = "client" }),
  awful.key({ modkey, "Control" }, "m", function(c)
    c.maximized_vertical = not c.maximized_vertical
    c:raise()
  end, { description = "(un)maximize vertically", group = "client" }),
  awful.key({ modkey, "Shift" }, "m", function(c)
    c.maximized_horizontal = not c.maximized_horizontal
    c:raise()
  end, { description = "(un)maximize horizontally", group = "client" }),

  awful.key({ modkey }, "F4", function(c)
    local s = awful.screen.focused()
    for _, c in ipairs(s.all_clients) do
      if c.maximized then
        print(c.name)
        print(c.x .. " " .. c.y)
      end
    end
  end, { description = "run debug lua", group = "debug" })
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it work on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 10 do
  globalkeys = gears.table.join(
    globalkeys,
    -- View tag only.
    awful.key({ modkey }, "#" .. i + 9, function()
      local screen = awful.screen.focused()
      local tag = screen.tags[i]
      if tag then
        tag:view_only()
      end
    end, { description = "view tag #" .. i, group = "tag" }),
    -- Toggle tag display.
    awful.key({ modkey, "Control" }, "#" .. i + 9, function()
      local screen = awful.screen.focused()
      local tag = screen.tags[i]
      if tag then
        awful.tag.viewtoggle(tag)
      end
    end, { description = "toggle tag #" .. i, group = "tag" }),
    -- Move client to tag.
    awful.key({ modkey, "Shift" }, "#" .. i + 9, function()
      if client.focus then
        local tag = client.focus.screen.tags[i]
        if tag then
          client.focus:move_to_tag(tag)
        end
      end
    end, { description = "move focused client to tag #" .. i, group = "tag" }),
    -- Toggle tag on focused client.
    awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9, function()
      if client.focus then
        local tag = client.focus.screen.tags[i]
        if tag then
          client.focus:toggle_tag(tag)
        end
      end
    end, { description = "toggle focused client on tag #" .. i, group = "tag" })
  )
end

clientbuttons = gears.table.join(
  awful.button({}, 1, function(c)
    c:emit_signal("request::activate", "mouse_click", { raise = true })
  end),
  awful.button({ modkey }, 1, function(c)
    c:emit_signal("request::activate", "mouse_click", { raise = true })
    awful.mouse.client.move(c)
  end),
  awful.button({ modkey }, 3, function(c)
    c:emit_signal("request::activate", "mouse_click", { raise = true })
    awful.mouse.client.resize(c)
  end)
)

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Mouse bindings
root.buttons(gears.table.join(
  awful.button({}, 3, function()
    mymainmenu:toggle()
  end),
  awful.button({}, 4, awful.tag.viewnext),
  awful.button({}, 5, awful.tag.viewprev)
))
-- }}}

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
  c:emit_signal("request::activate", "mouse_enter", { raise = false })
end)

client.connect_signal("focus", function(c)
  c.border_color = beautiful.border_focus
end)
client.connect_signal("unfocus", function(c)
  c.border_color = beautiful.border_normal
end)

client.connect_signal("manage", function(c)
  -- Set the windows at the slave,
  -- i.e. put it at the end of others instead of setting it master.
  -- if not awesome.startup then awful.client.setslave(c) end

  if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
    -- Prevent clients from being unreachable after screen count changes.
    awful.placement.no_offscreen(c)
  end
end)

require("auto_start")
require("mouse_follows_focus")
require("title_bars")

local global_rules = require("global_rules")
local hydrus = require("hydrus")

--No clue why but chaning awful.rules.rules from any other file does not work
gears.table.merge(awful.rules.rules, global_rules)
gears.table.merge(awful.rules.rules, hydrus.rules)

awful.ewmh.add_activate_filter(function(c)
  --if c.class == "steam" or c.class == "steamwebhelper" or c.name == "Steam" then
  --	return false
  --end
end, "ewmh")

--Undo focus change when sending client to some other screen
local last_screen_focus = nil
awful.ewmh.add_activate_filter(function(c, context)
  last_screen_focus = awful.screen.focused()
end, "screen.focus")
awful.ewmh.add_activate_filter(function(c, context)
  if last_screen_focus ~= nil then
    awful.screen.focus(last_screen_focus)
  end
  return false
end, "client.movetoscreen")

widgets.init_all()

print("Lua ran!")
