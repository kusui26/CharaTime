import Testing
import Foundation
import CoreGraphics
@testable import CTStudio

/// まばたきと寝息の 2 コマ目（プラン §9 Phase 2 の 2-C ⑤-6、D-38）。見本は、いまの 5 体の hero（正解が分かっている）。
@Suite("まばたきと寝息")
struct FaceTests {

    /// `design/chara.py` の目（中心 (44, 64) と (76, 64)、直径 13）を、枠の余白 5 を足して 4.5 倍した位置（hero）。
    static let eyeCenters = [(x: 220.5, y: 310.5), (x: 364.5, y: 310.5)]
    static let eyeWidth = 58.5
    /// `design/chara.py` の `EYE_REGION`（34, 54, 86, 76）を hero にした範囲。いまのまばたきの差分を作る範囲。
    static let eyeRegion = PixelBox(left: 175, top: 265, right: 410, bottom: 365)

    static func hero(_ name: String) throws -> Raster {
        try #require(Raster(cgImage: Samples.bundled(name)))
    }

    static func eyes(in image: Raster) throws -> (eyes: [Eye]?, scan: FaceScan) {
        let scan = FaceScan(image)
        return (EyeFinder.find(in: scan, figure: try #require(FigureMetrics(image))), scan)
    }

    /// 目を開けた絵と、アプリが作ったまばたきの絵。
    struct Blinked {
        let open: Raster
        let blink: Raster
        let regions: [PixelBox]
    }

    static func blinked(_ name: String) throws -> Blinked {
        let open = try hero(name)
        let found = try eyes(in: open)
        let eyes = try #require(found.eyes)
        let painted = try #require(BlinkPainter.blinked(open, eyes: eyes, scan: found.scan))
        return Blinked(open: open, blink: painted.image, regions: painted.regions)
    }

    @Test("目を開けた正面の絵から、2 つの目を見つける", arguments: ["piyo", "mochi", "fuwa", "chip"])
    func findsBothEyes(id: String) throws {
        for pose in ["idle_01", "sit_01"] {
            let found = try Self.eyes(in: Self.hero("\(id)_\(pose)"))
            let eyes = try #require(found.eyes, "\(id)_\(pose)")
            for (eye, center) in zip(eyes, Self.eyeCenters) {
                #expect(abs(eye.box.centerX - center.x) <= 1, "\(id)_\(pose)")
                #expect(abs(eye.box.centerY - center.y) <= 1, "\(id)_\(pose)")
                #expect(abs(Double(eye.box.width) - Self.eyeWidth) <= 2, "\(id)_\(pose)")
            }
        }
    }

    /// 目を消すと、隠れていた線と面を描き直すことになる。1 色で埋めると染みと欠けが残るので、作らない（F-EYES を勧める）。
    @Test("目がほかの線に重なる子（いまのクマオは、目の下半分がマズルに重なる）は、目を見つけない")
    func eyesOverlappingOtherLinesAreNotUsed() throws {
        for pose in ["idle_01", "sit_01"] {
            #expect(try Self.eyes(in: Self.hero("kumao_\(pose)")).eyes == nil, "\(pose)")
        }
    }

    @Test("目のまわりが 1 色でない（色の境の上にある）ときは、まばたきを作らない")
    func blinkNeedsUniformSkinAroundTheEye() throws {
        var image = try Self.hero("piyo_idle_01")
        // 左の目の左半分のまわりの肌を、ほっぺの色に塗る（目の上を色の境が通る）。
        let body = image.pixel(x: 220, y: 250)
        for y in 250..<372 {
            for x in 150..<221 where image.pixel(x: x, y: y) == body {
                image.fill([y * image.width + x], with: [255, 179, 198, 255])
            }
        }
        let found = try Self.eyes(in: image)
        let eyes = try #require(found.eyes)
        #expect(BlinkPainter.blinked(image, eyes: eyes, scan: found.scan) == nil)
    }

    @Test("目を閉じた絵・横向きの絵では、目を見つけない（閉じた目の弧を目と取り違えない）")
    func findsNoEyesWhenClosedOrSideways() throws {
        for name in ["piyo_sleep_01", "kumao_sleep_01", "chip_happy_01", "fuwa_happy_02", "mochi_walk_01"] {
            #expect(try Self.eyes(in: Self.hero(name)).eyes == nil, "\(name)")
        }
    }

    @Test("まばたきの絵は目のまわりだけが変わり、弧はいまのまばたきの絵（design/chara.py）と同じ形になる")
    func blinkMatchesTheBundledBlink() throws {
        let painted = try Self.blinked("piyo_idle_01")
        let changed = EyelidOverlay.differingPixels(painted.open, painted.blink)
        let outside = changed.indices.filter { changed[$0] }.filter { index in
            !Self.eyeRegion.contains(x: index % painted.open.width, y: index / painted.open.width)
        }
        #expect(outside.isEmpty)
        let truth = try Self.hero("piyo_idle_02")
        let ours = Self.darkPixels(painted.blink, in: Self.eyeRegion)
        let theirs = Self.darkPixels(truth, in: Self.eyeRegion)
        #expect(Samples.intersectionOverUnion(ours, theirs) >= 0.8)
    }

    @Test("目のまわりは肌の色で埋まり、白い光も開いた目の暗い画素も残らない")
    func openEyesAreErased() throws {
        let painted = try Self.blinked("mochi_idle_01")
        // 開いた目の上半分（弧は下半分に描く）は、体の色だけになる。
        for center in Self.eyeCenters {
            let top = PixelBox(left: Int(center.x) - 20, top: Int(center.y) - 25,
                               right: Int(center.x) + 20, bottom: Int(center.y) - 8)
            #expect(Self.darkPixels(painted.blink, in: top).allSatisfy { !$0 })
        }
    }

    @Test("まぶたの差分は mini の目のまわりに収まり、目を開けた mini に重ねるとまばたきの mini になる",
          arguments: ["piyo", "fuwa"])
    func eyelidStaysAroundTheEyes(id: String) throws {
        let painted = try Self.blinked("\(id)_idle_01")
        let openMini = try #require(FrameRenderer.mini(from: painted.open))
        let blinkMini = try #require(FrameRenderer.mini(from: painted.blink))
        let region = EyelidOverlay.regionMask(painted.regions.map(EyelidOverlay.miniBox),
                                              width: openMini.width, height: openMini.height)
        let changed = EyelidOverlay.differingPixels(openMini, blinkMini)
        #expect(changed.indices.allSatisfy { !changed[$0] || region[$0] })
        let overlay = try #require(EyelidOverlay.make(open: openMini, blink: blinkMini,
                                                     heroRegions: painted.regions))
        #expect(Self.composite(overlay, over: openMini) == blinkMini.pixels)
    }

