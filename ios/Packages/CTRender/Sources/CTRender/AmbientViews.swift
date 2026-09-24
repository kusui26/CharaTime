import SwiftUI
import CTCore
import CTAssets

/// 疑似アニメで描くときの材料（プラン §9 Phase 3 の 3-C ④）。止めた 1 枚で描くときは無い。
struct AmbientLook: Sendable, Equatable {
    /// 動かし方。描画の段の速さまでに絞ってある（`AmbientCue.limited(to:)`）。
    let cue: AmbientCue
    /// タイマーの起点。エントリの日付の 0 時（D-18）。
    let anchor: Date

    /// 時報の吹き出しの窓。動かし方に吹き出しが無ければ nil（エントリのあいだずっと出す）。
    var clockBubbleWindow: TimerWindow? {
        cue.overlays.first { $0.layer == .clockBubble }?.window
    }

    /// 光の粒の窓（並びは粒の番号の順）。
    var sparkleWindows: [TimerWindow] {
        cue.overlays.compactMap { overlay in
            if case .sparkle = overlay.layer { return overlay.window }
            return nil
        }
    }
}

/// 疑似アニメで動くキャラ。土台のコマを描き、重ねるコマとまぶたを窓で出し入れする（D-17）。
///
/// 絵はどれもウィジェット用の小さい版（mini）で、止めた 1 枚と同じ枠に描く。段が変わっても
/// キャラの位置と大きさは変わらない。
struct AmbientCharacterView: View {

    let character: CTCore.Character
    let position: RoomPoint
    let cue: AmbientCue
    let layout: SceneLayout
    let anchor: Date

    var body: some View {
        let height = layout.characterHeight(at: position, characterScale: character.scale)
        let frame = layout.spriteFrame(footAt: position, height: height, liftRatio: 0)
        // マスクは一辺 cell の四角。絵の枠（縦長）をすっぽり覆うよう、長いほうの辺に合わせる。
        let cell = Swift.max(frame.width, frame.height)
        ZStack {
            if let base = cue.baseFrame { SpriteView(assetName: spriteName(frame: base)) }
            ForEach(Array(cue.overlays.enumerated()), id: \.offset) { _, overlay in
                if let name = assetName(for: overlay.layer) {
                    SpriteView(assetName: name).shown(during: overlay.window, anchor: anchor, cell: cell)
                }
            }
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
    }

    /// 重ねるものの絵。キャラの絵でないもの（吹き出し・光の粒）は、ほかの層が描く。
    private func assetName(for layer: AmbientLayer) -> String? {
        switch layer {
        case .eyelid: character.eyelids[cue.pose]
        case .frame(let index): spriteName(frame: index)
        case .clockBubble, .sparkle: nil
        }
    }

    private func spriteName(frame: Int) -> String {
        character.spriteName(for: SpritePick(pose: cue.pose, frame: frame, facing: .front, size: .mini))
    }
}

/// ミラーボールの光の粒の置き場所。ボールのまわりに、斜めに散らす。
///
/// **View の外に置く**（`ItemOrder` と同じ。View の静的な値は `@MainActor` に縛られる）。
enum SparkleLayout {

    /// 粒を置く向き（度。0 が右、時計回り）。上下左右に偏らないよう斜めに散らす。
    static let angles: [Double] = [-40, 50, 140, 220]
    /// ボールの中心からの距離（ボールの幅に対する比）。紐と重ならない外側に置く。
    static let radiusRatio: Double = 1.9
    /// 粒の大きさ（ボールの幅に対する比）。
    static let sizeRatio: Double = 0.6

    /// `index` 番目の粒の枠。
    static func frame(_ index: Int, around ball: CGRect) -> CGRect {
        let angle = angles[index % angles.count] * .pi / 180
        let radius = ball.width * radiusRatio
        let size = ball.width * sizeRatio
        let center = CGPoint(x: ball.midX + cos(angle) * radius, y: ball.midY + sin(angle) * radius)
        return CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
    }
}

/// ミラーボールの光の粒。4 つを 0.25 秒ずつずらした窓で出し入れし、1 秒に 4 回きらめかせる。
struct AmbientSparkles: View {

    let windows: [TimerWindow]
    let ball: CGRect
    let anchor: Date
    let palette: RoomPalette
    let unit: Double

    /// 粒の縁取りの太さ（基準のポイント）。昼の淡い壁でも粒が見えるように縁を描く。
    private static let outlineWidth: Double = 1.6

    var body: some View {
        ForEach(Array(windows.enumerated()), id: \.offset) { index, window in
            let frame = SparkleLayout.frame(index, around: ball)
            SparkleShape()
                .fill(palette.glow)
                .overlay(SparkleShape().stroke(palette.outline, lineWidth: Self.outlineWidth * unit))
                .frame(width: frame.width, height: frame.height)
                .shown(during: window, anchor: anchor, cell: frame.width)
                .position(x: frame.midX, y: frame.midY)
        }
    }
}

/// 四稜星のきらめき（待受モードの光点と同じ形）。
struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: center)
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: center)
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: center)
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: center)
        return path
    }
}
