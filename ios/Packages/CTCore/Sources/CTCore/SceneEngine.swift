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
        let minute = Swift.min(Swift.max(input.calendar.minuteOfDay(time), 0),
                               Schedule.minutesPerDay - 0.000_1)
        let segment = plan.segment(atMinute: minute)
        let floor = input.room.floor

        // 区切りごとに独立した乱数列。区切りが 1 つ変わっても、ほかの区切りの動きは変わらない。
        let rng = IndexedRandom(seed: input.userSeed,
                                StableHash.string(input.character.id),
                                plan.day.seedComponent,
                                UInt64(bitPattern: Int64(segment.startMinute * 100)))

        let localSeconds = (minute - segment.startMinute) * 60
        var activity = segment.activity
        var position = Motion.position(in: segment, atMinute: minute, rng: rng, floor: floor)
        var facing = Motion.facing(in: segment, atMinute: minute, rng: rng, floor: floor)
        var bubble = greeting(at: minute, plan: plan, activity: activity)

        // 毎正時の時報。歩いていても立ち止まって正面を向く。
        let secondOfHour = (minute * 60).truncatingRemainder(dividingBy: 3600)
        if secondOfHour < clockGreetSeconds, !Interrupts.isAsleep(activity) {
            let hour = Int(minute / 60) % 24
            activity = .clockGreet
            facing = .front
            bubble = Bubble(text: "\(hour)時だよ", kind: .clock)
        }

        // 眠っているあいだは動かない。
        if Interrupts.isAsleep(activity) {
            position = segment.from
            facing = .front
        }

        let pose = activity.pose
        let frame = Motion.frameIndex(pose: pose,
                                      frameCount: input.character.frameCount(pose),
                                      localSeconds: localSeconds, rng: rng)

        let state = SceneState(time: time, activity: activity, position: position,
                               facing: facing, frame: frame, bubble: bubble)
        return Interrupts.apply(to: state, context: input.context)
    }

    /// 複数の時刻をまとめて。同じ日の行動表を作り直さないので、ウィジェットの
    /// タイムライン生成（5 分刻みで 48〜72 件）でも一度の計算で済む。
    public static func sceneStates(at times: [Date], input: WorldInput) -> [SceneState] {
        var cache: [DayKey: DayPlan] = [:]
        return times.map { time in
            let day = DayKey(time, calendar: input.calendar)
            let plan: DayPlan
            if let cached = cache[day] {
                plan = cached
            } else {
                plan = DayPlan.make(for: day, input: input)
                cache[day] = plan
            }
            return sceneState(at: time, input: input, plan: plan)
        }
    }

    /// 起きたときと寝る前の挨拶。
    static func greeting(at minute: Double, plan: DayPlan, activity: Activity) -> Bubble? {
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
