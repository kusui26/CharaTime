import SwiftUI
import CTStore
import CTRender

/// 置き方のガイド（プラン §9 Phase 3 の 3-4）。設定 →「置き方のガイド」から開く。
///
/// ホーム画面に大を 1 つ、ページのいちばん上に置く手順（基本の置き方。D-31）と、外観の条件、
/// いまの様子（ウィジェットの記録から推し量る）、うまくいかないときの手当てをまとめる。
/// 終わりの確かめ方は「読んで置ける」。
struct PlacementGuideScreen: View {

    let model: StandbyModel

    var body: some View {
        List {
            Section {
                PagePlanDiagram()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } footer: {
                Text("大を 1 つ、ページのいちばん上に置きます。その下には、アプリのアイコンを置いても、空けておいてもかまいません。")
            }
            stepsSection
            statusSection
            troubleSection
        }
        .navigationTitle("置き方のガイド")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.reloadWidgetRecord() }
    }

    // MARK: - 作り方

    private var stepsSection: some View {
        Section("作り方") {
            ForEach(Array(GuideStep.all.enumerated()), id: \.offset) { index, step in
                StepRow(number: index + 1, step: step)
            }
            NavigationLink("透過背景へ", value: SettingsRoute.transparentBackground)
        }
    }

    // MARK: - いまの様子

    private var statusSection: some View {
        Section {
            ForEach(checks, id: \.title) { CheckRow(check: $0) }
        } header: {
            Text("いまの様子（この iPhone）")
        } footer: {
            Text("置いてあるかは、ウィジェットが作り直すたびに残す記録から読んでいます（外してから 24 時間ほどは、"
                 + "置いてあるように出ます）。アプリに戻るたびに読み直します。")
        }
    }

    private var checks: [PlacementCheck] {
        PlacementCheck.items(PlacementCheck.Inputs(record: model.widgetRecord, widget: model.state.widget,
                                                   iconStyle: model.iconStyleReading, system: .current),
                             now: Date(), calendar: model.input.calendar)
    }

    // MARK: - うまくいかないとき

    private var troubleSection: some View {
        Section("うまくいかないとき") {
            ForEach(GuideTrouble.all, id: \.question) { trouble in
                DisclosureGroup(trouble.question) {
                    Text(trouble.answer).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// 作り方の 1 段。
struct GuideStep {
    let title: String
    let body: String

    /// ホーム画面の表示（「編集」「ウィジェットを追加」「カスタマイズ」など）は、iOS 26 の日本語の表示のまま
    /// （ロボットの `SpringBoardText` と同じ）。足したウィジェットは、ページのいちばん上に入る（ロボットで確かめた）。
    static let all = [
        GuideStep(title: "ページを決める",
                  body: "キャラが見やすい、空のページがおすすめです。ホーム画面の何もないところを長押しして"
                      + "編集モード（アイコンが揺れる）にし、最後のページの次に増える何もないページまでめくります"
                      + "（めくり過ぎるとアプリライブラリ）。"),
        GuideStep(title: "大を置く",
                  body: "左上の「編集」→「ウィジェットを追加」で「CharaTime」を選びます（検索でも出ます）。"
                      + "横にめくって大にし、「ウィジェットを追加」。大はページのいちばん上に入ります。"
                      + "右上の「完了」で終わります。"),
        GuideStep(title: "外観を選ぶ",
                  body: "ホーム画面の外観を「デフォルト」か「ダーク」にします（編集モードの「編集」→「カスタマイズ」）。"
                      + "「クリア」「色合い調整」では部屋の絵と透過背景が外れ、キャラとアイテムだけが色つきで立ちます。"),
        GuideStep(title: "好みで、透過背景とまばたき",
                  body: "壁紙の上にキャラがいるように見せたいときは「透過背景」へ。まばたきや寝息をさせたいときは、"
                      + "設定の「まばたき・寝息（疑似アニメ）」を入にします。"),
    ]
}

/// うまくいかないときの 1 問 1 答。
struct GuideTrouble {
    let question: String
    let answer: String

    static let all = [
        // D-31: 部屋の絵はどの大きさも同じなので、2 つ置くと同じキャラが 2 か所に見える。
        GuideTrouble(question: "キャラが 2 匹いる",
                     answer: "大・中・小は、どれも同じ部屋とキャラを映します。ホーム画面に 2 つ置くと、"
                         + "同じキャラが 2 か所に見えます。ホーム画面には大を 1 つだけ置いてください"
                         + "（スタンバイの小は別の画面なので、そのままで大丈夫です）。"),
        GuideTrouble(question: "キャラがまばたきしない",
                     answer: "設定の「まばたき・寝息（疑似アニメ）」が入か確かめてください。低電力モードのあいだと、"
                         + "動きをまだ確かめていない iOS（「いまの様子」の iOS で分かります）では、5 分ごとに絵が変わるだけです。"
                         + "「クリア」「色合い調整」の外観と、視差効果を減らす設定のあいだは、1 秒に 1 回の小さな動きだけです。"),
        GuideTrouble(question: "ウィジェットの中の壁紙が、外とずれて見える",
                     answer: "大がページのいちばん上にあるか確かめてください（透過背景は、その位置で切り抜いています）。"
                         + "壁紙を替えたときは、「透過背景」でスクショを撮り直して取り込みます。アプリ名のラベルの有無も、"
                         + "撮ったときと同じか確かめてください。それでもずれるときは「位置を確かめる・寄せる」で"
                         + "1 画素ずつ寄せます。"),
        GuideTrouble(question: "ウィジェットの縁に細い線が見える",
                     answer: "iOS 26 がすべてのウィジェットの縁に描く、ガラスの縁取りです。アプリからは消せません。"),
        GuideTrouble(question: "白い四角のウィジェットが残っている",
                     answer: "前に試したウィジェット（いまは無いもの）です。長押しして「ウィジェットを削除」で外してください。"),
        // 日本語の iOS では StandBy を「スタンバイ」と呼ぶ（設定の項目の名前も）。
        GuideTrouble(question: "スタンバイ（充電中の横向きの画面）にも置きたい",
                     answer: "設定の「スタンバイ」を入にし、充電しながら横向きに立ててロックすると、スタンバイになります。"
                         + "ウィジェットを長押しして、左上の「＋」から CharaTime の小を足します。"
                         + "夜は赤い表示になります（設定の「スタンバイ」→「ナイトモード」が入のとき）。"),
    ]
}

/// 作り方の 1 行（番号・見出し・説明）。
struct StepRow: View {
    let number: Int
    let step: GuideStep

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "\(number).circle.fill")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title).font(.headline)
                Text(step.body).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

/// いまの様子の 1 行。できている・まだ・好みで、を印で見分ける。
struct CheckRow: View {
    let check: PlacementCheck

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(check.title)
                Text(check.detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch check.state {
        case .done: "checkmark.circle.fill"
        case .pending: "circle"
        case .notNeeded: "minus.circle"
        }
    }

    private var color: Color {
        switch check.state {
        case .done: .green
        case .pending: .orange
        case .notNeeded: .secondary
        }
    }
}

/// 置き方の縮図（大をページのいちばん上に。D-31）。iOS 26 の実測の位置（`SlotGeometry`）で描くので、本物と形がそろう。
struct PagePlanDiagram: View {

    private static let geometry = SlotGeometry.iPhone402x874
    /// 画面の大きさ（ポイント。402×874 の iPhone）。
    private static let screen = CGSize(width: Double(geometry.pixelWidth) / geometry.scale,
                                       height: Double(geometry.pixelHeight) / geometry.scale)
    /// 縮図の高さ（ポイント）。手順と一緒に 1 画面に収まる大きさ。
    private static let height: Double = 240
    /// 画面の角丸と、Dock の位置（ポイント。実機のスクショで測ったおおよそ）。
    private static let screenCornerRadius: Double = 55
    private static let dock = CGRect(x: 17, y: 754, width: 367, height: 102)
    private static let dockCornerRadius: Double = 38
    /// ウィジェットの縁の線の太さ（ポイント）。
    private static let outlineWidth: Double = 1.5

    var body: some View {
        let scale = Self.height / Self.screen.height
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Self.screenCornerRadius * scale, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
            if let frame = Self.geometry.frame(of: SlotGeometry.largeAtTop, style: .labeled) {
                widget(SlotGeometry.largeAtTop.family, frame: frame, scale: scale)
            }
            RoundedRectangle(cornerRadius: Self.dockCornerRadius * scale, style: .continuous)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: Self.dock.width * scale, height: Self.dock.height * scale)
                .offset(x: Self.dock.minX * scale, y: Self.dock.minY * scale)
        }
        .frame(width: Self.screen.width * scale, height: Self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("大をページのいちばん上に置いた図")
    }

    private func widget(_ family: WidgetSlot.Family, frame: PixelRect, scale: Double) -> some View {
        let points = scale / Self.geometry.scale
        return RoundedRectangle(cornerRadius: WidgetStage.cornerRadius * scale, style: .continuous)
            .fill(Color.accentColor.opacity(0.18))
            .overlay(RoundedRectangle(cornerRadius: WidgetStage.cornerRadius * scale, style: .continuous)
                .stroke(Color.accentColor, lineWidth: Self.outlineWidth))
            .overlay(Text(family.displayName).font(.headline).foregroundStyle(Color.accentColor))
            .frame(width: Double(frame.width) * points, height: Double(frame.height) * points)
            .offset(x: Double(frame.x) * points, y: Double(frame.y) * points)
    }
}
