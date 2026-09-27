import Foundation
@testable import CTCore

/// テストで使う絵の持ち物（姿勢ごとの枚数）。取り込みの段（プラン §9 Phase 2 の 2-C ③）に合わせてある。
enum TestArt {

    /// Tier 1（§5.3 の 12 枚）。同梱の 5 体と同じ。見上げる・驚く（Tier 2）は無い。
    static let tierOne: [Pose: Int] = [.idle: 2, .walk: 4, .sit: 2, .sleep: 2, .happy: 2]
    /// どの姿勢にも絵がある（見上げる・驚くにも、まばたきの絵まで足したとき）。
    static let everyPose: [Pose: Int] = tierOne.merging([.lookUp: 2, .surprised: 2]) { $1 }
    /// ポーズの格子だけ（歩く帯なし）。まばたき・寝息の 2 コマ目はアプリが作る（D-38）。
    static let posesOnly: [Pose: Int] = [.idle: 2, .sit: 2, .sleep: 2, .happy: 2]
    /// 立ち姿 1 枚（Tier 0）。まばたきの絵（2 コマ目）はアプリが作る。
    static let single: [Pose: Int] = [.idle: 2]
    /// 立ち姿 1 枚で、目が見つからず、まばたきの絵を作れなかったもの。
    static let singleWithoutBlink: [Pose: Int] = [.idle: 1]

    /// その枚数の絵を持つキャラ。絵の名前は `<id>_<姿勢>_<番号>`。
    static func character(id: String = "piyo", frames: [Pose: Int],
                          personality: Personality = Personality(activity: 0.8, nightOwl: 0.3, napiness: 0.5,
                                                                 favorites: [.mirrorBall]),
                          origin: Origin = .bundled) -> Character {
        let poses = frames.mapValues { count in (0..<count).map { "frame_\($0 + 1)" } }
        let named = Dictionary(uniqueKeysWithValues: poses.map { pose, names in
            (pose, names.map { "\(id)_\(pose.rawValue)_\($0)" })
        })
        return Character(id: id, displayName: id, personality: personality, poses: named, origin: origin)
    }
}