    @Test("寝息の 2 コマ目は、足元を軸に縦へ 3% 伸ばす")
    func breathStretchesFromTheFeet() throws {
        let sleeping = try Self.hero("piyo_sleep_01")
        let metrics = try #require(FigureMetrics(sleeping))
        let figure = Figure(image: sleeping, originX: 0, originY: 0)
        let base = try #require(FrameRenderer.hero(figure, metrics: metrics, scale: 1))
        let breath = try #require(FrameRenderer.hero(figure, metrics: metrics, scale: 1, stretch: Breath.stretch))
        let first = try #require(FigureMetrics(base))
        let second = try #require(FigureMetrics(breath))
        #expect(abs(second.bottom - first.bottom) < 0.3)
        #expect(abs(second.height / first.height - Breath.stretch) < 0.003)
        #expect(abs(second.width - first.width) < 0.3)
    }

    @Test("覆う判定は、上の絵から 1 画素でもはみ出す下の絵の画素があれば false")
    func coversDetectsStickingOutPixels() {
        var small = Raster(width: 40, height: 40), large = Raster(width: 40, height: 40)
        Samples.dot(on: &small, center: CGPoint(x: 20, y: 20), radius: 8)
        Samples.dot(on: &large, center: CGPoint(x: 20, y: 20), radius: 12)
        #expect(Breath.covers(base: small, top: large))
        #expect(!Breath.covers(base: large, top: small))
    }

    /// 範囲の中の、暗い画素の印（範囲の中だけの並び）。
    static func darkPixels(_ image: Raster, in box: PixelBox) -> [Bool] {
        let dark = FaceScan.darkMask(of: image)
        return box.indices(imageWidth: image.width).map { dark[$0] != 0 }
    }

    /// 乗算済みの重ね合わせ（上の絵が下の絵を覆う）。
    static func composite(_ top: Raster, over bottom: Raster) -> [UInt8] {
        (0..<bottom.pixelCount).flatMap { index -> [UInt8] in
            let offset = index * 4
            let coverage = Int(top.pixels[offset + 3])
            return (0..<4).map { channel in
                UInt8(Int(top.pixels[offset + channel])
                      + (Int(bottom.pixels[offset + channel]) * (255 - coverage) + 127) / 255)
            }
        }
    }
}
