import SwiftUI

/// スパイク F の部品（プラン §9 Phase 3 の 3-0b）。本番の疑似アニメの組み方を、数えられる形で確かめる。
///
/// - **F の小（1・2・4・6・8・14 本）**: タイマーの本数と、ホーム画面に戻った直後の動き出しの遅れ（D-17）。
///   点は 0.25 秒ずつずらして並べるので、どの本数でも（4 本以上なら）0.25 秒ごとにどれかが切り替わる。
///   戻った直後に切り替わりが止まっていた長さを、画面収録から `scripts/home-screen.sh` が数える
/// - **F の大（組み方）**: 0 時起点（D-18）・桁の切り出し・入れ子のマスクの「かつ」・エントリ切替との相性
///
/// **どのタイマーも「その日の 0 時」から数える（D-18）。** 表示は時刻そのもの（「15:32:11」）になり、
/// 右端の字は壁時計の秒の一の位になる。本番と同じ組み方なので、数えた結果を壁時計と突き合わせられる。
enum MidnightClock {

    /// 数える長さ。0 時から 36 時間、つまり翌日の昼まで、作り直しなしで数え続ける（D-18）。
    static let spanSeconds: TimeInterval = 36 * 3600
    /// 最長の字数（「35:59:59」）。枠はこの字数ぶん取って右に寄せる。
    static let glyphCount = 8

    /// エントリの日付の 0 時。**日をまたいだエントリは翌日の 0 時**になる（プラン 3-C ④ 原則 2）。
    static func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}

/// その日の 0 時から数えるタイマーの文字（D-18）。
///
/// `advanceSeconds` だけ起点を前に置くと、表示がそのぶん進む。0.25 秒ずつ進めた 4 本を並べると、
/// 1 秒に 4 回どれかが切り替わる（1 秒より細かい動き。§9 Phase 3 の 3-C ④ 原則 3）。
struct MidnightTimerText: View {

    let date: Date
    var advanceSeconds: Double = 0
    let font: Font

    var body: some View {
        Text(timerInterval: start...start.addingTimeInterval(MidnightClock.spanSeconds),
             countsDown: false, showsHours: true)
            .font(font)
            .lineLimit(1)
    }

    private var start: Date {
        MidnightClock.startOfDay(for: date).addingTimeInterval(-advanceSeconds)
    }
}

/// タイマーの文字から、**右から数えて `index` 字目**の 1 字ぶんだけを切り出す（0 = 秒の一の位）。
///
/// 8 字ぶんの枠に右寄せで並べ、`index` 字ぶん右へずらしてから、右端 1 字の窓で切り取る。
/// 枠の幅を決めているので、ウィジェットの中でも描かれる（`.fixedSize()` は使わない。スパイク E の教訓）。
/// 「15:32:11」なら、0 = 秒の一の位、1 = 秒の十の位、2 = `:`、3 = 分の一の位。
struct GlyphWindow<Glyphs: View>: View {

    let index: Int
    let cell: Double
    @ViewBuilder let glyphs: Glyphs

    var body: some View {
        glyphs.multilineTextAlignment(.trailing)
            .frame(width: cell * Double(MidnightClock.glyphCount), alignment: .trailing)
            .offset(x: cell * Double(index))
            .frame(width: cell, height: cell, alignment: .trailing)
            .clipped()
    }
}

/// マスク書体で組んだ窓。書体の数字の集まりに入っているあいだだけ、1em の四角になる。
struct TimerMask: View {

    let date: Date
    let font: String
    var index = 0
    var advanceSeconds: Double = 0
    let cell: Double

    var body: some View {
        GlyphWindow(index: index, cell: cell) {
            MidnightTimerText(date: date, advanceSeconds: advanceSeconds, font: .custom(font, size: cell))
        }
    }
}

/// 薄い台の上に、マスクで出し入れする ● を重ねる。点かなければ台だけが見える。
struct MaskedDot<Mask: View>: View {

    let size: Double
    @ViewBuilder let mask: Mask

