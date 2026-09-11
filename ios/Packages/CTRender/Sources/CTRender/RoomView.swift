import SwiftUI
import CTCore

/// 部屋の背景（壁・床・幅木・窓）。
///
/// **Phase 1 は SwiftUI の図形で描く。** 同梱イラストは Phase 2 で生成 AI が作るが、
/// それまで待つと待受モードの動きを確かめられない。図形で描いておけば、
/// どの画面の大きさにも歪みなく合い、ウィジェットの小さな枠でもそのまま使える。
///
/// 壁と床の境目は床の矩形の上辺に置く。**日課エンジンはキャラを床の矩形の中しか
/// 歩かせない**ので、こうすると「壁の中を歩く」ことが起こり得ない。
struct RoomView: View {

    let floor: RoomRect
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

    /// 幅木の高さ（画面の高さに対する比）。
    private static let baseboardRatio: Double = 0.009
    /// 壁と床の境の線の太さ。
    private static let horizonLineRatio: Double = 0.005
    /// 床の手前側を濃くし始める位置（床の高さに対する比）。
    private static let nearFloorStart: Double = 0.55
    private static let nearFloorOpacity: Double = 0.55

    var body: some View {
        Canvas { context, size in
            let horizon = size.height * floor.minY
            draw(&context, size: size, horizon: horizon)
        }
        .overlay(alignment: .topLeading) {
            if showsWindow { WindowView(palette: palette, isNight: isNight) }
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

        let baseboard = size.height * Self.baseboardRatio
        context.fill(Path(CGRect(x: 0, y: horizon - baseboard, width: width, height: baseboard)),
                     with: .color(palette.baseboard))
        let line = size.height * Self.horizonLineRatio
        context.fill(Path(CGRect(x: 0, y: horizon - line / 2, width: width, height: line)),
                     with: .color(palette.outline))
        if showsRug { drawRug(&context, size: size, lineWidth: line) }
    }

    /// 敷物。床の真ん中に置いて、キャラの居場所を絵として示す。
    private func drawRug(_ context: inout GraphicsContext, size: CGSize, lineWidth: Double) {
        let center = floor.at(Self.rugCenter.x, Self.rugCenter.y)
        let rugWidth = floor.width * size.width * Self.rugWidthRatio
        let rugHeight = rugWidth * Self.rugFlatness
        let rect = CGRect(x: center.x * size.width - rugWidth / 2,
                          y: center.y * size.height - rugHeight / 2,
                          width: rugWidth, height: rugHeight)
        context.fill(Path(ellipseIn: rect), with: .color(palette.rug))
        context.stroke(Path(ellipseIn: rect), with: .color(palette.outline), lineWidth: lineWidth)
        context.fill(Path(ellipseIn: rect.insetBy(dx: rugWidth * 0.19, dy: rugHeight * 0.21)),
                     with: .color(palette.rugInner))
    }
}

/// 壁の窓。夜は月と星、昼は雲が見える。
struct WindowView: View {

    let palette: RoomPalette
    /// 夜は月と星、昼は白い雲。
    var isNight: Bool = true

    /// 窓の位置と大きさ（画面に対する比）。時計の下、キャラの上に来るように置く。
    private static let frame = RoomRect(x: 0.067, y: 0.339, width: 0.287, height: 0.149)
    private static let cornerRatio: Double = 0.08
    private static let strokeRatio: Double = 0.013

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let rect = CGRect(x: Self.frame.x * size.width, y: Self.frame.y * size.height,
                              width: Self.frame.width * size.width,
                              height: Self.frame.height * size.height)
            Canvas { context, _ in draw(&context, in: rect) }
        }
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
        for star in Self.stars {
            let point = CGPoint(x: rect.minX + rect.width * star.x,
                                y: rect.minY + rect.height * star.y)
            context.fill(Path(ellipseIn: CGRect(x: point.x - 1.4, y: point.y - 1.4,
                                                width: 2.8, height: 2.8)),
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
