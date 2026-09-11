import Foundation

/// 1 日の行動表の 1 区切り。
///
/// 位置は `from` から `to` へ動く。止まっている行動では両者が同じ値になる。
/// 区切りの終わりの位置が次の区切りの始まりの位置になるので、1 日を通して
/// キャラの位置は連続する（瞬間移動しない）。
public struct Segment: Sendable, Equatable {
    /// その日の 0:00 から数えた分。
    public let startMinute: Double
    public let endMinute: Double
    public let activity: Activity
    public let from: RoomPoint
    public let to: RoomPoint

    public init(startMinute: Double, endMinute: Double, activity: Activity,
                from: RoomPoint, to: RoomPoint) {
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.activity = activity
        self.from = from
        self.to = to
    }

    public var durationMinutes: Double { endMinute - startMinute }
    public var isMoving: Bool { from != to }
}

/// その日の行動表。0:00 から 24:00 までを隙間なく覆う。
public struct DayPlan: Sendable, Equatable {
    public let day: DayKey
    public let segments: [Segment]
    /// その日の起床時刻（0:00 から数えた分）。
    public let wakeMinute: Double
    /// その日の就寝時刻。1440 を超えるときは日付をまたぐ。
    public let bedtimeMinute: Double

    /// 指定した時刻を含む区切り。二分探索なので区切りが増えても速い。
    public func segment(atMinute minute: Double) -> Segment {
        let clamped = Swift.min(Swift.max(minute, 0), Schedule.minutesPerDay - 0.000_1)
        var low = 0
        var high = segments.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if segments[mid].startMinute <= clamped { low = mid } else { high = mid - 1 }
        }
        return segments[low]
    }
}

/// 日課の形を決める数値。すべてここに集めて、調整を 1 か所で行えるようにする。
public enum Schedule {
    public static let minutesPerDay: Double = 1440

    /// 区切りの境目は 5 分の倍数に揃える。ウィジェットのタイムラインが 5 分刻みなので、
    /// 境目が一致していないと「ウィジェットで見た姿」と「直後にアプリを開いた姿」がずれる。
    public static let gridMinutes: Double = 5

    /// 就寝は 22:00〜01:00 のあいだ。夜型度が上がるほど遅くなる。
    public static let bedtimeEarliestMinute: Double = 22 * 60
    public static let bedtimeSpanMinutes: Double = 180
    /// 起床は 6:00〜9:00 のあいだ。
    public static let wakeEarliestMinute: Double = 6 * 60
    public static let wakeSpanMinutes: Double = 180
    /// 就寝・起床のゆらぎ（5 分刻みで ±4 段 ＝ ±20 分）。
    public static let jitterSteps = 4

    /// 起きたあと伸びをしている時間。
    public static let wakeUpStretchMinutes: Double = 5
    /// ふつうの区切りの長さ（5〜25 分）。
    public static let segmentStepsMin = 1
    public static let segmentStepsMax = 5
    /// アイテムまで歩いていくのにかける時間。
    public static let approachMinutes: Double = 5
    /// これ以上離れていたら、歩いて近づいてから使う（床の幅に対する比）。
    public static let approachThresholdRatio: Double = 0.08

    /// 分どうしを比べるときの許容誤差。
    ///
    /// 丸めの誤差で「長さ 0 の区切り」や「0.00001 分の隙間」が生まれるのを防ぐ。
    /// 1 分の 1 万分の 1（＝ 6 マイクロ秒）なので、見た目には現れない。
    public static let epsilonMinutes: Double = 0.000_1

    /// ミラーボールで踊りたくなる時間帯。
    public static let danceStartMinute: Double = 19 * 60
    public static let danceEndMinute: Double = 23 * 60
    /// うたたねをしたくなる時間帯。この外でもまれにうとうとする（そのほうが自然なので）。
    public static let napStartMinute: Double = 11 * 60
    public static let napEndMinute: Double = 16 * 60

    static func snapToGrid(_ minute: Double) -> Double {
        (minute / gridMinutes).rounded() * gridMinutes
    }
}

