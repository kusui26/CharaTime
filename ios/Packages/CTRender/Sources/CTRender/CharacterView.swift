import SwiftUI
import CTCore
import CTAssets

/// 同梱の絵を 1 枚。`tools/pipeline` が焼いたものだけがここに来る。
struct SpriteView: View {

    let assetName: String

    var body: some View {
        Image(assetName, bundle: AssetBundle.value)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
    }
}

/// キャラ 1 体。コマを選び、味付け（呼吸・弾み・かしげ）を当てて描く。
struct CharacterView: View {

    let character: CTCore.Character
    let state: SceneState
    let layout: SceneLayout
    let flourish: Flourish

    var body: some View {
        let position = state.position
        let height = layout.characterHeight(at: position, characterScale: character.scale)
        let frame = layout.spriteFrame(footAt: position, height: height,
                                       liftRatio: flourish.liftRatio)
        SpriteView(assetName: assetName)
            .frame(width: frame.width, height: frame.height)
            // 絵は左を向いて描いてある。右へ歩くときだけ裏返す。
            .scaleEffect(x: (state.facing == .right ? -1 : 1) * flourish.stretchX,
                         y: flourish.stretchY, anchor: groundAnchor)
            .rotationEffect(.degrees(flourish.tiltDegrees), anchor: groundAnchor)
            .position(x: frame.midX, y: frame.midY)
    }

    /// 伸び縮みと傾きの支点。**絵の下端ではなく接地線**に置く。
    /// 下端に置くと、傾けたときに足が床から離れる。
    private var groundAnchor: UnitPoint {
        UnitPoint(x: 0.5, y: layout.geometry.groundRatio)
    }

    /// いま出すコマのアセット名。コマ番号が範囲外でも必ず 1 枚返す。
    private var assetName: String {
        let pose = state.activity.pose
        guard let frames = character.poses[pose], !frames.isEmpty else {
            return character.poses[.idle]?.first ?? ""
        }
        return frames[Swift.min(Swift.max(state.frame, 0), frames.count - 1)]
    }
}

/// 足元の影。
struct ShadowView: View {

    let state: SceneState
    let layout: SceneLayout
    let flourish: Flourish
    let characterScale: Double

    var body: some View {
        let height = layout.characterHeight(at: state.position, characterScale: characterScale)
        let frame = layout.shadowFrame(at: state.position, height: height,
                                       scale: flourish.shadowScale)
        Ellipse()
            .fill(Color(hex: 0x3B2B2B))
            .opacity(SceneLayout.shadowOpacity * flourish.shadowOpacity)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
    }
}
