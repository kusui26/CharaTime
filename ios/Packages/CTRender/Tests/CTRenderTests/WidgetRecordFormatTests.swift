import Testing
import Foundation
import CTStore
@testable import CTRender

/// 設定画面の「ウィジェットの記録」の見せ方（プラン §9 Phase 3 の 3-2c）。
@Suite("ウィジェットの記録の見せ方")
struct WidgetRecordFormatTests {

    static let tokyo: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    static func date(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        tokyo.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    /// シミュレータで使った `vmmap` と同じく、1 MB = 1024 × 1024 バイトで数える。
    @Test("メモリは MB（1024 × 1024 バイト）の小数 1 桁で見せる")
    func megabytes() {
        #expect(WidgetRecordFormat.megabytes(12_897_485) == "12.3 MB")
        #expect(WidgetRecordFormat.megabytes(31_457_280) == "30.0 MB")
        #expect(WidgetRecordFormat.megabytes(0) == "0.0 MB")
    }

    @Test("時刻は、きょうなら時と分だけ、ほかの日は月日も付ける")
    func times() {
        let now = Self.date(25, 9, 30)
        #expect(WidgetRecordFormat.time(Self.date(25, 9, 21), now: now, calendar: Self.tokyo) == "9:21")
        #expect(WidgetRecordFormat.time(Self.date(25, 0, 0), now: now, calendar: Self.tokyo) == "0:00")
        #expect(WidgetRecordFormat.time(Self.date(24, 23, 5), now: now, calendar: Self.tokyo) == "9/24 23:05")
    }

    @Test("大きさは、小・中・大で見せる")
    func familyNames() {
        #expect(WidgetSlot.Family.allCases.map(WidgetRecordFormat.familyName) == ["小", "中", "大"])
    }

    /// 1 件なら同梱データが読めなかったしるし、設定が入なのに「止め」なら書体を疑う。
    @Test("作ったタイムラインは、件数と、動くか止めかで見せる")
    func timelines() {
        func reload(entries: Int, moving: Bool) -> WidgetReload {
            WidgetReload(date: Self.date(25, 9, 0), family: .large, entryCount: entries,
                         footprintBytes: 0, peakBytes: 0, pseudoAnimation: moving)
        }
        #expect(WidgetRecordFormat.timeline(reload(entries: 73, moving: true)) == "73 件・動く")
        #expect(WidgetRecordFormat.timeline(reload(entries: 1, moving: false)) == "1 件・止め")
    }
}
