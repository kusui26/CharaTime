import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CTStore
@testable import CTStudio

/// 取り込んだ画像を読む（プラン §9 Phase 2 の 2-C ⑤-1）。何が来るか分からないので、形式・向き・大きさの
/// 端を押さえる。
@Suite("画像を読む")
struct ImageReadingTests {

    /// 単色の画像を、指定の形式・向き・色空間で書き出したデータ。
    static func encoded(width: Int, height: Int, type: UTType = .png, orientation: Int? = nil,
                        space: CFString = CGColorSpace.sRGB, bitsPerComponent: Int = 8) -> Data {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent,
                                bytesPerRow: 0, space: CGColorSpace(name: space)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(srgbRed: 1, green: 0.5, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil)!
        let properties = orientation.map { [kCGImagePropertyOrientation: $0] as CFDictionary }
        CGImageDestinationAddImage(destination, context.makeImage()!, properties)
        CGImageDestinationFinalize(destination)
        return output as Data
    }

    @Test("PNG をそのままの画素で読み、sRGB・8bit・乗算済みの形にする")
    func readsPNG() throws {
        let raster = try ImageReading.raster(from: Self.encoded(width: 40, height: 30))
        #expect(raster.size == PixelSize(width: 40, height: 30))
        // 上半分は透明、下半分は橙（Core Graphics の下半分を塗った）。
        #expect(raster.pixel(x: 5, y: 5) == [0, 0, 0, 0])
        #expect(raster.pixel(x: 5, y: 25) == [255, 128, 0, 255])
    }

    @Test("16bit・Display P3 の PNG も、sRGB・8bit に描き直して読める")
    func readsWideColor() throws {
        let data = Self.encoded(width: 20, height: 20, space: CGColorSpace.displayP3, bitsPerComponent: 16)
        let raster = try ImageReading.raster(from: data)
        #expect(raster.size == PixelSize(width: 20, height: 20))
        #expect(raster.alpha(x: 3, y: 15) == 255)
    }

    /// 写真アプリの絵は、画素を回さずに向きの情報（Exif）だけを持つことがある。
    @Test("向きの情報を解き、縦長に撮った絵は縦長に読む")
    func appliesOrientation() throws {
        let data = Self.encoded(width: 60, height: 20, type: .jpeg, orientation: 6)
        let raster = try ImageReading.raster(from: data)
        #expect(raster.size == PixelSize(width: 20, height: 60))
    }

    @Test("長辺 4096 を超える絵は、4096 まで縮めて読む")
    func downscalesLargeImages() throws {
        let raster = try ImageReading.raster(from: Self.encoded(width: 4400, height: 20))
        #expect(raster.width == ImageReading.maxWorkingLongSide)
    }

    @Test("長辺 8192 を超える絵は、展開せずに断る")
    func refusesHugeImages() {
        #expect(throws: StudioError.tooLarge(PixelSize(width: 8200, height: 4))) {
            try ImageReading.raster(from: Self.encoded(width: 8200, height: 4))
        }
    }

    @Test("画像でないものは断る")
    func refusesNonImages() {
        #expect(throws: StudioError.notAnImage) { try ImageReading.raster(from: Data("PNG ではない".utf8)) }
        #expect(throws: StudioError.notAnImage) { try ImageReading.raster(from: Data()) }
    }

    @Test("作業の絵は、PNG に書いて読み戻しても同じ画素")
    func pngRoundTrip() throws {
        let raster = try ImageReading.raster(from: Self.encoded(width: 16, height: 8))
        let restored = try ImageReading.raster(from: #require(raster.pngData()))
        #expect(restored == raster)
    }

    @Test("切り出しは、絵の外にはみ出した矩形を絵の中に収める")
    func cropsWithinBounds() throws {
        let raster = try ImageReading.raster(from: Self.encoded(width: 10, height: 10))
        let cropped = raster.cropped(to: PixelRect(x: 6, y: 6, width: 10, height: 10))
        #expect(cropped.size == PixelSize(width: 4, height: 4))
        #expect(cropped.pixel(x: 0, y: 0) == raster.pixel(x: 6, y: 6))
    }
}