/// 乱数列を用途ごとに分ける合い言葉。
///
/// 同じ種・同じ日から複数の値を引くので、用途ごとに違う定数を混ぜて列を分ける。
/// **一度決めたら変えない。** 変えるとその日の行動が丸ごと変わる。
enum RandomScope {
    /// 就寝・起床の時刻。
    static let sleepWindow: UInt64 = 0x51EE_9000
    /// 眠る場所。
    static let sleepSpot: UInt64 = 0x5_BED_0000
    /// 夜ふかしして日付をまたいだときの 0:00 の居場所。
    static let midnight: UInt64 = 0x4D1D_0000
    /// 起きているあいだの区切りの抽選。
    static let awakeSlot: UInt64 = 1
}

/// 行動を抽選するときの重み。
///
/// **この数値の組み合わせが「一日の過ごし方」を決める。** 歩きすぎ・踊りすぎを
/// 直したいときはここだけを触る。いまの値は、起きているあいだの内訳が
/// 歩く 3 割・立ち止まる 3 割・すわる 2 割ほどになるよう合わせてある
/// （テスト「一日の過ごし方が、歩きっぱなしにならない」が見張っている）。
enum ActivityWeight {

    /// 歩く。活発さで 0.20〜0.75 まで変わる。性格の差がいちばん出るところ。
    static let wanderBase: Double = 0.20
    static let wanderPerActivity: Double = 0.55
    /// 立ち止まる。
    static let idle: Double = 0.45
    /// 床にすわる。
    static let sitOnFloor: Double = 0.30

    /// うたたね。昼寝の時間帯では、ねぼすけ度に比例する。
    static let napPerNapiness: Double = 0.50
    /// ベッドがあるときのうたたね。寝床のほうが少し寝入りやすい。
    static let bedNapPerNapiness: Double = 0.60
    /// 時間帯の外でも、まれにうとうとする。0 にすると不自然に規則正しくなる。
    static let napOutsideWindow: Double = 0.02

    /// アイテムが増やす行動。
    static let sitOnItem: Double = 0.35
    static let play: Double = 0.28
    static let look: Double = 0.18
    static let eat: Double = 0.12
    /// ミラーボールで踊る。夜の時間帯だけ高い。
    static let danceAtNight: Double = 0.55
    static let danceInDaytime: Double = 0.015

    /// 好物の後押し。
    static let favoriteMultiplier: Double = 1.8
    /// **後押しは、その行動をしたくなる場面でだけ効かせる。**
    /// この値以下の重み（昼間の踊りなど）には掛けない。掛けると、好物というだけで
    /// 昼間からミラーボールの下で踊り続けてしまう。
    static let favoriteFloor: Double = 0.1

    /// 直前と同じ行動の起きにくさ。
    ///
    /// 同じ場所で同じことを続けると「決まった動きの繰り返し」に見えるので抑える。
    /// 強く抑えすぎると、活発な子とそうでない子の差まで消える（0.08 で消えた）。
    static let repeatSuppression: Double = 0.25
    /// **歩くことには抑制をかけない。** 行き先が毎回変わるので繰り返しには見えず、
    /// ここを抑えると性格の差が消える。
    static let unsuppressedKey = "wander"
}

// MARK: - 就寝と起床

public extension DayPlan {

    /// その日の就寝・起床時刻。性格の夜型度で前後し、日ごとに ±20 分ゆらぐ。
    static func sleepWindow(for day: DayKey, input: WorldInput) -> (bedtime: Double, wake: Double) {
        let rng = IndexedRandom(seed: input.userSeed,
                                StableHash.string(input.character.id),
                                day.seedComponent,
                                0x51EE_9000)
        let owl = input.character.personality.nightOwl
        let bedBase = Schedule.bedtimeEarliestMinute + owl * Schedule.bedtimeSpanMinutes
        let wakeBase = Schedule.wakeEarliestMinute + owl * Schedule.wakeSpanMinutes
        let jitter = -Schedule.jitterSteps...Schedule.jitterSteps
        let bedJitter = Double(rng.int(jitter, 0)) * Schedule.gridMinutes
        let wakeJitter = Double(rng.int(jitter, 1)) * Schedule.gridMinutes
        return (bedtime: Schedule.snapToGrid(bedBase) + bedJitter,
                wake: Schedule.snapToGrid(wakeBase) + wakeJitter)
    }
}

