import SwiftUI
import CTStore

/// 設定画面の「ウィジェットの記録」（プラン §9 Phase 3 の 3-2c）。
///
/// ウィジェット拡張が作り直すたびに残した記録（`WidgetDiagnostics`）をまとめて見せる。
/// 実機でメモリの最大値（R-18）と作り直しの間隔（3-7）を読むための欄で、ユーザーが記録表に写す。
struct WidgetRecordSection: View {

    let diagnostics: WidgetDiagnostics
    let now: Date
    let calendar: Calendar

    /// 「最近の作り直し」に並べる件数。大と中を置けば 1 日半ほど（それぞれ 1 日に約 4 回）。
    private static let recentCount = 12

    var body: some View {
        Section {
            if diagnostics.reloads.isEmpty {
                Text("まだ記録がありません。ホーム画面に置くと、ウィジェットを作り直すたびに残ります。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                memoryRow
                ForEach(diagnostics.summaries(now: now), id: \.family) { familyRow($0) }
                DisclosureGroup("最近の作り直し") {
                    let recent = Array(diagnostics.latest(Self.recentCount).enumerated())
                    ForEach(recent, id: \.offset) { _, reload in reloadRow(reload) }
                }
            }
        } header: {
            Text("ウィジェットの記録")
        } footer: {
            Text("メモリは、ウィジェットの拡張（大・中・小で 1 つ）が作り直すたびに自分で測った最大値です。"
                 + "上限は約 30 MB、目安は 15 MB 以下。作り直す時刻は OS が決めます。")
        }
    }

    /// 拡張のメモリ。大きさごとには分けない（1 つのプロセスが大・中・小を作る）。
    private var memoryRow: some View {
        HStack {
            Text("メモリの最大（24 時間）")
            Spacer()
            Text(diagnostics.peakBytes(now: now).map(WidgetRecordFormat.megabytes) ?? "—")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func familyRow(_ summary: WidgetDiagnostics.FamilySummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(WidgetRecordFormat.familyName(summary.family))
                Text("最後の作り直し " + time(summary.lastReload.date))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("24 時間で \(summary.reloadsInLastDay) 回")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func reloadRow(_ reload: WidgetReload) -> some View {
        HStack {
            Text(time(reload.date)).monospacedDigit()
            Text(WidgetRecordFormat.familyName(reload.family))
            Text(WidgetRecordFormat.timeline(reload))
                .foregroundStyle(.secondary)
            Spacer()
            Text(WidgetRecordFormat.megabytes(reload.peakBytes))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
    }

    private func time(_ date: Date) -> String {
        WidgetRecordFormat.time(date, now: now, calendar: calendar)
    }
}

/// 記録の見せ方。純粋な変換なので View の外に置く（View の静的な値は `@MainActor` に縛られる）。
enum WidgetRecordFormat {

    /// 1 MB のバイト数。シミュレータで使った `vmmap` と同じく 1024 × 1024 で数える。
    private static let bytesPerMegabyte: Double = 1024 * 1024

    static func megabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f MB", Double(bytes) / bytesPerMegabyte)
    }

    /// きょうなら「9:21」、ほかの日は「9/24 23:05」。
    static func time(_ date: Date, now: Date, calendar: Calendar) -> String {
        let clock = ClockFormat.time(date, calendar: calendar)
        guard !calendar.isDate(date, inSameDayAs: now) else { return clock }
        let day = calendar.dateComponents([.month, .day], from: date)
        return "\(day.month ?? 0)/\(day.day ?? 0) " + clock
    }

    static func familyName(_ family: WidgetSlot.Family) -> String {
        family.displayName
    }

    /// 作ったタイムライン: 「73 件・動く」。
    ///
    /// 件数が 1 件なら、同梱データが読めずに仮の 1 枚を出したしるし。「止め」は、設定が切か、
    /// 拡張がマスク書体を見つけられなかったしるし（設定が入なのに止めなら、書体を疑う）。
    static func timeline(_ reload: WidgetReload) -> String {
        "\(reload.entryCount) 件・" + (reload.pseudoAnimation ? "動く" : "止め")
    }
}
