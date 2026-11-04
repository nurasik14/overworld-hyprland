-- Overworld Hyprland — nvim entry: require('overworld').load('light'|'dark') or :colorscheme overworld-light
local M = {}
function M.load(mode)
  mode = mode or 'light'
  local ok, p = pcall(require, 'overworld.palette_' .. mode)
  if not ok then error('overworld: palette_' .. mode .. ' not found (run apps/install.sh)') end
  require('overworld.theme').apply(p)
end
-- follow the desktop: reads ~/.config/overworld/mode when present
function M.auto()
  local f = io.open(vim.fn.expand('~/.config/overworld/mode'), 'r')
  local mode = f and f:read('*l') or 'light'
  if f then f:close() end
  M.load(mode == 'dark' and 'dark' or 'light')
end
return M
