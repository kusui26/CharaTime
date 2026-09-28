import Foundation

/// 寝息の 2 コマ目（プラン §9 Phase 2 の 2-C ⑤-6、D-38）。
///
/// 1 コマ目を足元を軸に縦へ少し伸ばして作る（`FrameRenderer.hero` の `stretch`）。2-0 で生成 AI に描かせた
/// 「息を吸った寝姿」は、全体の 28% が違う別の絵だった。
enum Breath {

    /// 縦の伸び（足元を軸に）。3% 🔷（2-0 の試作。本番の絵で見て直す）。
    static let stretch = 1.03
    /// 覆う判定で、見える画素とみなす不透明さ（`tools/pipeline/art.py` の `OPAQUE_THRESHOLD`）。
    static let visibleAlpha: UInt8 = 128

    /// `top` を重ねたとき、`base` の見える画素がすべて隠れるか（`art.py` の `covers`）。覆えるなら、ウィジェットは
    /// 1 コマ目を土台にして 2 コマ目だけを重ねる（タイマー 1 本）。覆えなければ 2 枚を出し分ける（`sleepFrameCoversBase`）。
    static func covers(base: Raster, top: Raster) -> Bool {
        var stickingOut = false
        base.pixels.withUnsafeBufferPointer { base in
            top.pixels.withUnsafeBufferPointer { top in
                eachIndex(base.count / Raster.bytesPerPixel) { index in
                    let alpha = index &* Raster.bytesPerPixel &+ 3
                    if base[alpha] >= visibleAlpha && top[alpha] < visibleAlpha { stickingOut = true }
                }
            }
        }
        return !stickingOut
    }
}
