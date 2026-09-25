import Foundation

/// ウィジェットがいまどう見せられているか（プラン §9 Phase 3 の 3-C ⑤⑨）。
///
/// WidgetKit の環境（描き分け・背景を敷いたままか・Reduce Motion・減光）の束。描き方の決まり
/// （部屋を描くか・字の色・吹き出しの塗り方・段）は、この値だけから決める。
/// 環境から切り離しておくのは、アプリ内の下見で StandBy をまねるため（シミュレータに StandBy は無く、
/// 背景を外したかどうかの値は、WidgetKit の外から書き換えられない）。
public struct WidgetDisplay: Sendable, Equatable {

    public var tone: WidgetTone
    /// OS が背景（`containerBackground`）を敷いたまま見せているか。StandBy・着色・クリアでは外す。
    public var showsBackground: Bool
    public var reduceMotion: Bool
    /// 常時表示の減光中。
    public var luminanceReduced: Bool

    public init(tone: WidgetTone, showsBackground: Bool, reduceMotion: Bool = false,
                luminanceReduced: Bool = false) {
        self.tone = tone
        self.showsBackground = showsBackground
        self.reduceMotion = reduceMotion
        self.luminanceReduced = luminanceReduced
    }

    /// ふつうのホーム画面。
    public static let homeScreen = WidgetDisplay(tone: .fullColor, showsBackground: true)
    /// StandBy の昼。背景が外され、黒の上にフルカラーで出る（`research/B` §5）。
    public static let standByDay = WidgetDisplay(tone: .fullColor, showsBackground: false)
    /// StandBy の夜。背景が外され、明るさだけの赤で出る（vibrant）。
    public static let standByNight = WidgetDisplay(tone: .vibrant, showsBackground: false)
}

public extension WidgetDisplay {

    /// 部屋（壁・床・窓・敷物）を描くか。背景を外す描き方では描かず、床を薄く示す（D-28）。
    var drawsRoom: Bool { tone == .fullColor && showsBackground }

    /// 中身の後ろが暗いか。StandBy の昼は黒の上に出て、夜（vibrant）は明るさだけが赤く残る。
    /// どちらも濃い字や線が消える。着色・クリアは透明度だけで描かれるので、ここに入らない。
    var hasDarkBackdrop: Bool {
        tone == .vibrant || (tone == .fullColor && !showsBackground)
    }

    /// その見え方で使う配色。後ろが暗ければ、z や時計の字を淡い色にする。
    func palette(_ base: RoomPalette) -> RoomPalette {
        hasDarkBackdrop ? base.overDarkness() : base
    }

    /// 描画の段（3-C ⑤）。StandBy の夜は vibrant なので、5 分ごとの切り替えに落ちる。
    func capability(motion: WidgetMotion, system: SystemVersion = .current) -> RenderCapability {
        RenderCapability.resolve(RenderContext(
            surface: .homeWidget, system: system, tone: tone,
            pseudoAnimationEnabled: motion.pseudoAnimation, reduceMotion: reduceMotion,
            lowPowerMode: motion.lowPowerMode, luminanceReduced: luminanceReduced))
    }
}
