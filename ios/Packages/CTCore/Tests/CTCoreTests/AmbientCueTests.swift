import Testing
import Foundation
@testable import CTCore

/// 行動ごとの「土台と、重ねるもの」（プラン §9 Phase 3 の 3-C ④ の表、D-17）。
@Suite("ウィジェットの動かし方")
struct AmbientCueTests {

    private static let blink = DigitSet([2, 7])
    private static let ball = PlacedItem(id: "ball", kind: .mirrorBall, position: RoomPoint(x: 0.5, y: 0.7))
    private static let cushion = PlacedItem(id: "cu", kind: .cushion, position: RoomPoint(x: 0.3, y: 0.7))
    private static let room = Room(background: .bundled("room"), floor: .unit, items: [ball, cushion])

    /// いまの絵（Tier 1）。まばたきの絵は立ち姿（idle_02）とすわる姿（sit_02。3-2b で足した）にある。
    private static let tierOne = AmbientArt(eyelidPoses: [.idle, .sit], sleepFrameCoversBase: true)
    /// すわる姿のまばたきの絵が無い絵（3-2b より前の Tier 1 や、取り込んだキャラ）。
    private static let standingOnly = AmbientArt(eyelidPoses: [.idle], sleepFrameCoversBase: true)
    /// どの姿勢にもまぶたの差分がある絵（すわる・見上げるにもまばたきの絵を足したとき）。
    private static let everyEyelid = AmbientArt(eyelidPoses: Set(Pose.allCases), sleepFrameCoversBase: true)

    private func state(_ activity: Activity, bubble: Bubble? = nil) -> SceneState {
        SceneState(time: TestClock.today(20, 0), activity: activity,
                   position: RoomPoint(x: 0.5, y: 0.7), facing: .front, frame: 0, bubble: bubble)
    }

    private func cue(_ activity: Activity, bubble: Bubble? = nil, art: AmbientArt = tierOne) -> AmbientCue {
        AmbientCue.cue(for: state(activity, bubble: bubble), room: Self.room, blink: Self.blink, art: art)
    }

    private func layers(_ cue: AmbientCue) -> [AmbientLayer] { cue.overlays.map(\.layer) }

    // MARK: - まばたき

    @Test("立っているときは、立ち姿の 1 コマ目を土台に、まぶたを重ねる（タイマー 2 本）")
    func idleBlinks() {
        let idle = cue(.idle)
        #expect(idle.pose == .idle)
        #expect(idle.baseFrame == 0)
        #expect(layers(idle) == [.eyelid])
        #expect(idle.overlays.first?.window == BlinkRhythm.window(for: Self.blink))
        #expect(idle.timerCount == 2)
    }

    /// 歩く姿を 5 分止めておくと固まって見える。エントリの時刻には立ち止まった姿で描き、
    /// 居場所の移動はエントリ切替のアニメで見せる（3-C ④'）。
    @Test("歩いているときは、立ち止まった姿で描き、まばたく")
    func wanderingStandsStill() {
        let wandering = cue(.wander)
        #expect(wandering.pose == .idle)
        #expect(wandering.baseFrame == 0)
        #expect(layers(wandering) == [.eyelid])
    }

    @Test("食べるは立ち姿で、時報は立ち止まった姿で、まばたく")
    func eatingAndGreetingBlink() {
        for activity in [Activity.eat(itemId: "x"), .clockGreet] {
            #expect(cue(activity).pose == .idle)
            #expect(layers(cue(activity)) == [.eyelid])
        }
    }

    @Test("すわっているときは、すわる姿の 1 コマ目を土台に、まぶたを重ねる")
    func sittingBlinks() {
        let sitting = cue(.sit(itemId: "cu"))
        #expect(sitting.pose == .sit)
        #expect(sitting.baseFrame == 0)
        #expect(layers(sitting) == [.eyelid])
        #expect(sitting.timerCount == 2)
    }