    var body: some View {
        ZStack {
            Circle().fill(SpikeDial.unlit)
            Circle().fill(SpikeDial.lit).mask { mask }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - F の小: タイマーの本数

/// タイマーを `count` 本だけ抱えた盤。1 本が ● 1 つ。
///
/// k 番目の ● は、起点を (k mod 4) × 0.25 秒進め、4 つごとに偶数・奇数を入れ替える。
/// 4 本以上あれば 0.25 秒ごとにどれかが切り替わるので、動き出しの遅れを 0.25 秒の細かさで測れる。
/// **ほかにタイマーを置かない**（表題の横の秒のカウンタも無い）。本数がそのまま `count` になる。
struct TimerCountBoard: View {

    let count: Int
    let entryDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: MeasureLayout.rowSpacing) {
            Text("F \(count) 本")
                .font(.system(size: MeasureLayout.titleSize, weight: .bold, design: .rounded))
            VStack(alignment: .leading, spacing: MeasureLayout.dotSpacing) {
                ForEach(Array(stride(from: 0, to: count, by: MeasureLayout.columns)), id: \.self) { first in
                    HStack(spacing: MeasureLayout.dotSpacing) {
                        ForEach(first..<min(first + MeasureLayout.columns, count), id: \.self, content: dot)
                    }
                }
            }
            Spacer(minLength: 0)
            Text("絵を作ったのは \(SpikeFrame<EmptyView>.clock(entryDate))")
                .font(.system(size: MeasureLayout.noteSize))
                .opacity(MeasureLayout.noteOpacity)
        }
        .foregroundStyle(SpikeDial.ink)
    }

    /// k 番目の ●。起点を (k mod 4) × 0.25 秒進め、4 つごとに偶数・奇数を入れ替える。
    private func dot(_ index: Int) -> some View {
        MaskedDot(size: MeasureLayout.dotSize) {
            TimerMask(date: entryDate,
                      font: MaskFont.name(showsOnEvenSeconds: index / SpikeDial.dotCount % 2 == 0),
                      advanceSeconds: Double(index % SpikeDial.dotCount) * SpikeDial.phaseSeconds,
                      cell: MeasureLayout.dotSize)
        }
    }
}

// MARK: - F の大: 組み方

/// 本番の組み方を 1 枚で確かめる盤（大）。
///
/// | 行 | 何を出すか | 何が分かるか |
/// |---|---|---|
/// | 時計 | 0 時起点のタイマーを素の書体で | 表示が壁時計と同じ時刻になるか（D-18） |
/// | 桁 | 同じタイマーを棒の書体で。右に、秒の一の位・十の位・分の一の位を切り出したもの | 桁の切り出しが正しいか |
/// | まばたき | 集まり {2, 7} の窓を、0.75 秒進めた窓と「かつ」で重ねる | 5 秒に 2 回、0.25 秒だけ点くか |
/// | 30 秒 | 集まり {0, 1, 2} を秒の十の位に | 毎分の前半 30 秒だけ点くか（時報の窓） |
/// | 台 | 1 分ごとのエントリで左右に動く台と、その上で 1 秒ごとにまばたく目 | エントリ切替のアニメとタイマーの相性 |
struct DesignBoard: View {

    let entryDate: Date
    /// 台が右にいるか。1 分ごとのエントリで入れ替わる。
    let movedRight: Bool

    private let cell = MeasureLayout.designCell

    var body: some View {
        VStack(alignment: .leading, spacing: MeasureLayout.designRowSpacing) {
            ProbeRow("時計 0 時起点") { MidnightTimerText(date: entryDate, font: MeasureLayout.clockFont) }
            ProbeRow("桁 棒の高さ") { gauge }
            ProbeRow("まばたき かつ") { blink }
            ProbeRow("30 秒の窓") {
                MaskedDot(size: cell) {
                    TimerMask(date: entryDate, font: MaskFont.set012, index: 1, cell: cell)
                }
            }
            ProbeRow("台 1 分ごと") { MovingBlock(entryDate: entryDate, movedRight: movedRight) }
            Text("絵を作ったのは \(SpikeFrame<EmptyView>.clock(entryDate))")
                .font(.system(size: MeasureLayout.noteSize))
                .opacity(MeasureLayout.noteOpacity)
        }
        .foregroundStyle(SpikeDial.ink)
    }

    /// 時刻を棒の高さで。左は 8 字をそのまま、右は右から 0・1・3 字目を 1 字ずつ切り出したもの。
    /// 「15:32:11」なら、右の 3 本は 1・1・2（秒の一の位・十の位・分の一の位）の高さになる。
    private var gauge: some View {
        let gaugeCell = MeasureLayout.gaugeCell
        return HStack(spacing: MeasureLayout.gaugeGap) {
            MidnightTimerText(date: entryDate, font: .custom(MaskFont.gauge, size: gaugeCell))
                .multilineTextAlignment(.trailing)
                .frame(width: gaugeCell * Double(MidnightClock.glyphCount), alignment: .trailing)
                .background(SpikeDial.unlit.opacity(MeasureLayout.gaugeTrackOpacity))
            ForEach([0, 1, 3], id: \.self) { index in
                GlyphWindow(index: index, cell: gaugeCell) {
                    MidnightTimerText(date: entryDate, font: .custom(MaskFont.gauge, size: gaugeCell))
                }
                .background(SpikeDial.unlit)
            }
        }
    }

