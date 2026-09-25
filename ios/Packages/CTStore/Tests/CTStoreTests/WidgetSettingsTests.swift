import Testing
import Foundation
@testable import CTStore

/// `state.json` の `widget`（プラン §9 Phase 3 の 3-C ⑪）。
@Suite("ウィジェットの設定")
struct WidgetSettingsTests {

    /// 全部の項目を埋めた設定。ほかのテストでも使う。
    static let sample = WidgetSettings(
        pseudoAnimation: true,
        wallpaper: AppearanceImages(light: "wallpaper-light", dark: "wallpaper-dark"),
        slots: [
            SlotSetting(slot: WidgetSlot(family: .large, column: 0, row: 0),
                        frame: PixelRect(x: 79, y: 270, width: 1049, height: 1095),
                        crops: AppearanceImages(light: "crop-large-0-0-light", dark: "crop-large-0-0-dark")),
            SlotSetting(slot: WidgetSlot(family: .medium, column: 0, row: 2),
                        frame: PixelRect(x: 79, y: 1474, width: 1049, height: 493),
                        crops: AppearanceImages(light: "crop-medium-0-2-light")),
        ],
        pagePreset: .largeOverMedium,
        markersUntil: Date(timeIntervalSince1970: 1_790_219_400))

    private func decode(_ json: String) throws -> WidgetSettings {
        try JSONDecoder().decode(WidgetSettings.self, from: Data(json.utf8))
    }

    // MARK: - 疑似アニメの入／切

    @Test("選んでいなければ、疑似アニメは既定に従う")
    func pseudoAnimationFollowsDefault() {
        #expect(WidgetSettings().pseudoAnimation == nil)
        #expect(WidgetSettings().usesPseudoAnimation == WidgetSettings.defaultPseudoAnimation)
        #expect(WidgetSettings(pseudoAnimation: true).usesPseudoAnimation)
        #expect(!WidgetSettings(pseudoAnimation: false).usesPseudoAnimation)
    }

    /// Reduce Motion の人の疑似アニメは、自分で入にしたときだけ動く（D-19）。既定を入にするときは、
    /// その人たちの既定を分けてから変える（Q-15）。変えたことに、このテストで気づけるようにしておく。
    @Test("疑似アニメの既定は切（入にするなら、先に D-19 の前提を見直す）")
    func defaultStaysOffUntilTheBatteryIsMeasured() {
        #expect(!WidgetSettings.defaultPseudoAnimation)
    }

    /// nil を false として書くと、既定を入にしたとき（3-2b）に届かなくなる。
    @Test("選んでいないことは、JSON を往復しても「選んでいない」のまま")
    func unchosenSurvivesRoundTrip() throws {
        let data = try JSONEncoder().encode(WidgetSettings())
        let text = try #require(String(bytes: data, encoding: .utf8))
        #expect(!text.contains("pseudoAnimation"))
        #expect(try JSONDecoder().decode(WidgetSettings.self, from: data).pseudoAnimation == nil)
    }

    // MARK: - 読み書き

    @Test("JSON を往復しても変わらない")
    func roundTrip() throws {
        let data = try JSONEncoder().encode(Self.sample)
        #expect(try JSONDecoder().decode(WidgetSettings.self, from: data) == Self.sample)
    }

    @Test("空の設定は、何も選んでいない既定値")
    func emptyObjectIsDefault() throws {
        let settings = try decode("{}")
        #expect(settings == WidgetSettings())
        #expect(settings.pagePreset == .standalone)
        #expect(settings.wallpaper.names.isEmpty)
        #expect(settings.slots.isEmpty)
        #expect(settings.markersUntil == nil)
    }

