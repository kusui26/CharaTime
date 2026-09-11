import Testing
import Foundation
@testable import CTCore

/// 日課表の不変条件。ここが崩れると、キャラが瞬間移動したり、
/// 一日中同じことをしたり、床の外に出たりする（プラン §5.4）。
@Suite("日課表")
struct DayPlanTests {

    // MARK: - 下ごしらえ

    static let floor = RoomRect(x: 0.06, y: 0.62, width: 0.88, height: 0.24)

    static func character(_ id: String, activity: Double, nightOwl: Double,
                          napiness: Double, favorites: [ItemKind] = []) -> Character {
        Character(id: id, displayName: id,
                  personality: Personality(activity: activity, nightOwl: nightOwl,
                                           napiness: napiness, favorites: favorites),
                  poses: [.idle: ["a", "b"], .walk: ["w1", "w2", "w3", "w4"],
                          .sit: ["s"], .sleep: ["z1", "z2"], .happy: ["h1", "h2"]])
    }

    static func input(_ character: Character, items: [PlacedItem] = [], seed: UInt64 = 0xC0FF_EE01) -> WorldInput {
        WorldInput(character: character,
                   room: Room(background: .bundled("room"), floor: floor, items: items),
                   userSeed: seed)
    }

    static let piyo = character("piyo", activity: 0.9, nightOwl: 0.1, napiness: 0.2)
    static let fuwa = character("fuwa", activity: 0.6, nightOwl: 0.9, napiness: 0.3,
                                favorites: [.mirrorBall])
    static let someDay = DayKey(year: 2026, month: 9, day: 11)

    // MARK: - 決定論

    @Test("同じ入力なら何度作っても同じ表になる")
    func deterministic() {
        let a = DayPlan.make(for: Self.someDay, input: Self.input(Self.piyo))
        let b = DayPlan.make(for: Self.someDay, input: Self.input(Self.piyo))
        #expect(a == b)
        #expect(a.segments.count > 10)
    }

    @Test("種が違えば違う一日になる")
    func seedChangesTheDay() {
        let a = DayPlan.make(for: Self.someDay, input: Self.input(Self.piyo, seed: 1))
        let b = DayPlan.make(for: Self.someDay, input: Self.input(Self.piyo, seed: 2))
        #expect(a.segments != b.segments)
    }

    @Test("日が違えば違う一日になる")
    func dayChangesTheDay() {
        let a = DayPlan.make(for: Self.someDay, input: Self.input(Self.piyo))
        let b = DayPlan.make(for: Self.someDay.advanced(by: 1), input: Self.input(Self.piyo))
        #expect(a.segments != b.segments)
    }

    // MARK: - 表の形

