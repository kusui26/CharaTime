import Foundation
import CTStudio

/// chara-bake の失敗。どの絵・どのキャラで何が起きたかを添える（CLAUDE.md §3 の堅牢性）。
public enum BakeError: Error, Sendable, Equatable, CustomStringConvertible {
    /// 読めない（何を・理由）。
    case unreadable(String, String)
    /// 同梱のキャラの id ではない（id・同梱の id）。
    case unknownCharacter(String, [String])
    /// ファイル名から割り方が分からない。
    case unknownRawName(String)
    /// 同じ割り方の絵が 2 枚以上ある（割り方・ファイル名）。
    case duplicateLayout(SheetLayout, [String])
    /// 整える絵が 1 枚も無い（探した所）。
    case noRawImages(String)
    /// 整える処理の失敗（どの絵・理由）。
    case studio(String, StudioError)
    /// 書けない（どこへ・理由）。
    case writeFailed(String, String)
    /// 引数の誤り。
    case usage(String)

    public var description: String {
        switch self {
        case .unreadable(let what, let reason): "\(what) を読めません（\(reason)）"
        case .unknownCharacter(let id, let known):
            "\(id) は同梱のキャラの id ではありません（\(known.joined(separator: "・"))）"
        case .unknownRawName(let name): "\(name) の割り方が分かりません。名前を \(RawNaming.namingRule) で始めてください"
        case .duplicateLayout(let layout, let names):
            "\(layout.displayName) の絵が \(names.count) 枚あります（\(names.joined(separator: "・"))）。使う絵を指定してください"
        case .noRawImages(let folder): "\(folder) に整える絵がありません"
        case .studio(let file, let error): "\(file): \(error)"
        case .writeFailed(let path, let reason): "\(path) に書けません（\(reason)）"
        case .usage(let reason): reason
        }
    }
}
