import QtQuick
import qs.Common

/*  BookPage — the open page of the Book and Quill screen, as the game draws it: gui/book.png, cropped to its opaque part (the 256×256 atlas keeps the
 *  page in the top-left 192×192; the brown cover, red stitching and cream page are x 20..165, y 1..180 = 146×180 texels) and drawn at an integer
 *  `u` screen px per texel, nearest-neighbour.  Children are placed in BOOK TEXELS × u (use `bx(n)`), origin = the cropped top-left:
 *    text box        x 16, y 29, 114 × 128 texels  (the game's: x 36, y 30 on the 192 texture, 114 wide, 128 tall = 14 lines of 9)
 *    page indicator  right edge x 128, y 15
 *    page arrows     23 × 13 at (23, 156) and (96, 156)
 *  Without the Mojang art (Theme.tex falls back to assets/gen, then to the missing texture) a drawn cover and cream page stand in.
 */
Item {
    id: book
    property int u: Theme.gui
    readonly property int texW: 146
    readonly property int texH: 180
    readonly property url src: Theme.tex("gui/book")
    readonly property bool real: src.toString().length > 0 && src.toString() !== String(Theme.missingTexture)
    // the page's own colours (the same in Day and Night: the book is the same item in both)
    readonly property color paper: "#FFFAEE"
    readonly property color paperEdge: "#E9D9B6"
    readonly property color cover: "#7B4A2B"
    readonly property color ink: "#000000"
    readonly property color inkMuted: "#7A6C54"
    default property alias content: layer.data
    function bx(n) { return n * u; }

    width: texW * u
    height: texH * u

    Image {
        anchors.fill: parent
        visible: book.real
        source: book.real ? book.src : ""
        sourceClipRect: Qt.rect(20, 1, book.texW, book.texH)
        smooth: false
        mipmap: false
        cache: true
    }
    // stand-in: cover, page, the red stitching
    Item {
        anchors.fill: parent
        visible: !book.real
        Rectangle { x: book.bx(1); width: parent.width - book.bx(2); height: parent.height; color: "#3A2112" }
        Rectangle { y: book.bx(1); width: parent.width; height: parent.height - book.bx(2); color: "#3A2112" }
        Rectangle { x: book.bx(1); y: book.bx(1); width: parent.width - book.bx(2); height: parent.height - book.bx(2); color: book.cover }
        Rectangle { x: book.bx(6); y: book.bx(6); width: book.bx(130); height: book.bx(166); color: book.paper }
        Rectangle { x: book.bx(6); y: book.bx(6); width: book.bx(130); height: book.u; color: book.paperEdge }
        Rectangle { x: book.bx(6); y: book.bx(171); width: book.bx(130); height: book.u; color: book.paperEdge }
        Repeater {
            model: 12
            Rectangle { required property int index; x: book.bx(9); y: book.bx(8 + index * 13); width: book.u; height: book.bx(9); color: "#C3251D" }
        }
    }
    Item { id: layer; anchors.fill: parent }
}
