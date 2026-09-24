import Testing
import Foundation
@testable import CTCore

/// マスク書体の一族（プラン §9 Phase 3 の 3-2b）。動かし方が使う窓を、この書体だけで描けるか。
@Suite("マスク書体の一族")
struct MaskFontFamilyTests {

    private static let ball = PlacedItem(id: "ball", kind: .mirrorBall, position: RoomPoint(x: 0.5, y: 0.7))
    private static let room = Room(background: .bundled("room"), floor: .unit, items: [ball])
    private static let activities: [Activity] = [
        .sleep, .nap, .wander, .idle, .sit(itemId: nil), .dance(itemId: "ball"), .dance(itemId: "none"),
        .play(itemId: "x"), .look(itemId: nil), .eat(itemId: "x"), .clockGreet, .happyStretch,
    ]
    private static let arts = [AmbientArt(eyelidPoses: Set(Pose.allCases), sleepFrameCoversBase: true),
                               AmbientArt(eyelidPoses: [], sleepFrameCoversBase: false)]

    /// 動かし方が作りうる窓のすべて（どの行動・まばたきの集まり・絵・吹き出しでも）。
    private static func everyWindow() -> [TimerWindow] {
        let bubbles: [Bubble?] = [nil, Bubble(text: "12時だよ", kind: .clock)]
        return activities.flatMap { activity in
            BlinkRhythm.candidates.flatMap { blink in
                arts.flatMap { art in
                    bubbles.flatMap { bubble in
                        let state = SceneState(time: TestClock.today(12, 0), activity: activity,
                                               position: RoomPoint(x: 0.5, y: 0.7), facing: .front,
                                               frame: 0, bubble: bubble)
                        return AmbientCue.cue(for: state, room: room, blink: blink, art: art)
                            .overlays.map(\.window)
                    }
                }
            }
        }
    }

    @Test("動かし方が使う窓は、回した形にすれば一族の書体だけで描ける（足りない書体も余る書体も無い）")
    func familyCoversEveryWindow() {
        let used = Set(Self.everyWindow().flatMap { $0.canonical.terms.map(\.digits) })
        let family = Set(MaskFontFamily.digitSets)
        #expect(used == family,
                "足りない \(used.subtracting(family).map(\.key))、余り \(family.subtracting(used).map(\.key))")
    }

    @Test("まばたきの 15 通りは 2 本の書体で足りる")
    func blinkNeedsTwoFonts() {
        let blinkSets = Set(BlinkRhythm.candidates.flatMap {
            BlinkRhythm.window(for: $0).canonical.terms.map(\.digits)
        })
        #expect(blinkSets == [DigitSet([0, 5]), DigitSet([0, 3, 6])])
    }

    /// 描き手はマスクを入れ子にして「かつ」を作る。入れ子は 2 段までにしてある。
    @Test("どの窓も、タイマー 2 本までの「かつ」")
    func windowsNestAtMostTwoMasks() {
        #expect(Self.everyWindow().allSatisfy { (1...2).contains($0.timerCount) })
    }

    @Test("書体の名前になる集まりは、重ならず、空でない")
    func familyKeysAreUnique() {
        let keys = MaskFontFamily.digitSets.map(\.key)
        #expect(Set(keys).count == keys.count)
        #expect(keys.allSatisfy { !$0.isEmpty })
    }
}
