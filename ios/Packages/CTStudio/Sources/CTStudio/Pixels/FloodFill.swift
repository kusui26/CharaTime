import Foundation

/// 画素の格子を、通ってよい画素だけを通って塗り広げる（上下左右の 4 近傍）。
///
/// 背景を縁から抜くとき（2-C ⑤-2「縁からつながる地だけ」）と、目の中の白い光の穴を埋めるとき（⑤-6）に使う。
/// 最適化しないビルド（`swift test` の既定）でも遅くならないよう、画素は生のバッファで扱う（調査 H §2）。
struct FloodFill {

    let width: Int
    let height: Int

    /// 縁の画素の番号（上・下の行と、左・右の列）。
    var borderSeeds: [Int] {
        guard width > 0, height > 0 else { return [] }
        let rows = Array(0..<width) + Array((height - 1) * width..<height * width)
        let columns = (0..<height).flatMap { [$0 * width, $0 * width + width - 1] }
        return rows + columns
    }

    /// `seeds` から、`open` の画素だけを通って届く画素。
    func reach(from seeds: [Int], through open: [Bool]) -> [Bool] {
        var reached = [Bool](repeating: false, count: width * height)
        open.withUnsafeBufferPointer { openPixels in
            reached.withUnsafeMutableBufferPointer { reachedPixels in
                var stack = seeds.filter { openPixels[$0] && !reachedPixels[$0] }
                for seed in stack { reachedPixels[seed] = true }
                while let index = stack.popLast() {
                    spread(from: index, open: openPixels, reached: reachedPixels, stack: &stack)
                }
            }
        }
        return reached
    }

    private func spread(from index: Int, open: UnsafeBufferPointer<Bool>,
                        reached: UnsafeMutableBufferPointer<Bool>, stack: inout [Int]) {
        let x = index % width
        if x > 0 { visit(index - 1, open: open, reached: reached, stack: &stack) }
        if x < width - 1 { visit(index + 1, open: open, reached: reached, stack: &stack) }
        if index >= width { visit(index - width, open: open, reached: reached, stack: &stack) }
        if index + width < open.count { visit(index + width, open: open, reached: reached, stack: &stack) }
    }

    @inline(__always)
    private func visit(_ index: Int, open: UnsafeBufferPointer<Bool>,
                       reached: UnsafeMutableBufferPointer<Bool>, stack: inout [Int]) {
        guard open[index], !reached[index] else { return }
        reached[index] = true
        stack.append(index)
    }
}
