import Testing
import Foundation
import CTStore
@testable import CTRender

/// 記録表の見せ方（プラン §9 Phase 3 の 3-7）。画面と書き出しで同じ言い方をする。
@Suite("1 週間の運用の見せ方")
struct WeekRunFormatTests {

    @Test("答えと結果の言い方。まだなら「—」と「まだ」")
    func answers() {
        #expect(WeekRunFormat.answer(.yes) == "はい")
        #expect(WeekRunFormat.answer(.no) == "いいえ")
        #expect(WeekRunFormat.answer(nil) == "—")
        #expect(WeekRunFormat.result(.yes) == "期待どおり")
        #expect(WeekRunFormat.result(.no) == "ちがった")
        #expect(WeekRunFormat.result(nil) == "まだ")
    }

    @Test("1 日のまとめ: その日に聞いた問いの答えと、読んでいれば電池")
    func daySummary() {
        let first = WeekRunDay(number: 1, characterVisible: .yes, animating: .yes,
                               battery: BatteryUsage(charaTimePercent: 2, homeAndLockPercent: 5))
        #expect(WeekRunFormat.daySummary(first) == "見えていた はい・動いていた はい・同じ姿 —・電池 2%／5%")
        // 切の日は、まばたきを聞かない
        let second = WeekRunDay(number: 2, characterVisible: .yes, matchesApp: .no)
        #expect(WeekRunFormat.daySummary(second) == "見えていた はい・同じ姿 いいえ")
    }

    @Test("自動の記録の 1 日: 大きさごとの回数と最長の間隔、メモリ、疑似アニメ")
    func automatic() {
        let day = WidgetDiagnostics.DaySummary(day: Date(timeIntervalSince1970: 0),
                                               reloadCounts: [.large: 5, .small: 8],
                                               longestGapSeconds: [.large: 6.1 * 3600],
                                               peakBytes: 14_000_000, pseudoAnimation: [true, false])
        #expect(WeekRunFormat.automatic(day) == "大 5 回（最長 6.1 時間）・小 8 回・13.4 MB・入・切")
        let empty = WidgetDiagnostics.DaySummary(day: Date(timeIntervalSince1970: 0), reloadCounts: [:],
                                                 longestGapSeconds: [:], peakBytes: nil, pseudoAnimation: [])
        #expect(WeekRunFormat.automatic(empty) == "作り直しなし")
    }

    /// 記録の上限で古い記録が捨てられた日を、「作り直しなし」と読ませない。
    @Test("一部だけの日は、そうと分かるように書く")
    func partialDay() {
        let lost = WidgetDiagnostics.DaySummary(day: Date(timeIntervalSince1970: 0), reloadCounts: [:],
                                                longestGapSeconds: [:], peakBytes: nil, pseudoAnimation: [],
                                                isPartial: true)
        #expect(WeekRunFormat.automatic(lost) == "記録が残っていません（上限で古い記録が消えた）")
        let half = WidgetDiagnostics.DaySummary(day: Date(timeIntervalSince1970: 0), reloadCounts: [.large: 2],
                                                longestGapSeconds: [:], peakBytes: 1_048_576, pseudoAnimation: [true],
                                                isPartial: true)
        #expect(WeekRunFormat.automatic(half) == "大 2 回・1.0 MB・入（この日の前のほうは、上限で消えた）")
    }
}
