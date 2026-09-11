import SwiftUI
import CTRender

/// アプリ本体は薄い殻に留める。中身は CTCore（決定論）・CTRender（描画）・
/// CTStore（共有状態）・CTAssets（同梱データ）が持つ（プラン §7.3）。
@main
struct CharaTimeApp: App {
    var body: some Scene {
        WindowGroup {
            // 面 0・待受モード。このアプリの核（プラン §4.3）。
            StandbyScreen()
        }
    }
}
