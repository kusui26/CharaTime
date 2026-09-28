import Foundation

/// 背景を外した絵から、コマ（キャラ 1 体ずつ）を見つける（プラン §9 Phase 2 の 2-C ⑤-3、調査 H §5）。
///
/// 格子の等分には頼らない（生成 AI の格子は、コマの数は守っても等間隔にならない。2-C ①）。
/// 不透明さで二値にし、線の切れ目を少し太らせて閉じてから、つながった塊を取る。小さな塊は近くの体へ寄せ
/// （とさか・汗・z）、隅の透かしとごみは捨てる。期待する数より少なければ、触れ合った塊を谷で割る。
/// 行ごと・左からの順に並べる（手引きのコマの順が、そのまま既定の割り当てになる）。
enum FigureFinder {

    /// 線の切れ目を閉じる太らせ（短辺に対する割合。H §5 の手順案）。
    static let closingShare = 0.005
    /// 体とみなす大きさ: 大きいほうから期待する数の塊の、面積の中央値のこの割合以上（2-C ⑤-3 の 1/10）。
    static let bodyShareOfMedian = 0.1
    /// 小さな塊を近くの体へ寄せる距離（短辺に対する割合。H §5 の 5%）。
    static let attachShare = 0.05
    /// ごみとみなす大きさ（画素）。数画素の点は、捨てても知らせない。
    static let junkArea = 16
    /// 画像の隅とみなす範囲（幅・高さに対する割合）。見える透かしは隅に入る（Gemini のきらめき）。
    static let cornerShare = 0.15

    struct Result {
        var figures: [Figure]
        var notices: [ImportNotice]
    }

    static func find(in cutout: Raster, expected: Int) -> Result {
        let opaque = opaqueMask(of: cutout)
        let radius = closingRadius(width: cutout.width, height: cutout.height)
        let closed = Morphology.dilated(opaque, width: cutout.width, height: cutout.height, radius: radius)
        let components = ComponentLabels(mask: closed, width: cutout.width, height: cutout.height)
        let scanner = BlobScanner(components: components, opaque: opaque)
        let gathered = gather(scanner.blobs(), expected: expected, scanner: scanner)
        let splitter = TouchingSplitter(scanner: scanner)
        let separated = splitter.separated(gathered.bodies, expected: expected)
        let figures = ReadingOrder.sorted(separated).map {
            crop(cutout, $0, scanner: scanner, margin: radius + 1)
        }
        let countWarnings = countNotices(separated, expected: expected, splitter: splitter)
        return Result(figures: figures, notices: gathered.notices + countWarnings)
    }

    /// 不透明さ 0.5 以上の画素の印（0 か 255）。
    static func opaqueMask(of raster: Raster) -> [UInt8] {
        var mask = [UInt8](repeating: 0, count: raster.pixelCount)
        raster.pixels.withUnsafeBufferPointer { pixels in
            mask.withUnsafeMutableBufferPointer { mask in
                eachIndex(mask.count) { index in
                    if pixels[index &* Raster.bytesPerPixel &+ 3] >= 128 { mask[index] = Morphology.marked }
                }
            }
        }
        return mask
    }

    static func closingRadius(width: Int, height: Int) -> Int {
        Swift.max(1, Int((Double(Swift.min(width, height)) * closingShare).rounded()))
    }

    // MARK: - 体と部品

    /// 体を選び、小さな部品を近くの体へ寄せる。寄せられない部品は捨て、透かしなら知らせる。
    static func gather(_ blobs: [Blob], expected: Int,
                       scanner: BlobScanner) -> (bodies: [Blob], notices: [ImportNotice]) {
        let threshold = bodyThreshold(blobs, expected: expected)
        let reach = Int(Double(Swift.min(scanner.frame.width, scanner.frame.height)) * attachShare)
        let parts = blobs.filter { Double($0.area) < threshold }
        let start = (bodies: blobs.filter { Double($0.area) >= threshold }, dropped: [Blob]())
        let sorted = parts.reduce(start) { state, part in
            guard let nearest = nearestBody(to: part, in: state.bodies, within: reach) else {
                return (state.bodies, state.dropped + [part])
            }
            var bodies = state.bodies
            bodies[nearest] = bodies[nearest].absorbing(part)
            return (bodies, state.dropped)
        }
        return (sorted.bodies, droppedNotices(sorted.dropped, frame: scanner.frame))
    }

