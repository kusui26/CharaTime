import Foundation
import CTStore

/// 1 週間の運用の記録表の見せ方（プラン §9 Phase 3 の 3-7）。画面と書き出しで同じ言い方をする。
/// 純粋な変換なので View の外に置く（View の静的な値は `@MainActor` に縛られる）。
public enum WeekRunFormat {

    /// 毎日の問いの答え。まだなら「—」。
    public static func answer(_ answer: WeekRunAnswer?) -> String {
        switch answer {
        case .yes: "はい"
        case .no: "いいえ"
        case nil: "—"
        }
    }

    /// 一度だけ確かめることの結果。
    public static func result(_ answer: WeekRunAnswer?) -> String {
        switch answer {
        case .yes: "期待どおり"
        case .no: "ちがった"
        case nil: "まだ"
        }
    }

    /// タイムラインの疑似アニメ（入は true）。入と切が混ざれば両方、記録が無ければ「—」。
    static func pseudoAnimation(_ states: Set<Bool>) -> String {
        switch (states.contains(true), states.contains(false)) {
        case (true, true): "入・切"
        case (true, false): "入"
        case (false, true): "切"
        case (false, false): "—"
        }
    }

    /// 「6.1 時間」。
    static func hours(_ seconds: TimeInterval) -> String {
        String(format: "%.1f 時間", seconds / secondsPerHour)
    }

    private static let secondsPerHour: TimeInterval = 3600

    /// 1 日の記録のまとめ: 「見えていた はい・動いていた はい・同じ姿 —・電池 2%／5%」。
    /// その日に聞いた問いだけを並べる（切の日は、まばたきを聞かない）。
    public static func daySummary(_ day: WeekRunDay) -> String {
        let answers = WeekRunQuestion.asked(on: day.number).map { question in
            question.shortTitle + " " + answer(day[keyPath: question.answer])
        }
        let battery = day.battery.map { usage in
            "電池 " + percent(usage.charaTimePercent) + "／" + percent(usage.homeAndLockPercent)
        }
        return (answers + [battery].compactMap { $0 }).joined(separator: "・")
    }

    /// 「2%」。まだなら「—」。
    static func percent(_ value: Int?) -> String {
        value.map { "\($0)%" } ?? "—"
    }

    /// 自動の記録の 1 日: 「大 5 回（最長 6.1 時間）・小 8 回・13.4 MB・入」。作り直しが無ければ、そう書く。
    /// 上限で古い記録が捨てられた日は、そうと分かるように書く（「作り直しなし」と取り違えない）。
    public static func automatic(_ day: WidgetDiagnostics.DaySummary) -> String {
        let families = [WidgetSlot.Family.large, .medium, .small].compactMap { family -> String? in
            guard let count = day.reloadCounts[family] else { return nil }
            let gap = day.longestGapSeconds[family].map { "（最長 " + hours($0) + "）" } ?? ""
            return "\(family.displayName) \(count) 回" + gap
        }
        guard !families.isEmpty else {
            return day.isPartial ? "記録が残っていません（上限で古い記録が消えた）" : "作り直しなし"
        }
        let extras = [day.peakBytes.map(WidgetRecordFormat.megabytes), pseudoAnimation(day.pseudoAnimation)]
        let summary = (families + extras.compactMap { $0 }).joined(separator: "・")
        return day.isPartial ? summary + "（この日の前のほうは、上限で消えた）" : summary
    }
}
