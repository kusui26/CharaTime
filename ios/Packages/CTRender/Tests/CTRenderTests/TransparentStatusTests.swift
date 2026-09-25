import Testing
import CTStore
@testable import CTRender

/// 設定画面の「透過背景」の行に出す、いまの様子（プラン §9 Phase 3 の 3-3）。
@Suite("透過背景の様子")
struct TransparentStatusTests {

    private func label(light: String? = nil, dark: String? = nil) -> String {
        TransparentStatus.label(WidgetSettings(wallpaper: AppearanceImages(light: light, dark: dark)))
    }

    @Test("取り込んだ外観を見せる。何も無ければ「使っていない」")
    func labels() {
        #expect(label() == "使っていない")
        #expect(label(light: "l") == "ライトだけ")
        #expect(label(dark: "d") == "ダークだけ")
        #expect(label(light: "l", dark: "d") == "ライト・ダーク")
    }
}
