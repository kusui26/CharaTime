import Testing
@testable import CTRender

/// 「キャラが消える」だけは起こさない、という約束をここで守る（プラン §7.5、R-13）。
@Suite("描画段の決定")
struct RenderCapabilityTests {

    @Test("段の順序が定義どおり")
    func ordering() {
        #expect(RenderCapability.staticOnly < .timelineTransition)
        #expect(RenderCapability.timelineTransition < .ambient1fps)
        #expect(RenderCapability.ambient1fps < .ambient4fps)
    }

    @Test("測る前は安全側（公式の方式）に留まる")
    func unknownSpikeIsSafe() {
        let resolved = RenderCapability.resolve(RenderContext(surface: .homeWidget))
        #expect(resolved == .timelineTransition)
    }

    @Test("スパイクが Go でも、設定が切なら上げない")
    func featureFlagGatesTheLadder() {
        let off = RenderCapability.resolve(
            RenderContext(surface: .homeWidget, spike: .go, pseudoAnimationEnabled: false))
        #expect(off == .timelineTransition)

        let on = RenderCapability.resolve(
            RenderContext(surface: .homeWidget, spike: .go, pseudoAnimationEnabled: true))
        #expect(on == .ambient4fps)
    }

    @Test("Conditional Go と No-Go では上げない")
    func conditionalAndNoGoStayLow() {
        for verdict in [SpikeVerdict.conditionalGo, .noGo] {
            let resolved = RenderCapability.resolve(
                RenderContext(surface: .homeWidget, spike: verdict, pseudoAnimationEnabled: true))
            #expect(resolved == .timelineTransition, "\(verdict) で \(resolved) になった")
        }
    }

    @Test("減光中はどんな設定でも静止画まで落ちる")
    func luminanceReducedAlwaysFallsToStatic() {
        for surface in Surface.allCases {
            let resolved = RenderCapability.resolve(
                RenderContext(surface: surface, spike: .go,
                              pseudoAnimationEnabled: true, luminanceReduced: true))
            #expect(resolved == .staticOnly, "\(surface) が \(resolved) のままだった")
        }
    }

    @Test("省電力と Reduce Motion では上げない")
    func userPreferencesCapTheLadder() {
        let lowPower = RenderCapability.resolve(
            RenderContext(surface: .homeWidget, spike: .go,
                          pseudoAnimationEnabled: true, lowPowerMode: true))
        #expect(lowPower == .timelineTransition)

        let reduceMotion = RenderCapability.resolve(
            RenderContext(surface: .homeWidget, spike: .go,
                          pseudoAnimationEnabled: true, reduceMotion: true))
        #expect(reduceMotion == .timelineTransition)
    }

    @Test("ロック画面は脱色表示なので常に切り替えのみ")
    func lockScreenStaysLow() {
        let resolved = RenderCapability.resolve(
            RenderContext(surface: .lockWidget, spike: .go, pseudoAnimationEnabled: true))
        #expect(resolved == .timelineTransition)
    }

    @Test("Live Activity は 4KB の制約があるので 1fps まで")
    func liveActivityCappedAtOneFps() {
        let resolved = RenderCapability.resolve(
            RenderContext(surface: .liveActivity, spike: .go, pseudoAnimationEnabled: true))
        #expect(resolved == .ambient1fps)
    }

    @Test("待受モードは梯子の外（60fps で描く）")
    func standbyModeIsOutsideTheLadder() {
        let resolved = RenderCapability.resolve(
            RenderContext(surface: .standbyMode, spike: .unknown, pseudoAnimationEnabled: false))
        #expect(resolved == .ambient4fps)
    }

    /// どんな入力の組み合わせでも、必ずどれかの段に落ちる（クラッシュも未定義も無い）。
    @Test("あらゆる組み合わせで必ず描ける段が返る")
    func alwaysResolvesToSomething() {
        var seen = Set<RenderCapability>()
        for surface in Surface.allCases {
            for spike in [SpikeVerdict.unknown, .go, .conditionalGo, .noGo] {
                for flag in [true, false] {
                    for motion in [true, false] {
                        for power in [true, false] {
                            for dim in [true, false] {
                                seen.insert(RenderCapability.resolve(RenderContext(
                                    surface: surface, spike: spike, pseudoAnimationEnabled: flag,
                                    reduceMotion: motion, lowPowerMode: power, luminanceReduced: dim)))
                            }
                        }
                    }
                }
            }
        }
        #expect(seen.contains(.staticOnly))
        #expect(seen.contains(.timelineTransition))
        #expect(seen.contains(.ambient4fps))
    }
}
