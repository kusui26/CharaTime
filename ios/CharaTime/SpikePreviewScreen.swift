import SwiftUI

/// スパイクの見た目を本体アプリで確かめる画面（`-CTScreen spike`）。
///
/// **これで分かるのは「マスクフォントが正しく効くか」だけ。**
/// アプリは自分で動いているので、`Text(timerInterval:)` が更新されるのは当たり前。
/// スパイクの本題は「**ウィジェット拡張が止まっていても** OS が描き直すか」で、
/// それはホーム画面にウィジェットを置いて実機で見るしかない（`docs/260912_spike.md`）。
///
/// ここで見ておくのは、フォントの合字が効いて ● がきちんと出入りするか。
/// ここで間違っていると、実機で 1 日かけて「動かない」と判定してしまう。
///
/// **スパイク E はいちばん上に置く。** ホーム画面の E と見比べる「正解」なので、
/// 開いてすぐ、スクロールせずに全体が見えるようにする。
struct SpikePreviewScreen: View {

    @State private var anchor = Date()

    var body: some View {
        NavigationStack {
            List {
                probeSection
                Section("C 1 秒ごとの点滅") {
                    HStack(spacing: SpikeDial.dotSpacing) {
                        MaskedTimerDot(anchor: anchor, showsOnEvenSeconds: true)
                        MaskedTimerDot(anchor: anchor, showsOnEvenSeconds: false)
                    }
                    .frame(height: 40)
                    Text("2 つが交互に点きます。両方消えたままなら、フォントが登録されていません。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("D 0.25 秒ずらした 4 本") {
                    HStack(spacing: SpikeDial.dotSpacing) {
                        ForEach(0..<SpikeDial.dotCount, id: \.self) { index in
                            MaskedTimerDot(anchor: anchor,
                                           offsetSeconds: Double(index) * SpikeDial.phaseSeconds)
                        }
                    }
                    .frame(height: 40)
                    Text("点いている数が 4→3→2→1→0→1→… と 0.25 秒ごとに変わります。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("生のタイマー") {
                    Text(timerInterval: anchor...anchor.addingTimeInterval(SpikeDial.timerSpanSeconds),
                         countsDown: false, showsHours: false)
                        .font(.system(size: 34, weight: .semibold, design: .monospaced))
                    Text("マスクをかけない `Text(timerInterval:)`。秒が進むかを見ます。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Text("実機での判定は docs/260912_spike.md の手順で行います。"
                         + "この画面では「フォントが効くか」しか分かりません。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("スパイクの下見")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// E を、ホーム画面の大ウィジェットと同じ大きさで描く。
    ///
    /// **アプリの中では全部うまく動く。** ここの見え方が「正解」で、
    /// ホーム画面の E と見比べて違った行が、C・D を止めている原因を指す。
    private var probeSection: some View {
        Section {
            SpikeFrame(title: "E 切り分け", note: "アプリの中の正解", entryDate: anchor,
                       counterSpanSeconds: DigitCut.dailySpanSeconds) {
                ProbeBoard(anchor: anchor)
            }
            .padding(ProbePreview.contentInset)
            .frame(width: ProbePreview.width, height: ProbePreview.height)
            .background(ProbeLayout.paper, in: RoundedRectangle(cornerRadius: ProbePreview.cornerRadius))
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } header: {
            Text("E 切り分け（アプリの中での正解）")
        } footer: {
            Text("ホーム画面の E と見比べます。ここと違う行が、C・D を止めている原因です。")
        }
    }
}

/// 下見画面で E を描く大きさ。402×874pt の iPhone（17 / 17 Pro）の大ウィジェットに合わせる。
///
/// 値は iOS 26.5 シミュレータで E を置いたときに、chronod が記録した寸法そのもの
/// （`systemLarge::349.67/365.00/27.94`）。内側の余白はウィジェットの既定（16pt）にそろえる。
private enum ProbePreview {
    static let width = 349.67
    static let height: Double = 365
    static let contentInset: Double = 16
    static let cornerRadius = 27.94
}
