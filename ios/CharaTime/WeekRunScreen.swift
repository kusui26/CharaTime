import SwiftUI
import UIKit
import CTStore
import CTRender

/// 1 週間の運用の記録表（プラン §9 Phase 3 の 3-7）。設定 →「1 週間の運用」から開く。
///
/// 毎日 2 分で、きょうの問いに答え（1・2 日目の夜は電池も）、その日に確かめることを見る。作り直した時刻と
/// メモリは、ウィジェットの記録から自動で入る。最後に全部を 1 つの文章にして書き出し、送ってもらう。
/// **3-7 のあいだはビルドを替えない**ので、この画面もその版のまま 1 週間使う。
struct WeekRunScreen: View {

    let model: StandbyModel

    var body: some View {
        List {
            if let failure = model.weekRunSaveFailure {
                Section("記録を書けませんでした") {
                    Label(failure, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
            }
            if let startedAt = model.weekRun.startedAt {
                WeekRunStartedSections(model: model, startedAt: startedAt, now: Date())
            } else {
                WeekRunIntroSections(model: model)
            }
        }
        .navigationTitle("1 週間の運用")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
        .onAppear { model.reloadWidgetRecord() }
    }
}

/// 前の日の記録をつけ直す画面。
struct WeekRunDayScreen: View {

    let model: StandbyModel
    let number: Int

    var body: some View {
        List {
            Section {
                WeekRunDayFields(model: model, number: number)
            } header: {
                Text(model.weekRun.startedAt.map { dayLabel(startedAt: $0) } ?? "")
            }
        }
        .navigationTitle("\(number) 日目")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
    }

    private func dayLabel(startedAt: Date) -> String {
        let calendar = model.input.calendar
        return WeekRunPlan.dayLabel(WeekRunPlan.date(ofDay: number, startedAt: startedAt, calendar: calendar),
                                    calendar: calendar)
    }
}

// MARK: - 始める前

/// 始める前: 何をするかと、7 日の予定。
struct WeekRunIntroSections: View {

    let model: StandbyModel

    var body: some View {
        Section {
            Text("ウィジェットを置いたまま 1 週間すごし、毎日 2 分だけ様子をつけます。作り直した時刻とメモリは"
                 + "自動で入ります。7 日目に書き出して送ってください。")
            Text("毎日つけること: キャラが見えていたか・まばたきや寝息が動いていたか・アプリと同じ姿だったか"
                 + "（切り替わった直後に開いて）")
                .font(.footnote)
            Text("この 1 週間は、アプリを入れ直しません（同じ版のまま、1 週間の様子を見るため）。")
                .foregroundStyle(.secondary)
        }
        Section("予定") {
            ForEach(1...WeekRunPlan.length, id: \.self) { WeekRunPlanRow(day: $0) }
        }
        Section {
            Button("きょうから始める") { model.startWeekRun(at: Date()) }
        }
    }
}

/// 予定の 1 日（確かめることと、その日の手引き）。
struct WeekRunPlanRow: View {

    let day: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(day) 日目").font(.headline)
            ForEach(lines, id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
        }
    }

    private var lines: [String] {
        (WeekRunPlan.checks(on: day).map(\.title) + WeekRunPlan.notes(on: day)).map { "・" + $0 }
    }
}

// MARK: - 始めたあと

/// 始めたあと: きょうの記録、確かめること、これまでの日、自動の記録、書き出し。
struct WeekRunStartedSections: View {

    let model: StandbyModel
    let startedAt: Date
    let now: Date
    @State private var isConfirmingRestart = false

    private var calendar: Calendar { model.input.calendar }
    private var today: Int { WeekRunPlan.dayNumber(startedAt: startedAt, now: now, calendar: calendar) }

    var body: some View {
        todaySection
        todayChecksSection
        otherChecksSection
        if today > 1 { pastDaysSection }
        automaticSection
        exportSection
    }

    private var todaySection: some View {
        Section {
            ForEach(todayNotes, id: \.self) { Label($0, systemImage: "info.circle").font(.footnote) }
            WeekRunDayFields(model: model, number: today)
        } header: {
            Text("きょう（\(today) 日目・\(dayLabel(today))）")
        }
    }

    /// その日の手引き。7 日を過ぎたら、書き出して送るよう促す。
    private var todayNotes: [String] {
        today > WeekRunPlan.length ? ["7 日が過ぎました。いちばん下の「記録を書き出す」で送ってください"]
            : WeekRunPlan.notes(on: today)
    }

