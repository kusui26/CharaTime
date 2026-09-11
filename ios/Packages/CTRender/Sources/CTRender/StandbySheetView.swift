import SwiftUI
import CTCore
import CTStore

/// 待受モードから開く画面の入れ物。
struct StandbySheetView: View {

    let kind: StandbySheet
    let input: WorldInput
    let settings: CTStore.Settings

    var body: some View {
        NavigationStack {
            titled(content)
        }
        .presentationDetents([.medium, .large])
    }

    /// 題名を付ける。`navigationBarTitleDisplayMode` は iOS にしか無いので分けてある
    /// （CTRender は macOS でもビルドする。`swift test` がそこで走るため）。
    private func titled(_ view: some View) -> some View {
        #if os(iOS)
        view.navigationTitle(kind.title).navigationBarTitleDisplayMode(.inline)
        #else
        view.navigationTitle(kind.title)
        #endif
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .settings: SettingsSummaryView(settings: settings)
        case .dayPlan: DayPlanListView(input: input)
        }
    }
}

/// いまの設定を読むだけの画面。
///
/// **書き換えはまだできない。** 設定を保存する経路（`StateStore` への書き戻しと
/// ウィジェットの再読込）は Phase 3 で作る。ここでは「いまどうなっているか」を
/// 実機で確かめられるようにしておく。
struct SettingsSummaryView: View {

    let settings: CTStore.Settings

    var body: some View {
        List {
            Section("待受モード") {
                row("時計を出す", settings.showsClock ? "はい" : "いいえ")
                row("時計の見た目", settings.clockStyle.displayName)
                row("夜は暗くする", settings.nightMode ? "はい" : "いいえ")
            }
            Section("ウィジェット") {
                row("疑似アニメ", settings.widgetPseudoAnimation ? "入" : "切")
            }
            Section {
                Text("設定の書き換えは Phase 3 で作ります。いまは待受モードの見え方を"
                     + "実機で確かめるための画面です。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

/// きょうの行動表（プラン §9 Phase 1 の 1-5）。
///
/// 実機で 1 日放置したときに「何をしていたはずか」を突き合わせるための画面。
struct DayPlanListView: View {

    let input: WorldInput

    var body: some View {
        let plan = DayPlan.make(for: DayKey(Date(), calendar: input.calendar), input: input)
        List {
            Section("\(clock(plan.wakeMinute)) 起床 ・ \(clock(plan.bedtimeMinute)) 就寝") {
                ForEach(Array(plan.segments.enumerated()), id: \.offset) { _, segment in
                    HStack {
                        Text("\(clock(segment.startMinute))–\(clock(segment.endMinute))")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(segment.activity.label)
                        Spacer()
                        Text("\(Int(segment.durationMinutes))分")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func clock(_ minute: Double) -> String {
        String(format: "%02d:%02d", Int(minute) / 60 % 24, Int(minute) % 60)
    }
}