    @Test("すわる・見上げるは、まぶたの差分があれば、その姿勢を土台にまばたく")
    func otherPosesBlinkWhenTheArtAllows() {
        let sitting = cue(.sit(itemId: "cu"), art: Self.everyEyelid)
        let looking = cue(.look(itemId: nil), art: Self.everyEyelid)
        #expect(sitting.pose == .sit && sitting.baseFrame == 0)
        #expect(looking.pose == .lookUp && looking.baseFrame == 0)
        #expect(layers(sitting) == [.eyelid])
        #expect(layers(looking) == [.eyelid])
    }

    /// まぶたの差分は、まばたきの絵から作る。見上げる姿にはまばたきの絵が無いので作れない
    /// （すわる姿も、まばたきの絵が無い絵なら同じ）。別の姿勢の差分を重ねると、顔の位置が違うので
    /// 目の外にまぶたが浮く。
    @Test("まぶたの差分が無い姿勢は、1 コマ目だけを描く（タイマー 0 本）")
    func posesWithoutEyelidStayStill() {
        let stills = [cue(.look(itemId: nil)), cue(.sit(itemId: "cu"), art: Self.standingOnly)]
        for still in stills {
            #expect(still.baseFrame == 0)
            #expect(still.overlays.isEmpty)
            #expect(still.timerCount == 0)
        }
    }

    // MARK: - 寝息

    @Test("寝ているときは、1 コマ目を土台に、2 コマ目を 5 秒のうち 2 秒重ね、z を増やしていく（3 本）")
    func sleepBreathes() {
        for activity in [Activity.sleep, .nap] {
            let sleeping = cue(activity)
            #expect(sleeping.pose == .sleep)
            #expect(sleeping.baseFrame == 0)
            #expect(layers(sleeping) == [.frame(1), .sleepMark(1), .sleepMark(2)])
            #expect(sleeping.overlays.first?.window == .when(.sleepBreath))
            #expect(sleeping.timerCount == 3)
        }
    }

    /// 1 つ目の z は出したまま。2 つ目・3 つ目が順に出て、5 秒ごとに z → zz → zzz と増える（2026-09-25）。
    @Test("寝ているときの z は、5 秒ごとに z（2 秒）→ zz（1 秒）→ zzz（2 秒）と増える")
    func sleepMarksBuildUp() throws {
        let sleeping = cue(.sleep)
        let second = try #require(sleeping.overlays.first { $0.layer == .sleepMark(1) }?.window)
        let third = try #require(sleeping.overlays.first { $0.layer == .sleepMark(2) }?.window)
        let expected = [1, 1, 2, 3, 3]
        for secondOfMinute in 0..<20 {
            let time = TestClock.today(23, 10, Double(secondOfMinute) + 0.5)
            let shown = 1 + [second, third].filter { $0.isOpen(at: time, calendar: TestClock.tokyo) }.count
            #expect(shown == expected[secondOfMinute % 5], "\(secondOfMinute) 秒に z が \(shown) つ")
        }
    }

    /// 2 コマ目が 1 コマ目を覆えないと、重ねても 1 コマ目がはみ出して見える。
    @Test("2 コマ目が土台を覆えないときは、2 枚を出し分け、いつもどちらか 1 枚だけが見える")
    func sleepWithoutCoverAlternates() {
        let art = AmbientArt(eyelidPoses: [.idle], sleepFrameCoversBase: false)
        let sleeping = cue(.sleep, art: art)
        #expect(sleeping.pose == .sleep)
        #expect(sleeping.baseFrame == nil)
        #expect(layers(sleeping) == [.frame(0), .frame(1), .sleepMark(1), .sleepMark(2)])
        #expect(sleeping.timerCount == 4)
        assertExactlyOneShown(sleeping, seconds: 10)
    }

    // MARK: - よろこぶ・おどる

