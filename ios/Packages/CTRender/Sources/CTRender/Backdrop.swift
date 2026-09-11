import SwiftUI
import CoreGraphics
import CTCore

/// 背景の出どころ（プラン §4.4 の「部屋 3 系統」）。
///
/// 同梱の部屋は図形で描き、写真とホーム画面のスクリーンショットは取り込んだ画像を敷く。
/// **どれを選んでもキャラの動きは変わらない。** 変わるのは背景と、歩ける帯の位置だけ。
public enum RoomBackdrop: Sendable {

    /// SwiftUI の図形で描く同梱の部屋。
    case drawn(showsWindow: Bool = true)
    /// 取り込んだ写真、またはホーム画面のスクリーンショット。
    case picture(CGImage)

    /// 取り込んだ画像を敷いているか。
    ///
    /// 図形で描く部屋なら明るさが分かっているが、画像は何が来るか分からない。
    /// 敷物を敷くか、時計に覆いを敷くかの判断に使う。
    public var isPicture: Bool {
        if case .picture = self { return true }
        return false
    }
}

/// 背景を 1 枚描く。
struct BackdropView: View {

    let backdrop: RoomBackdrop
    let floor: RoomRect
    let palette: RoomPalette
    let isNight: Bool

    var body: some View {
        switch backdrop {
        case .drawn(let showsWindow):
            RoomView(floor: floor, palette: palette, showsWindow: showsWindow,
                     showsRug: true, isNight: isNight)
        case .picture(let image):
            PictureBackdrop(image: image, isNight: isNight)
        }
    }
}

/// 取り込んだ画像の背景。
///
/// 画面いっぱいに敷いて、はみ出したぶんは切り落とす。ホーム画面のスクリーンショットなら
/// 縦横比がぴったり合うので切れないが、写真は切れるのが自然。
struct PictureBackdrop: View {

    let image: CGImage
    let isNight: Bool

    /// 夜に画像を暗くする量。
    ///
    /// 写真はそのままだと夜の部屋でまぶしく、輪郭の濃いキャラも背景に埋もれる。
    /// 図形で描く部屋が夜の配色に入れ替わるのと同じ役目を、覆いで果たす。
    static let nightDimming: Double = 0.42

    var body: some View {
        GeometryReader { geometry in
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .overlay(Color.black.opacity(isNight ? Self.nightDimming : 0))
        }
        .ignoresSafeArea()
    }
}
