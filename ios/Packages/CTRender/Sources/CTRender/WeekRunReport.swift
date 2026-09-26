import Foundation
import CTStore

/// 1 週間の運用の記録を、1 つの文章（Markdown）に書き出す（プラン §9 Phase 3 の 3-7）。
///
/// 利用者は共有シートでコピーして送るだけで、Claude は毎日の記録・確かめたこと・自動の記録（作り直した
/// 時刻とメモリ）を一度に読める。作り直しの一覧は、始める前のぶんも含めて全部書く（比べる基準になる）。
public enum WeekRunReport {

    static let title = "# CharaTime 1 週間の運用の記録（3-7）"

    public static func markdown(record: WeekRunRecord, diagnostics: WidgetDiagnostics, now: Date,
                                calendar: Calendar, system: SystemVersion) -> String {
        guard let start = record.startedAt else { return title + "\n\nまだ始めていません。\n" }
        let sheet = WeekRunSheet(record: record, start: start, now: now, calendar: calendar)
        let sections = [sheet.header(system: system), sheet.dailyTable, sheet.batteryTable, sheet.checksTable,
                        sheet.automaticTable(diagnostics), sheet.reloadList(diagnostics)]
        return sections.joined(separator: "\n\n") + "\n"
    }
}

/// 書き出しの材料と、節ごとの書き方。
struct WeekRunSheet {

    let record: WeekRunRecord
    let start: Date
    let now: Date
    let calendar: Calendar

    /// 表に並べる日。7 日目まで（過ぎていれば、いまの日まで）。
    private var dayNumbers: ClosedRange<Int> {
        1...max(WeekRunPlan.length, WeekRunPlan.dayNumber(startedAt: start, now: now, calendar: calendar))
    }

    func header(system: SystemVersion) -> String {
        [WeekRunReport.title, "",
         "- 書き出した時刻: \(dayAndTime(now))",
         "- 始めた日: \(dayAndTime(start))",
         "- いま: \(WeekRunPlan.status(startedAt: start, now: now, calendar: calendar))",
         "- iOS: \(system.major).\(system.minor)"].joined(separator: "\n")
    }

    var dailyTable: String {
        let head = ["日", "日付"] + WeekRunQuestion.allCases.map(\.title) + ["メモ"]
        let rows = dayNumbers.map { number in
            let day = record.day(number)
            return [String(number), dayLabel(number)] + WeekRunQuestion.allCases.map { answerCell(day, $0) }
                + [cell(day.note)]
        }
        return table("毎日の記録", head: head, rows: rows)
    }

    var batteryTable: String {
        let head = ["日", "まばたき・寝息", "CharaTime", "ホーム画面とロック画面", "読んだ時刻"]
        let rows = WeekRunPlan.batteryDays.map { number in
            let battery = record.day(number).battery
            return [String(number), WeekRunPlan.expectsAnimation(on: number) ? "入" : "切",
                    WeekRunFormat.percent(battery?.charaTimePercent),
                    WeekRunFormat.percent(battery?.homeAndLockPercent), battery?.readAt.map(dateTime) ?? "—"]
        }
        return table("電池（設定 → バッテリー →「過去 24 時間」）", head: head, rows: rows)
    }

    var checksTable: String {
        let rows = WeekRunPlan.checks.map { item in
            let check = record.check(item.id)
            return [String(item.day), item.title, WeekRunFormat.result(check.answer),
                    check.answeredAt.map(dateTime) ?? "—", cell(check.note)]
        }
        return table("一度だけ確かめること", head: ["日", "場面", "結果", "答えた時刻", "メモ"], rows: rows)
    }

    func automaticTable(_ diagnostics: WidgetDiagnostics) -> String {
        let days = diagnostics.daySummaries(from: start, through: now, calendar: calendar)
        let rows = days.map { automaticRow($0) }
        let head = ["日付"] + Self.families.map(\.displayName) + ["メモリの最大", "疑似アニメ"]
        let partialNote = days.contains(where: \.isPartial) ? ["（一部）: 記録の上限で、その日の前のほうが消えている"] : []
        return ([table("ウィジェットの記録（自動）", head: head, rows: rows)] + partialNote + [lastReloads(diagnostics)])
            .joined(separator: "\n\n")
    }

