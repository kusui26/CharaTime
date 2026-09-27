import Foundation

/// 足りない姿勢を、どの絵でどう見せるか（プラン §9 Phase 2 の 2-C ③）。
///
/// 取り込んだキャラの絵は、立ち姿 1 枚（Tier 0）から 12 コマ（Tier 1）までまちまち。行動が求める姿勢の
/// 絵が無ければ、**立ち姿の絵を借り、動き（跳ねる・傾ける）と目を閉じたコマで見せる**。同梱の 5 体も、
/// 見上げる姿（Tier 2）はここで立ち姿になる。
///
/// **どの面もこの表を引く**（待受モードのコマと味付け、ウィジェットの止めた 1 枚と疑似アニメ）。
/// 表が 1 か所なので、面によって借りる絵が違う、ということが起きない。どれも時刻の関数のまま（§2）。
public struct PoseStandIn: Hashable, Sendable {

    /// 味付けの選び。
    public enum Flourishing: Hashable, Sendable {
        /// 求めた姿勢の味付け（歩く弾み・跳ねる・寝息・かしげ。§5.5）。
        case asWanted
        /// 立ち姿を跳ねさせて歩く（歩く絵が無いとき）。
        case hopWalk
    }

    /// 行動が求めた姿勢。
    public let wanted: Pose
    /// 絵を借りる姿勢。絵があれば `wanted` と同じ。
    public let source: Pose
    /// 出し続けるコマ。nil なら、借りた姿勢のコマ送り（立ち姿ならまばたき）。
    public let heldFrame: Int?
    public let flourishing: Flourishing

    public init(wanted: Pose, source: Pose, heldFrame: Int? = nil, flourishing: Flourishing = .asWanted) {
        self.wanted = wanted
        self.source = source
        self.heldFrame = heldFrame
        self.flourishing = flourishing
    }

    /// 絵を借りているか。
    public var isBorrowed: Bool { source != wanted }

    /// 立ち姿の 2 コマ目は、まばたきの絵（目を閉じた立ち姿。§5.3 の Tier 1）。寝顔に借りる。
    public static let eyesClosedFrame = 1

    /// 求めた姿勢の見せ方。`frameCounts` は、キャラが持っている絵の枚数（姿勢ごと）。
    public static func resolve(_ wanted: Pose, frameCounts: [Pose: Int]) -> PoseStandIn {
        // 立ち姿は借りる先が無い。絵が無ければ何も描かれないが、落ちはしない（`Character.placeholder`）。
        guard wanted != .idle, (frameCounts[wanted] ?? 0) == 0 else {
            return PoseStandIn(wanted: wanted, source: wanted)
        }
        return borrowingIdle(for: wanted, idleFrameCount: frameCounts[.idle] ?? 0)
    }

    /// 立ち姿を借りる（2-C ③ の表）。
    private static func borrowingIdle(for wanted: Pose, idleFrameCount: Int) -> PoseStandIn {
        switch wanted {
        case .walk:
            // 足は動かせないので、跳ねながら進む。まばたきはそのまま。
            PoseStandIn(wanted: .walk, source: .idle, flourishing: .hopWalk)
        case .sleep:
            // 寝顔は、目を閉じた立ち姿（まばたきの絵）。まばたきの絵も無ければ、目を開けたまま寝息だけ。
            PoseStandIn(wanted: .sleep, source: .idle,
                        heldFrame: idleFrameCount > eyesClosedFrame ? eyesClosedFrame : 0)
        case .idle, .sit, .happy, .lookUp, .surprised:
            // すわる（かしげる）・よろこぶ（跳ねて揺れる）・見上げる（かしげる）は、立ち姿に味付けだけ。
            PoseStandIn(wanted: wanted, source: .idle)
        }
    }

    /// いま何コマ目を出すか。`frameCount` は、借りた姿勢（`source`）の絵の枚数。
    public func frameIndex(frameCount: Int, localSeconds: Double, rng: IndexedRandom) -> Int {
        heldFrame ?? Motion.frameIndex(pose: source, frameCount: frameCount,
                                       localSeconds: localSeconds, rng: rng)
    }

    /// その瞬間の味付け。`localSeconds` は区切りが始まってからの秒数。
    public func flourish(localSeconds: Double) -> Flourish {
        switch flourishing {
        case .asWanted: ProceduralMotion.flourish(pose: wanted, localSeconds: localSeconds)
        case .hopWalk: ProceduralMotion.hopWalking(localSeconds)
        }
    }
}

public extension Character {

    /// 姿勢ごとの絵の枚数。無い姿勢は入らない。
    var frameCounts: [Pose: Int] { poses.mapValues(\.count) }

    /// その姿勢の見せ方。絵が無ければ、立ち姿を借りる（`PoseStandIn`）。
    func standIn(for pose: Pose) -> PoseStandIn {
        PoseStandIn.resolve(pose, frameCounts: frameCounts)
    }
}
