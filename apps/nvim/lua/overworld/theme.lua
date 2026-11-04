-- Overworld Hyprland — nvim highlight builder.  require('overworld.theme').apply(palette, 'day'|'night')
-- Installed as ~/.local/share/nvim/site/lua/overworld/theme.lua (never touches ~/.config/nvim).
--
-- Colour model: Minecraft chat colours for syntax (green strings, gold numbers, aqua functions, purple keywords,
-- red errors, yellow warnings). Day uses the chat colours darkened until every syntax colour reaches >= 4.5:1
-- on every background it can appear on; Night uses them brightened the same way (no-op for the bright chat colours).
local M = {}

-- ---------------------------------------------------------------- colour maths
local function rgb(h) h = h:gsub('^#', ''); return tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16) end
local function hex(r, g, b) return string.format('#%02x%02x%02x', math.floor(r + .5), math.floor(g + .5), math.floor(b + .5)) end
local function lin(v) v = v / 255; return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
local function lum(h) local r, g, b = rgb(h); return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b) end
function M.contrast(a, b)
  local la, lb = lum(a), lum(b)
  if la < lb then la, lb = lb, la end
  return (la + 0.05) / (lb + 0.05)
end
local function mix(a, b, t)   -- t = 0 -> a, 1 -> b
  local ar, ag, ab = rgb(a); local br, bg, bb = rgb(b)
  return hex(ar + (br - ar) * t, ag + (bg - ag) * t, ab + (bb - ab) * t)
end
-- Move `fg` toward `target` (black in Day, white in Night) until it reaches `min` against every bg in `bgs`.
local function ensure(fg, bgs, min, target)
  local function ok(c) for _, b in ipairs(bgs) do if M.contrast(c, b) < min then return false end end return true end
  if ok(fg) then return fg end
  for i = 1, 40 do
    local c = mix(fg, target, i / 40)
    if ok(c) then return c end
  end
  return target
end
M.ensure = ensure

