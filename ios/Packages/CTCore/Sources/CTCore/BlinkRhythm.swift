import Foundation

/// ウィジェットのまばたきのリズム（プラン §9 Phase 3 の 3-C ④ 原則 3）。
///
/// 秒の一の位が「集まり」に入った秒の、頭の 0.25 秒だけまぶたを重ねる。0.75 秒進めた
/// タイマーと「かつ」で重ねて 0.25 秒に絞るので、タイマーは 2 本使う。
///
/// **候補は、どの間隔も 3〜5 秒に収まる集まりだけ。** アプリの待受モードのまばたき
/// （`Motion.blinkIntervalSeconds` の 4 秒に、ゆらぎが最大 2.5 秒）と同じくらいの頻度にする。
/// 2 つ組（{2, 7} など）は 5 秒ごと、3 つ組（{0, 3, 6} など）は 3・3・4 秒ごとにまばたく。
/// 4 つ以上は、間隔を 3 秒以上に保てない（4 × 3 秒 > 10 秒）。
///
/// どの集まりにするかは、キャラと端末の種から決める。同じキャラなら、どのウィジェットも
/// 同じ秒にまばたく（0 時起点なので、ページのウィジェットどうしもそろう。D-18）。
public enum BlinkRhythm {

    /// まばたきの間隔の下限と上限（秒）。
    public static let minimumGapSeconds = 3
    public static let maximumGapSeconds = 5
    /// まぶたを重ねている長さ。1 秒を 4 つに分けた 1 つぶん。
    public static let blinkSeconds = 0.25

    /// まばたきに使える集まり。2 つ組が 5 通り、3 つ組が 10 通り（少ない順、同じ数なら名前の順）。
    public static let candidates: [DigitSet] = (1..<(1 << DigitSet.allDigits.count))
        .map { mask in DigitSet(DigitSet.allDigits.filter { mask & (1 << $0) != 0 }) }
        .filter(hasSteadyGaps)
        .sorted { ($0.digits.count, $0.key) < ($1.digits.count, $1.key) }

    /// そのキャラのまばたきの集まり。
    public static func digits(characterID: String, userSeed: UInt64) -> DigitSet {
        let rng = IndexedRandom(seed: userSeed, StableHash.string(characterID), RandomScope.blink)
        return candidates[rng.int(0...(candidates.count - 1), 0)]
    }

    /// そのキャラのまばたきの窓。集まりの秒の、頭の 0.25 秒だけ開く。
    public static func window(for digits: DigitSet) -> TimerWindow {
        .when(digits).and(.when(digits, advancedBy: 1 - blinkSeconds))
    }

    /// 秒の一の位は 10 秒で一周する。0 秒をまたぐ間隔も含めて、すべてが 3〜5 秒か。
    static func hasSteadyGaps(_ set: DigitSet) -> Bool {
        guard let first = set.digits.first, set.digits.count >= 2 else { return false }
        let gaps = zip(set.digits, Array(set.digits.dropFirst()) + [first + DigitSet.allDigits.count])
            .map { $1 - $0 }
        return gaps.allSatisfy { (minimumGapSeconds...maximumGapSeconds).contains($0) }
    }
}
