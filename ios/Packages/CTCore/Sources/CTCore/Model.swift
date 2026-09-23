import Foundation

// 日課エンジンが扱う値の定義。ロジックは持たず、アプリ・ウィジェット・
// パイプラインが同じ語彙で話すための型だけを置く（プラン §7.4）。
//
// 座標はすべて **0.0〜1.0 の正規化座標**。実際の画面サイズは描画側が持つので、
// ここは端末にも面（待受モード／ウィジェット／StandBy）にも依存しない。

// MARK: - 見た目

/// 1 体ぶんに用意する姿勢。Tier 1（プラン §5.3）は idle 2 / walk 4 / sit 1 / sleep 2 / happy 2 の 11 枚。
public enum Pose: String, Codable, Sendable, CaseIterable {
    case idle, walk, sit, sleep, happy
    case lookUp          // Tier 2
    case surprised       // Tier 2
}

/// `[Pose: [String]]` を JSON の **オブジェクト**として書けるようにする。
/// 宣言しないと配列（キーと値の交互並び）になり、手で書く manifest も
/// Python のパイプラインも扱いづらくなる。
extension Pose: CodingKeyRepresentable {}

public enum Facing: String, Codable, Sendable {
    case left, right, front, back
}

// MARK: - アイテム

public enum ItemKind: String, Codable, Sendable, CaseIterable {
    case mirrorBall, cushion, bed, plant, deskClock, ball, snack
}

/// アイテムが与える「できること」。これが日課表の語彙を増やす（プラン §5.6）。
public enum Affordance: String, Codable, Sendable, CaseIterable {
    case sit, sleep, dance, play, look, eat
}

public extension ItemKind {
    var affordances: [Affordance] {
        switch self {
        case .mirrorBall: [.dance]
        case .cushion:    [.sit]
        case .bed:        [.sleep]
        case .plant:      [.look]
        case .deskClock:  [.look]
        case .ball:       [.play]
        case .snack:      [.eat]
        }
    }
}

public struct PlacedItem: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var kind: ItemKind
    /// 床の中の位置（正規化座標）。
    public var position: RoomPoint

    public init(id: String, kind: ItemKind, position: RoomPoint) {
        self.id = id
        self.kind = kind
        self.position = position
    }
}

// MARK: - キャラクター

/// 行動の偏り。0.0〜1.0 に収める。
public struct Personality: Codable, Sendable, Equatable {
    /// 歩き回る頻度。
    public var activity: Double
    /// 夜型度。就寝・起床の時刻窓を決める。
    public var nightOwl: Double
    /// 昼寝の多さ。
    public var napiness: Double
    /// 好きなアイテム。日課の抽選で重みを増やす。
    public var favorites: [ItemKind]

    public init(activity: Double, nightOwl: Double, napiness: Double, favorites: [ItemKind] = []) {
        self.activity = activity.clampedToUnit
        self.nightOwl = nightOwl.clampedToUnit
        self.napiness = napiness.clampedToUnit
        self.favorites = favorites
    }

    // JSON から読むときも同じように丸める。手書きの manifest に 1.5 が入っていても
    // 行動の重みが壊れないようにするため。
    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        self.init(activity: try box.decodeIfPresent(Double.self, forKey: .activity) ?? 0.5,
                  nightOwl: try box.decodeIfPresent(Double.self, forKey: .nightOwl) ?? 0.5,
                  napiness: try box.decodeIfPresent(Double.self, forKey: .napiness) ?? 0.3,
                  favorites: try box.decodeIfPresent([ItemKind].self, forKey: .favorites) ?? [])
    }
}

public enum Origin: Codable, Sendable, Equatable {
    /// 同梱のキャラ。
    case bundled
    /// キャラ工房で取り込んだキャラ（プラン §6.7）。
    case user(createdAt: Date)
}

public struct Character: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var displayName: String
    /// 体格差。1.0 が身長 400px 相当の基準（プラン §5.3）。
    public var scale: Double
    public var personality: Personality
    /// 姿勢ごとのアセット名。`poses[.walk] = ["piyo_walk_01", ...]`
    public var poses: [Pose: [String]]
    /// ウィジェット用の小さい絵（mini）のアセット名。並びは `poses` と同じ（プラン §5.3、D-20）。
    ///
    /// ウィジェット拡張のメモリは約 30 MB しかない。待受モードの絵は 1 コマ展開すると約 1.9 MB に
    /// なるので、ウィジェットは小さく焼いたこちらを読む。無い姿勢は `poses` の絵で描く。
    public var miniPoses: [Pose: [String]]
    public var origin: Origin

    public init(id: String, displayName: String, scale: Double = 1.0,
                personality: Personality, poses: [Pose: [String]],
                miniPoses: [Pose: [String]] = [:], origin: Origin = .bundled) {
        self.id = id
        self.displayName = displayName
        self.scale = scale
        self.personality = personality
        self.poses = poses
        self.miniPoses = miniPoses
        self.origin = origin
    }

    // mini はあとから足した項目。無い JSON（取り込んだキャラなど）も読めるようにする。
    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(String.self, forKey: .id)
        displayName = try box.decode(String.self, forKey: .displayName)
        scale = try box.decode(Double.self, forKey: .scale)
        personality = try box.decode(Personality.self, forKey: .personality)
        poses = try box.decode([Pose: [String]].self, forKey: .poses)
        miniPoses = try box.decodeIfPresent([Pose: [String]].self, forKey: .miniPoses) ?? [:]
        origin = try box.decode(Origin.self, forKey: .origin)
    }

    /// その姿勢のコマ数。0 のときは呼び出し側が idle に落とす。
    public func frameCount(_ pose: Pose) -> Int { poses[pose]?.count ?? 0 }
}

