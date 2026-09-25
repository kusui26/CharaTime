import Foundation

/// ウィジェット系の面をどこまで動かすか（プラン §7.5、§9 Phase 3 の 3-C ⑤）。
///
/// アニメの実装方法を View に直書きせず、この段階で切り替える。上から順に試し、
/// 使えなければ 1 段下がる。**最下段の静止画までは必ず描けるので、OS の更新で
/// 疑似アニメが止まっても「キャラが消える」ことは起きない。**
public enum RenderCapability: Int, Comparable, Codable, Sendable, CaseIterable {
    /// 静止画 1 枚。最後の砦。
    case staticOnly = 0
    /// 5 分ごとの静止画＋エントリ切替の 2 秒トランジション。Apple 公式の方式。
    case timelineTransition = 1
    /// `Text(timerInterval:)` とマスク用フォントで 1fps（まばたき・呼吸）。
    case ambient1fps = 2
    /// 位相をずらした複数タイマーで 2〜4fps（光の粒）。
    case ambient4fps = 3

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public var label: String {
        switch self {
        case .staticOnly:         "静止画"
        case .timelineTransition: "5 分ごとに切り替え"
        case .ambient1fps:        "1fps"
        case .ambient4fps:        "2〜4fps"
        }
    }
}

/// キャラを出す面。待受モード（アプリ内）だけはこの梯子の外で、60fps で描く。
public enum Surface: String, Codable, Sendable, CaseIterable {
    case standbyMode      // 面0 アプリ内の待受モード
    case homeWidget       // 面1 ホーム画面ウィジェット
    case standBy          // 面2 StandBy
    case liveActivity     // 面3 Live Activity / Dynamic Island
    case lockWidget       // ロック画面ウィジェット
}

/// ウィジェットの描き分け（WidgetKit の `widgetRenderingMode` と同じ 3 つ）。
public enum WidgetTone: Sendable, CaseIterable {
    /// ふつうのホーム画面。
    case fullColor
    /// 着色・クリアの外観。背景が外され、中身は 1 色の濃淡になる。絵は `fullColor` を
    /// 指定したものだけが色を保つ（3-0 のスパイク F）。
    case accented
    /// StandBy の夜・ロック画面。背景が外され、明るさだけの 1 色になる。
    case vibrant
}

/// 動いている OS の版。
public struct SystemVersion: Sendable, Equatable, Comparable {
    public var major: Int
    public var minor: Int

    public init(major: Int, minor: Int = 0) {
        self.major = major
        self.minor = minor
    }

    public init(_ version: OperatingSystemVersion) {
        self.init(major: version.majorVersion, minor: version.minorVersion)
    }

    /// この端末の OS。
    public static var current: SystemVersion { SystemVersion(ProcessInfo.processInfo.operatingSystemVersion) }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor) < (rhs.major, rhs.minor)
    }
}

/// 疑似アニメが動くと確かめた OS の表（プラン D-22）。
///
/// 疑似アニメは公開 API の使い方としては想定外で、OS の更新で塞がれうる（R-13）。
/// **表に無い版では上げない。** 新しい版は、本番のウィジェットで確かめてから足す（スパイク E は 3-2c で消した）。
public enum VerifiedSystems {

    /// iOS 26.x（実機 26.1、シミュレータ 26.5 で確かめた。スパイク E・F）。
    public static let pseudoAnimationMajors: Set<Int> = [26]

    public static func allowsPseudoAnimation(_ system: SystemVersion) -> Bool {
        pseudoAnimationMajors.contains(system.major)
    }
}

public struct RenderContext: Sendable, Equatable {
    public var surface: Surface
    /// 動いている OS。確かめた版の表（`VerifiedSystems`）に無ければ上げない。
    public var system: SystemVersion
    /// ウィジェットの描き分け。ウィジェット以外の面では `.fullColor`。
    public var tone: WidgetTone
    /// 設定の疑似アニメの入／切（`WidgetSettings.usesPseudoAnimation`）。
    public var pseudoAnimationEnabled: Bool
    public var reduceMotion: Bool
    public var lowPowerMode: Bool
    /// 常時表示の減光中。この状態では OS がそもそもアニメを行わない。
    public var luminanceReduced: Bool