    @Test("0:00 から 24:00 までを隙間なく、重なりなく覆う")
    func coversTheWholeDay() {
        for offset in 0..<40 {
            let plan = DayPlan.make(for: Self.someDay.advanced(by: offset), input: Self.input(Self.fuwa))
            #expect(plan.segments.first?.startMinute == 0)
            #expect(plan.segments.last?.endMinute == Schedule.minutesPerDay)
            for (previous, next) in zip(plan.segments, plan.segments.dropFirst()) {
                #expect(previous.endMinute == next.startMinute,
                        "\(previous.endMinute) と \(next.startMinute) のあいだに隙間がある")
                #expect(previous.durationMinutes > 0)
            }
        }
    }

    /// ウィジェットのタイムラインが 5 分刻みなので、境目がずれていると
    /// 「ウィジェットで見た姿」と「直後にアプリを開いた姿」が食い違う（プラン §7.4）。
    @Test("区切りの境目が 5 分の倍数に乗っている")
    func boundariesOnFiveMinuteGrid() {
        for offset in 0..<30 {
            let plan = DayPlan.make(for: Self.someDay.advanced(by: offset), input: Self.input(Self.piyo))
            for segment in plan.segments {
                let remainder = segment.startMinute.truncatingRemainder(dividingBy: Schedule.gridMinutes)
                #expect(abs(remainder) < 0.000_1, "\(segment.startMinute) 分は 5 分の倍数ではない")
            }
        }
    }

    // MARK: - 眠り

    @Test("就寝と起床が決めた時間帯に収まる")
    func sleepWindowStaysInRange() {
        for chara in [Self.piyo, Self.fuwa] {
            for offset in 0..<60 {
                let plan = DayPlan.make(for: Self.someDay.advanced(by: offset), input: Self.input(chara))
                #expect(plan.wakeMinute >= 5 * 60 && plan.wakeMinute <= 10 * 60,
                        "\(chara.id) の起床が \(plan.wakeMinute / 60) 時")
                #expect(plan.bedtimeMinute >= 21 * 60 && plan.bedtimeMinute <= 26 * 60,
                        "\(chara.id) の就寝が \(plan.bedtimeMinute / 60) 時")
            }
        }
    }

    @Test("夜型は朝型より遅く寝て遅く起きる")
    func nightOwlSleepsLater() {
        var piyoTotal = 0.0, fuwaTotal = 0.0
        for offset in 0..<30 {
            let day = Self.someDay.advanced(by: offset)
            piyoTotal += DayPlan.make(for: day, input: Self.input(Self.piyo)).bedtimeMinute
            fuwaTotal += DayPlan.make(for: day, input: Self.input(Self.fuwa)).bedtimeMinute
        }
        #expect(fuwaTotal > piyoTotal + 30 * 60, "夜型と朝型の就寝時刻に差がない")
    }

    @Test("一日の大半は起きている")
    func mostOfTheDayIsAwake() {
        let plan = DayPlan.make(for: Self.someDay, input: Self.input(Self.piyo))
        let asleep = plan.segments
            .filter { ($0.activity).isAsleep }
            .reduce(0) { $0 + $1.durationMinutes }
        #expect(asleep > 5 * 60 && asleep < 12 * 60, "睡眠が \(asleep / 60) 時間")
    }

    // MARK: - 位置

    @Test("どの区切りでも床の中にいる")
    func staysOnTheFloor() {
        for offset in 0..<20 {
            let plan = DayPlan.make(for: Self.someDay.advanced(by: offset), input: Self.input(Self.fuwa))
            for segment in plan.segments {
                #expect(Self.floor.contains(segment.from), "\(segment.from) が床の外")
                #expect(Self.floor.contains(segment.to), "\(segment.to) が床の外")
            }
        }
    }

    /// 区切りの終わりの位置と、次の区切りの始まりの位置が一致すること。
    /// ここがずれると、5 分ごとに瞬間移動して見える。
    @Test("区切りをまたいでも瞬間移動しない")
    func positionIsContinuousAcrossSegments() {
        for offset in 0..<20 {
            let plan = DayPlan.make(for: Self.someDay.advanced(by: offset), input: Self.input(Self.fuwa))
            for (previous, next) in zip(plan.segments, plan.segments.dropFirst()) {
                #expect(previous.to == next.from,
                        "\(previous.endMinute) 分で \(previous.to) から \(next.from) へ飛んだ")
            }
        }
    }

    /// 24:00 の位置と、翌日 0:00 の位置が一致すること。
    /// ここがずれると、日付が変わった瞬間にキャラが飛ぶ。
    @Test("日をまたいでも位置がつながる")
    func positionIsContinuousAcrossDays() {
        for chara in [Self.piyo, Self.fuwa] {
            let world = Self.input(chara)
            for offset in 0..<30 {
                let day = Self.someDay.advanced(by: offset)
                let today = DayPlan.make(for: day, input: world)
                let tomorrow = DayPlan.make(for: day.advanced(by: 1), input: world)
                #expect(today.segments.last?.to == tomorrow.segments.first?.from,
                        "\(chara.id) の \(offset) 日目で、24:00 と翌 0:00 の位置が違う")
            }
        }
    }

    @Test("ベッドを置くと、そこで眠る")
    func bedBecomesTheSleepingSpot() {
        let bed = PlacedItem(id: "bed", kind: .bed, position: RoomPoint(x: 0.20, y: 0.68))
        let world = Self.input(Self.piyo, items: [bed])
        for offset in 0..<10 {
            let plan = DayPlan.make(for: Self.someDay.advanced(by: offset), input: world)
            let nightSleep = plan.segments.last { if case .sleep = $0.activity { true } else { false } }
            #expect(nightSleep?.from == Self.floor.clamping(bed.position),
                    "\(offset) 日目、ベッド以外で寝ている")
        }
    }

    // MARK: - アイテムが行動を増やす

    @Test("クッションを置くと座るようになる")
    func cushionAddsSitting() {
        let cushion = PlacedItem(id: "cushion", kind: .cushion, position: RoomPoint(x: 0.8, y: 0.7))
        var found = false
        for offset in 0..<14 {
            let plan = DayPlan.make(for: Self.someDay.advanced(by: offset),
                                    input: Self.input(Self.piyo, items: [cushion]))
            let satOnCushion = plan.segments.contains { segment in
                if case .sit(let id) = segment.activity { id == "cushion" } else { false }
            }
            if satOnCushion {
                found = true; break
            }
        }
        #expect(found, "2 週間ぶんを見てもクッションに座らなかった")
    }

    @Test("アイテムが無ければその行動は起きない")
    func noItemNoActivity() {
        for offset in 0..<20 {
            let plan = DayPlan.make(for: Self.someDay.advanced(by: offset), input: Self.input(Self.fuwa))
            for segment in plan.segments {
                switch segment.activity {
                case .dance, .play, .eat:
                    Issue.record("アイテムが無いのに \(segment.activity) が出た")
                case .sit(let id), .look(let id):
                    #expect(id == nil, "アイテムが無いのに \(String(describing: id)) を使った")
                default: break
                }
            }
        }
    }

    @Test("ミラーボールを置くと、夜のあいだ踊る")
    func mirrorBallMakesItDanceAtNight() {
        let ball = PlacedItem(id: "mb", kind: .mirrorBall, position: RoomPoint(x: 0.5, y: 0.72))
        var danceMinutes = 0.0
        var danceOutsideNight = 0.0
        for offset in 0..<21 {
            let plan = DayPlan.make(for: Self.someDay.advanced(by: offset),
                                    input: Self.input(Self.fuwa, items: [ball]))
            for segment in plan.segments {
                guard case .dance = segment.activity else { continue }
                danceMinutes += segment.durationMinutes
                if segment.startMinute < Schedule.danceStartMinute
                    || segment.startMinute >= Schedule.danceEndMinute {
                    danceOutsideNight += segment.durationMinutes
                }
            }
        }
        #expect(danceMinutes > 60, "3 週間で踊ったのが \(danceMinutes) 分しかない")
        #expect(danceOutsideNight < danceMinutes * 0.35,
                "夜以外に踊りすぎ（\(danceOutsideNight) / \(danceMinutes) 分）")
    }

    // MARK: - 飽きさせない

    @Test("一日のうちに何種類もの行動をする")
    func theDayHasVariety() {
        let items = [PlacedItem(id: "mb", kind: .mirrorBall, position: RoomPoint(x: 0.5, y: 0.7)),
                     PlacedItem(id: "cu", kind: .cushion, position: RoomPoint(x: 0.85, y: 0.72)),
                     PlacedItem(id: "pl", kind: .plant, position: RoomPoint(x: 0.12, y: 0.7))]
        for offset in 0..<10 {
            let plan = DayPlan.make(for: Self.someDay.advanced(by: offset),
                                    input: Self.input(Self.fuwa, items: items))
            let kinds = Set(plan.segments.map { String(describing: $0.activity) })
            #expect(kinds.count >= 5, "\(offset) 日目の行動が \(kinds.count) 種類しかない")
        }
    }

    @Test("同じ行動が延々と続かない")
    func doesNotRepeatForever() {
        let items = [PlacedItem(id: "cu", kind: .cushion, position: RoomPoint(x: 0.86, y: 0.74)),
                     PlacedItem(id: "bed", kind: .bed, position: RoomPoint(x: 0.22, y: 0.66))]
        for offset in 0..<14 {
            let plan = DayPlan.make(for: Self.someDay.advanced(by: offset),
                                    input: Self.input(Self.piyo, items: items))
            var runMinutes = 0.0
            var longest = 0.0
            var previousLabel = ""
            for segment in plan.segments {
                // 夜の睡眠と、歩き回っているあいだは対象外。歩きは行き先が毎回変わるので
                // 長く続いても「同じことの繰り返し」には見えない。
                if case .sleep = segment.activity { runMinutes = 0; previousLabel = ""; continue }
                if case .wander = segment.activity { runMinutes = 0; previousLabel = ""; continue }
                let label = segment.activity.label
                runMinutes = label == previousLabel ? runMinutes + segment.durationMinutes : segment.durationMinutes
                previousLabel = label
                longest = max(longest, runMinutes)
            }
            #expect(longest <= 60, "\(offset) 日目、同じ場所で \(longest) 分も同じことをした")
        }
    }

    /// 活動的な子が一日中うたた寝していたら、性格が反映されていない。
    @Test("ひるね好きでない子は、ベッドがあっても寝すぎない")
    func lowNapinessDoesNotSleepAllDay() {
        let bed = PlacedItem(id: "bed", kind: .bed, position: RoomPoint(x: 0.22, y: 0.66))
        var napTotal = 0.0
        let days = 14
        for offset in 0..<days {
            let plan = DayPlan.make(for: Self.someDay.advanced(by: offset),
                                    input: Self.input(Self.piyo, items: [bed]))
            for segment in plan.segments where segment.activity == .nap {
                napTotal += segment.durationMinutes
            }
        }
        let perDay = napTotal / Double(days)
        #expect(perDay < 75, "ひるねが 1 日あたり \(perDay) 分（ピヨはひるね 0.2）")
    }

    // MARK: - 総当たり

    /// 5 体 × 1 年ぶんを回して、どの日も不変条件を満たすこと。
    @Test("1 年ぶり回しても壊れない", .timeLimit(.minutes(1)))
    func oneYearOfEveryCharacter() {
        let items = [PlacedItem(id: "mb", kind: .mirrorBall, position: RoomPoint(x: 0.5, y: 0.7)),
                     PlacedItem(id: "cu", kind: .cushion, position: RoomPoint(x: 0.85, y: 0.72))]
        let roster = [
            Self.character("piyo", activity: 0.9, nightOwl: 0.1, napiness: 0.2, favorites: [.ball]),
            Self.character("mochi", activity: 0.3, nightOwl: 0.4, napiness: 0.8, favorites: [.cushion]),
            Self.character("kumao", activity: 0.4, nightOwl: 0.5, napiness: 0.5, favorites: [.cushion]),
            Self.character("fuwa", activity: 0.6, nightOwl: 0.9, napiness: 0.3, favorites: [.mirrorBall]),
            Self.character("chip", activity: 0.5, nightOwl: 0.35, napiness: 0.3, favorites: [.deskClock])
        ]
        var totalSegments = 0
        for chara in roster {
            let world = Self.input(chara, items: items)
            for offset in 0..<365 {
                let plan = DayPlan.make(for: Self.someDay.advanced(by: offset), input: world)
                totalSegments += plan.segments.count
                #expect(plan.segments.first?.startMinute == 0)
                #expect(plan.segments.last?.endMinute == Schedule.minutesPerDay)
                for (previous, next) in zip(plan.segments, plan.segments.dropFirst()) {
                    #expect(previous.endMinute == next.startMinute)
                    #expect(previous.to == next.from)
                }
            }
        }
        #expect(totalSegments > 5 * 365 * 20, "一日の区切りが少なすぎる（合計 \(totalSegments)）")
    }
}

