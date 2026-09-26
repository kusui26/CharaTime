import Testing
import Foundation
@testable import CTStore

/// 1 週間の運用（プラン §9 Phase 3 の 3-7）の記録表のうち、利用者が毎日つける分。
@Suite("1 週間の運用の記録表")
struct WeekRunRecordTests {

    /// 2026-09-26 9:00（日本時間）。
    static let start = Date(timeIntervalSince1970: 1_790_380_800)

    static func temporaryStore() -> WeekRunStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ct-week-run-\(UUID().uuidString)")
        return WeekRunStore(directory: directory)
    }

    // MARK: - 日の記録

    @Test("まだつけていない日は、空の記録として読める")
    func emptyDay() {
        let record = WeekRunRecord()
        #expect(record.startedAt == nil)
        #expect(record.day(3) == WeekRunDay(number: 3))
        #expect(record.day(3).characterVisible == nil)
        #expect(record.day(3).note.isEmpty)
    }

    @Test("日の記録を書き換えると、ほかの日はそのままで、日の順に並ぶ")
    func updatesADay() {
        let record = WeekRunRecord(startedAt: Self.start)
            .updatingDay(2) { $0.characterVisible = .yes }
            .updatingDay(1) { day in
                day.animating = .no
                day.note = "3 秒止まった"
            }
            .updatingDay(2) { $0.matchesApp = .yes }
        #expect(record.days.map(\.number) == [1, 2])
        #expect(record.day(2).characterVisible == .yes)
        #expect(record.day(2).matchesApp == .yes)
        #expect(record.day(1).animating == .no)
        #expect(record.day(1).note == "3 秒止まった")
        #expect(record.startedAt == Self.start)
    }

    @Test("一度だけ確かめることは、項目の名前で引く。まだなら空")
    func checks() {
        let record = WeekRunRecord().updatingCheck("afterUnlock") { check in
            check.answer = .no
            check.note = "2 秒遅れた"
        }
        #expect(record.check("afterUnlock").answer == .no)
        #expect(record.check("afterUnlock").note == "2 秒遅れた")
        #expect(record.check("lowPower") == WeekRunCheck())
    }

    // MARK: - 読み書き

    @Test("書いて読むと同じ記録表が戻る")
    func roundTrip() throws {
        let record = WeekRunRecord(startedAt: Self.start)
            .updatingDay(1) { day in
                day.characterVisible = .yes
                day.battery = BatteryUsage(charaTimePercent: 2, homeAndLockPercent: 5, readAt: Self.start)
            }
            .updatingCheck("afterKill") { check in
                check.answer = .yes
                check.answeredAt = Self.start
            }
        let data = try JSONEncoder().encode(record)
        #expect(try JSONDecoder().decode(WeekRunRecord.self, from: data) == record)
    }

    /// 1 週間ぶんの記録を、1 か所の壊れで失わない。
    @Test("壊れた日・知らない答え・壊れた値は、そこだけを捨てる")
    func lossyDecoding() throws {
        let json = """
        { "startedAt": 780000000,
          "days": [ { "number": 1, "characterVisible": "yes", "animating": "たぶん", "note": "ok" },
                    { "characterVisible": "no" },
                    { "number": 2, "battery": { "charaTimePercent": "二", "homeAndLockPercent": 3 } } ],
          "checks": { "afterUnlock": { "answer": "no", "note": "遅れた" }, "lowPower": 5 } }
        """
        let record = try JSONDecoder().decode(WeekRunRecord.self, from: Data(json.utf8))
        #expect(record.startedAt == Date(timeIntervalSinceReferenceDate: 780_000_000))
        #expect(record.days.map(\.number) == [1, 2])
        #expect(record.day(1).characterVisible == .yes)
        #expect(record.day(1).animating == nil)
        #expect(record.day(1).note == "ok")
        #expect(record.day(2).battery?.charaTimePercent == nil)
        #expect(record.day(2).battery?.homeAndLockPercent == 3)
        #expect(record.check("afterUnlock") == WeekRunCheck(answer: .no, note: "遅れた"))
        #expect(record.checks["lowPower"] == nil)
    }

    @Test("何も無い JSON は、まだ始めていない記録表")
    func emptyJSON() throws {
        #expect(try JSONDecoder().decode(WeekRunRecord.self, from: Data("{}".utf8)) == WeekRunRecord())
    }

    @Test("保存して読むと同じ記録表。ファイルが無い・壊れていれば、まだ始めていない記録表")
    func store() throws {
        let store = Self.temporaryStore()
        #expect(store.load() == WeekRunRecord())
        let record = WeekRunRecord(startedAt: Self.start).updatingDay(1) { $0.characterVisible = .yes }
        try store.save(record)
        #expect(store.load() == record)
        try Data("{ 壊れた".utf8).write(to: #require(store.fileURL))
        #expect(store.load() == WeekRunRecord())
    }

    @Test("共有コンテナが無ければ、読みは空、書きはどこに書けないかを添えて失敗する")
    func noContainer() {
        let store = WeekRunStore(directory: nil)
        #expect(store.load() == WeekRunRecord())
        #expect(throws: StateStore.StoreError.noContainer(appGroup: AppGroup.identifier)) {
            try store.save(WeekRunRecord())
        }
    }
}