    @Test("よろこぶときは、よろこぶ姿の 2 コマを 1 秒ごとに出し分ける（土台なし、2 本）")
    func cheeringAlternates() {
        for activity in [Activity.happyStretch, .play(itemId: "cu"), .dance(itemId: "cu")] {
            let cheering = cue(activity)
            #expect(cheering.pose == .happy)
            #expect(cheering.baseFrame == nil)
            #expect(layers(cheering) == [.frame(0), .frame(1)])
            #expect(cheering.timerCount == 2)
            assertExactlyOneShown(cheering, seconds: 6)
        }
    }

    @Test("ミラーボールでおどるときは、光の粒を 4 つ重ねる（合わせて 6 本）")
    func danceWithMirrorBallSparkles() {
        let dancing = cue(.dance(itemId: "ball"))
        #expect(dancing.pose == .happy)
        #expect(layers(dancing) == [.frame(0), .frame(1), .sparkle(0), .sparkle(1), .sparkle(2), .sparkle(3)])
        #expect(dancing.timerCount == 6)
        #expect(dancing.overlays.filter { $0.pace == .quarterSecond }.count == 4)
    }

    /// 光の粒は 0.25 秒ずつずらしてあるので、4 つのうちどれかが 0.25 秒ごとに入れ替わる。
    @Test("光の粒は、0.25 秒ごとにどれかが入れ替わる")
    func sparklesChangeFourTimesASecond() {
        let sparkles = cue(.dance(itemId: "ball")).overlays.filter { $0.pace == .quarterSecond }
        let start = TestClock.today(20, 30, 0.1)
        let patterns = (0..<8).map { step in
            sparkles.map { $0.window.isOpen(at: start.addingTimeInterval(Double(step) * 0.25),
                                            calendar: TestClock.tokyo) }
        }
        for (before, after) in zip(patterns, patterns.dropFirst()) {
            #expect(before != after)
        }
    }

    @Test("ミラーボールでないアイテムや、無いアイテムでは、光の粒を出さない")
    func noSparklesWithoutMirrorBall() {
        #expect(cue(.dance(itemId: "cu")).timerCount == 2)
        #expect(cue(.dance(itemId: "missing")).timerCount == 2)
    }

    // MARK: - 時報

    @Test("時報の吹き出しは、まぶたに加えて 2 本")
    func clockBubbleAddsTwoTimers() {
        let greeting = cue(.clockGreet, bubble: Bubble(text: "20時だよ", kind: .clock))
        #expect(layers(greeting) == [.eyelid, .clockBubble])
        #expect(greeting.timerCount == 4)
    }

    @Test("挨拶や独り言の吹き出しは、窓で出し入れしない（エントリのあいだずっと出す）")
    func otherBubblesAreNotWindowed() {
        let morning = cue(.idle, bubble: Bubble(text: "おはよう", kind: .greeting))
        #expect(layers(morning) == [.eyelid])
    }

    // MARK: - 本数の上限と、描画の段

    /// 日課エンジンでは、時報の 30 秒はおどりを止めて立ち止まるので、両方は重ならない。
    /// それでも重なったとき（8 本）に、上限の 8 本に収まることを確かめる。
    @Test("おどり・光の粒・時報が重なっても、上限の 8 本に収まる")
    func worstCaseFitsTheBudget() {
        let crowded = cue(.dance(itemId: "ball"), bubble: Bubble(text: "20時だよ", kind: .clock))
        #expect(crowded.timerCount == AmbientCue.maximumTimers)
        #expect(layers(crowded).contains(.clockBubble))
    }

    @Test("上限を超えるときは、光の粒、時報の順に外し、キャラの動きは残す")
    func dropsSparklesThenBubble() {
        let crowded = cue(.dance(itemId: "ball"), bubble: Bubble(text: "20時だよ", kind: .clock))
        #expect(layers(crowded.fitted(toTimers: 6)) == [.frame(0), .frame(1), .clockBubble])
        #expect(layers(crowded.fitted(toTimers: 3)) == [.frame(0), .frame(1)])
        #expect(layers(crowded.fitted(toTimers: 0)) == [.frame(0), .frame(1)])
        #expect(crowded.fitted(toTimers: 3).pose == .happy)
    }

