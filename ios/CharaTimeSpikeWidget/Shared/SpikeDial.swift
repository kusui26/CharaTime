import SwiftUI

/// スパイクの見た目を 1 か所に集める。
///
/// **キャラクターは使わない**（プラン §9 Phase 0 の 0-9「キャラ不要。● や絵文字でよい」）。
/// 確かめたいのは「絵が動くか」ではなく「OS が描き直してくれるか」の一点なので、
/// 絵が単純なほど、動いたかどうかの判断がはっきりする。
enum SpikeDial {

    /// ● の数。4 つ並べて、いくつ点いているかで速さを読む。
    static let dotCount = 4
    static let dotSize: Double = 26
    static let dotSpacing: Double = 14

    static let lit = Color(red: 0.878, green: 0.541, blue: 0.306)      // #E08A4E
    static let unlit = Color(red: 0.902, green: 0.855, blue: 0.788)    // #E6DAC9
    static let ink = Color(red: 0.231, green: 0.169, blue: 0.169)      // #3B2B2B
}

/// ● 1 つ。
struct SpikeDot: View {

    var isLit: Bool = true

    var body: some View {
        Circle()
            .fill(isLit ? SpikeDial.lit : SpikeDial.unlit)
            .frame(width: SpikeDial.dotSize, height: SpikeDial.dotSize)
    }
}

/// スパイクの枠。表題と、いちばん大事な 2 つの読みを必ず出す。
///
/// - **秒のカウンタ**: `Text(timerInterval:)` をそのまま出したもの。
///   これが進んでいれば、OS はウィジェットを描き直している。
/// - **この絵を作った時刻**: タイムラインのエントリが作られた時刻。
///   秒のカウンタが進んでいるのにこちらが古いままなら、
///   **拡張が動いていないのに画面だけ更新されている**ことになる。それがこの手法の要。
struct SpikeFrame<Content: View>: View {

    let title: String
    let note: String
    let entryDate: Date
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer()
                Text(timerInterval: entryDate...entryDate.addingTimeInterval(3600),
                     countsDown: false, showsHours: false)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
            }
            .foregroundStyle(SpikeDial.ink)

            content.frame(maxWidth: .infinity, alignment: .leading)

            Text("\(note) ・ 絵を作ったのは \(Self.clock(entryDate))")
                .font(.system(size: 10))
                .foregroundStyle(SpikeDial.ink.opacity(0.55))
        }
    }

    /// 秒まで出す。エントリが切り替わった瞬間が分かるように。
    static func clock(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return String(format: "%02d:%02d:%02d",
                      parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
    }
}