-- ---------------------------------------------------------------- builder
function M.apply(p, mode)
  vim.cmd('highlight clear')
  if vim.fn.exists('syntax_on') == 1 then vim.cmd('syntax reset') end
  vim.o.termguicolors = true
  local dark = p.is_dark and true or false
  mode = mode or (dark and 'night' or 'day')
  vim.o.background = dark and 'dark' or 'light'
  vim.g.colors_name = 'overworld-' .. mode

  -- backgrounds ---------------------------------------------------------------
  local bg       = p.bg0                                  -- Day #c6c6c6 / Night #141418
  local bg_alt   = dark and p.slot or p.surfaceAlt          -- raised / hovered
  local cursorln = dark and p.bg2 or '#cfcfcf'
  local visual   = dark and '#183a18' or '#a9d49c'        -- grass-tinted selection
  local float    = dark and p.tooltipFill or p.bg2        -- Night floats = Minecraft tooltip, Day floats = light panel
  local float_bd = dark and '#5000ff' or p.frame          -- tooltip purple border / dark frame
  local tint = {                                          -- diff / diagnostic line tints
    add    = dark and '#10260f' or '#b3dba6',
    change = dark and '#2a280a' or '#e0d79a',
    delete = dark and '#2e0f0f' or '#e3b0ab',
    text   = dark and '#403e0e' or '#d0c36b',
  }
  local all_bgs = { bg, bg_alt, cursorln, visual, float, tint.add, tint.change, tint.delete, tint.text, p.bg1, p.bg2 }
  local target = dark and '#ffffff' or '#000000'
  local function sx(color) return ensure(color, all_bgs, 4.6, target) end   -- syntax colour, guaranteed >= 4.5:1

  -- foreground roles (chat colours; Day = the dark variants) -------------------
  local function pick(day_c, night_c) return sx(dark and night_c or day_c) end
  local c = {
    fg      = p.text,
    muted   = p.textMuted,                                                  -- comments / punctuation
    dim     = sx(dark and '#8b8b95' or '#555555'),                          -- line numbers etc.
    line    = p.hairline,
    string  = pick(p.chatDarkGreen, p.chatGreen),
    number  = pick(p.chatGold, p.chatGold),
    func    = pick(p.chatDarkAqua, p.chatAqua),
    keyword = pick(p.chatDarkPurple, p.chatLightPurple),
    type    = pick(p.chatDarkBlue, p.chatBlue),
    const   = pick(p.lava, p.lava),
    member  = pick(p.water, p.water),
    special = pick(p.enchant, p.enchantGlint),
    err     = pick(p.chatDarkRed, p.chatRed),
    warn    = pick(p.chatGold, p.chatYellow),
    info    = pick(p.chatDarkBlue, p.chatAqua),
    hint    = pick(p.chatDarkAqua, p.chatAqua),
    ok      = pick(p.chatDarkGreen, p.chatGreen),
    link    = sx(p.link),
    xp      = pick(p.chatDarkGreen, p.xp),
    accent  = dark and p.accent or p.accent,                                -- Day #245018 / Night #55ff55
  }
  local on_dark_text = '#ffffff'

  local hl = function(group, spec) vim.api.nvim_set_hl(0, group, spec) end
  local groups = {
    -- editor ---------------------------------------------------------------
    Normal       = { fg = c.fg, bg = bg },           NormalNC = { fg = c.fg, bg = bg },
    NormalFloat  = { fg = dark and on_dark_text or c.fg, bg = float },
    FloatBorder  = { fg = float_bd, bg = float },
    FloatTitle   = { fg = dark and p.toastTitle or c.fg, bg = float, bold = true },
    FloatFooter  = { fg = c.muted, bg = float },
    Comment      = { fg = c.muted, italic = true },
    LineNr       = { fg = c.dim },                   LineNrAbove = { fg = c.dim }, LineNrBelow = { fg = c.dim },
    CursorLineNr = { fg = dark and p.chatGold or '#6b4800', bold = true },
    CursorLine   = { bg = cursorln },                CursorColumn = { bg = cursorln },
    CursorLineSign = { bg = cursorln },              CursorLineFold = { bg = cursorln },
    ColorColumn  = { bg = bg_alt },                  SignColumn = { fg = c.dim, bg = bg },
    FoldColumn   = { fg = c.dim, bg = bg },          Folded = { fg = c.muted, bg = bg_alt, italic = true },
    Visual       = { bg = visual },                  VisualNOS = { bg = visual },
    Search       = { fg = '#000000', bg = dark and '#a8a83a' or p.chatYellow },
    IncSearch    = { fg = '#000000', bg = p.chatGold },
    CurSearch    = { fg = '#000000', bg = p.chatGold, bold = true },
    Substitute   = { fg = '#000000', bg = p.chatRed },
    MatchParen   = { fg = c.keyword, bold = true, underline = true },
    NonText      = { fg = c.dim },                   Whitespace = { fg = c.line }, EndOfBuffer = { fg = bg },
    SpecialKey   = { fg = c.dim },                   Conceal = { fg = c.muted },
    Cursor       = { fg = bg, bg = p.cursor },       lCursor = { fg = bg, bg = p.cursor }, TermCursor = { fg = bg, bg = p.cursor },
    CursorIM     = { fg = bg, bg = p.cursor },
    Directory    = { fg = c.func, bold = true },     Title = { fg = c.number, bold = true },
    Question     = { fg = c.ok },                    MoreMsg = { fg = c.ok }, ModeMsg = { fg = c.fg, bold = true },
    ErrorMsg     = { fg = c.err, bold = true },      WarningMsg = { fg = c.warn },
    VertSplit    = { fg = dark and p.hairline or p.frame }, WinSeparator = { fg = dark and p.hairline or p.frame },
    -- Minecraft GUI chrome: dark title-bar strip with white text, like the window frame of the desktop
    StatusLine   = { fg = p.titlebarText, bg = p.titlebar },        StatusLineNC = { fg = c.muted, bg = bg_alt },
    StatusLineTerm = { fg = p.titlebarText, bg = p.titlebar },      StatusLineTermNC = { fg = c.muted, bg = bg_alt },
    WinBar       = { fg = c.fg, bg = bg, bold = true },             WinBarNC = { fg = c.muted, bg = bg },
    TabLine      = { fg = c.muted, bg = bg_alt },    TabLineFill = { bg = p.bg2 },
    TabLineSel   = { fg = p.titlebarText, bg = p.titlebar, bold = true },
    WildMenu     = { fg = '#000000', bg = p.chatGreen },
    Pmenu        = { fg = dark and on_dark_text or c.fg, bg = float },
    PmenuSel     = { fg = '#ffffff', bg = dark and '#28007f' or '#245018', bold = true },
    PmenuSbar    = { bg = bg_alt },                  PmenuThumb = { bg = dark and '#8b8b8b' or p.frame },
    PmenuKind    = { fg = c.func, bg = float },      PmenuKindSel = { fg = '#ffffff', bg = dark and '#28007f' or '#245018' },
    PmenuExtra   = { fg = c.muted, bg = float },     PmenuExtraSel = { fg = '#dddddd', bg = dark and '#28007f' or '#245018' },
    PmenuMatch   = { fg = c.number, bg = float, bold = true },
    QuickFixLine = { bg = visual, bold = true },
    SpellBad     = { sp = c.err, undercurl = true }, SpellCap = { sp = c.warn, undercurl = true },
    SpellLocal   = { sp = c.hint, undercurl = true }, SpellRare = { sp = c.special, undercurl = true },
    Added        = { fg = c.ok }, Changed = { fg = c.warn }, Removed = { fg = c.err },
    DiffAdd      = { bg = tint.add },   DiffChange = { bg = tint.change },
    DiffDelete   = { fg = c.err, bg = tint.delete }, DiffText = { bg = tint.text, bold = true },
    diffAdded    = { fg = c.ok }, diffRemoved = { fg = c.err }, diffChanged = { fg = c.warn },
    diffFile     = { fg = c.number }, diffLine = { fg = c.muted }, diffIndexLine = { fg = c.muted },
    -- legacy syntax (what you get without Treesitter) ---------------------------
    Constant     = { fg = c.const },                 String = { fg = c.string },   Character = { fg = c.string },
    Number       = { fg = c.number },                Boolean = { fg = c.number },  Float = { fg = c.number },
    Identifier   = { fg = c.fg },                    Function = { fg = c.func },
    Statement    = { fg = c.keyword },               Conditional = { fg = c.keyword }, Repeat = { fg = c.keyword }, Label = { fg = c.keyword },
    Operator     = { fg = c.muted },                 Keyword = { fg = c.keyword }, Exception = { fg = c.keyword },
    PreProc      = { fg = c.special },               Include = { fg = c.special }, Define = { fg = c.special }, Macro = { fg = c.special }, PreCondit = { fg = c.special },
    Type         = { fg = c.type },                  StorageClass = { fg = c.type }, Structure = { fg = c.type }, Typedef = { fg = c.type },
    Special      = { fg = c.special },               SpecialChar = { fg = c.special }, Tag = { fg = c.func }, Delimiter = { fg = c.muted },
    SpecialComment = { fg = c.muted, bold = true },  Debug = { fg = c.warn },
    Underlined   = { fg = c.link, underline = true }, Ignore = { fg = c.dim },
    Error        = { fg = c.err, bold = true },      Todo = { fg = '#000000', bg = p.chatYellow, bold = true },
    -- treesitter ---------------------------------------------------------------
    ['@variable'] = { fg = c.fg },                   ['@variable.builtin'] = { fg = c.const, italic = true },
    ['@variable.parameter'] = { fg = c.fg, italic = true }, ['@variable.parameter.builtin'] = { fg = c.const, italic = true },
    ['@variable.member'] = { fg = c.member },
    ['@constant'] = { fg = c.const }, ['@constant.builtin'] = { fg = c.number }, ['@constant.macro'] = { fg = c.special },
    ['@module'] = { fg = c.type }, ['@module.builtin'] = { fg = c.type, italic = true }, ['@label'] = { fg = c.keyword },
    ['@string'] = { fg = c.string }, ['@string.escape'] = { fg = c.special }, ['@string.regexp'] = { fg = c.warn },
    ['@string.special'] = { fg = c.special }, ['@string.special.url'] = { fg = c.link, underline = true },
    ['@string.special.symbol'] = { fg = c.special }, ['@string.documentation'] = { fg = c.string, italic = true },
    ['@character'] = { fg = c.string }, ['@character.special'] = { fg = c.special },
    ['@number'] = { fg = c.number }, ['@boolean'] = { fg = c.number }, ['@number.float'] = { fg = c.number },
    ['@type'] = { fg = c.type }, ['@type.builtin'] = { fg = c.type, italic = true }, ['@type.definition'] = { fg = c.type },
    ['@attribute'] = { fg = c.special }, ['@attribute.builtin'] = { fg = c.special, italic = true }, ['@property'] = { fg = c.member },
    ['@function'] = { fg = c.func }, ['@function.builtin'] = { fg = c.func, italic = true }, ['@function.call'] = { fg = c.func },
    ['@function.macro'] = { fg = c.special }, ['@function.method'] = { fg = c.func }, ['@function.method.call'] = { fg = c.func },
    ['@constructor'] = { fg = c.type }, ['@operator'] = { fg = c.muted },
    ['@keyword'] = { fg = c.keyword }, ['@keyword.function'] = { fg = c.keyword }, ['@keyword.operator'] = { fg = c.keyword },
    ['@keyword.import'] = { fg = c.special }, ['@keyword.return'] = { fg = c.keyword, italic = true },
    ['@keyword.conditional'] = { fg = c.keyword }, ['@keyword.repeat'] = { fg = c.keyword },
    ['@keyword.exception'] = { fg = c.keyword }, ['@keyword.directive'] = { fg = c.special },
    ['@keyword.modifier'] = { fg = c.keyword }, ['@keyword.type'] = { fg = c.keyword }, ['@keyword.coroutine'] = { fg = c.keyword },
    ['@punctuation.delimiter'] = { fg = c.muted }, ['@punctuation.bracket'] = { fg = c.muted }, ['@punctuation.special'] = { fg = c.special },
    ['@comment'] = { fg = c.muted, italic = true }, ['@comment.documentation'] = { fg = c.muted },
    ['@comment.todo'] = { fg = '#000000', bg = p.chatYellow, bold = true },
    ['@comment.note'] = { fg = '#ffffff', bg = dark and '#00007a' or p.chatDarkBlue, bold = true },
    ['@comment.warning'] = { fg = '#000000', bg = p.chatGold, bold = true },
    ['@comment.error'] = { fg = '#ffffff', bg = dark and '#aa0000' or p.chatDarkRed, bold = true },
    ['@markup.heading'] = { fg = c.number, bold = true }, ['@markup.heading.1'] = { fg = c.keyword, bold = true },
    ['@markup.heading.2'] = { fg = c.number, bold = true }, ['@markup.heading.3'] = { fg = c.func, bold = true },
    ['@markup.strong'] = { bold = true }, ['@markup.italic'] = { italic = true }, ['@markup.strikethrough'] = { strikethrough = true },
    ['@markup.underline'] = { underline = true }, ['@markup.quote'] = { fg = c.muted, italic = true },
    ['@markup.link'] = { fg = c.link }, ['@markup.link.url'] = { fg = c.link, underline = true }, ['@markup.link.label'] = { fg = c.func },
    ['@markup.raw'] = { fg = c.string }, ['@markup.raw.block'] = { fg = c.string },
    ['@markup.list'] = { fg = c.keyword }, ['@markup.list.checked'] = { fg = c.ok }, ['@markup.list.unchecked'] = { fg = c.muted },
    ['@tag'] = { fg = c.keyword }, ['@tag.attribute'] = { fg = c.member }, ['@tag.delimiter'] = { fg = c.muted },
    ['@diff.plus'] = { fg = c.ok }, ['@diff.minus'] = { fg = c.err }, ['@diff.delta'] = { fg = c.warn },
    -- LSP semantic tokens + references ---------------------------------------------------
    ['@lsp.type.class'] = { link = '@type' }, ['@lsp.type.enum'] = { link = '@type' }, ['@lsp.type.interface'] = { link = '@type' },
    ['@lsp.type.struct'] = { link = '@type' }, ['@lsp.type.type'] = { link = '@type' }, ['@lsp.type.typeParameter'] = { link = '@type' },
    ['@lsp.type.namespace'] = { link = '@module' }, ['@lsp.type.parameter'] = { link = '@variable.parameter' },
    ['@lsp.type.property'] = { link = '@property' }, ['@lsp.type.variable'] = { link = '@variable' },
    ['@lsp.type.function'] = { link = '@function' }, ['@lsp.type.method'] = { link = '@function.method' },
    ['@lsp.type.macro'] = { link = '@function.macro' }, ['@lsp.type.decorator'] = { link = '@attribute' },
    ['@lsp.type.enumMember'] = { link = '@constant' }, ['@lsp.type.keyword'] = { link = '@keyword' },
    ['@lsp.type.comment'] = { link = '@comment' }, ['@lsp.type.string'] = { link = '@string' },
    ['@lsp.type.number'] = { link = '@number' }, ['@lsp.type.operator'] = { link = '@operator' },
    ['@lsp.mod.deprecated'] = { strikethrough = true }, ['@lsp.mod.readonly'] = { link = '@constant' },
    LspReferenceText  = { bg = bg_alt }, LspReferenceRead = { bg = bg_alt }, LspReferenceWrite = { bg = bg_alt, underline = true },
    LspReferenceTarget = { bg = bg_alt },
    LspInlayHint = { fg = c.dim, bg = bg_alt, italic = true }, LspCodeLens = { fg = c.dim, italic = true },
    LspCodeLensSeparator = { fg = c.dim }, LspSignatureActiveParameter = { fg = c.number, bold = true, underline = true },
    -- diagnostics ------------------------------------------------------------------------
    DiagnosticError = { fg = c.err }, DiagnosticWarn = { fg = c.warn }, DiagnosticInfo = { fg = c.info },
    DiagnosticHint = { fg = c.hint }, DiagnosticOk = { fg = c.ok },
    DiagnosticUnderlineError = { sp = c.err, undercurl = true }, DiagnosticUnderlineWarn = { sp = c.warn, undercurl = true },
    DiagnosticUnderlineInfo = { sp = c.info, undercurl = true }, DiagnosticUnderlineHint = { sp = c.hint, undercurl = true },
    DiagnosticUnderlineOk = { sp = c.ok, undercurl = true },
    DiagnosticVirtualTextError = { fg = c.err, bg = tint.delete, italic = true },
    DiagnosticVirtualTextWarn  = { fg = c.warn, bg = tint.change, italic = true },
    DiagnosticVirtualTextInfo  = { fg = c.info, bg = bg_alt, italic = true },
    DiagnosticVirtualTextHint  = { fg = c.hint, bg = bg_alt, italic = true },
    DiagnosticVirtualTextOk    = { fg = c.ok, bg = tint.add, italic = true },
    DiagnosticSignError = { fg = c.err }, DiagnosticSignWarn = { fg = c.warn }, DiagnosticSignInfo = { fg = c.info },
    DiagnosticSignHint = { fg = c.hint }, DiagnosticSignOk = { fg = c.ok },
    DiagnosticFloatingError = { fg = c.err }, DiagnosticFloatingWarn = { fg = c.warn },
    DiagnosticFloatingInfo = { fg = c.info }, DiagnosticFloatingHint = { fg = c.hint }, DiagnosticFloatingOk = { fg = c.ok },
    DiagnosticUnnecessary = { fg = c.muted }, DiagnosticDeprecated = { strikethrough = true },
    -- GitSigns / fugitive ---------------------------------------------------------------------
    GitSignsAdd = { fg = c.ok }, GitSignsChange = { fg = c.warn }, GitSignsDelete = { fg = c.err },
    GitSignsAddNr = { fg = c.ok }, GitSignsChangeNr = { fg = c.warn }, GitSignsDeleteNr = { fg = c.err },
    GitSignsAddInline = { bg = tint.add }, GitSignsDeleteInline = { bg = tint.delete }, GitSignsChangeInline = { bg = tint.change },
    GitSignsCurrentLineBlame = { fg = c.dim, italic = true },
    -- Telescope -----------------------------------------------------------------------------------
    TelescopeNormal = { fg = dark and on_dark_text or c.fg, bg = float }, TelescopeBorder = { fg = float_bd, bg = float },
    TelescopeTitle = { fg = c.number, bold = true }, TelescopeSelection = { fg = '#ffffff', bg = dark and '#28007f' or '#245018', bold = true },
    TelescopeSelectionCaret = { fg = c.number }, TelescopeMultiSelection = { fg = c.special },
    TelescopeMatching = { fg = c.number, bold = true }, TelescopePromptPrefix = { fg = c.func },
    TelescopePromptNormal = { fg = dark and p.fieldText or c.fg, bg = dark and p.fieldFill or p.bg1 },
    TelescopePromptBorder = { fg = dark and p.fieldBorder or p.frame, bg = dark and p.fieldFill or p.bg1 },
    TelescopePromptTitle = { fg = c.number, bold = true }, TelescopeResultsTitle = { fg = c.number, bold = true },
    TelescopePreviewTitle = { fg = c.number, bold = true },
    -- NeoTree / NvimTree ------------------------------------------------------------------------------
    NeoTreeNormal = { fg = c.fg, bg = p.bg1 }, NeoTreeNormalNC = { fg = c.fg, bg = p.bg1 },
    NeoTreeDirectoryIcon = { fg = c.number }, NeoTreeDirectoryName = { fg = c.fg }, NeoTreeRootName = { fg = c.keyword, bold = true },
    NeoTreeGitAdded = { fg = c.ok }, NeoTreeGitModified = { fg = c.warn }, NeoTreeGitDeleted = { fg = c.err },
    NeoTreeGitUntracked = { fg = c.special }, NeoTreeGitIgnored = { fg = c.dim }, NeoTreeDotfile = { fg = c.dim },
    NeoTreeIndentMarker = { fg = c.line }, NeoTreeWinSeparator = { fg = c.line, bg = p.bg1 },
    NvimTreeNormal = { fg = c.fg, bg = p.bg1 }, NvimTreeFolderIcon = { fg = c.number },
    NvimTreeRootFolder = { fg = c.keyword, bold = true }, NvimTreeFolderName = { fg = c.fg },
    NvimTreeOpenedFolderName = { fg = c.fg, bold = true }, NvimTreeIndentMarker = { fg = c.line },
    -- WhichKey --------------------------------------------------------------------------------------------
    WhichKey = { fg = c.keyword }, WhichKeyGroup = { fg = c.func }, WhichKeyDesc = { fg = c.fg },
    WhichKeySeparator = { fg = c.muted }, WhichKeyValue = { fg = c.muted }, WhichKeyNormal = { fg = c.fg, bg = float },
    WhichKeyBorder = { fg = float_bd, bg = float }, WhichKeyIcon = { fg = c.func },
    -- indent-blankline ------------------------------------------------------------------------------------
    IndentBlanklineChar = { fg = p.hairline }, IblIndent = { fg = dark and '#31313a' or '#a8a8a8' },
    IblScope = { fg = dark and '#8b8b95' or '#555555' }, IblWhitespace = { fg = p.hairline },
    -- nvim-cmp / blink --------------------------------------------------------------------------------------
    CmpItemAbbr = { fg = dark and on_dark_text or c.fg }, CmpItemAbbrDeprecated = { fg = c.dim, strikethrough = true },
    CmpItemAbbrMatch = { fg = c.number, bold = true }, CmpItemAbbrMatchFuzzy = { fg = c.number },
    CmpItemMenu = { fg = c.muted }, CmpItemKind = { fg = c.func },
    CmpItemKindFunction = { link = '@function' }, CmpItemKindMethod = { link = '@function.method' },
    CmpItemKindVariable = { link = '@variable' }, CmpItemKindKeyword = { link = '@keyword' },
    CmpItemKindClass = { link = '@type' }, CmpItemKindStruct = { link = '@type' }, CmpItemKindInterface = { link = '@type' },
    CmpItemKindModule = { link = '@module' }, CmpItemKindProperty = { link = '@property' }, CmpItemKindField = { link = '@property' },
    CmpItemKindConstant = { link = '@constant' }, CmpItemKindSnippet = { fg = c.special },
    CmpItemKindText = { fg = c.string }, CmpItemKindFile = { fg = c.number }, CmpItemKindFolder = { fg = c.number },
    BlinkCmpMenu = { fg = c.fg, bg = float }, BlinkCmpMenuBorder = { fg = float_bd, bg = float },
    BlinkCmpMenuSelection = { fg = '#ffffff', bg = dark and '#28007f' or '#245018' },
    BlinkCmpLabelMatch = { fg = c.number, bold = true }, BlinkCmpDoc = { fg = c.fg, bg = float },
    BlinkCmpDocBorder = { fg = float_bd, bg = float },
    -- Lazy / Mason / notify / noice ------------------------------------------------------------------------------
    LazyNormal = { fg = dark and on_dark_text or c.fg, bg = float }, LazyButton = { fg = c.fg, bg = bg_alt },
    LazyButtonActive = { fg = '#ffffff', bg = dark and '#28007f' or '#245018', bold = true },
    LazyH1 = { fg = '#ffffff', bg = dark and '#28007f' or '#245018', bold = true }, LazyH2 = { fg = c.number, bold = true },
    LazyComment = { fg = c.muted }, LazySpecial = { fg = c.func }, LazyProp = { fg = c.muted },
    LazyCommit = { fg = c.string }, LazyCommitType = { fg = c.keyword }, LazyReasonPlugin = { fg = c.number },
    LazyReasonCmd = { fg = c.func }, LazyReasonEvent = { fg = c.special }, LazyReasonFt = { fg = c.keyword },
    LazyDimmed = { fg = c.dim }, LazyProgressDone = { fg = c.xp }, LazyProgressTodo = { fg = c.dim },
    MasonNormal = { fg = dark and on_dark_text or c.fg, bg = float }, MasonHeader = { fg = '#ffffff', bg = dark and '#28007f' or '#245018', bold = true },
    MasonHighlight = { fg = c.func }, MasonMuted = { fg = c.muted },
    NotifyBackground = { bg = float },
    NotifyERRORBorder = { fg = c.err }, NotifyWARNBorder = { fg = c.warn }, NotifyINFOBorder = { fg = c.info },
    NotifyDEBUGBorder = { fg = c.dim }, NotifyTRACEBorder = { fg = c.special },
    NotifyERRORTitle = { fg = c.err }, NotifyWARNTitle = { fg = c.warn }, NotifyINFOTitle = { fg = c.info },
    NotifyERRORIcon = { fg = c.err }, NotifyWARNIcon = { fg = c.warn }, NotifyINFOIcon = { fg = c.info },
    NoiceCmdlinePopup = { fg = dark and p.fieldText or c.fg, bg = dark and p.fieldFill or float },
    NoiceCmdlinePopupBorder = { fg = dark and p.fieldBorder or p.frame }, NoiceCmdlineIcon = { fg = c.func },
    -- mini.statusline / lualine fallbacks -------------------------------------------------------------------------------
    MiniStatuslineModeNormal = { fg = '#000000', bg = p.accentSoft, bold = true },
    MiniStatuslineModeInsert = { fg = '#000000', bg = p.chatAqua, bold = true },
    MiniStatuslineModeVisual = { fg = '#000000', bg = p.enchantGlint, bold = true },
    MiniStatuslineModeReplace = { fg = '#000000', bg = p.lava, bold = true },
    MiniStatuslineModeCommand = { fg = '#000000', bg = p.chatGold, bold = true },
    MiniStatuslineDevinfo = { fg = p.titlebarText, bg = p.slotDark }, MiniStatuslineFilename = { fg = p.titlebarText, bg = p.titlebar },
    MiniStatuslineFileinfo = { fg = p.titlebarText, bg = p.slotDark }, MiniStatuslineInactive = { fg = c.muted, bg = bg_alt },
  }
  for g, s in pairs(groups) do hl(g, s) end

  -- terminal palette (ANSI 0-15 from tokens)
  for i = 0, 15 do vim.g['terminal_color_' .. i] = p.ansi[i + 1] end
  M.colors = c   -- exposed for tests / statusline plugins
end

return M
