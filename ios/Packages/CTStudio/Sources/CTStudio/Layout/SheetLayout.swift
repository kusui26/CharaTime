import Foundation
import CTCore

/// 1 枚の画像の割り方（テンプレートの段。`docs/260926_prompt_templates.md` §1.3、プラン §9 Phase 2 の 2-C ④）。
///
/// どの段も、コマの数と並びが決まっている（プロンプトの ① で頼む）。取り込みは、見つけたコマを行ごと・左からの順に
/// 並べ、この並びで姿勢に割り当てる（確かめる画面で並べ替えられる。2-C ⑤-7）。
public enum SheetLayout: String, Sendable, CaseIterable, Codable {
    /// 1 枚の絵（正面の立ち姿 1 体）。手描き・ほかのアプリ（Tier 0）。
    case single
    /// S1 キャラシート（正面・横・後ろ）。正面だけを立ち姿に使う（「この絵だけで始める」。Tier 0）。
    case sheet
    /// P6 ポーズ 6 コマ（3×2、正方形）。利用者の既定（D-38）。
    case poses6
    /// P4 の 1 枚目（2×2、縦 3:4）: 立つ・すわる・寝る・よろこぶ（腕を上げる）。既定の 5 体と「くっきり」。
    case poses4A
    /// P4 の 2 枚目: 立つ（2 枚の背をそろえる基準）・よろこぶ（ほお）・見上げる・驚く。
    case poses4B
    /// W4 歩く 4 コマ（2×2、縦 3:4。左向き）。
    case walk

    /// コマの数。
    public var expectedCount: Int { slots.count }

    /// 行と列（直しのプロンプト F-COUNT に入れる）。
    public var grid: (rows: Int, columns: Int) {
        switch self {
        case .single: (1, 1)
        case .sheet: (1, 3)
        case .poses6: (2, 3)
        case .poses4A, .poses4B, .walk: (2, 2)
        }
    }

    /// 行ごと・左からの順の、コマの役目。
    public var slots: [FigureSlot] {
        switch self {
        case .single: [.frame(.idle, 0)]
        case .sheet: [.frame(.idle, 0), .unused, .unused]
        case .poses6: [.frame(.idle, 0), .frame(.sit, 0), .frame(.sleep, 0),
                       .frame(.happy, 0), .frame(.happy, 1), .spare(.lookUp)]
        case .poses4A: [.frame(.idle, 0), .frame(.sit, 0), .frame(.sleep, 0), .frame(.happy, 0)]
        case .poses4B: [.heightReference, .frame(.happy, 1), .spare(.lookUp), .spare(.surprised)]
        case .walk: (0..<4).map { .frame(.walk, $0) }
        }
    }
}

/// コマの役目。
public enum FigureSlot: Sendable, Hashable {
    /// 姿勢の何コマ目か（0 から）。まばたき・寝息の 2 コマ目はアプリが作るので、ここには来ない（D-38）。
    case frame(Pose, Int)
    /// 予備（見上げる・驚く）。Phase 4 の Tier 2 で使う（2-C ③）。
    case spare(Pose)
    /// 画像どうしの背をそろえる基準だけに使う立ち姿（P4 の 2 枚目）。枠には描かない。
    case heightReference
    /// 使わない（キャラシートの横・後ろ）。
    case unused
}
