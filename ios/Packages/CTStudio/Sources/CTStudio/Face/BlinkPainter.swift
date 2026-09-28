import Foundation
import CoreGraphics

/// 目を開けた絵から、まばたきの絵を作る（プラン §9 Phase 2 の 2-C ⑤-6、D-38）。
///
/// 目をまわりの肌の色で埋め、輪郭線の色で閉じた目の弧（寝姿の目と同じ、下にふくらむ弧）を描く。2 枚目の絵が
/// 要らず、位置が必ずそろう。弧の形は `design/chara.py` のまばたき（開いた目は直径 13 の円。弧の両端は中心から
/// 横に ±6・下へ 1、制御点は下へ 7、線の太さ 4.5）を、目の外接矩形に対する割合にしたもの。
enum BlinkPainter {

    /// 埋める範囲を、目から広げる幅（目の幅に対する割合）。目の輪郭のなめらかな縁を残さない（2-0 の試作）。
    static let fillGrowthShare = 0.15
    /// 肌の色が 1 色とみなせる、中央値からの色の距離（0〜√3）。生成 AI の平塗りのむらは 0.03 ほど（2-0 のピヨの 9 割）。
    static let skinTolerance: Float = 0.12
    /// 肌の輪のうち、中央値の近くにあるべき画素の割合。下回れば、目が色の境の上にある（1 色で埋めると染みになる）。
    /// いまの 5 体は 0.99〜1.0、2-0 のピヨは 0.92〜0.94（輪の端にほっぺがかかる）、色の境の上なら 0.5 ほど。
    static let uniformSkinShare = 0.8
    /// 肌の色を取る輪の幅（画素）。
    static let skinRingWidth = 2
    /// 弧の両端の、目の中心からの横の距離（目の幅に対する割合）。
    static let arcHalfSpanShare = 6.0 / 13
    /// 弧の両端の、目の中心からの下への距離（目の高さに対する割合）。
    static let arcEndDropShare = 1.0 / 13
    /// 弧の制御点の、目の中心からの下への距離（目の高さに対する割合）。
    static let arcControlDropShare = 7.0 / 13
    /// 弧の線の太さ（目の幅に対する割合）。
    static let arcStrokeShare = 4.5 / 13

    /// まばたきの絵と、描き変えた範囲（目ごと。hero の画素）。目のまわりが 1 色でない・描けなければ nil
    /// （その姿勢はまばたき無し）。
    static func blinked(_ image: Raster, eyes: [Eye],
                        scan: FaceScan) -> (image: Raster, regions: [PixelBox])? {
        var result = image
        var regions: [PixelBox] = []
        for eye in eyes {
            guard let filled = fill(eye, in: &result, scan: scan) else { return nil }
            regions.append(filled.union(arcBox(of: eye)))
        }
        let outline = scan.outlineColor
        let drawn = result.draw { context in
            for eye in eyes { drawArc(over: eye, color: outline, in: context, imageHeight: image.height) }
        }
        return drawn ? (result, regions) : nil
    }

    /// 目を肌の色で埋める。埋めうる範囲（肌の色を取った輪まで）を返す。肌の色が取れなければ nil。
    static func fill(_ eye: Eye, in image: inout Raster, scan: FaceScan) -> PixelBox? {
        let growth = Swift.max(1, Int((Double(eye.box.width) * fillGrowthShare).rounded()))
        let window = eye.box.expanded(by: growth + skinRingWidth + 1,
                                      within: PixelBox(width: image.width, height: image.height))
        let local = LocalMask(eye.pixels, window: window, imageWidth: image.width)
        let area = local.dilated(by: growth)
        let reach = local.dilated(by: growth + skinRingWidth)
        let ring = window.indices(imageWidth: image.width).enumerated().filter { local, _ in
            reach[local] != 0 && area[local] == 0
        }.map(\.element)
        guard let skin = skinColor(image, ring: ring, scan: scan) else { return nil }
        let painted = window.indices(imageWidth: image.width).enumerated().filter { local, global in
            area[local] != 0 && [0, eye.label].contains(scan.components.labels[global])
        }.map(\.element)
        image.fill(painted, with: skin)
        return window
    }

