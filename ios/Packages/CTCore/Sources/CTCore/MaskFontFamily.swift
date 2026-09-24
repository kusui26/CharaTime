import Foundation

/// 疑似アニメのマスク書体の一族（プラン §9 Phase 3 の 3-2b）。書体 1 本が、数字の集まり 1 つ。
///
/// 動かし方（`AmbientCue`）が使う窓を、書体の少ない形（`TimerWindow.canonical`）に回すと、
/// 要る集まりはこの 7 つになる。パイプライン（tools/pipeline）がこの集まりの書体を焼き、
/// 同梱データ（CTAssets の `mask_fonts.json`）に名前を書く。
///
/// **窓を足したら、ここにも、パイプラインの一覧にも足す。** 足りない集まりがあると、その窓は
/// 書体が見つからず、システムの字で描かれる（数字の形の穴から絵が覗く）。テストが食い違いを見張る。
public enum MaskFontFamily {

    public static let digitSets: [DigitSet] = [
        DigitSet([0, 5]),                           // まばたき（2 つ組を回した形）
        DigitSet([0, 3, 6]),                        // まばたき（3 つ組を回した形）
        .even,                                      // よろこぶの出し分け・光の粒（奇数は 1 秒進めた偶数）
        .sleepBreath,                               // 寝息
        DigitSet([0, 1, 2, 5, 6, 7]),               // 寝息の残り {2, 3, 4, 7, 8, 9} を回した形（覆えないとき）
        .zero,                                      // 時報（分の一の位）
        .firstHalfMinute,                           // 時報（秒の十の位）
    ]
}
