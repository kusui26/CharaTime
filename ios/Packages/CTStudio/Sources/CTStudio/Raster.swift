import Foundation
import CoreGraphics
import CTStore

/// 取り込みの作業に使う絵（プラン §9 Phase 2 の 2-C ⑤-1）。sRGB・8bit・**乗算済み** RGBA で、上の行から並ぶ。
///
/// 入口で必ずこの 1 つの形に描き直す（16bit・Display P3・グレーはここで落とす。パステルの平塗りでは差が
/// 見えない。調査 H §6）。乗算済みにそろえるのは、`CGContext` が 8bit の RGBA では乗算済みしか描けないのと、
/// 縮めるときに透明な画素の色が縁ににじまないため（H §6）。
public struct Raster: Sendable, Equatable, CustomStringConvertible {

    /// 1 画素のバイト数（R・G・B・A）。
    public static let bytesPerPixel = 4
    /// 不透明さの最大値。
    public static let opaque: UInt8 = 255

    public let width: Int
    public let height: Int
    /// 画素。R・G・B は A を掛けた値（乗算済み）。
    public internal(set) var pixels: [UInt8]

    /// 透明な絵。
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = [UInt8](repeating: 0, count: width * height * Self.bytesPerPixel)
    }

    init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height * Self.bytesPerPixel, "画素の数が大きさと合わない")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public var pixelCount: Int { width * height }

    /// 画素を並べない短い説明（テストの失敗の表示が、画素の配列で埋まらないように）。
    public var description: String { "Raster(\(width)×\(height))" }
    public var size: PixelSize { PixelSize(width: width, height: height) }

    /// (x, y) の不透明さ（0〜255。y は上から）。
    public func alpha(x: Int, y: Int) -> UInt8 {
        pixels[(y * width + x) * Self.bytesPerPixel + 3]
    }

    /// (x, y) の色（乗算済みの R・G・B・A）。
    public func pixel(x: Int, y: Int) -> [UInt8] {
        let offset = (y * width + x) * Self.bytesPerPixel
        return Array(pixels[offset..<offset + Self.bytesPerPixel])
    }

    /// 画素 1 つ（4 バイト）を写す。
    @inline(__always)
    static func copyPixel(from source: UnsafeBufferPointer<UInt8>, at from: Int,
                          to target: UnsafeMutableBufferPointer<UInt8>, at to: Int) {
        target[to] = source[from]
        target[to + 1] = source[from + 1]
        target[to + 2] = source[from + 2]
        target[to + 3] = source[from + 3]
    }

    /// 画素を 1 つの色（乗算済みの RGBA）で塗る。
    mutating func fill(_ indices: [Int], with color: [UInt8]) {
        for index in indices {
            for channel in 0..<Self.bytesPerPixel {
                pixels[index * Self.bytesPerPixel + channel] = color[channel]
            }
        }
    }

    /// 画素を、同じ大きさの別の絵の同じ画素で置き換える。
    mutating func fill(_ indices: [Int], from source: Raster) {
        for index in indices {
            let offset = index * Self.bytesPerPixel
            pixels.replaceSubrange(offset..<offset + Self.bytesPerPixel,
                                   with: source.pixels[offset..<offset + Self.bytesPerPixel])
        }
    }

    /// 矩形を切り出す（矩形は絵の中に収める）。
    public func cropped(to rect: PixelRect) -> Raster {
        let left = Swift.max(0, rect.x), top = Swift.max(0, rect.y)
        let right = Swift.min(width, rect.x + rect.width), bottom = Swift.min(height, rect.y + rect.height)
        guard right > left, bottom > top else { return Raster(width: 0, height: 0) }
        let rowBytes = (right - left) * Self.bytesPerPixel
        let rows = (top..<bottom).flatMap { y -> ArraySlice<UInt8> in
            let start = (y * width + left) * Self.bytesPerPixel
            return pixels[start..<start + rowBytes]
        }
        return Raster(width: right - left, height: bottom - top, pixels: rows)
    }
}

// MARK: - Core Graphics との受け渡し

public extension Raster {

    /// 描き直しに使う色空間（sRGB）。
    static let colorSpace: CGColorSpace? = CGColorSpace(name: CGColorSpace.sRGB)
    /// 8bit の RGBA を乗算済みで持つ（`CGContext` が描ける形。H §6）。
    static let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    /// CGImage を、この形（sRGB・8bit・乗算済み）に描き直す。描けなければ nil。
    init?(cgImage: CGImage) {
        var raster = Raster(width: cgImage.width, height: cgImage.height)
        let drawn = raster.draw { context in
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        }
        guard drawn else { return nil }
        self = raster
    }

    /// CGImage にする。作れなければ nil。
    var cgImage: CGImage? {
        guard let space = Self.colorSpace, width > 0, height > 0,
              let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8,
                       bitsPerPixel: Self.bytesPerPixel * 8, bytesPerRow: width * Self.bytesPerPixel,
                       space: space, bitmapInfo: CGBitmapInfo(rawValue: Self.bitmapInfo), provider: provider,
                       decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// この絵の画素に Core Graphics で描く。座標は Core Graphics のまま（原点は左下）。描けなければ false。
    mutating func draw(_ body: (CGContext) -> Void) -> Bool {
        guard let space = Self.colorSpace, width > 0, height > 0 else { return false }
        let (columns, rows) = (width, height)
        return pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: columns, height: rows,
                                          bitsPerComponent: 8, bytesPerRow: columns * Self.bytesPerPixel,
                                          space: space, bitmapInfo: Self.bitmapInfo) else { return false }
            body(context)
            return true
        }
    }
}
