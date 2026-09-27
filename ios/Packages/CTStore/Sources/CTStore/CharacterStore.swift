import Foundation
import CoreGraphics
import CTCore

/// 取り込んだキャラの置き場（プラン §9 Phase 2 の 2-C ③⑤-8⑥⑪）。App Group の `characters/<id>/`。
///
/// ```
/// characters/user-3f9a2c1b/
/// ├─ character.json      `CharacterFile`（Character ＋ 取り込みの記録）
/// ├─ hero/idle_01.png …  待受用（@3x、585×810）
/// └─ mini/idle_01.png …  ウィジェット用（@3x、273×378）。まぶたの差分 idle_eyelid.png も
/// ```
///
/// **読みは落ちない。** 壊れた・書きかけ・消えかけのフォルダは、そのキャラだけを読み飛ばし、ほかの子と
/// 既定の 5 体を生かす（ウィジェット拡張は、落ちると更新まで止まる。CLAUDE.md §2）。書きは、どのキャラの
/// どのファイルで失敗したかを添えて投げる（利用者が連れてきた子なので、黙って捨てない）。
///
/// 部屋と壁紙の画像（`ImageStore` の `images/`）とは別のフォルダ。その片づけに巻き込まれない。
public struct CharacterStore: Sendable {

    public enum StoreError: Error, Sendable, Equatable, CustomStringConvertible {
        /// 置き場が無い。どの App Group を探して届かなかったかを添える。
        case noContainer(appGroup: String)
        /// そのキャラのフォルダか `character.json` が無い。
        case notFound(id: String)
        /// `character.json` を読めない（壊れている・大きすぎる）。
        case unreadable(id: String, reason: String)
        /// 形に問題がある。
        case defective(id: String, CharacterDefect)
        /// 同じ id の子がもういる（置き換えるときは `replacing` を付ける）。
        case alreadyExists(id: String)
        /// 取り込めるのは `capacity` 体まで。どれかを消すと、新しい子を連れてこられる。
        case full(capacity: Int)
        /// 書けなかった。
        case writeFailed(id: String, name: String, reason: String)

        /// id の形が違う（`user-` で始まらない・使えない字がある）。
        static func invalidID(_ id: String) -> StoreError {
            .defective(id: id, CharacterDefect(.invalidID, id))
        }

        public var description: String {
            switch self {
            case .noContainer(let appGroup):
                "キャラを置けません（App Group \(appGroup) が未設定か、entitlements に入っていません）"
            case .notFound(let id): "\(id) が見つかりません"
            case .unreadable(let id, let reason): "\(id) の character.json を読めません（\(reason)）"
            case .defective(let id, let defect): "\(id): \(defect)"
            case .alreadyExists(let id): "\(id) はもういます"
            case .full(let capacity): "取り込めるのは \(capacity) 体までです"
            case .writeFailed(let id, let name, let reason): "\(id) の \(name) を書けませんでした（\(reason)）"
            }
        }
    }

    public static let folderName = "characters"
    public static let fileName = "character.json"
    /// 取り込めるキャラの数（Q-19）。1 体およそ 2〜3 MB なので、合わせて 20〜30 MB。
    public static let capacity = 10
    /// `character.json` の大きさの上限。1 体の定義は 3 KB ほど。壊れて膨らんだファイルを、
    /// ウィジェット拡張（メモリ約 30 MB）で丸ごと読まない。
    static let maxFileBytes = 64 * 1024
    /// 書きかけ（置く前）と、消えかけ（消す前）のフォルダの頭。読み手は `.` で始まるものを見ない。
    static let incomingPrefix = ".incoming-"
    static let removingPrefix = ".removing-"

    /// 置き場のある場所（App Group の共有コンテナ）。テストではテンポラリを渡す。
    public let directory: URL?

    public init(directory: URL?) {
        self.directory = directory
    }

    /// App Group の共有コンテナを使う既定の置き場。
    public static var shared: CharacterStore { CharacterStore(directory: AppGroup.containerURL) }

    public var folderURL: URL? {
        directory?.appendingPathComponent(Self.folderName, isDirectory: true)
    }

    // MARK: - 読み（落ちない）

    /// そのキャラの `character.json` を読んで確かめる（形と、絵のファイルがそろっているか）。
    ///
    /// **フォルダの一覧は取らない。** ウィジェットは、選んだ子のこれだけを読む（2-C ⑥）。
    public func read(id: String) -> Result<CharacterFile, StoreError> {
        guard let root = folderURL else { return .failure(.noContainer(appGroup: AppGroup.identifier)) }
        guard CharacterID.isUser(id) else { return .failure(.invalidID(id)) }
        let folder = root.appendingPathComponent(id, isDirectory: true)
        return decodeFile(in: folder, id: id).flatMap { file in
            fileDefect(file, in: folder, id: id).map { .failure(.defective(id: id, $0)) } ?? .success(file)
        }
    }

    /// 読めればそのキャラ、読めなければ nil（ウィジェット向け。理由は `read(id:)` で分かる）。
    public func load(id: String) -> CharacterFile? {
        try? read(id: id).get()
    }

