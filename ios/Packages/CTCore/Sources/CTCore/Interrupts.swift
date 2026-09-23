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
    /// 文脈がこれより古ければ、電池の割り込みに使わない。
    ///
    /// ウィジェットは、本体アプリが最後に読んだ電池の値を使う（プラン §9 Phase 3 の 3-C ⑩）。
    /// アプリを開かないあいだに値は古くなるので、朝の 10% のまま一日じゅう歩かせない、
    /// ということにならないよう 1 時間で信用しなくする。電池は 1 時間で大きく変わりうる。
    public static let freshnessSeconds: TimeInterval = 3600

    public static func apply(to state: SceneState, context: ContextSnapshot?) -> SceneState {
        guard let context else { return state }
        if let thanks = chargingReaction(to: state, context: context) { return thanks }
        return lowBatterySlowdown(of: state, context: context) ?? state
    }

    /// 充電を始めた直後だけ喜ぶ。ずっと喜んでいるとうるさいので時間で切る。
    ///
    /// 数えるのは充電を始めた時刻から。読み直した時刻からではない（読み直すたびに喜ばない）。
    private static func chargingReaction(to state: SceneState,
                                         context: ContextSnapshot) -> SceneState? {
        guard context.isCharging == true, let since = context.chargingSince,
              (0..<chargingReactionSeconds).contains(state.time.timeIntervalSince(since)),
              !state.activity.isAsleep else { return nil }
        var result = state
        result.changeActivity(to: .happyStretch)
        result.bubble = Bubble(text: "ありがとう", kind: .reaction)
        return result
    }

    /// 電池が少ないときは歩き回らない。吹き出しは出さない（急かさないため）。
    /// 1 時間より古い値では鈍らせない（`freshnessSeconds`）。
    private static func lowBatterySlowdown(of state: SceneState,
                                           context: ContextSnapshot) -> SceneState? {
        guard (0..<freshnessSeconds).contains(state.time.timeIntervalSince(context.capturedAt)),
              context.isLowBattery, case .wander = state.activity else { return nil }
        var result = state
        result.changeActivity(to: .idle)
        return result
    }

    /// 文脈が変わって、割り込みの答え（喜ぶ・鈍る）が変わりうるか（プラン §9 Phase 3 の 3-C ⑩）。
    ///
    /// 本体アプリは電池の知らせのたびに文脈を書き直す（充電中は 1% ごとに届く）。ウィジェットを
    /// 作り直すのは、答えが変わりうるときだけにする。作り直すたびに、拡張が 73 件を描き直すため。
    /// 電池が少ないあいだは、読み直すだけでも作り直す。鈍る時間（読んでから 1 時間）が延びるため。
    public static func mayChangeScene(from old: ContextSnapshot?, to new: ContextSnapshot?) -> Bool {
        switch (old, new) {
        case (nil, nil):
            false
        case (nil, _?), (_?, nil):
            true
        case let (old?, new?):
            old.isCharging != new.isCharging
                || old.chargingSince != new.chargingSince
                || old.isLowBattery != new.isLowBattery
                || (new.isLowBattery && old.capturedAt != new.capturedAt)
        }
    }
}

public extension ContextSnapshot {
    /// 電池が少ないとみなすか。充電中は、残りが少なくても鈍らせない。
    var isLowBattery: Bool {
        guard let level = batteryLevel, isCharging != true else { return false }
        return level < Interrupts.lowBatteryThreshold
    }
}
