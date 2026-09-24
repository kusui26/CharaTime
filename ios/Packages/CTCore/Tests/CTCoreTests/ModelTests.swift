import Testing
import Foundation
@testable import CTCore

@Suite("モデル")
struct ModelTests {

    private func sampleCharacter() -> Character {
        Character(
            id: "piyo", displayName: "ピヨ", scale: 1.0,
            personality: Personality(activity: 0.9, nightOwl: 0.1, napiness: 0.3, favorites: [.ball]),
            poses: [.idle: ["piyo_idle_01", "piyo_idle_02"],
                    .walk: ["piyo_walk_01", "piyo_walk_02", "piyo_walk_03", "piyo_walk_04"],
                    .sit: ["piyo_sit_01", "piyo_sit_02"],
                    .sleep: ["piyo_sleep_01", "piyo_sleep_02"],
                    .happy: ["piyo_happy_01", "piyo_happy_02"]],
            origin: .bundled)
    }

    @Test("キャラクターが JSON を往復しても変わらない")
    func characterRoundTrip() throws {
        let original = sampleCharacter()
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(Character.self, from: data)
        #expect(restored == original)
        #expect(restored.frameCount(.walk) == 4)
        #expect(restored.frameCount(.surprised) == 0)   // 未用意の姿勢は 0
    }

    /// すわる姿のまばたきの絵を 3-2b で足した（11 枚から 12 枚）。
    @Test("Tier 1 は 12 枚")
    func tierOneFrameCount() {
        let total = Pose.allCases.reduce(0) { $0 + sampleCharacter().frameCount($1) }
        #expect(total == 12)
    }

    @Test("取り込んだキャラも同じ型で往復する")
    func userCharacterRoundTrip() throws {
        var character = sampleCharacter()
        character.id = "my-dragon"
        character.origin = .user(createdAt: Date(timeIntervalSince1970: 1_789_000_000))
        let data = try JSONEncoder().encode(character)
        let restored = try JSONDecoder().decode(Character.self, from: data)
        #expect(restored.origin == .user(createdAt: Date(timeIntervalSince1970: 1_789_000_000)))
    }

    @Test("部屋が JSON を往復しても変わらない")
    func roomRoundTrip() throws {
        let room = Room(
            background: .homeScreenShot(fileName: "home-2026-09-11.png"),
            floor: RoomRect(x: 0.06, y: 0.62, width: 0.88, height: 0.24),
            items: [PlacedItem(id: "mb", kind: .mirrorBall, position: RoomPoint(x: 0.5, y: 0.2)),
                    PlacedItem(id: "c1", kind: .cushion, position: RoomPoint(x: 0.8, y: 0.7))])
        let data = try JSONEncoder().encode(room)
        let restored = try JSONDecoder().decode(Room.self, from: data)
        #expect(restored == room)
        #expect(restored.depthScaleFar == 0.85)
    }

    @Test("mini の絵の名前も JSON を往復する")
    func miniPosesRoundTrip() throws {
        var character = sampleCharacter()
        character.miniPoses = [.idle: ["piyo_idle_01_mini", "piyo_idle_02_mini"]]
        let data = try JSONEncoder().encode(character)
        let restored = try JSONDecoder().decode(Character.self, from: data)
        #expect(restored.miniPoses == character.miniPoses)
        #expect(restored == character)
    }