@Suite("性格が日課に出る")
struct PersonalityTests {

    static func napMinutes(_ chara: Character, days: Int = 14) -> Double {
        let bed = PlacedItem(id: "bed", kind: .bed, position: RoomPoint(x: 0.22, y: 0.66))
        var total = 0.0
        for offset in 0..<days {
            let plan = DayPlan.make(for: DayPlanTests.someDay.advanced(by: offset),
                                    input: DayPlanTests.input(chara, items: [bed]))
            for segment in plan.segments where segment.activity == .nap {
                total += segment.durationMinutes
            }
        }
        return total / Double(days)
    }

    static func walkMinutes(_ chara: Character, days: Int = 14) -> Double {
        var total = 0.0
        for offset in 0..<days {
            let plan = DayPlan.make(for: DayPlanTests.someDay.advanced(by: offset),
                                    input: DayPlanTests.input(chara))
            for segment in plan.segments where segment.activity == .wander {
                total += segment.durationMinutes
            }
        }
        return total / Double(days)
    }

    @Test("ひるね好きのほうが、よく昼寝する")
    func napinessShowsUp() {
        let sleepy = DayPlanTests.character("mochi", activity: 0.3, nightOwl: 0.4, napiness: 0.8)
        let lively = DayPlanTests.character("piyo", activity: 0.9, nightOwl: 0.1, napiness: 0.2)
        let sleepyNap = Self.napMinutes(sleepy)
        let livelyNap = Self.napMinutes(lively)
        #expect(sleepyNap > livelyNap * 1.8,
                "ひるね 0.8 が \(sleepyNap) 分、0.2 が \(livelyNap) 分（差が小さい）")
    }

    @Test("活動的なほうが、よく歩く")
    func activityShowsUp() {
        let lively = DayPlanTests.character("piyo", activity: 0.9, nightOwl: 0.1, napiness: 0.2)
        let calm = DayPlanTests.character("mochi", activity: 0.2, nightOwl: 0.4, napiness: 0.4)
        let livelyWalk = Self.walkMinutes(lively)
        let calmWalk = Self.walkMinutes(calm)
        #expect(livelyWalk > calmWalk * 1.4,
                "活動 0.9 が \(livelyWalk) 分、0.2 が \(calmWalk) 分（差が小さい）")
    }
}

