import Testing
import Foundation
import CTCore
import CTAssets
import CTStore
@testable import CTRender

/// ウィジェットの大きさごとの写し方（プラン §9 Phase 3 の 3-C ⑥）。
///
/// **どの大きさでも、キャラが枠からはみ出さないこと**をここで見張る。ウィジェットは
/// 5 分間同じ絵を出すので、頭が切れたまま 5 分止まるのがいちばん目立つ。
@Suite("ウィジェットの写し方")
struct WidgetStageTests {

    static let geometry = SpriteGeometry(aspectRatio: 130.0 / 180.0, groundRatio: 168.0 / 180.0)
    static let families = WidgetSlot.Family.allCases
    /// 同梱の部屋と、写真の部屋（帯を指で決めた形。左右の余白は待受モードが体の幅から決める）。
    static let rooms = [BundledRoom.room,
                        Room(background: .photo(fileName: "bg"),
                             floor: RoomRect(x: 0.177, y: 0.55, width: 0.646, height: 0.33))]
    /// 同梱のキャラの体格差の、いちばん小さいものと大きいもの（characters.json）。
    static let characterScales = [0.95, 1.0, 1.1]

    static func sizes(_ family: WidgetSlot.Family) -> [CGSize] {
        [WidgetStage.referenceSize(for: family), WidgetStage.labelFreeSize(for: family)]
    }

    static func layout(_ family: WidgetSlot.Family, size: CGSize? = nil, room: Room = BundledRoom.room,
                       characterScale: Double = 1) -> SceneLayout {
        WidgetStage.stage(for: family).layout(size: size ?? WidgetStage.referenceSize(for: family),
                                              room: room, geometry: geometry,
                                              characterScale: characterScale)
    }

    // MARK: - キャラの大きさ

    /// ページの部屋で、大と中のあいだを行き来しても大きさが変わらない（3-C ⑧）。
    @Test("大と中は、同じ機種ならキャラが同じ大きさ（約 110pt）")
    func largeAndMediumShareTheScale() {
        for sizes in [WidgetStage.referenceSize, WidgetStage.labelFreeSize] {
            let large = Self.layout(.large, size: sizes(.large)).characterBaseHeight
            let medium = Self.layout(.medium, size: sizes(.medium)).characterBaseHeight
            #expect(abs(large - medium) < 0.001)
        }
        #expect(abs(Self.layout(.large).characterBaseHeight - 110) < 1)
    }

    /// ウィジェット用の絵（mini）は枠の高さ 126pt で焼いてある。それより大きく描くと引き伸ばしになる。
    @Test("小は近影。キャラの枠の高さは、ウィジェット用の絵の大きさ（126pt）を超えない")
    func closeUpFitsTheMiniArt() {
        let base = Self.layout(.small).characterBaseHeight
        #expect(base > 120)
        #expect(base <= 126.0 + 0.01)
    }

    @Test("アイテムとキャラの大きさの釣り合いは、待受モードと同じ")
    func itemsKeepTheirProportionToTheCharacter() throws {
        let definitions = Catalog.itemsOrEmpty()
        let bed = try #require(definitions.first { $0.kind == .bed })
        let item = PlacedItem(id: "bed", kind: .bed, position: RoomPoint(x: 0.3, y: 0.76))
        let standby = SceneLayout(size: SceneLayout.referenceScreen, room: BundledRoom.room,
                                  geometry: Self.geometry)
        let expected = standby.itemFrame(item, definition: bed).width / standby.characterBaseHeight
        for family in Self.families {
            let layout = Self.layout(family)
            let ratio = layout.itemFrame(item, definition: bed).width / layout.characterBaseHeight
            #expect(abs(ratio - expected) < 0.0001, "\(family)")
        }
    }

    // MARK: - はみ出さない

