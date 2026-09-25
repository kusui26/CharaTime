import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import CTStore

/// 透過背景の材料（壁紙のスクショ）の取り込みと切り抜き（プラン §9 Phase 3 の 3-C ⑦、3-3）。
@Suite("透過背景の取り込み")
struct WallpaperStoreTests {

    static let large = WidgetSlot(family: .large, column: 0, row: 0)
    static let medium = WidgetSlot(family: .medium, column: 0, row: 2)
    /// 大の枠（ラベルあり）の左上と右下。印を付けて、切り抜きの向きと位置を確かめる。
    static let largeTopLeft = (x: 79, y: 270)
    static let largeBottomRight = (x: 79 + 1049 - 1, y: 270 + 1095 - 1)

    static func temporaryStore() -> WallpaperStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ct-wallpaper-\(UUID().uuidString)")
        return WallpaperStore(images: ImageStore(directory: directory))
    }

    /// 印を付ける 1 画素（上から数えた y）。
    struct Mark {
        let x: Int
        let y: Int
        let color: [UInt8]
    }

    /// 1206×2622 の壁紙のスクショのまね。灰色の地に、`marks` の画素だけ色を付ける。
    static func screenshot(width: Int = 1206, height: Int = 2622, marks: [Mark] = []) -> Data {
        var pixels = [UInt8](repeating: 128, count: width * height * 4)
        for index in stride(from: 3, to: pixels.count, by: 4) { pixels[index] = 255 }
        for mark in marks {
            let offset = (mark.y * width + mark.x) * 4
            pixels.replaceSubrange(offset..<offset + 3, with: mark.color)
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return output as Data
    }

    /// 画像の (x, y) の色（上から数えた y。RGB）。
    static func color(of image: CGImage, x: Int, y: Int) -> [UInt8] {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // 1 画素の板に、(x, y) がちょうど重なるように描く（CoreGraphics の y は下から）。
        context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
        return Array(pixel.prefix(3))
    }

    static let red: [UInt8] = [255, 0, 0]
    static let blue: [UInt8] = [0, 0, 255]

    // MARK: - 取り込む

    @Test("取り込むと、スクショを保存し、ページのいちばん上の大の枠で切り抜いて、設定に名前を書く")
    func importsAndCrops() throws {
        let store = Self.temporaryStore()
        let data = Self.screenshot(marks: [Mark(x: Self.largeTopLeft.x, y: Self.largeTopLeft.y, color: Self.red),
                                           Mark(x: Self.largeBottomRight.x, y: Self.largeBottomRight.y,
                                                color: Self.blue)])
        let settings = try store.importScreenshot(data, as: .light, style: .labeled, into: WidgetSettings(),
                                                  stamp: "1")
        #expect(settings.wallpaper.light == "wallpaper-light-1")
        #expect(settings.iconStyle == .labeled)
        #expect(settings.slots.map(\.slot) == [Self.large])
        let large = try #require(settings.slot(for: .large))
        #expect(large.frame == PixelRect(x: 79, y: 270, width: 1049, height: 1095))
        let cropName = try #require(large.crops.light)
        let crop = try #require(store.images.load(cropName))
        #expect(crop.width == 1049 && crop.height == 1095)
        // 左上の印は切り抜きの左上に、右下の印は右下に来る（上下が逆さにならない）。
        #expect(Self.color(of: crop, x: 0, y: 0) == Self.red)
        #expect(Self.color(of: crop, x: 1048, y: 1094) == Self.blue)
        #expect(store.images.exists("wallpaper-light-1"))
    }

    @Test("ダークをあとから取り込むと、ライトの切り抜きを残したまま、同じ枠でダークを足す")
    func addsTheDarkAppearance() throws {
        let store = Self.temporaryStore()
        let light = try store.importScreenshot(Self.screenshot(), as: .light, style: .labeled,
                                               into: WidgetSettings(), stamp: "1")
        let both = try store.importScreenshot(Self.screenshot(), as: .dark, style: .labeled, into: light, stamp: "2")
        #expect(both.wallpaper == AppearanceImages(light: "wallpaper-light-1", dark: "wallpaper-dark-2"))
        let large = try #require(both.slot(for: .large))
        #expect(large.frame == light.slot(for: .large)?.frame)
        #expect(large.crops.light != nil && large.crops.dark != nil)
    }

    /// 別の機種のスクショや、写真を選んでしまったとき。位置の分からない枠では切り抜かない。
    @Test("表の無い大きさの画像や、画像でないものは、理由を付けて断る")
    func rejectsWhatItCannotUse() {
        let store = Self.temporaryStore()
        #expect(throws: WallpaperStore.ImportError.unknownScreen(width: 1179, height: 2556)) {
            try store.importScreenshot(Self.screenshot(width: 1179, height: 2556), as: .light, style: .labeled,
                                       into: WidgetSettings(), stamp: "1")
        }
        #expect(throws: WallpaperStore.ImportError.notAnImage) {
            try store.importScreenshot(Data("壁紙ではない".utf8), as: .light, style: .labeled,
                                       into: WidgetSettings(), stamp: "1")
        }
    }

    // MARK: - 寄せる・ラベルの有無を変える

    @Test("枠を寄せると、保存してある壁紙から、ライトもダークも切り抜き直す")
    func recropsWhenNudged() throws {
        let store = Self.temporaryStore()
        let mark = Mark(x: Self.largeTopLeft.x + 2, y: Self.largeTopLeft.y + 1, color: Self.red)
        var settings = try store.importScreenshot(Self.screenshot(marks: [mark]), as: .light, style: .labeled,
                                                  into: WidgetSettings(), stamp: "1")
        settings = try store.importScreenshot(Self.screenshot(marks: [mark]), as: .dark, style: .labeled,
                                              into: settings, stamp: "2")
        let nudged = try store.recrop(settings, nudging: [Self.large: PixelOffset(dx: 2, dy: 1)], stamp: "3")
        let large = try #require(nudged.slot(for: .large))
        #expect(large.frame == PixelRect(x: 81, y: 271, width: 1049, height: 1095))
        for name in [large.crops.light, large.crops.dark] {
            let crop = try #require(name.flatMap(store.images.load))
            #expect(Self.color(of: crop, x: 0, y: 0) == Self.red)
        }
    }

    /// D-31 より前は、中（3 段目）も切り抜いていた。切り抜き直すときに外し、ファイルは片づけが消す。
    @Test("前に作った中の切り抜きは、切り抜き直すと設定から外れる")
    func dropsTheOldMediumCrop() throws {
        let store = Self.temporaryStore()
        var settings = try store.importScreenshot(Self.screenshot(), as: .light, style: .labeled,
                                                  into: WidgetSettings(), stamp: "1")
        settings.slots.append(SlotSetting(slot: Self.medium, frame: PixelRect(x: 79, y: 1474, width: 1049, height: 493),
                                          crops: AppearanceImages(light: "crop-medium-0-2-light-1")))
        let recropped = try store.recrop(settings, nudging: [Self.large: PixelOffset(dx: 1, dy: 0)], stamp: "2")
        #expect(recropped.slots.map(\.slot) == [Self.large])
        #expect(!recropped.imageNames.contains("crop-medium-0-2-light-1"))
    }

    @Test("ラベルの有無を変えると、別の表の枠で切り抜き直す（寄せた分は捨てる）")
    func switchesTheIconStyle() throws {
        let store = Self.temporaryStore()
        let settings = try store.importScreenshot(Self.screenshot(), as: .light, style: .labeled,
                                                  into: WidgetSettings(), stamp: "1")
        let nudged = try store.recrop(settings, nudging: [Self.large: PixelOffset(dx: 3, dy: 0)], stamp: "2")
        let switched = try store.recrop(nudged, style: .labelFree, stamp: "3")
        #expect(switched.iconStyle == .labelFree)
        #expect(switched.slot(for: .large)?.frame == PixelRect(x: 64, y: 270, width: 1079, height: 1077))
        let crop = try #require(switched.slot(for: .large)?.crops.light.flatMap(store.images.load))
        #expect(crop.width == 1079 && crop.height == 1077)
    }

    /// 端まで寄せても、スクショの外は切り抜かない。
    @Test("寄せすぎた枠は、スクショの内側に収める")
    func clampsTheNudge() throws {
        let store = Self.temporaryStore()
        let settings = try store.importScreenshot(Self.screenshot(), as: .light, style: .labeled,
                                                  into: WidgetSettings(), stamp: "1")
        let nudged = try store.recrop(settings, nudging: [Self.large: PixelOffset(dx: -500, dy: -500)],
                                      stamp: "2")
        #expect(nudged.slot(for: .large)?.frame == PixelRect(x: 0, y: 0, width: 1049, height: 1095))
    }

    // MARK: - やめる

    @Test("やめると、壁紙と切り抜きとラベルの有無を外す（ファイルは片づけが消す）")
    func removesTransparency() throws {
        let store = Self.temporaryStore()
        let settings = try store.importScreenshot(Self.screenshot(), as: .light, style: .labeled,
                                                  into: WidgetSettings(pseudoAnimation: true), stamp: "1")
        let removed = settings.removingTransparency()
        #expect(removed.wallpaper == AppearanceImages())
        #expect(removed.slots.isEmpty)
        #expect(removed.iconStyle == nil)
        #expect(removed.pseudoAnimation == true)
        #expect(removed.imageNames.isEmpty)
    }
}