    /// 5 秒に 2 回（x2 秒と x7 秒）、その頭の 0.25 秒だけ点く ●。左は片方の窓だけの対照（1 秒点く）。
    private var blink: some View {
        HStack(spacing: MeasureLayout.gaugeGap) {
            MaskedDot(size: cell) { TimerMask(date: entryDate, font: MaskFont.set27, cell: cell) }
            MaskedDot(size: cell) {
                TimerMask(date: entryDate, font: MaskFont.set27, cell: cell)
                    .mask {
                        TimerMask(date: entryDate, font: MaskFont.set27,
                                  advanceSeconds: MeasureLayout.andAdvanceSeconds, cell: cell)
                    }
            }
        }
    }
}

/// 1 分ごとのエントリで左右に動く台。**台の上の目は、台と一緒に動くタイマーのマスク。**
///
/// 本番の「居場所の移動はエントリ切替の 2 秒で見せる」（3-C ④'）と同じ組み方。
/// 動いているあいだも目がまばたき続けるか、切り替わりの瞬間に目がちらつかないかを見る。
struct MovingBlock: View {

    let entryDate: Date
    let movedRight: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MeasureLayout.blockCornerRadius)
                .fill(SpikeDial.ink.opacity(MeasureLayout.blockOpacity))
            // 目は橙にしない。数える道具は橙のかたまりを「動かない点」として読むので、動く目を混ぜない。
            Circle().fill(SpikeDial.ink)
                .frame(width: MeasureLayout.eyeSize, height: MeasureLayout.eyeSize)
                .mask {
                    TimerMask(date: entryDate, font: MaskFont.even, cell: MeasureLayout.eyeSize)
                }
        }
        .frame(width: MeasureLayout.blockSize, height: MeasureLayout.blockSize)
        .frame(width: MeasureLayout.trackWidth, alignment: movedRight ? .trailing : .leading)
        .animation(.easeInOut(duration: MeasureLayout.moveSeconds), value: movedRight)
    }
}

// MARK: - G: 透け方（3-0c）

/// スパイク G の盤。背景（`containerBackground`）だけを変えた 3 枚で、ホーム画面の壁紙がどう見えるかを比べる。
///
/// `research/B` §2.2 の未確認事項。`Color.clear`・`EmptyView()`・ほぼ透明の白を背景にしたとき、
/// 本当に壁紙が透けるのか、OS が板を敷くのかを、シミュレータと実機のスクリーンショットで見る。
struct ClearProbe: View {

    let label: String

    var body: some View {
        VStack(spacing: MeasureLayout.rowSpacing) {
            Text("G").font(.system(size: MeasureLayout.titleSize, weight: .bold, design: .rounded))
            Text(label).font(.system(size: MeasureLayout.noteSize, design: .monospaced))
        }
        .foregroundStyle(SpikeDial.ink)
        .padding(MeasureLayout.clearProbePadding)
        .background(ProbeLayout.paper.opacity(MeasureLayout.clearProbeLabelOpacity),
                    in: RoundedRectangle(cornerRadius: MeasureLayout.blockCornerRadius))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            // 枠の四隅に目印。透けていても、ウィジェットがどこにあるかが分かる。
            RoundedRectangle(cornerRadius: MeasureLayout.clearProbeCornerRadius)
                .strokeBorder(SpikeDial.lit, lineWidth: MeasureLayout.clearProbeStroke)
        }
    }
}

/// F と G の寸法。小は 164pt 角、大は 350×365pt（iOS 26.5 の実測）に収める。
enum MeasureLayout {

    // F の小
    /// 1 行に並べる ● の数。14 本でも 4 行に収まる。
    static let columns = 4
    static let dotSize: Double = 20
    static let dotSpacing: Double = 9
    static let rowSpacing: Double = 6
    static let titleSize: Double = 13
    static let noteSize: Double = 9
    static let noteOpacity = 0.55

    // F の大
    static let designCell: Double = 24
    /// 桁の棒の 1 字。8 字の並びと切り出し 3 つを、札（84pt）の右の 225pt に収める大きさ。
    static let gaugeCell: Double = 16
    static let designRowSpacing: Double = 10
    static let clockFont = Font.system(size: 20, weight: .semibold, design: .monospaced)
    static let gaugeGap: Double = 8
    static let gaugeTrackOpacity = 0.5
    /// 「かつ」で重ねる窓の進め方。0.75 秒進めた窓と重ねると、元の窓の頭 0.25 秒だけが残る。
    static let andAdvanceSeconds = 0.75
    static let blockSize: Double = 40
    static let eyeSize: Double = 14
    static let blockCornerRadius: Double = 8
    static let blockOpacity = 0.18
    /// 台が動く幅。左端から右端まで、ウィジェットの横幅の 6 割ほど。
    static let trackWidth: Double = 170
    /// エントリ切替で台が動く時間。公式の上限 2 秒に収める（3-C ④'）。
    static let moveSeconds = 1.5

    // G
    static let clearProbePadding: Double = 8
    static let clearProbeLabelOpacity = 0.85
    static let clearProbeCornerRadius: Double = 22
    static let clearProbeStroke: Double = 3
}
