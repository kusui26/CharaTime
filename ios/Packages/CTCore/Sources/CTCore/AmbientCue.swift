import Foundation

/// ウィジェットで、土台の絵に重ねて出し入れするもの（プラン §9 Phase 3 の 3-C ④）。
public enum AmbientLayer: Hashable, Sendable {
    /// まばたきの差分（まぶた）。その姿勢の 1 コマ目の上に重ねる。
    case eyelid
    /// その姿勢の、何コマ目か。寝息の 2 コマ目、よろこぶの 1・2 コマ目。
    case frame(Int)
    /// 時報の吹き出し。毎正時から 30 秒だけ出す。
    case clockBubble
    /// ミラーボールの光の粒（0〜3）。
    case sparkle(Int)

    /// タイマーが上限を超えるときに外す順（小さいほど先）。nil は外さない。
    ///
    /// **キャラの動きは最後まで残す**（3-C ④）。外すのは光の粒、その次に時報の吹き出し。
    var dropRank: Int? {
        switch self {
        case .sparkle:        0
        case .clockBubble:    1
        case .eyelid, .frame: nil
        }
    }
}

/// 重ねるものの速さ。描画の段（`RenderCapability`）が 1fps までなら、`.quarterSecond` を外す。
public enum AmbientPace: Int, Sendable, Comparable {
    /// 1 秒に 1 回まで変わる（まばたき・寝息・よろこぶ・時報）。
    case perSecond = 1
    /// 0.25 秒ずつずらして重ね、1 秒に 4 回変わる（光の粒）。
    case quarterSecond = 4

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// 重ねるもの 1 つと、それを見せる時間。
public struct AmbientOverlay: Hashable, Sendable {
    public let layer: AmbientLayer
    public let window: TimerWindow
    public let pace: AmbientPace

    public init(layer: AmbientLayer, window: TimerWindow, pace: AmbientPace = .perSecond) {
        self.layer = layer
        self.window = window
        self.pace = pace
    }
}

/// キャラの絵が、ウィジェットの動きのために持っているもの（3-C ⑫）。
///
/// どちらも絵から決まるので、パイプラインが画素を見て `characters.json` に書く（3-2b）。
public struct AmbientArt: Hashable, Sendable {

    /// まぶたの差分を持つ姿勢。
    ///
    /// 差分は、まばたきの絵と目を開けた絵の違いから作る（`idle_02` − `idle_01`）。まばたきの絵が
    /// 無い姿勢には作れない。Tier 1 の絵では立ち姿（idle）だけで、すわる姿は 1 コマしかない
    /// （待受モードでも、すわっているあいだはまばたきしない）。
    public let eyelidPoses: Set<Pose>

    /// 寝息の 2 コマ目が、1 コマ目をすっぽり覆えるか。覆えるなら 1 コマ目を土台にして
    /// 2 コマ目だけを重ねる（タイマー 1 本）。覆えないなら 2 枚を出し分ける（2 本）。
    public let sleepFrameCoversBase: Bool

    public init(eyelidPoses: Set<Pose>, sleepFrameCoversBase: Bool) {
        self.eyelidPoses = eyelidPoses
        self.sleepFrameCoversBase = sleepFrameCoversBase
    }
}

/// ある姿を、ウィジェットでどう動かすか（プラン §9 Phase 3 の 3-C ④、D-17）。
///
/// **土台の絵を常に描き、変わるところだけを重ねる。** 出し入れする絵が 2 枚だと、
/// 別々のタイマーの境目で 1 コマだけ「両方見える／両方消える」が起きる（スパイク E）。
/// 重ねる方式なら起きない。跳ねる絵（よろこぶ）のように土台を覆えないときだけ、2 枚を出し分ける。
///
/// 描き手は `baseFrame` を描き、`overlays` を順に重ねる。絵はどれも `pose` のもの（姿勢に
/// 絵が無ければ、待受モードと同じく立ち姿に落とす）。`pose` は `Activity.stillPose` と同じ。
/// 描画の段が上がらないとき（5 分ごとの切り替え）も、同じ姿勢の 1 コマ目を描く。段が変わっても
/// 姿勢が変わらないようにするため。
public struct AmbientCue: Hashable, Sendable {

    /// 描く姿勢。歩いているときは、立ち止まった姿（idle。`Activity.stillPose`）。
    public let pose: Pose
    /// 常に描くコマ。nil のときは、重ねるコマどうしで出し分ける。
    public let baseFrame: Int?
    public let overlays: [AmbientOverlay]

    public init(pose: Pose, baseFrame: Int?, overlays: [AmbientOverlay]) {
        self.pose = pose
        self.baseFrame = baseFrame
        self.overlays = overlays
    }

    /// 1 つのウィジェットに置けるタイマーの本数（D-17: 原則 4 本・最大 8 本）。
    ///
    /// 実機では 14 本でも、ホーム画面に戻った直後に止まらなかった（3-0b）。上限は遅れではなく、
    /// いちばん多い組み合わせ（夜のおどりの 2 本＋光の粒 4 本＋時報 2 本）に合わせてある。
    public static let maximumTimers = 8

    /// 使うタイマーの本数。
    public var timerCount: Int { overlays.reduce(0) { $0 + $1.window.timerCount } }

