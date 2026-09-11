import Testing
import Foundation
@testable import CTCore

/// 「すべての面が同じ時刻から同じ姿を得る」という約束を守るためのテスト。
@Suite("時刻から姿を引く")
struct SceneEngineTests {

    static var tokyo: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }

    static let floor = RoomRect(x: 0.06, y: 0.62, width: 0.88, height: 0.24)

    static func world(nightOwl: Double = 0.1, items: [PlacedItem] = [],
                      context: ContextSnapshot? = nil, seed: UInt64 = 0xBEEF_0001) -> WorldInput {
        WorldInput(
            character: Character(id: "piyo", displayName: "ピヨ",
                                 personality: Personality(activity: 0.9, nightOwl: nightOwl, napiness: 0.2),
                                 poses: [.idle: ["a", "b"], .walk: ["w1", "w2", "w3", "w4"],
                                         .sit: ["s"], .sleep: ["z1", "z2"], .happy: ["h1", "h2"]]),
            room: Room(background: .bundled("room"), floor: floor, items: items),
            userSeed: seed, context: context, calendar: tokyo)
    }

    /// 日本時間の日時から `Date` を作る。
    static func at(_ hour: Int, _ minute: Int, _ second: Int = 0, day: Int = 11) -> Date {
        var parts = DateComponents()
        parts.year = 2026; parts.month = 9; parts.day = day
        parts.hour = hour; parts.minute = minute; parts.second = second
        return tokyo.date(from: parts)!
    }

    // MARK: - 決定論

    @Test("同じ時刻を何度引いても同じ姿")
    func deterministic() {
        let world = Self.world()
        for hour in 0..<24 {
            let time = Self.at(hour, 17)
            #expect(SceneEngine.sceneState(at: time, input: world)
                    == SceneEngine.sceneState(at: time, input: world))
        }
    }

    /// ウィジェットは行動表を使い回して 5 分刻みのエントリを作る。
    /// その道と、1 件ずつ引く道で答えが変わってはいけない。
    @Test("まとめて引いても 1 件ずつ引いても同じ")
    func batchMatchesIndividual() {
        let world = Self.world()
        let times = (0..<72).map { Self.at(9, 0).addingTimeInterval(Double($0) * 300) }
        let batch = SceneEngine.sceneStates(at: times, input: world)
        for (time, fromBatch) in zip(times, batch) {
            #expect(fromBatch == SceneEngine.sceneState(at: time, input: world))
        }
    }

    // MARK: - 一日の流れ

    @Test("深夜は寝ていて、昼は起きている")
    func sleepsAtNightAndIsAwakeAtNoon() {
        let world = Self.world()
        #expect(Interrupts.isAsleep(SceneEngine.sceneState(at: Self.at(3, 0), input: world).activity))
        #expect(Interrupts.isAsleep(SceneEngine.sceneState(at: Self.at(4, 30), input: world).activity))
        #expect(!Interrupts.isAsleep(SceneEngine.sceneState(at: Self.at(12, 30), input: world).activity))
        #expect(!Interrupts.isAsleep(SceneEngine.sceneState(at: Self.at(17, 20), input: world).activity))
    }

    @Test("起きた直後は「おはよう」と言う")
    func greetsOnWaking() {
        let world = Self.world()
        let plan = DayPlan.make(for: DayKey(year: 2026, month: 9, day: 11), input: world)
        let wakeHour = Int(plan.wakeMinute) / 60
        let wakeMinute = Int(plan.wakeMinute) % 60
        let state = SceneEngine.sceneState(at: Self.at(wakeHour, wakeMinute, 40), input: world)
        #expect(state.bubble?.text == "おはよう")
        #expect(state.bubble?.kind == .greeting)
    }

    @Test("寝る直前は「おやすみ」と言う")
    func greetsBeforeSleeping() {
        let world = Self.world()
        let plan = DayPlan.make(for: DayKey(year: 2026, month: 9, day: 11), input: world)
        guard plan.bedtimeMinute < Schedule.minutesPerDay else { return }
        let minute = plan.bedtimeMinute - 1
        let state = SceneEngine.sceneState(at: Self.at(Int(minute) / 60, Int(minute) % 60, 30), input: world)
        #expect(state.bubble?.text == "おやすみ")
    }

    /// ガラケー待受らしさの要（プラン §5.4）。
    @Test("毎正時に立ち止まって時刻を知らせる")
    func announcesTheHour() {
        let world = Self.world()
        for hour in [10, 13, 16, 19] {
            let onTheHour = SceneEngine.sceneState(at: Self.at(hour, 0, 5), input: world)
            #expect(onTheHour.activity == .clockGreet, "\(hour) 時に時報が出ない")
            #expect(onTheHour.facing == .front)
            #expect(onTheHour.bubble?.text == "\(hour)時だよ")
            #expect(onTheHour.bubble?.kind == .clock)

            // 30 秒を過ぎたら元の行動に戻る
            let later = SceneEngine.sceneState(at: Self.at(hour, 0, 45), input: world)
            #expect(later.activity != .clockGreet)
        }
    }

    @Test("寝ているあいだは時報を出さない")
    func doesNotAnnounceWhileAsleep() {
        let world = Self.world()
        let state = SceneEngine.sceneState(at: Self.at(3, 0, 5), input: world)
        #expect(state.activity != .clockGreet)
        #expect(state.bubble == nil)
    }

    // MARK: - 位置と見た目

    @Test("一日じゅう床の中にいる")
    func staysOnTheFloorAllDay() {
        let world = Self.world(items: [
            PlacedItem(id: "mb", kind: .mirrorBall, position: RoomPoint(x: 0.5, y: 0.70)),
            PlacedItem(id: "cu", kind: .cushion, position: RoomPoint(x: 0.88, y: 0.74))])
        let times = (0..<Int(Schedule.minutesPerDay)).map { Self.at($0 / 60, $0 % 60) }
        for state in SceneEngine.sceneStates(at: times, input: world) {
            #expect(Self.floor.contains(state.position), "\(state.time) に \(state.position) にいた")
        }
    }

    /// 1 秒で床を横切るような動きをしたら、それは瞬間移動している。
    @Test("秒ごとに見ても、なめらかに動く")
    func movesSmoothly() {
        let world = Self.world(items: [PlacedItem(id: "cu", kind: .cushion, position: RoomPoint(x: 0.88, y: 0.74))])
        let start = Self.at(9, 0)
        // 9:00 から 15:00 まで 1 秒刻み。まとめて引くのは、行動表を作り直さないぶん速いから
        // （ウィジェットも同じ道を通る）。求める答えは 1 件ずつ引いたときと同じ。
        let times = (0...(6 * 3600)).map { start.addingTimeInterval(Double($0)) }
        let states = SceneEngine.sceneStates(at: times, input: world)
        var longestStep = 0.0
        for (previous, next) in zip(states, states.dropFirst()) {
            longestStep = max(longestStep, previous.position.distance(to: next.position))
        }
        #expect(longestStep < 0.08, "1 秒で \(longestStep) 動いた（瞬間移動の疑い）")
        #expect(longestStep > 0.000_1, "まったく動いていない")
    }

    @Test("コマ番号が用意した枚数に収まる")
    func frameIndexInRange() {
        let world = Self.world()
        let start = Self.at(0, 0)
        let times = stride(from: 0, to: 24 * 3600, by: 7).map { start.addingTimeInterval(Double($0)) }
        for state in SceneEngine.sceneStates(at: times, input: world) {
            let count = world.character.frameCount(state.activity.pose)
            #expect(state.frame >= 0)
            #expect(state.frame < max(1, count),
                    "\(state.activity) で \(state.frame) コマ目（用意は \(count) 枚）")
        }
    }

    @Test("歩いているあいだは向きが左右のどちらかになる")
    func facesTheDirectionOfTravel() {
        let world = Self.world()
        var sawLeft = false, sawRight = false
        let start = Self.at(10, 0)
        let times = stride(from: 0, to: 5 * 3600, by: 11).map { start.addingTimeInterval(Double($0)) }
        for state in SceneEngine.sceneStates(at: times, input: world) {
            guard case .wander = state.activity else { continue }
            if state.facing == .left { sawLeft = true }
            if state.facing == .right { sawRight = true }
            #expect(state.facing == .left || state.facing == .right)
        }
        #expect(sawLeft && sawRight, "片方向にしか歩いていない")
    }

    @Test("眠っているあいだは動かない")
    func doesNotMoveWhileAsleep() {
        let world = Self.world()
        let first = SceneEngine.sceneState(at: Self.at(2, 0), input: world)
        for minute in stride(from: 0, to: 90, by: 7) {
            let state = SceneEngine.sceneState(at: Self.at(2, 0).addingTimeInterval(Double(minute) * 60), input: world)
            guard Interrupts.isAsleep(state.activity) else { continue }
            #expect(state.position == first.position)
            #expect(state.facing == .front)
        }
    }

    // MARK: - 割り込み

    @Test("電池が少ないと歩き回らなくなる")
    func lowBatterySlowsItDown() {
        let time = Self.at(14, 22)
        let lively = Self.world()
        guard case .wander = SceneEngine.sceneState(at: time, input: lively).activity else {
            return   // たまたま歩いていない時刻なら、この検査は成り立たない
        }
        let tired = Self.world(context: ContextSnapshot(batteryLevel: 0.08, isCharging: false,
                                                        capturedAt: time))
        let state = SceneEngine.sceneState(at: time, input: tired)
        #expect(state.activity == .idle)
    }

    @Test("充電を始めると少しのあいだ喜ぶ")
    func celebratesCharging() {
        let time = Self.at(14, 22)
        let charging = Self.world(context: ContextSnapshot(batteryLevel: 0.4, isCharging: true,
                                                           capturedAt: time))
        let state = SceneEngine.sceneState(at: time.addingTimeInterval(30), input: charging)
        #expect(state.activity == .happyStretch)
        #expect(state.bubble?.text == "ありがとう")

        // ずっと喜んでいるとうるさいので、しばらくすると元に戻る
        let later = SceneEngine.sceneState(at: time.addingTimeInterval(400), input: charging)
        #expect(later.bubble?.text != "ありがとう")
    }

    @Test("寝ているあいだは充電に反応しない")
    func doesNotCelebrateWhileAsleep() {
        let time = Self.at(3, 10)
        let charging = Self.world(context: ContextSnapshot(batteryLevel: 0.4, isCharging: true,
                                                           capturedAt: time))
        let state = SceneEngine.sceneState(at: time.addingTimeInterval(30), input: charging)
        #expect(Interrupts.isAsleep(state.activity))
    }

    /// 姿勢ごとにコマ数が違う（歩く 4 枚・よろこぶ 2 枚）。割り込みで姿勢を差し替えたとき、
    /// 歩いている 4 コマ目のままだと、2 枚しかない配列の 4 番目を引いて落ちる。
    ///
    /// **端数の秒でずらして調べること。** ちょうどの秒（:00、:30）で引くと
    /// 歩きのコマ番号がいつも同じ値になり（`Int(秒 × 8) % 4` が 0 に張りつく）、
    /// コマ番号のずれを見逃す。
    @Test("割り込みで姿勢が変わったら、コマ番号が新しい姿勢の範囲に収まる")
    func interruptKeepsFrameInRange() {
        let character = Self.world().character
        let offsetsSeconds = [0.37, 12.8, 41.15, 77.6]
        for minute in stride(from: 0, to: 24 * 60, by: 7) {
            let time = Self.at(minute / 60, minute % 60)
            let contexts = [ContextSnapshot(batteryLevel: 0.4, isCharging: true, capturedAt: time),
                            ContextSnapshot(batteryLevel: 0.05, isCharging: false, capturedAt: time)]
            for context in contexts {
                for offset in offsetsSeconds {
                    let state = SceneEngine.sceneState(at: time.addingTimeInterval(offset),
                                                       input: Self.world(context: context))
                    let frameCount = character.frameCount(state.activity.pose)
                    let message = "\(minute / 60):\(minute % 60)+\(offset)秒 \(state.activity.label)"
                        + " コマ \(state.frame) / \(frameCount) 枚"
                    #expect(state.frame >= 0 && state.frame < Swift.max(1, frameCount),
                            Comment(rawValue: message))
                }
            }
        }
    }

    // MARK: - 速さ

    /// ウィジェットは 5 分刻みで 4〜6 時間ぶん（48〜72 件）のエントリを一度に作る。
    @Test("ウィジェット 1 回ぶんのエントリがすぐ作れる", .timeLimit(.minutes(1)))
    func widgetTimelineIsFast() {
        let world = Self.world(items: [PlacedItem(id: "cu", kind: .cushion, position: RoomPoint(x: 0.8, y: 0.72))])
        let start = Self.at(7, 0)
        for round in 0..<50 {
            let times = (0..<72).map { start.addingTimeInterval(Double(round * 60 + $0 * 300)) }
            let states = SceneEngine.sceneStates(at: times, input: world)
            #expect(states.count == 72)
        }
    }
}

