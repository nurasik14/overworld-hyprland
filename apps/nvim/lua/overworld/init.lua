-- Overworld Hyprland — nvim entry point.
--   require('overworld').setup({ mode = 'auto' | 'day' | 'night', follow = true })
--   require('overworld').load('day' | 'night')     (also accepts the legacy 'light' / 'dark')
--   require('overworld').auto()                    (reads ~/.config/overworld/mode: light|dark)
-- Or simply :colorscheme overworld-day / overworld-night.
local M = {}

local ALIAS = { light = 'day', day = 'day', dark = 'night', night = 'night' }
local MODE_FILE = '~/.config/overworld/mode'

local function norm(mode) return ALIAS[mode or 'day'] or 'day' end

-- The desktop's current mode as 'day' | 'night' (defaults to day when the file is absent).
function M.desktop_mode()
  local f = io.open(vim.fn.expand(MODE_FILE), 'r')
  local mode = f and f:read('*l') or 'light'
  if f then f:close() end
  mode = (mode or ''):gsub('%s+', '')
  return mode == 'dark' and 'night' or 'day'
end

function M.load(mode)
  mode = norm(mode)
  local ok, p = pcall(require, 'overworld.palette_' .. mode)
  if not ok then error('overworld: palette_' .. mode .. ' not found (run apps/install.sh): ' .. tostring(p)) end
  require('overworld.theme').apply(p, mode)
  M.current = mode
end

function M.auto() M.load(M.desktop_mode()) end

-- Palette of a mode (for statuslines, etc.)
function M.palette(mode) return require('overworld.palette_' .. norm(mode)) end

-- Ready-made lualine theme table:  require('lualine').setup{ options = { theme = require('overworld').lualine_theme() } }
function M.lualine_theme(mode)
  local p = M.palette(mode or M.current or M.desktop_mode())
  local function sec(bg, fg) return { fg = fg, bg = bg, gui = 'bold' } end
  local mid = { fg = p.titlebarText, bg = p.titlebar }
  local function mk(accent, on) return { a = sec(accent, on), b = { fg = p.titlebarText, bg = p.slotDark }, c = mid } end
  return {
    normal = mk(p.accentSoft, '#000000'), insert = mk(p.chatAqua or p.jade, '#000000'),
    visual = mk(p.enchantGlint, '#000000'), replace = mk(p.lava, '#000000'),
    command = mk(p.gold, '#000000'), inactive = { a = { fg = p.textMuted, bg = p.bg0 }, b = { fg = p.textMuted, bg = p.bg0 }, c = { fg = p.textMuted, bg = p.bg0 } },
  }
end

-- opts.mode   'auto' (default: follow ~/.config/overworld/mode) | 'day' | 'night'
-- opts.follow re-read the desktop mode on FocusGained when mode == 'auto' (default true)
function M.setup(opts)
  opts = opts or {}
  local mode = opts.mode or 'auto'
  if mode == 'auto' then M.auto() else M.load(mode) end
  local grp = vim.api.nvim_create_augroup('OverworldFollow', { clear = true })
  if mode == 'auto' and opts.follow ~= false then
    vim.api.nvim_create_autocmd('FocusGained', {
      group = grp,
      callback = function()
        local cs = vim.g.colors_name or ''
        if cs:match('^overworld%-') and M.desktop_mode() ~= M.current then M.auto() end
      end,
    })
  end
end

return M