    /// 取り込んだキャラ（Phase 5）や古い manifest には mini が無い。無くても読めて、空になる。
    @Test("mini の無い JSON も読め、mini は空になる")
    func missingMiniPosesDecodeAsEmpty() throws {
        let data = try JSONEncoder().encode(sampleCharacter())
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "miniPoses")
        let trimmed = try JSONSerialization.data(withJSONObject: object)
        let restored = try JSONDecoder().decode(Character.self, from: trimmed)
        #expect(restored.miniPoses.isEmpty)
        #expect(restored.poses == sampleCharacter().poses)
    }

    @Test("まぶたと寝息の判定も JSON を往復し、疑似アニメの絵の持ち物になる")
    func ambientArtRoundTrip() throws {
        var character = sampleCharacter()
        character.eyelids = [.idle: "piyo_idle_eyelid_mini"]
        character.sleepFrameCoversBase = true
        let restored = try JSONDecoder().decode(Character.self, from: try JSONEncoder().encode(character))
        #expect(restored == character)
        #expect(restored.ambientArt == AmbientArt(eyelidPoses: [.idle], sleepFrameCoversBase: true))
    }

    /// 分からないときは覆えないとみなす（重ねて縁がはみ出すより、2 枚を出し分けるほうが崩れない）。
    @Test("まぶたと寝息の判定が無い JSON は、まぶた無し・覆えないとして読む")
    func missingAmbientArtIsConservative() throws {
        let data = try JSONEncoder().encode(sampleCharacter())
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "eyelids")
        object.removeValue(forKey: "sleepFrameCoversBase")
        let trimmed = try JSONSerialization.data(withJSONObject: object)
        let restored = try JSONDecoder().decode(Character.self, from: trimmed)
        #expect(restored.eyelids.isEmpty)
        #expect(!restored.sleepFrameCoversBase)
    }

    @Test("止めた 1 枚で描くとき、歩く姿だけは立ち止まった姿にする")
    func stillPoseStandsWhenWandering() {
        let activities: [Activity] = [.sleep, .nap, .wander, .idle, .sit(itemId: nil), .dance(itemId: "m"),
                                      .play(itemId: "b"), .look(itemId: nil), .eat(itemId: "s"),
                                      .clockGreet, .happyStretch]
        for activity in activities {
            let expected: Pose = activity == .wander ? .idle : activity.pose
            #expect(activity.stillPose == expected, "\(activity)")
        }
    }

    @Test("画像を持つのは、取り込んだ背景だけ")
    func backgroundImageFileName() {
        #expect(Background.bundled("room").imageFileName == nil)
        #expect(Background.photo(fileName: "bg-1").imageFileName == "bg-1")
        #expect(Background.homeScreenShot(fileName: "bg-2").imageFileName == "bg-2")
    }

    @Test("アイテムが行動の語彙を増やす")
    func affordances() {
        let room = Room(
            background: .bundled("room-a"),
            floor: RoomRect(x: 0, y: 0.6, width: 1, height: 0.3),
            items: [PlacedItem(id: "mb", kind: .mirrorBall, position: .zero),
                    PlacedItem(id: "cu", kind: .cushion, position: .zero),
                    PlacedItem(id: "pl", kind: .plant, position: .zero)])
        #expect(room.items(providing: .dance).map(\.id) == ["mb"])
        #expect(room.items(providing: .sit).map(\.id) == ["cu"])
        #expect(room.items(providing: .look).map(\.id) == ["pl"])
        #expect(room.items(providing: .eat).isEmpty)          // おやつは未所持
    }

    @Test("すべてのアイテムが少なくとも 1 つの行動を持つ")
    func everyItemIsUseful() {
        for kind in ItemKind.allCases {
            #expect(!kind.affordances.isEmpty, "\(kind) にできることが無い")
        }
    }

    @Test("性格は 0〜1 に丸められる")
    func personalityClamping() {
        let wild = Personality(activity: 5.0, nightOwl: -3.0, napiness: 0.5)
        #expect(wild.activity == 1.0)
        #expect(wild.nightOwl == 0.0)
        #expect(wild.napiness == 0.5)
    }

    @Test("行動から姿勢が一意に決まる")
    func activityMapsToPose() {
        #expect(Activity.wander.pose == .walk)
        #expect(Activity.sleep.pose == .sleep)
        #expect(Activity.nap.pose == .sleep)
        #expect(Activity.dance(itemId: "mb").pose == .happy)
        #expect(Activity.sit(itemId: nil).pose == .sit)
        #expect(Activity.clockGreet.pose == .idle)
    }

    @Test("ある時刻の姿が JSON を往復する")
    func sceneStateEquality() {
        let state = SceneState(time: Date(timeIntervalSince1970: 1_789_000_000),
                               activity: .dance(itemId: "mb"),
                               position: RoomPoint(x: 0.4, y: 0.7),
                               facing: .left, frame: 1,
                               bubble: Bubble(text: "ふふ〜ん♪", kind: .idle))
        #expect(state == state)
        #expect(state.activity.pose == .happy)
    }
}

@Suite("JSON の形")
struct JSONShapeTests {

    /// `poses` は **オブジェクト**であること。配列になっていると、手で書く manifest も
    /// Python のパイプラインも扱えなくなる。
    @Test("poses は姿勢名をキーにしたオブジェクトになる")
    func posesEncodeAsObject() throws {
        let character = Character(
            id: "x", displayName: "X",
            personality: Personality(activity: 0.5, nightOwl: 0.5, napiness: 0.5),
            poses: [.idle: ["x_idle_01"]])
        let data = try JSONEncoder().encode(character)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let poses = try #require(object["poses"] as? [String: Any])
        #expect(poses["idle"] as? [String] == ["x_idle_01"])
    }

    @Test("origin は種類をキーにしたオブジェクトになる")
    func originEncoding() throws {
        let data = try JSONEncoder().encode(Character(
            id: "x", displayName: "X",
            personality: Personality(activity: 0.5, nightOwl: 0.5, napiness: 0.5),
            poses: [:], origin: .bundled))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["origin"] is [String: Any])
        #expect((object["origin"] as? [String: Any])?["bundled"] != nil)
    }

    @Test("範囲外の性格値は読み込み時にも丸められる")
    func personalityClampedOnDecode() throws {
        let json = #"{"activity": 9.0, "nightOwl": -4.0, "napiness": 0.25}"#
        let decoded = try JSONDecoder().decode(Personality.self, from: Data(json.utf8))
        #expect(decoded.activity == 1.0)
        #expect(decoded.nightOwl == 0.0)
        #expect(decoded.napiness == 0.25)
    }
}