// MARK: - 部屋

public enum Background: Codable, Sendable, Equatable {
    /// 同梱の部屋イラスト。
    case bundled(String)
    /// ユーザーが選んだ写真。
    case photo(fileName: String)
    /// ユーザーのホーム画面のスクリーンショット（メモの「アプリが並んでいる画面」）。
    case homeScreenShot(fileName: String)

    /// 取り込んだ画像のファイル名（`ImageStore` の名前）。同梱の部屋は nil。
    ///
    /// どの背景が画像を持つかは、ここだけで決める。描くときも、使わない画像を
    /// 片づけるときも、これを見る（片づけの見落としは、利用者の画像を消すことになる）。
    public var imageFileName: String? {
        switch self {
        case .bundled: nil
        case .photo(let fileName), .homeScreenShot(let fileName): fileName
        }
    }
}

public struct Room: Codable, Sendable, Equatable {
    public var background: Background
    /// キャラが歩ける矩形（正規化座標）。
    public var floor: RoomRect
    /// 奥行きによる縮尺。奥がいちばん小さく、手前がいちばん大きい。
    public var depthScaleFar: Double
    public var depthScaleNear: Double
    public var items: [PlacedItem]

    public init(background: Background, floor: RoomRect,
                depthScaleFar: Double = 0.85, depthScaleNear: Double = 1.0,
                items: [PlacedItem] = []) {
        self.background = background
        self.floor = floor
        self.depthScaleFar = depthScaleFar
        self.depthScaleNear = depthScaleNear
        self.items = items
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        background = try box.decode(Background.self, forKey: .background)
        floor = try box.decodeIfPresent(RoomRect.self, forKey: .floor) ?? .unit
        depthScaleFar = try box.decodeIfPresent(Double.self, forKey: .depthScaleFar) ?? 0.85
        depthScaleNear = try box.decodeIfPresent(Double.self, forKey: .depthScaleNear) ?? 1.0
        items = try box.decodeIfPresent([PlacedItem].self, forKey: .items) ?? []
    }

    /// その位置での大きさの倍率。奥ほど小さく見える簡易な 2.5D（プラン §5.4）。
    public func scale(at point: RoomPoint) -> Double {
        let ratio = floor.depthRatio(of: point)
        return depthScaleFar + (depthScaleNear - depthScaleFar) * ratio
    }

    /// その「できること」を持つアイテム。日課表の抽選に使う。
    public func items(providing affordance: Affordance) -> [PlacedItem] {
        items.filter { $0.kind.affordances.contains(affordance) }
    }
}

// MARK: - 文脈

/// 本体アプリが集めて App Group に置く文脈。ウィジェットはこれを読むだけ。
///
/// 歩数は HealthKit ではなく Core Motion（`CMPedometer`）で取る（プラン D-13）。
/// 当日ぶんだけなら権限が軽く、端末がロック中でも読めるため。
public struct ContextSnapshot: Codable, Sendable, Equatable {
    public var batteryLevel: Double?
    public var isCharging: Bool?
    public var stepCount: Int?
    /// 読んだ時刻。古い文脈は割り込みに使わない（`Interrupts.freshnessSeconds`）。
    public var capturedAt: Date
    /// 充電を始めた時刻。充電していないとき、始めた時刻が分からないときは nil。
    ///
    /// 読んだ時刻とは分けて持つ。充電したまま読み直すたびに「ありがとう」と言い直さないため
    /// （`reading(batteryLevel:isCharging:at:previous:)`）。
    public var chargingSince: Date?

    public init(batteryLevel: Double? = nil, isCharging: Bool? = nil,
                stepCount: Int? = nil, capturedAt: Date, chargingSince: Date? = nil) {
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
        self.stepCount = stepCount
        self.capturedAt = capturedAt
        self.chargingSince = chargingSince
    }

