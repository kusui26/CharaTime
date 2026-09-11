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
    /// これ以上離れていたら、歩いて近づいてから使う。
    public static let approachThreshold: Double = 0.08

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
        let bedJitter = Double(rng.int(-Schedule.jitterSteps...Schedule.jitterSteps, 0)) * Schedule.gridMinutes
        let wakeJitter = Double(rng.int(-Schedule.jitterSteps...Schedule.jitterSteps, 1)) * Schedule.gridMinutes
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
}

extension DayPlan {

    /// その時刻に取りうる行動と重み。
    ///
    /// アイテムが行動の語彙を増やす（プラン §5.6）。ミラーボールを置くと夜に踊るのは、
    /// ここで時間帯に応じて重みを足しているから。
    static func choices(atMinute minute: Double, input: WorldInput, previousKey: String?) -> [ActivityChoice] {
        let person = input.character.personality
        let room = input.room
        var result: [ActivityChoice] = []

        // どこにも依存しない基本の行動
        result.append(ActivityChoice(activity: .wander, anchor: nil,
                                     weight: 0.20 + person.activity * 0.55, key: "wander"))
        result.append(ActivityChoice(activity: .idle, anchor: nil,
                                     weight: 0.45, key: "idle"))
        result.append(ActivityChoice(activity: .sit(itemId: nil), anchor: nil,
                                     weight: 0.30, key: "sit-floor"))

        let isNapTime = minute >= Schedule.napStartMinute && minute < Schedule.napEndMinute
        result.append(ActivityChoice(activity: .nap, anchor: nil,
                                     weight: isNapTime ? person.napiness * 0.5 : 0.02, key: "nap"))

        // アイテムが増やす行動
        let isDanceTime = minute >= Schedule.danceStartMinute && minute < Schedule.danceEndMinute
        for item in room.items {
            let anchor = room.floor.clamping(item.position)
            let favored = person.favorites.contains(item.kind) ? 1.8 : 1.0
            for affordance in item.kind.affordances {
                let (activity, base): (Activity, Double) = switch affordance {
                case .sit:   (.sit(itemId: item.id), 0.35)
                case .sleep: (.nap, isNapTime ? person.napiness * 0.6 : 0.02)
                case .dance: (.dance(itemId: item.id), isDanceTime ? 0.55 : 0.015)
                case .play:  (.play(itemId: item.id), 0.28)
                case .look:  (.look(itemId: item.id), 0.18)
                case .eat:   (.eat(itemId: item.id), 0.12)
                }
                // 好物の後押しは、その行動をしたくなる場面でだけ効かせる。
                // 昼間からミラーボールの下で踊り続けるようなことを避けるため。
                let boosted = base > 0.1 ? base * favored : base
                result.append(ActivityChoice(activity: activity, anchor: anchor,
                                             weight: boosted,
                                             key: "\(affordance.rawValue)-\(item.id)"))
            }
        }

        // 同じ場所で同じことを続けると「決まった動きの繰り返し」に見えるので、
        // 直前と同じ行動は起きにくくする。
        //
        // ただし **歩くことには抑制をかけない**。行き先が毎回変わるので繰り返しには見えず、
        // ここを抑えると「よく歩く子」と「あまり歩かない子」の差まで消えてしまう。
        if let previousKey, previousKey != "wander" {
            result = result.map {
                $0.key == previousKey
                    ? ActivityChoice(activity: $0.activity, anchor: $0.anchor,
                                     weight: $0.weight * 0.25, key: $0.key)
                    : $0
            }
        }
        return result
    }
}

// MARK: - 日課表の組み立て

public extension DayPlan {

