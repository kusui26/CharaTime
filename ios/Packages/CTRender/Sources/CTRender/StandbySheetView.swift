import SwiftUI
import CTCore
import CTStore

/// いまの設定を見る画面。
///
/// **書き換えられるのは、ウィジェットの疑似アニメの入／切だけ**（3-2b。電池を入と切で
/// 測れるようにするため。Q-15）。ほかの設定の書き換えは、ウィジェットの設定画面（3-C ⑩）で作る。
/// ウィジェットが作り直すたびに残す記録（メモリ・作り直した時刻）も、ここで見せる（3-2c）。
public struct SettingsSummaryView: View {

    public let settings: CTStore.Settings
    public let widget: WidgetSettings
    /// 疑似アニメの入／切。nil なら読むだけ。
    public let pseudoAnimation: Binding<Bool>?
    /// いまのホーム画面ウィジェットの描画の段（アプリから見た見込み）。nil なら出さない。
    public let widgetCapability: RenderCapability?
    /// ウィジェットの記録。nil なら出さない。
    public let widgetRecord: WidgetDiagnostics?
    /// 記録の時刻を「きょう」と見比べる基準。記録は実時刻なので、時刻の早送りはかけない。
    public let now: Date
    public let calendar: Calendar
    /// 1 週間の運用（3-7）の様子（「3 日目」など）。nil なら行を出さない。
    public let weekRunStatus: String?

    public init(settings: CTStore.Settings, widget: WidgetSettings,
                pseudoAnimation: Binding<Bool>? = nil, widgetCapability: RenderCapability? = nil,
                widgetRecord: WidgetDiagnostics? = nil, now: Date = Date(), calendar: Calendar = .current,
                weekRunStatus: String? = nil) {
        self.settings = settings
        self.widget = widget
        self.pseudoAnimation = pseudoAnimation
        self.widgetCapability = widgetCapability
        self.widgetRecord = widgetRecord
        self.now = now
        self.calendar = calendar
        self.weekRunStatus = weekRunStatus
    }

    public var body: some View {
        List {
            Section("待受モード") {
                row("時計を出す", settings.showsClock ? "はい" : "いいえ")
                row("時計の見た目", settings.clockStyle.displayName)
                row("夜は暗くする", settings.nightMode ? "はい" : "いいえ")
            }
            Section {
                NavigationLink("置き方のガイド", value: SettingsRoute.placementGuide)
                if let weekRunStatus {
                    NavigationLink(value: SettingsRoute.weekRun) { row("1 週間の運用", weekRunStatus) }
                }
                if let pseudoAnimation {
                    Toggle("まばたき・寝息（疑似アニメ）", isOn: pseudoAnimation)
                } else {
                    row("疑似アニメ", pseudoAnimationLabel)
                }
                if let widgetCapability { row("いまの動き", widgetCapability.label) }
                // 進む先の画面はアプリが用意する（`SettingsRoute`）。
                NavigationLink(value: SettingsRoute.transparentBackground) {
                    row("透過背景", TransparentStatus.label(widget))
                }
            } header: {
                Text("ウィジェット")
            } footer: {
                Text("既定は切です（電池の減り方を測ってから決めます）。視差効果を減らす設定のあいだは、"
                     + "まばたき・寝息のような小さな動きだけにして、横にすべる動きときらめきを止めます。"
                     + "低電力モードのあいだは、5 分ごとに絵が変わるだけになります。")
            }
            if let widgetRecord {
                WidgetRecordSection(diagnostics: widgetRecord, now: now, calendar: calendar)
            }
            Section {
                Text("ほかの設定の書き換えは、ウィジェットの設定画面で作ります。いまは待受モードの見え方を"
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
