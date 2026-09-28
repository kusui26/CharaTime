import Foundation

/// 開いた目 1 つ（hero の画素）。
struct Eye: Equatable, Sendable {
    /// 暗い塊の番号（`FaceScan.components`）。
    let label: Int32
    /// 白い光の穴を埋めた目の外接矩形。
    let box: PixelBox
    /// 白い光の穴を埋めた目の画素（絵全体の番号）。
    let pixels: [Int]
}

/// 目を開けた正面の絵から、2 つの目を見つける（プラン §9 Phase 2 の 2-C ⑤-6、D-38）。
///
/// **目は「輪郭線とつながらない暗い塊で、白い光の穴を埋めた面の 6 割以上が暗いもの」**。大きさと高さの近い 2 つを
/// 選ぶ。2-0 の最初の試作は、くちばしの輪郭（暗い輪の中が明るい）を目と取り違えたので、暗さの割合で外す。
///
/// 目がほかの線に重なっている絵（いまのクマオは、目の下半分がマズルの輪郭線と内側に重なる）は、目を見つけない。
/// 目を消すと、隠れていた線と面を描き直すことになり、1 色で埋めると染みと欠けが残る（2026-09-28 に試した）。
/// まばたき無しにして、直しのプロンプト F-EYES（目を小さな点にする）を勧める。
enum EyeFinder {

    /// 穴を埋めた面のうち、暗い画素の割合の下限。目（黒い点に白い光 1 つ）は約 0.9、太い線で描いた小さな輪は下回る。
    static let darkShareOfFilled = 0.6
    /// 穴を埋めた面が、外接矩形に占める割合の下限。丸い点は 0.79、よろこぶ姿の閉じた目（太い弧）は 0.5 ほど。
    static let compactShare = 0.6
    /// 縦横比（幅 ÷ 高さ）の範囲。目は丸か縦長。閉じた目の弧（横長。2 前後）を外す。
    static let aspectRange = 0.5...1.6
    /// 目の幅の、体の幅に対する範囲。いまの 5 体は 0.125、生成 AI の「小さな点の目」はそれより小さい。
    static let widthShareRange = 0.02...0.2
    /// 目があってよい範囲（体の外接矩形の上からの割合）。2 頭身なので、頭は上の半分ほど。
    static let headShare = 0.75
    /// 2 つの目の、幅・高さの比の上限。
    static let pairSizeRatio = 1.5
    /// 2 つの目の中心の高さの差の上限（目の高さに対する割合）。
    static let pairLevelShare = 0.5
    /// 2 つの目の間隔の上限（体の幅に対する割合）。
    static let pairSpreadShare = 0.6

    /// 2 つの目（左から）。見つからなければ nil（まばたき無しにする）。
    static func find(in scan: FaceScan, figure: FigureMetrics) -> [Eye]? {
        let eyes = candidates(in: scan, figure: figure)
        let pairs = eyes.indices.flatMap { first in
            eyes.indices.filter { $0 > first }.map { (eyes[first], eyes[$0]) }
        }
        let matching = pairs.filter { matches($0.0, $0.1, figure: figure) }
        guard let best = matching.max(by: { $0.0.pixels.count + $0.1.pixels.count
                                            < $1.0.pixels.count + $1.1.pixels.count }) else { return nil }
        return [best.0, best.1].sorted { $0.box.centerX < $1.box.centerX }
    }

    /// 目になりうる暗い塊（輪郭線につながらず、大きさ・形・位置が目らしいもの）。
    static func candidates(in scan: FaceScan, figure: FigureMetrics) -> [Eye] {
        scan.blobs.filter { blob in
            guard let label = blob.labels.first, !scan.outlineLabels.contains(label) else { return false }
            return isEyeSized(blob.box, figure: figure)
        }.compactMap { filledEye($0, scan: scan) }
    }

    static func isEyeSized(_ box: PixelBox, figure: FigureMetrics) -> Bool {
        let aspect = Double(box.width) / Double(box.height)
        let widthShare = Double(box.width) / figure.width
        let headBottom = figure.top + figure.height * headShare
        return aspectRange.contains(aspect) && widthShareRange.contains(widthShare)
            && box.centerY < headBottom
    }

    /// 白い光の穴を埋め、暗い画素の割合と丸さを確かめる。
    static func filledEye(_ blob: Blob, scan: FaceScan) -> Eye? {
        guard let label = blob.labels.first else { return nil }
        let pixels = HoleFilling.filled(label, in: scan.components, box: blob.box)
        let eye = Eye(label: label, box: blob.box, pixels: pixels)
        let darkShare = Double(blob.area) / Double(pixels.count)
        return darkShare >= darkShareOfFilled && isRound(eye) ? eye : nil
    }

    /// 穴を埋めた面が、外接矩形を十分に満たすか（点か、細い線か）。
    static func isRound(_ eye: Eye) -> Bool {
        Double(eye.pixels.count) / Double(eye.box.area) >= compactShare
    }

    /// 2 つの目として釣り合うか（大きさ・高さが近く、重ならず、離れすぎない）。
    static func matches(_ first: Eye, _ second: Eye, figure: FigureMetrics) -> Bool {
        let widths = [first.box.width, second.box.width].map(Double.init)
        let heights = [first.box.height, second.box.height].map(Double.init)
        let spread = abs(first.box.centerX - second.box.centerX)
        return ratio(widths) <= pairSizeRatio && ratio(heights) <= pairSizeRatio
            && abs(first.box.centerY - second.box.centerY) <= pairLevelShare * (heights.max() ?? 0)
            && spread >= (widths.max() ?? 0) && spread <= pairSpreadShare * figure.width
    }

    static func ratio(_ values: [Double]) -> Double {
        (values.max() ?? 1) / Swift.max(values.min() ?? 1, 1)
    }
}

/// 塊の穴を埋める（外接矩形の外から塗り広げて届かなかった所が、塊と穴）。
enum HoleFilling {

    /// 塊 `label` と、それに囲まれた穴の画素（絵全体の番号）。
    static func filled(_ label: Int32, in components: ComponentLabels, box: PixelBox) -> [Int] {
        // 外接矩形の四方に 1 画素の余白を足し、余白の縁から塊の外を塗り広げる。
        let width = box.width + 2, height = box.height + 2
        let open = (0..<(width * height)).map { local -> Bool in
            let x = local % width + box.left - 1, y = local / width + box.top - 1
            let inside = x >= 0 && y >= 0 && x < components.width && y < components.height
            return !inside || components.labels[y * components.width + x] != label
        }
        let flood = FloodFill(width: width, height: height)
        let outside = flood.reach(from: flood.borderSeeds, through: open)
        return outside.indices.filter { !outside[$0] }.map { local in
            (local / width + box.top - 1) * components.width + local % width + box.left - 1
        }
    }
}
