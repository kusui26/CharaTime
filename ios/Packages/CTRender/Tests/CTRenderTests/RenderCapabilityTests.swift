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

    /// 面の頭打ちと、端末の状態による頭打ちは、**両方かかる**。
    ///
    /// Live Activity は 4KB の制約で最大 1fps だが、そこに Reduce Motion が重なれば
    /// さらに下がる。片方だけを見て答えを返すと、Reduce Motion を入れているのに
    /// 動いてしまう。
    @Test("Live Activity の頭打ちと端末の状態の頭打ちが重なる")
    func liveActivityStacksWithDeviceLimits() {
        func resolve(reduceMotion: Bool = false, lowPower: Bool = false,
                     pseudoAnimation: Bool = true) -> RenderCapability {
            RenderCapability.resolve(RenderContext(
                surface: .liveActivity, spike: .go, pseudoAnimationEnabled: pseudoAnimation,
                reduceMotion: reduceMotion, lowPowerMode: lowPower))
        }
        #expect(resolve() == .ambient1fps)
        #expect(resolve(reduceMotion: true) == .timelineTransition)
        #expect(resolve(lowPower: true) == .timelineTransition)
        #expect(resolve(pseudoAnimation: false) == .timelineTransition)
    }

    /// **迷ったら下げる。** 制約を 1 つ足して段が上がることは、決してあってはならない。
    @Test("制約を足すと、段は必ず下がるか同じ")
    func constraintsNeverRaiseTheLadder() {
        for surface in Surface.allCases {
            for spike in [SpikeVerdict.unknown, .go, .conditionalGo, .noGo] {
                let free = RenderCapability.resolve(RenderContext(
                    surface: surface, spike: spike, pseudoAnimationEnabled: true))
                let constraints: [RenderContext] = [
                    RenderContext(surface: surface, spike: spike,
                                  pseudoAnimationEnabled: false),
                    RenderContext(surface: surface, spike: spike,
                                  pseudoAnimationEnabled: true, reduceMotion: true),
                    RenderContext(surface: surface, spike: spike,
                                  pseudoAnimationEnabled: true, lowPowerMode: true),
                    RenderContext(surface: surface, spike: spike,
                                  pseudoAnimationEnabled: true, luminanceReduced: true)
                ]
                for context in constraints {
                    let limited = RenderCapability.resolve(context)
                    let message = "\(surface) \(spike): \(free.label) → \(limited.label)"
                    #expect(limited <= free, Comment(rawValue: message))
                }
            }
        }
    }
}
