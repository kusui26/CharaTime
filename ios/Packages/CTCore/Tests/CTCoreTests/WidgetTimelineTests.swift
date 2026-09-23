import Testing
import Foundation
@testable import CTCore

/// ウィジェットのエントリの時刻（プラン §9 Phase 3 の 3-C ③）。
@Suite("ウィジェットのタイムライン")
struct WidgetTimelineTests {

    private func entries(from now: Date, in calendar: Calendar = TestClock.tokyo) -> [Date] {
        WidgetTimeline.entryDates(from: now, calendar: calendar)
    }

    /// その暦で「0 時から何秒か」。升目の上なら 300 の倍数になる。
    private func secondsSinceMidnight(_ date: Date, _ calendar: Calendar = TestClock.tokyo) -> Double {
        date.timeIntervalSince(calendar.startOfDay(for: date))
    }

    // MARK: - 形

    @Test("最初の件は「いま」、あとは 5 分の升目に並ぶ")
    func firstIsNowThenGrid() {
        let now = TestClock.today(10, 2, 30)
        let dates = entries(from: now)
        #expect(dates.first == now)
        #expect(dates.dropFirst().first == TestClock.today(10, 5))
        for date in dates.dropFirst() {
            #expect(secondsSinceMidnight(date).truncatingRemainder(dividingBy: 300) == 0)
        }
        for (earlier, later) in zip(dates.dropFirst(), dates.dropFirst(2)) {
            #expect(later.timeIntervalSince(earlier) == 300)
        }
    }

    @Test("6 時間ぶん。いまと、升目 72 件")
    func sixHoursAhead() {
        let dates = entries(from: TestClock.today(10, 2, 30))
        #expect(dates.count == 73)
        #expect(dates.last == TestClock.today(16, 0))
    }

    @Test("いまが升目の上なら、次の升目から数える（同じ時刻を 2 度入れない）")
    func nowOnTheGrid() {
        let now = TestClock.today(10, 0)
        let dates = entries(from: now)
        #expect(dates.prefix(2) == [now, TestClock.today(10, 5)])
        #expect(dates.last == TestClock.today(16, 0))
        #expect(Set(dates).count == dates.count)
    }

    @Test("0 時ちょうどから始めても、升目がそろう")
    func startingAtMidnight() {
        let dates = entries(from: TestClock.today(0, 0))
        #expect(dates.first == TestClock.today(0, 0))
        #expect(dates.last == TestClock.today(6, 0))
    }

    // MARK: - 日付の境目

    @Test("日付をまたぐときは、翌日の 0 時を通って続く")
    func crossesMidnight() {
        let dates = entries(from: TestClock.today(22, 31))
        #expect(dates.contains(TestClock.date(2026, 9, 25, 0, 0)))
        #expect(dates.last == TestClock.date(2026, 9, 25, 4, 30))
        #expect(dates.count == 73)
    }

    @Test("24 時の直前からでも、翌日の 0 時の升目が次に来る")
    func justBeforeMidnight() {
        let now = TestClock.today(23, 59, 59.5)
        let dates = entries(from: now)
        #expect(dates.prefix(2) == [now, TestClock.date(2026, 9, 25, 0, 0)])
    }

    /// 最後のエントリが 23 時台で作り直しが遅れると、時計の表示が「24:05」になる（D-18）。
    @Test("終わりが 0 時の 1 時間前を切るなら、0 時ちょうどまで延ばす")
    func extendsToMidnight() {
        let dates = entries(from: TestClock.today(17, 10))
        #expect(dates.last == TestClock.date(2026, 9, 25, 0, 0))
        #expect(dates.count == 73 + 10)          // 23:15〜24:00 の 10 件
    }

    @Test("終わりが 0 時のちょうど 1 時間前なら、延ばさない")
    func marginBoundary() {
        #expect(entries(from: TestClock.today(17, 0)).last == TestClock.today(23, 0))
        #expect(entries(from: TestClock.today(17, 4, 59)).last == TestClock.today(23, 0))
        #expect(entries(from: TestClock.today(17, 5, 1)).last == TestClock.date(2026, 9, 25, 0, 0))
    }

    @Test("うるう日をまたいでも、升目が続く")
    func leapDay() {
        let dates = entries(from: TestClock.date(2028, 2, 28, 22, 0))
        #expect(dates.contains(TestClock.date(2028, 2, 29, 0, 0)))
        #expect(dates.last == TestClock.date(2028, 2, 29, 4, 0))
    }

    // MARK: - 夏時間

    @Test("夏時間が始まる日（2:00 → 3:00）も、絶対時刻で 5 分ごと、0 時から数えた升目に並ぶ")
    func springForward() {
        let newYork = TestClock.newYork
        let dates = entries(from: TestClock.date(2026, 3, 8, 0, 30, in: newYork), in: newYork)
        #expect(dates.count == 73)
        for (earlier, later) in zip(dates, dates.dropFirst()) {
            #expect(later.timeIntervalSince(earlier) == 300)
        }
        #expect(dates.allSatisfy { secondsSinceMidnight($0, newYork).truncatingRemainder(dividingBy: 300) == 0 })
        // 1:55 の次は 3:00（2 時台は存在しない）
        let beforeJump = TestClock.date(2026, 3, 8, 1, 55, in: newYork)
        let index = dates.firstIndex(of: beforeJump)
        #expect(index.map { dates[$0 + 1] } == TestClock.date(2026, 3, 8, 3, 0, in: newYork))
    }

    @Test("夏時間が終わる日（2:00 → 1:00）も、同じ時刻が 2 度来るだけで、升目は重ならない")
    func fallBack() {
        let newYork = TestClock.newYork
        let dates = entries(from: TestClock.date(2026, 11, 1, 0, 30, in: newYork), in: newYork)
        #expect(dates.count == 73)
        #expect(Set(dates).count == dates.count)
        for (earlier, later) in zip(dates, dates.dropFirst()) {
            #expect(later.timeIntervalSince(earlier) == 300)
        }
    }

    // MARK: - 日課表との一致

    /// 区切りの境目が升目にそろっているので、エントリの時刻から次のエントリまで、
    /// 区切り（行動の元）が変わらない。変わるなら、エントリの途中で行動が始まってしまう。
    @Test("エントリのあいだに、日課表の区切りが切り替わらない")
    func segmentsStartOnEntries() {
        let world = WorldInput(
            character: Character(id: "piyo", displayName: "ピヨ",
                                 personality: Personality(activity: 0.9, nightOwl: 0.4, napiness: 0.5),
                                 poses: [:]),
            room: Room(background: .bundled("room"), floor: .unit), userSeed: 0x5EED,
            calendar: TestClock.tokyo)
        let plan = DayPlan.make(for: DayKey(TestClock.today(0, 0), calendar: TestClock.tokyo), input: world)
        let dates = entries(from: TestClock.today(0, 0)) + entries(from: TestClock.today(6, 0))
            + entries(from: TestClock.today(12, 0)) + entries(from: TestClock.today(17, 55))
        for date in dates where DayKey(date, calendar: TestClock.tokyo) == plan.day {
            let minute = TestClock.tokyo.minuteOfDay(date)
            #expect(plan.segment(atMinute: minute) == plan.segment(atMinute: minute + 4.99),
                    "\(minute) 分からの 5 分のあいだに区切りが変わる")
        }
    }
}
