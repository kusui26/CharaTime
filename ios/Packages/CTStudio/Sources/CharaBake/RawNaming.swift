import Foundation
import CTStudio

/// 生の絵のファイル名から、割り方（テンプレートの段）を決める（テンプレート §3.1 の raw/ の名前）。
///
/// 名前は割り方の名前で始める: `poses-a`（B-2a）・`poses-b`（B-2b）・`walk`（B-3）・`sheet`（B-1）。利用者向けの
/// `poses6`（P6）と `single`（1 枚の絵）も受ける。作り直した絵は `poses-a_2.png` のように後ろに番号を付けてよい。
/// **キャラシートは、立ち姿のある絵（ポーズの格子・1 枚の絵）があれば使わない**（B-1 は参照のための絵。
/// 立ち姿のある絵が無いときだけ、シートの正面を立ち姿にする）。
public enum RawNaming {

    /// ファイル名の頭と割り方。長い名前から比べる（`poses-a` と `poses6` を取り違えない）。
    static let prefixes: [(prefix: String, layout: SheetLayout)] = [
        ("poses-a", .poses4A), ("poses-b", .poses4B), ("poses6", .poses6),
        ("single", .single), ("sheet", .sheet), ("walk", .walk),
    ]
    /// 知らせに出す、名前の決まり。
    static var namingRule: String { prefixes.map(\.prefix).joined(separator: "・") }
    /// 読む絵の拡張子（ImageIO が読める形のうち、生成 AI とほかのアプリが出すもの）。
    static let extensions: Set<String> = ["png", "jpg", "jpeg", "heic", "webp"]
    /// 立ち姿（`.frame(.idle, 0)`）を持つ割り方。これがあればキャラシートは使わない。
    static let standingLayouts: Set<SheetLayout> = [.single, .poses6, .poses4A]

    /// ファイル名から割り方を決める。決まりに合わなければ nil。
    public static func layout(of file: URL) -> SheetLayout? {
        let name = file.deletingPathExtension().lastPathComponent.lowercased()
        return prefixes.first { name.hasPrefix($0.prefix) }?.layout
    }

    /// 整える絵と割り方（`SheetLayout` の順）。名前が決まりに合わない・同じ割り方が 2 枚あれば断る。
    public static func inputs(_ files: [URL]) throws(BakeError) -> [RawInput] {
        var byLayout: [SheetLayout: [URL]] = [:]
        for file in files {
            guard let layout = layout(of: file) else { throw .unknownRawName(file.lastPathComponent) }
            byLayout[layout, default: []].append(file)
        }
        if !standingLayouts.isDisjoint(with: byLayout.keys) { byLayout[.sheet] = nil }
        for layout in SheetLayout.allCases {
            guard let found = byLayout[layout], found.count > 1 else { continue }
            throw .duplicateLayout(layout, found.map(\.lastPathComponent).sorted())
        }
        return SheetLayout.allCases.compactMap { layout in
            byLayout[layout]?.first.map { RawInput(file: $0, layout: layout) }
        }
    }

    /// フォルダの中の絵のファイル（名前の順）。
    public static func images(in folder: URL) -> [URL] {
        let path = folder.path(percentEncoded: false)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
        return names.sorted()
            .map { folder.appending(path: $0) }
            .filter { extensions.contains($0.pathExtension.lowercased()) }
    }
}

/// 整える絵 1 枚と、その割り方。
public struct RawInput: Sendable, Equatable {
    public let file: URL
    public let layout: SheetLayout
}
