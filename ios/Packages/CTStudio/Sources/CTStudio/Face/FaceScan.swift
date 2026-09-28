import Foundation

/// 顔を探す材料（hero の絵 1 枚ぶん）。暗い画素の塊と、そのうち絵の外（透明）に触れる塊（輪郭線）。
///
/// 目・閉じた目の弧・輪郭線は、どれも濃い色で描かれる（テンプレートのキャラカードは輪郭線 #3B2B2B、目は黒い点）。
/// 体の色はそれより明るい（いまの 5 体でいちばん暗いクマオの影でも明るさ 0.54）。
struct FaceScan {

    /// 暗い画素とみなす明るさの上限。輪郭線 #3B2B2B（0.18）と、いまの 5 体でいちばん暗い体の色（0.54）の間。
    static let darkLuminance: Float = 0.35

    let image: Raster
    let components: ComponentLabels
    /// 暗い塊（番号の順。`labels` は 1 つずつ）。
    let blobs: [Blob]
    /// 絵の外に触れる暗い塊の番号（輪郭線と、輪郭線につながった線）。
    let outlineLabels: Set<Int32>
    /// 番号ごとに、輪郭線か（画素ごとに引くので、集合でなく配列で持つ）。
    let isOutline: [Bool]

    init(_ image: Raster) {
        let dark = Self.darkMask(of: image)
        let components = ComponentLabels(mask: dark, width: image.width, height: image.height)
        let outline = Self.labelsTouchingOutside(image, components: components)
        self.image = image
        self.components = components
        self.blobs = BlobScanner(components: components, opaque: dark).blobs()
        self.outlineLabels = outline
        self.isOutline = (0...components.count).map { outline.contains(Int32($0)) }
    }

    /// 不透明さ 0.5 以上で、暗い画素の印（0 か 255）。乗算済みの値のまま比べる（明るさ × 不透明さ で割らずに）。
    static func darkMask(of image: Raster) -> [UInt8] {
        var mask = [UInt8](repeating: 0, count: image.pixelCount)
        image.pixels.withUnsafeBufferPointer { pixels in
            mask.withUnsafeMutableBufferPointer { mask in
                eachIndex(mask.count) { index in
                    let offset = index &* Raster.bytesPerPixel
                    let alpha = Float(pixels[offset + 3])
                    guard alpha >= 128 else { return }
                    let weighted = 0.2126 * Float(pixels[offset]) + 0.7152 * Float(pixels[offset + 1])
                        + 0.0722 * Float(pixels[offset + 2])
                    if weighted < darkLuminance * alpha { mask[index] = Morphology.marked }
                }
            }
        }
        return mask
    }

    /// 絵の外（不透明さ 0.5 未満）を 1 画素太らせて、重なる暗い塊の番号。
    static func labelsTouchingOutside(_ image: Raster, components: ComponentLabels) -> Set<Int32> {
        var outside = [UInt8](repeating: 0, count: image.pixelCount)
        image.pixels.withUnsafeBufferPointer { pixels in
            outside.withUnsafeMutableBufferPointer { outside in
                eachIndex(outside.count) { index in
                    if pixels[index &* Raster.bytesPerPixel &+ 3] < 128 { outside[index] = Morphology.marked }
                }
            }
        }
        let near = Morphology.dilated(outside, width: image.width, height: image.height, radius: 1)
        var touching = [Bool](repeating: false, count: components.count + 1)
        touching.withUnsafeMutableBufferPointer { touching in
            components.labels.withUnsafeBufferPointer { labels in
                near.withUnsafeBufferPointer { near in
                    eachIndex(near.count) { index in
                        if near[index] != 0 { touching[Int(labels[index])] = true }
                    }
                }
            }
        }
        return Set(touching.indices.dropFirst().filter { touching[$0] }.map { Int32($0) })
    }

    /// 輪郭線の色（輪郭線の不透明な画素の、成分ごとの中央値）。輪郭線が無ければ暗い茶色（テンプレートの #3B2B2B）。
    var outlineColor: RGBColor {
        var histogram = ChannelHistogram()
        isOutline.withUnsafeBufferPointer { isOutline in
            components.labels.withUnsafeBufferPointer { labels in
                image.pixels.withUnsafeBufferPointer { pixels in
                    eachIndex(labels.count) { index in
                        let offset = index &* Raster.bytesPerPixel
                        let isOpaque = pixels[offset + 3] == Raster.opaque
                        if isOutline[Int(labels[index])] && isOpaque { histogram.add(pixels, at: offset) }
                    }
                }
            }
        }
        return histogram.median ?? Self.templateOutline
    }

    /// テンプレートのキャラカードの輪郭線（#3B2B2B）。
    static let templateOutline = RGBColor(red: 0x3B / 255, green: 0x2B / 255, blue: 0x2B / 255)
}

/// 成分ごとの度数（0〜255）。画素を並べて並べ替えずに、中央値を求める。
struct ChannelHistogram {
    private var counts = [[Int]](repeating: [Int](repeating: 0, count: 256), count: 3)
    private var total = 0

    mutating func add(_ pixels: UnsafeBufferPointer<UInt8>, at offset: Int) {
        counts[0][Int(pixels[offset])] += 1
        counts[1][Int(pixels[offset + 1])] += 1
        counts[2][Int(pixels[offset + 2])] += 1
        total += 1
    }

    /// 成分ごとの中央値（0〜1）。1 つも無ければ nil。
    var median: RGBColor? {
        guard total > 0 else { return nil }
        let values = counts.map { channel -> Float in
            var seen = 0
            let middle = channel.firstIndex { count in
                seen += count
                return seen > total / 2
            } ?? 0
            return Float(middle) / Float(Raster.opaque)
        }
        return RGBColor(red: values[0], green: values[1], blue: values[2])
    }
}
