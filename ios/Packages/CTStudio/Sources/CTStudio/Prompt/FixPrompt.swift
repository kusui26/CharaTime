import Foundation

/// 直しのプロンプト（テンプレートの §5）。取り込みの知らせと組にして、コピーのボタンで渡す（§4.4、2-6）。
/// その絵を開いた会話で送る。
public enum FixPrompt: String, Sendable, CaseIterable {
    case space = "F-SPACE"
    case compact = "F-COMPACT"
    case count = "F-COUNT"
    case background = "F-BG"
    case backgroundWhite = "F-BG-WHITE"
    case shadow = "F-SHADOW"
    case eyes = "F-EYES"
    case same = "F-SAME"

    /// 本文。F-COUNT は、その段のコマの数と並びを入れる。
    public func text(for layout: SheetLayout) -> String {
        switch self {
        case .space: "Redraw the same image with much more empty space between the drawings. "
            + "Nothing may touch another drawing or the edge. Keep everything else the same."
        case .compact: "Redraw with every pose compact: arms close to the body or pointing up, "
            + "the sleeping pose curled up in a round ball. No pose may be wider than the standing pose. "
            + "Keep everything else the same."
        case .count: "There must be exactly \(layout.expectedCount) drawings in \(layout.grid.rows) rows x "
            + "\(layout.grid.columns) columns, in the order I listed. Please redraw."
        case .background: "Make the background fully transparent (real alpha, PNG). "
            + "Keep everything else exactly the same."
        case .backgroundWhite: "Change the background to solid pure white #FFFFFF everywhere. "
            + "Keep everything else exactly the same."
        case .shadow: "Remove every shadow, including any shadow under the feet. "
            + "Keep everything else exactly the same."
        case .eyes: "Redraw the eyes as two small black dots with a tiny white highlight. "
            + "Keep everything else the same."
        case .same: "The character changed. "
            + "Match Image 1 exactly: the same shapes, colors, face and proportions. Please redraw."
        }
    }
}

/// 知らせに対する手当て（テンプレートの §4.4）。
public enum NoticeRemedy: Sendable, Equatable {
    /// 直しのプロンプトを出す。
    case fix(FixPrompt)
    /// 「くっきりさせたいとき」（ポーズを P4 の 2 枚に分けるプロンプト）を勧める。
    case sharperPoses
}

extension ImportNotice {

    /// この知らせの手当て。直しが要らないもの（アプリが直した・外した）は nil。
    public var remedy: NoticeRemedy? {
        switch kind {
        case .figuresTouching: .fix(.space)
        case .figureCount: .fix(.count)
        case .widePose: .fix(.compact)
        case .backgroundNotTransparent: .fix(.background)
        case .backgroundNotSolid: .fix(.backgroundWhite)
        case .shadowUnderFeet: .fix(.shadow)
        case .eyesNotFound: .fix(.eyes)
        case .blurryOnStandby, .blurryOnWidget: .sharperPoses
        case .watermarkRemoved, .partsRemoved, .walkingRight: nil
        }
    }
}
