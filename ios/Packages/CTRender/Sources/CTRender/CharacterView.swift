import SwiftUI
import WidgetKit
import CTCore
import CTAssets

/// 絵を 1 枚。同梱の絵（`tools/pipeline` が焼いた Asset Catalog）も、取り込んだ絵（CTStore が読んだ画像）も、
/// **ここで同じに描く**（D-34。出どころは `SpriteSource`）。
///
/// **着色・クリアの外観でも色を保つ**（`widgetAccentedRenderingMode(.fullColor)`、3-C ⑤）。
/// 何も付けないと、その外観では絵も 1 色の濃淡になり、キャラの見分けがつかなくなる。
/// ウィジェットの外（アプリ）では、この指定は何もしない。
///
/// 絵は飾りとして扱う。名前つきで出すと、VoiceOver がアセット名（`piyo_idle_01_mini`）を読み上げる。
struct SpriteView: View {

    let name: String
    let source: SpriteSource

    var body: some View {
        if let image {
            image
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .widgetAccentedRenderingMode(.fullColor)
        }
    }

    /// 描く絵。読み込んだ絵に、その名前が無ければ nil（何も描かない）。
    private var image: Image? {
        switch source.art(named: name) {
        case .catalog(let assetName): Image(decorative: assetName, bundle: AssetBundle.value)
        // 大きさは枠（`.resizable()`）で決まるので、画像の倍率は使わない。
        case .loaded(let picture): Image(decorative: picture, scale: 1)
        case .missing: nil
        }
    }
}

/// どの大きさの絵で描くか。
public enum SpriteSize: Sendable {
    /// 待受モードの絵（hero）。
    case hero
    /// ウィジェット用の小さい絵（mini。D-20）。無い姿勢は hero で描く。
    case mini
}

/// どの絵を、どの向きで、どの大きさで描くか。
struct SpritePick: Sendable, Equatable {
    var pose: Pose
    var frame: Int
    var facing: Facing
    var size: SpriteSize

    /// 待受モード: 行動の姿勢とコマを、そのまま描く。姿勢の絵が無ければ、借りた立ち姿（`PoseStandIn`）の
    /// コマ（日課エンジンが、借りた絵のコマ番号を返す）。
    static func live(_ state: SceneState, character: CTCore.Character) -> SpritePick {
        SpritePick(pose: character.standIn(for: state.activity.pose).source, frame: state.frame,
                   facing: state.facing, size: .hero)
    }

    /// ウィジェット: 止めた 1 枚。止めた姿勢（歩いていれば立ち止まった姿）の 1 コマ目を正面で描く。
    ///
    /// 1 コマ目は目を開けた絵（idle の 2 コマ目はまばたき）。姿のコマをそのまま使うと、たまたま
    /// まばたきの瞬間に当たったエントリで、5 分間目を閉じたまま止まる（3-C ④）。寝姿の絵が無い子は、
    /// 寝顔として借りた、目を閉じた立ち姿のコマ（疑似アニメの土台と同じ。`AmbientCue`）。
    static func still(_ state: SceneState, character: CTCore.Character) -> SpritePick {
        let look = character.standIn(for: state.activity.stillPose)
        return SpritePick(pose: look.source, frame: look.heldFrame ?? 0, facing: .front, size: .mini)
    }
}

extension CTCore.Character {

    /// 描く絵の名前。**どんな指定でも必ず 1 枚返す**（落とさない）。
    ///
    /// 足りない姿勢は、選ぶときに借りた立ち姿になっている（`SpritePick`）。それでもその姿勢に絵が無ければ
    /// 立ち姿の 1 コマ目、コマ番号が範囲外なら端のコマを使う。
    func spriteName(for pick: SpritePick) -> String {
        let frames = self.frames(pick.pose, size: pick.size)
        guard !frames.isEmpty else { return self.frames(.idle, size: pick.size).first ?? "" }
        return frames[Swift.min(Swift.max(pick.frame, 0), frames.count - 1)]
    }

    private func frames(_ pose: Pose, size: SpriteSize) -> [String] {
        let hero = poses[pose] ?? []
        guard size == .mini, let mini = miniPoses[pose], !mini.isEmpty else { return hero }
        return mini
    }
}

/// キャラ 1 体。コマを選び、味付け（呼吸・弾み・かしげ）を当てて描く。
struct CharacterView: View {

    let character: CTCore.Character
    let sprites: SpriteSource
    let position: RoomPoint
    let pick: SpritePick
    let layout: SceneLayout
    let flourish: Flourish

    var body: some View {
        let height = layout.characterHeight(at: position, characterScale: character.scale)
        let frame = layout.spriteFrame(footAt: position, height: height,
                                       liftRatio: flourish.liftRatio)
        SpriteView(name: character.spriteName(for: pick), source: sprites)
            .frame(width: frame.width, height: frame.height)
            // 絵は左を向いて描いてある。右へ歩くときだけ裏返す（歩く絵の無い子は、正面の立ち姿を裏返す）。
            .scaleEffect(x: (pick.facing == .right ? -1 : 1) * flourish.stretchX,
                         y: flourish.stretchY, anchor: groundAnchor)
            .rotationEffect(.degrees(flourish.tiltDegrees), anchor: groundAnchor)
            .position(x: frame.midX, y: frame.midY)
    }

    /// 伸び縮みと傾きの支点。**絵の下端ではなく接地線**に置く。
    /// 下端に置くと、傾けたときに足が床から離れる。
    private var groundAnchor: UnitPoint {
        UnitPoint(x: 0.5, y: layout.geometry.groundRatio)
    }
}

/// 足元の影。
struct ShadowView: View {

    let position: RoomPoint
    let layout: SceneLayout
    let flourish: Flourish
    let characterScale: Double

    var body: some View {
        let height = layout.characterHeight(at: position, characterScale: characterScale)
        let frame = layout.shadowFrame(at: position, height: height,
                                       scale: flourish.shadowScale)
        Ellipse()
            .fill(Color(hex: 0x3B2B2B))
            .opacity(SceneLayout.shadowOpacity * flourish.shadowOpacity)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
    }
}
