import Testing
import Foundation
import CTCore
import CTAssets
import CTStore
@testable import CTRender

/// エントリの材料（プラン §9 Phase 3 の 3-C ②④'）と、アプリとウィジェットが同じ入力を組み立てる規則。
@Suite("ウィジェットのエントリ")
struct WidgetMomentTests {

    static let tokyo: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    static func date(_ hour: Int, _ minute: Int) -> Date {
        tokyo.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: hour, minute: minute))!
    }

    static let character = CTCore.Character(
        id: "piyo", displayName: "ピヨ",
        personality: Personality(activity: 0.9, nightOwl: 0.3, napiness: 0.4, favorites: [.mirrorBall]),
        poses: [:])

    static func input() -> WorldInput {
        WorldInput(character: character, room: BundledRoom.room, userSeed: 0x5EED_F00D, calendar: tokyo)
    }

    static let layout = WidgetStage.stage(for: .large).layout(
        size: WidgetStage.referenceSize(for: .large), room: BundledRoom.room,
        geometry: SpriteGeometry(aspectRatio: 130.0 / 180.0, groundRatio: 168.0 / 180.0))

    // MARK: - 姿

    /// ウィジェットの姿とアプリの姿が一致する（Gate 3）。描き方は違っても、姿は日課エンジンの答えそのもの。
    @Test("エントリの姿は、日課エンジンがその時刻に返す姿と同じ")
    func momentsCarryTheEngineAnswer() {
        let dates = WidgetTimeline.entryDates(from: Self.date(9, 2), calendar: Self.tokyo)
        let moments = WidgetMoments.make(at: dates, input: Self.input(), settings: CTStore.Settings(),
                                         layout: Self.layout)
        #expect(moments.map(\.date) == dates)
        #expect(moments.map(\.state) == SceneEngine.sceneStates(at: dates, input: Self.input()))
    }

    @Test("夜の配色は 22 時から 6 時の直前まで。夜モードが切なら使わない")
    func nightFollowsTheClockAndTheSetting() {
        let dates = [Self.date(5, 55), Self.date(6, 0), Self.date(21, 55), Self.date(22, 0)]
        let night = WidgetMoments.make(at: dates, input: Self.input(), settings: CTStore.Settings(),
                                       layout: Self.layout)
        #expect(night.map(\.isNight) == [true, false, false, true])
        var always = CTStore.Settings()
        always.nightMode = false
        let off = WidgetMoments.make(at: dates, input: Self.input(), settings: always, layout: Self.layout)
        #expect(off.allSatisfy { !$0.isNight })
    }

    // MARK: - 居場所のつながり

    @Test("近い移動は同じ番号のまま、幅の半分を超える移動で次の番号になる")
    func farMovesStartANewLeg() {
        let floor = BundledRoom.room.floor
        // 大は帯の幅が約 224pt。幅の半分（約 175pt）を超えるのは、帯の 8 割近くを横切るときだけ。
        let positions = [floor.at(0.0, 0.5), floor.at(0.1, 0.5), floor.at(0.95, 0.5), floor.at(0.9, 0.2),
                         floor.at(0.05, 0.9)]
        #expect(WidgetMoments.legs(of: positions, layout: Self.layout) == [0, 0, 1, 1, 2])
    }

    @Test("滑らせてよい距離は、実際に動くポイントで決まる（ウィジェットの幅の半分）")
    func slideLimitIsHalfTheWidth() {
        let floor = BundledRoom.room.floor
        let start = floor.at(0, 0.5)
        let travel = Self.layout.horizontalTravel(from: start, to: floor.at(1, 0.5))
        #expect(travel > Self.layout.size.width * WidgetMoments.slideLimitWidthRatio)
        #expect(WidgetMoments.legs(of: [], layout: Self.layout).isEmpty)
        #expect(WidgetMoments.legs(of: [start], layout: Self.layout) == [0])
    }

    // MARK: - この端末のキャラと部屋

    static let catalog = [
        CTCore.Character(id: "piyo", displayName: "ピヨ",
                         personality: Personality(activity: 0.5, nightOwl: 0.5, napiness: 0.5), poses: [:]),
        CTCore.Character(id: "mochi", displayName: "モチ",
                         personality: Personality(activity: 0.5, nightOwl: 0.5, napiness: 0.5), poses: [:]),
    ]

    @Test("選んだキャラを使い、見つからなければ同梱の先頭、1 体も無ければ無し")
    func characterFallsBackToTheFirst() {
        #expect(AppState(userSeed: 1, selectedCharacterID: "mochi").currentCharacter(among: Self.catalog)?.id
                == "mochi")
        #expect(AppState(userSeed: 1, selectedCharacterID: "kumao").currentCharacter(among: Self.catalog)?.id
                == "piyo")
        #expect(AppState(userSeed: 1).currentCharacter(among: []) == nil)
    }

    @Test("部屋を選んでいなければ同梱の部屋。入力には種・部屋・文脈をそのまま渡す")
    func inputCarriesTheSavedState() {
        let context = ContextSnapshot(batteryLevel: 0.3, isCharging: false, capturedAt: Self.date(9, 0))
        let photo = Room(background: .photo(fileName: "bg"), floor: RoomRect(x: 0.2, y: 0.6, width: 0.6, height: 0.2))
        let bare = AppState(userSeed: 42, context: context)
        #expect(bare.currentRoom == BundledRoom.room)
        let input = AppState(userSeed: 42, room: photo, context: context)
            .worldInput(character: Self.character, calendar: Self.tokyo)
        #expect(input.userSeed == 42)
        #expect(input.room == photo)
        #expect(input.context == context)
        #expect(input.calendar == Self.tokyo)
    }
}
