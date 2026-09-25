import Foundation
import CTStore

/// タイムラインを作り直したことを、ウィジェットの記録に残す（プラン §9 Phase 3 の 3-2c）。
///
/// メモリは 2 回測る。タイムラインを渡した直後と、少し待ってから。WidgetKit は渡したあとで
/// エントリの絵を作る（アーカイブする）ので、メモリがいちばん膨らむのはそのあとになる
/// （シミュレータでは、大を渡した時点の 15.6 MB が、絵を作るあいだに 28.8 MB まで膨らんだ）。
///
/// **待つあいだは、拡張を止めさせない**（`performExpiringActivity`）。拡張は仕事を終えると 1 秒ほどで
/// 止められ、ただ待つだけでは 2 回目が次に起こされるまで走らない（シミュレータで確かめた）。
/// 記録は測定の手がかりで、読めても書けなくても描画には関わらない。
enum ReloadRecorder {

    /// 絵を作り終えるのを待つ秒数。シミュレータでは、大を渡してから大と中の絵（146 件）を
    /// 作り終えるまで 2.4 秒だった。そのあいだ拡張は起きたままで、電池にはほぼ響かない。
    private static let settleSeconds: Double = 3

    /// 拡張を止めさせないようにするときの理由（OS のログに出る）。
    private static let activityReason = "ウィジェットの記録"

    static func record(family: WidgetSlot.Family, entries: [HomeEntry]) {
        guard let sample = ProcessMemory.sample() else { return }
        let reload = WidgetReload(date: Date(), family: family, entryCount: entries.count,
                                  footprintBytes: sample.footprintBytes, peakBytes: sample.peakBytes,
                                  pseudoAnimation: entries.first?.motion.pseudoAnimation ?? false)
        DiagnosticsStore.shared.update { $0.recording(reload) }
        ProcessInfo.processInfo.performExpiringActivity(withReason: activityReason) { expired in
            // 止められる間際の呼び出しでは、何もせずに返す（その回は 1 回目の値が残る）。
            guard !expired else { return }
            Thread.sleep(forTimeInterval: settleSeconds)
            guard let later = ProcessMemory.sample() else { return }
            DiagnosticsStore.shared.update { $0.raisingPeak(of: reload, to: later.peakBytes) }
        }
    }
}
