# Overworld Hyprland — kitty hotbar tab bar. Linked to ~/.config/kitty/tab_bar.py by apps/install.sh and used only
# while an Overworld mode file sets `tab_bar_style custom`; with Overworld off kitty ignores this file.
#
# Every tab is a hotbar slot:   ▌ 2 title ▐   — the active slot is drawn with the white selection frame (half blocks
# in the active foreground colour), inactive slots have no frame. Windows beyond the first show as a stack count.
from kitty.fast_data_types import Screen
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb, draw_title
from kitty.utils import color_as_int

FRAME_L, FRAME_R, GAP = '▌', '▐', ' '   # ▌ ▐


def draw_tab(draw_data: DrawData, screen: Screen, tab: TabBarData, before: int, max_title_length: int,
             index: int, is_last: bool, extra_data: ExtraData) -> int:
    bar_bg = as_rgb(color_as_int(draw_data.default_bg))
    slot_bg = as_rgb(draw_data.tab_bg(tab))
    slot_fg = as_rgb(draw_data.tab_fg(tab))
    frame = as_rgb(color_as_int(draw_data.active_fg)) if tab.is_active else slot_bg

    screen.cursor.bold = screen.cursor.italic = False
    screen.cursor.fg, screen.cursor.bg = frame, bar_bg
    screen.draw(FRAME_L)
    screen.cursor.fg, screen.cursor.bg = slot_fg, slot_bg
    screen.cursor.bold = tab.is_active
    inner = max(1, max_title_length - 2 - (2 if tab.num_windows > 1 else 0))
    draw_title(draw_data, screen, tab, index, inner)
    if tab.num_windows > 1:                       # the stack count of the hotbar slot
        screen.cursor.bold = True
        screen.draw(f'×{tab.num_windows} ' if tab.num_windows < 10 else '9+ ')
    screen.cursor.bold = False
    end = screen.cursor.x
    screen.cursor.fg, screen.cursor.bg = frame, bar_bg
    screen.draw(FRAME_R)
    screen.cursor.fg, screen.cursor.bg = 0, 0
    if not is_last:
        screen.draw(GAP)
    return screen.cursor.x if is_last else end + 1
