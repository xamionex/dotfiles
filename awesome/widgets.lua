local awful = require("awful")
local beautiful = require("beautiful")
local wibox = require("wibox")
local gears = require("gears")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
local dpi = beautiful.xresources.apply_dpi

-- Widgets
local cpu_widget = require("awesome-wm-widgets.cpu-widget.cpu-widget")
local ram_widget = require("awesome-wm-widgets.ram-widget.ram-widget")
-- local fs_widget = require("awesome-wm-widgets.fs-widget.fs-widget") -- Uncomment if used
-- local mympdwidget = require("mpc_widget") -- Uncomment if used

local widgets = {}

-- Initialize menu
function widgets.init_menu(terminal, editor_cmd)
    local myawesomemenu = {
        { "hotkeys",     function() hotkeys_popup.show_help(nil, awful.screen.focused()) end },
        { "manual",      terminal .. " -e man awesome" },
        { "edit config", editor_cmd .. " " .. awesome.conffile },
        { "restart",     awesome.restart },
        { "quit",        function() awesome.quit() end },
    }

    widgets.mymainmenu = awful.menu({
        items = {
            { "I'm tired boss...", "bash -c 'sudo systemctl poweroff -i'",            beautiful.awesome_icon },

            -- Disable screensaver, DPMS, and blanking
            { "Force Monitor On",  "bash -c 'xset s off; xset -dpms; xset s noblank'" },

            -- Restore screensaver, DPMS, and blanking
            { "Allow Monitor Off", "bash -c 'xset s on; xset +dpms; xset s blank'" },

            --{ "awesome",       myawesomemenu, beautiful.awesome_icon },
            --{ "open terminal", terminal },
        },
    })

    widgets.mylauncher = awful.widget.launcher({
        image = beautiful.awesome_icon,
        menu = widgets.mymainmenu
    })

    menubar.utils.terminal = terminal
end

-- Initialize individual widgets
function widgets.init_individual_widgets()
    widgets.mykeyboardlayout = awful.widget.keyboardlayout()
    widgets.mytextclock = wibox.widget.textclock()
    widgets.mycpuwidget = cpu_widget()
    widgets.myramwidget = ram_widget()
    -- widgets.myfswidget = fs_widget({
    --     mounts = { "/", "/part/sdb" },
    --     popup_bg = "#222222",
    -- })
    -- widgets.mympdwidget = mympdwidget
end

-- Initialize wiboxes for all screens
function widgets.init_wibox()
    local taglist_buttons = gears.table.join(
        awful.button({}, 1, function(t) t:view_only() end),
        awful.button({ modkey }, 1, function(t) if client.focus then client.focus:move_to_tag(t) end end),
        awful.button({}, 3, awful.tag.viewtoggle),
        awful.button({ modkey }, 3, function(t) if client.focus then client.focus:toggle_tag(t) end end),
        awful.button({}, 4, function(t) awful.tag.viewnext(t.screen) end),
        awful.button({}, 5, function(t) awful.tag.viewprev(t.screen) end)
    )

    local tasklist_buttons = gears.table.join(
        awful.button({}, 1, function(c)
            if c == client.focus then
                c.minimized = true
            else
                c:emit_signal("request::activate", "tasklist", { raise = true })
            end
        end),
        awful.button({}, 3, function() awful.menu.client_list({ theme = { width = 250 } }) end),
        awful.button({}, 4, function() awful.client.focus.byidx(1) end),
        awful.button({}, 5, function() awful.client.focus.byidx(-1) end)
    )

    awful.screen.connect_for_each_screen(function(s)
        -- Tags (reuse existing tags if they exist, otherwise create default ones)
        if not s.tags or #s.tags == 0 then
            awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" }, s, awful.layout.layouts[1])
        end
        -- awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9" }, s, {
        --     awful.layout.layouts[1],
        --     awful.layout.layouts[1],
        --     awful.layout.suit.max.fullscreen,
        --     awful.layout.layouts[1],
        --     awful.layout.layouts[1],
        --     awful.layout.layouts[1],
        --     awful.layout.layouts[1],
        --     awful.layout.layouts[1],
        --     awful.layout.layouts[1],
        -- })

        -- Promptbox
        s.mypromptbox = awful.widget.prompt()

        -- Layoutbox
        s.mylayoutbox = awful.widget.layoutbox(s)
        s.mylayoutbox:buttons(gears.table.join(
            awful.button({}, 1, function() awful.layout.inc(1) end),
            awful.button({}, 3, function() awful.layout.inc(-1) end),
            awful.button({}, 4, function() awful.layout.inc(1) end),
            awful.button({}, 5, function() awful.layout.inc(-1) end)
        ))

        -- Taglist
        s.mytaglist = awful.widget.taglist({
            screen = s,
            filter = awful.widget.taglist.filter.all,
            buttons = taglist_buttons,
        })

        -- Tasklist
        s.mytasklist = awful.widget.tasklist({
            screen = s,
            filter = awful.widget.tasklist.filter.currenttags,
            buttons = tasklist_buttons,
        })

        -- Wibox
        s.mywibox = awful.wibar({ position = "top", screen = s })
        s.mywibox_seperator = wibox.widget.textbox(" | ", false)

        s.mywibox:setup({
            layout = wibox.layout.align.horizontal,
            -- Left
            {
                layout = wibox.layout.fixed.horizontal,
                widgets.mylauncher,
                -- s.copy_textbox,
                s.mytaglist,
                s.mypromptbox,
            },
            -- Middle
            s.mytasklist,
            -- Right
            {
                layout = wibox.layout.fixed.horizontal,
                widgets.mycpuwidget,
                widgets.myramwidget,
                -- widgets.myfswidget,
                widgets.mykeyboardlayout,
                wibox.widget.systray(),
                -- widgets.mympdwidget,
                s.mywibox_seperator,
                widgets.mytextclock,
                s.mylayoutbox,
            },
        })
    end)
end

-- Remove all widgets and cleanup
function widgets.remove_all()
    -- Remove wiboxes from all screens
    for s in screen do
        if s.mywibox then
            s.mywibox:remove()
            s.mywibox = nil
        end

        -- Only remove widgets, keep tags intact
        s.mypromptbox = nil
        s.mylayoutbox = nil
        s.mytaglist = nil
        s.mytasklist = nil
        s.mywibox_seperator = nil
    end


    -- Clean up global widgets
    widgets.mylauncher = nil
    widgets.mymainmenu = nil
    widgets.mykeyboardlayout = nil
    widgets.mytextclock = nil
    widgets.mycpuwidget = nil
    widgets.myramwidget = nil
    -- widgets.myfswidget = nil
    -- widgets.mympdwidget = nil

    -- Clear the widgets table
    --   for k in pairs(widgets) do
    --     if string.sub(k, 1, 2) == "my" then
    --       widgets[k] = nil
    --     end
    --   end

    -- Force garbage collection to free up resources
    -- TODO: Replace with recoloring as this wastes RAM after a while
    collectgarbage()
end

-- Reinitialize all widgets | TODO: Replace with recoloring instead of reinitializing
function widgets.recolor()
    widgets.remove_all()

    local variables = require("variables")
    widgets.init_menu(variables.terminal, variables.editor_cmd)
    widgets.init_individual_widgets()
    widgets.init_wibox()
end

-- Initialize everything in order
function widgets.init()
    local variables = require("variables")
    widgets.init_menu(variables.terminal, variables.editor_cmd)
    widgets.init_individual_widgets()
    widgets.init_wibox()
end

return widgets
