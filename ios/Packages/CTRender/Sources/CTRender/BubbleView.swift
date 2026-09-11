import SwiftUI
import CTCore

/// キャラの吹き出し。
///
/// キャラの頭の横に出し、**画面の外へはみ出しそうなら反対側へ寄せる**。
/// 待受モードは横幅が限られるので、端で切れると読めなくなる。
struct BubbleView: View {

    let bubble: Bubble
    let layout: SceneLayout
    let characterPosition: RoomPoint
    let characterHeight: Double
    let palette: RoomPalette

    /// 吹き出しの見た目。キャラの輪郭と同じ太さ・同じ色でつなげる。
    private static let cornerRadius: Double = 18
    private static let borderWidth: Double = 3.5
    private static let horizontalPadding: Double = 14
    private static let verticalPadding: Double = 9
    private static let fontSize: Double = 15
    /// しっぽの大きさ。
    private static let tailSize: Double = 11
    /// キャラの頭からどれだけ上に出すか（背の高さに対する比）。
    private static let riseRatio: Double = 0.72
    /// 画面の縁からこれ以上内側に置く。
    private static let screenMargin: Double = 16

    var body: some View {
        let anchor = layout.point(characterPosition)
        // キャラが画面の左半分にいれば吹き出しは右に出す。逆なら左。
        let onRight = characterPosition.x < 0.5
        HStack(spacing: 0) {
            // **しっぽはキャラの側に付ける。** 吹き出しが右にあるならしっぽは左端、
            // 左にあるなら右端。向きも合わせないと、あらぬ方を指してしまう。
            if onRight { tail(pointingRight: false) }
            label
            if !onRight { tail(pointingRight: true) }
        }
        .fixedSize()
        .position(x: bubbleX(anchor: anchor, onRight: onRight),
                  y: anchor.y - characterHeight * Self.riseRatio)
    }

    private var label: some View {
        Text(bubble.text)
            .font(.system(size: Self.fontSize, weight: .medium, design: .rounded))
            .foregroundStyle(palette.outline)
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.vertical, Self.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .fill(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: Self.cornerRadius)
                        .stroke(palette.outline, lineWidth: Self.borderWidth)))
    }

    /// 白い三角に輪郭を付けたしっぽ。角丸の縁に少し食い込ませて、継ぎ目を隠す。
    /// `Triangle` は左を指す形なので、右へ向けるときだけ裏返す。
    private func tail(pointingRight: Bool) -> some View {
        Triangle()
            .fill(Color.white)
            .overlay(Triangle().stroke(palette.outline, lineWidth: Self.borderWidth))
            .frame(width: Self.tailSize, height: Self.tailSize * 1.2)
            .scaleEffect(x: pointingRight ? -1 : 1)
            .offset(x: pointingRight ? -Self.borderWidth : Self.borderWidth)
            .zIndex(-1)
    }

    /// 吹き出しの中心。画面の外へ出ないように寄せる。
    private func bubbleX(anchor: CGPoint, onRight: Bool) -> Double {
        let offset = characterHeight * 0.42
        let center = onRight ? anchor.x + offset : anchor.x - offset
        let half = Self.screenMargin + Self.tailSize
        return Swift.min(Swift.max(center, half), layout.size.width - half)
    }
}

/// 吹き出しのしっぽ。左向きの三角。
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
