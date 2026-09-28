import Foundation

/// つながった塊（小さな部品を寄せ集めたものも）。コマを見つける途中の姿（2-C ⑤-3）。
struct Blob: Equatable {

    /// 塊に入る番号（`ComponentLabels`）。とさかのような離れた部品を寄せると、番号が増える。
    var labels: Set<Int32>
    /// 不透明な画素（不透明さ 0.5 以上）の数。
    var area: Int
    /// 不透明な画素の外接矩形。
    var box: PixelBox
    /// この塊に入れる画素の範囲。触れ合った 2 体を割ったときだけ狭める（ふつうは絵全体）。
    var clip: PixelBox

    /// その画素が、この塊のものか。
    func owns(_ label: Int32, x: Int, y: Int) -> Bool {
        label != 0 && labels.contains(label) && clip.contains(x: x, y: y)
    }

    /// 小さな部品を寄せる。
    func absorbing(_ part: Blob) -> Blob {
        Blob(labels: labels.union(part.labels), area: area + part.area, box: box.union(part.box), clip: clip)
    }
}

/// 塊を測る道具（番号と、不透明な画素の印を持つ）。
struct BlobScanner {

    let components: ComponentLabels
    /// 不透明さ 0.5 以上の画素の印（0 か 255）。
    let opaque: [UInt8]

    var frame: PixelBox { PixelBox(width: components.width, height: components.height) }

    /// 番号ごとの塊（番号の順）。全画素を 1 度だけ回し、番号ごとの面積と外接矩形を数える。
    func blobs() -> [Blob] {
        guard components.count >= 1 else { return [] }
        let tally = self.tally()
        return (1...components.count).compactMap { label in
            let base = label * Self.tallyStride
            guard tally[base] > 0 else { return nil }
            let box = PixelBox(left: tally[base + 1], top: tally[base + 2],
                               right: tally[base + 3], bottom: tally[base + 4])
            return Blob(labels: [Int32(label)], area: tally[base], box: box, clip: frame)
        }
    }

    /// 番号ごとに [面積, 左, 上, 右, 下] を 5 つずつ並べた集計（最適化しないビルドでも速いよう、1 つの配列にする）。
    func tally() -> [Int] {
        var tally = [Int](repeating: 0, count: (components.count + 1) * Self.tallyStride)
        for label in 0...components.count {
            tally[label * Self.tallyStride + 1] = .max
            tally[label * Self.tallyStride + 2] = .max
        }
        let width = components.width
        components.labels.withUnsafeBufferPointer { labels in
            opaque.withUnsafeBufferPointer { opaque in
                tally.withUnsafeMutableBufferPointer { tally in
                    eachIndex(labels.count) { index in
                        guard opaque[index] != 0, labels[index] != 0 else { return }
                        let base = Int(labels[index]) * Self.tallyStride
                        Self.add(base, x: index % width, y: index / width, to: tally)
                    }
                }
            }
        }
        return tally
    }

    /// 集計の 1 つぶんの長さ（面積・左・上・右・下）。
    static let tallyStride = 5

    @inline(__always)
    private static func add(_ base: Int, x: Int, y: Int, to tally: UnsafeMutableBufferPointer<Int>) {
        tally[base] += 1
        tally[base + 1] = Swift.min(tally[base + 1], x)
        tally[base + 2] = Swift.min(tally[base + 2], y)
        tally[base + 3] = Swift.max(tally[base + 3], x + 1)
        tally[base + 4] = Swift.max(tally[base + 4], y + 1)
    }

    /// 塊の不透明な画素を、列ごと（`alongColumns` が偽なら行ごと）に数える（外接矩形の中だけ）。
    func profile(of blob: Blob, alongColumns: Bool) -> [Int] {
        var counts = [Int](repeating: 0, count: alongColumns ? blob.box.width : blob.box.height)
        visit(blob, within: blob.box) { x, y in
            counts[alongColumns ? x - blob.box.left : y - blob.box.top] += 1
        }
        return counts
    }

    /// `clip` の中だけに絞った塊の、面積と外接矩形。1 画素も無ければ nil。
    func narrowed(_ blob: Blob, to clip: PixelBox) -> Blob? {
        guard let region = blob.clip.intersection(clip) else { return nil }
        var narrowed = Blob(labels: blob.labels, area: 0, box: blob.box, clip: region)
        var box: PixelBox?
        visit(narrowed, within: blob.box) { x, y in
            narrowed.area += 1
            box = box.map { $0.union(PixelBox(x: x, y: y)) } ?? PixelBox(x: x, y: y)
        }
        guard let box else { return nil }
        narrowed.box = box
        return narrowed
    }

    /// 塊の不透明な画素を、`within` の中で 1 つずつ渡す。
    func visit(_ blob: Blob, within area: PixelBox, _ body: (Int, Int) -> Void) {
        let width = components.width
        components.labels.withUnsafeBufferPointer { labels in
            opaque.withUnsafeBufferPointer { opaque in
                eachIndex(area.area) { local in
                    let x = area.left + local % area.width, y = area.top + local / area.width
                    let index = y * width + x
                    if opaque[index] != 0, blob.owns(labels[index], x: x, y: y) { body(x, y) }
                }
            }
        }
    }
}
