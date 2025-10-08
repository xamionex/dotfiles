local awful = require("awful")

local home = os.getenv("HOME")

local auto_start = {
	"picom",
	"numlockx on",
	--"nvidia-settings -l",
	--"easyeffects --gapplication-service",
	--"aria2c --daemon --enable-rpc",
	--"dispwin -d 1 " .. home .. '"/.color/Dell S2721DGF.icm"',
	"greenclip daemon > /dev/null",
	--"xhidecursor",
	--"rssguard",
	--'"$HOME/.config/i3/Scripts/random-bg.sh"',
}

for i = 1, #auto_start do
	local cmd = auto_start[i]
	awful.spawn.easy_async_with_shell('pgrep -f "^' .. cmd .. '\\$"', function(out)
		if out:len() < 1 then
			awful.spawn(cmd)
		end
	end)
end
