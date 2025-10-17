local beautiful = require("beautiful")
local awful = require("awful")

local rules = {
    -- All clients will match this rule.
    {
        rule = {},
        properties = {
            border_width = beautiful.border_width,
            border_color = beautiful.border_normal,
            focus = awful.client.focus.filter,
            raise = true,
            keys = clientkeys,
            buttons = clientbuttons,
            screen = awful.screen.preferred,
            placement = awful.placement.no_overlap + awful.placement.no_offscreen,
        },
    },

    {
        rule = {
            instance = "^LibreWolf$",
        },
        properties = {
            tag = "3",
        },
    },

    {
        rule_any = {
            class = {
                "^steam$",          --All other windows
                "^steamwebhelper$", --All other windows
                "^vesktop$",
            },
            instance = {
                "^ts3client_linux_amd64$",
            },

            name = {
                "^Steam$", --Login Window
            },
        },

        properties = {
            tag = "10",
        },
    },

    -- Add titlebars to normal clients and dialogs
    {
        rule_any = {
            type = {
                "normal",
                "dialog",
            },
        },
        except_any = {
            class = {
                "^Hydrus Client$",
            },
        },
        properties = {
            titlebars_enabled = true,
        },
    },
    {
        rule = { class = "Hydrus Client" },
        properties = { floating = false, maximized = false },
    },
}

return rules
