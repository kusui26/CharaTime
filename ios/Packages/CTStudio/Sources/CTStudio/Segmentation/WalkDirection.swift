import Foundation

/// 歩く 4 コマの向き（プラン §9 Phase 2 の 2-C ⑤-7）。**左向きにそろえる**（右向きの絵は左右を反転する）。
///
/// 横向きの絵では、目は向いている側にある（いまの 5 体の歩きは、どれも目が体の上 6 割の中心より左）。コマごとに目の
/// 側を見て、多いほうを画像の向きとする。目が見つからないコマは数えない。1 つも決められなければ、そのまま使う。
enum WalkDirection {

    /// 右を向いているか。決められなければ false。
    static func facesRight(_ figures: [Figure]) -> Bool {
        let votes = figures.compactMap(facesRight)
        return votes.filter { $0 }.count * 2 > votes.count
    }

    /// 1 コマが右を向いているか。目が見つからなければ nil。
    static func facesRight(_ figure: Figure) -> Bool? {
        guard let metrics = FigureMetrics(figure.image) else { return nil }
        let eyes = EyeFinder.candidates(in: FaceScan(figure.image), figure: metrics)
        guard let eye = eyes.max(by: { $0.pixels.count < $1.pixels.count }) else { return nil }
        return eye.box.centerX > metrics.anchorX
    }
}
