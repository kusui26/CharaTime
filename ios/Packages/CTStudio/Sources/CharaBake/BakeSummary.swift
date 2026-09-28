import Foundation
import CTCore
import CTStudio

/// 道具の報告（画面に出す文）。知らせには、直しのプロンプト（テンプレート §5）を添える（2-4 でそのまま使えるように）。
enum BakeSummary {

    static func text(_ outcome: BakeOutcome, root: URL) -> String {
        let report = outcome.report
        let sources = report.sources.map(sourceLine)
        let sheetNotices = outcome.sheets.flatMap { sheet in
            sheet.notices.flatMap { noticeLines($0, layout: sheet.layout, prefix: "\(sheet.file): ") }
        }
        let fallbackLayout = outcome.sheets.first?.layout ?? .poses4A
        let assemblyNotices = outcome.notices.flatMap { noticeLines($0, layout: fallbackLayout, prefix: "") }
        return ([report.id] + sources + sheetNotices + assemblyNotices + resultLines(report)
                + ["  コンタクトシート: \(relative(outcome.contactSheet, to: root))"]
                + closingLines(outcome, root: root)).joined(separator: "\n")
    }

    static func sourceLine(_ source: BakeReport.Source) -> String {
        "  \(source.file)  \(source.layout.displayName)  \(source.figures)/\(source.layout.expectedCount) コマ"
            + "  \(source.pixelWidth)×\(source.pixelHeight)・\(source.background.displayName)"
    }

    /// 知らせと、その直し。
    static func noticeLines(_ notice: ImportNotice, layout: SheetLayout, prefix: String) -> [String] {
        let head = "  ! \(prefix)\(notice)"
        switch notice.remedy {
        case .fix(let fix): return [head, "      直し（\(fix.rawValue)）: \(fix.text(for: layout))"]
        case .sharperPoses: return [head, "      立ち姿を大きく描いてもらう（コマを大きく、余白を広く）"]
        case nil: return [head]
        }
    }

    static func resultLines(_ report: BakeReport) -> [String] {
        let frames = Pose.allCases.compactMap { pose in
            report.frames[pose].map { "\(pose.displayName) \($0)" }
        }
        let spares = report.spares.map(\.displayName)
        let eyelids = report.eyelids.map(\.displayName)
        return [
            "  コマ: " + frames.joined(separator: "・")
                + (spares.isEmpty ? "" : "（予備: \(spares.joined(separator: "・"))）"),
            "  まぶたの差分: " + (eyelids.isEmpty ? "なし" : eyelids.joined(separator: "・"))
                + " ／ 寝息の 2 コマ目: 1 コマ目を" + (report.sleepFrameCoversBase ? "覆える" : "覆えない")
                + " ／ 立ち姿の背: \(report.standingHeight) 画素",
        ]
    }

    static func closingLines(_ outcome: BakeOutcome, root: URL) -> [String] {
        guard let final = outcome.final else {
            return ["✗ そろわないので final/ には書きませんでした:"] + outcome.missing.map { "  ・\($0)" }
        }
        return ["✓ \(relative(final, to: root))/ に書きました。"
                + "次は python3 tools/pipeline/pipeline.py で Asset Catalog に入れます"]
    }

    /// リポジトリの根からの場所（根の外なら、そのままの場所）。
    static func relative(_ url: URL, to root: URL) -> String {
        let path = url.standardizedFileURL.path(percentEncoded: false)
        let base = root.standardizedFileURL.path(percentEncoded: false)
        let prefix = base.hasSuffix("/") ? base : base + "/"
        return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
    }
}
