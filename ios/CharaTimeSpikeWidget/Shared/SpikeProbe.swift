import SwiftUI

/// スパイク E の中身。C・D が点かなかった理由を、1 枚のウィジェットで切り分ける。
///
/// C・D は実機のホーム画面で一度も点かなかったが、秒のカウンタは進んでいた
/// （`docs/260912_spike.md` 3-4）。原因の候補は 3 つあり、見た目では区別できなかった。
///
/// - (a) 拡張の中で書体が登録されていない
/// - (b) 書体は効いているが、切り出した窓が字から外れている
/// - (c) 毎秒更新されるタイマー文字を、マスクの材料にできない
///
/// ①〜④ で原因を見分け、α〜δ で直し方を試す。シミュレータのホーム画面では (b) だった。
/// `.fixedSize()` を当てたタイマー文字の枠の幅が、有限の値にならない（`DigitCut`）。
///
/// **幅は測らない。** 有限でない枠に `GeometryReader` を当てると、SwiftUI の中の検査で
/// 拡張ごと落ちる（シミュレータで 2 度落ちて分かった）。E は A〜D と同じプロセスで動くので、
/// 落ちれば A〜D まで巻き添えになる。有限でない枠に触れる所は、実機で落ちずに動いている
/// C・D と同じ形（決まった幅の枠に入れて切り取る）だけで組む。
///
/// **ウィジェットと、本体アプリの下見画面の両方で同じものを描く。**
/// 下見画面の見え方が「すべてうまくいったときの正解」で、ホーム画面との差が答えになる。
struct ProbeBoard: View {

    let anchor: Date

    var body: some View {
        VStack(alignment: .leading, spacing: ProbeLayout.rowSpacing) {
            ProbeRow("① 止まった字") { ProbeWindow { stillText } }
            ProbeRow("② 動く字") { ProbeWindow { liveText.fixedSize() } }
            ProbeRow("③ 動く字・枠あり") { ProbeWindow { boundedLiveText } }
            ProbeRow("④ マスク 動｜止") { maskBars }
            ProbeRow("α 枠あり右寄せ") { dotPair(cut: .boundedTrailing) }
            ProbeRow("β 左から5字目") { dotPair(cut: .fifthFromLeading) }
            ProbeRow("γ マスクなし") { glyphPair }
            ProbeRow("δ 4本ずらし") { glyphQuartet }
        }
    }

    /// ① と ④ の右に使う、動かない字。書体が効いていれば「■ ▯ ▯ ■ ■」に見える
    /// （偶数の書体なので、0 と 2 と 4 が塗りつぶし、5 と `:` が空）。
    private var stillText: some View {
        Text(verbatim: ProbeLayout.stillSample)
            .font(.custom(MaskFont.even, size: ProbeLayout.fontSize))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(SpikeDial.ink)
    }

    /// ② の材料。C・D と同じタイマーの文字（1 時間・分と秒）を、切り出さずにそのまま出す。
    private var liveText: some View {
        MaskFontTimer(start: anchor, size: ProbeLayout.fontSize)
            .foregroundStyle(SpikeDial.ink)
    }

    /// ③ と ④ の左の材料。α と同じ組み方（1 日・時も出す）で、枠を 8 字ぶんに決めて右に寄せる。
    private var boundedLiveText: some View {
        DigitCut.boundedTrailing
            .timer(from: anchor, offsetSeconds: 0, showsOnEvenSeconds: true, size: ProbeLayout.fontSize)
            .multilineTextAlignment(.trailing)
            .frame(width: ProbeLayout.liveBarWidth, alignment: .trailing)
            .foregroundStyle(SpikeDial.ink)
    }

    /// ④ 同じ字をマスクにして、橙の帯から色を抜く。左は動く字（③ と同じ）、右は止まった字（対照）。
    /// 動く字でも、枠を決めてあればマスクの材料になるかを見る。
    private var maskBars: some View {
        HStack(spacing: ProbeLayout.pairSpacing) {
            maskedBar(width: ProbeLayout.liveBarWidth) { boundedLiveText }
            maskedBar(width: ProbeLayout.stillBarWidth) { stillText }
        }
    }

    /// 薄い帯の上に、マスクをかけた橙の帯を重ねる。何も抜けなければ薄い帯だけが残る。
    private func maskedBar<Mask: View>(width: Double, @ViewBuilder _ mask: () -> Mask) -> some View {
        let shape = mask()
        return ZStack(alignment: .leading) {
            bar(SpikeDial.unlit, width: width)
            bar(SpikeDial.lit, width: width).mask(alignment: .leading) { shape }
        }
    }

    private func bar(_ color: Color, width: Double) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: width, height: ProbeLayout.fontSize)
    }

    /// α・β: C と同じ ● の組を、直した切り出し方で。薄い ● の上に重ねるので、
    /// 点かなければ C と同じく「薄い丸が 2 つ」に見える。同じ言葉で見比べられる。
    private func dotPair(cut: DigitCut) -> some View {
        HStack(spacing: SpikeDial.dotSpacing) {
            ForEach([true, false], id: \.self) { evenSeconds in
                ZStack {
                    SpikeDot(isLit: false)
                    MaskedTimerDot(anchor: anchor, showsOnEvenSeconds: evenSeconds, cut: cut)
                }
            }
        }
    }

    /// γ: マスクを使わず、字そのものを ■ にする。偶数の秒と奇数の秒で 1 つずつ。
    private var glyphPair: some View {
        HStack(spacing: SpikeDial.dotSpacing) {
            ForEach([true, false], id: \.self) { evenSeconds in
                GlyphSocket {
                    BareTimerGlyph(anchor: anchor, showsOnEvenSeconds: evenSeconds, cut: ProbeLayout.bareCut)
                }
            }
        }
    }

    /// δ: γ の作りで、起点を 0.25 秒ずつずらした 4 本。点いている数が 0.25 秒ごとに変わる。
    private var glyphQuartet: some View {
        HStack(spacing: SpikeDial.dotSpacing) {
            ForEach(0..<SpikeDial.dotCount, id: \.self) { index in
                GlyphSocket {
                    BareTimerGlyph(anchor: anchor,
                                   offsetSeconds: Double(index) * SpikeDial.phaseSeconds,
                                   cut: ProbeLayout.bareCut)
                }
            }
        }
    }
}

