import SwiftUI
import CTCore
import CTStore

/// いまの設定を読むだけの画面。
///
/// **書き換えはまだできない。** 設定を保存する経路（`StateStore` への書き戻しと
/// ウィジェットの再読込）は Phase 3 で作る。ここでは「いまどうなっているか」を
/// 実機で確かめられるようにしておく。
public struct SettingsSummaryView: View {

    public let settings: CTStore.Settings
    public let widget: WidgetSettings

    public init(settings: CTStore.Settings, widget: WidgetSettings) {
        self.settings = settings
        self.widget = widget
    }

    public var body: some View {
        List {
            Section("待受モード") {
                row("時計を出す", settings.showsClock ? "はい" : "いいえ")
                row("時計の見た目", settings.clockStyle.displayName)
                row("夜は暗くする", settings.nightMode ? "はい" : "いいえ")
            }
            Section("ウィジェット") {
                row("疑似アニメ", pseudoAnimationLabel)
            }
            Section {
                Text("設定の書き換えは Phase 3 で作ります。いまは待受モードの見え方を"
                     + "実機で確かめるための画面です。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 選んでいなければ「（既定）」を添える。既定は 3-2b で決める（プラン §9 Phase 3 の 3-C ⑪）。
    private var pseudoAnimationLabel: String {
        let value = widget.usesPseudoAnimation ? "入" : "切"
        return widget.pseudoAnimation == nil ? "\(value)（既定）" : value
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
public struct DayPlanListView: View {

    public let input: WorldInput

    public init(input: WorldInput) { self.input = input }

    public var body: some View {
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
