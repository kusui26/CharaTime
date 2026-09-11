import Foundation

/// 文脈による割り込み。
///
/// 日課表そのものは差し替えず、出来上がった `SceneState` の後段で合成する。
/// こうしておくと、割り込みが入っても日課の決定論は崩れない（プラン §5.4）。
///
/// **罰を与えない。** 放っておいても弱ったり死んだりはせず、電池が少ないときに
/// 動きが鈍くなる程度に留める。当時のケータイパートナーが「電池が一晩で空になる」
/// 「消せない BGM が鳴る」と嫌われた反省でもある（プラン §2.5）。
public enum Interrupts {

    /// これを下回ると動きが鈍くなる。
    public static let lowBatteryThreshold: Double = 0.15
    /// 充電を始めてから喜んでいる時間。
    public static let chargingReactionSeconds: TimeInterval = 180

    public static func apply(to state: SceneState, context: ContextSnapshot?) -> SceneState {
        guard let context else { return state }
        if let thanks = chargingReaction(to: state, context: context) { return thanks }
        return lowBatterySlowdown(of: state, context: context) ?? state
    }

    /// 充電を始めた直後だけ喜ぶ。ずっと喜んでいるとうるさいので時間で切る。
    private static func chargingReaction(to state: SceneState,
                                         context: ContextSnapshot) -> SceneState? {
        let sinceCapture = state.time.timeIntervalSince(context.capturedAt)
        guard context.isCharging == true,
              sinceCapture >= 0, sinceCapture < chargingReactionSeconds,
              !isAsleep(state.activity) else { return nil }
        var result = state
        result.changeActivity(to: .happyStretch)
        result.bubble = Bubble(text: "ありがとう", kind: .reaction)
        return result
    }

    /// 電池が少ないときは歩き回らない。吹き出しは出さない（急かさないため）。
    private static func lowBatterySlowdown(of state: SceneState,
                                           context: ContextSnapshot) -> SceneState? {
        guard let level = context.batteryLevel, level < lowBatteryThreshold,
              context.isCharging != true, case .wander = state.activity else { return nil }
        var result = state
        result.changeActivity(to: .idle)
        return result
    }

    static func isAsleep(_ activity: Activity) -> Bool {
        switch activity {
        case .sleep, .nap: true
        default: false
        }
    }
}