    @Test("どの大きさ・部屋・体格でも、帯のどこに立っても、キャラが枠からはみ出さない")
    func characterStaysInsideTheWidget() {
        for family in Self.families {
            for size in Self.sizes(family) {
                for room in Self.rooms {
                    for scale in Self.characterScales {
                        let layout = Self.layout(family, size: size, room: room, characterScale: scale)
                        for corner in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0), (0.5, 0.5)] {
                            let foot = room.floor.at(corner.0, corner.1)
                            assertInside(layout, foot: foot, scale: scale,
                                         note: "\(family) \(size) 体格 \(scale) 帯 \(corner)")
                        }
                    }
                }
            }
        }
    }

    private func assertInside(_ layout: SceneLayout, foot: RoomPoint, scale: Double, note: String,
                              sourceLocation: SourceLocation = #_sourceLocation) {
        let height = layout.characterHeight(at: foot, characterScale: scale)
        let frame = layout.spriteFrame(footAt: foot, height: height, liftRatio: 0)
        let halfBody = frame.width * SceneLayout.bodyWidthRatio / 2
        #expect(frame.minY >= 0, "頭が切れる: \(note)", sourceLocation: sourceLocation)
        #expect(frame.maxY <= layout.size.height, "足が切れる: \(note)", sourceLocation: sourceLocation)
        #expect(frame.midX - halfBody >= 0, "左が切れる: \(note)", sourceLocation: sourceLocation)
        #expect(frame.midX + halfBody <= layout.size.width, "右が切れる: \(note)",
                sourceLocation: sourceLocation)
    }

    // MARK: - 写し方

    @Test("床の帯は、大きさごとに決めた高さへ写る")
    func bandLandsWhereTheStageSays() {
        for family in Self.families {
            let stage = WidgetStage.stage(for: family)
            for room in Self.rooms {
                let layout = Self.layout(family, room: room)
                let height = layout.size.height
                #expect(abs(layout.horizonY - stage.band.lowerBound * height) < 0.001)
                #expect(abs(layout.projection.y(room.floor.maxY) - stage.band.upperBound * height) < 0.001)
            }
        }
    }

    @Test("帯の真ん中は、ウィジェットの真ん中に来る")
    func bandIsCentered() {
        for family in Self.families {
            for room in Self.rooms {
                let layout = Self.layout(family, room: room)
                let center = (room.floor.minX + room.floor.maxX) / 2
                #expect(abs(layout.projection.x(center) - layout.size.width / 2) < 0.001)
            }
        }
    }

    @Test("大と中は部屋を幅いっぱいに写し、小は帯の端で体が収まるよう縮める")
    func horizontalScaleFitsTheBody() {
        for family in [WidgetSlot.Family.large, .medium] {
            let layout = Self.layout(family)
            // CGFloat と Double を #expect の中で直接比べると、同じ値でも等しくならない。そろえてから比べる。
            #expect(Double(layout.projection.xScale) == Double(layout.size.width))
        }
        let small = Self.layout(.small)
        #expect(small.projection.xScale < small.size.width)
    }

    @Test("窓は大と中だけに描き、描くときは壁の中に収まる")
    func windowFitsOnTheWall() {
        #expect(WidgetStage.stage(for: .large).showsWindow)
        #expect(WidgetStage.stage(for: .medium).showsWindow)
        #expect(!WidgetStage.stage(for: .small).showsWindow)
        for family in [WidgetSlot.Family.large, .medium] {
            let layout = Self.layout(family)
            let window = layout.fixtureFrame(RoomFixture.window)
            #expect(window.minY >= 0, "\(family)")
            #expect(window.maxY <= layout.horizonY, "\(family) の窓が床にかかる")
        }
    }

    @Test("吊るすアイテム（ミラーボール）は、どの大きさでも枠の中に見える")
    func hangingItemIsVisible() throws {
        let ball = try #require(Catalog.itemsOrEmpty().first { $0.kind == .mirrorBall })
        let placed = try #require(BundledRoom.room.items.first { $0.kind == .mirrorBall })
        for family in Self.families {
            let frame = Self.layout(family).itemFrame(placed, definition: ball)
            #expect(frame.minY >= 0 && frame.maxY <= Self.layout(family).horizonY, "\(family)")
        }
    }

    @Test("帯の厚みが 0 に近い部屋でも、写し方が有限に決まる")
    func degenerateFloorStaysFinite() {
        let flat = Room(background: .bundled("r"), floor: RoomRect(x: 0.2, y: 0.7, width: 0.6, height: 0))
        for family in Self.families {
            let projection = Self.layout(family, room: flat).projection
            #expect(projection.yScale.isFinite && projection.yOffset.isFinite)
        }
    }
}
