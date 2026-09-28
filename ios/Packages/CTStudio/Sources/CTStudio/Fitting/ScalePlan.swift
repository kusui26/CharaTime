import Foundation

/// 画像ごとの倍率（プラン §9 Phase 2 の 2-C ⑤-4）。**倍率は画像ごとに 1 つ。画像どうしは立ち姿の背でつなぐ。**
///
/// 1. 立ち姿の外接矩形が、枠の高さ 93.05%・幅 79.81% に収まるいちばん大きい背を、本来の背とする
/// 2. どの画像のどのコマも、幅 95% に収まり、上端が枠からはみ出さないところまで、全体の背を縮める
///    （画像ごとに縮めると、画像をまたいで姿勢を送るたびに伸び縮みして見える）
/// 3. 画像ごとの倍率は、背 ÷ その画像の背の基準（立ち姿の高さ。歩く 4 コマは高さの中央値）
///
/// 2-0 では、目の間隔がどのポーズでも ±2% だったので、1 枚の中は 1 つの倍率で足りる。
struct ScalePlan: Equatable, Sendable {

    /// 1 枚の画像の、そろえる材料。
    struct Sheet: Equatable, Sendable {
        /// 背の基準（元の画素）。立ち姿の外接矩形の高さ。立ち姿が無い画像（歩く 4 コマ）は、コマの高さの中央値。
        let referenceHeight: Double
        /// この画像から枠に描くコマ（外したコマは入れない）。
        let figures: [FigureMetrics]

        init(referenceHeight: Double, figures: [FigureMetrics]) {
            self.referenceHeight = referenceHeight
            self.figures = figures
        }

        /// 立ち姿の無い画像。コマの高さの中央値を背の基準にする（歩く 4 コマは、背の差が 1% 以内だった。2-0）。
        init(medianOf figures: [FigureMetrics]) {
            self.init(referenceHeight: Self.medianHeight(of: figures), figures: figures)
        }

        /// 高さの中央値（偶数個なら真ん中の 2 つの平均）。無ければ 1。
        static func medianHeight(of figures: [FigureMetrics]) -> Double {
            let heights = figures.map(\.height).sorted()
            let middle = heights.count / 2
            guard !heights.isEmpty else { return 1 }
            guard heights.count.isMultiple(of: 2) else { return heights[middle] }
            return (heights[middle - 1] + heights[middle]) / 2
        }
    }

    /// 立ち姿の、枠の中での外接矩形の高さ（hero の画素）。どの画像もこの背にそろう。
    let standingHeight: Double
    /// 全コマを収めるために縮めた割合（1 なら縮めていない）。
    let shrink: Double

    /// `standing` は立ち姿（目を開けた正面）の寸法。`sheets` には立ち姿の画像も入れる。
    init(standing: FigureMetrics, sheets: [Sheet]) {
        let natural = standing.height * Self.standingScale(standing)
        let limit = sheets.map { Self.fittingScale($0.figures) * $0.referenceHeight }.min() ?? natural
        standingHeight = Swift.min(natural, limit)
        shrink = standingHeight / natural
    }

    /// その画像の倍率（元の画素 → hero の画素）。
    func scale(for sheet: Sheet) -> Double {
        standingHeight / sheet.referenceHeight
    }

    /// 全コマを収めるために 1 割以上縮めたか（横に広い姿勢がある）。
    var isCompacted: Bool { shrink < FrameGeometry.compactWarningRatio }

    /// 立ち姿が、枠の高さ 93.05%・幅 79.81% に収まるいちばん大きい倍率。
    static func standingScale(_ standing: FigureMetrics) -> Double {
        let frame = FrameGeometry.hero
        return Swift.min(Double(frame.height) * FrameGeometry.standingHeightShare / standing.height,
                         Double(frame.width) * FrameGeometry.standingWidthShare / standing.width)
    }

    /// どのコマも、枠の中央から左右それぞれ幅 95% の半分に収まり、上端が枠からはみ出さない倍率。
    /// 横は外接矩形の幅でなく、枠の中央に置く所（`anchorX`）からの長いほうで測る（しっぽが片側に出る子）。
    static func fittingScale(_ figures: [FigureMetrics]) -> Double {
        let frame = FrameGeometry.hero
        let halfWidth = Double(frame.width) * FrameGeometry.figureWidthShare / 2
        let headroom = FrameGeometry.outlineBottom(in: frame)
        return figures.map { figure in
            let reach = Swift.max(figure.anchorX - figure.left, figure.right - figure.anchorX)
            return Swift.min(halfWidth / reach, headroom / figure.height)
        }.min() ?? .infinity
    }
}
