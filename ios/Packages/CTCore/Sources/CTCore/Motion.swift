import Foundation

/// 区切りの中で、位置・向き・コマ番号を時刻から直接求める。
///
/// どれも「経過時間の関数」で、状態を持たない。だから任意の時刻を飛ばして引けるし、
/// アプリを閉じて開き直しても、ウィジェットで見た姿と食い違わない（プラン §5.4）。
public enum Motion {

    /// 歩くときの経由点の間隔。
    public static let waypointSeconds: Double = 6
    /// 経由点で立ち止まる確率。ずっと同じ速さで動くと機械的に見える。
    public static let dwellProbability: Double = 0.30
    /// 立ち止まっているあいだの割合。残りで次の経由点まで移動する。
    public static let dwellFraction: Double = 0.45

    /// 0〜1 をなめらかに（両端でゆっくり、中央で速く）。
    public static func easeInOut(_ t: Double) -> Double {
        let clamped = Swift.min(1, Swift.max(0, t))
        return clamped * clamped * (3 - 2 * clamped)
    }

    /// 区切りの中の位置。
    public static func position(in segment: Segment, atMinute minute: Double,
                                rng: IndexedRandom, floor: RoomRect) -> RoomPoint {
        guard segment.isMoving else { return segment.from }

        let elapsed = Swift.max(0, (minute - segment.startMinute) * 60)
        let total = Swift.max(0.000_1, segment.durationMinutes * 60)
        let slotCount = Swift.max(1, Int((total / waypointSeconds).rounded()))
        let slotLength = total / Double(slotCount)
        let slot = Swift.min(slotCount - 1, Int(elapsed / slotLength))
        let withinSlot = (elapsed - Double(slot) * slotLength) / slotLength

        let a = waypoint(slot, of: slotCount, in: segment, rng: rng, floor: floor)
        let b = waypoint(slot + 1, of: slotCount, in: segment, rng: rng, floor: floor)

        // 立ち止まる区間でも、終わりには必ず次の経由点に着く。着かないと
        // 次の区切りの始まりと位置がずれて、瞬間移動して見える。
        let dwells = rng.bool(dwellProbability, UInt64(slot), 7)
        let progress = dwells
            ? easeInOut((withinSlot - dwellFraction) / (1 - dwellFraction))
            : easeInOut(withinSlot)

        return floor.clamping(RoomPoint(x: a.x + (b.x - a.x) * progress,
                                        y: a.y + (b.y - a.y) * progress))
    }

    /// 何番目の経由点か。配列を作らず、添字から直接求める。
    static func waypoint(_ index: Int, of count: Int, in segment: Segment,
                         rng: IndexedRandom, floor: RoomRect) -> RoomPoint {
        if index <= 0 { return segment.from }
        if index >= count { return segment.to }
        let ratio = Double(index) / Double(count)
        let baseX = segment.from.x + (segment.to.x - segment.from.x) * ratio
        let baseY = segment.from.y + (segment.to.y - segment.from.y) * ratio
        // まっすぐ歩くと機械的に見えるので、左右と奥行きに少し散らす。
        let jitterX = (rng.unit(UInt64(index), 0) - 0.5) * floor.width * 0.18
        let jitterY = (rng.unit(UInt64(index), 1) - 0.5) * floor.height * 0.35
        return floor.clamping(RoomPoint(x: baseX + jitterX, y: baseY + jitterY))
    }

    /// 向き。歩いているときだけ進行方向を向き、それ以外は正面。
    public static func facing(in segment: Segment, atMinute minute: Double,
                              rng: IndexedRandom, floor: RoomRect) -> Facing {
        guard segment.isMoving else { return .front }
        let now = position(in: segment, atMinute: minute, rng: rng, floor: floor)
        let ahead = position(in: segment, atMinute: minute + 1.0 / 60.0, rng: rng, floor: floor)
        let dx = ahead.x - now.x
        // 動きが小さいときは向きを変えない。立ち止まった瞬間にちらつくため。
        if abs(dx) < 0.000_5 {
            return segment.to.x < segment.from.x ? .left : .right
        }
        return dx < 0 ? .left : .right
    }

    // MARK: - コマ番号

    /// 姿勢ごとのコマ送りの速さ。少ない枚数でも自然に見える値にしてある（プラン §5.5）。
    public static let walkFramesPerSecond: Double = 8
    public static let happyFramesPerSecond: Double = 5
    public static let sleepSecondsPerFrame: Double = 4
    /// まばたきの間隔と長さ。
    public static let blinkIntervalSeconds: Double = 4.0
    public static let blinkVarianceSeconds: Double = 2.5
    public static let blinkDurationSeconds: Double = 0.18

    /// いま何コマ目を出すか。
    public static func frameIndex(pose: Pose, frameCount: Int,
                                  localSeconds: Double, rng: IndexedRandom) -> Int {
        guard frameCount > 1 else { return 0 }
        switch pose {
        case .walk:
            return Int(localSeconds * walkFramesPerSecond) % frameCount
        case .happy:
            return Int(localSeconds * happyFramesPerSecond) % frameCount
        case .sleep:
            return Int(localSeconds / sleepSecondsPerFrame) % frameCount
        case .idle, .sit:
            // 立ち止まっているとき・すわっているときは目を開けたまま。ときどき 1 コマだけまばたく
            // （2 コマ目がまばたきの絵。すわる姿の 2 コマ目は 3-2b で足した）。
            let interval = blinkIntervalSeconds + rng.unit(11) * blinkVarianceSeconds
            let phase = localSeconds.truncatingRemainder(dividingBy: interval)
            return phase < blinkDurationSeconds ? 1 : 0
        case .lookUp, .surprised:
            return 0
        }
    }
}
