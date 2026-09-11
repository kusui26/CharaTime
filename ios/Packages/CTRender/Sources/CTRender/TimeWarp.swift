import Foundation

/// 見せかけの時刻。**確認のためだけに時刻をずらす仕組み**（プラン §9 Phase 1 の 1-5）。
///
/// 待受モードは「いまの時刻の姿」しか出せないので、そのままでは夜中に起動したら
/// 寝ている姿しか見られない。ここで時刻を差し替えると、昼の散歩も夜の踊りも
/// その場で確かめられる。1 日を 1 分に早送りすれば、放置テストの下見もできる。
///
/// **決定論は壊れない。** 日課エンジンに渡す時刻を変えているだけで、
/// 「その時刻の姿」は本物と同じ計算で出る。
public struct TimeWarp: Sendable, Equatable {

    /// 見せかけの時刻の起点。nil なら実時刻をそのまま使う。
    public var displayOrigin: Date?
    /// `displayOrigin` に対応する実時刻。
    public var realOrigin: Date
    /// 早送りの倍率。0 で時刻が止まる。
    public var scale: Double

    public init(displayOrigin: Date?, realOrigin: Date, scale: Double) {
        self.displayOrigin = displayOrigin
        self.realOrigin = realOrigin
        self.scale = scale
    }

    /// 実時刻をそのまま使う（ふだんはこれ）。
    public static let real = TimeWarp(displayOrigin: nil, realOrigin: .distantPast, scale: 1)

    public var isActive: Bool { displayOrigin != nil }

    public func apply(to now: Date) -> Date {
        guard let displayOrigin else { return now }
        return displayOrigin.addingTimeInterval(now.timeIntervalSince(realOrigin) * scale)
    }

    /// 実行引数から読む。指定が無ければ実時刻。
    ///
    ///     -CTTime 14:30        きょうの 14:30 から
    ///     -CTTime 2026-09-12T14:30   その日時から
    ///     -CTSpeed 0           止める（既定）
    ///     -CTSpeed 240         240 倍速（1 日が 6 分）
    public static func fromArguments(_ arguments: [String], now: Date = Date(),
                                     calendar: Calendar = .current) -> TimeWarp {
        guard let text = value(of: "-CTTime", in: arguments),
              let origin = parse(text, now: now, calendar: calendar) else { return .real }
        let scale = value(of: "-CTSpeed", in: arguments).flatMap(Double.init) ?? 0
        return TimeWarp(displayOrigin: origin, realOrigin: now, scale: scale)
    }

    static func value(of flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.index(after: index) < arguments.endIndex else { return nil }
        return arguments[arguments.index(after: index)]
    }

    /// `14:30` か `2026-09-12T14:30` を読む。読めなければ nil。
    static func parse(_ text: String, now: Date, calendar: Calendar) -> Date? {
        let halves = text.split(separator: "T", maxSplits: 1)
        // 空文字だと halves が空になる。末尾を取れば添字で落ちない。
        guard let clock = halves.last else { return nil }
        let numbers = clock.split(separator: ":").compactMap { Int($0) }
        guard numbers.count >= 2 else { return nil }

        var parts = calendar.dateComponents([.year, .month, .day], from: now)
        if halves.count == 2 {
            let day = halves[0].split(separator: "-").compactMap { Int($0) }
            guard day.count == 3 else { return nil }
            parts.year = day[0]; parts.month = day[1]; parts.day = day[2]
        }
        parts.hour = numbers[0]
        parts.minute = numbers[1]
        parts.second = numbers.count > 2 ? numbers[2] : 0
        return calendar.date(from: parts)
    }
}