// MARK: - 夜をまたぐ位置

public extension DayPlan {

    /// その晩に眠る場所。ベッドがあればベッド、無ければその晩ごとに決まる場所。
    ///
    /// **前日の表と当日の表が同じ答えを出せるように、日付だけから決める。**
    /// ここが日ごとに変わると、0:00 をまたいだ瞬間にキャラが瞬間移動する。
    static func sleepSpot(night day: DayKey, input: WorldInput) -> RoomPoint {
        if let bed = input.room.items.first(where: { $0.kind == .bed }) {
            return input.room.floor.clamping(bed.position)
        }
        let rng = IndexedRandom(seed: input.userSeed,
                                StableHash.string(input.character.id),
                                day.seedComponent,
                                0x5_BED_0000)
        return input.room.floor.at(rng.unit(0), rng.unit(1))
    }

    /// その日の 0:00 時点でいる場所。前の晩の過ごし方で決まる。
    static func midnightPosition(for day: DayKey, input: WorldInput) -> RoomPoint {
        let previous = day.advanced(by: -1)
        let previousBedtime = sleepWindow(for: previous, input: input).bedtime
        if previousBedtime <= Schedule.minutesPerDay {
            return sleepSpot(night: previous, input: input)      // 前日のうちに寝ている
        }
        // 夜ふかしして起きたまま日付をまたいだ場合
        let rng = IndexedRandom(seed: input.userSeed,
                                StableHash.string(input.character.id),
                                previous.seedComponent,
                                0x4D1D_0000)
        return input.room.floor.at(rng.unit(0), rng.unit(1))
    }
}

// MARK: - 行動の抽選

/// 抽選の候補。`key` は「同じ行動が続くのを抑える」ための識別子。
struct ActivityChoice {
    let activity: Activity
    /// その行動をする場所。nil なら「いまいる場所」または自由に歩く。
    let anchor: RoomPoint?
    let weight: Double
    let key: String

    /// 重みだけを差し替えた同じ候補。
    func reweighted(_ transform: (Double) -> Double) -> ActivityChoice {
        ActivityChoice(activity: activity, anchor: anchor, weight: transform(weight), key: key)
    }
}

extension DayPlan {

    /// その時刻に取りうる行動と重み。
    ///
    /// アイテムが行動の語彙を増やす（プラン §5.6）。ミラーボールを置くと夜に踊るのは、
    /// `itemChoices` が時間帯に応じて重みを足しているから。
    ///
    /// **並び順を変えないこと。** `weightedIndex` は添字の順で引くので、
    /// 順番が変わるとその日の行動が丸ごと変わる。
    static func choices(atMinute minute: Double, input: WorldInput,
                        previousKey: String?) -> [ActivityChoice] {
        let all = basicChoices(atMinute: minute, personality: input.character.personality)
            + itemChoices(atMinute: minute, input: input)
        return suppressingRepeat(of: previousKey, in: all)
    }

    /// アイテムが無くてもできること。
    static func basicChoices(atMinute minute: Double,
                             personality: Personality) -> [ActivityChoice] {
        let napWeight = isNapTime(minute)
            ? personality.napiness * ActivityWeight.napPerNapiness
            : ActivityWeight.napOutsideWindow
        return [
            ActivityChoice(activity: .wander, anchor: nil,
                           weight: ActivityWeight.wanderBase
                               + personality.activity * ActivityWeight.wanderPerActivity,
                           key: "wander"),
            ActivityChoice(activity: .idle, anchor: nil,
                           weight: ActivityWeight.idle, key: "idle"),
            ActivityChoice(activity: .sit(itemId: nil), anchor: nil,
                           weight: ActivityWeight.sitOnFloor, key: "sit-floor"),
            ActivityChoice(activity: .nap, anchor: nil,
                           weight: napWeight, key: "nap")
        ]
    }

