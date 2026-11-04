"""Overworld cursor art — original pixel art on a 16x16 grid (white fill, auto dark outline, light-grey edge shading).

Each cursor = (frames, hotspot) with frames a list of 16x16 RGBA PIL images and hotspot (x, y) in grid pixels.
build_cursor.py scales the grid to 24/32/48 px with nearest-neighbour and writes Xcursor + hyprcursor themes.
"""
import math

from PIL import Image, ImageDraw

CLEAR = (0, 0, 0, 0)
WHITE, SHADE, OUTLINE = (255, 255, 255, 255), (186, 190, 208, 255), (16, 16, 22, 255)
RED, REDSHADE = (226, 58, 52, 255), (150, 30, 28, 255)
GOLD, GREEN, BLUE = (240, 200, 70, 255), (110, 200, 80, 255), (90, 160, 235, 255)
G = 16


# ----------------------------------------------------------------------------------------------- helpers
def blank():
    return Image.new("RGBA", (G, G), CLEAR)


def from_rows(rows, ox=1, oy=1, pal=None, img=None):
    img = img or blank()
    pal = pal or {"w": WHITE, "g": SHADE, "r": RED, "o": OUTLINE, "y": GOLD, "b": BLUE, "n": GREEN}
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in pal and 0 <= ox + x < G and 0 <= oy + y < G:
                img.putpixel((ox + x, oy + y), pal[ch])
    return img


def finish(img, shade=True, outline=True):
    """add the light-grey right/bottom edge shading to white pixels, then a dark 8-neighbour outline"""
    px = img.load()
    solid = {(x, y) for y in range(G) for x in range(G) if px[x, y][3]}
    if shade:
        for (x, y) in solid:
            if px[x, y] == WHITE and (((x + 1, y) not in solid) or ((x, y + 1) not in solid)):
                px[x, y] = SHADE
    if outline:
        for (x, y) in solid:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < G and 0 <= ny < G and (nx, ny) not in solid:
                        px[nx, ny] = OUTLINE
    return img


def mask_from_draw(fn):
    """run fn(ImageDraw) on a 16x16 white-on-clear canvas (no anti-aliasing: draws solid pixels)"""
    im = blank()
    d = ImageDraw.Draw(im)
    fn(d)
    return im


def mirror(img):
    return img.transpose(Image.FLIP_LEFT_RIGHT)


# ----------------------------------------------------------------------------------------------- pointer shapes
ARROW = ["w.......", "ww......", "www.....", "wwww....", "wwwww...", "wwwwww..", "wwwwwww.", "wwwwwwww",
         "wwwww...", "ww.ww...", "w..www..", "...www..", "....www.", "....www."]
HAND = [".....ww.......", ".....ww.......", ".....ww.......", ".....ww.......", ".....wwwww....", ".....wwwwwww..", ".ww..wwwwwwww.",
        ".wwwwwwwwwwww.", "..wwwwwwwwwww.", "..wwwwwwwwwww.", "...wwwwwwwwww.", "...wwwwwwwww..", "....wwwwwwww..", "....wwwwwwww.."]
NWSE = ["wwwwww........", "wwwww.........", "wwww..........", "wwwww.........", "wwwwww........", "w.wwwww.......", "...wwwww......", "....wwwww.....",
        ".....wwwww.w..", "......wwwwww..", ".......wwwww..", "........wwww..", ".......wwwww..", "......wwwwww.."]
NWSE = ["wwwwww........", "wwwww.........", "wwww..........", "wwwww.........", "wwwwww........", "w.wwwww.......", "...wwwww......", "....wwwww.....",
        ".....wwwww.w..", "......wwwwww..", ".......wwwww..", "......wwww....", ".....wwwww....", "....wwwwww...."]


def arrow(extra=None):
    img = from_rows(ARROW)
    if extra:
        extra(img)
    return finish(img)


def c_arrow():
    return [arrow()], (1, 1)


def c_hand():
    return [finish(from_rows(HAND))], (6, 1)


def c_text():  # I-beam
    rows = ["wwwww", "..w..", "..w..", "..w..", "..w..", "..w..", "..w..", "..w..", "..w..", "..w..", "..w..", "wwwww"]
    return [finish(from_rows(rows, ox=5, oy=2), shade=False)], (7, 8)


