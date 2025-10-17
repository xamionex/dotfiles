-- Wallpaper + Pywal integration (simplified)

local gears = require("gears")
local awful = require("awful")
local naughty = require("naughty")
local beautiful = require("beautiful")

local wallpaper_dir = os.getenv("HOME") .. "/Pictures/Wallpapers/awesome"
local pywal_cache = os.getenv("HOME") .. "/.cache/wal/colors"
local wezterm_theme = os.getenv("HOME") .. "/.config/wezterm/theme"
local theme = require("theme")
local wallpaper_timer = nil

-- ==================================================
-- WALLPAPER MANAGEMENT
-- ==================================================

local wallpapers = {}
local current_wallpaper = nil

local function set_wallpaper(path)
    if not path then return end
    beautiful.wallpaper = path
    for s in screen do
        gears.wallpaper.maximized(path, s, true)
    end
    current_wallpaper = path
end

local function random_wallpaper()
    awful.spawn.easy_async_with_shell('find "' .. wallpaper_dir .. '" -type f', function(out)
        wallpapers = {}
        for line in out:gmatch("[^\n]+") do table.insert(wallpapers, line) end
        if #wallpapers == 0 then
            naughty.notify({ title = "Wallpaper", text = "No wallpapers found." })
            return
        end
        local pick = wallpapers[math.random(#wallpapers)]
        if pick ~= current_wallpaper then
            set_wallpaper(pick)
        end
    end)
end

-- ==================================================
-- PYWAL THEME SYNC
-- ==================================================

local function read_pywal_colors()
    local f = io.open(pywal_cache, "r")
    if not f then return nil end
    local colors = {}
    for i = 0, 15 do colors[i] = f:read("*l") end
    f:close()
    return colors
end

local function write_wezterm_theme(colors)
    if not colors then return end
    local f = io.open(wezterm_theme, "w")
    if not f then return end
    f:write("[Colors:Window]\n")
    f:write("BackgroundNormal=" .. (colors[0] or "#222222") .. "\n")
    f:write("ForegroundNormal=" .. (colors[7] or "#dddddd") .. "\n\n")
    f:write("[General]\n")
    f:write("AccentColor=" .. (colors[1] or "#ff0000") .. "\n")
    f:close()
end

local function apply_pywal(wall)
    awful.spawn.easy_async_with_shell("wal -i '" .. wall .. "' -n", function()
        gears.timer.start_new(1, function()
            local colors = read_pywal_colors()
            write_wezterm_theme(colors)
            theme.update_pywal_colors()
        end)
    end)
end

-- ==================================================
-- AUTO ROTATION + SIGNALS
-- ==================================================

local function start_timer()
	if not wallpaper_timer then
	    wallpaper_timer = gears.timer {
	        timeout = 10 * 60, -- Rotate every X seconds
	        autostart = true,
	        call_now = true,
	        callback = function()
	            awful.spawn.easy_async_with_shell('find "' .. wallpaper_dir .. '" -type f', function(out)
	                local files = {}
	                for line in out:gmatch("[^\n]+") do table.insert(files, line) end
	                if #files > 0 then
	                    local pick = files[math.random(#files)]
	                    if pick ~= current_wallpaper then
	                        set_wallpaper(pick)
	                        apply_pywal(pick)
	                    end
	                end
	            end)
	        end
	    }
	end
end

function cleanup_wallpaper()
    if wallpaper_timer then
        wallpaper_timer:stop()
        wallpaper_timer = nil
    end
end

screen.connect_signal("property::geometry", function(s) set_wallpaper(current_wallpaper) end)

start_timer()

return {
    set_wallpaper = set_wallpaper,
    random_wallpaper = random_wallpaper,
    apply_pywal = apply_pywal,
    cleanup = cleanup_wallpaper,
    start = start_timer
}
