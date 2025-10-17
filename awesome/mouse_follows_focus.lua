local awful = require("awful")
local gears = require("gears")

local last_focus = nil

local function is_client_equal(c1, c2)
    if c1 == nil or not c1.valid then
        return false
    end
    if c2 == nil or not c2.valid then
        return false
    end

    return c1.window == c2.window
end

local function is_last_focus(c)
    return is_client_equal(c, last_focus)
end

local function __center_mouse(c, ignore_last_focus)
    if not is_client_equal(client.focus, c) then
        return
    end

    local coords = mouse.coords()
    if coords.buttons[1] or coords.buttons[3] then --Left or Right click. Exit here for resize/reposition
        return
    end

    --Do not move away from wibars and widgets
    if mouse.current_widget ~= nil or mouse.current_wibar ~= nil then
        return
    end

    if not ignore_last_focus and is_last_focus(c) then
        return
    end

    last_focus = c

    local g = c:geometry()
    mouse.coords({
        x = g.x + g.width / 2,
        y = g.y + g.height / 2,
    }, true)
end

local function center_mouse(c, ignore_last_focus)
    --Small delay, otherwise closing windows can bug out
    gears.timer.weak_start_new(0.05, function()
        __center_mouse(c, ignore_last_focus)
    end)
end

--client.connect_signal("request::geometry", function(c)
--	center_mouse()
--end)
client.connect_signal("property::size", function(c)
    center_mouse(c, is_last_focus(c))
end)
client.connect_signal("property::position", function(c)
    center_mouse(c, is_last_focus(c))
end)
client.connect_signal("request::activate", function(c, context)
    if context ~= "mouse_click" and context ~= "mouse_enter" and awful.client.focus.filter(c) ~= nil then
        center_mouse(c)
    end
end)
