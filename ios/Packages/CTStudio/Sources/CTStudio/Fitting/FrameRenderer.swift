import Foundation
import CoreGraphics
import CTStore

/// コマを枠に描く（プラン §9 Phase 2 の 2-C ⑤-4・⑤-5）。
///
/// 足元（輪郭線のいちばん下）を枠の 94.72% に、体の上 6 割の中心を枠の中央に置き、画像ごとの倍率で描く。
/// **コマごとに余白を詰めない**（詰めるとコマを送るたびに跳ねて見える。`tools/pipeline` の決めごと）。
/// 乗算済みのまま `CGContext` の高品質の補間で描き、最後に色を不透明さで頭打ちにする（H §6）。
enum FrameRenderer {

    /// コマ 1 つを hero の枠に描く。`stretch` は足元を軸にした縦の伸び（寝息の 2 コマ目。`Breath`）。描けなければ nil。
    static func hero(_ figure: Figure, metrics: FigureMetrics, scale: Double,
                     stretch: Double = 1) -> Raster? {
        let frame = FrameGeometry.hero
        let left = FrameGeometry.centerX(of: frame) - metrics.anchorX * scale
        let top = FrameGeometry.outlineBottom(in: frame) - metrics.bottom * scale * stretch
        return draw(figure.image, into: frame, left: left, top: top,
                    scale: (horizontal: scale, vertical: scale * stretch))
    }

    /// hero を mini に縮める。**mini は必ず hero から作る**（目を開けた絵とまばたきの絵が同じ道を通るので、
    /// まぶたの差分が目のまわりだけになる。2-C ⑤-6）。
    static func mini(from hero: Raster) -> Raster? {
        let frame = FrameGeometry.mini
        let ratio = Double(frame.width) / Double(hero.width)
        return draw(hero, into: frame, left: 0, top: 0, scale: (ratio, ratio))
    }

    /// 絵を、上からの位置 `top`・左からの位置 `left`・倍率 `scale` で、`size` の透明な枠に描く。
    static func draw(_ image: Raster, into size: PixelSize, left: Double, top: Double,
                     scale: (horizontal: Double, vertical: Double)) -> Raster? {
        guard let picture = image.cgImage else { return nil }
        let width = Double(image.width) * scale.horizontal, height = Double(image.height) * scale.vertical
        // Core Graphics は左下が原点なので、上からの位置を下からの位置に直す。
        let rect = CGRect(x: left, y: Double(size.height) - top - height, width: width, height: height)
        var raster = Raster(width: size.width, height: size.height)
        let drawn = raster.draw { context in
            context.interpolationQuality = .high
            context.draw(picture, in: rect)
        }
        guard drawn else { return nil }
        raster.clampColorsToAlpha()
        return raster
    }
}

extension Raster {

    /// 乗算済みの色を、不透明さで頭打ちにする（補間の揺り戻しで、色が不透明さを超えることがある。H §6）。
    mutating func clampColorsToAlpha() {
        let count = pixelCount
        pixels.withUnsafeMutableBufferPointer { pixels in
            eachIndex(count) { index in
                let offset = index &* Raster.bytesPerPixel
                let alpha = pixels[offset + 3]
                if pixels[offset] > alpha { pixels[offset] = alpha }
                if pixels[offset + 1] > alpha { pixels[offset + 1] = alpha }
                if pixels[offset + 2] > alpha { pixels[offset + 2] = alpha }
            }
        }
    }
}
