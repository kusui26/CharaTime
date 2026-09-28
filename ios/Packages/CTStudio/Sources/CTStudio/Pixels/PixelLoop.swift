import Foundation

/// 0 から `count` 未満の番号を、1 つずつ渡す。**画素を全部回す所はこれを使う**（プラン §9 Phase 2 の 2-C ⑫）。
///
/// 最適化しないビルド（`swift test` の既定）では、`for i in 0..<n` の繰り返しと `Array.map` そのものが、1 回ごとに
/// 重い呼び出しになる。hero 1 枚（47 万画素）を回すと、`for` は 60 ms・`map` は 33 ms、`while` で回してクロージャを
/// 呼ぶこの形は 3 ms だった（2026-09-28 に測った）。最適化したビルド（アプリ・Mac の道具）では、どれも同じ速さになる。
@inline(__always)
func eachIndex(_ count: Int, _ body: (Int) -> Void) {
    eachIndex(in: 0..<count, body)
}

/// 範囲の番号を 1 つずつ渡す（`eachIndex(_:_:)` と同じ理由）。
@inline(__always)
func eachIndex(in range: Range<Int>, _ body: (Int) -> Void) {
    var index = range.lowerBound
    while index < range.upperBound {
        body(index)
        index &+= 1
    }
}
