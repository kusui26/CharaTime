import Testing
import Foundation
@testable import CTStore

/// ウィジェット拡張が残す記録（プラン §9 Phase 3 の 3-2c）。実機でメモリと作り直しの間隔を読むため。
@Suite("ウィジェットの記録")
struct WidgetDiagnosticsTests {

    /// 2026-09-25 9:00（日本時間）。
    static let nine = Date(timeIntervalSince1970: 1_790_294_400)

    static func reload(_ minutes: Double, _ family: WidgetSlot.Family = .large,
                       footprint: UInt64 = 10_000_000, peak: UInt64 = 12_000_000) -> WidgetReload {
        WidgetReload(date: nine.addingTimeInterval(minutes * 60), family: family, entryCount: 73,
                     footprintBytes: footprint, peakBytes: peak, pseudoAnimation: true)
    }

    // MARK: - 記録

    @Test("上限を超えたら、古いものから捨てる")
    func keepsTheNewest() {
        let many = (0..<(WidgetDiagnostics.capacity + 5)).map { Self.reload(Double($0)) }
        let diagnostics = many.reduce(WidgetDiagnostics()) { $0.recording($1) }
        #expect(diagnostics.reloads.count == WidgetDiagnostics.capacity)
        #expect(diagnostics.reloads.first == many[5])
        #expect(diagnostics.reloads.last == many.last)
    }

    /// 1 回目は渡した直後、2 回目は絵を作り終えたころに測る。最大値は下がらない。
    @Test("あとで測った最大値で、同じ作り直しの記録だけを引き上げる")
    func raisesThePeakOfTheSameReload() {
        let first = Self.reload(0, .large, peak: 12_000_000)
        let other = Self.reload(0, .medium, peak: 11_000_000)
        let diagnostics = WidgetDiagnostics().recording(first).recording(other)
        let raised = diagnostics.raisingPeak(of: first, to: 15_000_000)
        #expect(raised.reloads[0].peakBytes == 15_000_000)
        #expect(raised.reloads[1].peakBytes == 11_000_000)
        #expect(raised.raisingPeak(of: first, to: 9_000_000) == raised)
        #expect(diagnostics.raisingPeak(of: Self.reload(99), to: 20_000_000) == diagnostics)
    }

    // MARK: - まとめ

    /// 24 時間の窓の端: ちょうど 24 時間前は入れず、その 1 秒あとからは入れる。
    static let dayAgo: Double = -24 * 60
    static let justInsideDay: Double = dayAgo + 1.0 / 60

    @Test("大きさごとに、最後の作り直しと 24 時間の回数をまとめる（大・中・小の順）")
    func summarizesEachFamily() throws {
        let diagnostics = [
            Self.reload(Self.dayAgo, .large),
            Self.reload(Self.justInsideDay, .large),
            Self.reload(-60, .medium),
            Self.reload(0, .large),
        ].reduce(WidgetDiagnostics()) { $0.recording($1) }
        let summaries = diagnostics.summaries(now: Self.nine)
        #expect(summaries.map(\.family) == [.large, .medium])
        let large = try #require(summaries.first)
        #expect(large.lastReload == Self.reload(0, .large))
        #expect(large.reloadsInLastDay == 2)
        #expect(summaries[1].reloadsInLastDay == 1)
        #expect(WidgetDiagnostics().summaries(now: Self.nine).isEmpty)
    }

    /// 拡張は大・中・小を 1 つのプロセスで作るので、メモリは大きさを分けずに 1 つの値で見る。
    @Test("メモリの最大値は、大きさを分けずに 24 時間の中から取る。記録が無ければ nil")
    func peakOverTheLastDay() {
        let diagnostics = [
            Self.reload(Self.dayAgo, .large, peak: 18_000_000),
            Self.reload(Self.justInsideDay, .medium, peak: 16_000_000),
            Self.reload(0, .large, peak: 12_000_000),
        ].reduce(WidgetDiagnostics()) { $0.recording($1) }
        #expect(diagnostics.peakBytes(now: Self.nine) == 16_000_000)
        #expect(diagnostics.peakBytes(now: Self.nine.addingTimeInterval(2 * 86_400)) == nil)
        #expect(WidgetDiagnostics().peakBytes(now: Self.nine) == nil)
    }

    @Test("新しい順に、指定した件数だけ取り出せる")
    func latestComesFirst() {
        let diagnostics = (0..<5).map { Self.reload(Double($0)) }.reduce(WidgetDiagnostics()) { $0.recording($1) }
        #expect(diagnostics.latest(3).map(\.date) == [4, 3, 2].map { Self.nine.addingTimeInterval($0 * 60) })
        #expect(diagnostics.latest(10).count == 5)
    }

    // MARK: - 読み書き

    private func makeStore() throws -> (DiagnosticsStore, URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ct-diagnostics-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (DiagnosticsStore(directory: dir), dir)
    }

    @Test("書いて読むと同じ記録が戻る")
    func roundTrip() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        store.update { $0.recording(Self.reload(0)) }
        store.update { $0.recording(Self.reload(5, .medium)) }
        #expect(store.load().reloads == [Self.reload(0), Self.reload(5, .medium)])
    }

    /// 記録のために拡張を落とさない。読めなければ空、書けなければ何もしない（CLAUDE.md §2）。
    @Test("置き場が無い・ファイルが無い・壊れているときは、空として読む")
    func neverFailsToLoad() throws {
        let nowhere = DiagnosticsStore(directory: nil)
        nowhere.update { $0.recording(Self.reload(0)) }
        #expect(nowhere.load() == WidgetDiagnostics())

        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(store.load() == WidgetDiagnostics())
        let fileURL = try #require(store.fileURL)
        try Data("{ 壊れた JSON".utf8).write(to: fileURL)
        #expect(store.load() == WidgetDiagnostics())
        store.update { $0.recording(Self.reload(0)) }
        #expect(store.load().reloads == [Self.reload(0)])
    }

    // MARK: - メモリ

    @Test("このプロセスのメモリを測れる（最大値は、いまの値以上）")
    func samplesProcessMemory() throws {
        let sample = try #require(ProcessMemory.sample())
        #expect(sample.footprintBytes > 0)
        #expect(sample.peakBytes >= sample.footprintBytes)
    }
}
