import SwiftUI
import CoreGraphics

/// 透過背景の材料（プラン §9 Phase 3 の 3-C ⑦、3-3）。壁紙のスクリーンショットを、このウィジェットの
/// 枠で切り抜いたもの。外観（ライト・ダーク）ごとに 1 枚。
///
/// ダークの外観では壁紙が約 2 割暗くなるので、外観ごとに撮った 1 枚を使い分ける（3-0c）。
public struct WidgetWallpaper: Sendable {

    public var light: CGImage?
    public var dark: CGImage?

    public init(light: CGImage?, dark: CGImage?) {
        self.light = light
        self.dark = dark
    }

    /// その外観の切り抜き。無ければ nil。
    public func image(for scheme: ColorScheme) -> CGImage? {
        scheme == .dark ? dark : light
    }

    /// 切り抜きが、その大きさのウィジェットにぴったり合うか。
    ///
    /// アイコンを大きく（ラベルなし）すると枠が変わり、別の機種で撮ったスクショなら画素の数から違う。
    /// 合わない壁紙を敷くと、透けて見えるどころか継ぎ目が目立つ。
    static func fits(_ image: CGImage, size: CGSize, scale: Double) -> Bool {
        abs(Double(image.width) - Double(size.width) * scale) <= fitTolerancePixels
            && abs(Double(image.height) - Double(size.height) * scale) <= fitTolerancePixels
    }

    /// 切り抜きとウィジェットの大きさ（画素）の許す差。表の値（349.67pt など）は小数 2 桁に丸めてあり、
    /// 画素に直すと 1 画素ずれうる（349.67 × 3 = 1049.01）。2 画素ずれたら別の枠とみなす。
    static let fitTolerancePixels: Double = 1.5
}

/// ウィジェットの背景の描き方。見え方と透過背景の材料から決める（3-C ⑦⑨）。
enum WidgetBackground: Equatable {
    /// 図形で描く部屋（壁・床・窓・敷物）。
    case room
    /// 壁紙の切り抜き（透過背景）。部屋の代わりに敷き、アイテムとキャラをその上に置く。
    case wallpaper(CGImage)
    /// OS が背景を外す描き方（着色・クリア・StandBy）での床の手がかり。
    case floorHint(fadesEdges: Bool)

    static func choose(display: WidgetDisplay, wallpaper: WidgetWallpaper?, scheme: ColorScheme,
                       size: CGSize, scale: Double) -> WidgetBackground {
        guard display.drawsRoom else { return .floorHint(fadesEdges: display.hasDarkBackdrop) }
        guard let image = wallpaper?.image(for: scheme),
              WidgetWallpaper.fits(image, size: size, scale: scale) else { return .room }
        return .wallpaper(image)
    }

    /// その背景の上で使う配色。壁紙の明るさは分からないので、取り込んだ画像の上の配色
    /// （字を淡い色に）にする。
    func palette(_ base: RoomPalette) -> RoomPalette {
        if case .wallpaper = self { return base.overPicture() }
        return base
    }

    /// 壁紙の上に描くか。字（z）に影を付け、吊るすアイテムの紐を描かない（`SceneLook.overWallpaper`）。
    var isWallpaper: Bool {
        if case .wallpaper = self { return true }
        return false
    }
}

/// 透過背景の切り抜きを、ウィジェットの枠いっぱいに敷く。
///
/// 切り抜きはウィジェットと同じ画素の数（`WidgetWallpaper.fits`）なので、ほぼ等倍で描かれる。
/// 夜でも暗くしない（本物の壁紙とそろわなくなる。待受モードの写真の部屋とは違う）。
struct WallpaperBackdrop: View {

    let image: CGImage
    /// 画面の倍率（@3x なら 3）。切り抜きの 1 画素を、画面の 1 画素に描く。
    let scale: Double

    var body: some View {
        Image(decorative: image, scale: scale)
            .resizable()
            .interpolation(.high)
    }
}
