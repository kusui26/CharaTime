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

    var body: some View {
        Group {
            if let world = model.world {
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
        case .settings: titled(SettingsSummaryView(settings: model.state.settings), kind.title)
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