/// マスクを使わず、**字そのものを ■ にして**点滅させる（E の γ・δ）。
///
/// マスク書体の偶数（または奇数）の数字は 1em の塗りつぶしなので、1 字ぶんを
/// 切り出せば、それだけで 1 秒ごとに出たり消えたりする ■ になる。
/// α・β が点かないとき、止めているのが「マスク」なのか「切り出し」なのかをこれで分ける。
struct BareTimerGlyph: View {

    let anchor: Date
    var offsetSeconds: Double = 0
    var showsOnEvenSeconds = true
    let cut: DigitCut

    var body: some View {
        cut.lastDigit(of: timer, cell: SpikeDial.dotSize)
            .foregroundStyle(SpikeDial.lit)
            .frame(width: SpikeDial.dotSize, height: SpikeDial.dotSize)
    }

    private var timer: MaskFontTimer {
        cut.timer(from: anchor, offsetSeconds: offsetSeconds,
                  showsOnEvenSeconds: showsOnEvenSeconds, size: SpikeDial.dotSize)
    }
}

/// γ・δ の ■ の下に敷く薄い台。点かなくても、どこに出るはずだったかが見える。
struct GlyphSocket<Glyph: View>: View {

    @ViewBuilder let glyph: Glyph

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ProbeLayout.socketCornerRadius)
                .fill(SpikeDial.unlit)
                .frame(width: SpikeDial.dotSize, height: SpikeDial.dotSize)
            glyph
        }
    }
}

/// E の 1 行。左に「何を見る行か」の札、右にその中身。
struct ProbeRow<Content: View>: View {

    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(spacing: ProbeLayout.labelGap) {
            Text(label)
                .font(.system(size: ProbeLayout.labelFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(SpikeDial.ink)
                .lineLimit(1)
                .minimumScaleFactor(ProbeLayout.labelMinimumScale)
                .frame(width: ProbeLayout.labelWidth, alignment: .leading)
            content
        }
    }
}

/// ①〜③ の覗き窓。決まった幅の窓に字を左から入れ、窓の外は切り取る。
///
/// **窓の地の色が、字のない所を見せる。** ①〜③ の字がどこに並ぶか（左から始まるか、
/// 右に寄るか、そもそも出るか）を、アプリの中の正解と見比べて読む。
///
/// 決まった幅の枠に入れて切り取る形は、実機で落ちずに動いている C・D と同じ。
/// 字の枠の幅が有限でなくても、窓の大きさは変わらない。
struct ProbeWindow<Content: View>: View {

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(width: ProbeLayout.windowWidth, alignment: .leading)
            .clipped()
            .background(ProbeLayout.windowTint)
    }
}

/// E の寸法と色。帯の幅は「字数 × 字の大きさ」から導く（全字が 1em 幅なので）。
enum ProbeLayout {

    /// ①〜④ の字の大きさ。1 字 = 16pt で並ぶ。④ の帯 2 本（8 字と 5 字）が 1 行に収まる大きさ。
    static let fontSize: Double = 16
    /// ① と ④ の右に使う動かない字。偶数・奇数の数字と `:` を含み、分と秒のタイマーと同じ形。
    static let stillSample = "05:24"
    /// ③ と ④ の左の帯の幅。α と同じ 8 字ぶん。
    static let liveBarWidth = fontSize * Double(DigitCut.dailyGlyphCount)
    /// ④ の右の帯の幅。動かない字（5 字）がちょうど収まる。
    static let stillBarWidth = fontSize * Double(stillSample.count)
    /// ①〜③ の覗き窓の幅。③ の 8 字（128pt）より広く取り、字の外側も見えるようにする。
    static let windowWidth: Double = 150
    /// γ・δ（マスクなし）で使う切り出し方。α と同じ（シミュレータのウィジェットで点いたほう）。
    static let bareCut = DigitCut.boundedTrailing

    static let rowSpacing: Double = 6
    static let pairSpacing: Double = 10
    static let labelWidth: Double = 84
    static let labelGap: Double = 8
    static let labelFontSize: Double = 10
    /// 札が収まらないときに、字をどこまで縮めてよいか。
    static let labelMinimumScale = 0.8
    static let socketCornerRadius: Double = 4

    /// E の地の色。**明暗どちらの外観でも同じ明るい地**にして、細い数字まで読めるようにする。
    static let paper = Color(red: 0.980, green: 0.961, blue: 0.929)    // #FAF5ED
    /// 覗き窓の地の色。字（濃い茶）とも、盤面の地とも、マスクの帯（橙）とも見分けがつく青。
    static let windowTint = Color(red: 0.765, green: 0.859, blue: 0.945)  // #C3DBF1
}
