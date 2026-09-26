import Testing
import Foundation
import CTStore
@testable import CTRender

/// 1 週間の運用（プラン §9 Phase 3 の 3-7）の予定と、確かめること。
@Suite("1 週間の運用の予定")
struct WeekRunPlanTests {

    static let tokyo: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    /// 2026-09-26（土）9:00（日本時間）。
    static let start = Date(timeIntervalSince1970: 1_790_380_800)
    static let hour: TimeInterval = 3600

    static func day(at now: Date) -> Int {
        WeekRunPlan.dayNumber(startedAt: start, now: now, calendar: tokyo)
    }

    /// 暦の日で数える。夜に始めても、0 時を越えれば 2 日目。
    @Test("始めた日が 1 日目。0 時を越えるごとに 1 日進む。始める前の時刻でも 1 日目")
    func dayNumber() {
        let nextMidnight = Self.tokyo.startOfDay(for: Self.start).addingTimeInterval(24 * Self.hour)
        #expect(Self.day(at: Self.start) == 1)
        #expect(Self.day(at: nextMidnight.addingTimeInterval(-1)) == 1)
        #expect(Self.day(at: nextMidnight) == 2)
        #expect(Self.day(at: Self.start.addingTimeInterval(6 * 24 * Self.hour)) == 7)
        #expect(Self.day(at: Self.start.addingTimeInterval(7 * 24 * Self.hour)) == 8)
        #expect(Self.day(at: Self.start.addingTimeInterval(-48 * Self.hour)) == 1)
    }

    @Test("何日目の日付。1 日目は始めた日")
    func dateOfDay() {
        let first = WeekRunPlan.date(ofDay: 1, startedAt: Self.start, calendar: Self.tokyo)
        let third = WeekRunPlan.date(ofDay: 3, startedAt: Self.start, calendar: Self.tokyo)
        #expect(WeekRunPlan.dayLabel(first, calendar: Self.tokyo) == "9/26（土）")
        #expect(WeekRunPlan.dayLabel(third, calendar: Self.tokyo) == "9/28（月）")
    }

    @Test("確かめることは 1〜7 日目に日の順で割り振り、毎日 1 つ以上ある。名前は重ならない")
    func checksAreSpreadOverTheWeek() {
        let ids = WeekRunPlan.checks.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(WeekRunPlan.checks.allSatisfy { (1...WeekRunPlan.length).contains($0.day) })
        #expect(WeekRunPlan.checks.map(\.day) == WeekRunPlan.checks.map(\.day).sorted())
        #expect((1...WeekRunPlan.length).allSatisfy { !WeekRunPlan.checks(on: $0).isEmpty })
        #expect(WeekRunPlan.checks(on: 7).map(\.id) == ["crashLog"])
    }

    /// Q-15: 入の 24 時間と切の 24 時間を 1 回ずつ読む。切の日は、まばたきが止まっているのが正しい。
    @Test("電池を読むのは 1・2 日目。2 日目は切の日")
    func batteryAndTheOffDay() {
        #expect(WeekRunPlan.readsBattery(on: 1) && WeekRunPlan.readsBattery(on: 2))
        #expect(!WeekRunPlan.readsBattery(on: 3))
        #expect(WeekRunPlan.expectsAnimation(on: 1) && WeekRunPlan.expectsAnimation(on: 3))
        #expect(!WeekRunPlan.expectsAnimation(on: 2))
    }

    @Test("毎日の問いは 3 つ。切の日には、まばたきを聞かない")
    func questions() {
        #expect(WeekRunQuestion.asked(on: 1) == [.characterVisible, .animating, .matchesApp])
        #expect(WeekRunQuestion.asked(on: 2) == [.characterVisible, .matchesApp])
        // 問いは、記録表のどの欄に書くかを知っている
        var day = WeekRunDay(number: 1)
        day[keyPath: WeekRunQuestion.matchesApp.answer] = .no
        #expect(day.matchesApp == .no)
        #expect(day[keyPath: WeekRunQuestion.animating.answer] == nil)
    }

    @Test("その日の手引き: 1 日目の夜に切にし、2 日目の夜に入に戻す。7 日目は書き出して送る")
    func notes() {
        #expect(WeekRunPlan.notes(on: 1).contains { $0.contains("切にする") })
        #expect(WeekRunPlan.notes(on: 2).contains { $0.contains("入に戻す") })
        #expect(WeekRunPlan.notes(on: 7).contains { $0.contains("書き出す") })
        #expect(WeekRunPlan.notes(on: 4).isEmpty)
    }

    @Test("設定の行に出す様子: まだ・N 日目・終わった")
    func status() {
        #expect(WeekRunPlan.status(startedAt: nil, now: Self.start, calendar: Self.tokyo) == "まだ始めていません")
        let twoDaysLater = Self.start.addingTimeInterval(24 * Self.hour)
        #expect(WeekRunPlan.status(startedAt: Self.start, now: twoDaysLater, calendar: Self.tokyo) == "2 日目")
        let eighth = Self.start.addingTimeInterval(7 * 24 * Self.hour)
        #expect(WeekRunPlan.status(startedAt: Self.start, now: eighth, calendar: Self.tokyo) == "終わりました（8 日目）")
    }
}
