import Testing
import Foundation
@testable import CTCore

/// 本体アプリが読んだ文脈（電池・充電）と、それをウィジェットがどう使うか（プラン §9 Phase 3 の 3-C ⑩）。
@Suite("文脈")
struct ContextTests {

    private let noon = TestClock.today(12, 0)

    // MARK: - 読み直し

    @Test("前の文脈が無いまま充電中なら、いま充電を始めたとみなす")
    func firstReadingWhileCharging() {
        let reading = ContextSnapshot.reading(batteryLevel: 0.5, isCharging: true, at: noon, previous: nil)
        #expect(reading.chargingSince == noon)
        #expect(reading.capturedAt == noon)
    }

    /// 充電したままアプリを開き直すたびに「ありがとう」と言い直さない。
    @Test("充電したまま読み直しても、充電を始めた時刻は変わらない")
    func keepsChargingStart() {
        let first = ContextSnapshot.reading(batteryLevel: 0.5, isCharging: true, at: noon, previous: nil)
        let later = noon.addingTimeInterval(1800)
        let again = ContextSnapshot.reading(batteryLevel: 0.7, isCharging: true, at: later, previous: first)
        #expect(again.chargingSince == noon)
        #expect(again.capturedAt == later)
        #expect(again.batteryLevel == 0.7)
    }

    @Test("充電していなかったところから充電を始めたら、その時刻にする")
    func startsCharging() {
        let unplugged = ContextSnapshot.reading(batteryLevel: 0.3, isCharging: false, at: noon, previous: nil)
        let plugged = noon.addingTimeInterval(60)
        let charging = ContextSnapshot.reading(batteryLevel: 0.3, isCharging: true, at: plugged,
                                               previous: unplugged)
        #expect(unplugged.chargingSince == nil)
        #expect(charging.chargingSince == plugged)
    }

    @Test("充電をやめたら、始めた時刻は消える")
    func stopsCharging() {
        let charging = ContextSnapshot(batteryLevel: 0.9, isCharging: true, capturedAt: noon, chargingSince: noon)
        let reading = ContextSnapshot.reading(batteryLevel: 0.9, isCharging: false,
                                              at: noon.addingTimeInterval(60), previous: charging)
        #expect(reading.chargingSince == nil)
    }

    @Test("始めた時刻が分からない充電は、分からないまま引き継ぐ")
    func unknownStartStaysUnknown() {
        let unknown = ContextSnapshot(isCharging: true, capturedAt: noon)
        let reading = ContextSnapshot.reading(batteryLevel: 0.6, isCharging: true,
                                              at: noon.addingTimeInterval(60), previous: unknown)
        #expect(reading.chargingSince == nil)
    }

    @Test("電池と一緒に読まない歩数は、前の値を引き継ぐ")
    func keepsStepCount() {
        let previous = ContextSnapshot(stepCount: 4200, capturedAt: noon)
        let reading = ContextSnapshot.reading(batteryLevel: 0.6, isCharging: false,
                                              at: noon.addingTimeInterval(60), previous: previous)
        #expect(reading.stepCount == 4200)
    }

    // MARK: - 割り込み

    private func wandering(at time: Date) -> SceneState {
        SceneState(time: time, activity: .wander, position: RoomPoint(x: 0.5, y: 0.7), facing: .left, frame: 2)
    }

    @Test("読んでから 1 時間のうちは、電池が少ないと歩き回らない")
    func freshLowBatterySlowsDown() {
        let context = ContextSnapshot(batteryLevel: 0.08, isCharging: false, capturedAt: noon)
        let state = Interrupts.apply(to: wandering(at: noon.addingTimeInterval(3599)), context: context)
        #expect(state.activity == .idle)
    }

    /// アプリを開かないあいだに電池の値は古くなる。朝の 10% のまま一日じゅう歩かせない（罰を与えない）。
    @Test("1 時間より古い電池の値では、歩みを鈍らせない")
    func staleLowBatteryIsIgnored() {
        let context = ContextSnapshot(batteryLevel: 0.08, isCharging: false, capturedAt: noon)
        let state = Interrupts.apply(to: wandering(at: noon.addingTimeInterval(3600)), context: context)
        #expect(state.activity == .wander)
    }

