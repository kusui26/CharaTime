import Foundation

/// 取り込みの知らせ（プラン §9 Phase 2 の 2-C ⑤-7、テンプレート §4.4）。
///
/// 取り込みは止めずに進め、気づいたことを知らせる。直しが要るものには、直しのプロンプト（`FixPrompt`）を
/// 組にして出す（キャラ工房がコピーのボタンで渡す。2-6）。何がどこで（`detail`）を添える。
public struct ImportNotice: Hashable, Sendable, CustomStringConvertible {

    public enum Kind: String, Hashable, Sendable, CaseIterable {
        case figuresTouching = "コマがくっついています"
        case figureCount = "コマの数が合いません"
        case widePose = "横に広い姿勢があるので、キャラが小さめになります"
        case backgroundNotTransparent = "背景が透明ではありません"
        case backgroundNotSolid = "地が 1 色ではありません"
        case shadowUnderFeet = "足元に影があります"
        case eyesNotFound = "まばたきを作れませんでした（目が見つかりません）"
        case blurryOnStandby = "立ち姿が小さく、待受で少しぼやけます"
        case blurryOnWidget = "立ち姿が小さく、ウィジェットでもぼやけます"
        case watermarkRemoved = "隅の透かしを外しました"
        case partsRemoved = "離れた小さな部品を外しました"
        case walkingRight = "歩く向きが右だったので、左右を反転しました"
    }

    public let kind: Kind
    /// 何がどこで（コマの番号・数・画素数など）。
    public let detail: String

    public init(_ kind: Kind, _ detail: String = "") {
        self.kind = kind
        self.detail = detail
    }

    public var description: String { detail.isEmpty ? kind.rawValue : "\(kind.rawValue)（\(detail)）" }
}
