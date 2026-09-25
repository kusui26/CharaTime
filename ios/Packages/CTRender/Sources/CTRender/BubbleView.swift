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
    /// 地と字の塗り方。
    var paint: BubblePaint = .paper

    static let standby = BubbleStyle(fontSize: 15, horizontalPadding: 14, verticalPadding: 9,
                                     cornerRadius: 18, borderWidth: 3.5, tailSize: 11,
                                     edgeMargin: 16)

    /// ウィジェット。キャラが待受モードの半分ほどなので、吹き出しも小さくする。
    /// 字はホーム画面のアプリ名（約 12pt）と同じくらいにして、読める大きさを保つ。
    static let widget = BubbleStyle(fontSize: 12, horizontalPadding: 9, verticalPadding: 5,
                                    cornerRadius: 12, borderWidth: 2.5, tailSize: 8,
                                    edgeMargin: 6)

    /// 同じ形で、塗り方だけを替える。
    func painted(_ paint: BubblePaint) -> BubbleStyle {
        var style = self
        style.paint = paint
        return style
    }
}

/// 吹き出しの塗り方。ウィジェットの描き分けごとに、字が読める組み合わせが違う（3-C ⑨）。
enum BubblePaint: Sendable, Equatable {
    /// 白い地に濃い字と縁。ふつうのホーム画面と、StandBy の昼（黒の上）。
    case paper
    /// 地を薄くし、字と縁は濃いまま。着色・クリアは透明度だけが残るので、白い地のままだと
    /// 縁も字も地も同じ 1 色に塗られて字が消える（3-0 のスパイク F）。地が薄ければ字が浮く。
    case faint
    /// 地を黒で塗り、字と縁を淡い色にする。StandBy の夜（vibrant）は明るさだけが赤く残り、
    /// 濃い字は消える。白い地にすると、夜の部屋で明るい赤の板が光ってしまう。黒は闇になるので
    /// 地が無いように見え、後ろのもの（ミラーボール）を隠して字を読ませる。
    case glow

    init(_ tone: WidgetTone) {
        switch tone {
        case .fullColor: self = .paper
        case .accented: self = .faint
        case .vibrant: self = .glow
        }
    }
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
    /// 疑似アニメの窓で出し入れするときの材料（時報の 30 秒。3-C ③）。nil なら出したまま。
    var window: AnchoredWindow?

    /// 窓のマスクの一辺（ポイント）。吹き出し（字 6 字ほどと、しっぽ）がすっぽり入る大きさ。
    private static let windowCell: Double = 160

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
        .shown(during: window, cell: Self.windowCell)
        .position(x: bubbleX(anchor: anchor, onRight: onRight),
                  y: anchor.y - characterHeight * Self.riseRatio)
    }

    private var label: some View {
        Text(bubble.text)
            .font(.system(size: style.fontSize, weight: .medium, design: .rounded))
            .foregroundStyle(ink)
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: style.cornerRadius)
                        .stroke(border, lineWidth: style.borderWidth)))
    }

    /// 地の色を塗った三角に、斜めの 2 辺だけ輪郭を付けたしっぽ。角丸の縁に少し食い込ませて、
    /// 継ぎ目を隠す（付け根の辺は、吹き出しの縁と重なるので描かない）。
    /// `Triangle` は左を指す形なので、右へ向けるときだけ裏返す。
    private func tail(pointingRight: Bool) -> some View {
        Triangle()
            .fill(fill)
            .overlay(TailEdges().stroke(border, style: StrokeStyle(lineWidth: style.borderWidth,
                                                                   lineJoin: .round)))
            .frame(width: style.tailSize, height: style.tailSize * 1.2)
            .scaleEffect(x: pointingRight ? -1 : 1)
            .offset(x: pointingRight ? -style.borderWidth : style.borderWidth)
            .zIndex(-1)
    }

    // MARK: - 塗り方（`BubblePaint`）

    /// 着色・クリアで地に残す濃さ。字（濃さ 1）との差で読ませる。
    private static let faintFillOpacity: Double = 0.3
    /// 夜の赤で、縁を字より控えめにする濃さ。縁が字と同じ明るさだと、枠ばかりが目立つ。
    private static let glowBorderOpacity: Double = 0.6

    private var fill: Color {
        switch style.paint {
        case .paper: .white
        case .faint: .white.opacity(Self.faintFillOpacity)
        case .glow: .black
        }
    }

    /// 字の色。夜の赤では白（明るいところほど赤く残る）。
    private var ink: Color { style.paint == .glow ? .white : palette.outline }

    private var border: Color {
        style.paint == .glow ? .white.opacity(Self.glowBorderOpacity) : palette.outline
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

/// しっぽの輪郭。`Triangle` の斜めの 2 辺だけで、吹き出しに付く辺は描かない。
struct TailEdges: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}
