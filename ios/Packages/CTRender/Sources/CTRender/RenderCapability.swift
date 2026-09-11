import Foundation

/// ウィジェット系の面をどこまで動かすか（プラン §7.5）。
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
    /// 位相をずらした複数タイマーで 2〜4fps（歩行）。
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

/// Phase 0 のスパイクの判定（プラン D-11）。実機で測るまでは `unknown`。
public enum SpikeVerdict: String, Codable, Sendable {
    case unknown
    case go
    case conditionalGo
    case noGo
}

public struct RenderContext: Sendable, Equatable {
    public var surface: Surface
    public var spike: SpikeVerdict
    /// 設定の feature flag。スパイクで Go が出るまでは切っておく。
    public var pseudoAnimationEnabled: Bool
    public var reduceMotion: Bool
    public var lowPowerMode: Bool
    /// 常時表示の減光中。この状態では OS がそもそもアニメを行わない。
    public var luminanceReduced: Bool

    public init(surface: Surface, spike: SpikeVerdict = .unknown,
                pseudoAnimationEnabled: Bool = false, reduceMotion: Bool = false,
                lowPowerMode: Bool = false, luminanceReduced: Bool = false) {
        self.surface = surface
        self.spike = spike
        self.pseudoAnimationEnabled = pseudoAnimationEnabled
        self.reduceMotion = reduceMotion
        self.lowPowerMode = lowPowerMode
        self.luminanceReduced = luminanceReduced
    }
}

public extension RenderCapability {

    /// 面と端末の状態から、実際に使う段を決める。
    ///
    /// 迷ったら下げる。上げてよいのは、スパイクで Go が出ていて、設定が入で、
    /// 省電力でも Reduce Motion でも減光中でもないときだけ。
    static func resolve(_ context: RenderContext) -> RenderCapability {
        if let fixed = fixedCapability(for: context) { return fixed }
        return Swift.min(ceiling(forSpike: context.spike), throttle(for: context))
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

    /// 実機スパイクの判定が許す上限。測るまでは安全側に置く（プラン D-11）。
    private static func ceiling(forSpike spike: SpikeVerdict) -> RenderCapability {
        switch spike {
        case .go: .ambient4fps
        case .conditionalGo, .noGo, .unknown: .timelineTransition
        }
    }

    /// 設定・省電力・面の制約による頭打ち。**迷ったら下げる**ので、
    /// 2 つの頭打ちは低いほうを採る。
    private static func throttle(for context: RenderContext) -> RenderCapability {
        // 設定が切、Reduce Motion、省電力のどれかなら上げない。
        let heldDown = !context.pseudoAnimationEnabled
            || context.reduceMotion
            || context.lowPowerMode
        let byState: RenderCapability = heldDown ? .timelineTransition : .ambient4fps

        // Live Activity は 4KB の制約があり、コマ数を増やしても載らない。
        let bySurface: RenderCapability = context.surface == .liveActivity
            ? .ambient1fps : .ambient4fps

        return Swift.min(byState, bySurface)
    }
}
