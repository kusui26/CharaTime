import Foundation

/// 色（0〜1。乗算を戻した値）。
struct RGBColor: Equatable, Sendable {
    var red: Float
    var green: Float
    var blue: Float

    static let white = RGBColor(red: 1, green: 1, blue: 1)

    /// 乗算済みの 8bit の画素から、乗算を戻して作る。透明な画素は黒。
    init(premultipliedRed red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        let scale: Float = alpha == 0 ? 0 : 1 / Float(alpha)
        self.red = Float(red) * scale
        self.green = Float(green) * scale
        self.blue = Float(blue) * scale
    }

    init(red: Float, green: Float, blue: Float) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// 色どうしの距離（RGB の空間でのユークリッド距離。0〜√3）。調査 H §2 の物差し。
    func distance(to other: RGBColor) -> Float {
        let dr = red - other.red, dg = green - other.green, db = blue - other.blue
        return (dr * dr + dg * dg + db * db).squareRoot()
    }

    /// 明るさ（sRGB の輝度の近似。Rec. 709 の係数）。
    var luminance: Float { 0.2126 * red + 0.7152 * green + 0.0722 * blue }

    /// いちばん強い成分と、いちばん弱い成分の差。緑の地のような鮮やかな地を見分ける。
    var saturation: Float { Swift.max(red, green, blue) - Swift.min(red, green, blue) }
}

/// 絵の縁の帯。背景の手がかりはここだけで取る（調査 H §2「縁の色から背景色を推し量る」）。
struct BorderBand {

    /// 帯の太さの上限（画素）。H の実測は 2048 四方で 8 画素。
    static let maxThickness = 8
    /// 小さい絵では、短辺のこの割合まで細くする（テストの小さな見本でも、帯が絵を覆い尽くさない）。
    static let thicknessShare = 16

    let colors: [RGBColor]
    let alphas: [UInt8]

    init(_ raster: Raster) {
        let shortSide = Swift.min(raster.width, raster.height)
        let band = Swift.max(1, Swift.min(Self.maxThickness, shortSide / Self.thicknessShare))
        let indices = Self.borderIndices(width: raster.width, height: raster.height, band: band)
        (colors, alphas) = raster.pixels.withUnsafeBufferPointer { pixels in
            (indices.map { index in
                let offset = index * Raster.bytesPerPixel
                return RGBColor(premultipliedRed: pixels[offset], green: pixels[offset + 1],
                                blue: pixels[offset + 2], alpha: pixels[offset + 3])
            }, indices.map { pixels[$0 * Raster.bytesPerPixel + 3] })
        }
    }

    /// 縁から `band` 画素以内の画素の番号（上から、左から）。
    static func borderIndices(width: Int, height: Int, band: Int) -> [Int] {
        (0..<height).flatMap { y -> [Int] in
            guard y >= band, y < height - band else { return Array(y * width..<(y + 1) * width) }
            let left = y * width..<(y * width + Swift.min(band, width))
            let right = Swift.max(y * width + band, (y + 1) * width - band)..<(y + 1) * width
            return Array(left) + Array(right)
        }
    }

    /// 透明な画素（不透明さが `clearBelow` 未満）の割合。
    func transparentShare(clearBelow: UInt8) -> Float {
        guard !alphas.isEmpty else { return 0 }
        return Float(alphas.filter { $0 < clearBelow }.count) / Float(alphas.count)
    }

    /// 見えている画素の色の、成分ごとの中央値。見えている画素が無ければ nil。
    func medianColor(visibleFrom: UInt8) -> RGBColor? {
        let visible = zip(colors, alphas).filter { $0.1 >= visibleFrom }.map(\.0)
        guard !visible.isEmpty else { return nil }
        func median(_ values: [Float]) -> Float { values.sorted()[values.count / 2] }
        return RGBColor(red: median(visible.map(\.red)), green: median(visible.map(\.green)),
                        blue: median(visible.map(\.blue)))
    }

    /// 帯の画素のうち、どれかの色から `distance` 以内の割合。
    func share(near keys: [RGBColor], within distance: Float) -> Float {
        guard !colors.isEmpty else { return 0 }
        let near = zip(colors, alphas).filter { color, alpha in
            alpha > 0 && keys.contains { color.distance(to: $0) < distance }
        }
        return Float(near.count) / Float(colors.count)
    }
}