    @Test("読んだ時刻より前の姿には、電池の値を当てない")
    func contextFromTheFutureIsIgnored() {
        let context = ContextSnapshot(batteryLevel: 0.08, isCharging: false, capturedAt: noon)
        let state = Interrupts.apply(to: wandering(at: noon.addingTimeInterval(-60)), context: context)
        #expect(state.activity == .wander)
    }

    @Test("喜ぶのは、充電を始めてから 3 分のあいだだけ")
    func celebratesOnlyAfterChargingStarts() {
        let started = noon
        let context = ContextSnapshot(batteryLevel: 0.4, isCharging: true,
                                      capturedAt: started.addingTimeInterval(1200), chargingSince: started)
        let during = Interrupts.apply(to: wandering(at: started.addingTimeInterval(179)), context: context)
        let after = Interrupts.apply(to: wandering(at: started.addingTimeInterval(180)), context: context)
        #expect(during.activity == .happyStretch)
        #expect(after.activity == .wander)
    }

    // MARK: - ウィジェットを作り直すか

    private func reading(_ level: Double, charging: Bool = false, since: Date? = nil,
                         at offsetSeconds: TimeInterval = 0) -> ContextSnapshot {
        ContextSnapshot(batteryLevel: level, isCharging: charging,
                        capturedAt: noon.addingTimeInterval(offsetSeconds), chargingSince: since)
    }

    @Test("電池が少ないとみなすのは、しきい値を下回り、充電していないときだけ")
    func lowBatteryNeedsLevelAndNoCharging() {
        #expect(reading(0.14).isLowBattery)
        #expect(!reading(0.15).isLowBattery)
        #expect(!reading(0.05, charging: true).isLowBattery)
        #expect(!ContextSnapshot(capturedAt: noon).isLowBattery)       // 読めていない
    }

    @Test("初めて読んだときは、作り直す")
    func firstReadingChangesTheScene() {
        #expect(Interrupts.mayChangeScene(from: nil, to: reading(0.5)))
        #expect(!Interrupts.mayChangeScene(from: nil, to: nil))
    }

    /// 充電中は 1% ごとに知らせが来る。そのたびに 73 件を描き直させない。
    @Test("残りが少し減っただけでは、作り直さない")
    func smallLevelChangesAreIgnored() {
        #expect(!Interrupts.mayChangeScene(from: reading(0.50), to: reading(0.49, at: 120)))
        #expect(!Interrupts.mayChangeScene(from: reading(0.8, charging: true, since: noon),
                                           to: reading(0.81, charging: true, since: noon, at: 60)))
    }

    @Test("充電を始めたとき・やめたときは、作り直す")
    func chargingChangesTheScene() {
        #expect(Interrupts.mayChangeScene(from: reading(0.5), to: reading(0.5, charging: true, since: noon)))
        #expect(Interrupts.mayChangeScene(from: reading(0.5, charging: true, since: noon), to: reading(0.5)))
    }

    @Test("電池が少なくなったとき・戻ったときは、作り直す")
    func crossingTheThresholdChangesTheScene() {
        #expect(Interrupts.mayChangeScene(from: reading(0.16), to: reading(0.14, at: 60)))
        #expect(Interrupts.mayChangeScene(from: reading(0.14), to: reading(0.14, charging: true, since: noon)))
    }

    /// 鈍るのは読んでから 1 時間だけ。読み直した時刻を渡さないと、ウィジェットだけ先に元気になる。
    @Test("電池が少ないあいだは、読み直しただけでも作り直す")
    func rereadingWhileLowChangesTheScene() {
        #expect(Interrupts.mayChangeScene(from: reading(0.10), to: reading(0.10, at: 600)))
        #expect(!Interrupts.mayChangeScene(from: reading(0.40), to: reading(0.40, at: 600)))
    }

    @Test("充電中でも、始めた時刻が分からなければ喜ばない")
    func noCelebrationWithoutStart() {
        let context = ContextSnapshot(batteryLevel: 0.4, isCharging: true, capturedAt: noon)
        let state = Interrupts.apply(to: wandering(at: noon.addingTimeInterval(10)), context: context)
        #expect(state.activity == .wander)
    }
}
