import Foundation

/// 時刻から「いまの姿」を引く。**すべての面がこの関数を同じ入力で呼ぶ。**
///
/// 待受モードは毎フレーム、ウィジェットは 5 分刻みの未来の時刻で呼ぶ。
/// どちらも同じ答えが返るので、ホーム画面で見た姿とアプリを開いた姿が一致する。
public enum SceneEngine {

    /// 毎正時、この秒数のあいだは立ち止まって時刻を知らせる。ガラケー待受の要。
    public static let clockGreetSeconds: Double = 30
    /// 起床・就寝の挨拶を出す長さ。
    public static let greetingMinutes: Double = 3
    /// 時報の判定に使う 1 時間の秒数。
    static let secondsPerHour: Double = 3600

    /// ある時刻の姿。
    public static func sceneState(at time: Date, input: WorldInput) -> SceneState {
        let day = DayKey(time, calendar: input.calendar)
        return sceneState(at: time, input: input, plan: DayPlan.make(for: day, input: input))
    }

    /// 行動表を使い回す版。
    ///
    /// 行動表を作るのは 1 回あたり 0.3 ミリ秒ほどかかるが、引くだけなら 6 マイクロ秒で済む。
    /// 待受モードは毎フレーム呼ぶので、同じ日のあいだは表を持ち回したい。
    ///
    /// **渡された表が別の日のものだったら、黙って作り直す。** 呼び出し側が日付の変わり目を
    /// 取りこぼしても、間違った姿を返すよりは作り直すほうがよい。
    public static func sceneState(at time: Date, input: WorldInput, plan: DayPlan) -> SceneState {
        let today = DayKey(time, calendar: input.calendar)
        guard plan.day == today else {
            return sceneState(at: time, input: input, plan: DayPlan.make(for: today, input: input))
        }
        let minute = clampToDay(input.calendar.minuteOfDay(time))
        let segment = plan.segment(atMinute: minute)
        let rng = segmentRandom(for: segment, in: plan, input: input)

        var state = posture(in: segment, atMinute: minute, time: time, input: input, rng: rng)
        state.bubble = greeting(at: minute, plan: plan)
        applyClockGreet(to: &state, atMinute: minute)
        stillWhileAsleep(&state, in: segment)
        state.frame = frameIndex(for: state, in: segment, atMinute: minute,
                                 character: input.character, rng: rng)
        return Interrupts.apply(to: state, context: input.context)
    }

    /// 0:00 以上 24:00 未満に収める。
    static func clampToDay(_ minute: Double) -> Double {
        Swift.min(Swift.max(minute, 0), Schedule.minutesPerDay - Schedule.epsilonMinutes)
    }

    /// 区切りごとに独立した乱数列。
    ///
    /// 区切りの開始時刻を種に混ぜるので、ひとつの区切りが変わっても、
    /// ほかの区切りの動き（経由点のゆらぎやまばたきの間隔）は変わらない。
    static func segmentRandom(for segment: Segment, in plan: DayPlan,
                              input: WorldInput) -> IndexedRandom {
        IndexedRandom(seed: input.userSeed,
                      StableHash.string(input.character.id),
                      plan.day.seedComponent,
                      UInt64(bitPattern: Int64(segment.startMinute * 100)))
    }

    /// 区切りから素直に導かれる姿（割り込みを当てる前）。
    static func posture(in segment: Segment, atMinute minute: Double, time: Date,
                        input: WorldInput, rng: IndexedRandom) -> SceneState {
        let floor = input.room.floor
        return SceneState(
            time: time,
            activity: segment.activity,
            position: Motion.position(in: segment, atMinute: minute, rng: rng, floor: floor),
            facing: Motion.facing(in: segment, atMinute: minute, rng: rng, floor: floor),
            frame: 0)
    }

    /// 毎正時の時報。歩いていても立ち止まって正面を向く。眠っているあいだは起こさない。
    static func applyClockGreet(to state: inout SceneState, atMinute minute: Double) {
        let secondOfHour = (minute * 60).truncatingRemainder(dividingBy: secondsPerHour)
        guard secondOfHour < clockGreetSeconds, !Interrupts.isAsleep(state.activity) else { return }
        let hour = Int(minute / 60) % 24
        state.activity = .clockGreet
        state.facing = .front
        state.bubble = Bubble(text: "\(hour)時だよ", kind: .clock)
    }

    /// 眠っているあいだは動かない。
    static func stillWhileAsleep(_ state: inout SceneState, in segment: Segment) {
        guard Interrupts.isAsleep(state.activity) else { return }
        state.position = segment.from
        state.facing = .front
    }

    /// いま何コマ目か。**姿勢が確定したあとに呼ぶ**（コマ数は姿勢ごとに違うため）。
    static func frameIndex(for state: SceneState, in segment: Segment, atMinute minute: Double,
                           character: CTCore.Character, rng: IndexedRandom) -> Int {
        let pose = state.activity.pose
        return Motion.frameIndex(pose: pose,
                                 frameCount: character.frameCount(pose),
                                 localSeconds: (minute - segment.startMinute) * 60,
                                 rng: rng)
    }

    /// 複数の時刻をまとめて。同じ日の行動表を作り直さないので、ウィジェットの
    /// タイムライン生成（5 分刻みで 48〜72 件）でも一度の計算で済む。
    public static func sceneStates(at times: [Date], input: WorldInput) -> [SceneState] {
        var cache: [DayKey: DayPlan] = [:]
        return times.map { time in
            let day = DayKey(time, calendar: input.calendar)
            let plan = cache[day] ?? DayPlan.make(for: day, input: input)
            cache[day] = plan
            return sceneState(at: time, input: input, plan: plan)
        }
    }

    /// 起きたときと寝る前の挨拶。
    static func greeting(at minute: Double, plan: DayPlan) -> Bubble? {
        if minute >= plan.wakeMinute, minute < plan.wakeMinute + greetingMinutes {
            return Bubble(text: "おはよう", kind: .greeting)
        }
        let bedtime = plan.bedtimeMinute
        if bedtime < Schedule.minutesPerDay,
           minute >= bedtime - greetingMinutes, minute < bedtime {
            return Bubble(text: "おやすみ", kind: .greeting)
        }
        return nil
    }
}
