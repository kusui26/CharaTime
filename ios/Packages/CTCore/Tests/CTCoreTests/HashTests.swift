import Testing
import Foundation
@testable import CTCore

/// ここが崩れると、ウィジェットとアプリが違う姿を描く。CTCore で最も守るべき性質。
@Suite("決定論ハッシュ")
struct HashTests {

    // MARK: - 固定値

    /// アルゴリズムを変えたら必ずここが落ちる。
    ///
    /// もし誰かが `Hash64` を Swift 標準の `Hasher` に置き換えたら、この検査は
    /// **実行のたびにランダムに落ちる**。それが狙いで、プロセス間で値が変わる実装が
    /// 紛れ込んだことに気づける。
    @Test("固定値が変わっていない")
    func goldenValues() {
        #expect(Hash64.mix(1) == 6_238_072_747_940_578_789)
        #expect(Hash64.combine(0) == 16_294_208_416_658_607_535)
        #expect(Hash64.combine(0, [1]) == 10_257_114_587_443_610_966)
        #expect(Hash64.combine(0, [1, 0]) == 2_133_242_336_784_641_628)
        #expect(Hash64.combine(42, [7, 3]) == 11_953_855_576_423_381_528)
        #expect(StableHash.string("piyo") == 14_238_553_083_033_833_900)
        #expect(StableHash.string("mochi") == 10_226_573_141_351_048_419)
        #expect(StableHash.string("") == 17_665_956_581_633_026_203)
    }

    @Test("可変長引数と配列は同じ値になる")
    func variadicMatchesArray() {
        #expect(Hash64.combine(9, 1, 2, 3) == Hash64.combine(9, [1, 2, 3]))
        #expect(Hash64.combine(9) == Hash64.combine(9, []))
    }

    // MARK: - 決定論

    @Test("同じ入力なら何度呼んでも同じ")
    func repeatable() {
        for index in UInt64(0)..<200 {
            let first = Hash64.combine(7, index, index &* 3)
            let second = Hash64.combine(7, index, index &* 3)
            #expect(first == second)
        }
    }

    @Test("種・並び順・個数が違えば違う値になる")
    func distinguishesInputs() {
        #expect(Hash64.combine(0, 1) != Hash64.combine(1, 1))          // 種違い
        #expect(Hash64.combine(0, 1, 2) != Hash64.combine(0, 2, 1))    // 並び違い
        #expect(Hash64.combine(0, 1) != Hash64.combine(0, 1, 0))       // 個数違い
        #expect(StableHash.string("piyo") != StableHash.string("piyó"))
        #expect(StableHash.string("ab") != StableHash.string("ba"))
    }

    // MARK: - 散り具合

    /// 入力の 1 ビットを変えたら、出力の約半分のビットが変わること（雪崩効果）。
    /// ここが弱いと、隣り合う時刻で同じ行動が続いて「同じ動きの繰り返し」に見える。
    @Test("1 ビットの違いが出力の約半分に広がる")
    func avalanche() {
        var totalFlipped = 0
        var samples = 0
        for seed in UInt64(0)..<64 {
            let base = Hash64.combine(seed, 0)
            for bit in UInt64(0)..<64 {
                let flipped = Hash64.combine(seed, 1 << bit)
                totalFlipped += (base ^ flipped).nonzeroBitCount
                samples += 1
            }
        }
        let average = Double(totalFlipped) / Double(samples)
        #expect(average > 30.0 && average < 34.0, "平均 \(average) ビット（理想 32）")
    }

    @Test("連番の入力でも衝突しない")
    func noCollisionsOnSequentialInput() {
        var seen = Set<UInt64>()
        for index in UInt64(0)..<20_000 {
            seen.insert(Hash64.combine(12_345, index))
        }
        #expect(seen.count == 20_000)
    }

    @Test("文字列ハッシュが衝突しない")
    func stringHashSpread() {
        let ids = (0..<5_000).map { "chara-\($0)" }
        #expect(Set(ids.map(StableHash.string)).count == ids.count)
    }
}
