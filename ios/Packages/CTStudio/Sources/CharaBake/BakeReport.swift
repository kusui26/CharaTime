import Foundation
import CTCore
import CTStore
import CTStudio

/// 整えたときの記録（`final/bake.json`）。どの絵を、どう整えたか（プラン §6.6 の記録を助ける）。
///
/// **描くのには使わない**（`tools/pipeline` は絵のファイルだけを読む）。焼き直しても同じ中身なら同じバイトになるよう、
/// 日時を持たず、キーを並べて書く（git の差分を出さない）。
public struct BakeReport: Codable, Sendable, Equatable {

    /// 生の絵 1 枚ぶん（場所は持たない。ファイル名だけ）。
    public struct Source: Codable, Sendable, Equatable {
        public let file: String
        public let layout: SheetLayout
        public let pixelWidth: Int
        public let pixelHeight: Int
        public let background: ImportRecord.Background
        /// 見つけたコマの数（手引きの数は `layout.expectedCount`）。
        public let figures: Int
        public let notices: [String]
    }

    public let id: String
    /// 手引き（プロンプトのテンプレート）の版。
    public let guideVersion: String?
    public let sources: [Source]
    /// そろえるときに気づいたこと。
    public let notices: [String]
    public let frames: [Pose: Int]
    public let eyelids: [Pose]
    public let spares: [Pose]
    public let sleepFrameCoversBase: Bool
    /// 立ち姿の、枠の中での外接矩形の高さ（hero の画素。小数 1 桁）。
    public let standingHeight: Double

    init(id: String, inputs: [RawInput], analyses: [SheetAnalysis], result: StudioResult) {
        self.id = id
        guideVersion = result.record.guideVersion
        sources = zip(inputs, analyses).map { input, analysis in
            Source(file: input.file.lastPathComponent, layout: analysis.layout,
                   pixelWidth: analysis.source.pixelWidth, pixelHeight: analysis.source.pixelHeight,
                   background: analysis.source.background, figures: analysis.figures.count,
                   notices: analysis.notices.map(\.description))
        }
        notices = result.notices.map(\.description)
        frames = result.frames.mapValues(\.count)
        eyelids = Pose.allCases.filter { result.eyelids[$0] != nil }
        spares = Pose.allCases.filter { result.spares[$0] != nil }
        sleepFrameCoversBase = result.sleepFrameCoversBase
        standingHeight = (result.standingHeight * 10).rounded() / 10
    }

    /// `bake.json` の中身（キーを並べ、字下げして書く）。
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self) + Data("\n".utf8)
    }
}
