import Foundation
import CoreGraphics
import ImageIO
import CTAssets
import CTStore
@testable import CTStudio

/// テストの見本（プラン §9 Phase 2 の 2-C ⑫）。**いまの絵（正解が分かっている）**を、いろいろな地に、
/// 位置と大きさを少しずつずらして並べた合成画像。同梱の @3x の絵（パイプラインが焼いたもの）を材料にする。
///
/// 最適化しないビルド（`swift test` の既定）では画素のループが遅いので、見本は小さく作る（調査 H §2）。
enum Samples {

    /// 地の種類。
    enum Ground {
        case transparent
        case solid(red: CGFloat, green: CGFloat, blue: CGFloat)
        /// 市松模様（Gemini が「透明」を描いたもの）。
        case checkerboard(light: CGFloat, dark: CGFloat, square: Int)
        /// 模様（1 色でも市松でもない地）。
        case stripes
    }

    /// 置く絵 1 枚。`origin` は左上、`scale` は元の絵に対する倍率。
    struct Placement {
        let name: String
        let origin: CGPoint
        let scale: CGFloat
    }

    static let white = Ground.solid(red: 1, green: 1, blue: 1)
    static let green = Ground.solid(red: 0, green: 1, blue: 0)

    /// 同梱の @3x の絵（macOS の `swift test` では、Asset Catalog がそのまま置かれる）。
    static func bundled(_ name: String) -> CGImage {
        let catalog = AssetBundle.value.url(forResource: "Characters", withExtension: "xcassets")!
        let url = catalog.appending(path: "\(name).imageset/\(name)@3x.png")
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        return CGImageSourceCreateImageAtIndex(source, 0, nil)!
    }

    /// 地に絵を並べた 1 枚。
    static func sheet(width: Int, height: Int, ground: Ground, placements: [Placement]) -> Raster {
        var raster = Raster(width: width, height: height)
        _ = raster.draw { context in
            paint(ground, in: context, width: width, height: height)
            context.interpolationQuality = .high
            for placement in placements {
                let image = bundled(placement.name)
                let size = CGSize(width: CGFloat(image.width) * placement.scale,
                                  height: CGFloat(image.height) * placement.scale)
                // Core Graphics は左下が原点なので、上からの位置を下からの位置に直す。
                let origin = CGPoint(x: placement.origin.x, y: CGFloat(height) - placement.origin.y - size.height)
                context.draw(image, in: CGRect(origin: origin, size: size))
            }
        }
        return raster
    }

    static func paint(_ ground: Ground, in context: CGContext, width: Int, height: Int) {
        switch ground {
        case .transparent:
            return
        case .solid(let red, let green, let blue):
            context.setFillColor(CGColor(srgbRed: red, green: green, blue: blue, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        case .checkerboard(let light, let dark, let square):
            for row in 0..<(height / square + 1) {
                for column in 0..<(width / square + 1) {
                    let gray = (row + column).isMultiple(of: 2) ? light : dark
                    context.setFillColor(CGColor(srgbRed: gray, green: gray, blue: gray, alpha: 1))
                    context.fill(CGRect(x: column * square, y: row * square, width: square, height: square))
                }
            }
        case .stripes:
            let colors = [CGColor(srgbRed: 0.9, green: 0.3, blue: 0.2, alpha: 1),
                          CGColor(srgbRed: 0.2, green: 0.5, blue: 0.9, alpha: 1),
                          CGColor(srgbRed: 0.95, green: 0.85, blue: 0.3, alpha: 1)]
            for (index, stripe) in stride(from: 0, to: width + height, by: 24).enumerated() {
                context.setFillColor(colors[index % colors.count])
                context.fill(CGRect(x: stripe, y: 0, width: 24, height: height))
            }
        }
    }

    /// 丸い点を描く（浮いた部品・透かし・ごみのまね）。`center` は上からの位置。
    static func dot(on raster: inout Raster, center: CGPoint, radius: CGFloat, gray: CGFloat = 0.25) {
        let height = CGFloat(raster.height)
        _ = raster.draw { context in
            context.setFillColor(CGColor(srgbRed: gray, green: gray, blue: gray, alpha: 1))
            context.fillEllipse(in: CGRect(x: center.x - radius, y: height - center.y - radius,
                                           width: radius * 2, height: radius * 2))
        }
    }

    /// 1 枚だけを置いた、同じ大きさの透明な絵（そのコマの正解）。
    static func alone(_ placement: Placement, width: Int, height: Int) -> Raster {
        sheet(width: width, height: height, ground: .transparent, placements: [placement])
    }

    /// 不透明さ 0.5 以上の画素の外接矩形（上から、右と下は含まない）。
    static func opaqueBox(_ raster: Raster) -> PixelBox? {
        let indices = stride(from: 0, to: raster.pixelCount, by: 1).filter { raster.pixels[$0 * 4 + 3] >= 128 }
        guard !indices.isEmpty else { return nil }
        let xs = indices.map { $0 % raster.width }, ys = indices.map { $0 / raster.width }
        return PixelBox(left: xs.min()!, top: ys.min()!, right: xs.max()! + 1, bottom: ys.max()! + 1)
    }

    /// 不透明さ 0.5 以上の画素の印。
    static func mask(_ raster: Raster) -> [Bool] {
        stride(from: 3, to: raster.pixels.count, by: 4).map { raster.pixels[$0] >= 128 }
    }

    /// 2 つの印の重なりの割合（IoU）。調査 H の物差し。
    static func intersectionOverUnion(_ first: [Bool], _ second: [Bool]) -> Double {
        let both = zip(first, second).filter { $0 && $1 }.count
        let either = zip(first, second).filter { $0 || $1 }.count
        return either == 0 ? 1 : Double(both) / Double(either)
    }
}
