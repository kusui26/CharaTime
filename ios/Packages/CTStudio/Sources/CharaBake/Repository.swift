import Foundation
import CTCore

/// chara-bake が読む所と書く所（プラン §6.4、§9 Phase 2 の 2-C ⑦）。
///
/// リポジトリの根で動かす。読むのは、同梱の `characters.json` と Asset Catalog（いまの絵）と、生の絵（`raw/`）。
/// 書くのは、整えた絵（`assets-src/characters/<id>/final/`。git に入れる）と、確かめのコンタクトシート
/// （`.shots/bake/`。git に入れない）。テストは、書く所だけを一時フォルダにする。
public struct Repository: Sendable {

    /// 同梱のデータのある所（CTAssets の Resources）。
    static let resources = "ios/Packages/CTAssets/Sources/CTAssets/Resources"

    /// 読む所（リポジトリの根）。
    public let root: URL
    /// 書く所。ふだんは `root` と同じ。
    public let output: URL

    public init(root: URL, output: URL? = nil) {
        self.root = root
        self.output = output ?? root
    }

    var charactersJSON: URL { root.appending(path: "\(Self.resources)/characters.json") }
    var characterCatalog: URL { root.appending(path: "\(Self.resources)/Characters.xcassets") }

    /// いまの絵（Asset Catalog の @3x）。
    func bundledImage(_ name: String) -> URL {
        characterCatalog.appending(path: "\(name).imageset/\(name)@3x.png")
    }

    /// そのキャラの生の絵の置き場（git に入れない）。
    func rawFolder(of id: String) -> URL {
        root.appending(path: "assets-src/characters/\(id)/raw")
    }

    /// そのキャラの整えた絵の置き場。
    func finalFolder(of id: String) -> URL {
        output.appending(path: "assets-src/characters/\(id)/final")
    }

    /// 確かめのコンタクトシートの置き場。
    var shots: URL { output.appending(path: ".shots/bake") }

    /// 同梱のキャラと絵の枠（`characters.json`）。
    func bundledCatalog() throws(BakeError) -> BundledCatalog {
        do {
            return try JSONDecoder().decode(BundledCatalog.self, from: Data(contentsOf: charactersJSON))
        } catch {
            throw .unreadable(charactersJSON.lastPathComponent, error.localizedDescription)
        }
    }
}

/// `characters.json` のうち、道具が読むところ。書くのは `tools/pipeline` だけ（ここでは読むだけ）。
struct BundledCatalog: Decodable, Sendable {

    struct Geometry: Decodable, Sendable {
        /// 絵の上端から接地線までの割合（`SpriteGeometry.groundRatio`）。
        let groundRatio: Double
    }

    let characters: [CTCore.Character]
    let spriteGeometry: Geometry

    /// その id の子。無ければ、同梱の id を添えて断る。
    func character(_ id: String) throws(BakeError) -> CTCore.Character {
        guard let found = characters.first(where: { $0.id == id }) else {
            throw .unknownCharacter(id, characters.map(\.id))
        }
        return found
    }
}
