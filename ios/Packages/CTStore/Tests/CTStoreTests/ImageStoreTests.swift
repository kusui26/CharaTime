import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import CTStore

/// 画像は「ユーザーが選んだもの」なので、何が来るか分からない。
/// **大きすぎるもの・画像でないもの・置き場が無い場合**を押さえておく。
@Suite("画像の置き場")
struct ImageStoreTests {

    static func temporaryStore() -> ImageStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ct-images-\(UUID().uuidString)")
        return ImageStore(directory: directory)
    }

    /// 単色の PNG を作る。テストのための素材。
    static func makePNG(width: Int, height: Int) -> Data? {
        let bytesPerRow = width * 4
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(CGColor(red: 0.9, green: 0.6, blue: 0.3, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    @Test("取り込んだ画像を読み返せる")
    func storeAndLoad() throws {
        let store = Self.temporaryStore()
        let data = try #require(Self.makePNG(width: 400, height: 800))
        #expect(!store.exists("room"))
        try store.store(data, as: "room")
        #expect(store.exists("room"))
        let loaded = try #require(store.load("room"))
        #expect(loaded.width == 400)
        #expect(loaded.height == 800)
    }

    @Test("長辺が上限を超える画像は縮めて置く")
    func largeImagesAreScaledDown() throws {
        let store = Self.temporaryStore()
        let longSide = ImageStore.maxPixelSize * 2
        let data = try #require(Self.makePNG(width: longSide, height: longSide / 2))
        try store.store(data, as: "big")
        let loaded = try #require(store.load("big"))
        #expect(Swift.max(loaded.width, loaded.height) == ImageStore.maxPixelSize)
        // 縦横比は保たれる。
        #expect(abs(Double(loaded.width) / Double(loaded.height) - 2.0) < 0.02)
    }

    @Test("上限より小さい画像は引き伸ばさない")
    func smallImagesKeepTheirSize() throws {
        let store = Self.temporaryStore()
        let data = try #require(Self.makePNG(width: 300, height: 200))
        try store.store(data, as: "small")
        let loaded = try #require(store.load("small"))
        #expect(loaded.width == 300)
        #expect(loaded.height == 200)
    }

    @Test("画像でないものは断る")
    func rejectsNonImages() {
        let store = Self.temporaryStore()
        let junk = Data("これは画像ではありません".utf8)
        #expect(throws: ImageStore.StoreError.notAnImage) { try store.store(junk, as: "junk") }
        #expect(throws: ImageStore.StoreError.notAnImage) { try store.store(Data(), as: "empty") }
    }

    @Test("置き場が無いときは、どの App Group かを添えて断る")
    func reportsMissingContainer() throws {
        let store = ImageStore(directory: nil)
        let data = try #require(Self.makePNG(width: 10, height: 10))
        #expect(throws: ImageStore.StoreError.noContainer(appGroup: AppGroup.identifier)) {
            try store.store(data, as: "x")
        }
        #expect(store.load("x") == nil)
        #expect(!store.exists("x"))
    }

    @Test("読めない名前を渡しても落ちない")
    func loadingUnknownNameReturnsNil() {
        let store = Self.temporaryStore()
        #expect(store.load("いない") == nil)
        store.remove("いない")          // 消しても落ちない
    }

    @Test("使われていない画像だけを消す")
    func removesOnlyUnusedImages() throws {
        let store = Self.temporaryStore()
        let data = try #require(Self.makePNG(width: 40, height: 40))
        for name in ["keep", "drop-1", "drop-2"] { try store.store(data, as: name) }
        store.removeAll(keeping: ["keep"])
        #expect(store.exists("keep"))
        #expect(!store.exists("drop-1"))
        #expect(!store.exists("drop-2"))
    }

    @Test("同じ名前で置き直すと入れ替わる")
    func storingTwiceReplaces() throws {
        let store = Self.temporaryStore()
        try store.store(try #require(Self.makePNG(width: 100, height: 100)), as: "room")
        try store.store(try #require(Self.makePNG(width: 220, height: 140)), as: "room")
        let loaded = try #require(store.load("room"))
        #expect(loaded.width == 220)
        #expect(loaded.height == 140)
    }
}
