import Testing
import Foundation
import CTCore
import CTAssets
@testable import CTRender

/// 置き方がずれると、キャラが床に埋まったり浮いたりする。
/// **画面の大きさが変わっても、足元が床に乗ること**をここで見張る。
@Suite("画面への置き方")
struct SceneLayoutTests {

    static let geometry = SpriteGeometry(aspectRatio: 130.0 / 180.0, groundRatio: 168.0 / 180.0)
    static let floor = RoomRect(x: 0.08, y: 0.66, width: 0.84, height: 0.20)

    static func layout(width: Double = 390, height: Double = 844,
                       items: [PlacedItem] = []) -> SceneLayout {
        SceneLayout(size: CGSize(width: width, height: height),
                    room: Room(background: .bundled("r"), floor: floor, items: items),
                    geometry: geometry)
    }

    /// 実機・シミュレータ・ウィジェットで出てくる大きさ。
    static let screenSizes: [(Double, Double)] = [
        (390, 844),    // iPhone 13/14
        (402, 874),    // iPhone 17 Pro
        (440, 956),    // iPhone 17 Pro Max
        (170, 170),    // 小ウィジェット
        (364, 170),    // 中ウィジェット
    ]

    @Test("どの画面の大きさでも、絵の接地線がちょうど足元に来る")
    func groundLineLandsOnTheFoot() {
        for (width, height) in Self.screenSizes {
            let layout = Self.layout(width: width, height: height)
            for vertical in [0.0, 0.5, 1.0] {
                let foot = Self.floor.at(0.5, vertical)
                let spriteHeight = layout.characterHeight(at: foot, characterScale: 1)
                let frame = layout.spriteFrame(footAt: foot, height: spriteHeight, liftRatio: 0)
                let groundLine = frame.minY + frame.height * Self.geometry.groundRatio
                let note = "\(width)x\(height) v=\(vertical): \(groundLine) と \(foot.y * height)"
                #expect(abs(groundLine - foot.y * height) < 0.001, Comment(rawValue: note))
                #expect(abs(frame.midX - foot.x * width) < 0.001)
            }
        }
    }

    @Test("浮くと、その高さだけ絵が持ち上がる")
    func liftRaisesTheSprite() {
        let layout = Self.layout()
        let foot = Self.floor.at(0.5, 0.5)
        let height = layout.characterHeight(at: foot, characterScale: 1)
        let grounded = layout.spriteFrame(footAt: foot, height: height, liftRatio: 0)
        let lifted = layout.spriteFrame(footAt: foot, height: height, liftRatio: 0.05)
        #expect(abs((grounded.minY - lifted.minY) - height * 0.05) < 0.001)
        #expect(grounded.size == lifted.size)
    }

    @Test("奥にいるほど小さく見える")
    func farAwayIsSmaller() {
        let layout = Self.layout()
        let far = layout.characterHeight(at: Self.floor.at(0.5, 0.0), characterScale: 1)
        let near = layout.characterHeight(at: Self.floor.at(0.5, 1.0), characterScale: 1)
        #expect(far < near)
        // 既定の 0.85〜1.0 のぶんだけ違う。
        #expect(abs(far / near - 0.85) < 0.001)
    }

    @Test("キャラの大きさの指定が、そのまま背の高さに効く")
    func characterScaleApplies() {
        let layout = Self.layout()
        let point = Self.floor.at(0.5, 0.5)
        let normal = layout.characterHeight(at: point, characterScale: 1)
        let bigger = layout.characterHeight(at: point, characterScale: 1.2)
        #expect(abs(bigger / normal - 1.2) < 0.001)
    }

