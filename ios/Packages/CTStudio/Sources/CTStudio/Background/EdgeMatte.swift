import Foundation

/// 抜いた地との境の画素の、不透明さと色を決める（プラン §9 Phase 2 の 2-C ⑤-2。調査 H §2 を 2026-09-28 に改めた）。
///
/// 境の画素は、体の色 F と地の色 K が、覆う割合 α で混ざった色 C＝αF＋(1−α)K になっている。F を近くの内側の
/// 画素から取れば、**α は C−K を F−K に映した長さ**で決まり、縁の太さが元の絵と同じになる（地の色からの距離に
/// 比例させるだけだと、濃い輪郭線の縁で α を高く見積もり、縁が 0.5 画素ほど太った。見本で測った）。
/// 色は F で塗る（にじみ取り。混ざった色のまま残すと、白い地は白い線、緑の地は緑の線になって縁に見える）。
///
/// 境として扱うのは、地の側の柔らかい帯（地の色からの距離が `ColorKey.clearDistance` 以上）と、体の側の 2 画素。
enum EdgeMatte {

    /// 体の側で境として扱う深さ（地から 8 近傍で数えた画素）。縮めて描かれた絵の縁は 1〜2 画素にぼける。
    static let depth: Int8 = 2
    /// 体の色を探す範囲（画素の半径）。境の画素から、2 画素内側まで届く。
    static let searchRadius = 2

    /// 画素の印。地（透明にする）・地の側の柔らかい帯・体の側の輪（1〜`depth`）・内側（触らない）。
    static let clearMark: Int8 = -1
    static let softMark: Int8 = 0
    static let innerMark: Int8 = depth + 1

    /// 地から数えた画素の印を付ける。1 つ外の輪を 1 画素太らせ（vImage）、内側と重なった画素を次の輪にする。
    static func marks(width: Int, height: Int, background: [Bool], distances: [Float]) -> [Int8] {
        var marks = [Int8](repeating: innerMark, count: background.count)
        var outer = [UInt8](repeating: 0, count: background.count)
        marks.withUnsafeMutableBufferPointer { marks in
            outer.withUnsafeMutableBufferPointer { outer in
                background.withUnsafeBufferPointer { background in
                    distances.withUnsafeBufferPointer { distances in
                        eachIndex(background.count) { index in
                            guard background[index] else { return }
                            marks[index] = distances[index] < ColorKey.clearDistance ? clearMark : softMark
                            outer[index] = Morphology.marked
                        }
                    }
                }
            }
        }
        for ring in 1...depth {
            let near = Morphology.dilated(outer, width: width, height: height, radius: 1)
            outer = mark(ring, in: &marks, where: near)
        }
        return marks
    }

    /// 内側の画素のうち `near` に入るものに `ring` の印を付け、付けた画素の印（次の輪の外側）を返す。
    static func mark(_ ring: Int8, in marks: inout [Int8], where near: [UInt8]) -> [UInt8] {
        var ringPixels = [UInt8](repeating: 0, count: marks.count)
        marks.withUnsafeMutableBufferPointer { marks in
            near.withUnsafeBufferPointer { near in
                ringPixels.withUnsafeMutableBufferPointer { ringPixels in
                    eachIndex(marks.count) { index in
                        guard marks[index] == innerMark, near[index] != 0 else { return }
                        marks[index] = ring
                        ringPixels[index] = Morphology.marked
                    }
                }
            }
        }
        return ringPixels
    }

    /// 地を透明にし、境の画素の不透明さと色を決める。内側は触らない。
    static func apply(to raster: inout Raster, keys: [RGBColor], nearestKeys: [Int], marks: [Int8]) {
        let source = raster.pixels
        let (width, height) = (raster.width, raster.height)
        raster.pixels.withUnsafeMutableBufferPointer { pixels in
            source.withUnsafeBufferPointer { source in
                marks.withUnsafeBufferPointer { marks in
                    let matting = Matting(source: source, marks: marks, width: width, height: height)
                    eachIndex(marks.count) { index in
                        switch marks[index] {
                        case innerMark: return
                        case clearMark: ColorKey.clear(pixels, at: index &* Raster.bytesPerPixel)
                        default: matting.matte(pixels, at: index, key: keys[nearestKeys[index]])
                        }
                    }
                }
            }
        }
    }
}

/// 境の画素 1 つぶんの計算（元の画素と印を読むだけ）。
private struct Matting {
    let source: UnsafeBufferPointer<UInt8>
    let marks: UnsafeBufferPointer<Int8>
    let width: Int
    let height: Int

    /// 覆う割合を求めて、体の色で塗る。近くに体の色が無ければ、地の側は距離に比例させ、体の側は触らない。
    func matte(_ pixels: UnsafeMutableBufferPointer<UInt8>, at index: Int, key: RGBColor) {
        let offset = index * Raster.bytesPerPixel
        let observed = color(at: index)
        guard let front = frontColor(around: index, key: key) else {
            if marks[index] == EdgeMatte.softMark {
                ColorKey.unmix(pixels, at: offset, distance: observed.distance(to: key), key: key)
            }
            return
        }
        let alpha = coverage(of: observed, front: front, key: key) * Float(source[offset + 3])
        guard alpha >= 1 else { return ColorKey.clear(pixels, at: offset) }
        pixels[offset] = UInt8((front.red * alpha).rounded())
        pixels[offset + 1] = UInt8((front.green * alpha).rounded())
        pixels[offset + 2] = UInt8((front.blue * alpha).rounded())
        pixels[offset + 3] = UInt8(alpha.rounded())
    }

    /// C−K を F−K に映した長さ（0〜1）。
    func coverage(of observed: RGBColor, front: RGBColor, key: RGBColor) -> Float {
        let toFront = (front.red - key.red, front.green - key.green, front.blue - key.blue)
        let dot = (observed.red - key.red) * toFront.0 + (observed.green - key.green) * toFront.1
            + (observed.blue - key.blue) * toFront.2
        let length = toFront.0 * toFront.0 + toFront.1 * toFront.1 + toFront.2 * toFront.2
        return Swift.min(1, Swift.max(0, dot / length))
    }

    /// 自分より内側の画素のうち、地の色からいちばん遠い色（混ざりのいちばん少ない体の色）。
    /// 地の色から `ColorKey.solidDistance` 以上離れていなければ、体の色とみなさない（地のむら）。
    func frontColor(around index: Int, key: RGBColor) -> RGBColor? {
        let x = index % width, y = index / width, own = marks[index], reach = EdgeMatte.searchRadius
        var best: (color: RGBColor, distance: Float)?
        for row in Swift.max(0, y - reach)...Swift.min(height - 1, y + reach) {
            for column in Swift.max(0, x - reach)...Swift.min(width - 1, x + reach) {
                let neighbor = row * width + column
                guard marks[neighbor] > own else { continue }
                let candidate = color(at: neighbor)
                let distance = candidate.distance(to: key)
                if distance > best?.distance ?? ColorKey.solidDistance { best = (candidate, distance) }
            }
        }
        return best?.color
    }

    func color(at index: Int) -> RGBColor {
        let offset = index * Raster.bytesPerPixel
        return RGBColor(premultipliedRed: source[offset], green: source[offset + 1],
                        blue: source[offset + 2], alpha: source[offset + 3])
    }
}
