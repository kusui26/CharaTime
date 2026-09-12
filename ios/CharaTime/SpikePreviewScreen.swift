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
struct SpikePreviewScreen: View {

    @State private var anchor = Date()

    var body: some View {
        NavigationStack {
            List {
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
                            MaskedTimerDot(anchor: anchor, offsetSeconds: Double(index) * 0.25)
                        }
                    }
                    .frame(height: 40)
                    Text("点いている数が 4→3→2→1→0→1→… と 0.25 秒ごとに変わります。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("生のタイマー") {
                    Text(timerInterval: anchor...anchor.addingTimeInterval(3600),
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
}
