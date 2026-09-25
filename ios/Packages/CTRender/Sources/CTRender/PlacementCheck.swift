import Foundation
import CTStore

/// 置き方のガイドの「いまの様子」の 1 行（プラン §9 Phase 3 の 3-4）。
///
/// アプリはホーム画面を見られないので、ウィジェットの記録（ウィジェットが作り直すたびに残す）から、
/// 大（と中）が置いてあるかを推し量る。24 時間のうちに作り直していれば、置いてあるとみなす
/// （タイムラインは 6 時間ぶんなので、置いてあれば 1 日に何度か作り直す）。
///
/// 基本の置き方は、大を 1 つ、ページのいちばん上に（D-31）。中は大と同じ部屋を丸ごと映し、キャラが
/// 2 か所に見えるので、置いてあるときだけ行を出して、外すのを勧める。
public struct PlacementCheck: Sendable, Equatable {

    public enum State: Sendable, Equatable {
        /// できている。
        case done
        /// まだ（ページを作るのに要る）。
        case pending
        /// ページを作るのには要らない。好みで選ぶもの（使っていない）と、この画面では使えないもの。
        case notNeeded
    }

    public let title: String
    public let detail: String
    public let state: State

    /// いまの様子を決める材料。
    public struct Inputs: Sendable {
        /// ウィジェットの記録（大と中が置いてあるかを推し量る。中は置いてあれば、外すのを勧める）。
        public var record: WidgetDiagnostics
        public var widget: WidgetSettings
        /// ウィジェットが知らせた大きさから読んだ、ラベルの有無。
        public var iconStyle: SlotGeometry.IconStyleReading
        public var system: SystemVersion

        public init(record: WidgetDiagnostics, widget: WidgetSettings,
                    iconStyle: SlotGeometry.IconStyleReading, system: SystemVersion) {
            self.record = record
            self.widget = widget
            self.iconStyle = iconStyle
            self.system = system
        }
    }

    /// ページ（大・中・ラベル）、飾り（透過背景・まばたき）、iOS の順に並べる。中は置いてあるときだけ。
    public static func items(_ inputs: Inputs, now: Date, calendar: Calendar) -> [PlacementCheck] {
        let summaries = inputs.record.summaries(now: now)
        let summary = { (family: WidgetSlot.Family) in summaries.first { $0.family == family } }
        let widgets = [large(summary(.large), now: now, calendar: calendar),
                       medium(summary(.medium), now: now, calendar: calendar)]
        let extras = [label(inputs.iconStyle), transparency(inputs.widget),
                      pseudoAnimation(inputs.widget), os(inputs.system)]
        return widgets.compactMap { $0 } + extras
    }

    private static func large(_ summary: WidgetDiagnostics.FamilySummary?, now: Date,
                              calendar: Calendar) -> PlacementCheck {
        let title = WidgetSlot.Family.large.displayName
        guard let summary else {
            return PlacementCheck(title: title, detail: "まだ見当たりません（置くと、ここに出ます）", state: .pending)
        }
        guard let note = placedNote(summary, now: now, calendar: calendar) else {
            return PlacementCheck(title: title, detail: "24 時間作り直していません（外したのかもしれません）",
                                  state: .pending)
        }
        return PlacementCheck(title: title, detail: note, state: .done)
    }

    /// 中は、置いてあるときだけ行を出す。大と同じ部屋を映すので、ページには要らない（D-31）。
    private static func medium(_ summary: WidgetDiagnostics.FamilySummary?, now: Date,
                               calendar: Calendar) -> PlacementCheck? {
        summary.flatMap { placedNote($0, now: now, calendar: calendar) }.map { note in
            PlacementCheck(title: WidgetSlot.Family.medium.displayName,
                           detail: note + "。大と同じ部屋を映すので、キャラが 2 か所に見えます。外すのがおすすめです",
                           state: .notNeeded)
        }
    }

    /// 24 時間のうちに作り直していれば「置いてあります（最後に作り直したのは …）」。していなければ nil。
    private static func placedNote(_ summary: WidgetDiagnostics.FamilySummary, now: Date,
                                   calendar: Calendar) -> String? {
        guard summary.reloadsInLastDay > 0 else { return nil }
        let time = WidgetRecordFormat.time(summary.lastReload.date, now: now, calendar: calendar)
        return "置いてあります（最後に作り直したのは \(time)）"
    }

    /// 表に無い大きさは、待っても分からない。ページは作れるので「まだ」にせず、透過背景が使えないと伝える。
    private static func label(_ reading: SlotGeometry.IconStyleReading) -> PlacementCheck {
        let title = "アプリ名のラベル"
        switch reading {
        case .detected(.labeled): return PlacementCheck(title: title, detail: "あり", state: .done)
        case .detected(.labelFree):
            return PlacementCheck(title: title, detail: "なし（大きいアプリアイコン）", state: .done)
        case .notYetPlaced: return PlacementCheck(title: title, detail: "大を置くと分かります", state: .pending)
        case .unknownSize:
            return PlacementCheck(title: title, detail: "表に無い大きさです（画面の表示を拡大しているときなど）。"
                                      + "透過背景は使えません", state: .notNeeded)
        }
    }

    private static func transparency(_ widget: WidgetSettings) -> PlacementCheck {
        let isUsed = !widget.wallpaper.names.isEmpty
        return PlacementCheck(title: "透過背景", detail: TransparentStatus.label(widget),
                              state: isUsed ? .done : .notNeeded)
    }

    private static func pseudoAnimation(_ widget: WidgetSettings) -> PlacementCheck {
        let isOn = widget.usesPseudoAnimation
        return PlacementCheck(title: "まばたき・寝息", detail: isOn ? "入" : "切", state: isOn ? .done : .notNeeded)
    }

    /// 確かめていない版では、疑似アニメを使わない（D-22）。
    private static func os(_ system: SystemVersion) -> PlacementCheck {
        let version = "\(system.major).\(system.minor)"
        guard VerifiedSystems.allowsPseudoAnimation(system) else {
            return PlacementCheck(title: "iOS", detail: "\(version)（まだ確かめていない版。5 分ごとの切り替えになります）",
                                  state: .pending)
        }
        return PlacementCheck(title: "iOS", detail: "\(version)（動きを確かめた版）", state: .done)
    }
}
