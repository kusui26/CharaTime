import Testing
import Foundation
import CoreGraphics
import CTStore
@testable import CTRender

/// 置き方のガイドの「いまの様子」（プラン §9 Phase 3 の 3-4）。
@Suite("置き方のガイドのいまの様子")
struct PlacementCheckTests {

    static let tokyo: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    /// 2026-09-25 23:40（日本時間）。
    static let now = tokyo.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 23, minute: 40))!
    static let verified = SystemVersion(major: 26, minor: 1)

    static func reload(_ family: WidgetSlot.Family, hoursAgo: Double) -> WidgetReload {
        WidgetReload(date: now.addingTimeInterval(-hoursAgo * 3600), family: family, entryCount: 73,
                     footprintBytes: 1, peakBytes: 1, pseudoAnimation: true)
    }

    private func items(record: [WidgetReload] = [], widget: WidgetSettings = WidgetSettings(),
                       iconStyle: SlotGeometry.IconStyleReading = .notYetPlaced,
                       system: SystemVersion = verified) -> [PlacementCheck] {
        PlacementCheck.items(PlacementCheck.Inputs(record: WidgetDiagnostics(reloads: record), widget: widget,
                                                   iconStyle: iconStyle, system: system),
                             now: Self.now, calendar: Self.tokyo)
    }

    private func item(_ title: String, in items: [PlacementCheck]) -> PlacementCheck? {
        items.first { $0.title == title }
    }

    @Test("大は、24 時間のうちに作り直していれば置いてある。最後の時刻を添える")
    func placedLarge() throws {
        let large = try #require(item("大", in: items(record: [Self.reload(.large, hoursAgo: 0.1)])))
        #expect(large.state == .done)
        #expect(large.detail == "置いてあります（最後に作り直したのは 23:34）")
    }

    @Test("大の記録が無ければまだ。24 時間作り直していなければ、外したのかもしれない")
    func largeNotPlaced() throws {
        let nothing = try #require(item("大", in: items()))
        #expect(nothing.state == .pending)
        #expect(nothing.detail == "まだ見当たりません（置くと、ここに出ます）")
        let stale = try #require(item("大", in: items(record: [Self.reload(.large, hoursAgo: 30)])))
        #expect(stale.state == .pending)
        #expect(stale.detail == "24 時間作り直していません（外したのかもしれません）")
    }

    /// 基本の置き方は大 1 つ（D-31）。中は大と同じ部屋を映すので、置いてあれば外すのを勧める。
    @Test("中は、置いてあるときだけ、ページには要らないものとして外すのを勧める")
    func mediumIsNotNeeded() throws {
        let medium = try #require(item("中", in: items(record: [Self.reload(.large, hoursAgo: 1),
                                                                Self.reload(.medium, hoursAgo: 0.1)])))
        #expect(medium.state == .notNeeded)
        #expect(medium.detail == "置いてあります（最後に作り直したのは 23:34）。大と同じ部屋を映すので、"
                + "キャラが 2 か所に見えます。外すのがおすすめです")
        #expect(item("中", in: items()) == nil)
        #expect(item("中", in: items(record: [Self.reload(.medium, hoursAgo: 30)])) == nil)
    }

    @Test("ラベルの有無は、ウィジェットの大きさから分かったときだけ済み")
    func iconStyle() {
        #expect(item("アプリ名のラベル", in: items(iconStyle: .detected(.labeled)))?.detail == "あり")
        #expect(item("アプリ名のラベル", in: items(iconStyle: .detected(.labelFree)))?.detail
                == "なし（大きいアプリアイコン）")
        #expect(item("アプリ名のラベル", in: items(iconStyle: .detected(.labeled)))?.state == .done)
        #expect(item("アプリ名のラベル", in: items())?.state == .pending)
        #expect(item("アプリ名のラベル", in: items())?.detail == "大を置くと分かります")
    }

    /// 置いてあっても表に無い大きさなら、待っても分からない。透過背景が使えないことを伝える。
    @Test("表に無い大きさなら、ページには要らないものとして、透過背景が使えないと伝える")
    func unknownIconStyle() throws {
        let label = try #require(item("アプリ名のラベル", in: items(iconStyle: .unknownSize)))
        #expect(label.state == .notNeeded)
        #expect(label.detail == "表に無い大きさです（画面の表示を拡大しているときなど）。透過背景は使えません")
    }

    /// 透過背景とまばたきは好みで選ぶもの。使っていなくても「まだ」ではない。
    @Test("透過背景とまばたきは、使っていなければ、ページには要らないもの")
    func optionalFeatures() {
        let plain = items()
        #expect(item("透過背景", in: plain)?.state == .notNeeded)
        #expect(item("まばたき・寝息", in: plain)?.state == .notNeeded)
        let chosen = items(widget: WidgetSettings(pseudoAnimation: true,
                                                  wallpaper: AppearanceImages(light: "l", dark: "d")))
        #expect(item("透過背景", in: chosen)?.state == .done)
        #expect(item("透過背景", in: chosen)?.detail == "ライト・ダーク")
        #expect(item("まばたき・寝息", in: chosen)?.state == .done)
    }

    /// 確かめていない版では、疑似アニメを使わない（D-22）。
    @Test("iOS の版は、動きを確かめた版かを添える")
    func systemVersion() throws {
        let verified = try #require(item("iOS", in: items()))
        #expect(verified.state == .done)
        #expect(verified.detail == "26.1（動きを確かめた版）")
        let unknown = try #require(item("iOS", in: items(system: SystemVersion(major: 27, minor: 0))))
        #expect(unknown.state == .pending)
        #expect(unknown.detail == "27.0（まだ確かめていない版。5 分ごとの切り替えになります）")
    }

    @Test("並びは、ページ（大・中・ラベル）、飾り（透過背景・まばたき）、iOS の順。中は置いてあるときだけ")
    func order() {
        #expect(items().map(\.title) == ["大", "アプリ名のラベル", "透過背景", "まばたき・寝息", "iOS"])
        #expect(items(record: [Self.reload(.medium, hoursAgo: 1)]).map(\.title)
                == ["大", "中", "アプリ名のラベル", "透過背景", "まばたき・寝息", "iOS"])
    }
}
