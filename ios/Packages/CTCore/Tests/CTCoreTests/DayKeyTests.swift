import Testing
import Foundation
@testable import CTCore

@Suite("日付")
struct DayKeyTests {

    @Test("通し日数が暦と合う")
    func ordinalMatchesCalendar() {
        #expect(DayKey(year: 1970, month: 1, day: 1).ordinal == 0)
        #expect(DayKey(year: 1970, month: 1, day: 2).ordinal == 1)
        #expect(DayKey(year: 1999, month: 12, day: 31).ordinal == 10_956)
        #expect(DayKey(year: 2000, month: 1, day: 1).ordinal == 10_957)
        #expect(DayKey(year: 2024, month: 2, day: 29).ordinal == 19_782)   // うるう日
        #expect(DayKey(year: 2026, month: 3, day: 1).ordinal == 20_513)
        #expect(DayKey(year: 2026, month: 9, day: 11).ordinal == 20_707)
    }

    @Test("通し日数から暦へ戻せる")
    func ordinalRoundTrip() {
        for offset in stride(from: -20_000, through: 30_000, by: 37) {
            let restored = DayKey(fromOrdinal: offset)
            #expect(restored.ordinal == offset, "\(offset) → \(restored) → \(restored.ordinal)")
        }
    }

    @Test("前後の日へ動かせる")
    func advancing() {
        let day = DayKey(year: 2026, month: 3, day: 1)
        #expect(day.advanced(by: -1) == DayKey(year: 2026, month: 2, day: 28))
        #expect(day.advanced(by: 1) == DayKey(year: 2026, month: 3, day: 2))
        // うるう年をまたぐ
        let leap = DayKey(year: 2024, month: 3, day: 1)
        #expect(leap.advanced(by: -1) == DayKey(year: 2024, month: 2, day: 29))
    }

    @Test("Date からタイムゾーンに沿って切り出せる")
    func fromDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let formatter = ISO8601DateFormatter()

        // 日本時間の 2026-09-11 00:30 は、UTC ではまだ 9-10。日付は日本時間で決まる。
        let justAfterMidnight = try #require(formatter.date(from: "2026-09-10T15:30:00Z"))
        #expect(DayKey(justAfterMidnight, calendar: calendar) == DayKey(year: 2026, month: 9, day: 11))

        let justBeforeMidnight = try #require(formatter.date(from: "2026-09-10T14:30:00Z"))
        #expect(DayKey(justBeforeMidnight, calendar: calendar) == DayKey(year: 2026, month: 9, day: 10))
    }

    @Test("0:00 からの分が出せる")
    func minuteOfDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let formatter = ISO8601DateFormatter()

        let midnight = try #require(formatter.date(from: "2026-09-10T15:00:00Z"))   // JST 9/11 00:00
        #expect(abs(calendar.minuteOfDay(midnight) - 0) < 0.001)

        let evening = try #require(formatter.date(from: "2026-09-11T11:42:00Z"))    // JST 20:42
        #expect(abs(calendar.minuteOfDay(evening) - (20 * 60 + 42)) < 0.001)
    }

    @Test("並べ替えができる")
    func ordering() {
        #expect(DayKey(year: 2026, month: 1, day: 31) < DayKey(year: 2026, month: 2, day: 1))
        #expect(DayKey(year: 2025, month: 12, day: 31) < DayKey(year: 2026, month: 1, day: 1))
    }
}
