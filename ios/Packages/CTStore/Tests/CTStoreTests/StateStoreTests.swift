import Testing
import Foundation
import CTCore
@testable import CTStore

@Suite("状態の保存")
struct StateStoreTests {

    /// テストごとに使い捨てのディレクトリを作る。`swift test` は素の macOS プロセスで
    /// 動くので App Group の共有コンテナには届かない。だから場所を注入できるようにしてある。
    private func makeStore() throws -> (StateStore, URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ct-store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (StateStore(directory: dir), dir)
    }

    @Test("書いて読むと同じ値が戻る")
    func roundTrip() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        var state = AppState(userSeed: 0xDEAD_BEEF_CAFE_1234, selectedCharacterID: "fuwa")
        state.settings.nightMode = false
        state.room = Room(background: .photo(fileName: "bg-1"), floor: .unit)
        state.context = ContextSnapshot(batteryLevel: 0.42, isCharging: true, capturedAt: Self.noon,
                                        chargingSince: Self.noon.addingTimeInterval(-600))
        state.widget = WidgetSettingsTests.sample
        try store.save(state)

        let loaded = store.load()
        #expect(loaded.outcome == .loaded)
        #expect(loaded.state == state)
        #expect(loaded.state.userSeed == 0xDEAD_BEEF_CAFE_1234)
        #expect(loaded.state.settings.nightMode == false)
        #expect(loaded.state.context?.chargingSince == Self.noon.addingTimeInterval(-600))
        #expect(loaded.state.widget.pseudoAnimation == true)
    }

    /// 2026-09-24 12:00（日本時間）。秒の端数が無い時刻にして、JSON の往復で値が揺れないようにする。
    private static let noon = Date(timeIntervalSince1970: 1_790_218_800)

    @Test("まだ無いときは既定値と notFound")
    func missingFile() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let loaded = store.load(fallbackSeed: 7)
        #expect(loaded.outcome == .notFound)
        #expect(loaded.state.userSeed == 7)
        #expect(loaded.state.selectedCharacterID == "piyo")
    }

    /// ウィジェット拡張が落ちると、その後の更新まで止まる。壊れた JSON でも描き続ける。
    @Test("壊れていても落ちずに既定値を返す")
    func corruptedFile() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("{ これは JSON ではない".utf8).write(to: store.fileURL!)

        let loaded = store.load(fallbackSeed: 11)
        guard case .corrupted = loaded.outcome else {
            Issue.record("corrupted が返らなかった: \(loaded.outcome)"); return
        }
        #expect(loaded.state.userSeed == 11)
    }

    @Test("知らない項目は捨て、足りない項目は既定値で埋める")
    func toleratesUnknownAndMissingKeys() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        // 将来のアプリが書いたつもりの JSON（未知の項目つき、settings は一部だけ）
        let json = """
        { "schemaVersion": 1, "userSeed": 99, "selectedCharacterID": "kumao",
          "settings": { "showsClock": false }, "roomThemeAddedLater": "night-v2" }
        """
        try Data(json.utf8).write(to: store.fileURL!)

        let loaded = store.load()
        #expect(loaded.outcome == .loaded)
        #expect(loaded.state.selectedCharacterID == "kumao")
        #expect(loaded.state.settings.showsClock == false)
        #expect(loaded.state.settings.nightMode == true)          // 足りない分は既定値
        #expect(loaded.state.settings.soundEnabled == false)
    }

    @Test("未来の版は信用せず既定値に落とす")
    func futureSchema() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let json = """
        { "schemaVersion": 99, "userSeed": 1234, "selectedCharacterID": "chip",
          "context": { "batteryLevel": 0.05, "capturedAt": 780000000 },
          "widget": { "pseudoAnimation": true } }
        """
        try Data(json.utf8).write(to: store.fileURL!)

        let loaded = store.load()
        #expect(loaded.outcome == .futureSchema(99))
        #expect(loaded.state.userSeed == 1234)                    // 種だけは引き継ぐ
        #expect(loaded.state.selectedCharacterID == "piyo")
        #expect(loaded.state.context == nil)                      // 文脈もウィジェットの設定も信用しない
        #expect(loaded.state.widget == WidgetSettings())
    }

    // MARK: - 3-1 で足した項目（プラン §9 Phase 3 の 3-C ⑪）

    /// 3-1 より前のアプリが書いた JSON。疑似アニメの入／切は settings にあり、文脈とウィジェットの設定は無い。
    @Test("3-1 より前の JSON を読むと、文脈は無く、ウィジェットは何も選んでいない")
    func readsJSONFromBeforeWidgetSettings() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let json = """
        { "schemaVersion": 1, "userSeed": 42, "selectedCharacterID": "piyo",
          "settings": { "showsClock": true, "clockStyle": "modern", "nightMode": false,
                        "soundEnabled": false, "widgetPseudoAnimation": false } }
        """
        try Data(json.utf8).write(to: store.fileURL!)

        let loaded = store.load()
        #expect(loaded.outcome == .loaded)
        #expect(loaded.state.userSeed == 42)
        #expect(loaded.state.settings.clockStyle == .modern)
        #expect(loaded.state.settings.nightMode == false)
        #expect(loaded.state.context == nil)
        #expect(loaded.state.widget == WidgetSettings())
    }

    /// 読むだけの設定画面が書いた false は、利用者が選んだ値ではない（3-C ⑪）。
    /// 引き継ぐと、既定を入にしたとき（3-2b）に、いまの端末だけ切のまま残ってしまう。
    @Test("settings にあった疑似アニメの値は引き継がず、保存し直すと消える")
    func dropsOldPseudoAnimationFlag() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let json = #"{ "schemaVersion": 1, "userSeed": 42, "settings": { "widgetPseudoAnimation": false } }"#
        try Data(json.utf8).write(to: store.fileURL!)

        let loaded = store.load()
        #expect(loaded.state.widget.pseudoAnimation == nil)
        #expect(loaded.state.widget.usesPseudoAnimation == WidgetSettings.defaultPseudoAnimation)
        try store.save(loaded.state)
        let text = try String(contentsOf: store.fileURL!, encoding: .utf8)
        #expect(!text.contains("widgetPseudoAnimation"))
    }

    /// 全体を読めなくすると、種まで既定値に戻り、別のキャラの一日になってしまう。
    @Test("文脈やウィジェットの設定が壊れていても、それだけを捨て、種と部屋は残る")
    func brokenNewBlocksDoNotSpreadToTheRest() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let json = """
        { "schemaVersion": 1, "userSeed": 77, "selectedCharacterID": "kumao",
          "room": { "background": { "photo": { "fileName": "bg-7" } } },
          "context": { "batteryLevel": "たくさん" },
          "widget": "壊れている" }
        """
        try Data(json.utf8).write(to: store.fileURL!)

        let loaded = store.load()
        #expect(loaded.outcome == .loaded)
        #expect(loaded.state.userSeed == 77)
        #expect(loaded.state.selectedCharacterID == "kumao")
        #expect(loaded.state.room?.background == .photo(fileName: "bg-7"))
        #expect(loaded.state.context == nil)
        #expect(loaded.state.widget == WidgetSettings())
    }

    @Test("読んだ時刻の無い文脈は、無かったことにする")
    func contextWithoutCaptureTimeIsDropped() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let json = #"{ "schemaVersion": 1, "userSeed": 5, "context": { "batteryLevel": 0.1, "isCharging": false } }"#
        try Data(json.utf8).write(to: store.fileURL!)

        let loaded = store.load()
        #expect(loaded.outcome == .loaded)
        #expect(loaded.state.context == nil)
    }

    @Test("保存すると版が現在のものに揃う")
    func saveStampsCurrentVersion() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        try store.save(AppState(schemaVersion: 0, userSeed: 5))
        #expect(store.load().state.schemaVersion == AppState.currentSchemaVersion)
    }

    @Test("初回だけ作り、二度目からは同じ種を返す")
    func loadOrCreateKeepsSeed() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let first = try store.loadOrCreate()
        let second = try store.loadOrCreate()
        #expect(first.userSeed == second.userSeed)
        #expect(first.userSeed != 0)
    }

    @Test("共有コンテナが無いときは書き込みが失敗し、読みは既定値を返す")
    func noContainer() {
        let store = StateStore(directory: nil)
        #expect(store.load().outcome == .noContainer)
        #expect(throws: StateStore.StoreError.noContainer(appGroup: AppGroup.identifier)) {
            try store.save(AppState(userSeed: 1))
        }
    }

    @Test("保存した JSON は人が読める形で並ぶ")
    func humanReadableOutput() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        try store.save(AppState(userSeed: 1, selectedCharacterID: "mochi"))
        let text = try String(contentsOf: store.fileURL!, encoding: .utf8)
        #expect(text.contains("\n"))                               // 整形されている
        #expect(text.range(of: "schemaVersion")!.lowerBound
                < text.range(of: "selectedCharacterID")!.lowerBound)  // キーが並んでいる
    }
}