    /// 置いてあるアイテムが増やす行動。
    static func itemChoices(atMinute minute: Double, input: WorldInput) -> [ActivityChoice] {
        let personality = input.character.personality
        let floor = input.room.floor
        return input.room.items.flatMap { item in
            let favored = personality.favorites.contains(item.kind)
                ? ActivityWeight.favoriteMultiplier : 1.0
            return item.kind.affordances.map { affordance in
                let (activity, base) = offer(affordance, of: item,
                                             atMinute: minute, personality: personality)
                // 好物の後押しは、その行動をしたくなる場面でだけ効かせる。
                let weight = base > ActivityWeight.favoriteFloor ? base * favored : base
                return ActivityChoice(activity: activity, anchor: floor.clamping(item.position),
                                      weight: weight, key: "\(affordance.rawValue)-\(item.id)")
            }
        }
    }

    /// アイテムの用途ひとつぶんの、行動と素の重み。
    private static func offer(_ affordance: Affordance, of item: PlacedItem, atMinute minute: Double,
                              personality: Personality) -> (Activity, Double) {
        switch affordance {
        case .sit:
            (.sit(itemId: item.id), ActivityWeight.sitOnItem)
        case .sleep:
            (.nap, isNapTime(minute)
                ? personality.napiness * ActivityWeight.bedNapPerNapiness
                : ActivityWeight.napOutsideWindow)
        case .dance:
            (.dance(itemId: item.id), isDanceTime(minute)
                ? ActivityWeight.danceAtNight : ActivityWeight.danceInDaytime)
        case .play: (.play(itemId: item.id), ActivityWeight.play)
        case .look: (.look(itemId: item.id), ActivityWeight.look)
        case .eat:  (.eat(itemId: item.id), ActivityWeight.eat)
        }
    }

    /// 直前と同じ行動を起きにくくする。歩くことだけは抑えない。
    private static func suppressingRepeat(of previousKey: String?,
                                          in choices: [ActivityChoice]) -> [ActivityChoice] {
        guard let previousKey, previousKey != ActivityWeight.unsuppressedKey else { return choices }
        return choices.map { choice in
            choice.key == previousKey
                ? choice.reweighted { $0 * ActivityWeight.repeatSuppression }
                : choice
        }
    }

    static func isNapTime(_ minute: Double) -> Bool {
        minute >= Schedule.napStartMinute && minute < Schedule.napEndMinute
    }

    static func isDanceTime(_ minute: Double) -> Bool {
        minute >= Schedule.danceStartMinute && minute < Schedule.danceEndMinute
    }
}

// MARK: - 日課表の組み立て

/// 日課表を組み立てるあいだの、書きかけの状態。
///
/// 「いまどこまで埋めたか・どこに居るか」をこの型の中だけに閉じ込めて、
/// `DayPlan.make(for:input:)` を短く保つ。組み立てが終わったら捨てる。
private struct PlanBuilder {
    let input: WorldInput
    let rng: IndexedRandom

    private(set) var segments: [Segment] = []
    /// 埋め終わった時刻（その日の 0:00 から数えた分）。
    private(set) var cursor: Double = 0
    private(set) var position: RoomPoint
    /// 直前に選んだ行動。同じ行動が続くのを抑えるために持つ。
    private var previousKey: String?
    /// 抽選に使った回数。区切りごとに違う乱数列を引くための添字。
    private var step: UInt64 = 0

    init(input: WorldInput, rng: IndexedRandom, startingAt position: RoomPoint) {
        self.input = input
        self.rng = rng
        self.position = position
    }

    /// 区切りをひとつ足して、時刻と位置を進める。
    private mutating func append(_ activity: Activity, until end: Double, movingTo destination: RoomPoint) {
        guard end > cursor else { return }
        segments.append(Segment(startMinute: cursor, endMinute: end,
                                activity: activity, from: position, to: destination))
        position = destination
        cursor = end
    }

    /// その場でじっとしている区切り。
    mutating func stay(_ activity: Activity, until end: Double) {
        append(activity, until: end, movingTo: position)
    }

    /// 眠る。起きたときは「直前に何をしていたか」を忘れる。
    mutating func sleep(until end: Double) {
        stay(.sleep, until: end)
        previousKey = nil
    }

