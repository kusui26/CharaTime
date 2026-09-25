import Testing
import SwiftUI
import CoreGraphics
@testable import CTRender

/// 透過背景をウィジェットに敷くかどうか（プラン §9 Phase 3 の 3-C ⑦、3-3）。
@Suite("透過背景の出し分け")
struct WidgetWallpaperTests {

    /// 塗りつぶした画像（中身は問わない。大きさだけを見る）。
    static func image(width: Int, height: Int) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    /// iPhone 17 Pro の大（ラベルあり）: 349.67 × 365.00pt、@3x で 1049 × 1095 画素（3-C ①）。
    static let largeSize = CGSize(width: 349.67, height: 365.00)
    static let largeCrop = image(width: 1049, height: 1095)
    static let wallpaper = WidgetWallpaper(light: largeCrop, dark: image(width: 1049, height: 1095))

    private func background(_ display: WidgetDisplay, _ wallpaper: WidgetWallpaper?,
                            scheme: ColorScheme = .light, size: CGSize = largeSize) -> WidgetBackground {
        WidgetBackground.choose(display: display, wallpaper: wallpaper, scheme: scheme, size: size, scale: 3)
    }

    @Test("ふつうのホーム画面で、大きさの合う切り抜きがあれば、部屋の代わりに敷く")
    func wallpaperReplacesTheRoom() {
        #expect(background(.homeScreen, Self.wallpaper) == .wallpaper(Self.largeCrop))
        #expect(background(.homeScreen, nil) == .room)
    }

    @Test("外観に合う切り抜きを選び、その外観の切り抜きが無ければ部屋に戻す")
    func followsTheAppearance() {
        let dark = Self.wallpaper.dark
        #expect(background(.homeScreen, Self.wallpaper, scheme: .dark) == dark.map(WidgetBackground.wallpaper))
        let lightOnly = WidgetWallpaper(light: Self.largeCrop, dark: nil)
        #expect(background(.homeScreen, lightOnly, scheme: .dark) == .room)
    }

    /// アイコンを大きく（ラベルなし）すると、大は 359.67 × 359.00pt になる。ラベルありの枠で
    /// 切り抜いた壁紙を敷くと、継ぎ目がずれて目立つ。
    @Test("切り抜きの大きさがウィジェットと合わなければ、部屋に戻す（1 画素までは合うとみなす）")
    func mismatchedCropFallsBackToTheRoom() {
        let labelFree = CGSize(width: 359.67, height: 359.00)
        #expect(background(.homeScreen, Self.wallpaper, size: labelFree) == .room)
        let roundedDown = WidgetWallpaper(light: Self.image(width: 1048, height: 1095), dark: nil)
        #expect(background(.homeScreen, roundedDown) == .wallpaper(roundedDown.light!))
        let tooNarrow = WidgetWallpaper(light: Self.image(width: 1047, height: 1095), dark: nil)
        #expect(background(.homeScreen, tooNarrow) == .room)
    }

    /// 着色・クリア・StandBy は OS が背景を外すので、壁紙を敷いても見えない（D-28）。
    @Test("背景を外す描き方では、切り抜きがあっても床の手がかりに戻る")
    func removedBackgroundKeepsTheFloorHint() {
        let tinted = WidgetDisplay(tone: .accented, showsBackground: false)
        #expect(background(tinted, Self.wallpaper) == .floorHint(fadesEdges: false))
        #expect(background(.standByDay, Self.wallpaper) == .floorHint(fadesEdges: true))
        #expect(background(.standByNight, Self.wallpaper) == .floorHint(fadesEdges: true))
    }

    /// 壁紙の明るさは分からない。字（z）を淡い色にし、影で縁取る。紐は描かない（`SceneLook.overWallpaper`）。
    @Test("壁紙を敷くときは、取り込んだ画像の上の配色にし、壁紙の上として描く")
    func inkOverTheWallpaper() {
        #expect(WidgetBackground.wallpaper(Self.largeCrop).palette(.day) == RoomPalette.day.overPicture())
        #expect(WidgetBackground.wallpaper(Self.largeCrop).isWallpaper)
        #expect(WidgetBackground.room.palette(.day) == .day)
        #expect(!WidgetBackground.room.isWallpaper)
        #expect(!WidgetBackground.floorHint(fadesEdges: true).isWallpaper)
    }
}