    /// その日の行動表を作る。同じ入力なら必ず同じ表になる。
    static func make(for day: DayKey, input: WorldInput) -> DayPlan {
        let floor = input.room.floor
        let (bedtime, wake) = sleepWindow(for: day, input: input)
        // 前の晩に日付をまたいで起きていたぶん。負なら 0:00 時点で既に寝ている。
        let previousBedtime = sleepWindow(for: day.advanced(by: -1), input: input).bedtime - Schedule.minutesPerDay
        // 0:00 の位置と、24:00 の位置。前後の日の表と必ず一致する。
        let startPosition = midnightPosition(for: day, input: input)
        let endPosition = midnightPosition(for: day.advanced(by: 1), input: input)

        let rng = IndexedRandom(seed: input.userSeed,
                                StableHash.string(input.character.id),
                                day.seedComponent)
        var segments: [Segment] = []
        var cursor: Double = 0
        var position = startPosition
        var previousKey: String?
        var step: UInt64 = 0

        /// 起きているあいだを区切りで埋める。
        func fillAwake(until limit: Double) {
            while cursor < limit - 0.000_1 {
                let slotRng = rng.scoped(1, step)
                let all = choices(atMinute: cursor, input: input, previousKey: previousKey)
                guard let picked = slotRng.weightedIndex(all.map(\.weight), 0).map({ all[$0] }) else { break }

                // アイテムを使うなら、離れていたら歩いて近づく。瞬間移動させないため。
                if let anchor = picked.anchor, position.distance(to: anchor) > Schedule.approachThreshold {
                    let walkEnd = Swift.min(cursor + Schedule.approachMinutes, limit)
                    if walkEnd > cursor {
                        segments.append(Segment(startMinute: cursor, endMinute: walkEnd,
                                                activity: .wander, from: position, to: anchor))
                        position = anchor
                        cursor = walkEnd
                    }
                    if cursor >= limit - 0.000_1 { previousKey = "wander"; step += 1; break }
                }

                let steps = slotRng.int(Schedule.segmentStepsMin...Schedule.segmentStepsMax, 1)
                let end = Swift.min(cursor + Double(steps) * Schedule.gridMinutes, limit)

                let destination: RoomPoint = switch picked.activity {
                case .wander: floor.at(slotRng.unit(2), slotRng.unit(3))
                default: picked.anchor ?? position
                }
                segments.append(Segment(startMinute: cursor, endMinute: end,
                                        activity: picked.activity, from: position, to: destination))
                position = destination
                previousKey = picked.key
                cursor = end
                step += 1
            }
        }

        /// 指定の時刻までに、歩いて目的の場所へ寄せる。
        func walkTo(_ destination: RoomPoint, arrivingAt arrival: Double) {
            guard arrival > cursor else { return }
            let walkStart = Swift.max(cursor, arrival - Schedule.approachMinutes)
            if walkStart > cursor { fillAwake(until: walkStart) }
            if arrival > cursor {
                segments.append(Segment(startMinute: cursor, endMinute: arrival,
                                        activity: .wander, from: position, to: destination))
                position = destination
                cursor = arrival
            }
        }

        // ① 0:00 から起床まで
        if previousBedtime > 0 {
            fillAwake(until: previousBedtime)            // 夜ふかしして日付をまたいだぶん
            segments.append(Segment(startMinute: previousBedtime, endMinute: wake,
                                    activity: .sleep, from: position, to: position))
        } else {
            segments.append(Segment(startMinute: 0, endMinute: wake,
                                    activity: .sleep, from: startPosition, to: startPosition))
            position = startPosition
        }
        cursor = wake
        previousKey = nil

        // ② 起きてすぐの伸び
        let dayEnd = Swift.min(bedtime, Schedule.minutesPerDay)
        let stretchEnd = Swift.min(wake + Schedule.wakeUpStretchMinutes, dayEnd)
        if stretchEnd > cursor {
            segments.append(Segment(startMinute: cursor, endMinute: stretchEnd,
                                    activity: .happyStretch, from: position, to: position))
            cursor = stretchEnd
        }

        // ③ 起きているあいだ。最後は寝床（または 0:00 の居場所）へ歩いて終わる。
        walkTo(endPosition, arrivingAt: dayEnd)

        // ④ 就寝から 24:00 まで
        if bedtime < Schedule.minutesPerDay {
            segments.append(Segment(startMinute: bedtime, endMinute: Schedule.minutesPerDay,
                                    activity: .sleep, from: endPosition, to: endPosition))
        }

        return DayPlan(day: day, segments: normalize(segments), wakeMinute: wake, bedtimeMinute: bedtime)
    }

    /// 隙間・重複・長さ 0 の区切りを取り除き、0:00〜24:00 をちょうど覆う形に整える。
    /// 同じ場所で同じことをしている区切りが並んだら 1 つにつなぐ。
    private static func normalize(_ raw: [Segment]) -> [Segment] {
        var result: [Segment] = []
        var cursor: Double = 0
        for segment in raw {
            let start = Swift.max(segment.startMinute, cursor)
            let end = Swift.min(segment.endMinute, Schedule.minutesPerDay)
            guard end > start + 0.000_1 else { continue }

            // 止まったまま同じことを続けているなら、前の区切りを伸ばすだけでよい。
            // 区切りを分けたままだとコマ送りがそこで巻き戻り、動きが不自然になる。
            if let last = result.last, !last.isMoving, !segment.isMoving,
               last.to == segment.from, last.activity == segment.activity {
                result[result.count - 1] = Segment(startMinute: last.startMinute, endMinute: end,
                                                   activity: last.activity,
                                                   from: last.from, to: last.to)
                cursor = end
                continue
            }
            result.append(Segment(startMinute: start, endMinute: end, activity: segment.activity,
                                  from: segment.from, to: segment.to))
            cursor = end
        }
        if var last = result.last, cursor < Schedule.minutesPerDay {
            // 最後を 24:00 まで伸ばす。丸めの誤差で数分あまることがあるため。
            last = Segment(startMinute: last.startMinute, endMinute: Schedule.minutesPerDay,
                           activity: last.activity, from: last.from, to: last.to)
            result[result.count - 1] = last
        }
        return result
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
        case .sit(let id):  id == nil ? "すわる" : "すわる(\(id!))"
        case .dance(let id): "おどる(\(id))"
        case .play(let id):  "あそぶ(\(id))"
        case .look(let id):  id == nil ? "ながめる" : "ながめる(\(id!))"
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
