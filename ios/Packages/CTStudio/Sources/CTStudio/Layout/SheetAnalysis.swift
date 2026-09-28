import Foundation
import CTStore

/// 1 枚の画像を読み、背景を外し、コマを見つけた結果（プラン §9 Phase 2 の 2-C ⑤-1〜3）。確かめる画面（2-6）に並べる。
public struct SheetAnalysis: Sendable {

    public let layout: SheetLayout
    /// 元の画像の画素数と、背景の外し方（取り込みの記録に残す。元の画像そのものは残さない）。
    public let source: ImportRecord.Source
    /// 見つけたコマ（行ごと・左からの順）。歩く 4 コマは左向きにそろえてある。
    public let figures: [Figure]
    /// 気づいたこと（コマの数・透かし・影・背景・歩く向き）。
    public let notices: [ImportNotice]

    /// 既定の割り当て: コマの順に段の役目を当てる（手引きのコマの順）。役目より多いコマは外す。
    public var defaultAssignment: AssignedSheet {
        let placements = zip(figures, layout.slots).map { AssignedSheet.Placement(figure: $0, slot: $1) }
        return AssignedSheet(source: source, placements: placements)
    }
}

/// 確かめる画面で決めた、1 枚の画像のコマの役目（並べ替え・左右反転・外したあと。2-C ⑤-7）。
public struct AssignedSheet: Sendable {

    public struct Placement: Sendable, Equatable {
        public var figure: Figure
        public var slot: FigureSlot

        public init(figure: Figure, slot: FigureSlot) {
            self.figure = figure
            self.slot = slot
        }
    }

    public var source: ImportRecord.Source
    /// 外したコマは入れない。
    public var placements: [Placement]

    public init(source: ImportRecord.Source, placements: [Placement]) {
        self.source = source
        self.placements = placements
    }
}
