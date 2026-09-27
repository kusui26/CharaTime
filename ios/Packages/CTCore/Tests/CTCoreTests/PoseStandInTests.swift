import Testing
import Foundation
@testable import CTCore

/// 足りない姿勢の代わり（プラン §9 Phase 2 の 2-C ③）。取り込んだキャラは、立ち姿 1 枚（Tier 0）から
/// 12 コマ（Tier 1）まで、持っている絵がまちまち。どの段でも、日課のすべての姿を描けること。
@Suite("足りない姿勢の代わり")
struct PoseStandInTests {

    // MARK: - 表

    @Test("絵のある姿勢は、その絵のまま、その姿勢の味付けで描く（同梱の 5 体の 12 枚）")
    func posesWithPicturesKeepTheirOwn() {
        for pose in [Pose.idle, .walk, .sit, .sleep, .happy] {
            let look = PoseStandIn.resolve(pose, frameCounts: TestArt.tierOne)
            #expect(look == PoseStandIn(wanted: pose, source: pose), "\(pose)")
            #expect(!look.isBorrowed)
        }
    }

    /// 同梱の 5 体にも、見上げる・驚くの絵（Tier 2）は無い。
    @Test("見上げる・驚くの絵が無ければ、立ち姿を借り、味付けは求めた姿勢のもの")
    func tierTwoPosesBorrowTheStandingPose() {
        for pose in [Pose.lookUp, .surprised] {
            let look = PoseStandIn.resolve(pose, frameCounts: TestArt.tierOne)
            #expect(look == PoseStandIn(wanted: pose, source: .idle), "\(pose)")
            #expect(look.isBorrowed)
        }
    }