    @ViewBuilder
    private var todayChecksSection: some View {
        let items = WeekRunPlan.checks(on: today)
        if !items.isEmpty {
            Section("きょう確かめること") {
                ForEach(items) { WeekRunCheckRow(model: model, item: $0) }
            }
        }
    }

    private var otherChecksSection: some View {
        Section {
            ForEach(WeekRunPlan.checks.filter { $0.day != today }) { item in
                DisclosureGroup {
                    WeekRunCheckRow(model: model, item: item, showsTitle: false)
                } label: {
                    WeekRunCheckLabel(item: item, check: model.weekRun.check(item.id))
                }
            }
        } header: {
            Text("ほかの日に確かめること")
        } footer: {
            Text("日がずれてもかまいません。できた日に「期待どおり」か「ちがった」を選びます。")
        }
    }

    private var pastDaysSection: some View {
        Section("これまでの日") {
            ForEach(Array((1..<today).reversed()), id: \.self) { number in
                NavigationLink(value: SettingsRoute.weekRunDay(number)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(number) 日目・\(dayLabel(number))")
                        Text(WeekRunFormat.daySummary(model.weekRun.day(number)))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var automaticSection: some View {
        Section {
            ForEach(model.widgetRecord.daySummaries(from: startedAt, through: now, calendar: calendar),
                    id: \.day) { day in
                VStack(alignment: .leading, spacing: 2) {
                    Text(WeekRunPlan.dayLabel(day.day, calendar: calendar))
                    Text(WeekRunFormat.automatic(day)).font(.footnote).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("ウィジェットの記録（自動）")
        } footer: {
            Text("ウィジェットが作り直した回数と、いちばん長い間隔、メモリの最大です。タイムラインは 6 時間ぶんなので、"
                 + "間隔がそれより長いと、そのあいだ居場所と姿が変わりません。")
        }
    }

    private var exportSection: some View {
        Section {
            ShareLink(item: model.weekRunReport(now: now), subject: Text("CharaTime 1 週間の運用の記録"),
                      preview: SharePreview("1 週間の運用の記録")) {
                Label("記録を書き出す", systemImage: "square.and.arrow.up")
            }
            Button("記録を消して始め直す", role: .destructive) { isConfirmingRestart = true }
        } footer: {
            Text("書き出した文章を「コピー」して、Claude に送ってください。途中で送ってもかまいません。")
        }
        .confirmationDialog("これまでの記録を消しますか？", isPresented: $isConfirmingRestart,
                            titleVisibility: .visible) {
            Button("消して、きょうから始め直す", role: .destructive) { model.startWeekRun(at: Date()) }
            Button("消して、始める前に戻す", role: .destructive) { model.resetWeekRun() }
        } message: {
            Text("ウィジェットの記録（自動）は消えません。")
        }
    }

    private func dayLabel(_ number: Int) -> String {
        WeekRunPlan.dayLabel(WeekRunPlan.date(ofDay: number, startedAt: startedAt, calendar: calendar),
                             calendar: calendar)
    }
}

// MARK: - 1 日の欄

/// 1 日の記録の欄（問い・電池・メモ）。きょうの欄と、前の日をつけ直す画面で使う。
struct WeekRunDayFields: View {

    let model: StandbyModel
    let number: Int

    var body: some View {
        ForEach(WeekRunQuestion.asked(on: number), id: \.self) { question in
            VStack(alignment: .leading, spacing: 6) {
                Text(question.title)
                Text(question.detail).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                WeekRunAnswerPicker(title: question.title, labels: .daily, answer: answer(question))
            }
            .padding(.vertical, 2)
        }
        if WeekRunPlan.readsBattery(on: number) { batteryRows }
        TextField("メモ（気づいたこと）", text: note, axis: .vertical)
    }

    /// 電池の欄（Q-15）。切にする・入に戻すのも、ここでできる。
    @ViewBuilder
    private var batteryRows: some View {
        Text("電池（設定 → バッテリー →「過去 24 時間」）").font(.footnote).foregroundStyle(.secondary)
        LabeledContent("CharaTime") { PercentField(value: percent(\.charaTimePercent)) }
        LabeledContent("ホーム画面とロック画面") { PercentField(value: percent(\.homeAndLockPercent)) }
        Toggle("まばたき・寝息（疑似アニメ）", isOn: pseudoAnimation)
    }

    private var pseudoAnimation: Binding<Bool> {
        Binding(get: { model.state.widget.usesPseudoAnimation }, set: { model.setPseudoAnimation($0) })
    }

    private func answer(_ question: WeekRunQuestion) -> Binding<WeekRunAnswer?> {
        Binding(get: { model.weekRun.day(number)[keyPath: question.answer] },
                set: { value in model.updateWeekRunDay(number) { $0[keyPath: question.answer] = value } })
    }

    private var note: Binding<String> {
        Binding(get: { model.weekRun.day(number).note },
                set: { value in model.updateWeekRunDay(number) { $0.note = value } })
    }

    /// 電池の値。書いた時刻も残す（24 時間の窓が、入か切の時間にそろっていたかを後で確かめる）。
    private func percent(_ keyPath: WritableKeyPath<BatteryUsage, Int?>) -> Binding<Int?> {
        Binding(get: { model.weekRun.day(number).battery?[keyPath: keyPath] },
                set: { value in
                    model.updateWeekRunDay(number) { day in
                        var battery = day.battery ?? BatteryUsage()
                        battery[keyPath: keyPath] = value
                        battery.readAt = Date()
                        day.battery = battery
                    }
                })
    }
}

/// % を書く欄。
struct PercentField: View {

    @Binding var value: Int?

    /// 欄の幅（ポイント）。「100」が収まる。
    private static let width: Double = 56

    var body: some View {
        HStack(spacing: 2) {
            TextField("—", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: Self.width)
            Text("%").foregroundStyle(.secondary)
        }
    }
}

// MARK: - 確かめること

/// 一度だけ確かめることの 1 行（やり方・見るもの・結果・メモ）。
struct WeekRunCheckRow: View {

    let model: StandbyModel
    let item: WeekRunCheckItem
    var showsTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsTitle { Text(item.title).font(.headline) }
            // 区切りのボタンやメモの欄と並ぶと、長い字が 1 行で切られることがある。高さを字に合わせる。
            Text("やり方: " + item.how).font(.footnote).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("見るもの: " + item.expected).font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            WeekRunAnswerPicker(title: item.title, labels: .check, answer: answer)
            TextField("メモ（ちがったら、どうだったか）", text: note, axis: .vertical).font(.footnote)
        }
        .padding(.vertical, 2)
    }

    /// 答えた時刻も残す。ウィジェットの記録（作り直した時刻）と見比べる。
    private var answer: Binding<WeekRunAnswer?> {
        Binding(get: { model.weekRun.check(item.id).answer },
                set: { value in
                    model.updateWeekRunCheck(item.id) { check in
                        check.answer = value
                        check.answeredAt = value == nil ? nil : Date()
                    }
                })
    }

    private var note: Binding<String> {
        Binding(get: { model.weekRun.check(item.id).note },
                set: { value in model.updateWeekRunCheck(item.id) { $0.note = value } })
    }
}

/// 畳んだ「確かめること」の見出し（何日目・場面・結果）。
struct WeekRunCheckLabel: View {

    let item: WeekRunCheckItem
    let check: WeekRunCheck

    var body: some View {
        HStack {
            Text("\(item.day) 日目").font(.footnote).foregroundStyle(.secondary).monospacedDigit()
            Text(item.title)
            Spacer()
            Text(WeekRunFormat.result(check.answer)).font(.footnote).foregroundStyle(resultColor)
        }
    }

    private var resultColor: Color {
        switch check.answer {
        case .yes: .green
        case .no: .orange
        case nil: .secondary
        }
    }
}

// MARK: - 答え

/// 答えの言い方。毎日の問いは「はい・いいえ」、確かめることは「期待どおり・ちがった」。
struct WeekRunAnswerLabels {
    let yes: String
    let no: String

    static let daily = WeekRunAnswerLabels(yes: WeekRunFormat.answer(.yes), no: WeekRunFormat.answer(.no))
    static let check = WeekRunAnswerLabels(yes: WeekRunFormat.result(.yes), no: WeekRunFormat.result(.no))
}

/// まだ・はい・いいえ（まだ・期待どおり・ちがった）を 1 回押すだけで選ぶ。毎日 2 分で終わるように。
struct WeekRunAnswerPicker: View {

    let title: String
    let labels: WeekRunAnswerLabels
    @Binding var answer: WeekRunAnswer?

    var body: some View {
        Picker(title, selection: $answer) {
            Text("まだ").tag(WeekRunAnswer?.none)
            Text(labels.yes).tag(WeekRunAnswer?.some(.yes))
            Text(labels.no).tag(WeekRunAnswer?.some(.no))
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

extension View {

    /// キーボードの上に「完了」を出す。数字のキーボードには改行が無く、書いた % を決める手段が要る
    /// （数字の欄は、キーボードを閉じたときに値が決まる）。
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                    to: nil, from: nil, for: nil)
                }
            }
        }
    }
}
