import SwiftUI
import CTCore

/// 部屋に作り付けのもの（部屋を決めた画面に対する比）。
///
/// **View の外に置く。** SwiftUI の `View` は `@MainActor` なので、その静的な値を
/// 置き方の計算やテストから読むと、隔離の検査に引っかかる（`ItemOrder` と同じ教訓）。
enum RoomFixture {
    /// 窓。時計の下、キャラの上に来るように置く。
    static let window = RoomRect(x: 0.067, y: 0.339, width: 0.287, height: 0.149)
}

/// 部屋の背景（壁・床・幅木・窓）。
///
/// **Phase 1 は SwiftUI の図形で描く。** 同梱イラストは Phase 2 で生成 AI が作るが、
/// それまで待つと待受モードの動きを確かめられない。図形で描いておけば、
/// どの画面の大きさにも歪みなく合い、ウィジェットの小さな枠でもそのまま使える。
///
/// 壁と床の境目は床の矩形の上辺に置く。**日課エンジンはキャラを床の矩形の中しか
/// 歩かせない**ので、こうすると「壁の中を歩く」ことが起こり得ない。
///
/// 位置は `SceneLayout` の写し方で、窓や敷物の大きさと線の太さは舞台（`stage`）で決める。
/// 待受モードでは画面そのもの、ウィジェットでは大きさごとの写し方になる（3-C ⑥）。
struct RoomView: View {

    let layout: SceneLayout
    let palette: RoomPalette
    /// 窓を描くか。ウィジェットの小さな枠では省く。
    var showsWindow: Bool = true
    /// 敷物を描くか。写真やホーム画面のスクショを背景にするときは描かない。
    var showsRug: Bool = true
    /// 夜か。窓の外が月と星になる。
    var isNight: Bool = true

    /// 敷物の大きさと位置（床の矩形に対する比）。
    private static let rugCenter = RoomPoint(x: 0.62, y: 0.78)
    private static let rugWidthRatio: Double = 0.62
    private static let rugFlatness: Double = 0.32

    /// 幅木の高さ（舞台の高さに対する比）。
    private static let baseboardRatio: Double = 0.009
    /// 壁と床の境の線の太さ。
    private static let horizonLineRatio: Double = 0.005
    /// 床の手前側を濃くし始める位置（床の高さに対する比）。
    private static let nearFloorStart: Double = 0.55
    private static let nearFloorOpacity: Double = 0.55

    var body: some View {
        Canvas { context, size in
            draw(&context, size: size, horizon: layout.horizonY)
        }
        .overlay {
            if showsWindow {
                WindowView(rect: layout.fixtureFrame(RoomFixture.window), unit: layout.unit,
                           palette: palette, isNight: isNight)
            }
        }
        .ignoresSafeArea()
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, horizon: Double) {
        let width = size.width
        context.fill(Path(CGRect(x: 0, y: 0, width: width, height: horizon)),
                     with: .color(palette.wall))
        context.fill(Path(CGRect(x: 0, y: horizon, width: width, height: size.height - horizon)),
                     with: .color(palette.floor))

        // 手前の床を濃くして、奥行きを出す。
        let nearTop = horizon + (size.height - horizon) * Self.nearFloorStart
        context.opacity = Self.nearFloorOpacity
        context.fill(Path(CGRect(x: 0, y: nearTop, width: width, height: size.height - nearTop)),
                     with: .color(palette.floorNear))
        context.opacity = 1

        let baseboard = layout.stage.height * Self.baseboardRatio
        context.fill(Path(CGRect(x: 0, y: horizon - baseboard, width: width, height: baseboard)),
                     with: .color(palette.baseboard))
        let line = layout.stage.height * Self.horizonLineRatio
        context.fill(Path(CGRect(x: 0, y: horizon - line / 2, width: width, height: line)),
                     with: .color(palette.outline))
        if showsRug { drawRug(&context, lineWidth: line) }
    }

