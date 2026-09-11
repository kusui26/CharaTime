import Foundation

/// 添字で引く決定論的な乱数。
///
/// 連番の疑似乱数生成器（`SystemRandomNumberGenerator` や `SplitMix64` を回すもの）
/// との違いは、**任意の添字の値を、先頭から再生せずに直接引ける**こと。
/// ウィジェットは「いまから 3 時間後のエントリ」をその場で作る必要があるので、
/// この性質が要る（プラン §5.4）。
///
/// ```swift
/// let rng = IndexedRandom(seed: userSeed, StableHash.string("piyo"), dayNumber)
/// let bedtimeMinutes = rng.int(22 * 60 ... 25 * 60, 1)   // 添字 1 番の値
/// let firstWaypointX = rng.unit(2, 0)                    // 添字 2 番の 0 番目
/// ```
public struct IndexedRandom: Sendable, Equatable {

    /// この乱数列の種。`scoped(_:)` で派生させると別の列になる。
    public let seed: UInt64

    public init(seed: UInt64) {
        self.seed = seed
    }

    /// 種と、文脈を表す座標から作る。キャラ ID や日付を混ぜるときに使う。
    public init(seed: UInt64, _ parts: UInt64...) {
        self.seed = Hash64.combine(seed, parts)
    }

    /// この乱数列から、さらに別の列を派生させる。
    ///
    /// セグメントごと・経由点ごとに列を分けておくと、あとから片方の添字だけを
    /// 増やしても、もう片方の値が動かない。
    public func scoped(_ parts: UInt64...) -> IndexedRandom {
        IndexedRandom(seed: Hash64.combine(seed, parts))
    }

    // MARK: - 生の値

    public func raw(_ parts: UInt64...) -> UInt64 {
        Hash64.combine(seed, parts)
    }

    // MARK: - 変換

    /// 0.0 以上 1.0 未満の値。
    public func unit(_ parts: UInt64...) -> Double {
        Self.unit(Hash64.combine(seed, parts))
    }

    /// `range` の中の整数。上下端を含む。
    public func int(_ range: ClosedRange<Int>, _ parts: UInt64...) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound) + 1
        let raw = Hash64.combine(seed, parts)
        // 剰余を使うと下端に偏る。上位 64 ビットを取れば偏りは無視できる大きさになる。
        let offset = raw.multipliedFullWidth(by: span).high
        return range.lowerBound + Int(offset)
    }

    /// 確率 `probability`（0.0〜1.0）で true。
    public func bool(_ probability: Double, _ parts: UInt64...) -> Bool {
        guard probability > 0 else { return false }
        guard probability < 1 else { return true }
        return Self.unit(Hash64.combine(seed, parts)) < probability
    }

    /// 重み付き抽選。返すのは `weights` の添字。
    ///
    /// 重みがすべて 0 以下、または空のときは `nil`。日課表で「いま選べる行動が無い」
    /// 状態を呼び出し側に気づかせるため、既定値で黙って埋めない。
    public func weightedIndex(_ weights: [Double], _ parts: UInt64...) -> Int? {
        let total = weights.reduce(0.0) { $0 + Swift.max(0, $1) }
        guard total > 0 else { return nil }
        let target = Self.unit(Hash64.combine(seed, parts)) * total
        var running = 0.0
        for (index, weight) in weights.enumerated() {
            running += Swift.max(0, weight)
            if target < running { return index }
        }
        return weights.indices.last { weights[$0] > 0 }
    }

    // MARK: - 内部

    /// 上位 53 ビットを使って [0, 1) の Double にする。Double の仮数に合わせてある。
    @usableFromInline
    static func unit(_ raw: UInt64) -> Double {
        Double(raw >> 11) * (1.0 / 9_007_199_254_740_992.0)   // 2^53
    }
}
