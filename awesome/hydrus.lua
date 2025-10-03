local awful = require("awful")

--TODO: Maybe improve performance by only waiting for signals when hydrus is actually open

local hydrus = {}

hydrus.class_name = "Hydrus Client"

hydrus.rules = {
	rule = { class = "^" .. hydrus.class_name .. "$" },
	properties = { floating = false, maximized = false },
}

function hydrus.is_client(c)
	return c.class == hydrus.class_name
end

hydrus.slaves = {
	"manage tags",
	"Delete files?", --Deleting
	"Are you sure?", --Restoring files
}

function hydrus.arrange_clients(c, manage)
	if not hydrus.is_client(c) then
		return
	end

	local mwfact = 0.7
	awful.layout.set(awful.layout.suit.tile.right, c.tag)
	awful.tag.setmwfact(mwfact, c.tag)

	if not manage then
		return
	end

	for k, v in pairs(hydrus.slaves) do
		if string.find(c.name, v) then
			awful.client.setslave(c)
			break
		end
	end
end

client.connect_signal("focus", function(c)
	if not hydrus.is_client(c) then
		return
	end

	c.screen.mywibox.visible = false
end)

client.connect_signal("unfocus", function(c)
	if not hydrus.is_client(c) then
		return
	end

	c.screen.mywibox.visible = true
end)

client.connect_signal("manage", function(c)
	hydrus.arrange_clients(c, true)
end)
client.connect_signal("unmanage", function(c)
	hydrus.arrange_clients(c, false)
end)

return hydrus
