import SwiftUI
import CTCore
import CTAssets

/// ある時刻のキャラと部屋を 1 枚の絵にする。**すべての面がこれを使う**（プラン §7.5）。
///
/// 面ごとに違うのは「どの時刻を渡すか」と「どの大きさで置くか」だけ。
/// 待受モードは毎フレーム、ウィジェットは 5 分ごとの 1 枚を、同じ関数に渡す。
public struct SceneView: View {

    public let state: SceneState
    public let world: SceneWorld
    public let palette: RoomPalette
    /// 動きを止めるか（Reduce Motion・省電力。プラン §7.5）。
    public let reducesMotion: Bool
    /// 演出の位相に使う連続した秒数。
    public let seconds: Double
    /// 夜か。窓の外の見え方が変わる。
    public let isNight: Bool

    public init(state: SceneState, world: SceneWorld, palette: RoomPalette,
                reducesMotion: Bool = false, seconds: Double = 0, isNight: Bool = false) {
        self.state = state
        self.world = world
        self.palette = palette
        self.reducesMotion = reducesMotion
        self.seconds = seconds
        self.isNight = isNight
    }

    public var body: some View {
        GeometryReader { geometry in
            let layout = SceneLayout(size: geometry.size, room: world.room,
                                     geometry: world.spriteGeometry)
            let parts = ItemOrder.split(world.room.items, character: state.position,
                                        definitions: world.definitions)
            ZStack {
                BackdropView(backdrop: world.backdrop, floor: world.room.floor,
                             palette: palette, isNight: isNight)
                layer(parts.behind, layout: layout)
                ShadowView(state: state, layout: layout, flourish: flourish,
                           characterScale: world.character.scale)
                CharacterView(character: world.character, state: state,
                              layout: layout, flourish: flourish)
                layer(parts.front, layout: layout)
                EffectsView(state: state, room: world.room, layout: layout,
                            definitions: world.definitions, palette: palette, seconds: seconds)
                bubble(layout: layout)
            }
        }
    }

    /// Reduce Motion のときは味付けを外し、コマの切り替えだけにする。
    private var flourish: Flourish {
        reducesMotion ? .still : state.flourish
    }

    private func layer(_ items: [PlacedItem], layout: SceneLayout) -> some View {
        ItemLayer(items: items, definitions: world.definitions,
                  layout: layout, palette: palette)
    }

    @ViewBuilder
    private func bubble(layout: SceneLayout) -> some View {
        if let bubble = state.bubble {
            BubbleView(bubble: bubble, layout: layout,
                       characterPosition: state.position,
                       characterHeight: layout.characterHeight(at: state.position,
                                                               characterScale: world.character.scale),
                       palette: palette)
        }
    }
}

/// 絵を描くのに要るもの一式。`WorldInput`（日課エンジンへの入力）の描画側の相棒。
///
/// 分けてあるのは、CTCore が絵のことを何も知らないため。CTCore は
/// 「どこで何をしているか」だけを返し、ここが「それをどう描くか」を持つ。
public struct SceneWorld: Sendable {

    public var character: CTCore.Character
    public var room: Room
    public var definitions: [ItemKind: ItemDefinition]
    public var spriteGeometry: SpriteGeometry
    /// 背景の出どころ。
    public var backdrop: RoomBackdrop

    public init(character: CTCore.Character, room: Room,
                definitions: [ItemKind: ItemDefinition],
                spriteGeometry: SpriteGeometry = .fallback,
                backdrop: RoomBackdrop = .drawn()) {
        self.character = character
        self.room = room
        self.definitions = definitions
        self.spriteGeometry = spriteGeometry
        self.backdrop = backdrop
    }

    /// 同梱データから組み立てる。読めない項目は既定値で埋める（落とさないため）。
    public static func bundled(character: CTCore.Character, room: Room,
                               backdrop: RoomBackdrop = .drawn()) -> SceneWorld {
        let definitions = Dictionary(Catalog.itemsOrEmpty().map { ($0.kind, $0) },
                                     uniquingKeysWith: { first, _ in first })
        return SceneWorld(character: character, room: room, definitions: definitions,
                          spriteGeometry: Catalog.spriteGeometry(), backdrop: backdrop)
    }
}
