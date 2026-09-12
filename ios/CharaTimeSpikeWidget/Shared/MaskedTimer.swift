import SwiftUI

/// マスクフォントで ● を出したり消したりする（プラン §9 Phase 0 の 0-9 の C・D）。
///
/// **仕掛け。** `Text(timerInterval:)` は、ウィジェット拡張が止まっていても
/// OS が毎秒描き直す唯一のテキスト（`research/B` §S21/S22）。そこに
/// 「偶数の数字は塗りつぶし、奇数の数字は空」を返すフォントを当て、
/// **文字列の右端 1 文字ぶんだけを切り出す**。右端は必ず秒の一の位なので、
/// その偶奇は秒の偶奇と同じ。こうすると ● が 1 秒ごとに出たり消えたりする。
///
/// **合字は使わない。** `research/E` §2.3 は「`:` + 2 桁を合字で 1 グリフに」と
/// 書いているが、手元で試すと **`Text(timerInterval:)` には合字が適用されなかった**
/// （ふつうの `Text("05:24")` では効く）。右端を切り出す方式なら合字が要らない。
///
/// **公式に保証された手法ではない。** Apple がいつ塞いでもおかしくないし、
/// Xcode 26.1 以降の SDK でビルドすると止まるという報告もある（`research/F` §2）。
/// 実機で確かめるためだけのものなので、製品には入れない。
struct MaskedTimerDot: View {

    /// 時刻の起点。ここからの経過秒がフォントに渡る。
    let anchor: Date
    /// 起点をずらす秒数。**これで 1 秒より細かい動きを作る。**
    ///
    /// 0.25 秒ずつずらした 4 本を重ねると、点いている ● の数が
    /// 4→3→2→1→0→1→… と 0.25 秒ごとに変わる。1 秒に 4 回動けば 4fps。
    var offsetSeconds: Double = 0
    /// 偶数の秒で見せるか、奇数の秒で見せるか。
    var showsOnEvenSeconds: Bool = true

    /// マスクの 1 文字ぶんの大きさ。● がすっぽり入る大きさにする。
    private var cell: Double { SpikeDial.dotSize * 1.4 }

    private var fontName: String {
        showsOnEvenSeconds ? "CTSpikeMaskEven" : "CTSpikeMaskOdd"
    }

    var body: some View {
        let start = anchor.addingTimeInterval(-offsetSeconds)
        SpikeDot()
            .frame(width: SpikeDial.dotSize, height: SpikeDial.dotSize)
            .mask(mask(from: start))
    }

    /// タイマーの文字を、**右端 1 文字ぶんだけ**切り出したもの。
    /// 右端は必ず秒の一の位なので、分の桁が何桁になっても崩れない。
    private func mask(from start: Date) -> some View {
        Text(timerInterval: start...start.addingTimeInterval(3600),
             countsDown: false, showsHours: false)
            .font(.custom(fontName, size: cell))
            .lineLimit(1)
            .fixedSize()
            .frame(width: cell, alignment: .trailing)
            .clipped()
            .frame(width: SpikeDial.dotSize, height: SpikeDial.dotSize)
    }
}
