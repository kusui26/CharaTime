import SwiftUI
import CTCore

/// 吹き出しの見た目。待受モードとウィジェットで、字の大きさが違う。
struct BubbleStyle: Sendable, Equatable {
    var fontSize: Double
    var horizontalPadding: Double
    var verticalPadding: Double
    var cornerRadius: Double
    /// 縁取りの太さ。キャラの輪郭と同じ太さ・同じ色でつなげる。
    var borderWidth: Double
    /// しっぽの大きさ。
    var tailSize: Double
    /// 枠の縁からこれ以上内側に置く。
    var edgeMargin: Double
    /// 地の白の濃さ（0〜1）。
    var fillOpacity: Double

    static let standby = BubbleStyle(fontSize: 15, horizontalPadding: 14, verticalPadding: 9,
                                     cornerRadius: 18, borderWidth: 3.5, tailSize: 11,
                                     edgeMargin: 16, fillOpacity: 1)

    /// ウィジェット。キャラが待受モードの半分ほどなので、吹き出しも小さくする。
    /// 字はホーム画面のアプリ名（約 12pt）と同じくらいにして、読める大きさを保つ。
    static let widget = BubbleStyle(fontSize: 12, horizontalPadding: 9, verticalPadding: 5,
                                    cornerRadius: 12, borderWidth: 2.5, tailSize: 8,
                                    edgeMargin: 6, fillOpacity: 1)

    /// 着色・クリアの外観で読ませる形。
    ///
    /// その外観では色の違いが消え、濃さの違いだけが残る（3-0 のスパイク F）。白い地のままだと
    /// 縁も字も地も同じ 1 色の塗りになって字が消えるので、地だけを薄くする。
    func tinted() -> BubbleStyle {
        var style = self
        style.fillOpacity = Self.tintedFillOpacity
        return style
    }

    private static let tintedFillOpacity: Double = 0.3
}

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
    var style: BubbleStyle = .standby

    /// キャラの足元からどれだけ上に出すか（背の高さに対する比）。頭の横に来る。
    private static let riseRatio: Double = 0.72
    /// キャラの中心からどれだけ横に出すか（背の高さに対する比）。
    private static let sideRatio: Double = 0.42

    var body: some View {
        let anchor = layout.point(characterPosition)
        // キャラが画面の左半分にいれば吹き出しは右に出す。逆なら左。
        let onRight = anchor.x < layout.size.width / 2
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
            .font(.system(size: style.fontSize, weight: .medium, design: .rounded))
            .foregroundStyle(palette.outline)
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(Color.white.opacity(style.fillOpacity))
                    .overlay(RoundedRectangle(cornerRadius: style.cornerRadius)
                        .stroke(palette.outline, lineWidth: style.borderWidth)))
    }

    /// 白い三角に輪郭を付けたしっぽ。角丸の縁に少し食い込ませて、継ぎ目を隠す。
    /// `Triangle` は左を指す形なので、右へ向けるときだけ裏返す。
    private func tail(pointingRight: Bool) -> some View {
        Triangle()
            .fill(Color.white.opacity(style.fillOpacity))
            .overlay(Triangle().stroke(palette.outline, lineWidth: style.borderWidth))
            .frame(width: style.tailSize, height: style.tailSize * 1.2)
            .scaleEffect(x: pointingRight ? -1 : 1)
            .offset(x: pointingRight ? -style.borderWidth : style.borderWidth)
            .zIndex(-1)
    }

    /// 吹き出しの中心。画面の外へ出ないように寄せる。
    private func bubbleX(anchor: CGPoint, onRight: Bool) -> Double {
        let offset = characterHeight * Self.sideRatio
        let center = onRight ? anchor.x + offset : anchor.x - offset
        let half = style.edgeMargin + style.tailSize
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