    @Test("立ち姿 1 枚の子: 歩くは跳ねて進み、寝るは目を閉じた立ち姿、すわる・よろこぶは立ち姿に味付け")
    func singlePictureTable() {
        let table = Dictionary(uniqueKeysWithValues: Pose.allCases.map {
            ($0, PoseStandIn.resolve($0, frameCounts: TestArt.single))
        })
        #expect(table[.walk] == PoseStandIn(wanted: .walk, source: .idle, flourishing: .hopWalk))
        #expect(table[.sleep] == PoseStandIn(wanted: .sleep, source: .idle,
                                             heldFrame: PoseStandIn.eyesClosedFrame))
        for pose in [Pose.idle, .sit, .happy, .lookUp, .surprised] {
            #expect(table[pose] == PoseStandIn(wanted: pose, source: .idle), "\(pose)")
        }
    }

    @Test("まばたきの絵を作れなかった 1 枚の子は、目を開けた立ち姿のまま寝る")
    func singlePictureWithoutBlinkSleepsWithEyesOpen() {
        let look = PoseStandIn.resolve(.sleep, frameCounts: TestArt.singleWithoutBlink)
        #expect(look == PoseStandIn(wanted: .sleep, source: .idle, heldFrame: 0))
    }

    @Test("ポーズの格子だけの子は、歩くときだけ立ち姿を借りる")
    func posesOnlyBorrowForWalking() {
        #expect(PoseStandIn.resolve(.walk, frameCounts: TestArt.posesOnly).flourishing == .hopWalk)
        for pose in [Pose.idle, .sit, .sleep, .happy] {
            #expect(!PoseStandIn.resolve(pose, frameCounts: TestArt.posesOnly).isBorrowed, "\(pose)")
        }
    }

    /// 同梱データが読めなかったときの仮のキャラ（`Character.placeholder`）は、絵を 1 枚も持たない。
    @Test("絵が 1 枚も無くても、立ち姿の 1 コマ目を指して落ちない")
    func noPicturesAtAll() {
        let rng = IndexedRandom(seed: 1)
        for pose in Pose.allCases {
            let look = PoseStandIn.resolve(pose, frameCounts: [:])
            #expect(look.source == .idle, "\(pose)")
            #expect(look.frameIndex(frameCount: 0, localSeconds: 12.3, rng: rng) == 0, "\(pose)")
        }
    }

    // MARK: - コマと味付け

    @Test("借りた立ち姿は、立ち姿と同じ間隔でまばたく。寝顔は目を閉じたまま")
    func borrowedFramesFollowTheStandingRhythm() {
        let rng = IndexedRandom(seed: 0x51_7B11)
        let seconds = Array(stride(from: 0.0, to: 60.0, by: 0.05))
        let standing = seconds.map { Motion.frameIndex(pose: .idle, frameCount: 2, localSeconds: $0, rng: rng) }
        for pose in [Pose.walk, .sit, .happy, .lookUp] {
            let look = PoseStandIn.resolve(pose, frameCounts: TestArt.single)
            #expect(seconds.map { look.frameIndex(frameCount: 2, localSeconds: $0, rng: rng) } == standing,
                    "\(pose)")
        }
        let sleeping = PoseStandIn.resolve(.sleep, frameCounts: TestArt.single)
        #expect(seconds.allSatisfy {
            sleeping.frameIndex(frameCount: 2, localSeconds: $0, rng: rng) == PoseStandIn.eyesClosedFrame
        })
    }

    @Test("借りた姿勢の味付けは、求めた姿勢のもの（すわるはかしげ、よろこぶは跳ね、寝るは深い寝息）")
    func borrowedPosesKeepTheWantedFlourish() {
        for pose in [Pose.sit, .happy, .sleep, .lookUp, .surprised] {
            let look = PoseStandIn.resolve(pose, frameCounts: TestArt.single)
            for seconds in [0.0, 0.31, 1.7, 5.25, 41.9] {
                #expect(look.flourish(localSeconds: seconds)
                        == ProceduralMotion.flourish(pose: pose, localSeconds: seconds), "\(pose) \(seconds)")
            }
        }
    }

    @Test("歩く絵が無いと、歩くあいだは跳ねて進む（歩く絵の弾みより高く）")
    func walkingWithoutPicturesHops() {
        let hop = PoseStandIn.resolve(.walk, frameCounts: TestArt.single)
        let walk = PoseStandIn.resolve(.walk, frameCounts: TestArt.tierOne)
        let samples = stride(from: 0.0, to: 3.0, by: 0.01)
        let hopHeight = samples.map { hop.flourish(localSeconds: $0).liftRatio }.max() ?? 0
        let walkHeight = samples.map { walk.flourish(localSeconds: $0).liftRatio }.max() ?? 0
        #expect(abs(hopHeight - ProceduralMotion.hopWalkLiftRatio) < 0.001)
        #expect(hopHeight > walkHeight * 1.5)
        #expect(hop.flourish(localSeconds: 0.5) == ProceduralMotion.hopWalking(0.5))
    }

    // MARK: - 日課エンジン

    static let floor = RoomRect(x: 0.06, y: 0.62, width: 0.88, height: 0.24)

    static func input(_ character: Character, seed: UInt64 = 0xA11_DA7) -> WorldInput {
        let ball = PlacedItem(id: "ball", kind: .mirrorBall, position: RoomPoint(x: 0.5, y: 0.3))
        let cushion = PlacedItem(id: "cu", kind: .cushion, position: RoomPoint(x: 0.8, y: 0.72))
        return WorldInput(character: character,
                          room: Room(background: .bundled("room"), floor: floor, items: [ball, cushion]),
                          userSeed: seed, calendar: TestClock.tokyo)
    }

    /// 1 日を 31.37 秒刻みで（約 2,750 の時刻）。刻みに端数を付け、コマ送り（歩く 8fps）とまばたき
    /// （0.18 秒）のどの位相にも当たるようにする。刻みが歩きのコマの周期で割り切れると、区切りの中で
    /// いつも同じコマを引き、コマ番号のずれを見逃す。
    static let day: [Date] = stride(from: 0.37, to: 24 * 3600, by: 31.37).map {
        TestClock.today(0, 0).addingTimeInterval($0)
    }

    @Test("どの段の子でも、1 日じゅう、コマ番号は描く絵の枚数に収まる", arguments: [
        TestArt.tierOne, TestArt.posesOnly, TestArt.single, TestArt.singleWithoutBlink,
    ])
    func framesStayWithinTheDrawnPictures(frames: [Pose: Int]) {
        let character = TestArt.character(id: "user-7e57", frames: frames)
        for state in SceneEngine.sceneStates(at: Self.day, input: Self.input(character)) {
            let source = character.standIn(for: state.activity.pose).source
            let count = character.frameCount(source)
            #expect(count > 0, "\(state.activity) の絵が無い")
            #expect(state.frame >= 0 && state.frame < count,
                    "\(state.activity): \(source) の \(state.frame) コマ目（\(count) 枚）")
        }
    }

    @Test("立ち姿 1 枚の子は、寝ているあいだ目を閉じ、歩くあいだ跳ねて進む")
    func singlePictureLivesThroughTheDay() {
        let character = TestArt.character(id: "user-7e57", frames: TestArt.single)
        let states = SceneEngine.sceneStates(at: Self.day, input: Self.input(character))
        let asleep = states.filter { $0.activity.isAsleep }
        let walking = states.filter { $0.activity == .wander }
        #expect(!asleep.isEmpty && !walking.isEmpty)
        #expect(asleep.allSatisfy { $0.frame == PoseStandIn.eyesClosedFrame })
        #expect(walking.contains { $0.flourish.tiltDegrees != 0 }, "跳ねて歩くと左右に揺れる")
        let highest = walking.map(\.flourish.liftRatio).max() ?? 0
        #expect(highest > ProceduralMotion.walkLiftRatio, "歩きの弾みより高く跳ねる")
    }

    /// 日課エンジンは絵の出どころを知らない（2-C ⑥）。見るのは id・性格・姿勢ごとの枚数だけ。
    @Test("絵の名前と出どころが違っても、id と性格と枚数が同じなら、同じ一日を過ごす")
    func engineIgnoresWherePicturesComeFrom() {
        let bundled = TestArt.character(id: "user-7e57", frames: TestArt.tierOne)
        var imported = bundled
        imported.origin = .user(createdAt: Date(timeIntervalSince1970: 1_790_000_000))
        imported.poses = imported.poses.mapValues { names in names.map { "hero/" + $0 } }
        #expect(SceneEngine.sceneStates(at: Self.day, input: Self.input(imported))
                == SceneEngine.sceneStates(at: Self.day, input: Self.input(bundled)))
    }

    /// 日課は id を種に含むので（§5.4）、取り込んだ子にも、その子だけの一日がある。
    @Test("絵が同じでも、id が違えば別の一日になる")
    func eachCharacterHasItsOwnDay() {
        let one = TestArt.character(id: "user-0001", frames: TestArt.single)
        let other = TestArt.character(id: "user-0002", frames: TestArt.single)
        #expect(SceneEngine.sceneStates(at: Self.day, input: Self.input(one))
                != SceneEngine.sceneStates(at: Self.day, input: Self.input(other)))
    }
}
