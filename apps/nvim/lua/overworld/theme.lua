-- Overworld Hyprland — nvim highlight builder. require('overworld.theme').apply(palette)
-- Installed as ~/.local/share/nvim/site/lua/overworld/theme.lua (never touches ~/.config/nvim).
local M = {}

function M.apply(p)
  vim.cmd('highlight clear')
  if vim.fn.exists('syntax_on') == 1 then vim.cmd('syntax reset') end
  vim.o.termguicolors = true
  vim.o.background = p.is_dark and 'dark' or 'light'
  vim.g.colors_name = p.name:gsub('_', '-')

  local dark = p.is_dark
  local c = {
    bg      = p.surface,  bg_alt = p.surfaceAlt, bg0 = p.bg0, bg1 = p.bg1, bg2 = p.bg2,
    fg      = p.text,     muted  = p.textMuted,  dim = p.ink[4],
    frame   = p.frame,    line   = p.hairline,
    accent  = p.accent,   accent_soft = p.accentSoft, gold = p.accent2,
    seal    = p.seal,     err = p.error, warn = p.warning, ok = p.success, info = p.info,
    plum    = p.plum,     jade = p.jade, indigo = p.indigo, herb = p.herb, link = p.link,
    sel     = dark and '#364336' or '#cdd2c0',          -- kitty selection tones (opaque, from tokens kitty.conf)
    cursorline = dark and p.bg2 or p.surfaceAlt,
    menu    = dark and p.bg2 or p.bg1,
  }

  local hl = function(group, spec) vim.api.nvim_set_hl(0, group, spec) end
  local groups = {
    -- editor
    Normal       = { fg = c.fg, bg = c.bg },        NormalNC = { fg = c.fg, bg = c.bg },
    NormalFloat  = { fg = c.fg, bg = c.menu },      FloatBorder = { fg = c.line, bg = c.menu },
    FloatTitle   = { fg = c.gold, bg = c.menu, bold = true },
    Comment      = { fg = c.muted, italic = true },
    LineNr       = { fg = c.dim },                  CursorLineNr = { fg = c.seal, bold = true },
    CursorLine   = { bg = c.cursorline },           CursorColumn = { bg = c.cursorline },
    ColorColumn  = { bg = c.bg_alt },               SignColumn = { fg = c.dim, bg = c.bg },
    FoldColumn   = { fg = c.dim, bg = c.bg },       Folded = { fg = c.muted, bg = c.bg_alt, italic = true },
    Visual       = { bg = c.sel },                  VisualNOS = { bg = c.sel },
    Search       = { fg = c.bg, bg = c.gold },      IncSearch = { fg = p.textOnSeal, bg = c.seal },
    CurSearch    = { fg = p.textOnSeal, bg = c.seal }, Substitute = { fg = p.textOnSeal, bg = c.seal },
    MatchParen   = { fg = c.seal, bold = true, underline = true },
    NonText      = { fg = c.dim },                  Whitespace = { fg = c.line }, EndOfBuffer = { fg = c.bg },
    SpecialKey   = { fg = c.dim },                  Conceal = { fg = c.muted },
    Cursor       = { fg = c.bg, bg = p.cursor },    lCursor = { fg = c.bg, bg = p.cursor }, TermCursor = { fg = c.bg, bg = p.cursor },
    Directory    = { fg = c.accent, bold = true },  Title = { fg = c.gold, bold = true },
    Question     = { fg = c.ok },                   MoreMsg = { fg = c.accent }, ModeMsg = { fg = c.accent, bold = true },
    ErrorMsg     = { fg = c.err, bold = true },     WarningMsg = { fg = c.warn },
    VertSplit    = { fg = c.line },                 WinSeparator = { fg = c.line },
    StatusLine   = { fg = p.titlebarText, bg = p.titlebar }, StatusLineNC = { fg = c.muted, bg = c.bg0 },
    TabLine      = { fg = c.muted, bg = c.bg0 },    TabLineFill = { bg = c.bg0 }, TabLineSel = { fg = p.titlebarText, bg = p.titlebar, bold = true },
    WildMenu     = { fg = c.bg, bg = c.accent },
    Pmenu        = { fg = c.fg, bg = c.menu },      PmenuSel = { fg = c.fg, bg = c.bg_alt, bold = true },
    PmenuSbar    = { bg = c.bg0 },                  PmenuThumb = { bg = c.dim },
    PmenuKind    = { fg = c.gold, bg = c.menu },    PmenuExtra = { fg = c.muted, bg = c.menu },
    QuickFixLine = { bg = c.bg_alt, bold = true },
    SpellBad     = { sp = c.err, undercurl = true }, SpellCap = { sp = c.warn, undercurl = true },
    SpellLocal   = { sp = c.jade, undercurl = true }, SpellRare = { sp = c.plum, undercurl = true },
    DiffAdd      = { bg = dark and '#22301f' or '#dfe6cd' }, DiffChange = { bg = dark and '#2d2a1a' or '#ece2c3' },
    DiffDelete   = { fg = c.err, bg = dark and '#331c17' or '#ecd4cf' }, DiffText = { bg = dark and '#3b3920' or '#e3d2a8', bold = true },
    Added        = { fg = c.ok }, Changed = { fg = c.warn }, Removed = { fg = c.err },
    diffAdded    = { fg = c.ok }, diffRemoved = { fg = c.err }, diffChanged = { fg = c.warn }, diffFile = { fg = c.gold }, diffLine = { fg = c.muted },
    -- syntax (legacy)
    Constant     = { fg = c.plum },                 String = { fg = c.ok },       Character = { fg = c.ok },
    Number       = { fg = c.gold },                 Boolean = { fg = c.gold },    Float = { fg = c.gold },
    Identifier   = { fg = c.fg },                   Function = { fg = c.accent, bold = true },
    Statement    = { fg = c.seal },                 Conditional = { fg = c.seal }, Repeat = { fg = c.seal }, Label = { fg = c.seal },
    Operator     = { fg = c.muted },                Keyword = { fg = c.seal },    Exception = { fg = c.seal },
    PreProc      = { fg = c.plum },                 Include = { fg = c.plum },    Define = { fg = c.plum }, Macro = { fg = c.plum }, PreCondit = { fg = c.plum },
    Type         = { fg = c.indigo },               StorageClass = { fg = c.indigo }, Structure = { fg = c.indigo }, Typedef = { fg = c.indigo },
    Special      = { fg = c.jade },                 SpecialChar = { fg = c.jade }, Tag = { fg = c.accent }, Delimiter = { fg = c.muted },
    SpecialComment = { fg = c.muted, bold = true }, Debug = { fg = c.warn },
    Underlined   = { fg = c.link, underline = true }, Ignore = { fg = c.dim }, Error = { fg = c.err, bold = true }, Todo = { fg = p.textOnSeal, bg = c.seal, bold = true },
    -- treesitter
    ['@variable'] = { fg = c.fg },                  ['@variable.builtin'] = { fg = c.plum, italic = true },
    ['@variable.parameter'] = { fg = c.fg, italic = true }, ['@variable.member'] = { fg = c.jade },
    ['@constant'] = { fg = c.plum }, ['@constant.builtin'] = { fg = c.gold }, ['@constant.macro'] = { fg = c.plum },
    ['@module'] = { fg = c.indigo }, ['@label'] = { fg = c.seal },
    ['@string'] = { fg = c.ok }, ['@string.escape'] = { fg = c.jade }, ['@string.regexp'] = { fg = c.warn }, ['@string.special'] = { fg = c.jade },
    ['@string.special.url'] = { fg = c.link, underline = true },
    ['@character'] = { fg = c.ok }, ['@number'] = { fg = c.gold }, ['@boolean'] = { fg = c.gold }, ['@number.float'] = { fg = c.gold },
    ['@type'] = { fg = c.indigo }, ['@type.builtin'] = { fg = c.indigo, italic = true }, ['@type.definition'] = { fg = c.indigo },
    ['@attribute'] = { fg = c.plum }, ['@property'] = { fg = c.jade },
    ['@function'] = { fg = c.accent, bold = true }, ['@function.builtin'] = { fg = c.accent }, ['@function.call'] = { fg = c.accent },
    ['@function.macro'] = { fg = c.plum }, ['@function.method'] = { fg = c.accent }, ['@function.method.call'] = { fg = c.accent },
    ['@constructor'] = { fg = c.indigo }, ['@operator'] = { fg = c.muted },
    ['@keyword'] = { fg = c.seal }, ['@keyword.function'] = { fg = c.seal }, ['@keyword.operator'] = { fg = c.seal },
    ['@keyword.import'] = { fg = c.plum }, ['@keyword.return'] = { fg = c.seal, italic = true }, ['@keyword.conditional'] = { fg = c.seal },
    ['@keyword.repeat'] = { fg = c.seal }, ['@keyword.exception'] = { fg = c.seal }, ['@keyword.directive'] = { fg = c.plum },
    ['@punctuation.delimiter'] = { fg = c.muted }, ['@punctuation.bracket'] = { fg = c.muted }, ['@punctuation.special'] = { fg = c.jade },
    ['@comment'] = { fg = c.muted, italic = true }, ['@comment.documentation'] = { fg = c.muted },
    ['@comment.todo'] = { fg = p.textOnSeal, bg = c.seal, bold = true }, ['@comment.note'] = { fg = c.bg, bg = c.accent, bold = true },
    ['@comment.warning'] = { fg = c.bg, bg = c.warn, bold = true }, ['@comment.error'] = { fg = p.textOnSeal, bg = c.err, bold = true },
    ['@markup.heading'] = { fg = c.gold, bold = true }, ['@markup.heading.1'] = { fg = c.seal, bold = true }, ['@markup.heading.2'] = { fg = c.gold, bold = true },
    ['@markup.strong'] = { bold = true }, ['@markup.italic'] = { italic = true }, ['@markup.strikethrough'] = { strikethrough = true },
    ['@markup.underline'] = { underline = true }, ['@markup.quote'] = { fg = c.muted, italic = true },
    ['@markup.link'] = { fg = c.link }, ['@markup.link.url'] = { fg = c.link, underline = true }, ['@markup.link.label'] = { fg = c.accent },
    ['@markup.raw'] = { fg = c.ok }, ['@markup.list'] = { fg = c.seal }, ['@markup.list.checked'] = { fg = c.ok }, ['@markup.list.unchecked'] = { fg = c.muted },
    ['@tag'] = { fg = c.seal }, ['@tag.attribute'] = { fg = c.jade }, ['@tag.delimiter'] = { fg = c.muted },
    ['@diff.plus'] = { fg = c.ok }, ['@diff.minus'] = { fg = c.err }, ['@diff.delta'] = { fg = c.warn },
    -- LSP
    ['@lsp.type.class'] = { link = '@type' }, ['@lsp.type.enum'] = { link = '@type' }, ['@lsp.type.interface'] = { link = '@type' },
    ['@lsp.type.namespace'] = { link = '@module' }, ['@lsp.type.parameter'] = { link = '@variable.parameter' },
    ['@lsp.type.property'] = { link = '@property' }, ['@lsp.type.variable'] = { link = '@variable' },
    ['@lsp.type.function'] = { link = '@function' }, ['@lsp.type.method'] = { link = '@function.method' }, ['@lsp.type.keyword'] = { link = '@keyword' },
    LspReferenceText  = { bg = c.bg_alt }, LspReferenceRead = { bg = c.bg_alt }, LspReferenceWrite = { bg = c.bg_alt, underline = true },
    LspInlayHint      = { fg = c.dim, bg = c.bg_alt, italic = true }, LspCodeLens = { fg = c.dim, italic = true },
    LspSignatureActiveParameter = { fg = c.seal, bold = true },
    DiagnosticError = { fg = c.err }, DiagnosticWarn = { fg = c.warn }, DiagnosticInfo = { fg = c.indigo }, DiagnosticHint = { fg = c.jade }, DiagnosticOk = { fg = c.ok },
    DiagnosticUnderlineError = { sp = c.err, undercurl = true }, DiagnosticUnderlineWarn = { sp = c.warn, undercurl = true },
    DiagnosticUnderlineInfo = { sp = c.indigo, undercurl = true }, DiagnosticUnderlineHint = { sp = c.jade, undercurl = true },
    DiagnosticVirtualTextError = { fg = c.err, bg = dark and '#331c17' or '#ecd4cf', italic = true },
    DiagnosticVirtualTextWarn = { fg = c.warn, bg = dark and '#33291a' or '#ece2c3', italic = true },
    DiagnosticVirtualTextInfo = { fg = c.indigo, bg = c.bg_alt, italic = true }, DiagnosticVirtualTextHint = { fg = c.jade, bg = c.bg_alt, italic = true },
    DiagnosticSignError = { fg = c.err }, DiagnosticSignWarn = { fg = c.warn }, DiagnosticSignInfo = { fg = c.indigo }, DiagnosticSignHint = { fg = c.jade },
    DiagnosticUnnecessary = { fg = c.muted, undercurl = false },
    -- common plugins
    GitSignsAdd = { fg = c.ok }, GitSignsChange = { fg = c.warn }, GitSignsDelete = { fg = c.err },
    TelescopeBorder = { fg = c.line, bg = c.menu }, TelescopeNormal = { fg = c.fg, bg = c.menu }, TelescopeSelection = { bg = c.bg_alt, bold = true },
    TelescopeMatching = { fg = c.seal, bold = true }, TelescopePromptPrefix = { fg = c.seal }, TelescopeTitle = { fg = c.gold, bold = true },
    NeoTreeNormal = { fg = c.fg, bg = c.bg1 }, NeoTreeNormalNC = { fg = c.fg, bg = c.bg1 }, NvimTreeNormal = { fg = c.fg, bg = c.bg1 },
    NvimTreeFolderIcon = { fg = c.gold }, NvimTreeRootFolder = { fg = c.seal, bold = true }, NeoTreeDirectoryIcon = { fg = c.gold }, NeoTreeRootName = { fg = c.seal, bold = true },
    WhichKey = { fg = c.seal }, WhichKeyGroup = { fg = c.accent }, WhichKeyDesc = { fg = c.fg }, WhichKeySeparator = { fg = c.muted },
    IndentBlanklineChar = { fg = c.line }, IblIndent = { fg = c.line }, IblScope = { fg = c.dim },
    CmpItemAbbrMatch = { fg = c.seal, bold = true }, CmpItemAbbrMatchFuzzy = { fg = c.seal }, CmpItemKind = { fg = c.gold }, CmpItemMenu = { fg = c.muted },
    LazyNormal = { fg = c.fg, bg = c.menu }, MasonNormal = { fg = c.fg, bg = c.menu },
    NotifyBackground = { bg = c.menu }, NoiceCmdlinePopupBorder = { fg = c.line },
    MiniStatuslineModeNormal = { fg = p.titlebarText, bg = p.titlebar, bold = true }, MiniStatuslineModeInsert = { fg = p.textOnAccent, bg = c.accent, bold = true },
    MiniStatuslineModeVisual = { fg = p.textOnSeal, bg = c.plum, bold = true }, MiniStatuslineModeReplace = { fg = p.textOnSeal, bg = c.seal, bold = true },
  }
  for g, s in pairs(groups) do hl(g, s) end

  -- terminal palette (ANSI 0–15 from tokens)
  for i = 0, 15 do vim.g['terminal_color_' .. i] = p.ansi[i + 1] end
end

return M
