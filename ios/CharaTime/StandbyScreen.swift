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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let world = model.world {
                StandbyView(input: model.input, world: world,
                            settings: model.state.settings, battery: model.battery,
                            timeWarp: model.timeWarp)
            } else {
                MissingAssetsView(reason: model.loadFailure)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, phase in model.scenePhaseChanged(to: phase) }
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
