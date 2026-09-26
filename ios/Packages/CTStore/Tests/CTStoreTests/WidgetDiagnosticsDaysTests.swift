import Testing
import Foundation
@testable import CTStore

/// ウィジェットの記録の、日ごとのまとめ（プラン §9 Phase 3 の 3-7）。1 週間の運用の記録表が使う。
@Suite("ウィジェットの記録の日ごとのまとめ")
struct WidgetDiagnosticsDaysTests {

    static let tokyo: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    /// 2026-09-26 9:00（日本時間）。運用を始めた時刻。
    static let start = Date(timeIntervalSince1970: 1_790_380_800)
    static let hour: TimeInterval = 3600

    static func reload(_ hours: Double, _ family: WidgetSlot.Family = .large, peak: UInt64 = 12_000_000,
                       pseudoAnimation: Bool = true) -> WidgetReload {
        WidgetReload(date: start.addingTimeInterval(hours * hour), family: family, entryCount: 73,
                     footprintBytes: 1, peakBytes: peak, pseudoAnimation: pseudoAnimation)
    }

    static func diagnostics(_ reloads: [WidgetReload]) -> WidgetDiagnostics {
        WidgetDiagnostics(reloads: reloads)
    }

    @Test("始めた日から今日まで、日ごとに回数・いちばん長い間隔・メモリの最大・疑似アニメをまとめる")
    func summarizesEachDay() throws {
        let record = Self.diagnostics([
            Self.reload(-20),                                     // 9/25 13:00（始める前）
            Self.reload(0, peak: 13_000_000),                     // 9/26 9:00（前から 20 時間）
            Self.reload(1, .small, peak: 14_000_000),             // 9/26 10:00
            Self.reload(6),                                       // 9/26 15:00（前から 6 時間）
            Self.reload(25, pseudoAnimation: false),              // 9/27 10:00（前から 19 時間）
        ])
        let days = record.daySummaries(from: Self.start, through: Self.start.addingTimeInterval(51 * Self.hour),
                                       calendar: Self.tokyo)
        #expect(days.map(\.day) == [0, 1, 2].map { Self.tokyo.startOfDay(for: Self.start)
                                                    .addingTimeInterval(Double($0) * 24 * Self.hour) })
        let first = try #require(days.first)
        #expect(first.reloadCounts == [.large: 2, .small: 1])
        #expect(first.longestGapSeconds == [.large: 20 * Self.hour])
        #expect(first.peakBytes == 14_000_000)
        #expect(first.pseudoAnimation == [true])
        #expect(days[1].reloadCounts == [.large: 1])
        #expect(days[1].longestGapSeconds == [.large: 19 * Self.hour])
        #expect(days[1].pseudoAnimation == [false])
        // 記録の無い日も、0 回として並べる（止まっていたことが分かる）
        #expect(days[2].reloadCounts.isEmpty)
        #expect(days[2].peakBytes == nil)
        #expect(days[2].pseudoAnimation.isEmpty)
    }

    /// 0 時ちょうどは新しい日。23:59 までは前の日。
    @Test("日の境目は 0 時")
    func dayBoundary() {
        let midnight = Self.tokyo.startOfDay(for: Self.start).addingTimeInterval(24 * Self.hour)
        let record = Self.diagnostics([
            WidgetReload(date: midnight.addingTimeInterval(-1), family: .large, entryCount: 73,
                         footprintBytes: 1, peakBytes: 1, pseudoAnimation: true),
            WidgetReload(date: midnight, family: .large, entryCount: 73,
                         footprintBytes: 1, peakBytes: 1, pseudoAnimation: false),
        ])
        let days = record.daySummaries(from: Self.start, through: midnight, calendar: Self.tokyo)
        #expect(days.map(\.reloadCounts) == [[.large: 1], [.large: 1]])
        #expect(days.map(\.pseudoAnimation) == [[true], [false]])
    }

    @Test("入と切が混ざった日は、両方を持つ")
    func mixedPseudoAnimation() {
        let record = Self.diagnostics([Self.reload(1), Self.reload(7, pseudoAnimation: false)])
        let days = record.daySummaries(from: Self.start, through: Self.start, calendar: Self.tokyo)
        #expect(days.first?.pseudoAnimation == [true, false])
    }

    @Test("始める前の時刻までなら空。長すぎる範囲は、終わりから数えた上限の日数まで")
    func range() {
        let record = Self.diagnostics([Self.reload(0)])
        #expect(record.daySummaries(from: Self.start, through: Self.start.addingTimeInterval(-Self.hour),
                                    calendar: Self.tokyo).isEmpty)
        let years = record.daySummaries(from: Self.start.addingTimeInterval(-800 * 24 * Self.hour),
                                        through: Self.start, calendar: Self.tokyo)
        #expect(years.count == WidgetDiagnostics.maximumSummaryDays)
        #expect(years.last?.day == Self.tokyo.startOfDay(for: Self.start))
        #expect(years.last?.reloadCounts == [.large: 1])
    }

    /// 記録が上限まで詰まっていると、いちばん古い記録より前は捨てられている。その日を「作り直しなし」と
    /// 読むと、止まっていたと取り違える。
    @Test("記録が上限まで詰まっていれば、いちばん古い記録より前から始まる日は一部だけと印を付ける")
    func partialDays() throws {
        let full = Self.diagnostics((0..<WidgetDiagnostics.capacity).map { Self.reload(20 + Double($0) * 0.1) })
        let days = full.daySummaries(from: Self.start, through: Self.start.addingTimeInterval(48 * Self.hour),
                                     calendar: Self.tokyo)
        // 最初の記録は 9/27 5:00。9/26 は捨てられた分があるかもしれず、9/27 も 0 時から 5 時までが欠ける
        #expect(days.map(\.isPartial) == [true, true, false])
        #expect(days[0].reloadCounts.isEmpty)
        let notFull = Self.diagnostics([Self.reload(20)])
        let complete = notFull.daySummaries(from: Self.start, through: Self.start.addingTimeInterval(24 * Self.hour),
                                            calendar: Self.tokyo)
        #expect(complete.map(\.isPartial) == [false, false])
    }

    /// 大と小（スタンバイ）を合わせて 1 日に 40 回（いまの作りの見込みの 2 倍）作り直しても、1 週間を残せる。
    @Test("記録は 1 週間ぶん残る")
    func keepsAWeek() {
        #expect(WidgetDiagnostics.capacity >= 40 * 7)
    }
}
