import SwiftUI
import CTCore
import CTAssets

/// ある時刻のキャラと部屋を 1 枚の絵にする。**すべての面がこれを使う**（プラン §7.5）。
///
/// 面ごとに違うのは「どの時刻を渡すか」と「どの大きさで置くか」だけ。
/// 待受モードは毎フレーム、ウィジェットは 5 分ごとの 1 枚を、同じ関数に渡す
/// （ウィジェットの枠は `WidgetScene`）。
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
            ZStack {
                BackdropView(backdrop: world.backdrop, layout: layout,
                             palette: palette, isNight: isNight)
                SceneLayers(state: state, world: world, layout: layout, palette: palette,
                            look: .standby(reducesMotion: reducesMotion), seconds: seconds)
            }
        }
    }
}

/// 待受モードとウィジェットで違う、描き方の選び（プラン §7.5）。
struct SceneLook: Sendable, Equatable {
    /// 待受モードは動くコマそのまま、ウィジェットは止めた 1 枚（`SpritePick.still`）。
    var stills: Bool
    /// 呼吸・弾み・かしげを当てるか。止めた 1 枚に当てると、跳ねた途中で 5 分止まる。
    var flourishes: Bool
    var bubble: BubbleStyle
    var showsSparkles: Bool
    /// キャラ（影と吹き出しを含む）の同一性。変わると、滑らせずに消えて現れる（3-C ④'）。
    var characterIdentity: Int
    /// 疑似アニメで描くときの材料。nil なら止めた 1 枚で描く（描画の段が 5 分ごとの切り替えまで）。
    var ambient: AmbientLook?
    /// 利用者の壁紙の上（透過背景）に描くか。明るさの分からない背景なので、淡い字（z）に影を付ける。
    /// 天井も無いので、吊るすアイテムの紐を描かない（紐がウィジェットの上端から生えて、見えないはずの枠が分かる）。
    var overWallpaper = false

    static func standby(reducesMotion: Bool) -> SceneLook {
        SceneLook(stills: false, flourishes: !reducesMotion, bubble: .standby,
                  showsSparkles: true, characterIdentity: 0, ambient: nil)
    }

    static func widget(identity: Int, tone: WidgetTone, ambient: AmbientLook?,
                       overWallpaper: Bool = false) -> SceneLook {
        SceneLook(stills: true, flourishes: false,
                  bubble: BubbleStyle.widget.painted(BubblePaint(tone)),
                  showsSparkles: false, characterIdentity: identity, ambient: ambient,
                  overWallpaper: overWallpaper)
    }
}

/// 部屋の中身（アイテム・影・キャラ・演出・吹き出し）を重ねる。待受モードもウィジェットもこれを使う。
///
/// **アイテムとキャラは 1 つの重なりに置き、前後は `zIndex` で決める。** キャラが動いて
/// アイテムの前後が入れ替わっても、アイテムの View は同じまま残る。ウィジェットのエントリ切替で、
/// 前後が入れ替わったアイテムだけが消えて現れ直す、ということが起きない。
struct SceneLayers: View {

    let state: SceneState
    let world: SceneWorld
    let layout: SceneLayout
    let palette: RoomPalette
    let look: SceneLook
    let seconds: Double

    /// 重ねる順。画面の下にあるアイテムほど手前（プラン §7.5 の「y でソート」）。
    private enum Depth {
        static let itemsBehind: Double = 0
        static let character: Double = 1
        static let itemsInFront: Double = 2
        static let effects: Double = 3
        static let bubble: Double = 4
    }

    var body: some View {
        let parts = ItemOrder.split(world.room.items, character: state.position,
                                    definitions: world.definitions)
        let frontIDs = Set(parts.front.map(\.id))
        ZStack {
            ForEach(parts.behind + parts.front) { item in
                if let definition = world.definitions[item.kind] {
                    ItemView(item: item, definition: definition, layout: layout, palette: palette,
                             showsCord: !look.overWallpaper)
                        .zIndex(frontIDs.contains(item.id) ? Depth.itemsInFront : Depth.itemsBehind)
                }
            }
            character.zIndex(Depth.character)
            EffectsView(state: state, room: world.room, layout: layout, definitions: world.definitions,
                        palette: palette, seconds: seconds, showsSparkles: look.showsSparkles,
                        showsSleepMarks: look.ambient == nil, shadowsInk: look.overWallpaper)
                .zIndex(Depth.effects)
            sparkles.zIndex(Depth.effects)
            sleepMarks.zIndex(Depth.effects)
            bubble.zIndex(Depth.bubble)
        }
    }

    private var pick: SpritePick { look.stills ? .still(state) : .live(state) }
    private var flourish: Flourish { look.flourishes ? state.flourish : .still }

    private var character: some View {
        ZStack {
            ShadowView(position: state.position, layout: layout, flourish: flourish,
                       characterScale: world.character.scale)
            if let ambient = look.ambient {
                AmbientCharacterView(character: world.character, position: state.position,
                                     cue: ambient.cue, layout: layout, anchor: ambient.anchor)
            } else {
                CharacterView(character: world.character, position: state.position, pick: pick,
                              layout: layout, flourish: flourish)
            }
        }
        .id(look.characterIdentity)
        .transition(.opacity)
    }

    @ViewBuilder
    private var bubble: some View {
        if let bubble = state.bubble {
            BubbleView(bubble: bubble, layout: layout, characterPosition: state.position,
                       characterHeight: layout.characterHeight(at: state.position,
                                                               characterScale: world.character.scale),
                       palette: palette, style: look.bubble, window: window(for: bubble))
                .id(look.characterIdentity)
                .transition(.opacity)
        }
    }

    /// 時報の吹き出しだけは、疑似アニメで描くとき 30 秒で隠す（3-C ③）。ほかの吹き出しは出したまま。
    private func window(for bubble: Bubble) -> AnchoredWindow? {
        guard bubble.kind == .clock, let ambient = look.ambient,
              let window = ambient.clockBubbleWindow else { return nil }
        return AnchoredWindow(window: window, anchor: ambient.anchor)
    }

    /// 疑似アニメで描くときの、寝ている「z」（5 秒ごとに z → zz → zzz）。止めた 1 枚で描くときは
    /// `EffectsView` が、エントリの時刻で浮かんでいる途中の 3 つを描く。
    @ViewBuilder
    private var sleepMarks: some View {
        if let ambient = look.ambient, state.activity.isAsleep {
            AmbientSleepMarks(windows: ambient.sleepMarkWindows, anchor: ambient.anchor,
                              origin: layout.point(state.position),
                              height: layout.characterHeight(at: state.position, characterScale: 1),
                              ink: palette.clockInk, shadowsInk: look.overWallpaper)
        }
    }

    /// ミラーボールでおどるときの光の粒（疑似アニメの段が 4fps のときだけ、動かし方に入っている）。
    @ViewBuilder
    private var sparkles: some View {
        if let ambient = look.ambient, !ambient.sparkleWindows.isEmpty, let ball = danceBallFrame {
            AmbientSparkles(windows: ambient.sparkleWindows, ball: ball, anchor: ambient.anchor,
                            palette: palette, unit: layout.unit)
        }
    }

    /// おどっているミラーボールの枠。
    private var danceBallFrame: CGRect? {
        guard case .dance(let itemID) = state.activity,
              let item = world.room.items.first(where: { $0.id == itemID }),
              let definition = world.definitions[item.kind] else { return nil }
        return layout.itemFrame(item, definition: definition)
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
