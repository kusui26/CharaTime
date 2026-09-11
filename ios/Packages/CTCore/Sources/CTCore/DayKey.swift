import Foundation

/// ローカルタイムゾーンでの「その日」。日課表の種になる。
///
/// `Date` をそのまま種にすると秒ごとに違う日課ができてしまう。日付の境目は
/// ユーザーのタイムゾーンで決まるので、`Calendar` を通して切り出す。
public struct DayKey: Hashable, Sendable, Codable, Comparable {

    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// 1970-01-01 からの通し日数。種に混ぜるために使う。
    ///
    /// `Calendar` を介さず整数演算だけで出すので、タイムゾーンや暦の設定に左右されない。
    /// アルゴリズムは Howard Hinnant の `days_from_civil`。
    public var ordinal: Int {
        var y = year
        if month <= 2 { y -= 1 }
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400                                        // [0, 399]
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    /// 種に混ぜるための符号なし表現。
    public var seedComponent: UInt64 { UInt64(bitPattern: Int64(ordinal)) }

    public func advanced(by days: Int) -> DayKey {
        DayKey(fromOrdinal: ordinal + days)
    }

    /// 通し日数から暦へ戻す（`civil_from_days`）。
    public init(fromOrdinal ordinal: Int) {
        let z = ordinal + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097                                     // [0, 146096]
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let shiftedYear = yearOfEra + era * 400
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shiftedMonth = (5 * dayOfYear + 2) / 153                         // [0, 11]
        let dayOfMonth = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1        // [1, 31]
        let month = shiftedMonth + (shiftedMonth < 10 ? 3 : -9)              // [1, 12]
        self.init(year: shiftedYear + (month <= 2 ? 1 : 0), month: month, day: dayOfMonth)
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool { lhs.ordinal < rhs.ordinal }
}

public extension Calendar {

    /// その日の 0:00。
    func startOfLocalDay(_ day: DayKey) -> Date? {
        var parts = DateComponents()
        parts.year = day.year
        parts.month = day.month
        parts.day = day.day
        return date(from: parts)
    }

    /// 0:00 から数えた分。秒未満も小数で含む。
    ///
    /// 夏時間のある地域では 1 日が 23 時間や 25 時間になるため、値が 1440 を超えることがある。
    /// 呼び出し側で日課表の範囲に丸める（日本標準時では起きない）。
    func minuteOfDay(_ date: Date) -> Double {
        let midnight = startOfDay(for: date)
        return date.timeIntervalSince(midnight) / 60.0
    }
}
