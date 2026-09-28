import Testing
import Foundation
import CoreGraphics
@testable import CTStudio

/// 枠にそろえる（プラン §9 Phase 2 の 2-C ⑤-4・⑤-5）。**同梱の絵を縮めて並べ、整えて戻すと、元の枠・接地線と
/// 1 画素以内にそろうか**（2-C ⑫。2-2 の終わりの確かめ方）。
@Suite("枠にそろえる")
struct FrameFittingTests {

    /// 見本の倍率。生成 AI の立ち姿（約 450 画素）に近い大きさ（ピヨの立ち姿が 438 画素）。
    static let scale: CGFloat = 0.6

    static func bundledRaster(_ name: String) throws -> Raster {
        try #require(Raster(cgImage: Samples.bundled(name)))
    }

    static func measure(_ raster: Raster) throws -> FigureMetrics {
        try #require(FigureMetrics(raster))
    }

    /// 1 枚の画像に並べたコマを、見つけて枠に描いた hero（並べた順）。
    static func roundTrip(_ names: [String], ground: Samples.Ground = .transparent) throws -> [Raster] {
        let placements = names.enumerated().map { index, name in
            Samples.Placement(name: name, origin: CGPoint(x: 20 + index * 372, y: 24 + index % 2 * 9),
                              scale: scale)
        }
        let sheet = Samples.sheet(width: 20 + names.count * 372, height: 530, ground: ground,
                                  placements: placements)
        guard case .removed(let cutout, _) = BackgroundRemoval.remove(from: sheet) else {
            throw StudioError.drawingFailed
        }
        let figures = FigureFinder.find(in: cutout, expected: names.count).figures
        let metrics = try figures.map { try measure($0.image) }
        let sheetFit = ScalePlan.Sheet(referenceHeight: metrics[0].height, figures: metrics)
        let plan = ScalePlan(standing: metrics[0], sheets: [sheetFit])
        #expect(plan.shrink == 1)
        return try zip(figures, metrics).map { figure, metrics in
            try #require(FrameRenderer.hero(figure, metrics: metrics, scale: plan.scale(for: sheetFit)))
        }
    }

    static func expectClose(_ found: FigureMetrics, _ truth: FigureMetrics, within tolerance: Double,
                            _ comment: Comment) {
        #expect(abs(found.left - truth.left) <= tolerance, comment)
        #expect(abs(found.right - truth.right) <= tolerance, comment)
        #expect(abs(found.top - truth.top) <= tolerance, comment)
        #expect(abs(found.bottom - truth.bottom) <= tolerance, comment)
        #expect(abs(found.anchorX - truth.anchorX) <= tolerance, comment)
    }

    @Test("寸法は、縁の不透明さで画素より細かく測る（いまのピヨの立ち姿を Python で測った値と同じ）")
    func measuresTheBundledStandingPose() throws {
        let metrics = try Self.measure(Self.bundledRaster("piyo_idle_01"))
        let truth = FigureMetrics(left: 59.05, top: 36.78, right: 525.93, bottom: 767.24, anchorX: 292.5)
        Self.expectClose(metrics, truth, within: 0.02, "piyo_idle_01")
    }

    @Test("いまの絵の立ち姿は、輪郭線のいちばん下が枠の 94.72%、幅は枠の 79.81%（枠の決まりの出どころ）")
    func bundledStandingPosesMatchTheFrameRules() throws {
        for id in ["piyo", "mochi", "kumao", "chip"] {
            let metrics = try Self.measure(Self.bundledRaster("\(id)_idle_01"))
            #expect(abs(metrics.bottom - FrameGeometry.outlineBottom(in: FrameGeometry.hero)) < 0.05, "\(id)")
            #expect(abs(metrics.width / 585 - FrameGeometry.standingWidthShare) < 0.0001, "\(id)")
            #expect(metrics.height / 810 <= FrameGeometry.standingHeightShare + 0.0001, "\(id)")
        }
    }