def c_vtext():
    img = from_rows(["w.......w", "wwwwwwwww", "w.......w"], ox=3, oy=5) if False else None
    rows = ["w.........w", "w.........w", "wwwwwwwwwww", "w.........w", "w.........w"]
    im = blank()
    for x in range(11):
        im.putpixel((2 + x, 8), WHITE)
    for dy in (-2, -1, 0, 1, 2):
        if dy:
            im.putpixel((2, 8 + dy), WHITE)
            im.putpixel((12, 8 + dy), WHITE)
    return [finish(im, shade=False)], (7, 8)


def c_cross():  # the game's crosshair: a plus sign
    def f(d):
        d.line([(1, 7), (13, 7)], fill=WHITE)
        d.line([(7, 1), (7, 13)], fill=WHITE)
        d.line([(1, 8), (13, 8)], fill=WHITE)
        d.line([(8, 1), (8, 13)], fill=WHITE)
    im = mask_from_draw(f)
    # gap in the middle for aiming
    for (x, y) in ((6, 7), (6, 8), (9, 7), (9, 8), (7, 6), (8, 6), (7, 9), (8, 9)):
        im.putpixel((x, y), CLEAR)
    im.putpixel((7, 7), CLEAR); im.putpixel((8, 8), CLEAR); im.putpixel((7, 8), CLEAR); im.putpixel((8, 7), CLEAR)
    for (x, y) in ((7, 7), (8, 7), (7, 8), (8, 8)):
        im.putpixel((x, y), WHITE)
    return [finish(im, shade=False)], (7, 7)


def c_cell():  # thick plus (spreadsheet cell)
    def f(d):
        d.rectangle([6, 2, 8, 12], fill=WHITE)
        d.rectangle([2, 6, 12, 8], fill=WHITE)
    return [finish(mask_from_draw(f))], (7, 7)


def c_move():  # four-way arrow
    def f(d):
        d.rectangle([7, 2, 8, 13], fill=WHITE)
        d.rectangle([2, 7, 13, 8], fill=WHITE)
        for k in range(4):
            d.line([(7 - k, 1 + k), (8 + k, 1 + k)], fill=WHITE)
            d.line([(7 - k, 14 - k), (8 + k, 14 - k)], fill=WHITE)
            d.line([(1 + k, 7 - k), (1 + k, 8 + k)], fill=WHITE)
            d.line([(14 - k, 7 - k), (14 - k, 8 + k)], fill=WHITE)
    return [finish(mask_from_draw(f))], (8, 8)


def _ns():
    def f(d):
        d.rectangle([7, 4, 8, 11], fill=WHITE)
        for k in range(4):
            d.line([(7 - k, 1 + k), (8 + k, 1 + k)], fill=WHITE)
            d.line([(7 - k, 14 - k), (8 + k, 14 - k)], fill=WHITE)
    return mask_from_draw(f)


def c_ns():
    return [finish(_ns())], (8, 8)


def c_ew():
    return [finish(_ns().transpose(Image.ROTATE_90))], (8, 8)


def _nwse():
    def f(d):
        d.polygon([(1, 1), (7, 1), (1, 7)], fill=WHITE)
        d.polygon([(14, 14), (8, 14), (14, 8)], fill=WHITE)
        d.line([(3, 3), (12, 12)], fill=WHITE, width=3)
    return mask_from_draw(f)


def c_nwse():
    return [finish(_nwse())], (8, 8)


def c_nesw():
    return [finish(mirror(_nwse()))], (8, 8)


def c_notallowed():
    def f(d):
        d.ellipse([1, 1, 14, 14], outline=RED, width=3)
        d.line([(3, 12), (12, 3)], fill=RED, width=3)
    im = mask_from_draw(f)
    return [finish(im, shade=False)], (8, 8)


def c_help():
    q = ["..www..", ".ww.ww.", ".ww.ww.", ".....ww", "....ww.", "...ww..", "...ww..", ".......", "...ww..", "...ww.."]
    img = from_rows(ARROW)
    from_rows(q, ox=8, oy=5, img=img)
    return [finish(img)], (1, 1)


