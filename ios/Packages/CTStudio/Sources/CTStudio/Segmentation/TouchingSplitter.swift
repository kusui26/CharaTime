import Foundation

/// 触れ合って 1 つになった 2 体を、不透明さの谷で割る（プラン §9 Phase 2 の 2-C ⑤-3）。
///
/// 期待する数より体が少ないとき、膨らんだ塊（ほかの体より幅か高さが大きいもの）から順に、真ん中あたりの
/// 「不透明な画素がいちばん少ない列（行）」で割ってみる。**谷が深いときだけ割る**。1 体の真ん中には胴があり、
/// 列の画素は多いので、深い谷はできない（1 体を真ん中で切ってしまうより、「コマの間を空けて作り直す」を
/// 知らせるほうがよい）。塊が 1 つしか無く、ふつうの体の大きさが分からないときも、同じ守りで試せる。
struct TouchingSplitter {

    /// 谷の深さ: 列の不透明な画素の数が、いちばん多い列のこの割合以下なら割る。
    static let valleyShare = 0.15
    /// 谷を探す範囲（塊の幅に対する割合）。端で割ると、体の一部を切り落とす。
    static let valleySearch = 0.25...0.75
    /// 膨らんだ塊: ほかの体の幅（高さ）の、この倍以上。2 体が少し重なっていても拾える値。
    static let swollenRatio = 1.3

    let scanner: BlobScanner

    /// 体が `expected` に届くまで、割れるものを割る。
    func separated(_ bodies: [Blob], expected: Int) -> [Blob] {
        guard bodies.count < expected, let next = separatedOnce(bodies) else { return bodies }
        return separated(next, expected: expected)
    }

    /// 1 つ割る。膨らんだ塊から順に、膨らんだ向きを先に試す。どれも割れなければ nil。
    func separatedOnce(_ bodies: [Blob]) -> [Blob]? {
        guard let typical = typicalSize(of: bodies) else { return nil }
        let order = bodies.indices.sorted { swelling(bodies[$0], typical) > swelling(bodies[$1], typical) }
        for candidate in order {
            let blob = bodies[candidate]
            let wide = Double(blob.box.width) / typical.width >= Double(blob.box.height) / typical.height
            if let halves = split(blob, alongColumns: wide) ?? split(blob, alongColumns: !wide) {
                return Array(bodies[..<candidate]) + [halves.0, halves.1] + Array(bodies[(candidate + 1)...])
            }
        }
        return nil
    }

    /// ほかの体より、`swollenRatio` 倍以上に膨らんだ塊の番号（いちばん膨らんだもの）。触れ合いの知らせに使う。
    func swollenIndex(in bodies: [Blob]) -> Int? {
        guard let typical = typicalSize(of: bodies) else { return nil }
        let swellings = bodies.map { swelling($0, typical) }
        guard let candidate = swellings.indices.max(by: { swellings[$0] < swellings[$1] }),
              swellings[candidate] >= Self.swollenRatio else { return nil }
        return candidate
    }

    /// ふつうの体に比べた膨らみ（幅と高さの、大きいほうの比）。
    func swelling(_ blob: Blob, _ typical: (width: Double, height: Double)) -> Double {
        Swift.max(Double(blob.box.width) / typical.width, Double(blob.box.height) / typical.height)
    }

    /// ふつうの体の大きさ（幅と高さの、低いほうの中央値。膨らんだ塊に引っぱられない）。
    func typicalSize(of bodies: [Blob]) -> (width: Double, height: Double)? {
        guard !bodies.isEmpty else { return nil }
        let widths = bodies.map(\.box.width).sorted(), heights = bodies.map(\.box.height).sorted()
        let middle = (bodies.count - 1) / 2
        return (Double(Swift.max(1, widths[middle])), Double(Swift.max(1, heights[middle])))
    }

    /// 谷で 2 つに割る。谷が浅い・割った片方が空なら nil。
    func split(_ blob: Blob, alongColumns: Bool) -> (Blob, Blob)? {
        let profile = scanner.profile(of: blob, alongColumns: alongColumns)
        guard let cut = valley(in: profile) else { return nil }
        let position = (alongColumns ? blob.box.left : blob.box.top) + cut
        let sides = Self.sides(of: scanner.frame, at: position, alongColumns: alongColumns)
        guard let first = scanner.narrowed(blob, to: sides.before),
              let second = scanner.narrowed(blob, to: sides.after) else { return nil }
        return (first, second)
    }

    /// 絵を、列（行）`position` の手前と、そこから先に分ける。
    static func sides(of frame: PixelBox, at position: Int,
                      alongColumns: Bool) -> (before: PixelBox, after: PixelBox) {
        var before = frame, after = frame
        if alongColumns {
            before.right = position
            after.left = position
        } else {
            before.bottom = position
            after.top = position
        }
        return (before, after)
    }

    /// 真ん中あたりで、いちばん少ない列（行）の番号。十分に深くなければ nil。
    func valley(in profile: [Int]) -> Int? {
        guard let peak = profile.max(), peak > 0 else { return nil }
        let lower = Int(Double(profile.count) * Self.valleySearch.lowerBound)
        let upper = Int(Double(profile.count) * Self.valleySearch.upperBound)
        guard lower < upper, let deepest = (lower..<upper).min(by: { profile[$0] < profile[$1] }),
              Double(profile[deepest]) <= Double(peak) * Self.valleyShare else { return nil }
        return deepest
    }
}

/// コマを、行ごと・左からの順に並べる（手引きのコマの順。2-C ⑤-3）。
enum ReadingOrder {

    /// 同じ行とみなす、中心の高さの差（体の高さの中央値に対する割合）。
    static let rowTolerance = 0.4

    static func sorted(_ bodies: [Blob]) -> [Blob] {
        rows(of: bodies).flatMap { row in row.sorted { $0.box.centerX < $1.box.centerX } }
    }

    /// 中心の高さの近いものを、上の行から順にまとめる。
    static func rows(of bodies: [Blob]) -> [[Blob]] {
        let heights = bodies.map(\.box.height).sorted()
        guard !heights.isEmpty else { return [] }
        let tolerance = Double(heights[(heights.count - 1) / 2]) * rowTolerance
        return bodies.sorted { $0.box.centerY < $1.box.centerY }.reduce(into: [[Blob]]()) { rows, body in
            let rowCenter = rows.last.map { row in row.map(\.box.centerY).reduce(0, +) / Double(row.count) }
            if let rowCenter, abs(body.box.centerY - rowCenter) <= tolerance {
                rows[rows.count - 1].append(body)
            } else {
                rows.append([body])
            }
        }
    }
}
