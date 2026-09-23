import SwiftUI
import WidgetKit
import CTCore
import CTStore

/// ホーム画面ウィジェットの絵（プラン §9 Phase 3 の 3-C ⑥）。大・中・小で、部屋の写し方だけが違う。
///
/// **部屋（壁・床・窓・敷物）も中身と一緒に描く。** `containerBackground` に置くと、エントリ切替の
/// アニメで中身だけが動き、背景と食い違う瞬間ができるため。背景を外す描き方（着色・クリア・
/// StandBy）では部屋を描かず、キャラとアイテムだけにする（OS が背景を敷き直す）。
///
/// 絵は止めた 1 枚（`SpritePick.still`）。エントリが切り替わると、キャラを約 1.5 秒かけて
/// 新しい居場所へ滑らせる（④'）。遠くへ移るときは滑らせず、消えて現れる（`WidgetMoment.leg`）。
public struct WidgetScene: View {

    public let family: WidgetSlot.Family
    public let moment: WidgetMoment
    public let world: SceneWorld

    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var luminanceReduced

    public init(family: WidgetSlot.Family, moment: WidgetMoment, world: SceneWorld) {
        self.family = family
        self.moment = moment
        self.world = world
    }

    /// エントリ切替でキャラを滑らせる長さ（秒）。OS がエントリ切替に許すアニメは最大 2 秒で、
    /// スパイク F では 1.5 秒の台が乱れずに動いた（3-C ①、R-21）。
    static let slideSeconds: Double = 1.5

    public var body: some View {
        let tone = WidgetTone(renderingMode)
        let palette = RoomPalette.forNight(moment.isNight)
        GeometryReader { geometry in
            let stage = WidgetStage.stage(for: family)
            let layout = stage.layout(size: geometry.size, room: world.room,
                                      geometry: world.spriteGeometry,
                                      characterScale: world.character.scale)
            ZStack {
                if tone == .fullColor && showsBackground {
                    RoomView(layout: layout, palette: palette, showsWindow: stage.showsWindow,
                             showsRug: true, isNight: moment.isNight)
                } else {
                    FloorHint(layout: layout)
                }
                SceneLayers(state: moment.state, world: world, layout: layout, palette: palette,
                            look: .widget(identity: moment.leg, tone: tone),
                            seconds: moment.date.timeIntervalSinceReferenceDate)
            }
            .animation(slide, value: moment.date)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
        .containerBackground(palette.wall, for: .widget)
    }

    /// VoiceOver で読む中身。キャラの名前と、吹き出しの言葉。
    private var spokenSummary: String {
        [world.character.displayName, moment.state.bubble?.text].compactMap { $0 }.joined(separator: "、")
    }

    /// エントリ切替の動き。Reduce Motion では滑らせず、すぐ入れ替える（D-19）。
    /// 常時表示の減光中は、OS がそもそもアニメを行わない。
    private var slide: Animation? {
        reduceMotion || luminanceReduced ? nil : .easeInOut(duration: Self.slideSeconds)
    }
}

/// 部屋を描かないときの、床の手がかり（着色・クリア・StandBy）。
///
/// OS が背景を外すと、アイテムもキャラも宙に浮いて見える。床を半透明の帯と線だけで描いて、
/// 足元を支える。その描き方では色の違いが消え、濃さの違いだけが残る（3-0）ので、濃さだけで描く。
struct FloorHint: View {

    let layout: SceneLayout

    /// 床の帯と、壁との境の線の濃さ。
    private static let floorOpacity: Double = 0.10
    private static let lineOpacity: Double = 0.30
    /// 境の線の太さ（舞台の高さに対する比。部屋の絵と同じ）。
    private static let lineRatio: Double = 0.005

    var body: some View {
        Canvas { context, size in
            let horizon = layout.horizonY
            context.fill(Path(CGRect(x: 0, y: horizon, width: size.width, height: size.height - horizon)),
                         with: .color(.white.opacity(Self.floorOpacity)))
            let line = layout.stage.height * Self.lineRatio
            context.fill(Path(CGRect(x: 0, y: horizon - line / 2, width: size.width, height: line)),
                         with: .color(.white.opacity(Self.lineOpacity)))
        }
    }
}

extension WidgetTone {
    /// WidgetKit の描き分けから。知らない描き分けは、いちばん手厚いフルカラーとして描く。
    init(_ mode: WidgetRenderingMode) {
        if mode == .accented {
            self = .accented
        } else if mode == .vibrant {
            self = .vibrant
        } else {
            self = .fullColor
        }
    }
}
