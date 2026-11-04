-- Overworld Hyprland — :colorscheme overworld-night  (Minecraft "Night": deepslate / obsidian GUI, moon + nether accents)
-- Installed to ~/.local/share/nvim/site/colors/ ; palette comes from tokens via lua/overworld/palette_night.lua
package.loaded['overworld.theme'] = nil
require('overworld').load('night')
