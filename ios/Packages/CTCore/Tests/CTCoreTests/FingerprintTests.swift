import Testing
import Foundation
@testable import CTCore

/// 指紋は「日課表を作り直すべきか」を決める。**変わるべきときに変わり、
/// 変わるべきでないときに変わらない**ことをここで見張る。
@Suite("入力の指紋")
struct FingerprintTests {

    static func world(seed: UInt64 = 0xBEEF,
                      characterID: String = "piyo",
                      activity: Double = 0.5,
                      floor: RoomRect = RoomRect(x: 0.1, y: 0.6, width: 0.8, height: 0.2),
                      items: [PlacedItem] = []) -> WorldInput {
        WorldInput(
            character: Character(id: characterID, displayName: "テスト",
                                 personality: Personality(activity: activity, nightOwl: 0.3,
                                                          napiness: 0.4),
                                 poses: [.idle: ["a"]]),
            room: Room(background: .bundled("r"), floor: floor, items: items),
            userSeed: seed)
    }

    @Test("同じ入力なら同じ指紋")
    func stable() {
        #expect(Self.world().fingerprint == Self.world().fingerprint)
    }

    @Test("日課表に効く値を変えると指紋も変わる")
    func changesWithThePlanInputs() {
        let base = Self.world().fingerprint
        #expect(Self.world(seed: 0xBEE0).fingerprint != base)
        #expect(Self.world(characterID: "mochi").fingerprint != base)
        #expect(Self.world(activity: 0.9).fingerprint != base)
        #expect(Self.world(floor: RoomRect(x: 0.1, y: 0.5, width: 0.8, height: 0.2))
                    .fingerprint != base)
        #expect(Self.world(items: [PlacedItem(id: "c", kind: .cushion,
                                              position: RoomPoint(x: 0.3, y: 0.7))])
                    .fingerprint != base)
    }

    @Test("アイテムを動かすと指紋が変わる")
    func changesWhenItemMoves() {
        func withCushion(at x: Double) -> UInt64 {
            Self.world(items: [PlacedItem(id: "c", kind: .cushion,
                                          position: RoomPoint(x: x, y: 0.7))]).fingerprint
        }
        #expect(withCushion(at: 0.3) != withCushion(at: 0.5))
        #expect(withCushion(at: 0.3) == withCushion(at: 0.3))
    }

    @Test("日課表に効かない値では指紋が変わらない")
    func ignoresWhatDoesNotAffectThePlan() {
        var withBackground = Self.world()
        withBackground.room.background = .photo(fileName: "abc")
        #expect(withBackground.fingerprint == Self.world().fingerprint)

        // 文脈（電池）は日課表を差し替えず、後段で合成する（プラン §5.4）。
        var withContext = Self.world()
        withContext.context = ContextSnapshot(batteryLevel: 0.1, capturedAt: .distantPast)
        #expect(withContext.fingerprint == Self.world().fingerprint)
    }

    @Test("好物は並び順に依らない")
    func favoritesAreASet() {
        func person(_ favorites: [ItemKind]) -> UInt64 {
            Personality(activity: 0.5, nightOwl: 0.5, napiness: 0.5,
                        favorites: favorites).fingerprint
        }
        #expect(person([.cushion, .bed]) == person([.bed, .cushion]))
        #expect(person([.cushion, .bed]) != person([.cushion]))
    }

    @Test("見た目に出ない細かさの違いは拾わない")
    func ignoresInvisibleDifferences() {
        let coarse = Self.world(floor: RoomRect(x: 0.1, y: 0.6, width: 0.8, height: 0.2))
        // 1 万分の 1 より細かい差は同じ扱い。画面の 1 画素よりずっと小さい。
        let hair = Self.world(floor: RoomRect(x: 0.1 + 0.000_001, y: 0.6,
                                              width: 0.8, height: 0.2))
        #expect(coarse.fingerprint == hair.fingerprint)
    }
}
