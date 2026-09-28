import Foundation

/// つながった塊に番号を付ける（8 近傍）。コマを見つける（2-C ⑤-3、調査 H §5）・目を探す（⑤-6）に使う。
///
/// 最適化しないビルドでも遅くならないよう、生のバッファで塗り広げる（H §5: 2048 四方で 40〜60 ms は
/// 最適化したビルドの値。`swift test` では小さな見本で回す）。
struct ComponentLabels: CustomStringConvertible {

    let width: Int
    let height: Int
    /// 画素ごとの塊の番号（0 は塊の外。1 から）。
    let labels: [Int32]
    /// 塊の数。
    let count: Int

    var description: String { "ComponentLabels(\(width)×\(height)、\(count) 個)" }

    /// `mask` の 0 でない画素を、8 近傍でつないで番号を付ける。
    init(mask: [UInt8], width: Int, height: Int) {
        var labels = [Int32](repeating: 0, count: mask.count)
        var count: Int32 = 0
        mask.withUnsafeBufferPointer { mask in
            labels.withUnsafeMutableBufferPointer { labels in
                var stack: [Int] = []
                eachIndex(mask.count) { start in
                    guard mask[start] != 0, labels[start] == 0 else { return }
                    count += 1
                    let fill = Fill(width: width, height: height, mask: mask, labels: labels, label: count)
                    fill.run(from: start, stack: &stack)
                }
            }
        }
        self.width = width
        self.height = height
        self.labels = labels
        self.count = Int(count)
    }

    /// 1 つの塊を塗る。
    private struct Fill {
        let width: Int
        let height: Int
        let mask: UnsafeBufferPointer<UInt8>
        let labels: UnsafeMutableBufferPointer<Int32>
        let label: Int32

        func run(from start: Int, stack: inout [Int]) {
            labels[start] = label
            stack.append(start)
            while let index = stack.popLast() {
                let x = index % width
                let hasLeft = x > 0, hasRight = x < width - 1
                let hasUp = index >= width, hasDown = index + width < labels.count
                if hasLeft { visit(index - 1, &stack) }
                if hasRight { visit(index + 1, &stack) }
                if hasUp { visitRow(index - width, hasLeft: hasLeft, hasRight: hasRight, &stack) }
                if hasDown { visitRow(index + width, hasLeft: hasLeft, hasRight: hasRight, &stack) }
            }
        }

        /// 上か下の行の、真上（真下）と斜めの 3 画素。
        @inline(__always)
        private func visitRow(_ center: Int, hasLeft: Bool, hasRight: Bool, _ stack: inout [Int]) {
            visit(center, &stack)
            if hasLeft { visit(center - 1, &stack) }
            if hasRight { visit(center + 1, &stack) }
        }

        @inline(__always)
        private func visit(_ index: Int, _ stack: inout [Int]) {
            guard mask[index] != 0, labels[index] == 0 else { return }
            labels[index] = label
            stack.append(index)
        }
    }
}