@Suite("一日の配分")
struct DailyMixTests {

    static let items = [
        PlacedItem(id: "mb", kind: .mirrorBall, position: RoomPoint(x: 0.50, y: 0.70)),
        PlacedItem(id: "cu", kind: .cushion, position: RoomPoint(x: 0.86, y: 0.74)),
        PlacedItem(id: "pl", kind: .plant, position: RoomPoint(x: 0.12, y: 0.70))
    ]

    /// 1 日あたりの、行動ごとの分数。
    static func mix(_ chara: Character, days: Int = 14) -> [String: Double] {
        var totals: [String: Double] = [:]
        for offset in 0..<days {
            let plan = DayPlan.make(for: DayPlanTests.someDay.advanced(by: offset),
                                    input: DayPlanTests.input(chara, items: items))
            for segment in plan.segments {
                let key = segment.activity.label.prefix { $0 != "(" }.description
                totals[key, default: 0] += segment.durationMinutes
            }
        }
        return totals.mapValues { $0 / Double(days) }
    }

    @Test("眠っているのは 1 日 7〜9 時間")
    func sleepsAReasonableAmount() {
        for chara in [DayPlanTests.piyo, DayPlanTests.fuwa] {
            let sleep = Self.mix(chara)["ねる"] ?? 0
            #expect(sleep > 7 * 60 && sleep < 9 * 60, "\(chara.id) の睡眠が \(sleep / 60) 時間")
        }
    }

