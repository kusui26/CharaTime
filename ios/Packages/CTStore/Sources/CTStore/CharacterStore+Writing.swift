import Foundation
import CoreGraphics
import CTCore

// 取り込んだキャラの書き（プラン §9 Phase 2 の 2-C ⑤-8）。書くのはアプリだけ。ウィジェットは読むだけ。

public extension CharacterStore {

    /// 取り込んだキャラを置く。
    ///
    /// 一時フォルダ（`.incoming-<id>`）に、絵 → `character.json` の順に書き、最後にフォルダの名前を変えて置く。
    /// 読み手（ウィジェット）は、書きかけのフォルダを見ない。置く前に形と絵のそろいを確かめ（書く側は厳しく）、
    /// 読む側が頼れるフォルダだけを置く。書き終えたら、呼び出し側がウィジェットに作り直しを頼む。
    ///
    /// - `replacing`: 同じ id の子がいれば入れ替える（コマを足す・引っ越しの「置き換える」）。
    ///   偽なら、同じ id の子がいるときは断る（`alreadyExists`）。
    func install(_ package: CharacterPackage, replacing: Bool = false) throws {
        guard let root = folderURL else { throw StoreError.noContainer(appGroup: AppGroup.identifier) }
        let id = package.file.character.id
        if let defect = package.defect { throw StoreError.defective(id: id, defect) }
        try checkRoom(for: id, in: root, replacing: replacing)
        let incoming = root.appendingPathComponent(Self.incomingPrefix + id, isDirectory: true)
        // 途中で失敗したら、書きかけを残さない（置けたときは、名前を変えたので消すものが無い）。
        defer { try? FileManager.default.removeItem(at: incoming) }
        try write(package, into: incoming)
        let target = root.appendingPathComponent(id, isDirectory: true)
        try place(incoming, at: target, id: id, replacing: replacing)
    }

    /// 取り込んだキャラを消す。先にフォルダの名前を変えてから消すので、読み手が消えかけのフォルダを見ない。
    func remove(id: String) throws {
        guard let root = folderURL else { throw StoreError.noContainer(appGroup: AppGroup.identifier) }
        guard CharacterID.isUser(id) else { throw StoreError.invalidID(id) }
        let target = root.appendingPathComponent(id, isDirectory: true)
        guard FileManager.default.fileExists(atPath: target.path) else { throw StoreError.notFound(id: id) }
        let trash = root.appendingPathComponent(Self.removingPrefix + id, isDirectory: true)
        try? FileManager.default.removeItem(at: trash)
        try Self.attempt(id, Self.folderLabel) { try FileManager.default.moveItem(at: target, to: trash) }
        // 消し損ねても、次の片づけ（`removeLeftovers`）で消える。読み手からは、もう見えない。
        try? FileManager.default.removeItem(at: trash)
    }

    /// 書きかけ・消えかけのフォルダを片づける（前に途中で落ちたときの残り）。アプリの起動時に呼ぶ。
    func removeLeftovers() {
        guard let root = folderURL else { return }
        let prefixes = [Self.incomingPrefix, Self.removingPrefix]
        for name in folderNames() where prefixes.contains(where: name.hasPrefix) {
            try? FileManager.default.removeItem(at: root.appendingPathComponent(name, isDirectory: true))
        }
    }

    /// 新しい子の id。いまいる子（読めないフォルダも）と重ならないものを選ぶ。
    ///
    /// 8 桁の乱数が重なる見込みは無いに等しいが、重なれば引き直す（`random` はテストで差し替える）。
    func newID(random: () -> UInt32 = { UInt32.random(in: .min ... .max) }) -> String {
        let taken = Set(folderNames())
        for _ in 0..<Self.idAttempts {
            let candidate = CharacterID.makeUser(random: random())
            if !taken.contains(candidate) { return candidate }
        }
        return CharacterID.makeUser(random: random())
    }
}

extension CharacterStore {

    /// id を引き直す回数の上限。8 桁の乱数が 16 回続けて重なることは無い。無限に引き続けないための柵。
    static let idAttempts = 16
    /// フォルダごと動かすのに失敗したときの、どのファイルか（`writeFailed` の `name`）。
    static let folderLabel = "フォルダ"

    /// 同じ id の子がいれば、置き換えるときだけ通す。新しい子なら、`capacity` 体まで。
    private func checkRoom(for id: String, in root: URL, replacing: Bool) throws {
        guard !FileManager.default.fileExists(atPath: root.appendingPathComponent(id).path) else {
            guard replacing else { throw StoreError.alreadyExists(id: id) }
            return
        }
        guard loadAll().files.count < Self.capacity else { throw StoreError.full(capacity: Self.capacity) }
    }

    /// 一時フォルダに、絵 → `character.json` の順に書く。`character.json` が最後なので、途中で落ちても
    /// 読める形のフォルダは残らない（そもそも一時フォルダは、読み手から見えない）。
    private func write(_ package: CharacterPackage, into folder: URL) throws {
        let id = package.file.character.id
        try? FileManager.default.removeItem(at: folder)             // 前に途中で落ちたときの書きかけ
        for kind in CharacterImageKind.allCases {
            try Self.attempt(id, kind.rawValue) {
                try FileManager.default.createDirectory(at: folder.appendingPathComponent(kind.rawValue),
                                                        withIntermediateDirectories: true)
            }
        }
        for (name, image) in package.images.sorted(by: { $0.key < $1.key }) {
            try Self.attempt(id, name) { try ImageFile.writePNG(image, to: Self.imageURL(name, in: folder)) }
        }
        try Self.attempt(id, Self.fileName) { try Self.writeJSON(package.file, into: folder) }
    }

    /// `character.json` を書く。**ファイルの保護は既定のまま**（初回のロック解除から読める）。
    /// `.complete` にすると、ロック中にウィジェットが描けない（2-C ⑤-8）。
    private static func writeJSON(_ file: CharacterFile, into folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]   // 差分が読める形で残す
        try encoder.encode(file).write(to: folder.appendingPathComponent(fileName), options: [.atomic])
    }

    /// 書き終えた一時フォルダを、名前を変えて置く。置き換えるときは入れ替える（読み手は、入れ替える前か
    /// あとの、どちらかの完全なフォルダだけを見る）。
    private func place(_ incoming: URL, at target: URL, id: String, replacing: Bool) throws {
        try Self.attempt(id, Self.folderLabel) {
            if replacing, FileManager.default.fileExists(atPath: target.path) {
                _ = try FileManager.default.replaceItemAt(target, withItemAt: incoming)
            } else {
                try FileManager.default.moveItem(at: incoming, to: target)
            }
        }
    }

    /// 失敗を、どのキャラのどのファイルかを添えた `writeFailed` にして投げ直す。
    private static func attempt(_ id: String, _ name: String, _ body: () throws -> Void) throws {
        do {
            try body()
        } catch let failure as ImageFile.WriteFailure {
            throw StoreError.writeFailed(id: id, name: name, reason: failure.reason)
        } catch {
            throw StoreError.writeFailed(id: id, name: name, reason: error.localizedDescription)
        }
    }
}
