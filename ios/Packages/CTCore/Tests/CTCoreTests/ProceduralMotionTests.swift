import Testing
import Foundation
@testable import CTCore

/// 味付けは「絵を足さずに動きを足す」ためのもの。やりすぎると絵が壊れて見えるので、
/// **どの時刻でも度を越さないこと**をここで見張る。
@Suite("プロシージャルな味付け")
struct ProceduralMotionTests {

    /// 1 日ぶんを細かく刻んで調べる。周期がどれも数秒なので、0.05 秒刻みで 60 秒も
    /// 見ればすべての位相を通る。
    static let samples: [Double] = stride(from: 0.0, through: 60.0, by: 0.05).map { $0 }

    @Test("同じ時刻を何度引いても同じ味付け")
    func deterministic() {
        for pose in Pose.allCases {
            for seconds in [0.0, 0.37, 4.2, 59.9] {
                #expect(ProceduralMotion.flourish(pose: pose, localSeconds: seconds)
                        == ProceduralMotion.flourish(pose: pose, localSeconds: seconds))
            }
        }
    }

    @Test("どの姿勢でも、どの時刻でも、度を越さない")
    func staysWithinBounds() {
        for pose in Pose.allCases {
            for seconds in Self.samples {
                let flourish = ProceduralMotion.flourish(pose: pose, localSeconds: seconds)
                let note = "\(pose) \(seconds) 秒: \(flourish)"
                #expect((0...0.08).contains(flourish.liftRatio), Comment(rawValue: note))
                #expect((0.92...1.08).contains(flourish.stretchX), Comment(rawValue: note))
                #expect((0.92...1.08).contains(flourish.stretchY), Comment(rawValue: note))
                #expect(abs(flourish.tiltDegrees) <= 6, Comment(rawValue: note))
                #expect((0.5...1.0).contains(flourish.shadowScale), Comment(rawValue: note))
                #expect((0.5...1.0).contains(flourish.shadowOpacity), Comment(rawValue: note))
            }
        }
    }

    @Test("眠っているあいだは浮かないし、傾かない")
    func sleepingStaysOnTheFloor() {
        for seconds in Self.samples {
            let flourish = ProceduralMotion.flourish(pose: .sleep, localSeconds: seconds)
            #expect(flourish.liftRatio == 0)
            #expect(flourish.tiltDegrees == 0)
            #expect(flourish.shadowScale == 1)
        }
    }

    @Test("眠っているときの呼吸は、立っているときよりゆっくり深い")
    func sleepBreathesSlowerAndDeeper() {
        func amplitude(_ pose: Pose, period: Double) -> Double {
            let samples = stride(from: 0.0, through: period, by: period / 200)
                .map { ProceduralMotion.flourish(pose: pose, localSeconds: $0).stretchY }
            return (samples.max() ?? 1) - (samples.min() ?? 1)
        }
        let standing = amplitude(.idle, period: ProceduralMotion.breathPeriodSeconds)
        let sleeping = amplitude(.sleep, period: ProceduralMotion.sleepBreathPeriodSeconds)
        #expect(sleeping > standing)
        #expect(ProceduralMotion.sleepBreathPeriodSeconds > ProceduralMotion.breathPeriodSeconds)
    }

    @Test("歩きの弾みは、着地で 0・歩の半ばで最大")
    func walkBouncesOncePerStep() {
        let period = ProceduralMotion.walkBouncePeriodSeconds
        #expect(ProceduralMotion.flourish(pose: .walk, localSeconds: 0).liftRatio == 0)
        let peak = ProceduralMotion.flourish(pose: .walk, localSeconds: period / 2).liftRatio
        #expect(abs(peak - ProceduralMotion.walkLiftRatio) < 0.000_1)
        // 1 周したら戻る
        let landed = ProceduralMotion.flourish(pose: .walk, localSeconds: period).liftRatio
        #expect(landed < 0.000_1)
    }

    @Test("浮いているときは影が小さく薄くなる")
    func shadowFollowsTheLift() {
        for pose in [Pose.walk, .happy] {
            let onGround = ProceduralMotion.flourish(pose: pose, localSeconds: 0)
            let highest = (0...200).map {
                ProceduralMotion.flourish(pose: pose, localSeconds: Double($0) * 0.01)
            }.max { $0.liftRatio < $1.liftRatio }
            guard let lifted = highest else { Issue.record("味付けが 1 つも取れなかった"); return }
            #expect(lifted.shadowScale < onGround.shadowScale)
            #expect(lifted.shadowOpacity < onGround.shadowOpacity)
        }
    }

    @Test("味付けなしは、まったく動かさない値")
    func stillIsNeutral() {
        let still = Flourish.still
        #expect(still.liftRatio == 0)
        #expect(still.stretchX == 1)
        #expect(still.stretchY == 1)
        #expect(still.tiltDegrees == 0)
        #expect(still.shadowScale == 1)
        #expect(still.shadowOpacity == 1)
    }

    @Test("すわると、ときどき首をかしげる")
    func sittingTiltsNowAndThen() {
        let tilts = Self.samples.map {
            ProceduralMotion.flourish(pose: .sit, localSeconds: $0).tiltDegrees
        }
        #expect((tilts.max() ?? 0) > 3)
        #expect((tilts.min() ?? 0) < -3)
    }
}
