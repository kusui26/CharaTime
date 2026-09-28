import Foundation

/// 1 色の地（または市松の 2 色）を、**縁からつながるところだけ**柔らかく抜く（プラン §9 Phase 2 の 2-C ⑤-2、
/// 調査 H §2）。
///
/// 画像全体で色を抜くと、輪郭線に囲まれた内側の同じ色（白目・白い体）まで消える（白い体のモチは IoU 0.33）。
/// 縁から塗り広げて届いた地だけを抜けば、内側は残る。境の画素の不透明さと色は `EdgeMatte` が決める
/// （見本で IoU は白・緑の地 0.9999、市松 0.998。H の試作は 0.992〜0.995）。
enum ColorKey {

    /// 地の色からの距離がこれ未満なら、地そのもの（透明にする。H §2 の実測の値 🔷。本物の絵で合わなければ直す）。
    static let clearDistance: Float = 0.10
    /// 縁から塗り広げる地の範囲（距離がこれ未満）。体の色とみなす下限でもある（`EdgeMatte`）。
    static let solidDistance: Float = 0.30
    /// 地の色がこれだけ鮮やかなら（緑の地）、縁の画素で地の色の成分を抑える（H §2 の「緑を抑える」）。
    static let vividKeySaturation: Float = 0.3

    /// 地を抜く。`keys` は地の色（1 色か、市松の 2 色）。
    static func remove(keys: [RGBColor], from raster: inout Raster) {
        let measured = measure(raster, keys: keys)
        let flood = FloodFill(width: raster.width, height: raster.height)
        let background = flood.reach(from: flood.borderSeeds, through: isNearKey(measured.distances))
        let marks = EdgeMatte.marks(width: raster.width, height: raster.height, background: background,
                                    distances: measured.distances)
        EdgeMatte.apply(to: &raster, keys: keys, nearestKeys: measured.nearest, marks: marks)
    }

    /// 画素ごとの、いちばん近い地の色までの距離と、その色の番号。透明な画素は地とみなす（距離 0）。
    ///
    /// 全画素を回すので、1 画素ごとに配列を作らない（最適化しないビルドでは、それだけで数倍遅くなる）。
    static func measure(_ raster: Raster, keys: [RGBColor]) -> (distances: [Float], nearest: [Int]) {
        var distances = [Float](repeating: 0, count: raster.pixelCount)
        var nearest = [Int](repeating: 0, count: raster.pixelCount)
        raster.pixels.withUnsafeBufferPointer { pixels in
            distances.withUnsafeMutableBufferPointer { distanceOut in
                nearest.withUnsafeMutableBufferPointer { nearestOut in
                    eachIndex(raster.pixelCount) { index in
                        let offset = index &* Raster.bytesPerPixel
                        guard pixels[offset + 3] >= AlphaSnap.clearBelow else { return }
                        let color = RGBColor(premultipliedRed: pixels[offset], green: pixels[offset + 1],
                                             blue: pixels[offset + 2], alpha: pixels[offset + 3])
                        (distanceOut[index], nearestOut[index]) = nearestKey(to: color, among: keys)
                    }
                }
            }
        }
        return (distances, nearest)
    }

    /// 地を塗り広げてよい画素（地の色からの距離が `solidDistance` 未満）。
    static func isNearKey(_ distances: [Float]) -> [Bool] {
        var near = [Bool](repeating: false, count: distances.count)
        near.withUnsafeMutableBufferPointer { near in
            distances.withUnsafeBufferPointer { distances in
                eachIndex(distances.count) { near[$0] = distances[$0] < solidDistance }
            }
        }
        return near
    }

    /// いちばん近い地の色までの距離と、その色の番号。
    static func nearestKey(to color: RGBColor, among keys: [RGBColor]) -> (Float, Int) {
        var best: (distance: Float, index: Int) = (.greatestFiniteMagnitude, 0)
        for index in keys.indices {
            let distance = color.distance(to: keys[index])
            if distance < best.distance { best = (distance, index) }
        }
        return best
    }

    /// 1 画素ぶん。観測した色 C＝αF＋(1−α)K から前景の色 F を戻し（K は地の色）、乗算済みで書く（H §2）。
    /// α は地の色からの距離に比例させる。近くに体の色が無い地のむらにだけ使う（ふつうの縁は `EdgeMatte`）。
    static func unmix(_ pixels: UnsafeMutableBufferPointer<UInt8>, at offset: Int,
                      distance: Float, key: RGBColor) {
        let softBand = solidDistance - clearDistance
        let coverage = Swift.min(1, Swift.max(0, (distance - clearDistance) / softBand))
        let alpha = coverage * Float(pixels[offset + 3]) / Float(Raster.opaque)
        guard alpha > 0 else { return clear(pixels, at: offset) }
        let observed = RGBColor(premultipliedRed: pixels[offset], green: pixels[offset + 1],
                                blue: pixels[offset + 2], alpha: pixels[offset + 3])
        let recoveredColor = recovered(observed, key: key, coverage: coverage)
        let front = despilled(recoveredColor, key: key, isEdge: coverage < 1)
        let scale = alpha * Float(Raster.opaque)
        pixels[offset] = UInt8((front.red * scale).rounded())
        pixels[offset + 1] = UInt8((front.green * scale).rounded())
        pixels[offset + 2] = UInt8((front.blue * scale).rounded())
        pixels[offset + 3] = UInt8(scale.rounded())
    }

    /// 1 画素を透明にする。
    @inline(__always)
    static func clear(_ pixels: UnsafeMutableBufferPointer<UInt8>, at offset: Int) {
        pixels[offset] = 0
        pixels[offset + 1] = 0
        pixels[offset + 2] = 0
        pixels[offset + 3] = 0
    }

    /// 混ざった色から、前景の色を戻す（0〜1 に収める）。
    static func recovered(_ observed: RGBColor, key: RGBColor, coverage: Float) -> RGBColor {
        func channel(_ value: Float, _ keyValue: Float) -> Float {
            Swift.min(1, Swift.max(0, keyValue + (value - keyValue) / coverage))
        }
        return RGBColor(red: channel(observed.red, key.red), green: channel(observed.green, key.green),
                        blue: channel(observed.blue, key.blue))
    }

    /// 鮮やかな地（緑）の縁で、地の色でいちばん強い成分を、残りの大きいほうまで抑える。
    static func despilled(_ color: RGBColor, key: RGBColor, isEdge: Bool) -> RGBColor {
        guard isEdge, key.saturation >= vividKeySaturation else { return color }
        var result = color
        if key.green >= key.red, key.green >= key.blue {
            result.green = Swift.min(color.green, Swift.max(color.red, color.blue))
        } else if key.red >= key.blue {
            result.red = Swift.min(color.red, Swift.max(color.green, color.blue))
        } else {
            result.blue = Swift.min(color.blue, Swift.max(color.red, color.green))
        }
        return result
    }
}
