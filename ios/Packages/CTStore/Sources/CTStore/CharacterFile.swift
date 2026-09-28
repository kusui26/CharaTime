import Foundation
import CTCore

/// 取り込んだキャラ 1 体の `character.json`（プラン §9 Phase 2 の 2-C ③⑪）。
///
/// **`Character` と同じ形に、取り込みの記録を足したもの。** 同梱の `characters.json` の 1 体と同じ項目が
/// そのまま並ぶので、どちらも同じ `Character` の読み方で読める（D-34）。記録は描くのに使わないので、
/// 壊れていても読み捨てて、キャラは生かす。
public struct CharacterFile: Codable, Sendable, Equatable {

    /// この型が理解できる版。`AppState` と同じく、項目を足すだけなら上げない（3-C ⑪）。
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var character: CTCore.Character
    public var importRecord: ImportRecord?

    public init(character: CTCore.Character, importRecord: ImportRecord? = nil) {
        self.schemaVersion = Self.currentSchemaVersion
        self.character = character
        self.importRecord = importRecord
    }

    private enum FileKeys: String, CodingKey {
        case schemaVersion, importRecord
    }

    public init(from decoder: any Decoder) throws {
        character = try CTCore.Character(from: decoder)
        let box = try decoder.container(keyedBy: FileKeys.self)
        schemaVersion = try box.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        importRecord = try? box.decodeIfPresent(ImportRecord.self, forKey: .importRecord)
    }

    // `Character` の項目と同じ階層に、版と記録を並べる。
    public func encode(to encoder: any Encoder) throws {
        try character.encode(to: encoder)
        var box = encoder.container(keyedBy: FileKeys.self)
        try box.encode(schemaVersion, forKey: .schemaVersion)
        try box.encodeIfPresent(importRecord, forKey: .importRecord)
    }
}

/// 取り込みの記録（2-C ③）。どの段で、どんな元の画像から、どう背景を外したか。
///
/// **描くのには使わない。** 整え方を直すとき・知らせを出すときの手がかり。元の画像そのものは残さない
/// （Exif・位置情報を持ち込まない。`research/I` §5.1）ので、ここに残すのは画素の数と外し方だけ。
public struct ImportRecord: Codable, Sendable, Equatable {

    /// どの段で取り込んだか（2-C ③ の表）。
    public enum Stage: String, Codable, Sendable, CaseIterable {
        /// 正面の立ち姿 1 枚（Tier 0）。
        case single
        /// ポーズの格子（立つ・すわる・ねる・よろこぶ）。歩く 4 コマは無い。
        case poses
        /// ポーズと歩く 4 コマ（Tier 1）。
        case posesAndWalk
    }

    /// 背景の外し方（D-36。SVG は D-39）。
    public enum Background: String, Codable, Sendable, CaseIterable {
        /// 透明のまま（不透明さだけそろえた）。
        case transparent
        /// 1 色の地を、縁からつながるところだけ抜いた。
        case solidColor
        /// 市松模様（生成 AI が「透明」を描いたもの）を抜いた。
        case checkerboard
        /// Vision の被写体の切り抜き。
        case subjectLift
        /// SVG を絵にした（全面を覆う最初の四角は背景として外した）。
        case vector
    }

    /// 元の画像 1 枚ぶん。
    public struct Source: Codable, Sendable, Equatable {
        public var pixelWidth: Int
        public var pixelHeight: Int
        public var background: Background

        public init(pixelWidth: Int, pixelHeight: Int, background: Background) {
            self.pixelWidth = pixelWidth
            self.pixelHeight = pixelHeight
            self.background = background
        }
    }

    public var stage: Stage
    /// 取り込んだ順。あとからコマを足したら（2-C ⑤-9）、後ろに足す。
    public var sources: [Source]
    /// 取り込んだときに画面に出していた手引き（プロンプトのテンプレート）の版（`PromptTemplate.version`）。
    /// どの版で切り分けにつまずきやすいかを、あとで見る（テンプレートの §4.5）。2-1 の記録には無い。
    public var guideVersion: String?

    public init(stage: Stage, sources: [Source], guideVersion: String? = nil) {
        self.stage = stage
        self.sources = sources
        self.guideVersion = guideVersion
    }
}
