import SwiftUI
import CTRender

/// アプリ本体は薄い殻に留める。中身は CTCore（決定論）・CTRender（描画）・
/// CTStore（共有状態）・CTAssets（同梱データ）が持つ（プラン §7.3）。
@main
struct CharaTimeApp: App {
    var body: some Scene {
        WindowGroup {
            // Phase 1 で待受モードに置き換わる。いまは骨組みの自己診断だけ。
            SkeletonView()
        }
    }
}