@Suite("行動表の受け渡し")
struct PlanHandoffTests {

    /// 待受モードは表を持ち回して毎フレーム引く。日付をまたいだときに
    /// 古い表を渡し続けても、間違った姿を返してはいけない。
    @Test("別の日の表を渡されたら作り直す")
    func stalePlanIsRebuilt() {
        let world = SceneEngineTests.world()
        let yesterday = DayPlan.make(for: DayKey(year: 2026, month: 9, day: 10), input: world)
        let time = SceneEngineTests.at(14, 30, day: 11)

        let withStalePlan = SceneEngine.sceneState(at: time, input: world, plan: yesterday)
        let fresh = SceneEngine.sceneState(at: time, input: world)
        #expect(withStalePlan == fresh)
    }

    @Test("正しい日の表なら、作り直したときと同じ答えになる")
    func matchingPlanGivesSameAnswer() {
        let world = SceneEngineTests.world()
        let plan = DayPlan.make(for: DayKey(year: 2026, month: 9, day: 11), input: world)
        for minute in stride(from: 0, to: 1440, by: 13) {
            let time = SceneEngineTests.at(minute / 60, minute % 60, day: 11)
            #expect(SceneEngine.sceneState(at: time, input: world, plan: plan)
                    == SceneEngine.sceneState(at: time, input: world))
        }
    }

    @Test("日付をまたぐ連続した時刻でも、姿が飛ばない")
    func continuousAcrossMidnight() {
        let world = SceneEngineTests.world(nightOwl: 0.95)   // 夜ふかしする子
        let base = SceneEngineTests.at(23, 55, day: 11)
        // 日をまたぐので、まとめ引きの中で行動表が作り直される道も同時に確かめている。
        let times = (0...(20 * 60)).map { base.addingTimeInterval(Double($0)) }
        let states = SceneEngine.sceneStates(at: times, input: world)
        var longestStep = 0.0
        for (previous, next) in zip(states, states.dropFirst()) {
            longestStep = max(longestStep, previous.position.distance(to: next.position))
        }
        #expect(longestStep < 0.08, "日付の変わり目で \(longestStep) 飛んだ")
    }
}
