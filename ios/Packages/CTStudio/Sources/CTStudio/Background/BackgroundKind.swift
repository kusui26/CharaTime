import Foundation

/// 背景の外し方（プラン §9 Phase 2 の 2-C ⑤-2、D-36）。縁の帯だけを見て決める。
///
/// 判定の順: 透明 → 1 色の地 → 2 色の市松模様（Gemini が「透明」を描いたもの）→ それ以外（Vision に回す）。
enum BackgroundKind: Equatable, Sendable {
    case transparent
    case solid(RGBColor)
    case checkerboard(RGBColor, RGBColor)
    case complex

    /// 縁の帯のうち、これだけの割合が透明なら「透明の地」（2-C ⑤-2）。
    static let transparentBorderShare: Float = 0.9
    /// 縁の帯のうち、これだけの割合が地の色の近くなら「1 色の地」（2-C ⑤-2。調査 H §2 の一様さ 0.9）。
    static let uniformBorderShare: Float = 0.9
    /// 地の色の「近く」とみなす色の距離（H §2 の実測で、白・緑の地の一様さが 1.000 になった値）。
    static let nearDistance: Float = 0.10
    /// 市松の 2 色は、それぞれ帯のこれだけを占める（片方だけなら 1 色の地）。
    static let checkerColorShare: Float = 0.2
    /// 市松の 2 色が、これより近ければ同じ色とみなす。
    static let checkerSeparation: Float = 0.05
    /// 2 色に分けるときの繰り返しの回数（縁の帯の色は 2 つの塊にはっきり分かれるので、数回で落ち着く）。
    static let clusteringRounds = 6

    /// 縁の帯から、背景の外し方を決める。
    static func classify(_ band: BorderBand) -> BackgroundKind {
        let clearShare = band.transparentShare(clearBelow: AlphaSnap.clearBelow)
        if clearShare >= transparentBorderShare { return .transparent }
        guard let key = band.medianColor(visibleFrom: AlphaSnap.solidFrom) else { return .complex }
        if band.share(near: [key], within: nearDistance) >= uniformBorderShare { return .solid(key) }
        return checkerboard(in: band, startingFrom: key) ?? .complex
    }

    /// 市松模様の 2 色。縁の帯の色を 2 つに分け、両方で帯のほとんどを覆い、どちらも十分にあれば市松とみなす。
    static func checkerboard(in band: BorderBand, startingFrom first: RGBColor) -> BackgroundKind? {
        let colors = zip(band.colors, band.alphas).filter { $0.1 >= AlphaSnap.solidFrom }.map(\.0)
        let farthest = colors.max { $0.distance(to: first) < $1.distance(to: first) }
        guard let farthest else { return nil }
        let (one, two) = (0..<clusteringRounds).reduce((first, farthest)) { centers, _ in
            recentered(colors, around: centers)
        }
        guard one.distance(to: two) >= checkerSeparation,
              band.share(near: [one, two], within: nearDistance) >= uniformBorderShare,
              band.share(near: [one], within: nearDistance) >= checkerColorShare,
              band.share(near: [two], within: nearDistance) >= checkerColorShare else { return nil }
        return .checkerboard(one, two)
    }

    /// 2 つの中心のどちらに近いかで色を分け、それぞれの平均を新しい中心にする（2 つに分ける 1 回ぶん）。
    static func recentered(_ colors: [RGBColor],
                           around centers: (RGBColor, RGBColor)) -> (RGBColor, RGBColor) {
        let nearFirst = colors.filter { $0.distance(to: centers.0) <= $0.distance(to: centers.1) }
        let nearSecond = colors.filter { $0.distance(to: centers.0) > $0.distance(to: centers.1) }
        return (mean(nearFirst) ?? centers.0, mean(nearSecond) ?? centers.1)
    }

    static func mean(_ colors: [RGBColor]) -> RGBColor? {
        guard !colors.isEmpty else { return nil }
        let count = Float(colors.count)
        return RGBColor(red: colors.map(\.red).reduce(0, +) / count,
                        green: colors.map(\.green).reduce(0, +) / count,
                        blue: colors.map(\.blue).reduce(0, +) / count)
    }
}