    @Test("縮めて並べた立ち姿を整えると、元の枠・接地線と 1 画素以内に戻る", arguments: ["piyo", "chip"])
    func standingPoseRoundTrips(id: String) throws {
        let heroes = try Self.roundTrip(["\(id)_idle_01"])
        let found = try Self.measure(heroes[0])
        Self.expectClose(found, try Self.measure(Self.bundledRaster("\(id)_idle_01")), within: 1, "\(id)")
    }

    @Test("同じ画像のほかのコマは、立ち姿と同じ倍率で、足元を 94.72%・上 6 割の中心を枠の中央に置く")
    func otherPosesShareTheScale() throws {
        let names = ["piyo_idle_01", "piyo_sit_01", "piyo_sleep_01", "piyo_happy_01"]
        let heroes = try Self.roundTrip(names)
        for (hero, name) in zip(heroes, names).dropFirst() {
            let found = try Self.measure(hero)
            let truth = try Self.measure(Self.bundledRaster(name))
            #expect(abs(found.width - truth.width) <= 1, "\(name)")
            #expect(abs(found.height - truth.height) <= 1, "\(name)")
            #expect(abs(found.bottom - 767.25) <= 0.5, "\(name)")
            #expect(abs(found.anchorX - 292.5) <= 0.5, "\(name)")
        }
    }

    @Test("白い地・緑の地・市松模様から抜いても、立ち姿は元の枠と 1 画素以内に戻る")
    func keyedGroundsRoundTrip() throws {
        let grounds: [(String, Samples.Ground)] = [
            ("白", Samples.white), ("緑", Samples.green),
            ("市松", .checkerboard(light: 1, dark: 0.8, square: 12)),
        ]
        let truth = try Self.measure(Self.bundledRaster("mochi_idle_01"))
        for (label, ground) in grounds {
            let heroes = try Self.roundTrip(["mochi_idle_01"], ground: ground)
            Self.expectClose(try Self.measure(heroes[0]), truth, within: 1, "\(label)")
        }
    }

    @Test("mini は hero を縮めて作り、いまの mini と 1 画素以内にそろう")
    func miniMatchesTheBundledMini() throws {
        let hero = try Self.bundledRaster("kumao_idle_01")
        let mini = try #require(FrameRenderer.mini(from: hero))
        #expect(mini.width == 273 && mini.height == 378)
        let truth = try Self.measure(Self.bundledRaster("kumao_idle_01_mini"))
        Self.expectClose(try Self.measure(mini), truth, within: 1, "kumao mini")
    }

    @Test("描いた絵は、乗算済みの色が不透明さを超えない")
    func colorsNeverExceedAlpha() throws {
        let hero = try Self.roundTrip(["fuwa_happy_01"])[0]
        let mini = try #require(FrameRenderer.mini(from: hero))
        for raster in [hero, mini] {
            let overflow = stride(from: 0, to: raster.pixels.count, by: 4).contains { offset in
                (0..<3).contains { raster.pixels[offset + $0] > raster.pixels[offset + 3] }
            }
            #expect(!overflow)
        }
    }
}

/// 倍率の決め方（2-C ⑤-4）。寸法だけで決まる純粋な計算。
@Suite("倍率の決め方")
struct ScalePlanTests {

    /// 横の中心に置いた寸法（元の画素）。
    static func figure(width: Double, height: Double, anchorOffset: Double = 0) -> FigureMetrics {
        FigureMetrics(left: 0, top: 0, right: width, bottom: height, anchorX: width / 2 + anchorOffset)
    }

    @Test("立ち姿が幅で決まる子は幅 79.81%、背で決まる子は高さ 93.05% になる")
    func standingPoseFillsTheLimit() {
        let wide = Self.figure(width: 100, height: 120)
        let wideSheet = ScalePlan.Sheet(referenceHeight: 120, figures: [wide])
        let widePlan = ScalePlan(standing: wide, sheets: [wideSheet])
        #expect(abs(100 * widePlan.scale(for: wideSheet) - 585 * 0.7981) < 1e-9)
        let tall = Self.figure(width: 60, height: 120)
        let tallSheet = ScalePlan.Sheet(referenceHeight: 120, figures: [tall])
        let tallPlan = ScalePlan(standing: tall, sheets: [tallSheet])
        #expect(abs(120 * tallPlan.scale(for: tallSheet) - 810 * 0.9305) < 1e-9)
        #expect(tallPlan.shrink == 1 && !tallPlan.isCompacted)
    }

