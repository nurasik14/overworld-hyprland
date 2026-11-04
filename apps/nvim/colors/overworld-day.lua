-- Overworld Hyprland — :colorscheme overworld-day  (Minecraft "Day": light-grey GUI, grass + sky accents)
-- Installed to ~/.local/share/nvim/site/colors/ ; palette comes from tokens via lua/overworld/palette_day.lua
package.loaded['overworld.theme'] = nil
require('overworld').load('day')
