import SwiftUI

/// マスクフォントで ● を出したり消したりする（プラン §9 Phase 0 の 0-9 の C・D、スパイク E の α・β）。
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
    /// 秒の一の位の切り出し方。C・D は当初の作りのまま、E の α・β が直した作りを使う。
    var cut = DigitCut.asBuilt

    /// マスクの 1 文字ぶんの大きさ。● がすっぽり入り、縁が欠けないように少し大きくする。
    private var cell: Double { SpikeDial.dotSize * Self.cellRatio }
    private static let cellRatio = 1.4

    var body: some View {
        SpikeDot()
            .frame(width: SpikeDial.dotSize, height: SpikeDial.dotSize)
            .mask(lastDigit)
    }

    /// タイマーの文字から、**秒の一の位の 1 文字ぶんだけ**を切り出したもの。
    private var lastDigit: some View {
        cut.lastDigit(of: timer, cell: cell)
            .frame(width: SpikeDial.dotSize, height: SpikeDial.dotSize)
    }

    private var timer: MaskFontTimer {
        cut.timer(from: anchor, offsetSeconds: offsetSeconds,
                  showsOnEvenSeconds: showsOnEvenSeconds, size: cell)
    }
}

/// マスク書体で組んだタイマーの文字。C・D・E のどれもが、これを材料にする。
///
/// 上向きに数えることと、1 行に収めることだけをここで決める。
/// **枠の大きさは決めない。** 大きさの決め方こそが C・D の成否を分けたので、
/// 使う側（`DigitCut` と E の各行）がそれぞれ決める。
/// 数える長さと時の出し方の既定は、C・D と同じ（1 時間・分と秒だけ）。
struct MaskFontTimer: View {

    let start: Date
    var showsOnEvenSeconds = true
    let size: Double
    var showsHours = false
    var spanSeconds = SpikeDial.timerSpanSeconds

    var body: some View {
        Text(timerInterval: start...start.addingTimeInterval(spanSeconds),
             countsDown: false, showsHours: showsHours)
            .font(.custom(MaskFont.name(showsOnEvenSeconds: showsOnEvenSeconds), size: size))
            .lineLimit(1)
    }
}

/// マスク書体の名前。`tools/spike/make_mask_fonts.py` が作る。
/// どれも全字が 1em 幅・行の高さも 1em ちょうど。
enum MaskFont {

    /// 偶数の数字（0,2,4,6,8）が 1em の塗りつぶし、奇数は空。
    static let even = "CTSpikeMaskEven"
    /// その裏返し。
    static let odd = "CTSpikeMaskOdd"
    /// 2 と 7 だけが塗りつぶし。秒の一の位に当てると 5 秒に 2 回開く（スパイク F のまばたき）。
    static let set27 = "CTSpikeMaskSet27"
    /// 0・1・2 だけが塗りつぶし。秒の十の位に当てると毎分の前半 30 秒だけ開く（スパイク F の時報の窓）。
    static let set012 = "CTSpikeMaskSet012"
    /// マスクではなく、数字 d を高さ (d+1)/10 em の棒で描く（スパイク F で桁の切り出しを目で確かめる）。
    static let gauge = "CTSpikeGauge"

    static func name(showsOnEvenSeconds: Bool) -> String {
        showsOnEvenSeconds ? even : odd
    }
}

/// 秒の一の位を、タイマーの文字列からどう切り出すか。
///
/// **C・D が点かなかった原因は、切り出す前に当てた `.fixedSize()` だった**
/// （2026-09-23、シミュレータのホーム画面で確認）。ウィジェットの中の
/// `Text(timerInterval:)` に `.fixedSize()` を当てると、枠の幅が有限の値にならない。
/// スパイク E の幅を測る行が、その幅を整数にしようとして拡張ごと落ちたことで分かった。
/// 幅が有限でない枠の「右端 1em」は、画面のどこにも無い。だから何も映らなかった。
/// アプリの中では幅が字にぴったりになるので、下見画面では効いていた。
///
/// E では、タイマー文字自身の枠の幅に頼らない切り出し方を 2 通り試す（α・β）。
/// シミュレータのホーム画面では **α が点き、β は点かなかった**。
enum DigitCut: Sendable {

    /// C・D の作り。字にぴったりの枠（`.fixedSize()`）の右端 1em を切り出す。
    case asBuilt
    /// α: 枠の幅を決め、字をその右端に寄せて、右端 1em を切り出す。
    ///
    /// **丸 1 日、作り直しなしで数え続ける。** 時も出して（最長「24:00:00」の 8 字）、
    /// 枠も 8 字ぶん取る。1 時間で数え終わると点滅も止まり、判定表の
    /// 「1 時間放置」を測れない（止まったのが OS なのか、数え終わっただけなのか分からない）。
    case boundedTrailing
    /// β: 字数を 5 字にそろえ、左から 5 字目を切り出す。
    ///
    /// 枠の幅がどうであれ、左寄せの字は枠の左端から並ぶ。字数が決まっていれば、
    /// 最後の字の位置も決まる。字数は、数え始めを 10 分前にずらしてそろえる。
    ///
    /// **この見立ては外れた**（シミュレータで点かなかった）。`.fixedSize()` を当てた字は、
    /// 左端からでも描かれない（E の ② と同じ）。実機で同じになるかを見る対照として残す。
    case fifthFromLeading

    /// 1 時間を分と秒で数えるときの最長の字数（「60:00」）。β は字数をこれにそろえる。
    static let hourlyGlyphCount = 5
    /// 1 日を時・分・秒で数えるときの最長の字数（「24:00:00」）。α はこの幅の枠を取る。
    static let dailyGlyphCount = 8
    /// α が数える長さ。丸 1 日。
    static let dailySpanSeconds: TimeInterval = 86_400

    /// β で数え始めを前にずらす長さ。10 分。「0:05」（4 字）を「10:05」（5 字）にする。
    /// 1 時間の範囲のうち、置いてから 50 分は 5 字のまま数える。
    static let prerollSeconds: TimeInterval = 600

    /// 切り出し方に合わせて、材料のタイマーを組む。`offsetSeconds` は D・δ の位相ずらし。
    func timer(from anchor: Date, offsetSeconds: Double,
               showsOnEvenSeconds: Bool, size: Double) -> MaskFontTimer {
        let preroll = self == .fifthFromLeading ? Self.prerollSeconds : 0
        let start = anchor.addingTimeInterval(-offsetSeconds - preroll)
        guard self == .boundedTrailing else {
            return MaskFontTimer(start: start, showsOnEvenSeconds: showsOnEvenSeconds, size: size)
        }
        return MaskFontTimer(start: start, showsOnEvenSeconds: showsOnEvenSeconds, size: size,
                             showsHours: true, spanSeconds: Self.dailySpanSeconds)
    }

    /// タイマーの文字から、秒の一の位の 1em ぶんだけを切り出す。
    @ViewBuilder
    func lastDigit(of timer: MaskFontTimer, cell: Double) -> some View {
        switch self {
        case .asBuilt:
            timer.fixedSize()
                .frame(width: cell, alignment: .trailing)
                .clipped()
        case .boundedTrailing:
            timer.multilineTextAlignment(.trailing)
                .frame(width: cell * Double(Self.dailyGlyphCount), alignment: .trailing)
                .frame(width: cell, alignment: .trailing)
                .clipped()
        case .fifthFromLeading:
            timer.fixedSize()
                .offset(x: -cell * Double(Self.hourlyGlyphCount - 1))
                .frame(width: cell, alignment: .leading)
                .clipped()
        }
    }
}
