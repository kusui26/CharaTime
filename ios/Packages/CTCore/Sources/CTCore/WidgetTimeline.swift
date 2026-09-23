import Foundation

/// ウィジェットのタイムラインの、エントリの時刻（プラン §9 Phase 3 の 3-C ③）。
///
/// **最初の件は「いま」、あとは日課表と同じ 5 分の升目。** 日課表の区切りの境目も
/// この升目にそろっている（`Schedule.gridMinutes`）ので、エントリが切り替わった瞬間に
/// 行動が途中から始まることがない。升目はその日の 0 時から数えるので、夏時間の日も
/// 日課表と同じ升目になる。
///
/// 6 時間ぶん（いま＋ 72 件）を 1 本にして、使い切ったら作り直す（`.atEnd`）。
/// 作り直しは 1 日に約 4 回で、更新の予算（1 日 40〜70 回）をほとんど使わない。
public enum WidgetTimeline {

    /// 1 本のタイムラインで先読みする長さ。
    public static let horizonMinutes: Double = 360

    /// 最後のエントリから 0 時までがこれより短ければ、0 時ちょうどのエントリまで延ばす。
    ///
    /// 疑似アニメのタイマーは、エントリの日付の 0 時から数える（D-18）。最後のエントリが
    /// 23 時台のまま、作り直しが 0 時より遅れると、時計の表示が「24:05」のようになる。
    /// 0 時のエントリを入れておけば、そのエントリは翌日の 0 時から数えるので、
    /// 作り直しが遅れても日付の境目で古い表示が残らない。
    public static let midnightMarginMinutes: Double = 60

    /// エントリの時刻。いま、そのあと 5 分の升目ごと。
    public static func entryDates(from now: Date, calendar: Calendar) -> [Date] {
        let horizonEnd = now.addingTimeInterval(horizonMinutes * secondsPerMinute)
        let entries = [now] + gridPoints(after: now, through: horizonEnd, calendar: calendar)
        return extendedToMidnight(entries, calendar: calendar)
    }

    // MARK: - 升目

    private static let secondsPerMinute: Double = 60
    private static var gridSeconds: Double { Schedule.gridMinutes * secondsPerMinute }

    /// `start` より後から `end` まで（`end` を含む）の升目。
    static func gridPoints(after start: Date, through end: Date, calendar: Calendar) -> [Date] {
        let first = firstGridPoint(after: start, calendar: calendar)
        guard first <= end else { return [] }
        return stride(from: first.timeIntervalSinceReferenceDate,
                      through: end.timeIntervalSinceReferenceDate, by: gridSeconds)
            .map(Date.init(timeIntervalSinceReferenceDate:))
    }

    /// `time` より後の、最初の升目。ちょうど升目の上なら、その次。
    ///
    /// 升目はその日の 0 時から 5 分ごと。0 時は絶対時刻でも 5 分の倍数の上にある
    /// （時差も夏時間のずれも 5 分の倍数）ので、日をまたいでも升目はつながる。
    static func firstGridPoint(after time: Date, calendar: Calendar) -> Date {
        let midnight = calendar.startOfDay(for: time)
        let steps = (time.timeIntervalSince(midnight) / gridSeconds).rounded(.down) + 1
        return midnight.addingTimeInterval(steps * gridSeconds)
    }

    /// 最後のエントリが 0 時の直前なら、0 時ちょうどまで升目を足す。
    private static func extendedToMidnight(_ entries: [Date], calendar: Calendar) -> [Date] {
        guard let last = entries.last,
              let nextMidnight = calendar.date(byAdding: .day, value: 1,
                                               to: calendar.startOfDay(for: last)),
              nextMidnight.timeIntervalSince(last) < midnightMarginMinutes * secondsPerMinute
        else { return entries }
        return entries + gridPoints(after: last, through: nextMidnight, calendar: calendar)
    }
}
