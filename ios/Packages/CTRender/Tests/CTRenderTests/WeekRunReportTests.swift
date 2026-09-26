import Testing
import Foundation
import CoreGraphics
import CTStore
@testable import CTRender

/// 1 週間の運用（プラン §9 Phase 3 の 3-7）の記録を、1 つの文章に書き出す。
@Suite("1 週間の運用の書き出し")
struct WeekRunReportTests {

    static let tokyo = WeekRunPlanTests.tokyo
    /// 2026-09-26（土）9:00（日本時間）。
    static let start = WeekRunPlanTests.start
    static let hour: TimeInterval = 3600

    static func reload(_ hours: Double, _ family: WidgetSlot.Family = .large, peak: UInt64 = 12_000_000,
                       pseudoAnimation: Bool = true, size: CGSize? = nil) -> WidgetReload {
        WidgetReload(date: start.addingTimeInterval(hours * hour), family: family, entryCount: 73,
                     footprintBytes: 1, peakBytes: peak, pseudoAnimation: pseudoAnimation, displaySize: size)
    }

    static let record = WeekRunRecord(startedAt: start)
        .updatingDay(1) { day in
            day.characterVisible = .yes
            day.animating = .yes
            day.matchesApp = .yes
            day.battery = BatteryUsage(charaTimePercent: 2, homeAndLockPercent: 5,
                                       readAt: start.addingTimeInterval(13 * hour))
        }
        .updatingDay(2) { day in
            day.characterVisible = .yes
            day.matchesApp = .no
            day.note = "一瞬ずれた | 次は\n合った"
        }
        .updatingCheck("afterUnlock") { check in
            check.answer = .yes
            check.answeredAt = start.addingTimeInterval(0.5 * hour)
        }
        .updatingCheck("lowPower") { check in
            check.answer = .no
            check.note = "まばたきが続いた"
        }

    static let diagnostics = WidgetDiagnostics(reloads: [
        reload(-20),
        reload(0, peak: 13_000_000, size: CGSize(width: 349.67, height: 365)),
        reload(1, .small, peak: 14_000_000),
        reload(25, pseudoAnimation: false),
    ])

    /// 2 日目の 11:00 に書き出す。
    static let report = WeekRunReport.markdown(record: record, diagnostics: diagnostics,
                                               now: start.addingTimeInterval(26 * hour), calendar: tokyo,
                                               system: SystemVersion(major: 26, minor: 1))

    @Test("見出しに、書き出した時刻・始めた日・いま何日目か・iOS の版を書く")
    func header() {
        #expect(Self.report.hasPrefix("# CharaTime 1 週間の運用の記録（3-7）\n"))
        #expect(Self.report.contains("- 書き出した時刻: 9/27（日） 11:00\n"))
        #expect(Self.report.contains("- 始めた日: 9/26（土） 9:00\n"))
        #expect(Self.report.contains("- いま: 2 日目\n"))
        #expect(Self.report.contains("- iOS: 26.1\n"))
    }

    /// 表の中の「|」と改行は、表が崩れないように置き換える。
    @Test("毎日の表: 7 日ぶん並べ、つけていない所は「—」、切の日のまばたきは「（切の日）」")
    func dailyTable() {
        #expect(Self.report.contains("| 日 | 日付 | キャラが見えていた | まばたき・寝息が動いていた | アプリと同じ姿だった | メモ |"))
        #expect(Self.report.contains("| 1 | 9/26（土） | はい | はい | はい |  |"))
        #expect(Self.report.contains("| 2 | 9/27（日） | はい | （切の日） | いいえ | 一瞬ずれた ｜ 次は 合った |"))
        #expect(Self.report.contains("| 7 | 10/2（金） | — | — | — |  |"))
    }

    @Test("電池の表: 1 日目は入、2 日目は切の 24 時間。読んだ時刻を添える")
    func batteryTable() {
        #expect(Self.report.contains("| 1 | 入 | 2% | 5% | 9/26 22:00 |"))
        #expect(Self.report.contains("| 2 | 切 | — | — | — |"))
    }

    @Test("確かめたことの表: 結果は「期待どおり・ちがった・まだ」")
    func checksTable() {
        #expect(Self.report.contains("| 1 | ロックを解除したあと | 期待どおり | 9/26 9:30 |  |"))
        #expect(Self.report.contains("| 6 | 低電力モード | ちがった | — | まばたきが続いた |"))
        #expect(Self.report.contains("| 1 | 入れ直した直後 | まだ | — |  |"))
    }

    @Test("ウィジェットの記録の表: 日ごとの回数・いちばん長い間隔・メモリの最大・疑似アニメ")
    func automaticTable() {
        #expect(Self.report.contains("| 9/26（土） | 1 回・最長 20.0 時間 | 0 回 | 1 回 | 13.4 MB | 入 |"))
        #expect(Self.report.contains("| 9/27（日） | 1 回・最長 25.0 時間 | 0 回 | 0 回 | 11.4 MB | 切 |"))
        #expect(Self.report.contains("最後の作り直し: 大 9/27 10:00（1.0 時間前）・小 9/26 10:00（25.0 時間前）"))
    }

    @Test("作り直しの一覧を、始める前のぶんも含めて古い順にすべて書く")
    func reloadList() {
        #expect(Self.report.contains("- 9/25 13:00 大 73 件・動く 11.4 MB\n- 9/26 9:00 大 73 件・動く 12.4 MB 349.67×365.00pt\n"))
        #expect(Self.report.contains("- 9/27 10:00 大 73 件・止め 11.4 MB\n"))
    }

    @Test("まだ始めていなければ、そう書く")
    func notStarted() {
        let report = WeekRunReport.markdown(record: WeekRunRecord(), diagnostics: Self.diagnostics, now: Self.start,
                                            calendar: Self.tokyo, system: SystemVersion(major: 26, minor: 1))
        #expect(report == "# CharaTime 1 週間の運用の記録（3-7）\n\nまだ始めていません。\n")
    }
}