def c_copy():
    img = from_rows(ARROW)
    pl = ["..n..", "..n..", "nnnnn", "..n..", "..n.."]
    from_rows(pl, ox=9, oy=9, pal={"n": GREEN}, img=img)
    return [finish(img, shade=False)], (1, 1)


def c_alias():
    img = from_rows(ARROW)
    from_rows(["..y..", ".yyy.", "..y..", "..y..", "yyy.."], ox=9, oy=9, pal={"y": GOLD}, img=img)
    return [finish(img, shade=False)], (1, 1)


def c_menu():
    img = from_rows(ARROW)
    from_rows(["bbbbb", ".....", "bbbbb", ".....", "bbbbb"], ox=9, oy=8, pal={"b": BLUE}, img=img)
    return [finish(img, shade=False)], (1, 1)


def c_zoom(plus=True):
    def f(d):
        d.ellipse([1, 1, 10, 10], outline=WHITE, width=2)
        d.line([(9, 9), (14, 14)], fill=WHITE, width=2)
    im = mask_from_draw(f)
    d = ImageDraw.Draw(im)
    d.line([(4, 5), (7, 5)], fill=WHITE)
    if plus:
        d.line([(5, 4), (5, 7)], fill=WHITE)
    return [finish(im, shade=False)], (5, 5)


def c_grab():  # open hand
    def f(d):
        for i, top in enumerate((3, 1, 1, 3)):
            x = 3 + i * 3
            d.rectangle([x, top, x + 1, 9], fill=WHITE)
        d.rectangle([3, 8, 13, 13], fill=WHITE)
        d.rectangle([1, 9, 3, 11], fill=WHITE)
        d.rectangle([12, 5, 13, 9], fill=WHITE)
        d.rectangle([2, 8, 4, 12], fill=WHITE)
    return [finish(mask_from_draw(f))], (8, 8)


def c_grabbing():  # fist
    def f(d):
        d.rectangle([3, 5, 13, 12], fill=WHITE)
        d.rectangle([2, 7, 3, 10], fill=WHITE)
        for x in (3, 6, 9, 12):
            d.rectangle([x, 4, x + 1, 5], fill=WHITE)
        d.rectangle([4, 13, 12, 13], fill=WHITE)
    im = mask_from_draw(f)
    px = im.load()
    for x in (5, 8, 11):  # finger separators
        for y in (5, 6):
            px[x, y] = SHADE
    return [finish(im)], (8, 8)


def c_clock(frames=8):
    out = []
    for i in range(frames):
        img = blank()
        d = ImageDraw.Draw(img)
        d.ellipse([2, 2, 13, 13], fill=WHITE, outline=SHADE)
        d.ellipse([3, 3, 12, 12], fill=(250, 244, 214, 255))
        a = 2 * math.pi * i / frames - math.pi / 2
        d.line([(7.5, 7.5), (7.5 + 4 * math.cos(a), 7.5 + 4 * math.sin(a))], fill=OUTLINE)
        d.point([(7, 7), (8, 8), (7, 8), (8, 7)], fill=OUTLINE)
        for (x, y) in ((7, 3), (8, 3), (7, 12), (8, 12), (3, 7), (3, 8), (12, 7), (12, 8)):
            img.putpixel((x, y), GOLD)
        out.append(finish(img, shade=False))
    return out, (8, 8)


def c_progress(frames=8):
    out = []
    ring = [(11, 9), (12, 10), (12, 12), (10, 13), (8, 13), (7, 12), (7, 10), (8, 9)]  # 8 spinner cells, lower-right of the arrow
    ring = [(10 + round(3 * math.cos(2 * math.pi * k / 8)), 11 + round(3 * math.sin(2 * math.pi * k / 8))) for k in range(8)]
    for i in range(frames):
        img = from_rows(ARROW)
        for k, (x, y) in enumerate(ring):
            age = (i - k) % 8
            c = (240, 200, 70, 255) if age == 0 else ((200, 160, 50, 255) if age == 1 else ((120, 100, 50, 255) if age < 4 else (70, 70, 80, 255)))
            for dx in (0, 1):
                for dy in (0, 1):
                    if 0 <= x + dx < G and 0 <= y + dy < G and not img.getpixel((x + dx, y + dy))[3]:
                        pass
            if 0 <= x < G and 0 <= y < G:
                img.putpixel((x, y), c)
        out.append(finish(img, shade=False))
    return out, (1, 1)