    public init(surface: Surface, system: SystemVersion = .current, tone: WidgetTone = .fullColor,
                pseudoAnimationEnabled: Bool = false, reduceMotion: Bool = false,
                lowPowerMode: Bool = false, luminanceReduced: Bool = false) {
        self.surface = surface
        self.system = system
        self.tone = tone
        self.pseudoAnimationEnabled = pseudoAnimationEnabled
        self.reduceMotion = reduceMotion
        self.lowPowerMode = lowPowerMode
        self.luminanceReduced = luminanceReduced
    }
}

public extension RenderCapability {

    /// 面と端末の状態から、実際に使う段を決める（3-C ⑤ の表を上から順に）。
    ///
    /// 迷ったら下げる。上げてよいのは、確かめた OS で、設定が入で、単色（vibrant）で描いておらず、
    /// 省電力でも減光中でもないときだけ。着色・クリアと Reduce Motion では 1fps まで。
    static func resolve(_ context: RenderContext) -> RenderCapability {
        if let fixed = fixedCapability(for: context) { return fixed }
        return Swift.min(ceiling(for: context.system), throttle(for: context))
    }

    /// 面や端末の状態だけで段が決まってしまう場合。ほかの条件を見るまでもない。
    private static func fixedCapability(for context: RenderContext) -> RenderCapability? {
        // 常時表示の減光中は OS がアニメを行わない。上げても電池を使うだけ。
        if context.luminanceReduced { return .staticOnly }
        // ロック画面は脱色表示で、そもそも細かい動きが読めない。
        if context.surface == .lockWidget { return .timelineTransition }
        // 待受モードは SwiftUI が 60fps で描くので、この梯子を使わない。
        // 呼ばれたときは最上段を返しておく（描画側が別経路を選ぶ）。
        if context.surface == .standbyMode { return .ambient4fps }
        return nil
    }

    /// OS が許す上限。確かめていない版では、公式の方式に留める（D-22）。
    private static func ceiling(for system: SystemVersion) -> RenderCapability {
        VerifiedSystems.allowsPseudoAnimation(system) ? .ambient4fps : .timelineTransition
    }

    /// 設定・省電力・描き分け・面の制約による頭打ち。**迷ったら下げる**ので、
    /// 頭打ちが重なったら低いほうを採る。
    private static func throttle(for context: RenderContext) -> RenderCapability {
        // 単色（vibrant）は細かい動きが読めない。
        let heldDown = !context.pseudoAnimationEnabled
            || context.lowPowerMode
            || context.tone == .vibrant
        let byState: RenderCapability = heldDown ? .timelineTransition : .ambient4fps

        // 着色・クリア（accented）は 1fps まで。タイマーは止まらず、重ねる絵（まぶた・コマ）も
        // fullColor で色を保つ（3-2b でホーム画面を収録して確かめた）。光の粒（4fps）は図形なので
        // この描き方では色を失い、見え方も確かめていない。
        let byTone: RenderCapability = context.tone == .accented ? .ambient1fps : .ambient4fps

        // Reduce Motion も 1fps まで（D-19。2026-09-25 に改めた）。減らしたいのは大きな動きなので、
        // その場での小さな変化（まばたき・寝息・z）は続け、1 秒に 4 回のきらめきは止める。
        // エントリ切替の横すべりは `WidgetScene` が止める。
        let byMotion: RenderCapability = context.reduceMotion ? .ambient1fps : .ambient4fps

        // Live Activity は 4KB の制約があり、コマ数を増やしても載らない。
        let bySurface: RenderCapability = context.surface == .liveActivity
            ? .ambient1fps : .ambient4fps

        return Swift.min(byState, byTone, byMotion, bySurface)
    }
}
