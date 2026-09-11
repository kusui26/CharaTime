import Testing
import Foundation
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
        state.settings.widgetPseudoAnimation = true
        try store.save(state)

        let loaded = store.load()
        #expect(loaded.outcome == .loaded)
        #expect(loaded.state.userSeed == 0xDEAD_BEEF_CAFE_1234)
        #expect(loaded.state.selectedCharacterID == "fuwa")
        #expect(loaded.state.settings.nightMode == false)
        #expect(loaded.state.settings.widgetPseudoAnimation == true)
    }

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
        let json = #"{ "schemaVersion": 99, "userSeed": 1234, "selectedCharacterID": "chip" }"#
        try Data(json.utf8).write(to: store.fileURL!)

        let loaded = store.load()
        #expect(loaded.outcome == .futureSchema(99))
        #expect(loaded.state.userSeed == 1234)                    // 種だけは引き継ぐ
        #expect(loaded.state.selectedCharacterID == "piyo")
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
        #expect(throws: StateStore.StoreError.noContainer) { try store.save(AppState(userSeed: 1)) }
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