    /// 電池を読み直したときの、次の文脈（プラン §9 Phase 3 の 3-C ⑩）。
    ///
    /// 充電を始めた時刻は、前の文脈で充電していなかったとき（前の文脈が無いときも）だけ、
    /// 読んだ時刻にする。前から充電していれば、前の値を引き継ぐ。歩数は電池と一緒には
    /// 読まないので、前の値を引き継ぐ。
    public static func reading(batteryLevel: Double?, isCharging: Bool?, at time: Date,
                               previous: ContextSnapshot?) -> ContextSnapshot {
        let wasCharging = previous?.isCharging == true
        let since: Date? = switch (isCharging == true, wasCharging) {
        case (false, _):    nil
        case (true, true):  previous?.chargingSince
        case (true, false): time
        }
        return ContextSnapshot(batteryLevel: batteryLevel, isCharging: isCharging,
                               stepCount: previous?.stepCount, capturedAt: time, chargingSince: since)
    }
}

// MARK: - 世界への入力と、ある時刻の姿

/// すべての面が同じものを組み立てて `sceneState(at:)` に渡す（プラン §7.2）。
public struct WorldInput: Sendable {
    public var character: Character
    public var room: Room
    /// 端末ごとに 1 回だけ決める種。これが同じなら同じ日課になる。
    public var userSeed: UInt64
    public var context: ContextSnapshot?
    /// ローカルタイムゾーンの暦。日付の境目を決めるのに使う。
    public var calendar: Calendar

    public init(character: Character, room: Room, userSeed: UInt64,
                context: ContextSnapshot? = nil, calendar: Calendar = .current) {
        self.character = character
        self.room = room
        self.userSeed = userSeed
        self.context = context
        self.calendar = calendar
    }
}

public struct Bubble: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        case greeting     // おはよう・おやすみ
        case clock        // 時報
        case reaction     // 充電・久しぶりの起動など
        case idle         // 独り言
    }
    public var text: String
    public var kind: Kind

    public init(text: String, kind: Kind) {
        self.text = text
        self.kind = kind
    }
}

public enum Activity: Codable, Sendable, Equatable {
    case sleep
    case nap
    case wander
    case idle
    case sit(itemId: String?)
    case dance(itemId: String)
    case play(itemId: String)
    case look(itemId: String?)
    case eat(itemId: String)
    case clockGreet
    /// 起きた直後の伸び。
    case happyStretch

    /// 眠っているか。描く側も「動かさない」判断にこれを使う。
    public var isAsleep: Bool {
        switch self {
        case .sleep, .nap: true
        default: false
        }
    }

    /// この行動を描くのに使う姿勢。
    public var pose: Pose {
        switch self {
        case .sleep, .nap:            .sleep
        case .wander:                 .walk
        case .idle, .clockGreet:      .idle
        case .sit:                    .sit
        case .dance, .play, .happyStretch: .happy
        case .look:                   .lookUp
        case .eat:                    .idle
        }
    }

    /// 止めた 1 枚で描くときの姿勢（ウィジェット。プラン §9 Phase 3 の 3-C ④）。
    ///
    /// 歩く姿を 5 分止めておくと、足を上げたまま固まって見える。エントリの時刻には
    /// 立ち止まった姿（idle）で描き、居場所の移動はエントリ切替のアニメで見せる（④'）。
    /// ほかの行動は、その行動の姿勢のまま。
    public var stillPose: Pose {
        if case .wander = self { return .idle }
        return pose
    }
}

/// ある時刻のキャラの姿。面ごとに違うのは描き方だけで、この値は共通。
public struct SceneState: Sendable, Equatable {
    public var time: Date
    public var activity: Activity
    /// 床の中の位置（正規化座標）。
    public var position: RoomPoint
    public var facing: Facing
    /// 姿勢の何コマ目か。
    public var frame: Int
    public var bubble: Bubble?
    /// 絵を足さずに動きを足すための味付け（呼吸・弾み・首のかしげ）。
    public var flourish: Flourish

    public init(time: Date, activity: Activity, position: RoomPoint,
                facing: Facing, frame: Int, bubble: Bubble? = nil,
                flourish: Flourish = .still) {
        self.time = time
        self.activity = activity
        self.position = position
        self.facing = facing
        self.frame = frame
        self.bubble = bubble
        self.flourish = flourish
    }

    /// 割り込みで行動を差し替える。
    ///
    /// **コマ番号を 0 に戻すのが要点。** 姿勢ごとにコマ数が違う（歩く 4 枚・
    /// よろこぶ 2 枚）ので、歩いている 4 コマ目のまま「よろこぶ」に変えると、
    /// 2 枚しかない配列の 4 番目を引いて落ちる。姿勢が変わればコマ送りは最初から始まる。
    public mutating func changeActivity(to newActivity: Activity) {
        guard activity != newActivity else { return }
        activity = newActivity
        facing = .front
        frame = 0
    }
}

// MARK: - 小さな道具

extension Double {
    var clampedToUnit: Double { Swift.min(1, Swift.max(0, self)) }
}
