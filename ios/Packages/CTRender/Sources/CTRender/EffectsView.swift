import SwiftUI
import CTCore
import CTAssets

/// 部屋の演出（ミラーボールの光点・キラキラ、眠っているときの「z」、踊るときの音符）。
///
/// **すべて時刻の関数で描く。** 待受モードは毎フレーム、ウィジェットは 1 枚だけ
/// 描くが、同じ時刻なら同じ絵になる。
struct EffectsView: View {

    let state: SceneState
    let room: Room
    let layout: SceneLayout
    let definitions: [ItemKind: ItemDefinition]
    let palette: RoomPalette
    /// 演出の位相に使う秒数。区切りの中の経過秒ではなく、連続した時刻を使う。
    let seconds: Double
    /// ミラーボールの光点を描くか。
    ///
    /// ウィジェットでは描かない（3-C ⑥）。止めた 1 枚では回らない光点がただの点になり、
    /// 動かすのは疑似アニメのタイマーの役目（3-2b の光の粒）。「z」や音符は止まっていても
    /// 寝ている・おどっていると読めるので、ウィジェットでも描く。
    var showsSparkles: Bool = true

    /// 光点の数と、1 周にかける秒数。
    private static let sparkleCount = 9
    private static let sparkleTurnSeconds: Double = 14
    private static let sparkleRadiusRatio: Double = 3.4
    /// 「z」が浮かんでいく周期。
    private static let sleepDriftSeconds: Double = 3.2
    /// 音符が浮かんでいく周期。
    private static let noteDriftSeconds: Double = 2.4

    /// ミラーボールのまわりのほのかな光。
    private static let glowRadiusRatio: Double = 2.6

    var body: some View {
        Canvas { context, size in
            drawBallGlow(&context)
            if isDancing {
                if showsSparkles { drawSparkles(&context, size: size) }
                drawNotes(&context)
            }
            if isAsleep { drawSleepMarks(&context) }
        }
        .allowsHitTesting(false)
    }

    /// ミラーボールはいつでもほのかに光っている。踊っているときだけ光点が回る。
    private func drawBallGlow(_ context: inout GraphicsContext) {
        guard let frame = mirrorBallFrame else { return }
        let radius = frame.width * Self.glowRadiusRatio / 2
        let circle = CGRect(x: frame.midX - radius, y: frame.midY - radius,
                            width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: circle),
                     with: .radialGradient(
                        Gradient(colors: [palette.glow.opacity(isDancing ? 0.30 : 0.16),
                                          palette.glow.opacity(0)]),
                        center: CGPoint(x: frame.midX, y: frame.midY),
                        startRadius: 0, endRadius: radius))
    }

    private var mirrorBallFrame: CGRect? {
        guard let ball = room.items.first(where: { $0.kind == .mirrorBall }),
              let definition = definitions[.mirrorBall] else { return nil }
        return layout.itemFrame(ball, definition: definition)
    }

    private var isAsleep: Bool { state.activity.isAsleep }

    private var isDancing: Bool {
        if case .dance = state.activity { return true }
        return false
    }

    /// ミラーボールのまわりを回る光点。回転は時刻の関数なので巻き戻らない。
    private func drawSparkles(_ context: inout GraphicsContext, size: CGSize) {
        guard let frame = mirrorBallFrame else { return }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let radius = frame.width * Self.sparkleRadiusRatio / 2
        let turn = seconds / Self.sparkleTurnSeconds * 2 * .pi
        for index in 0..<Self.sparkleCount {
            let angle = turn + Double(index) / Double(Self.sparkleCount) * 2 * .pi
            let wobble = 0.7 + 0.3 * sin(seconds * 1.7 + Double(index))
            let point = CGPoint(x: center.x + cos(angle) * radius * wobble,
                                y: center.y + sin(angle) * radius * 0.72 * wobble)
            drawSparkle(&context, at: point, size: frame.width * 0.11 * wobble)
        }
    }

    /// 四稜星のきらめき。
    private func drawSparkle(_ context: inout GraphicsContext, at point: CGPoint, size: Double) {
        var path = Path()
        path.move(to: CGPoint(x: point.x, y: point.y - size))
        path.addQuadCurve(to: CGPoint(x: point.x + size, y: point.y), control: point)
        path.addQuadCurve(to: CGPoint(x: point.x, y: point.y + size), control: point)
        path.addQuadCurve(to: CGPoint(x: point.x - size, y: point.y), control: point)
        path.addQuadCurve(to: CGPoint(x: point.x, y: point.y - size), control: point)
        context.fill(path, with: .color(palette.glow.opacity(0.9)))
    }

    /// 眠っているときの「z」。3 つが順に浮かんで消える。
    private func drawSleepMarks(_ context: inout GraphicsContext) {
        let height = layout.characterHeight(at: state.position, characterScale: 1)
        let origin = layout.point(state.position)
        for index in 0..<3 {
            let phase = (seconds / Self.sleepDriftSeconds + Double(index) / 3)
                .truncatingRemainder(dividingBy: 1)
            let mark = FloatingMark(text: "z", size: height * (0.14 + 0.05 * phase),
                                    color: palette.clockInk.opacity((1 - phase) * 0.8))
            draw(&context, mark,
                 at: CGPoint(x: origin.x + height * (0.22 + 0.20 * phase),
                             y: origin.y - height * (0.40 + 0.42 * phase)))
        }
    }

    /// 踊っているときの音符。
    private func drawNotes(_ context: inout GraphicsContext) {
        let height = layout.characterHeight(at: state.position, characterScale: 1)
        let origin = layout.point(state.position)
        for index in 0..<2 {
            let phase = (seconds / Self.noteDriftSeconds + Double(index) / 2)
                .truncatingRemainder(dividingBy: 1)
            let side: Double = index == 0 ? -1 : 1
            let mark = FloatingMark(text: "♪", size: height * 0.16,
                                    color: palette.glow.opacity((1 - phase) * 0.95))
            draw(&context, mark,
                 at: CGPoint(x: origin.x + side * height * (0.30 + 0.12 * phase),
                             y: origin.y - height * (0.70 + 0.40 * phase)))
        }
    }

    /// Canvas に文字を描く。
    ///
    /// **色は `shading` で指定する。** `Text` に付けた `foregroundStyle` は
    /// `GraphicsContext.resolve(_:)` を通ると効かず、既定の色（黒に近い灰）で出てしまう。
    private func draw(_ context: inout GraphicsContext, _ mark: FloatingMark, at point: CGPoint) {
        var resolved = context.resolve(
            Text(mark.text).font(.system(size: mark.size, weight: .bold, design: .rounded)))
        resolved.shading = .color(mark.color)
        context.draw(resolved, at: point)
    }
}

/// 浮かんでいく文字（「z」と音符）。
private struct FloatingMark {
    let text: String
    let size: Double
    let color: Color
}