    /// 一日じゅう歩き回っていると、座っている姿や寝ている姿に出会えなくなる。
    @Test("起きているあいだの歩きは 2〜5 割")
    func walkingIsAFractionOfTheDay() {
        for chara in [DayPlanTests.piyo, DayPlanTests.fuwa] {
            let totals = Self.mix(chara)
            let sleep = totals["ねる"] ?? 0
            let walk = totals["あるく"] ?? 0
            let ratio = walk / (Schedule.minutesPerDay - sleep)
            #expect(ratio > 0.20 && ratio < 0.50, "\(chara.id) の歩きが起床時間の \(Int(ratio * 100))%")
        }
    }

    @Test("どの子も 6 種類以上のことをする")
    func everyoneHasAVariedDay() {
        for chara in [DayPlanTests.piyo, DayPlanTests.fuwa] {
            #expect(Self.mix(chara).count >= 6, "\(chara.id) の行動が \(Self.mix(chara).count) 種類")
        }
    }

    /// 昼の時間帯の外でうとうとすること自体は自然なので禁じない。
    /// ただし「昼寝の時間帯」が意味を持つ程度には偏っていてほしい。
    @Test("うたたねは昼の時間帯に集中する")
    func napsConcentrateAroundMidday() {
        var inWindow = 0.0
        var outOfWindow = 0.0
        let days = 30
        let characters = [DayPlanTests.piyo, DayPlanTests.fuwa]
        for chara in characters {
            for offset in 0..<days {
                let plan = DayPlan.make(for: DayPlanTests.someDay.advanced(by: offset),
                                        input: DayPlanTests.input(chara, items: Self.items))
                for segment in plan.segments where segment.activity == .nap {
                    let midpoint = (segment.startMinute + segment.endMinute) / 2
                    if midpoint >= Schedule.napStartMinute && midpoint < Schedule.napEndMinute {
                        inWindow += segment.durationMinutes
                    } else {
                        outOfWindow += segment.durationMinutes
                    }
                }
            }
        }
        let windowLength = Schedule.napEndMinute - Schedule.napStartMinute
        let sampleMinutes = Double(days * characters.count)
        // 単位時間あたりの割合で比べる。時間帯の長さが違うので、総量では比べられない。
        let rateInside = inWindow / (windowLength * sampleMinutes)
        let rateOutside = outOfWindow / ((Schedule.minutesPerDay - windowLength) * sampleMinutes)
        let inside = String(format: "%.1f", rateInside * 100)
        let outside = String(format: "%.1f", rateOutside * 100)
        #expect(inWindow > 0, "まったくうたたねしない")
        #expect(rateInside > rateOutside * 3,
                "昼の時間帯で \(inside)%、その外で \(outside)%（偏りが小さい）")
    }
}