# canonical shape name -> factory.  `ALIASES` lists every other name the shape answers to.
SHAPES = {
    "left_ptr": c_arrow, "pointer": c_hand, "text": c_text, "vertical-text": c_vtext, "crosshair": c_cross, "cell": c_cell, "move": c_move,
    "ns-resize": c_ns, "ew-resize": c_ew, "nwse-resize": c_nwse, "nesw-resize": c_nesw, "not-allowed": c_notallowed, "help": c_help,
    "copy": c_copy, "alias": c_alias, "context-menu": c_menu, "zoom-in": lambda: c_zoom(True), "zoom-out": lambda: c_zoom(False),
    "grab": c_grab, "grabbing": c_grabbing, "wait": c_clock, "progress": c_progress,
}
ANIMATED = {"wait": 100, "progress": 100}  # ms per frame

ALIASES = {
    "left_ptr": ["default", "arrow", "top_left_arrow", "left_arrow", "right_ptr", "draft_large", "draft_small", "dnd-none", "context-menu_", "center_ptr", "e29285e634086352946a0e7090d73106", "00000000000000020006000e7e9ffc3f"],
    "pointer": ["hand1", "hand2", "pointing_hand", "9d800788f1b08800ae810202380a0822", "openhand_"],
    "text": ["xterm", "ibeam", "xterm_", "08e8e1c95fe2fc01f976f1e063a24ccd_"],
    "vertical-text": ["vertical_text"],
    "crosshair": ["cross", "tcross", "cross_reverse", "diamond_cross", "target", "plus_", "crossed_circle_"],
    "cell": ["plus", "cell_"],
    "move": ["all-scroll", "fleur", "size_all", "4498f0e0c1937ffe01fd06f973665830", "grab_all_"],
    "ns-resize": ["row-resize", "n-resize", "s-resize", "top_side", "bottom_side", "sb_v_double_arrow", "v_double_arrow", "size_ver", "double_arrow", "split_v", "base_arrow_down", "base_arrow_up", "up", "down", "col-resize_ns_"],
    "ew-resize": ["col-resize", "e-resize", "w-resize", "left_side", "right_side", "sb_h_double_arrow", "h_double_arrow", "size_hor", "split_h", "sb_left_arrow", "sb_right_arrow", "left", "right", "14fef782d02440884392942c11205230"],
    "nwse-resize": ["nw-resize", "se-resize", "top_left_corner", "bottom_right_corner", "size_fdiag", "fd_double_arrow", ],
    "nesw-resize": ["ne-resize", "sw-resize", "top_right_corner", "bottom_left_corner", "size_bdiag", "bd_double_arrow", ],
    "not-allowed": ["no-drop", "forbidden", "crossed_circle", "circle", "dnd-no-drop"],
    "help": ["question_arrow", "whats_this", "left_ptr_help", "d9ce0ab605698f320427677b458ad60b"],
    "copy": ["dnd-copy", "1081e37283d90000800003c07f3ef6bf", "6407b0e94181790501fd1e167b474872"],
    "alias": ["dnd-link", "link", "640fb0e74195791501fd1ed57b41487f"],
    "context-menu": [],
    "zoom-in": [], "zoom-out": [],
    "grab": ["openhand", "hand"],
    "grabbing": ["closedhand", "dnd-move", "dnd-ask", "closed_hand"],
    "wait": ["watch", "clock"],
    "progress": ["left_ptr_watch", "half-busy", "3ecb610c1bf2410f44200f48c40d3599", "08e8e1c95fe2fc01f976f1e063a24ccd"],
}
# drop the placeholder-ish names ending in "_" (kept above only as notes)
ALIASES = {k: [a for a in v if not a.endswith("_")] for k, v in ALIASES.items()}
