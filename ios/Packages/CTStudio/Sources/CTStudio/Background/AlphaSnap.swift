import Foundation

/// 不透明さをそろえる（プラン §9 Phase 2 の 2-C ⑤-2）: 240 以上は 255、16 未満は 0。
///
/// 生成 AI の透明 PNG は、体の中の不透明さが 253〜254 で 255 にならず、縁の外に 1〜31 の薄いにじみがある
/// （2-0 の実測）。そろえないと、まぶたや寝息のコマを重ねたときに下の絵が透ける。
enum AlphaSnap {

    /// これ以上は 255 にする 🔷（2-0 の絵の体の中は 252〜254 が 93%）。
    static let solidFrom: UInt8 = 240
    /// これ未満は 0 にする 🔷（縁の外のにじみは 1〜31）。
    static let clearBelow: UInt8 = 16

    static func apply(to raster: inout Raster) {
        let count = raster.pixelCount
        raster.pixels.withUnsafeMutableBufferPointer { pixels in
            eachIndex(count) { index in
                let offset = index &* Raster.bytesPerPixel
                // 透明と不透明の画素（ほとんど）は、そろえるものが無い。
                let alpha = pixels[offset + 3]
                if alpha != 0 && alpha != Raster.opaque { snap(pixels, at: offset) }
            }
        }
    }

    /// 1 画素ぶん。乗算済みなので、不透明さを 255 に上げるときは色も同じ割合で上げる（色味を保つ）。
    static func snap(_ pixels: UnsafeMutableBufferPointer<UInt8>, at offset: Int) {
        let alpha = Int(pixels[offset + 3])
        if alpha < Int(clearBelow) {
            for channel in 0..<Raster.bytesPerPixel { pixels[offset + channel] = 0 }
            return
        }
        guard alpha >= Int(solidFrom), alpha < Int(Raster.opaque) else { return }
        for channel in 0..<3 {
            let raised = (Int(pixels[offset + channel]) * Int(Raster.opaque) + alpha / 2) / alpha
            pixels[offset + channel] = UInt8(Swift.min(Int(Raster.opaque), raised))
        }
        pixels[offset + 3] = Raster.opaque
    }
}
