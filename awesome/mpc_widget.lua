local mpc = require("mpc")
local textbox = require("wibox.widget.textbox")
local timer = require("gears.timer")

local mpd_widget = textbox()
local state, title, artist, file = "stop", "", "", ""

local function update_widget()
	local color = "green"

	local text = (title or "") .. " - " .. (artist or "")
	if #text > 30 then
		text = string.sub(text, 0, 30)
	end
	if state == "pause" then
		text = text .. " (paused)"
		color = "grey"
	end
	if state == "stop" then
		text = text .. " (stopped)"
		color = "red"
	end

	mpd_widget.markup = '<span foreground="' .. color .. '">' .. text .. "</span>"
end
local connection
local function error_handler(err)
	mpd_widget:set_text("Error: " .. tostring(err))
	-- Try a reconnect soon-ish
	timer.start_new(10, function()
		connection:send("ping")
	end)
end
connection = mpc.new(
	nil,
	nil,
	nil,
	error_handler,
	"status",
	function(_, result)
		state = result.state
	end,
	"currentsong",
	function(_, result)
		title, artist, file = result.title, result.artist, result.file
		pcall(update_widget)
	end
)

return mpd_widget