    @Test("床に置くアイテムは下端が、吊るすアイテムは上端が、指定の位置に来る")
    func itemsAnchorCorrectly() {
        let layout = Self.layout()
        let onFloor = PlacedItem(id: "c", kind: .cushion, position: RoomPoint(x: 0.4, y: 0.80))
        let hanging = PlacedItem(id: "m", kind: .mirrorBall, position: RoomPoint(x: 0.7, y: 0.28))
        let cushion = ItemDefinition(id: "cushion", kind: .cushion, displayName: "クッション",
                                     assetName: "item_cushion", widthRatio: 0.2,
                                     anchorOffset: .zero, aspectRatio: 1.83)
        let ball = ItemDefinition(id: "mirror-ball", kind: .mirrorBall, displayName: "ミラーボール",
                                  assetName: "item_mirror_ball", widthRatio: 0.18,
                                  anchorOffset: .zero, aspectRatio: 1.0,
                                  hangsFromCeiling: true)
        let cushionFrame = layout.itemFrame(onFloor, definition: cushion)
        #expect(abs(cushionFrame.maxY - 0.80 * 844) < 0.001)
        #expect(abs(cushionFrame.midX - 0.4 * 390) < 0.001)

        let ballFrame = layout.itemFrame(hanging, definition: ball)
        #expect(abs(ballFrame.minY - 0.28 * 844) < 0.001)
        // 紐は天井から絵の上端まで。
        let cord = layout.cord(for: ballFrame)
        #expect(cord.from.y == 0)
        #expect(cord.to.y > ballFrame.minY)
    }

    @Test("縦横比が 0 のアイテムでも落ちない")
    func zeroAspectDoesNotDivideByZero() {
        let layout = Self.layout()
        let broken = ItemDefinition(id: "x", kind: .ball, displayName: "壊れた",
                                    assetName: "item_ball", widthRatio: 0.1,
                                    anchorOffset: .zero, aspectRatio: 0)
        let frame = layout.itemFrame(
            PlacedItem(id: "x", kind: .ball, position: RoomPoint(x: 0.5, y: 0.8)),
            definition: broken)
        #expect(frame.height.isFinite)
        #expect(frame.height > 0)
    }

    @Test("影は足元を中心にした横長の楕円")
    func shadowSitsUnderTheFoot() {
        let layout = Self.layout()
        let foot = Self.floor.at(0.5, 0.5)
        let height = layout.characterHeight(at: foot, characterScale: 1)
        let shadow = layout.shadowFrame(at: foot, height: height, scale: 1)
        #expect(abs(shadow.midX - foot.x * 844 * (390.0 / 844)) < 0.001)
        #expect(abs(shadow.midY - foot.y * 844) < 0.001)
        #expect(shadow.width > shadow.height)
        // 浮くと小さくなる。
        #expect(layout.shadowFrame(at: foot, height: height, scale: 0.7).width < shadow.width)
    }

    @Test("アイテムを奥と手前に分けると、キャラより下のものだけが手前に来る")
    func itemsSplitAroundTheCharacter() {
        let definitions: [ItemKind: ItemDefinition] = [
            .cushion: ItemDefinition(id: "cushion", kind: .cushion, displayName: "",
                                     assetName: "", widthRatio: 0.2, anchorOffset: .zero),
            .mirrorBall: ItemDefinition(id: "mb", kind: .mirrorBall, displayName: "",
                                        assetName: "", widthRatio: 0.2, anchorOffset: .zero,
                                        hangsFromCeiling: true),
        ]
        let items = [
            PlacedItem(id: "back", kind: .cushion, position: RoomPoint(x: 0.2, y: 0.70)),
            PlacedItem(id: "front", kind: .cushion, position: RoomPoint(x: 0.6, y: 0.84)),
            PlacedItem(id: "ball", kind: .mirrorBall, position: RoomPoint(x: 0.7, y: 0.28)),
        ]
        let split = ItemOrder.split(items, character: RoomPoint(x: 0.5, y: 0.78),
                                    definitions: definitions)
        #expect(split.behind.map(\.id) == ["ball", "back"])
        #expect(split.front.map(\.id) == ["front"])
    }
}