    /// 寝ている z は飾りなので、光の粒と同じく先に外す。寝息（キャラの動き）は最後まで残す。
    @Test("上限を超えるときは、寝ている z を先に外し、寝息は残す")
    func dropsSleepMarksBeforeBreathing() {
        let sleeping = cue(.sleep, art: AmbientArt(eyelidPoses: [.idle], sleepFrameCoversBase: false))
        #expect(layers(sleeping.fitted(toTimers: 3)) == [.frame(0), .frame(1)])
        #expect(sleeping.limited(to: .perSecond) == sleeping)
    }

    @Test("1fps までの段では、光の粒を外す")
    func limitedToOncePerSecond() {
        let dancing = cue(.dance(itemId: "ball"))
        let limited = dancing.limited(to: .perSecond)
        #expect(layers(limited) == [.frame(0), .frame(1)])
        #expect(limited.pose == dancing.pose && limited.baseFrame == dancing.baseFrame)
        #expect(dancing.limited(to: .quarterSecond) == dancing)
    }

    @Test("日課エンジンのどの姿でも、上限を超えず、絵があれば必ず何かが動く")
    func everySceneStateFits() {
        let world = WorldInput(
            character: Character(id: "piyo", displayName: "ピヨ",
                                 personality: Personality(activity: 0.9, nightOwl: 0.5, napiness: 0.6,
                                                          favorites: [.mirrorBall]),
                                 poses: [:]),
            room: Self.room, userSeed: 0xC0FFEE, calendar: TestClock.tokyo)
        let times = (0..<(24 * 60 / 5)).map { TestClock.today(0, 0).addingTimeInterval(Double($0) * 300) }
        for state in SceneEngine.sceneStates(at: times, input: world) {
            let rich = AmbientCue.cue(for: state, room: Self.room, blink: Self.blink, art: Self.everyEyelid)
            let plain = AmbientCue.cue(for: state, room: Self.room, blink: Self.blink, art: Self.tierOne)
            #expect(rich.timerCount <= AmbientCue.maximumTimers)
            #expect(rich.timerCount >= 1, "動かし方の無い姿: \(state.activity)")
            #expect(plain.timerCount <= rich.timerCount)
        }
    }

    /// 描画の段が変わっても（5 分ごとの切り替え ⇄ 1fps）、描く姿勢は変わらない。
    @Test("動かし方の姿勢は、止めた 1 枚の姿勢と同じ")
    func cuePoseMatchesStillPose() {
        let activities: [Activity] = [.sleep, .nap, .wander, .idle, .sit(itemId: "cu"), .dance(itemId: "ball"),
                                      .play(itemId: "cu"), .look(itemId: nil), .eat(itemId: "x"),
                                      .clockGreet, .happyStretch]
        for activity in activities {
            #expect(cue(activity).pose == activity.stillPose, "\(activity)")
        }
    }

    // MARK: - 道具

    /// 出し分ける 2 枚（コマ）は、どの瞬間もちょうど 1 枚だけが見えていなければならない。
    /// 数えるのはコマだけ（寝ている z のような飾りは、コマと一緒に出ていてよい）。
    private func assertExactlyOneShown(_ cue: AmbientCue, seconds: Double,
                                       sourceLocation: SourceLocation = #_sourceLocation) {
        let start = TestClock.today(14, 0, 0.05)
        let frames = cue.overlays.filter { if case .frame = $0.layer { true } else { false } }
        for step in 0..<Int(seconds * 4) {
            let time = start.addingTimeInterval(Double(step) * 0.25)
            let shown = frames.filter { $0.window.isOpen(at: time, calendar: TestClock.tokyo) }
            #expect(shown.count == 1, "\(step) 番目の時刻で \(shown.count) 枚", sourceLocation: sourceLocation)
        }
    }
}
