import Testing
import Foundation
@testable import CTCore

@Suite("添字で引く乱数")
struct IndexedRandomTests {

    private let rng = IndexedRandom(seed: 12_345, StableHash.string("piyo"), 20_260_911)

    @Test("固定値が変わっていない")
    func golden() {
        #expect(rng.seed == 1_186_737_903_034_645_186)
        #expect(abs(rng.unit(1) - 0.745_104_047_113_541_8) < 1e-15)
        #expect(rng.int(0...59, 2) == 2)
        #expect(rng.weightedIndex([1, 2, 3, 4], 3) == 0)
    }

    /// 先頭から再生せずに任意の添字を引けること。ウィジェットが
    /// 「3 時間後のエントリ」をその場で作れるのはこの性質による。
    @Test("順に引いても飛ばして引いても同じ値")
    func randomAccessMatchesSequential() {
        let sequential = (UInt64(0)..<50).map { rng.raw($0) }
        for index in stride(from: UInt64(49), through: 0, by: -1) {
            #expect(rng.raw(index) == sequential[Int(index)])
        }
    }

    @Test("unit は 0 以上 1 未満")
    func unitRange() {
        for index in UInt64(0)..<20_000 {
            let value = rng.unit(index)
            #expect(value >= 0.0 && value < 1.0)
        }
    }

    @Test("unit が偏らない")
    func unitDistribution() {
        var buckets = [Int](repeating: 0, count: 10)
        let samples = 40_000
        for index in UInt64(0)..<UInt64(samples) {
            buckets[min(9, Int(rng.unit(index) * 10))] += 1
        }
        let expected = Double(samples) / 10.0
        for (bucket, count) in buckets.enumerated() {
            let drift = abs(Double(count) - expected) / expected
            #expect(drift < 0.06, "バケット \(bucket) が \(count) 件（期待 \(expected)）")
        }
    }

    @Test("int は範囲の内側に収まり、両端も出る")
    func intRange() {
        var seenLow = false, seenHigh = false
        for index in UInt64(0)..<20_000 {
            let value = rng.int(5...9, index)
            #expect(value >= 5 && value <= 9)
            if value == 5 { seenLow = true }
            if value == 9 { seenHigh = true }
        }
        #expect(seenLow && seenHigh)
    }

    @Test("要素が 1 つだけの範囲")
    func intSingleValue() {
        for index in UInt64(0)..<100 {
            #expect(rng.int(3...3, index) == 3)
        }
    }

    @Test("負の範囲も扱える")
    func intNegativeRange() {
        for index in UInt64(0)..<2_000 {
            let value = rng.int(-20 ... -10, index)
            #expect(value >= -20 && value <= -10)
        }
    }

    @Test("bool の確率がおおむね合う")
    func boolProbability() {
        let samples = 20_000
        var hits = 0
        for index in UInt64(0)..<UInt64(samples) where rng.bool(0.3, index) { hits += 1 }
        let rate = Double(hits) / Double(samples)
        #expect(abs(rate - 0.3) < 0.02, "実測 \(rate)")
        #expect(!rng.bool(0.0, 1))
        #expect(rng.bool(1.0, 1))
        #expect(!rng.bool(-1, 1))
    }

    @Test("重み付き抽選が重みどおりに散る")
    func weightedDistribution() {
        let weights = [1.0, 3.0, 0.0, 6.0]      // 合計 10。3 番目は絶対に出ない
        var counts = [Int](repeating: 0, count: weights.count)
        let samples = 20_000
        for index in UInt64(0)..<UInt64(samples) {
            guard let picked = rng.weightedIndex(weights, index) else {
                Issue.record("重みがあるのに nil が返った"); return
            }
            counts[picked] += 1
        }
        #expect(counts[2] == 0)
        for index in [0, 1, 3] {
            let rate = Double(counts[index]) / Double(samples)
            let expected = weights[index] / 10.0
            #expect(abs(rate - expected) < 0.02, "添字 \(index): 実測 \(rate) 期待 \(expected)")
        }
    }

    @Test("選べる行動が無いときは nil（既定値で黙って埋めない）")
    func weightedEmpty() {
        #expect(rng.weightedIndex([], 1) == nil)
        #expect(rng.weightedIndex([0, 0, 0], 1) == nil)
        #expect(rng.weightedIndex([-1, -2], 1) == nil)
    }

    @Test("scoped で派生させた列は互いに独立")
    func scopedIndependence() {
        let a = rng.scoped(1)
        let b = rng.scoped(2)
        #expect(a.seed != b.seed)
        #expect(a.seed != rng.seed)
        var same = 0
        for index in UInt64(0)..<1_000 where a.raw(index) == b.raw(index) { same += 1 }
        #expect(same == 0)
        // 派生のしかたが同じなら同じ列になる（決定論）
        #expect(rng.scoped(1).seed == a.seed)
    }
}
