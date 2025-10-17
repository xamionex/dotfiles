local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")

local title_bars = {}

-- Track titlebars state
title_bars.enabled = true
title_bars.current_clients = {}

-- Function to create titlebar for a client
function title_bars.create_titlebar(c)
    if not title_bars.enabled then
        return
    end

    -- buttons for the titlebar
    local buttons = gears.table.join(
        awful.button({}, 1, function()
            c:emit_signal("request::activate", "titlebar", { raise = true })
            awful.mouse.client.move(c)
        end),
        awful.button({}, 3, function()
            c:emit_signal("request::activate", "titlebar", { raise = true })
            awful.mouse.client.resize(c)
        end)
    )

    awful.titlebar(c):setup({
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout = wibox.layout.fixed.horizontal,
        },
        {     -- Middle
            { -- Title
                align = "center",
                widget = awful.titlebar.widget.titlewidget(c),
            },
            buttons = buttons,
            layout = wibox.layout.flex.horizontal,
        },
        { -- Right
            awful.titlebar.widget.floatingbutton(c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton(c),
            awful.titlebar.widget.ontopbutton(c),
            awful.titlebar.widget.closebutton(c),
            layout = wibox.layout.fixed.horizontal(),
        },
        layout = wibox.layout.align.horizontal,
    })

    -- Track this client
    title_bars.current_clients[c] = true
end

-- Function to remove titlebar from a client
function title_bars.remove_titlebar(c)
    if c and c.valid then
        awful.titlebar(c, { position = "top" }):remove()
        title_bars.current_clients[c] = nil
    end
end

-- Function to remove all titlebars
function title_bars.remove_all()
    title_bars.enabled = false

    for client, _ in pairs(title_bars.current_clients) do
        if client and client.valid then
            awful.titlebar(client, { position = "top" }):remove()
        end
    end

    title_bars.current_clients = {}
end

-- Function to enable titlebars
function title_bars.enable()
    title_bars.enabled = true
    title_bars.refresh_all()
end

-- Function to disable titlebars
function title_bars.disable()
    title_bars.remove_all()
end

-- Function to refresh titlebars for all current clients
function title_bars.refresh_all()
    if not title_bars.enabled then
        return
    end

    -- Clear current tracking
    title_bars.current_clients = {}

    -- Recreate titlebars for all valid clients
    for _, c in ipairs(client.get()) do
        if c.valid then
            title_bars.remove_titlebar(c) -- Remove existing first
            title_bars.create_titlebar(c) -- Create new one
        end
    end
end

-- Function to restart titlebars (disable and re-enable)
function title_bars.restart()
    title_bars.remove_all()
    title_bars.enable()
end

-- Function to toggle titlebars on/off
function title_bars.toggle()
    if title_bars.enabled then
        title_bars.disable()
    else
        title_bars.enable()
    end
end

-- Connect the signal to our managed function
client.connect_signal("request::titlebars", function(c)
    title_bars.create_titlebar(c)
end)

-- Clean up when clients are closed
client.connect_signal("unmanage", function(c)
    title_bars.current_clients[c] = nil
end)

return title_bars
