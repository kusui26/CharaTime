import Foundation
import CTCore
import CTStore
import CTStudio

// 道具の知らせに出す名前（日本語）。テンプレートの段の名前（B-1 など）を添えて、手引きと照らし合わせやすくする。

extension SheetLayout {
    var displayName: String {
        switch self {
        case .single: "1 枚の絵"
        case .sheet: "キャラシート（B-1）"
        case .poses6: "ポーズ 6 コマ（P6）"
        case .poses4A: "ポーズ 4 コマの 1 枚目（B-2a）"
        case .poses4B: "ポーズ 4 コマの 2 枚目（B-2b）"
        case .walk: "歩く 4 コマ（B-3）"
        }
    }
}

extension Pose {
    var displayName: String {
        switch self {
        case .idle: "立ち姿"
        case .walk: "歩く"
        case .sit: "すわる"
        case .sleep: "寝る"
        case .happy: "よろこぶ"
        case .lookUp: "見上げる"
        case .surprised: "驚く"
        }
    }
}

extension ImportRecord.Background {
    var displayName: String {
        switch self {
        case .transparent: "透明"
        case .solidColor: "1 色の地"
        case .checkerboard: "市松模様の地"
        case .subjectLift: "被写体の切り抜き"
        case .vector: "SVG"
        }
    }
}