    /// 敷物。床の真ん中に置いて、キャラの居場所を絵として示す。
    private func drawRug(_ context: inout GraphicsContext, lineWidth: Double) {
        let floor = layout.room.floor
        let center = layout.point(floor.at(Self.rugCenter.x, Self.rugCenter.y))
        let rugWidth = floor.width * layout.stage.width * Self.rugWidthRatio
        let rugHeight = rugWidth * Self.rugFlatness
        let rect = CGRect(x: center.x - rugWidth / 2, y: center.y - rugHeight / 2,
                          width: rugWidth, height: rugHeight)
        context.fill(Path(ellipseIn: rect), with: .color(palette.rug))
        context.stroke(Path(ellipseIn: rect), with: .color(palette.outline), lineWidth: lineWidth)
        context.fill(Path(ellipseIn: rect.insetBy(dx: rugWidth * 0.19, dy: rugHeight * 0.21)),
                     with: .color(palette.rugInner))
    }
}

/// 壁の窓。夜は月と星、昼は雲が見える。
struct WindowView: View {

    /// 窓の枠（ポイント）。
    let rect: CGRect
    /// 基準の 1pt が何 pt か。星の大きさに使う。
    let unit: Double
    let palette: RoomPalette
    /// 夜は月と星、昼は白い雲。
    var isNight: Bool = true

    private static let cornerRatio: Double = 0.08
    private static let strokeRatio: Double = 0.013
    /// 星の直径（基準のポイント）。
    private static let starDiameter: Double = 2.8

    var body: some View {
        Canvas { context, _ in draw(&context, in: rect) }
    }

    private func draw(_ context: inout GraphicsContext, in rect: CGRect) {
        let corner = rect.width * Self.cornerRatio
        let stroke = rect.width * Self.strokeRatio
        let pane = Path(roundedRect: rect, cornerRadius: corner)
        context.fill(pane, with: .color(palette.sky))

        if isNight { drawNightSky(&context, in: rect) } else { drawDaySky(&context, in: rect) }

        // 桟と枠。
        let mullion = CGRect(x: rect.minX, y: rect.midY - stroke / 2,
                             width: rect.width, height: stroke)
        context.fill(Path(mullion), with: .color(palette.outline))
        context.stroke(pane, with: .color(palette.outline), lineWidth: stroke)
    }

    /// 月と星。
    private func drawNightSky(_ context: inout GraphicsContext, in rect: CGRect) {
        let moon = CGRect(x: rect.minX + rect.width * 0.55, y: rect.minY + rect.height * 0.14,
                          width: rect.width * 0.28, height: rect.width * 0.28)
        context.fill(Path(ellipseIn: moon), with: .color(palette.glow))
        let diameter = Self.starDiameter * unit
        for star in Self.stars {
            let point = CGPoint(x: rect.minX + rect.width * star.x,
                                y: rect.minY + rect.height * star.y)
            context.fill(Path(ellipseIn: CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2,
                                                width: diameter, height: diameter)),
                         with: .color(palette.glow.opacity(0.75)))
        }
    }

    /// 白い雲。
    private func drawDaySky(_ context: inout GraphicsContext, in rect: CGRect) {
        for puff in Self.clouds {
            let width = rect.width * puff.width
            let center = CGPoint(x: rect.minX + rect.width * puff.x,
                                 y: rect.minY + rect.height * puff.y)
            context.fill(Path(ellipseIn: CGRect(x: center.x - width / 2,
                                                y: center.y - width * 0.34,
                                                width: width, height: width * 0.68)),
                         with: .color(.white.opacity(0.88)))
        }
    }

    private static let clouds: [RoomRect] = [
        RoomRect(x: 0.36, y: 0.24, width: 0.44, height: 0),
        RoomRect(x: 0.56, y: 0.28, width: 0.32, height: 0),
        RoomRect(x: 0.30, y: 0.66, width: 0.26, height: 0),
    ]

    private static let stars: [RoomPoint] = [
        RoomPoint(x: 0.20, y: 0.62), RoomPoint(x: 0.38, y: 0.30),
        RoomPoint(x: 0.30, y: 0.82), RoomPoint(x: 0.72, y: 0.70)
    ]
}
