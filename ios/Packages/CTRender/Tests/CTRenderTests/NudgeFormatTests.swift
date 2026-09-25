import Testing
import CTStore
@testable import CTRender

/// 透過背景の枠を寄せた量の見せ方（プラン §9 Phase 3 の 3-3）。
@Suite("枠を寄せた量の見せ方")
struct NudgeFormatTests {

    @Test("向きと画素の数で見せる。寄せていなければ、そう書く")
    func texts() {
        #expect(NudgeFormat.text(.zero) == "寄せていません")
        #expect(NudgeFormat.text(PixelOffset(dx: 2, dy: 0)) == "右に 2")
        #expect(NudgeFormat.text(PixelOffset(dx: -1, dy: 3)) == "左に 1・下に 3")
        #expect(NudgeFormat.text(PixelOffset(dx: 0, dy: -4)) == "上に 4")
    }
}
