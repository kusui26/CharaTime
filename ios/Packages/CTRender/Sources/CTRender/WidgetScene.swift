import SwiftUI
import WidgetKit
import CTCore
import CTStore

/// ホーム画面ウィジェットの絵（プラン §9 Phase 3 の 3-C ⑥）。大・中・小で、部屋の写し方だけが違う。
///
/// **部屋（壁・床・窓・敷物）も中身と一緒に描く。** `containerBackground` に置くと、エントリ切替の
/// アニメで中身だけが動き、背景と食い違う瞬間ができるため。背景を外す描き方（着色・クリア・
/// StandBy）では部屋を描かず、キャラとアイテムだけにする（OS が背景を敷き直す）。
/// どう見せられているか（`WidgetDisplay`）は WidgetKit の環境から読む。StandBy の黒の上と夜の赤では、
/// 字を淡い色にし、吹き出しの塗り方を替える（3-C ⑨）。
///
/// 描画の段（3-C ⑤）が 1fps 以上なら、止めた 1 枚の上で、まばたき・寝息・よろこぶを
/// マスク書体のタイマーで出し入れする（疑似アニメ。3-C ④）。段が下がれば止めた 1 枚だけを描く。
/// エントリが切り替わると、キャラを約 1.5 秒かけて新しい居場所へ滑らせる（④'）。
/// 遠くへ移るときは滑らせず、消えて現れる（`WidgetMoment.leg`）。
public struct WidgetScene: View {

    public let family: WidgetSlot.Family
    public let moment: WidgetMoment
    public let world: SceneWorld
    public let motion: WidgetMotion
    /// 見え方の決め打ち。アプリ内の下見で StandBy をまねるときだけ渡す。nil なら WidgetKit の環境に従う。
    public let displayOverride: WidgetDisplay?

    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var luminanceReduced

    public init(family: WidgetSlot.Family, moment: WidgetMoment, world: SceneWorld,
                motion: WidgetMotion = .still, display: WidgetDisplay? = nil) {
        self.family = family
        self.moment = moment
        self.world = world
        self.motion = motion
        self.displayOverride = display
    }

    /// エントリ切替でキャラを滑らせる長さ（秒）。OS がエントリ切替に許すアニメは最大 2 秒で、
    /// スパイク F では 1.5 秒の台が乱れずに動いた（3-C ①、R-21）。
    static let slideSeconds: Double = 1.5

    public var body: some View {
        let display = self.display
        let palette = display.palette(.forNight(moment.isNight))
        GeometryReader { geometry in
            let stage = WidgetStage.stage(for: family)
            let layout = stage.layout(size: geometry.size, room: world.room,
                                      geometry: world.spriteGeometry,
                                      characterScale: world.character.scale)
            let ambient = moment.ambientLook(at: display.capability(motion: motion))
            ZStack {
                if display.drawsRoom {
                    RoomView(layout: layout, palette: palette, showsWindow: stage.showsWindow,
                             showsRug: true, isNight: moment.isNight)
                } else {
                    FloorHint(layout: layout, fadesEdges: display.hasDarkBackdrop)
                }
                SceneLayers(state: moment.state, world: world, layout: layout, palette: palette,
                            look: .widget(identity: moment.leg, tone: display.tone, ambient: ambient),
                            seconds: moment.date.timeIntervalSinceReferenceDate)
            }
            .animation(slide(display), value: moment.date)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
        .containerBackground(palette.wall, for: .widget)
    }

    /// いまの見え方。決め打ちが無ければ、WidgetKit の環境から読む。
    private var display: WidgetDisplay {
        displayOverride ?? WidgetDisplay(tone: WidgetTone(renderingMode), showsBackground: showsBackground,
                                         reduceMotion: reduceMotion, luminanceReduced: luminanceReduced)
    }

    /// VoiceOver で読む中身。キャラの名前と、吹き出しの言葉。
    private var spokenSummary: String {
        [world.character.displayName, moment.state.bubble?.text].compactMap { $0 }.joined(separator: "、")
    }

    /// エントリ切替の動き。Reduce Motion では滑らせず、すぐ入れ替える（D-19）。
    /// 常時表示の減光中は、OS がそもそもアニメを行わない。
    private func slide(_ display: WidgetDisplay) -> Animation? {
        display.reduceMotion || display.luminanceReduced ? nil : .easeInOut(duration: Self.slideSeconds)
    }
}

/// ウィジェットを動かしてよいか。タイムラインを作ったときに決まること（3-C ⑤）。
public struct WidgetMotion: Sendable, Equatable {

