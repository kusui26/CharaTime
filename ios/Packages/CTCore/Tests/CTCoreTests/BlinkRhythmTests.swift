import Testing
import Foundation
@testable import CTCore

@Suite("まばたきのリズム")
struct BlinkRhythmTests {

    /// 10 秒で一周する秒の一の位の上で、0 秒をまたぐ間隔も含めた間隔の一覧。
    private func cyclicGaps(_ set: DigitSet) -> [Int] {
        let digits = set.digits
        return digits.indices.map { index in
            let next = index + 1 < digits.count ? digits[index + 1] : digits[0] + 10
            return next - digits[index]
        }
    }

    @Test("候補は 2 つ組が 5 通り、3 つ組が 10 通り")
    func candidateCounts() {
        let candidates = BlinkRhythm.candidates
        #expect(candidates.filter { $0.digits.count == 2 }.count == 5)
        #expect(candidates.filter { $0.digits.count == 3 }.count == 10)
        #expect(candidates.count == 15)
        #expect(Set(candidates).count == candidates.count)
        #expect(candidates.first == DigitSet([0, 5]))
    }

    /// アプリの待受モードのまばたき（4〜6.5 秒ごと）と同じくらいの頻度にするため。
    @Test("どの候補も、まばたきの間隔が 3〜5 秒に収まる")
    func gapsStayInRange() {
        for set in BlinkRhythm.candidates {
            let gaps = cyclicGaps(set)
            #expect(gaps.allSatisfy { (3...5).contains($0) }, "\(set.key) の間隔 \(gaps)")
            #expect(gaps.reduce(0, +) == 10)
        }
    }

    @Test("同じキャラと種なら、いつ引いても同じ集まり")
    func deterministic() {
        let first = BlinkRhythm.digits(characterID: "piyo", userSeed: 0xBEEF_0001)
        for _ in 0..<5 {
            #expect(BlinkRhythm.digits(characterID: "piyo", userSeed: 0xBEEF_0001) == first)
        }
        #expect(BlinkRhythm.candidates.contains(first))
    }

    /// 種によって偏らず、ほとんどの候補が選ばれる（キャラや人ごとにまばたきの癖が違って見える）。
    @Test("種を変えると、いろいろな集まりが選ばれる")
    func spreadsAcrossCandidates() {
        let chosen = Set((0..<600).map { BlinkRhythm.digits(characterID: "piyo", userSeed: UInt64($0)) })
        #expect(chosen.count >= 13, "選ばれたのは \(chosen.count) 通り")
    }

    @Test("窓は、集まりの秒の頭 0.25 秒だけ開く")
    func windowOpensBriefly() {
        let set = DigitSet([1, 4, 7])
        let window = BlinkRhythm.window(for: set)
        #expect(window.timerCount == 2)
        let spans = TestClock.openSpans(of: { window.isOpen(at: $0, calendar: TestClock.tokyo) },
                                        from: TestClock.today(8, 0, 0), seconds: 10)
        #expect(spans.map { ($0.start * 100).rounded() / 100 } == [1, 4, 7])
        #expect(spans.allSatisfy { abs($0.length - BlinkRhythm.blinkSeconds) < 0.02 })
    }
}
