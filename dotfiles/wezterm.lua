local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.hide_tab_bar_if_only_one_tab = true

if wezterm.hostname() == "ramjet" or wezterm.hostname() == "scramjet" then
	config.color_scheme = "Gruvbox dark, hard (base16)"
else
	config.color_scheme = "Rosé Pine Moon (base16)"
end

config.font = wezterm.font("FiraCode Nerd Font Mono")

return config