    /// 起きているあいだを、抽選した行動で隙間なく埋める。
    mutating func fillAwake(until limit: Double) {
        while cursor < limit - Schedule.epsilonMinutes {
            guard fillOneSlot(until: limit) else { return }
        }
    }

    /// 区切りをひとつ抽選して埋める。選べる行動が無ければ false。
    private mutating func fillOneSlot(until limit: Double) -> Bool {
        let slotRng = rng.scoped(RandomScope.awakeSlot, step)
        let all = DayPlan.choices(atMinute: cursor, input: input, previousKey: previousKey)
        guard let picked = slotRng.weightedIndex(all.map(\.weight), 0).map({ all[$0] }) else {
            return false
        }
        step += 1

        if let anchor = picked.anchor, !approach(anchor, until: limit) { return true }

        let steps = slotRng.int(Schedule.segmentStepsMin...Schedule.segmentStepsMax, 1)
        let end = Swift.min(cursor + Double(steps) * Schedule.gridMinutes, limit)
        let destination: RoomPoint = switch picked.activity {
        case .wander: input.room.floor.at(slotRng.unit(2), slotRng.unit(3))
        default: picked.anchor ?? position
        }
        append(picked.activity, until: end, movingTo: destination)
        previousKey = picked.key
        return true
    }

    /// アイテムが離れていたら歩いて近づく。瞬間移動させないため。
    /// 近づくだけで時間切れになったら false（その区切りの行動は次の機会に回す）。
    private mutating func approach(_ anchor: RoomPoint, until limit: Double) -> Bool {
        guard position.distance(to: anchor) > Schedule.approachThresholdRatio else { return true }
        append(.wander, until: Swift.min(cursor + Schedule.approachMinutes, limit), movingTo: anchor)
        guard cursor < limit - Schedule.epsilonMinutes else {
            previousKey = ActivityWeight.unsuppressedKey
            return false
        }
        return true
    }

    /// 指定の時刻ちょうどに着くように、それまでを埋めてから歩いて寄せる。
    mutating func walk(to destination: RoomPoint, arrivingAt arrival: Double) {
        guard arrival > cursor else { return }
        let walkStart = Swift.max(cursor, arrival - Schedule.approachMinutes)
        if walkStart > cursor { fillAwake(until: walkStart) }
        append(.wander, until: arrival, movingTo: destination)
    }
}

public extension DayPlan {

    /// その日の行動表を作る。同じ入力なら必ず同じ表になる。
    static func make(for day: DayKey, input: WorldInput) -> DayPlan {
        let (bedtime, wake) = sleepWindow(for: day, input: input)
        // 前の晩に日付をまたいで起きていたぶん。0 以下なら 0:00 時点で既に寝ている。
        let previousBedtime = sleepWindow(for: day.advanced(by: -1), input: input).bedtime
            - Schedule.minutesPerDay
        // 0:00 の位置と 24:00 の位置。前後の日の表と必ず一致させる（瞬間移動を防ぐ）。
        let startPosition = midnightPosition(for: day, input: input)
        let endPosition = midnightPosition(for: day.advanced(by: 1), input: input)

        var builder = PlanBuilder(
            input: input,
            rng: IndexedRandom(seed: input.userSeed,
                               StableHash.string(input.character.id),
                               day.seedComponent),
            startingAt: startPosition)

        // ① 0:00 から起床まで（夜ふかししていたぶんを埋めてから眠る）
        if previousBedtime > 0 { builder.fillAwake(until: previousBedtime) }
        builder.sleep(until: wake)

        // ② 起きてすぐの伸び
        let dayEnd = Swift.min(bedtime, Schedule.minutesPerDay)
        builder.stay(.happyStretch, until: Swift.min(wake + Schedule.wakeUpStretchMinutes, dayEnd))

        // ③ 起きているあいだ。最後は寝床（または 0:00 の居場所）へ歩いて終わる。
        builder.walk(to: endPosition, arrivingAt: dayEnd)

        // ④ 就寝から 24:00 まで
        if bedtime < Schedule.minutesPerDay { builder.sleep(until: Schedule.minutesPerDay) }

        return DayPlan(day: day, segments: normalize(builder.segments),
                       wakeMinute: wake, bedtimeMinute: bedtime)
    }

