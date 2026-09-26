import SwiftUI
import CTCore
import CTAssets
import CTRender
import CTStore

/// 待受モードを本体アプリに置くための殻。
///
/// CTRender は SwiftUI だけで書いてある（ウィジェット拡張と共有するため）。
/// **UIKit が要る仕事はここでやる**: 画面消灯の抑止と、電池の読み取り。
struct StandbyScreen: View {

    @State private var model = StandbyModel()
    @State private var sheet: StandbySheet? = StandbySheet.initial(
        from: ProcessInfo.processInfo.arguments)
    @Environment(\.scenePhase) private var scenePhase

    /// `-CTScreen band` で、帯を直す画面から開く（確認用）。
    private static let startsWithBandEditor =
        ProcessInfo.processInfo.arguments.contains("band")

    /// `-CTScreen widgets` で、ホーム画面ウィジェットの下見画面を出す（確認用。3-2）。
    private static let showsWidgetPreview =
        ProcessInfo.processInfo.arguments.contains("widgets")

    /// `-CTScreen standBy` で、StandBy の見え方をまねる下見画面を出す（確認用。3-5）。
    private static let showsStandByPreview =
        ProcessInfo.processInfo.arguments.contains("standBy")

    /// `-CTScreen transparent`・`alignment`・`guide`・`weekRun` で、設定の中の画面を開いた状態で起動する
    /// （確認用。3-3・3-4・3-7）。
    private static let initialSettingsPath: [SettingsRoute] = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("alignment") { return [.transparentBackground, .transparentAlignment] }
        if arguments.contains("guide") { return [.placementGuide] }
        if arguments.contains("weekRun") { return [.weekRun] }
        return arguments.contains("transparent") ? [.transparentBackground] : []
    }()

    /// 設定のシートの中で進んだ画面。
    @State private var settingsPath = initialSettingsPath
    /// 設定のシートの高さ。設定の中の画面（透過背景・置き方のガイド）を開いて起動するときは、全体が見える高さで開く。
    @State private var settingsDetent: PresentationDetent = initialSettingsPath.isEmpty ? .medium : .large

    var body: some View {
        Group {
            if Self.showsStandByPreview, let world = model.world {
                StandByPreviewScreen(input: model.input, world: world, settings: model.state.settings,
                                     motion: model.widgetMotion, timeWarp: model.timeWarp)
            } else if Self.showsWidgetPreview, let world = model.world {
                WidgetPreviewScreen(input: model.input, world: world, settings: model.state.settings,
                                    motion: model.widgetMotion, timeWarp: model.timeWarp)
            } else if let world = model.world {
                StandbyView(input: model.input, world: world,
                            settings: model.state.settings, battery: model.battery,
                            timeWarp: model.timeWarp, sheet: $sheet)
            } else {
                MissingAssetsView(reason: model.loadFailure)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        // **へやの画面だけは全画面で出す。** 歩ける帯は画面の高さに対する比で決めるので、
        // シートの余白ぶん縮んだ画面で決めると、待受モードに戻したときに帯がずれる。
        .fullScreenCover(isPresented: isShowingRoom) { roomSetup() }
        .sheet(item: Binding(get: { sheet == .room ? nil : sheet },
                             set: { sheet = $0 })) { sheetContent($0) }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        // 確認用: `-CTImportWallpaper` で渡した壁紙のスクショを取り込む（3-3）。渡していなければ何もしない。
        .task { await model.importWallpapersForChecking(ProcessInfo.processInfo.arguments) }
        .onChange(of: scenePhase) { _, phase in model.scenePhaseChanged(to: phase) }
    }

    /// へやの画面が出ているか。全画面で出すので、ほかのシートとは別に持つ。
    private var isShowingRoom: Binding<Bool> {
        Binding(get: { sheet == .room }, set: { if !$0 { sheet = nil } })
    }

    /// **部屋を選ぶ画面だけは本体アプリが持つ**（写真アプリを開くので、
    /// ウィジェット拡張と共有する層には置けない）。
    @ViewBuilder
    private func roomSetup() -> some View {
        if let world = model.world {
            RoomSetupSheet(
                current: model.room, world: world,
                onChooseBundled: { model.chooseBundledRoom(); sheet = nil },
                onApplyPicture: { choice, data, floor in
                    model.applyPicture(choice, imageData: data, floor: floor)
                    sheet = nil
                },
                onApplyBand: { floor in model.applyBand(floor); sheet = nil },
                onClose: { sheet = nil },
                start: Self.startsWithBandEditor ? .adjustingBand : .choosing)
        }
    }

    @ViewBuilder
    private func sheetContent(_ kind: StandbySheet) -> some View {
        switch kind {
        case .room: EmptyView()      // 全画面で出すので、ここには来ない
        case .dayPlan: titled(DayPlanListView(input: model.input), kind.title)
        case .settings:
            NavigationStack(path: $settingsPath) {
                settingsSummary.navigationTitle(kind.title).navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large], selection: $settingsDetent)
            .onAppear { model.reloadWidgetRecord() }
        }
    }

    /// 設定画面。ウィジェットの疑似アニメの入／切だけは、ここで書き換えられる（3-2b）。
    private var settingsSummary: some View {
        SettingsSummaryView(
            settings: model.state.settings, widget: model.state.widget,
            pseudoAnimation: Binding(get: { model.state.widget.usesPseudoAnimation },
                                     set: { model.setPseudoAnimation($0) }),
            widgetCapability: model.widgetCapability,
            // ウィジェットが作り直すたびに残した記録（3-2c）。記録は実時刻なので、時刻の早送りはかけない。
            widgetRecord: model.widgetRecord, now: Date(), calendar: model.input.calendar,
            weekRunStatus: WeekRunPlan.status(startedAt: model.weekRun.startedAt, now: Date(),
                                              calendar: model.input.calendar))
        .navigationDestination(for: SettingsRoute.self) { route in
            switch route {
            case .transparentBackground: TransparentBackgroundScreen(model: model)
            case .transparentAlignment: TransparentAlignmentScreen(model: model)
            case .placementGuide: PlacementGuideScreen(model: model)
            case .weekRun: WeekRunScreen(model: model)
            case .weekRunDay(let number): WeekRunDayScreen(model: model, number: number)
            }
        }
    }

    private func titled(_ view: some View, _ title: String) -> some View {
        NavigationStack {
            view.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

/// 同梱データが読めなかったときの画面。**落とさずに理由を出す。**
struct MissingAssetsView: View {

    let reason: String?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "questionmark.folder").font(.system(size: 44))
            Text("キャラクターのデータを読めませんでした")
                .font(.headline)
            if let reason {
                Text(reason)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Text("tools/pipeline を走らせて、同梱データを作り直してください。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }
}
