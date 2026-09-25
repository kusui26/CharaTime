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

    /// 寝ている「z」の窓（z の番号 → 窓）。1 つ目（0 番）は出したままなので入っていない。
    var sleepMarkWindows: [Int: TimerWindow] {
        Dictionary(cue.overlays.compactMap { overlay -> (Int, TimerWindow)? in
            if case .sleepMark(let index) = overlay.layer { return (index, overlay.window) }
            return nil
        }, uniquingKeysWith: { first, _ in first })
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
        case .clockBubble, .sparkle, .sleepMark: nil
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

/// 寝ているときの「z」（2026-09-25）。待受モードで浮かんでいく道筋の 3 か所に置き、1 つ目は
/// 出したまま、2 つ目・3 つ目を窓で出し入れする（5 秒ごとに z → zz → zzz）。
///
/// 窓が外されていれば（タイマーの上限）、その z は出したままにする。止めた 1 枚と同じ 3 つが見える。
struct AmbientSleepMarks: View {

    let windows: [Int: TimerWindow]
    let anchor: Date
    /// キャラの足元（画面の座標）。
    let origin: CGPoint
    let height: Double
    let ink: Color
    /// 字に影を付けるか（透過背景の壁紙の上。`InkShadow`）。
    var shadowsInk = false

    /// 窓のマスクの一辺（字の大きさに対する比）。字がすっぽり入る大きさ。
    private static let cellRatio: Double = 1.6

    var body: some View {
        ForEach(0..<SleepMarkLayout.count, id: \.self) { index in
            let spot = SleepMarkLayout.mark(phase: SleepMarkLayout.widgetPhase(index), origin: origin,
                                            height: height)
            let cell = spot.fontSize * Self.cellRatio
            Text(SleepMarkLayout.text)
                .font(.system(size: spot.fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(ink.opacity(spot.opacity))
                .shadow(color: shadowsInk ? InkShadow.color : .clear, radius: InkShadow.radiusPoints)
                .frame(width: cell, height: cell)
                .shown(during: windows[index].map { AnchoredWindow(window: $0, anchor: anchor) }, cell: cell)
                .position(spot.center)
        }
        .accessibilityHidden(true)
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
