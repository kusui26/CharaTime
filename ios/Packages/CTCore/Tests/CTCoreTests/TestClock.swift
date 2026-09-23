import Foundation

/// テストで時刻を作る。日付の境目はその地域の暦で決まるので、暦と一緒に作る。
///
/// 夏時間を確かめるときはニューヨーク（2026-03-08 に 2:00 → 3:00、2026-11-01 に 2:00 → 1:00）を使う。
/// 日本には夏時間が無いが、暦を引数で受ける以上、どの地域でも升目が崩れないことを見ておく。
enum TestClock {

    static let tokyo = calendar("Asia/Tokyo")
    static let newYork = calendar("America/New_York")

    static func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier) ?? .gmt
        return calendar
    }

    /// その暦での日時。秒は小数も受ける（0.25 秒刻みの窓を確かめるため）。
    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int,
                     _ second: Double = 0, in calendar: Calendar = tokyo) -> Date {
        var parts = DateComponents()
        parts.year = year; parts.month = month; parts.day = day
        parts.hour = hour; parts.minute = minute
        let whole = Int(second.rounded(.down))
        parts.second = whole
        parts.nanosecond = Int(((second - Double(whole)) * 1_000_000_000).rounded())
        return calendar.date(from: parts)!
    }

    /// 2026-09-24（木）の日本時間。多くのテストはこの日で足りる。
    static func today(_ hour: Int, _ minute: Int, _ second: Double = 0) -> Date {
        date(2026, 9, 24, hour, minute, second)
    }

    /// `window` が開いているあいだを、`start` から `seconds` 秒ぶん、`step` 秒刻みで調べて
    /// [開いた時刻（start からの秒）, 開いていた長さ] の組にする。
    static func openSpans(of isOpen: (Date) -> Bool, from start: Date, seconds: Double,
                          step: Double = 0.01) -> [(start: Double, length: Double)] {
        let samples = Int((seconds / step).rounded())
        var spans: [(start: Double, length: Double)] = []
        var openedAt: Double?
        for index in 0...samples {
            let offset = Double(index) * step
            let open = isOpen(start.addingTimeInterval(offset))
            if open, openedAt == nil { openedAt = offset }
            if !open, let began = openedAt {
                spans.append((start: began, length: offset - began))
                openedAt = nil
            }
        }
        return spans
    }
}
