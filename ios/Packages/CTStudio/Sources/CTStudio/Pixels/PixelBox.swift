import Foundation
import CTStore

/// 画素の矩形。原点は左上で、右端と下端は含まない（`left..<right`、`top..<bottom`）。
struct PixelBox: Equatable, Hashable, Sendable {
    var left: Int
    var top: Int
    var right: Int
    var bottom: Int

    /// 1 画素ぶん。
    init(x: Int, y: Int) {
        self.init(left: x, top: y, right: x + 1, bottom: y + 1)
    }

    init(left: Int, top: Int, right: Int, bottom: Int) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }

    /// 絵全体。
    init(width: Int, height: Int) {
        self.init(left: 0, top: 0, right: width, bottom: height)
    }

    var width: Int { right - left }
    var height: Int { bottom - top }
    var area: Int { width * height }
    var centerX: Double { Double(left + right) / 2 }
    var centerY: Double { Double(top + bottom) / 2 }
    var rect: PixelRect { PixelRect(x: left, y: top, width: width, height: height) }

    func contains(x: Int, y: Int) -> Bool {
        x >= left && x < right && y >= top && y < bottom
    }

    func union(_ other: PixelBox) -> PixelBox {
        PixelBox(left: Swift.min(left, other.left), top: Swift.min(top, other.top),
                 right: Swift.max(right, other.right), bottom: Swift.max(bottom, other.bottom))
    }

    /// 重なり（無ければ nil）。
    func intersection(_ other: PixelBox) -> PixelBox? {
        let box = PixelBox(left: Swift.max(left, other.left), top: Swift.max(top, other.top),
                           right: Swift.min(right, other.right), bottom: Swift.min(bottom, other.bottom))
        return box.width > 0 && box.height > 0 ? box : nil
    }

    /// 四方に `margin` 広げ、`limit` の中に収める。
    func expanded(by margin: Int, within limit: PixelBox) -> PixelBox {
        PixelBox(left: Swift.max(limit.left, left - margin),
                 top: Swift.max(limit.top, top - margin),
                 right: Swift.min(limit.right, right + margin),
                 bottom: Swift.min(limit.bottom, bottom + margin))
    }

    /// 矩形の画素の、絵全体での番号（上の行から）。
    func indices(imageWidth: Int) -> [Int] {
        (top..<bottom).flatMap { y in (left..<right).map { y * imageWidth + $0 } }
    }

    /// 矩形どうしのすき間（画素）。重なっていれば 0。
    func gap(to other: PixelBox) -> Int {
        let horizontal = Swift.max(0, Swift.max(other.left - right, left - other.right))
        let vertical = Swift.max(0, Swift.max(other.top - bottom, top - other.bottom))
        return Swift.max(horizontal, vertical)
    }
}
