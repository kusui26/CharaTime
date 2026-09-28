import Testing
import Foundation
import CoreGraphics
@testable import CTStudio

/// コマを見つける（プラン §9 Phase 2 の 2-C ⑤-3、調査 H §5）。見本は、同梱のピヨの 6 コマを 2 段 × 3 列に、
/// 位置を少しずつずらして並べたもの（生成 AI の格子は、コマの数は守っても等間隔にならない）。
@Suite("コマを見つける")
struct FigureFinderTests {

    static let width = 660
    static let height = 590
    static let scale: CGFloat = 0.3

    static func placement(_ name: String, _ x: CGFloat, _ y: CGFloat) -> Samples.Placement {
        Samples.Placement(name: name, origin: CGPoint(x: x, y: y), scale: scale)
    }

    /// P6 の並び（上の段: 立つ・すわる・寝る、下の段: よろこぶ 2 つ・歩く）。
    static let grid = [
        placement("piyo_idle_01", 20, 18), placement("piyo_sit_01", 230, 30), placement("piyo_sleep_01", 445, 12),
        placement("piyo_happy_01", 15, 300), placement("piyo_happy_02", 225, 285), placement("piyo_walk_01", 440, 310),
    ]

    static func sheet(_ placements: [Samples.Placement] = grid) -> Raster {
        Samples.sheet(width: width, height: height, ground: .transparent, placements: placements)
    }

    /// 見つけたコマの、元の絵の中での不透明な外接矩形。
    static func boxInSheet(_ figure: Figure) -> PixelBox? {
        Samples.opaqueBox(figure.image).map {
            PixelBox(left: $0.left + figure.originX, top: $0.top + figure.originY,
                     right: $0.right + figure.originX, bottom: $0.bottom + figure.originY)
        }
    }

    @Test("格子が等間隔でなくても、6 コマを行ごと・左からの順に見つけ、コマの画素だけを切り出す")
    func findsEveryFigureInReadingOrder() throws {
        let result = FigureFinder.find(in: Self.sheet(), expected: 6)
        #expect(result.figures.count == 6)
        #expect(result.notices.isEmpty)
        for (figure, placement) in zip(result.figures, Self.grid) {
            let truth = Samples.alone(placement, width: Self.width, height: Self.height)
            let expected = try #require(Samples.opaqueBox(truth))
            let found = try #require(Self.boxInSheet(figure))
            #expect(found == expected, "\(placement.name)")
            // コマの画素は、そのコマを 1 枚だけ置いた絵と同じ。
            let region = PixelBox(left: figure.originX, top: figure.originY,
                                  right: figure.originX + figure.image.width,
                                  bottom: figure.originY + figure.image.height)
            #expect(Samples.mask(figure.image) == Samples.mask(truth.cropped(to: region.rect)), "\(placement.name)")
        }
    }

    @Test("離れた小さな部品（汗・とさか）は、近くの体へ寄せる")
    func attachesSmallPartsToTheNearestBody() throws {
        var sheet = Self.sheet()
        // 立ち姿の頭の少し上に、離れた小さな点を置く（すき間は寄せる距離より短い）。
        Samples.dot(on: &sheet, center: CGPoint(x: 108, y: 30), radius: 5)
        let result = FigureFinder.find(in: sheet, expected: 6)
        #expect(result.figures.count == 6)
        #expect(result.notices.isEmpty)
        let standing = try #require(Self.boxInSheet(result.figures[0]))
        #expect(standing.top <= 25)
    }

    @Test("隅の透かしは捨てて知らせ、数画素のごみは黙って捨てる")
    func dropsWatermarksAndJunk() {
        var sheet = Self.sheet()
        Samples.dot(on: &sheet, center: CGPoint(x: 640, y: 572), radius: 8)
        Samples.dot(on: &sheet, center: CGPoint(x: 645, y: 280), radius: 1.5)
        let result = FigureFinder.find(in: sheet, expected: 6)
        #expect(result.figures.count == 6)
        #expect(result.notices == [ImportNotice(.watermarkRemoved, "1 個")])
    }

    @Test("体から離れた部品は、隅でなくても捨てて知らせる")
    func dropsStrayParts() {
        var sheet = Self.sheet()
        Samples.dot(on: &sheet, center: CGPoint(x: 640, y: 280), radius: 6)
        let result = FigureFinder.find(in: sheet, expected: 6)
        #expect(result.figures.count == 6)
        #expect(result.notices == [ImportNotice(.partsRemoved, "1 個")])
    }

    /// 立ち姿の不透明な幅は、@3x の 585 画素の枠の 79.8%（467 画素）。その少し手前に次の絵を置けば触れ合う。
    @Test("触れ合った 2 体は、不透明さの谷で割る")
    func splitsTouchingFigures() throws {
        let first = Self.placement("piyo_idle_01", 40, 40)
        let second = Self.placement("mochi_idle_01", 40 + 460 * Self.scale, 40)
        let result = FigureFinder.find(in: Self.sheet([first, second]), expected: 2)
        #expect(result.figures.count == 2)
        #expect(result.notices.isEmpty)
        let widths = try result.figures.map { figure -> Int in
            let box = try #require(Samples.opaqueBox(figure.image))
            return box.right - box.left
        }
        // 1 体の幅は 467 × 0.3 ≈ 140 画素。割った位置のずれで、数画素は変わる。
        #expect(widths.allSatisfy { abs($0 - 140) <= 10 }, "\(widths)")
    }

    /// 深く重なった 2 体を真ん中で割ると、1 体を切ることになる。割らずに「作り直す」を知らせる。
    @Test("深く重なって谷が浅ければ割らず、コマがくっついていると知らせる")
    func reportsTouchingWhenTheValleyIsShallow() {
        let first = Self.placement("piyo_idle_01", 40, 40)
        let second = Self.placement("piyo_idle_01", 40 + 300 * Self.scale, 40)
        let apart = Self.placement("piyo_sit_01", 440, 40)
        let result = FigureFinder.find(in: Self.sheet([first, second, apart]), expected: 3)
        #expect(result.figures.count == 2)
        #expect(result.notices == [ImportNotice(.figuresTouching, "2 体（3 体のはず）")])
    }

    @Test("コマが足りない・多いときは、数が合わないと知らせる（見つけたコマは返す）")
    func reportsWrongCounts() {
        let missing = FigureFinder.find(in: Self.sheet(Array(Self.grid.prefix(5))), expected: 6)
        #expect(missing.figures.count == 5)
        #expect(missing.notices == [ImportNotice(.figureCount, "5 体（6 体のはず）")])
        let extra = FigureFinder.find(in: Self.sheet(), expected: 4)
        #expect(extra.figures.count == 6)
        #expect(extra.notices == [ImportNotice(.figureCount, "6 体（4 体のはず）")])
    }

    @Test("左右を反転した姿は、もう一度反転すると元に戻る")
    func mirroringTwiceRestores() throws {
        let figure = try #require(FigureFinder.find(in: Self.sheet(), expected: 6).figures.last)
        #expect(figure.mirrored() != figure)
        #expect(figure.mirrored().mirrored() == figure)
    }
}