    /// 体とみなす面積の下限。大きいほうから `expected` 個の塊の面積の中央値の 1/10。
    static func bodyThreshold(_ blobs: [Blob], expected: Int) -> Double {
        let largest = blobs.map(\.area).sorted(by: >).prefix(Swift.max(1, expected))
        guard !largest.isEmpty else { return .infinity }
        return Double(Array(largest)[largest.count / 2]) * bodyShareOfMedian
    }

    /// いちばん近い体の番号（すき間が `reach` 以内のものだけ）。
    static func nearestBody(to part: Blob, in bodies: [Blob], within reach: Int) -> Int? {
        let gaps = bodies.map { part.box.gap(to: $0.box) }
        guard let nearest = gaps.indices.min(by: { gaps[$0] < gaps[$1] }),
              gaps[nearest] <= reach else { return nil }
        return nearest
    }

    static func droppedNotices(_ dropped: [Blob], frame: PixelBox) -> [ImportNotice] {
        let visible = dropped.filter { $0.area > junkArea }
        let watermarks = visible.filter { isInCorner($0.box, frame: frame) }
        let others = visible.count - watermarks.count
        return (watermarks.isEmpty ? [] : [ImportNotice(.watermarkRemoved, "\(watermarks.count) 個")])
            + (others == 0 ? [] : [ImportNotice(.partsRemoved, "\(others) 個")])
    }

    /// 矩形が、絵の四隅のどれかの範囲に収まっているか。
    static func isInCorner(_ box: PixelBox, frame: PixelBox) -> Bool {
        let marginX = Int(Double(frame.width) * cornerShare)
        let marginY = Int(Double(frame.height) * cornerShare)
        let nearLeft = box.right <= frame.left + marginX, nearRight = box.left >= frame.right - marginX
        let nearTop = box.bottom <= frame.top + marginY, nearBottom = box.top >= frame.bottom - marginY
        return (nearLeft || nearRight) && (nearTop || nearBottom)
    }

    /// 数が合わないときの知らせ。少なくて膨らんだ塊があれば、コマが触れ合っている（割れなかった）。
    /// そうでなければ、描かれたコマの数が違う（テンプレート §4.4 の F-SPACE と F-COUNT）。
    static func countNotices(_ bodies: [Blob], expected: Int, splitter: TouchingSplitter) -> [ImportNotice] {
        guard bodies.count != expected else { return [] }
        let detail = "\(bodies.count) 体（\(expected) 体のはず）"
        let touching = bodies.count < expected && splitter.swollenIndex(in: bodies) != nil
        return [ImportNotice(touching ? .figuresTouching : .figureCount, detail)]
    }

    // MARK: - 切り出し

    /// 塊の画素だけを、外接矩形を `margin` だけ広げて切り出す（縁のなめらかな画素も入れる）。
    static func crop(_ cutout: Raster, _ blob: Blob, scanner: BlobScanner, margin: Int) -> Figure {
        let limit = blob.clip.intersection(scanner.frame) ?? scanner.frame
        let box = blob.box.expanded(by: margin, within: limit)
        var image = Raster(width: box.width, height: box.height)
        let width = cutout.width
        image.pixels.withUnsafeMutableBufferPointer { target in
            cutout.pixels.withUnsafeBufferPointer { source in
                scanner.components.labels.withUnsafeBufferPointer { labels in
                    eachIndex(box.area) { local in
                        let x = box.left + local % box.width, y = box.top + local / box.width
                        guard blob.owns(labels[y * width + x], x: x, y: y) else { return }
                        Raster.copyPixel(from: source, at: (y * width + x) * Raster.bytesPerPixel,
                                         to: target, at: local * Raster.bytesPerPixel)
                    }
                }
            }
        }
        return Figure(image: image, originX: box.left, originY: box.top)
    }
}