    /// 輪の画素のうち、不透明で暗くないもの（肌）の、成分ごとの中央値。肌が 1 色でなければ nil。
    static func skinColor(_ image: Raster, ring: [Int], scan: FaceScan) -> [UInt8]? {
        let skin = ring.filter { image.alpha(x: $0 % image.width, y: $0 / image.width) == Raster.opaque
                                 && scan.components.labels[$0] == 0 }
        guard !skin.isEmpty else { return nil }
        let median = (0..<3).map { channel in
            skin.map { image.pixels[$0 * Raster.bytesPerPixel + channel] }.sorted()[skin.count / 2]
        }
        let center = RGBColor(premultipliedRed: median[0], green: median[1], blue: median[2],
                              alpha: Raster.opaque)
        let near = skin.filter { index in
            let pixel = image.pixel(x: index % image.width, y: index / image.width)
            let color = RGBColor(premultipliedRed: pixel[0], green: pixel[1], blue: pixel[2], alpha: pixel[3])
            return color.distance(to: center) <= skinTolerance
        }
        guard Double(near.count) >= Double(skin.count) * uniformSkinShare else { return nil }
        return median + [Raster.opaque]
    }

    /// 閉じた目の弧を描く。座標は Core Graphics（原点は左下）に直す。
    static func drawArc(over eye: Eye, color: RGBColor, in context: CGContext, imageHeight: Int) {
        let geometry = ArcGeometry(eye.box)
        let flip = { (point: CGPoint) in CGPoint(x: point.x, y: CGFloat(imageHeight) - point.y) }
        context.setStrokeColor(CGColor(srgbRed: CGFloat(color.red), green: CGFloat(color.green),
                                       blue: CGFloat(color.blue), alpha: 1))
        context.setLineWidth(geometry.stroke)
        context.setLineCap(.round)
        context.move(to: flip(geometry.start))
        context.addQuadCurve(to: flip(geometry.end), control: flip(geometry.control))
        context.strokePath()
    }

    /// 弧が描かれうる範囲（線の太さぶん外へ広げる）。
    static func arcBox(of eye: Eye) -> PixelBox {
        let geometry = ArcGeometry(eye.box)
        let lowest = (geometry.start.y + geometry.control.y) / 2
        return PixelBox(left: Int((geometry.start.x - geometry.stroke).rounded(.down)),
                        top: Int((geometry.start.y - geometry.stroke).rounded(.down)),
                        right: Int((geometry.end.x + geometry.stroke).rounded(.up)),
                        bottom: Int((lowest + geometry.stroke).rounded(.up)))
    }
}

/// 閉じた目の弧の形（上からの座標）。
struct ArcGeometry {
    let start: CGPoint
    let end: CGPoint
    let control: CGPoint
    let stroke: CGFloat

    init(_ box: PixelBox) {
        let width = Double(box.width), height = Double(box.height)
        let endY = box.centerY + height * BlinkPainter.arcEndDropShare
        start = CGPoint(x: box.centerX - width * BlinkPainter.arcHalfSpanShare, y: endY)
        end = CGPoint(x: box.centerX + width * BlinkPainter.arcHalfSpanShare, y: endY)
        control = CGPoint(x: box.centerX, y: box.centerY + height * BlinkPainter.arcControlDropShare)
        stroke = width * BlinkPainter.arcStrokeShare
    }
}

/// 絵の一部（窓）だけの白黒の印。目のまわりを太らせるのに使う（絵全体を太らせない）。
struct LocalMask {
    let window: PixelBox
    let marks: [UInt8]

    /// 絵全体の番号 `pixels` のうち、窓に入るものに印を付ける。
    init(_ pixels: [Int], window: PixelBox, imageWidth: Int) {
        var marks = [UInt8](repeating: 0, count: window.area)
        for index in pixels {
            let x = index % imageWidth, y = index / imageWidth
            guard window.contains(x: x, y: y) else { continue }
            marks[(y - window.top) * window.width + x - window.left] = Morphology.marked
        }
        self.window = window
        self.marks = marks
    }

    func dilated(by radius: Int) -> [UInt8] {
        Morphology.dilated(marks, width: window.width, height: window.height, radius: radius)
    }
}
