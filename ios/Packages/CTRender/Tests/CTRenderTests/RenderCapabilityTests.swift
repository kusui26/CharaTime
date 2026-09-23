import Testing
@testable import CTRender

/// 「キャラが消える」だけは起こさない、という約束をここで守る（プラン §7.5、3-C ⑤、R-13）。
@Suite("描画段の決定")
struct RenderCapabilityTests {

    /// 確かめた版（iOS 26.x）と、確かめていない版。
    static let verified = SystemVersion(major: 26, minor: 1)
    static let unverified = SystemVersion(major: 27, minor: 0)

    /// 何も制約が無いホーム画面ウィジェット。個々のテストは、ここから 1 つだけ変える。
    static func free(_ change: (inout RenderContext) -> Void = { _ in }) -> RenderCapability {
        var context = RenderContext(surface: .homeWidget, system: verified, tone: .fullColor,
                                    pseudoAnimationEnabled: true)
        change(&context)
        return RenderCapability.resolve(context)
    }

    @Test("段の順序が定義どおり")
    func ordering() {
        #expect(RenderCapability.staticOnly < .timelineTransition)
        #expect(RenderCapability.timelineTransition < .ambient1fps)
        #expect(RenderCapability.ambient1fps < .ambient4fps)
    }

    @Test("確かめた OS で、設定が入で、フルカラーなら、いちばん上まで上がる")
    func freeContextReachesTheTop() {
        #expect(Self.free() == .ambient4fps)
    }

    @Test("確かめた OS の表は iOS 26.x")
    func verifiedSystemTable() {
        #expect(VerifiedSystems.allowsPseudoAnimation(SystemVersion(major: 26, minor: 0)))
        #expect(VerifiedSystems.allowsPseudoAnimation(SystemVersion(major: 26, minor: 5)))
        #expect(!VerifiedSystems.allowsPseudoAnimation(SystemVersion(major: 25, minor: 9)))
        #expect(!VerifiedSystems.allowsPseudoAnimation(SystemVersion(major: 27, minor: 0)))
    }

    /// iOS の更新で疑似アニメが塞がれても、キャラは 5 分ごとの絵で見え続ける（D-22）。
    @Test("確かめていない OS では、公式の方式（5 分ごとの切り替え）に留める")
    func unverifiedSystemStaysLow() {
        #expect(Self.free { $0.system = Self.unverified } == .timelineTransition)
    }

    @Test("設定が切なら上げない")
    func featureFlagGatesTheLadder() {
        #expect(Self.free { $0.pseudoAnimationEnabled = false } == .timelineTransition)
    }

    @Test("着色・クリア（accented）と単色（vibrant）では上げない")
    func tintedAndVibrantStayLow() {
        #expect(Self.free { $0.tone = .accented } == .timelineTransition)
        #expect(Self.free { $0.tone = .vibrant } == .timelineTransition)
    }

    @Test("減光中はどんな設定でも静止画まで落ちる")
    func luminanceReducedAlwaysFallsToStatic() {
        for surface in Surface.allCases {
            let resolved = Self.free {
                $0.surface = surface
                $0.luminanceReduced = true
            }
            #expect(resolved == .staticOnly, "\(surface) が \(resolved) のままだった")
        }
    }

    @Test("省電力と Reduce Motion では上げない")
    func userPreferencesCapTheLadder() {
        #expect(Self.free { $0.lowPowerMode = true } == .timelineTransition)
        #expect(Self.free { $0.reduceMotion = true } == .timelineTransition)
    }

    @Test("ロック画面は脱色表示なので常に切り替えのみ")
    func lockScreenStaysLow() {
        #expect(Self.free { $0.surface = .lockWidget } == .timelineTransition)
    }

    @Test("Live Activity は 4KB の制約があるので 1fps まで")
    func liveActivityCappedAtOneFps() {
        #expect(Self.free { $0.surface = .liveActivity } == .ambient1fps)
    }

    @Test("待受モードは梯子の外（60fps で描く）")
    func standbyModeIsOutsideTheLadder() {
        let resolved = RenderCapability.resolve(
            RenderContext(surface: .standbyMode, system: Self.unverified, pseudoAnimationEnabled: false))
        #expect(resolved == .ambient4fps)
    }

    /// どんな入力の組み合わせでも、必ずどれかの段に落ちる（クラッシュも未定義も無い）。
    @Test("あらゆる組み合わせで必ず描ける段が返る")
    func alwaysResolvesToSomething() {
        let seen = Set(Self.everyContext().map(RenderCapability.resolve))
        #expect(seen.contains(.staticOnly))
        #expect(seen.contains(.timelineTransition))
        #expect(seen.contains(.ambient4fps))
    }

    /// Live Activity は 4KB の制約で最大 1fps だが、そこに Reduce Motion が重なれば
    /// さらに下がる。片方だけを見て答えを返すと、Reduce Motion を入れているのに動いてしまう。
    @Test("Live Activity の頭打ちと端末の状態の頭打ちが重なる")
    func liveActivityStacksWithDeviceLimits() {
        func resolve(_ change: (inout RenderContext) -> Void) -> RenderCapability {
            Self.free {
                $0.surface = .liveActivity
                change(&$0)
            }
        }
        #expect(resolve { _ in } == .ambient1fps)
        #expect(resolve { $0.reduceMotion = true } == .timelineTransition)
        #expect(resolve { $0.lowPowerMode = true } == .timelineTransition)
        #expect(resolve { $0.pseudoAnimationEnabled = false } == .timelineTransition)
        #expect(resolve { $0.system = Self.unverified } == .timelineTransition)
    }

    /// **迷ったら下げる。** 制約を 1 つ足して段が上がることは、決してあってはならない。
    @Test("制約を足すと、段は必ず下がるか同じ")
    func constraintsNeverRaiseTheLadder() {
        let constraints: [(String, (inout RenderContext) -> Void)] = [
            ("設定が切", { $0.pseudoAnimationEnabled = false }),
            ("Reduce Motion", { $0.reduceMotion = true }),
            ("省電力", { $0.lowPowerMode = true }),
            ("減光中", { $0.luminanceReduced = true }),
            ("確かめていない OS", { $0.system = Self.unverified }),
            ("着色", { $0.tone = .accented }),
            ("単色", { $0.tone = .vibrant }),
        ]
        for base in Self.everyContext() {
            let before = RenderCapability.resolve(base)
            for (name, constrain) in constraints {
                var limited = base
                constrain(&limited)
                let after = RenderCapability.resolve(limited)
                #expect(after <= before, "\(base.surface) に「\(name)」: \(before.label) → \(after.label)")
            }
        }
    }

    /// 面・OS・描き分け・設定・端末の状態の、すべての組み合わせ。
    static func everyContext() -> [RenderContext] {
        let flags = [false, true]
        return Surface.allCases.flatMap { surface in
            [verified, unverified].flatMap { system in
                WidgetTone.allCases.flatMap { tone in
                    flags.flatMap { flag in
                        flags.flatMap { motion in
                            flags.flatMap { power in
                                flags.map { dim in
                                    RenderContext(surface: surface, system: system, tone: tone,
                                                  pseudoAnimationEnabled: flag, reduceMotion: motion,
                                                  lowPowerMode: power, luminanceReduced: dim)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
