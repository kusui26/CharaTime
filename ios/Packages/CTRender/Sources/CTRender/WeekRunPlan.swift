import Foundation
import CTStore

/// 1 週間の運用（プラン §9 Phase 3 の 3-7）の予定と、確かめること。記録表の中身を決める。
///
/// 毎日つけるのは 3 つ（`WeekRunQuestion`）。電池は Q-15 のために、1 日目の夜に入の 24 時間を、2 日目の
/// 夜に切の 24 時間を読む。一度だけ確かめること（3-E の表と、Gate 3 の「決めたとおりに落ちる」）は、
/// 1 日 2 つほどに分けて割り振る。**3-7 のあいだはビルドを替えない**ので、ここを直すのは運用の前だけ。
public enum WeekRunPlan {

    /// 運用の日数。
    public static let length = 7
    /// まばたき・寝息を切にする日（Q-15 の切の 24 時間）。1 日目の夜に切にし、2 日目の夜に入に戻す。
    public static let pseudoAnimationOffDay = 2
    /// 電池を読む日（夜）。1 日目は入の 24 時間、2 日目は切の 24 時間。
    static let batteryDays = 1...2

    /// きょうは何日目か。始めた日を 1 日目として、暦の日で数える（始める前の時刻でも 1）。
    public static func dayNumber(startedAt: Date, now: Date, calendar: Calendar) -> Int {
        let elapsed = calendar.dateComponents([.day], from: calendar.startOfDay(for: startedAt),
                                              to: calendar.startOfDay(for: now)).day ?? 0
        return max(elapsed, 0) + 1
    }

    /// 何日目の日付（その日の 0 時）。
    public static func date(ofDay day: Int, startedAt: Date, calendar: Calendar) -> Date {
        let first = calendar.startOfDay(for: startedAt)
        return calendar.date(byAdding: .day, value: day - 1, to: first) ?? first
    }

    /// 「9/26（土）」。
    public static func dayLabel(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.month, .day, .weekday], from: date)
        let names = ClockFormat.weekdayNames
        let weekday = names[((parts.weekday ?? 1) - 1) % names.count]
        return "\(parts.month ?? 0)/\(parts.day ?? 0)（\(weekday)）"
    }

    /// その日に、まばたき・寝息が動いているはずか（切の日は止まっているのが正しい）。
    public static func expectsAnimation(on day: Int) -> Bool {
        day != pseudoAnimationOffDay
    }

    /// その日の夜に、電池を読むか。
    public static func readsBattery(on day: Int) -> Bool {
        batteryDays.contains(day)
    }

    /// その日に確かめること。
    public static func checks(on day: Int) -> [WeekRunCheckItem] {
        checks.filter { $0.day == day }
    }

    /// 設定の行に出す様子。
    public static func status(startedAt: Date?, now: Date, calendar: Calendar) -> String {
        guard let startedAt else { return "まだ始めていません" }
        let day = dayNumber(startedAt: startedAt, now: now, calendar: calendar)
        return day <= length ? "\(day) 日目" : "終わりました（\(day) 日目）"
    }

    /// その日の手引き（確かめること以外にやること）。
    public static func notes(on day: Int) -> [String] {
        switch day {
        case 1:
            ["夜: 設定 → バッテリー →「過去 24 時間」で、CharaTime と「ホーム画面とロック画面」の % を読んで書き、"
                + "まばたき・寝息を切にする（あすの 24 時間を、切で測るため）"]
        case pseudoAnimationOffDay:
            ["きょうは切の日です。まばたき・寝息は止まり、5 分ごとの切り替えだけになります",
             "夜（きのう電池を読んだのと同じころ）: もう一度電池を読んで書き、まばたき・寝息を入に戻す"]
        case length:
            ["最後の日です。確かめることを見終えたら、「記録を書き出す」で送ってください"]
        default:
            []
        }
    }
}

/// 毎日の問い。
public enum WeekRunQuestion: String, CaseIterable, Sendable {
    case characterVisible
    case animating
    case matchesApp

    public var title: String {
        switch self {
        case .characterVisible: "キャラが見えていた"
        case .animating: "まばたき・寝息が動いていた"
        case .matchesApp: "アプリと同じ姿だった"
        }
    }

    /// まとめの 1 行に使う短い言い方。
    public var shortTitle: String {
        switch self {
        case .characterVisible: "見えていた"
        case .animating: "動いていた"
        case .matchesApp: "同じ姿"
        }
    }

    public var detail: String {
        switch self {
        case .characterVisible: "ホーム画面の大に、キャラがいつもいた（消えていなかった）"
        case .animating: "目をやったとき、まばたきか寝息が動いていた"
        case .matchesApp: "0 分・5 分…で姿が変わった直後にアプリを開き、同じ行動・同じ場所だった"
        }
    }

    /// 記録表のどの欄に書くか。
    public var answer: WritableKeyPath<WeekRunDay, WeekRunAnswer?> {
        switch self {
        case .characterVisible: \.characterVisible
        case .animating: \.animating
        case .matchesApp: \.matchesApp
        }
    }

    /// その日に聞く問い。切の日は、まばたきを聞かない（止まっているのが正しい）。
    public static func asked(on day: Int) -> [WeekRunQuestion] {
        allCases.filter { $0 != .animating || WeekRunPlan.expectsAnimation(on: day) }
    }
}

/// 一度だけ確かめることの 1 つ。
public struct WeekRunCheckItem: Sendable, Equatable, Identifiable {
    /// 記録表に残す名前。**変えない**（変えると、つけた結果が読めなくなる）。
    public let id: String
    /// 何日目に見るか。
    public let day: Int
    public let title: String
    /// やり方。
    public let how: String
    /// 見るもの。そのとおりなら「期待どおり」。
    public let expected: String
}
