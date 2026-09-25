import Foundation

/// このプロセスのメモリ（プラン §9 Phase 3 の 3-2c）。ウィジェット拡張が自分を測るのに使う。
///
/// 見るのは `phys_footprint`（OS がメモリの上限と比べる値。ウィジェット拡張は約 30 MB を超えると
/// 落とされる）と、その最大値（`ledger_phys_footprint_peak`。プロセスが起きてからの最大）。
/// シミュレータで使った `vmmap` の「Physical footprint」と同じ値で、実機でも読める。
public enum ProcessMemory {

    public struct Sample: Sendable, Equatable {
        public let footprintBytes: UInt64
        public let peakBytes: UInt64
    }

    /// いまの値と最大値。読めなければ nil。
    public static func sample() -> Sample? {
        var info = task_vm_info_data_t()
        let fullCount = MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        var count = mach_msg_type_number_t(fullCount)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: fullCount) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        // 最大値の欄は、古い OS では返ってこない（返ってきた長さで分かる）。無ければいまの値で代える。
        // この欄だけ符号付きなので、負の値（読めなかった印）は 0 に寄せる。
        let peak = count >= peakFieldCount
            ? UInt64(clamping: info.ledger_phys_footprint_peak) : info.phys_footprint
        return Sample(footprintBytes: info.phys_footprint, peakBytes: Swift.max(peak, info.phys_footprint))
    }

    /// 最大値の欄まで読むのに要る長さ（`natural_t` の個数）。
    private static var peakFieldCount: mach_msg_type_number_t {
        let offset = MemoryLayout<task_vm_info_data_t>.offset(of: \.ledger_phys_footprint_peak) ?? 0
        return mach_msg_type_number_t((offset + MemoryLayout<UInt64>.size) / MemoryLayout<natural_t>.size)
    }
}