    /// 新しいアプリが書いた型（知らないページの型）や、型の違う値。
    @Test("1 項目が壊れていても、ほかの項目は残る")
    func brokenFieldKeepsTheRest() throws {
        let settings = try decode("""
        { "pseudoAnimation": "はい", "pagePreset": "fourSmalls", "markersUntil": "あした",
          "wallpaper": { "light": "wp-l", "dark": "wp-d" },
          "slots": [ { "slot": { "family": "small", "column": 1, "row": 0 },
                       "frame": { "x": 635, "y": 270, "width": 493, "height": 493 } } ] }
        """)
        #expect(settings.pseudoAnimation == nil)
        #expect(settings.pagePreset == .standalone)
        #expect(settings.markersUntil == nil)
        #expect(settings.wallpaper == AppearanceImages(light: "wp-l", dark: "wp-d"))
        #expect(settings.slots.map(\.slot) == [WidgetSlot(family: .small, column: 1, row: 0)])
    }

    /// 位置合わせをやり直させないため、読めないスロットのせいでほかのスロットを捨てない。
    @Test("読めないスロットだけを捨てる")
    func dropsOnlyUnreadableSlots() throws {
        let settings = try decode("""
        { "slots": [
            { "slot": { "family": "small", "column": 0, "row": 1 },
              "frame": { "x": 79, "y": 872, "width": 493, "height": 493 },
              "crops": { "light": "crop-a" } },
            { "slot": { "family": "extraLarge", "column": 0, "row": 0 },
              "frame": { "x": 0, "y": 0, "width": 10, "height": 10 } },
            { "slot": { "family": "medium", "column": 0, "row": 0 } },
            null,
            { "slot": { "family": "large", "column": 0, "row": 1 },
              "frame": { "x": 79, "y": 872, "width": 1049, "height": 1095 } } ] }
        """)
        #expect(settings.slots.map(\.slot) == [WidgetSlot(family: .small, column: 0, row: 1),
                                               WidgetSlot(family: .large, column: 0, row: 1)])
        #expect(settings.slots.first?.crops.light == "crop-a")
        #expect(settings.slots.last?.crops == AppearanceImages())
    }

    @Test("切り抜きが壊れていても、スロットの枠は残す（切り抜きは作り直せる）")
    func brokenCropsKeepTheFrame() throws {
        let settings = try decode("""
        { "slots": [ { "slot": { "family": "medium", "column": 0, "row": 1 },
                       "frame": { "x": 79, "y": 872, "width": 1049, "height": 493 },
                       "crops": ["crop-a"] } ] }
        """)
        #expect(settings.slots.first?.frame == PixelRect(x: 79, y: 872, width: 1049, height: 493))
        #expect(settings.slots.first?.crops == AppearanceImages())
    }

    @Test("スロットの並びが配列でなければ、スロットは無いものとする")
    func slotsThatAreNotAnArray() throws {
        let settings = try decode(#"{ "slots": { "small": 1 }, "pagePreset": "threeMediums" }"#)
        #expect(settings.slots.isEmpty)
        #expect(settings.pagePreset == .threeMediums)
    }

    // MARK: - 画像の名前

    @Test("参照している画像は、壁紙の 2 枚と、スロットごとの切り抜き")
    func imageNames() {
        #expect(Set(Self.sample.imageNames) == ["wallpaper-light", "wallpaper-dark", "crop-large-0-0-light",
                                                "crop-large-0-0-dark", "crop-medium-0-2-light"])
        #expect(WidgetSettings().imageNames.isEmpty)
    }

    @Test("外観ごとの名前は、まだ無いものを除く")
    func appearanceNames() {
        #expect(AppearanceImages().names.isEmpty)
        #expect(AppearanceImages(dark: "d").names == ["d"])
        #expect(AppearanceImages(light: "l", dark: "d").names == ["l", "d"])
    }

    // MARK: - スロット

    /// 大は 1 ページに 1 つ、いちばん上に置くので、自分の大きさでスロットが分かる（D-31）。
    /// 中と小は置き場所が決まらないので、D-31 より前に作った中の切り抜きが残っていても使わない。
    @Test("透過背景を使うのは、ページのいちばん上の大だけ。中と小と、用意していないときは nil")
    func slotForFamily() {
        #expect(Self.sample.slot(for: .large)?.slot == WidgetSlot(family: .large, column: 0, row: 0))
        #expect(Self.sample.slot(for: .medium) == nil)
        #expect(Self.sample.slot(for: .small) == nil)
        #expect(WidgetSettings().slot(for: .large) == nil)
    }
}