    /// 隙間・重複・長さ 0 の区切りを取り除き、0:00〜24:00 をちょうど覆う形に整える。
    /// 同じ場所で同じことをしている区切りが並んだら 1 つにつなぐ。
    private static func normalize(_ raw: [Segment]) -> [Segment] {
        var result: [Segment] = []
        var cursor: Double = 0
        for segment in raw {
            let start = Swift.max(segment.startMinute, cursor)
            let end = Swift.min(segment.endMinute, Schedule.minutesPerDay)
            guard end > start + Schedule.epsilonMinutes else { continue }
            if canExtend(result.last, with: segment) {
                extendLast(&result, to: end)
            } else {
                result.append(Segment(startMinute: start, endMinute: end,
                                      activity: segment.activity,
                                      from: segment.from, to: segment.to))
            }
            cursor = end
        }
        // 丸めの誤差で数分あまることがあるので、最後を 24:00 まで伸ばす。
        if cursor < Schedule.minutesPerDay { extendLast(&result, to: Schedule.minutesPerDay) }
        return result
    }

    /// 前の区切りを伸ばすだけで済むか。
    ///
    /// 止まったまま同じことを続けているなら、区切りを分ける意味がない。分けたままだと
    /// コマ送りがそこで 0 に巻き戻り、歩き方やまばたきが不自然に途切れる。
    private static func canExtend(_ last: Segment?, with next: Segment) -> Bool {
        guard let last else { return false }
        return !last.isMoving && !next.isMoving
            && last.to == next.from && last.activity == next.activity
    }

    /// いちばん後ろの区切りの終わりを動かす。
    private static func extendLast(_ segments: inout [Segment], to end: Double) {
        guard let last = segments.last else { return }
        segments[segments.count - 1] = Segment(startMinute: last.startMinute, endMinute: end,
                                               activity: last.activity,
                                               from: last.from, to: last.to)
    }
}

extension RoomPoint {
    func distance(to other: RoomPoint) -> Double {
        ((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y)).squareRoot()
    }
}

// MARK: - 人が読む形

public extension Activity {
    /// 日本語の短い名前。デバッグ画面とログで使う。
    var label: String {
        switch self {
        case .sleep:        "ねる"
        case .nap:          "うたたね"
        case .wander:       "あるく"
        case .idle:         "たちどまる"
        case .sit(let id):   id.map { "すわる(\($0))" } ?? "すわる"
        case .dance(let id): "おどる(\(id))"
        case .play(let id):  "あそぶ(\(id))"
        case .look(let id):  id.map { "ながめる(\($0))" } ?? "ながめる"
        case .eat(let id):   "たべる(\(id))"
        case .clockGreet:   "時報"
        case .happyStretch: "のびをする"
        }
    }
}

public extension DayPlan {

    /// 一日を人が読める表にする。デバッグ画面（プラン §7.7）とテストで使う。
    func summary() -> String {
        func clock(_ minute: Double) -> String {
            String(format: "%02d:%02d", Int(minute) / 60 % 24, Int(minute) % 60)
        }
        let header = String(format: "%04d-%02d-%02d  起床 %@  就寝 %@  区切り %d",
                            day.year, day.month, day.day,
                            clock(wakeMinute), clock(bedtimeMinute), segments.count)
        let rows = segments.map { segment in
            let move = segment.isMoving
                ? String(format: "(%.2f,%.2f)→(%.2f,%.2f)",
                         segment.from.x, segment.from.y, segment.to.x, segment.to.y)
                : String(format: "(%.2f,%.2f)", segment.from.x, segment.from.y)
            return String(format: "  %@-%@ %3.0f分  %-16@ %@",
                          clock(segment.startMinute), clock(segment.endMinute),
                          segment.durationMinutes, segment.activity.label as NSString, move)
        }
        return ([header] + rows).joined(separator: "\n")
    }
}