    /// 取り込んだキャラの一覧（キャラを選ぶ画面。2-C ⑧）。読めないフォルダは読み飛ばし、理由を添えて返す。
    public func loadAll() -> CharacterShelf {
        // 書きかけ・消えかけ（`.incoming-`・`.removing-`）と、隠しファイルは見ない。
        let ids = folderNames().filter { !$0.hasPrefix(".") }.sorted()
        return CharacterShelf(results: ids.map(read(id:)))
    }

    /// 絵のファイルの場所。id と名前の形が正しくなければ nil（フォルダの外を指させない）。
    public func imageURL(_ name: String, of id: String) -> URL? {
        guard let root = folderURL, CharacterID.isUser(id),
              CharacterImageKind.allCases.contains(where: { CharacterImageName.isValid(name, kind: $0) })
        else { return nil }
        return Self.imageURL(name, in: root.appendingPathComponent(id, isDirectory: true))
    }

    /// 絵を読み、展開して持つ。長辺が `maxPixelSize` を超える絵は縮めて読む（壊れて大きくなった絵で、
    /// メモリを使い切らない）。読めなければ nil（ウィジェットを落とさない）。
    public func image(_ name: String, of id: String, maxPixelSize: Int) -> CGImage? {
        imageURL(name, of: id).flatMap { ImageFile.read(at: $0, fittingIn: maxPixelSize) }
    }

    static func imageURL(_ name: String, in folder: URL) -> URL {
        folder.appendingPathComponent(name + ".png")
    }

    /// 置き場の中の名前（フォルダも、書きかけも）。置き場が無ければ空。
    func folderNames() -> [String] {
        folderURL.flatMap { try? FileManager.default.contentsOfDirectory(atPath: $0.path) } ?? []
    }

    // MARK: - 読みの道具

    private func decodeFile(in folder: URL, id: String) -> Result<CharacterFile, StoreError> {
        let url = folder.appendingPathComponent(Self.fileName)
        guard let bytes = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return .failure(.notFound(id: id))
        }
        guard bytes <= Self.maxFileBytes else {
            return .failure(.unreadable(id: id, reason: "\(bytes) バイト（上限 \(Self.maxFileBytes) バイト）"))
        }
        do {
            return .success(try JSONDecoder().decode(CharacterFile.self, from: Data(contentsOf: url)))
        } catch {
            return .failure(.unreadable(id: id, reason: String(describing: error)))
        }
    }

    /// 読んだ定義の問題。版・フォルダの名前・形・絵のファイルの順に見る。
    private func fileDefect(_ file: CharacterFile, in folder: URL, id: String) -> CharacterDefect? {
        // 新しいアプリが書いた定義は、解釈できない項目を握ったまま描くより、既定のキャラで描くほうが安全。
        guard file.schemaVersion <= CharacterFile.currentSchemaVersion else {
            return CharacterDefect(.futureSchema, "版 \(file.schemaVersion)")
        }
        guard file.character.id == id else { return CharacterDefect(.mismatchedID, file.character.id) }
        return CharacterCheck.defect(in: file.character) ?? missingImage(of: file.character, in: folder)
    }

    private func missingImage(of character: CTCore.Character, in folder: URL) -> CharacterDefect? {
        let missing = CharacterCheck.referencedImages(of: character).first {
            !FileManager.default.fileExists(atPath: Self.imageURL($0.name, in: folder).path)
        }
        return missing.map { CharacterDefect(.missingImage, $0.name) }
    }
}

/// 取り込んだキャラの一覧を読んだ結果（`CharacterStore.loadAll`）。
public struct CharacterShelf: Sendable, Equatable {

    /// 読めたキャラ。連れてきた順（同じ日時なら id の順）。
    public let files: [CharacterFile]
    /// 読めなかったフォルダと、その理由。**フォルダは消さない**（利用者の子なので、黙って捨てない）。
    public let skipped: [CharacterStore.StoreError]

    public init(files: [CharacterFile] = [], skipped: [CharacterStore.StoreError] = []) {
        self.files = files
        self.skipped = skipped
    }

    init(results: [Result<CharacterFile, CharacterStore.StoreError>]) {
        let files = results.compactMap { try? $0.get() }
        let skipped = results.compactMap { result -> CharacterStore.StoreError? in
            if case .failure(let error) = result { return error }
            return nil
        }
        self.init(files: files.sorted(by: Self.arrivalOrder), skipped: skipped)
    }

    /// 読めたキャラ（連れてきた順）。
    public var characters: [CTCore.Character] { files.map(\.character) }

    private static func arrivalOrder(_ lhs: CharacterFile, _ rhs: CharacterFile) -> Bool {
        (arrival(of: lhs), lhs.character.id) < (arrival(of: rhs), rhs.character.id)
    }

    private static func arrival(of file: CharacterFile) -> Date {
        if case .user(let createdAt) = file.character.origin { return createdAt }
        return .distantPast
    }
}
