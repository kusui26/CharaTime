import Foundation

/// コマの寸法。枠にそろえる倍率と位置を決める（プラン §9 Phase 2 の 2-C ⑤-4）。
///
/// 不透明さ 0.5 以上の外接矩形を、**縁の画素の不透明さ（覆う割合）で画素より細かく**測る。元の絵が枠より
/// 小さいと、元の 1 画素のずれが枠では 1.5〜3 画素に広がるので、整数の画素では「元の枠と 1 画素以内」に届かない
/// （2-C ⑫）。座標は画素の境目を整数とする（1 画素目の左端が 0、右端が 1）。
struct FigureMetrics: Equatable, Sendable {

    /// 外接矩形の左・上・右・下の端。
    let left: Double
    let top: Double
    let right: Double
    let bottom: Double
    /// 体の上 6 割（`FrameGeometry.upperBodyShare`）の外接矩形の、横の中心。枠の中央に置く所。
    let anchorX: Double

    var width: Double { right - left }
    var height: Double { bottom - top }

    init(left: Double, top: Double, right: Double, bottom: Double, anchorX: Double) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
        self.anchorX = anchorX
    }

    /// 測る。不透明さ 0.5 以上の画素が無ければ nil。
    init?(_ image: Raster) {
        let profile = CoverageProfile(image)
        guard let vertical = Self.span(profile.rows), let horizontal = Self.span(profile.columns) else {
            return nil
        }
        let bandEnd = Int(vertical.lower + (vertical.upper - vertical.lower) * FrameGeometry.upperBodyShare)
        let band = Int(vertical.lower)..<Swift.min(image.height, Swift.max(bandEnd, Int(vertical.lower) + 1))
        let upper = Self.span(CoverageProfile.columns(of: image, rows: band)) ?? horizontal
        self.init(left: horizontal.lower, top: vertical.lower, right: horizontal.upper,
                  bottom: vertical.upper, anchorX: (upper.lower + upper.upper) / 2)
    }

    /// 覆う割合の並び（行ごとか列ごと）から、不透明な範囲の両端を画素より細かく求める。
    ///
    /// 0.5 以上の最初の画素を r とすると、手前の端は r + 1 − c(r) − c(r−1)。端が r の中にあれば c(r−1) は 0 で、
    /// 端の手前の画素 r−1 が半分未満しか覆われていなければ c(r) は 1 なので、どちらの場合も端の位置になる。奥の端も同じ。
    static func span(_ coverage: [Double]) -> (lower: Double, upper: Double)? {
        guard let first = coverage.firstIndex(where: { $0 >= CoverageProfile.opaqueShare }),
              let last = coverage.lastIndex(where: { $0 >= CoverageProfile.opaqueShare }) else { return nil }
        let before = first > 0 ? coverage[first - 1] : 0
        let after = last + 1 < coverage.count ? coverage[last + 1] : 0
        return (Double(first) + 1 - coverage[first] - before, Double(last) + coverage[last] + after)
    }
}

/// 行ごと・列ごとの、いちばん大きい不透明さ（0〜1。その行・列を縁が覆う割合とみなす）。
struct CoverageProfile {

    /// 見える画素とみなす覆う割合（不透明さ 0.5。いまの絵の「輪郭線のいちばん下」の測り方と同じ）。
    static let opaqueShare = 0.5

    let rows: [Double]
    let columns: [Double]

    init(_ image: Raster) {
        var rows = [UInt8](repeating: 0, count: image.height)
        var columns = [UInt8](repeating: 0, count: image.width)
        let width = image.width
        image.pixels.withUnsafeBufferPointer { pixels in
            rows.withUnsafeMutableBufferPointer { rows in
                columns.withUnsafeMutableBufferPointer { columns in
                    eachIndex(image.pixelCount) { index in
                        let alpha = pixels[index &* Raster.bytesPerPixel &+ 3]
                        let y = index / width, x = index % width
                        if alpha > rows[y] { rows[y] = alpha }
                        if alpha > columns[x] { columns[x] = alpha }
                    }
                }
            }
        }
        self.rows = rows.map(Self.share)
        self.columns = columns.map(Self.share)
    }

    /// `rows` の行だけを見た、列ごとの値。
    static func columns(of image: Raster, rows: Range<Int>) -> [Double] {
        var columns = [UInt8](repeating: 0, count: image.width)
        let width = image.width
        image.pixels.withUnsafeBufferPointer { pixels in
            columns.withUnsafeMutableBufferPointer { columns in
                eachIndex(in: rows.lowerBound * width..<rows.upperBound * width) { index in
                    let alpha = pixels[index &* Raster.bytesPerPixel &+ 3]
                    if alpha > columns[index % width] { columns[index % width] = alpha }
                }
            }
        }
        return columns.map(share)
    }

    static func share(_ alpha: UInt8) -> Double {
        Double(alpha) / Double(Raster.opaque)
    }
}
