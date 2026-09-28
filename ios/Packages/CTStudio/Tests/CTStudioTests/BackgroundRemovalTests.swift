import Testing
import Foundation
import CoreGraphics
import CTStore
@testable import CTStudio

/// 背景を外す（プラン §9 Phase 2 の 2-C ⑤-2、D-36）。見本の絵は、同梱のピヨ（黄色）とモチ（白い体）を
/// 地に並べたもの。透明の地に並べた同じ絵の不透明さを正解にして比べる（調査 H の IoU）。
@Suite("背景を外す")
struct BackgroundRemovalTests {

    static let width = 520
    static let height = 360
    /// ピヨ（黄色）とモチ（白い体。白い地に置くと、体が地と同じ色になる）。
    static let placements = [
        Samples.Placement(name: "piyo_idle_01", origin: CGPoint(x: 30, y: 40), scale: 0.35),
        Samples.Placement(name: "mochi_idle_01", origin: CGPoint(x: 280, y: 50), scale: 0.35),
    ]

    static func sheet(_ ground: Samples.Ground) -> Raster {
        Samples.sheet(width: width, height: height, ground: ground, placements: placements)
    }

    /// 正解: 透明の地に並べた絵の不透明さ。
    static let truth = Samples.mask(sheet(.transparent))

    static func removed(_ ground: Samples.Ground) throws -> (Raster, ImportRecord.Background) {
        guard case .removed(let raster, let method) = BackgroundRemoval.remove(from: sheet(ground)) else {
            Issue.record("背景を外せなかった")
            throw CancellationError()
        }
        return (raster, method)
    }

    /// 縁の半透明の画素（不透明さ 26〜229）のうち、条件に合う色の割合。にじみを数える（H §2）。
    static func edgeShare(_ raster: Raster, where isFringe: (Float, Float, Float) -> Bool) -> Double {
        let edges = stride(from: 0, to: raster.pixels.count, by: 4).filter {
            (26...229).contains(raster.pixels[$0 + 3])
        }
        let fringe = edges.filter { offset in
            let alpha = Float(raster.pixels[offset + 3])
            return isFringe(Float(raster.pixels[offset]) / alpha, Float(raster.pixels[offset + 1]) / alpha,
                            Float(raster.pixels[offset + 2]) / alpha)
        }
        return edges.isEmpty ? 0 : Double(fringe.count) / Double(edges.count)
    }

    @Test("透明の地は、そのまま使い、不透明さだけをそろえる（240 以上は 255、16 未満は 0）")
    func transparentGroundOnlySnapsAlpha() throws {
        let (raster, method) = try Self.removed(.transparent)
        #expect(method == .transparent)
        #expect(Samples.mask(raster) == Self.truth)
        let alphas = Set(stride(from: 3, to: raster.pixels.count, by: 4).map { raster.pixels[$0] })
        #expect(alphas.allSatisfy { $0 == 0 || $0 == 255 || (16...239).contains($0) })
    }

    @Test("白い地は、縁からつながるところだけを抜く。白い体（モチ）は残り、白いにじみも残らない")
    func whiteGroundIsRemovedButTheWhiteBodyStays() throws {
        let (raster, method) = try Self.removed(Samples.white)
        #expect(method == .solidColor)
        #expect(Samples.intersectionOverUnion(Samples.mask(raster), Self.truth) >= 0.999)
        // モチのおなかの真ん中（白い体）は不透明のまま。
        #expect(raster.alpha(x: 280 + 102, y: 50 + 200) == 255)
        #expect(Self.edgeShare(raster) { red, green, blue in min(red, green, blue) > 0.85 } < 0.02)
    }

    @Test("緑の地は、抜いたあと縁に緑が残らない（縁は内側の体の色で塗る）")
    func greenGroundLeavesNoGreenFringe() throws {
        let (raster, method) = try Self.removed(Samples.green)
        #expect(method == .solidColor)
        #expect(Samples.intersectionOverUnion(Samples.mask(raster), Self.truth) >= 0.999)
        #expect(Self.edgeShare(raster) { red, green, blue in green > red + 0.15 && green > blue + 0.15 } < 0.01)
    }

    /// Gemini に「透明」と頼むと、市松模様を描く（`research/G` §4.6）。2 色とも地として抜く。
    @Test("市松模様の地は、2 色とも地として抜く")
    func checkerboardGroundIsRemoved() throws {
        let (raster, method) = try Self.removed(.checkerboard(light: 1.0, dark: 0.8, square: 12))
        #expect(method == .checkerboard)
        #expect(Samples.intersectionOverUnion(Samples.mask(raster), Self.truth) >= 0.995)
    }

    @Test("1 色でも市松でもない地は、Vision の被写体の切り抜きに回す")
    func patternedGroundNeedsSubjectLift() {
        #expect(BackgroundRemoval.remove(from: Self.sheet(.stripes)) == .needsSubjectLift)
    }

    @Test("被写体を切り抜いた絵は、透明の地と同じに扱い、外し方を「被写体の切り抜き」と記録する")
    func liftedSubjectsAreTreatedAsTransparent() {
        guard case .removed(let raster, let method) = BackgroundRemoval.lifted(Self.sheet(.transparent)) else {
            Issue.record("受け取れなかった")
            return
        }
        #expect(method == .subjectLift)
        #expect(Samples.mask(raster) == Self.truth)
    }

    // MARK: - 小さな部品

    @Test("不透明さをそろえると、色味は変えずに不透明にする")
    func alphaSnapKeepsTheHue() {
        var raster = Raster(width: 3, height: 1, pixels: [
            200, 100, 50, 250,     // ほぼ不透明 → 不透明に
            5, 5, 5, 10,           // ほぼ透明 → 透明に
            60, 60, 60, 120,       // 半透明 → そのまま
        ])
        AlphaSnap.apply(to: &raster)
        #expect(raster.pixel(x: 0, y: 0) == [204, 102, 51, 255])
        #expect(raster.pixel(x: 1, y: 0) == [0, 0, 0, 0])
        #expect(raster.pixel(x: 2, y: 0) == [60, 60, 60, 120])
    }

    @Test("縁の帯だけで、地の種類を見分ける")
    func groundKindsAreClassifiedFromTheBorder() {
        func kind(_ ground: Samples.Ground) -> BackgroundKind {
            BackgroundKind.classify(BorderBand(Samples.sheet(width: 96, height: 96, ground: ground, placements: [])))
        }
        #expect(kind(.transparent) == .transparent)
        #expect(kind(Samples.white) == .solid(.white))
        guard case .checkerboard = kind(.checkerboard(light: 1.0, dark: 0.8, square: 8)) else {
            Issue.record("市松と見分けられない")
            return
        }
        #expect(kind(.stripes) == .complex)
    }
}