    /// 疑似アニメを使うか。設定（`WidgetSettings.usesPseudoAnimation`）が入で、マスク書体が
    /// 登録されているとき。書体が無いとシステムの字に落ち、数字の形の穴から絵が覗くため。
    public var pseudoAnimation: Bool
    /// タイムラインを作ったときに低電力モードだったか（電池を守る。3-C ⑤）。
    public var lowPowerMode: Bool

    public init(pseudoAnimation: Bool, lowPowerMode: Bool) {
        self.pseudoAnimation = pseudoAnimation
        self.lowPowerMode = lowPowerMode
    }

    /// 動かさない（止めた 1 枚）。
    public static let still = WidgetMotion(pseudoAnimation: false, lowPowerMode: false)
}

public extension WidgetMoment {

    /// その描画の段で、疑似アニメをどう描くか。段が 1fps に届かなければ nil（止めた 1 枚）。
    /// 1fps の段では、0.25 秒ずつ動くもの（光の粒）を外す。
    internal func ambientLook(at capability: RenderCapability) -> AmbientLook? {
        guard capability >= .ambient1fps else { return nil }
        let pace: AmbientPace = capability >= .ambient4fps ? .quarterSecond : .perSecond
        return AmbientLook(cue: cue.limited(to: pace), anchor: anchor)
    }
}

/// 部屋を描かないときの、床の手がかり（着色・クリア・StandBy）。
///
/// OS が背景を外すと、アイテムもキャラも宙に浮いて見える。床を半透明の帯と線だけで描いて、
/// 足元を支える。その描き方では色の違いが消え、濃さの違いだけが残る（3-0）ので、濃さだけで描く。
struct FloorHint: View {

    let layout: SceneLayout
    /// 帯の両端を闇へぼかすか。StandBy は背景もウィジェットの枠も見えないので、端まで塗ると
    /// 帯の四角い端が箱の縁に見える（3-5）。着色・クリアはガラスの板が枠を見せるので、端まで塗る。
    var fadesEdges = false

    /// 床の帯と、壁との境の線の濃さ。
    private static let floorOpacity: Double = 0.10
    private static let lineOpacity: Double = 0.30
    /// 境の線の太さ（舞台の高さに対する比。部屋の絵と同じ）。
    private static let lineRatio: Double = 0.005
    /// ぼかす幅（ウィジェットの幅に対する比。両端それぞれ）。
    private static let fadeWidthRatio: Double = 0.22

    var body: some View {
        Canvas { context, size in
            let horizon = layout.horizonY
            let line = layout.stage.height * Self.lineRatio
            fill(&context, CGRect(x: 0, y: horizon, width: size.width, height: size.height - horizon),
                 opacity: Self.floorOpacity)
            fill(&context, CGRect(x: 0, y: horizon - line / 2, width: size.width, height: line),
                 opacity: Self.lineOpacity)
        }
    }

    /// 白を `opacity` の濃さで塗る。端をぼかすときは、左右の端で透明になるように塗る。
    private func fill(_ context: inout GraphicsContext, _ rect: CGRect, opacity: Double) {
        let white = Color.white.opacity(opacity)
        guard fadesEdges else { return context.fill(Path(rect), with: .color(white)) }
        let clear = Color.white.opacity(0)
        let fade = Self.fadeWidthRatio
        let gradient = Gradient(stops: [
            .init(color: clear, location: 0), .init(color: white, location: fade),
            .init(color: white, location: 1 - fade), .init(color: clear, location: 1)
        ])
        let start = CGPoint(x: rect.minX, y: rect.midY)
        let end = CGPoint(x: rect.maxX, y: rect.midY)
        context.fill(Path(rect), with: .linearGradient(gradient, startPoint: start, endPoint: end))
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