    @Test("横に広い姿勢があると、全コマが幅 95% に収まるまで縮め、1 割以上なら知らせる")
    func widePoseShrinksEverything() {
        let standing = Self.figure(width: 100, height: 120)
        let sleeping = Self.figure(width: 200, height: 60)
        let sheet = ScalePlan.Sheet(referenceHeight: 120, figures: [standing, sleeping])
        let plan = ScalePlan(standing: standing, sheets: [sheet])
        // 寝姿の半分（100）が、枠の幅 95% の半分（277.875）に収まる倍率。
        #expect(abs(plan.scale(for: sheet) - 277.875 / 100) < 1e-9)
        #expect(plan.isCompacted)
        #expect(abs(plan.shrink - (277.875 / 100) / (585 * 0.7981 / 100)) < 1e-9)
    }

    @Test("しっぽが片側に出る子は、枠の中央に置く所から長いほうで収める")
    func lopsidedFigureFitsByItsLongerSide() {
        let standing = Self.figure(width: 100, height: 120)
        // 幅 160 だが、中央に置く所から右へ 120 出ている。
        let tail = Self.figure(width: 160, height: 100, anchorOffset: -40)
        let sheet = ScalePlan.Sheet(referenceHeight: 120, figures: [standing, tail])
        let plan = ScalePlan(standing: standing, sheets: [sheet])
        #expect(abs(plan.scale(for: sheet) - 277.875 / 120) < 1e-9)
    }

    @Test("背の高いコマは、上端が枠からはみ出さないまで縮める")
    func tallFigureStaysInsideTheFrame() {
        let standing = Self.figure(width: 60, height: 120)
        let raisedArms = Self.figure(width: 60, height: 150)
        let sheet = ScalePlan.Sheet(referenceHeight: 120, figures: [standing, raisedArms])
        let plan = ScalePlan(standing: standing, sheets: [sheet])
        #expect(abs(150 * plan.scale(for: sheet) - 810 * FrameGeometry.outlineBottomShare) < 1e-9)
    }

    @Test("別の画像は立ち姿の背でつなぐ。歩く 4 コマは高さの中央値を立ち姿の背にそろえる")
    func sheetsLinkThroughTheStandingHeight() {
        let standing = Self.figure(width: 100, height: 120)
        let poses = ScalePlan.Sheet(referenceHeight: 120, figures: [standing])
        let walking = [130.0, 128, 132, 131].map { Self.figure(width: 90, height: $0) }
        let walk = ScalePlan.Sheet(medianOf: walking)
        #expect(walk.referenceHeight == 130.5)
        let plan = ScalePlan(standing: standing, sheets: [poses, walk])
        #expect(abs(130.5 * plan.scale(for: walk) - plan.standingHeight) < 1e-9)
        #expect(abs(120 * plan.scale(for: poses) - plan.standingHeight) < 1e-9)
    }

    @Test("別の画像に横に広いコマがあれば、どの画像も同じ割合で縮める（画像をまたいで背が変わらない）")
    func wideFigureInAnotherSheetShrinksEverySheet() {
        let standing = Self.figure(width: 100, height: 120)
        let poses = ScalePlan.Sheet(referenceHeight: 120, figures: [standing])
        // 2 枚目は半分の大きさで描かれ、立ち姿（60）の 3 倍の幅のコマがある。
        let other = ScalePlan.Sheet(referenceHeight: 60, figures: [Self.figure(width: 50, height: 60),
                                                                   Self.figure(width: 150, height: 40)])
        let plan = ScalePlan(standing: standing, sheets: [poses, other])
        #expect(abs(75 * plan.scale(for: other) - 277.875) < 1e-9)
        #expect(abs(120 * plan.scale(for: poses) - 60 * plan.scale(for: other)) < 1e-9)
    }
}