    /// 自動の記録の表に並べる大きさ。置いていない大きさも 0 回として並べる（表の形を毎日そろえる）。
    private static let families: [WidgetSlot.Family] = [.large, .medium, .small]

    func reloadList(_ diagnostics: WidgetDiagnostics) -> String {
        let lines = diagnostics.reloads.sorted { $0.date < $1.date }.map { reloadLine($0) }
        return (["## 作り直しの一覧（古い順）", ""] + lines).joined(separator: "\n")
    }
}

// MARK: - 1 マスの書き方

private extension WeekRunSheet {

    func table(_ title: String, head: [String], rows: [[String]]) -> String {
        let lines = [row(head), row(head.map { _ in "---" })] + rows.map { row($0) }
        return (["## \(title)", ""] + lines).joined(separator: "\n")
    }

    func row(_ cells: [String]) -> String {
        "| " + cells.joined(separator: " | ") + " |"
    }

    /// 表の 1 マス。表が崩れないように「|」と改行を置き換える。
    func cell(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "｜").replacingOccurrences(of: "\n", with: " ")
    }

    /// 聞かない日（切の日のまばたき）は「（切の日）」。
    func answerCell(_ day: WeekRunDay, _ question: WeekRunQuestion) -> String {
        guard WeekRunQuestion.asked(on: day.number).contains(question) else { return "（切の日）" }
        return WeekRunFormat.answer(day[keyPath: question.answer])
    }

    func automaticRow(_ day: WidgetDiagnostics.DaySummary) -> [String] {
        let date = WeekRunPlan.dayLabel(day.day, calendar: calendar) + (day.isPartial ? "（一部）" : "")
        return [date] + Self.families.map { reloadsCell(day, $0) }
            + [day.peakBytes.map(WidgetRecordFormat.megabytes) ?? "—",
               WeekRunFormat.pseudoAnimation(day.pseudoAnimation)]
    }

    /// 「5 回・最長 6.1 時間」。間隔が無い（その日が初めて）なら回数だけ。
    func reloadsCell(_ day: WidgetDiagnostics.DaySummary, _ family: WidgetSlot.Family) -> String {
        let count = "\(day.reloadCounts[family] ?? 0) 回"
        return day.longestGapSeconds[family].map { count + "・最長 " + WeekRunFormat.hours($0) } ?? count
    }

    func lastReloads(_ diagnostics: WidgetDiagnostics) -> String {
        let parts = diagnostics.summaries(now: now).map { summary in
            let date = summary.lastReload.date
            let ago = WeekRunFormat.hours(now.timeIntervalSince(date))
            return "\(summary.family.displayName) \(dateTime(date))（\(ago)前）"
        }
        return "最後の作り直し: " + (parts.isEmpty ? "まだ記録がありません" : parts.joined(separator: "・"))
    }

    /// 「- 9/26 9:00 大 73 件・動く 12.4 MB 349.67×365.00pt」。大きさは、知らせていれば添える。
    func reloadLine(_ reload: WidgetReload) -> String {
        let size = reload.displaySize.map { size in
            String(format: " %.2f×%.2fpt", Double(size.width), Double(size.height))
        }
        let what = "\(reload.family.displayName) \(WidgetRecordFormat.timeline(reload))"
        let memory = WidgetRecordFormat.megabytes(reload.peakBytes)
        return "- \(dateTime(reload.date)) \(what) \(memory)" + (size ?? "")
    }

    func dayLabel(_ number: Int) -> String {
        WeekRunPlan.dayLabel(WeekRunPlan.date(ofDay: number, startedAt: start, calendar: calendar),
                             calendar: calendar)
    }

    /// 「9/26 22:00」。
    func dateTime(_ date: Date) -> String {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 0)/\(parts.day ?? 0) " + ClockFormat.time(date, calendar: calendar)
    }

    /// 「9/26（土） 22:00」。
    func dayAndTime(_ date: Date) -> String {
        WeekRunPlan.dayLabel(date, calendar: calendar) + " " + ClockFormat.time(date, calendar: calendar)
    }
}