    /// `pace` までの速さのものだけを残す。描画の段が 1fps までなら `.perSecond` を渡す。
    public func limited(to pace: AmbientPace) -> AmbientCue {
        keeping { $0.pace <= pace }
    }

    /// タイマーを `maximum` 本までに収める。光の粒、時報の吹き出しの順に外す。
    public func fitted(toTimers maximum: Int = maximumTimers) -> AmbientCue {
        guard timerCount > maximum,
              let rank = overlays.compactMap(\.layer.dropRank).min() else { return self }
        return keeping { $0.layer.dropRank != rank }.fitted(toTimers: maximum)
    }

    private func keeping(_ isKept: (AmbientOverlay) -> Bool) -> AmbientCue {
        AmbientCue(pose: pose, baseFrame: baseFrame, overlays: overlays.filter(isKept))
    }
}

public extension AmbientCue {

    /// その姿の動かし方。
    ///
    /// - `blink`: そのキャラのまばたきの集まり（`BlinkRhythm.digits`）
    /// - `art`: そのキャラの絵が持っているもの（まぶたの差分、寝息の 2 コマ目が覆えるか）
    ///
    /// 上限（`maximumTimers`）を超えるものは外してから返す。
    static func cue(for state: SceneState, room: Room, blink: DigitSet, art: AmbientArt) -> AmbientCue {
        let body = bodyCue(for: state.activity, room: room, blink: blink, art: art)
        let bubble = state.bubble?.kind == .clock ? [clockBubble] : []
        return AmbientCue(pose: body.pose, baseFrame: body.baseFrame, overlays: body.overlays + bubble)
            .fitted()
    }

    /// キャラの動き。歩く姿は、エントリの時刻に立ち止まった姿で描く（居場所の移動は
    /// エントリ切替のアニメで見せる。3-C ④'）。
    private static func bodyCue(for activity: Activity, room: Room, blink: DigitSet,
                                art: AmbientArt) -> AmbientCue {
        switch activity {
        case .sleep, .nap:
            sleeping(coversBase: art.sleepFrameCoversBase)
        case .dance(let itemId):
            cheering(withSparkles: room.hasMirrorBall(id: itemId))
        case .play, .happyStretch:
            cheering(withSparkles: false)
        case .wander, .idle, .clockGreet, .eat, .sit, .look:
            blinking(activity.stillPose, blink: blink, art: art)
        }
    }

    /// その姿勢の 1 コマ目に、まぶたを重ねる。まぶたの差分が無い姿勢は、1 コマ目だけ。
    private static func blinking(_ pose: Pose, blink: DigitSet, art: AmbientArt) -> AmbientCue {
        let eyelid = AmbientOverlay(layer: .eyelid, window: BlinkRhythm.window(for: blink))
        return AmbientCue(pose: pose, baseFrame: 0,
                          overlays: art.eyelidPoses.contains(pose) ? [eyelid] : [])
    }

    /// 寝息。2 秒吸って 3 秒吐く。
    private static func sleeping(coversBase: Bool) -> AmbientCue {
        let exhale = AmbientOverlay(layer: .frame(1), window: .when(.sleepBreath))
        guard !coversBase else {
            return AmbientCue(pose: .sleep, baseFrame: 0, overlays: [exhale])
        }
        let inhale = AmbientOverlay(layer: .frame(0), window: .when(DigitSet.sleepBreath.complement))
        return AmbientCue(pose: .sleep, baseFrame: nil, overlays: [inhale, exhale])
    }

    /// よろこぶ 2 コマを 1 秒ごとに出し分ける。ミラーボールの前なら、光の粒も重ねる。
    private static func cheering(withSparkles: Bool) -> AmbientCue {
        let frames = [AmbientOverlay(layer: .frame(0), window: .when(.even)),
                      AmbientOverlay(layer: .frame(1), window: .when(.odd))]
        return AmbientCue(pose: .happy, baseFrame: nil, overlays: frames + (withSparkles ? sparkles : []))
    }

    /// ミラーボールの光の粒。0.25 秒ずつずらした 4 つで、1 秒に 4 回きらめく。
    private static var sparkles: [AmbientOverlay] {
        (0..<sparkleCount).map { index in
            AmbientOverlay(layer: .sparkle(index),
                           window: .when(.even, advancedBy: Double(index) * sparklePhaseSeconds),
                           pace: .quarterSecond)
        }
    }

    /// 時報の吹き出し。毎正時からの 30 秒だけ開く（分の一の位が 0、かつ秒の十の位が 0〜2）。
    ///
    /// 時報のエントリは :00 から 5 分続くが、そのあいだ分の一の位は 0〜4 なので、
    /// 開くのは最初の 30 秒だけになる。
    private static var clockBubble: AmbientOverlay {
        AmbientOverlay(layer: .clockBubble,
                       window: .when(.zero, at: .minuteOnes).and(.when(.firstHalfMinute, at: .secondTens)))
    }

    private static let sparkleCount = 4
    private static let sparklePhaseSeconds = 0.25
}

extension Room {
    /// その ID のアイテムがミラーボールか。
    func hasMirrorBall(id: String) -> Bool {
        items.contains { $0.id == id && $0.kind == .mirrorBall }
    }
}
