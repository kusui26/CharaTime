import Testing
import Foundation
@testable import CTAssets
import CTCore

/// **JSON が呼ぶ絵が全部そろっているか**（プラン §7.7 の「参照切れ検出」）。
///
/// Asset Catalog は実機向けにビルドするときだけ `Assets.car` に畳まれる。
/// macOS の `swift test` では畳まれず、`.xcassets` がそのままコピーされるので、
/// ここでは **imageset が置かれているか**をファイルとして確かめる。
/// 「絵が画面に出るか」は実機とシミュレータのスクリーンショットで見る。
@Suite("同梱画像の参照")
struct AssetCatalogTests {

    /// パイプラインが焼く倍率。
    static let scales = ["@1x", "@2x", "@3x"]

    static func catalog(_ name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "xcassets")
    }

    /// その名前の imageset が、3 つの倍率ぶんそろっているか。
    static func missingFiles(for name: String, in catalog: URL) -> [String] {
        let imageset = catalog.appending(path: "\(name).imageset")
        guard FileManager.default.fileExists(atPath: imageset.appending(path: "Contents.json").path)
        else { return ["\(name).imageset がありません"] }
        return scales.compactMap { scale in
            let file = imageset.appending(path: "\(name)\(scale).png")
            return FileManager.default.fileExists(atPath: file.path) ? nil : "\(name)\(scale).png"
        }
    }

    @Test("キャラクターのコマが全部そろっている")
    func everyCharacterFrameExists() throws {
        let catalog = try #require(Self.catalog("Characters"),
                                   "Characters.xcassets が同梱されていません")
        let characters = try Catalog.characters()
        #expect(characters.count == 5)
        for character in characters {
            let names = Pose.allCases.flatMap { character.poses[$0] ?? [] }
            #expect(names.count == 11, Comment(rawValue: "\(character.id) は \(names.count) 枚"))
            for name in names {
                let missing = Self.missingFiles(for: name, in: catalog)
                #expect(missing.isEmpty, Comment(rawValue: "\(character.id): \(missing)"))
            }
        }
    }

    /// ウィジェットは mini だけを読む（D-20）。待受モードの絵と姿勢・枚数がそろっていないと、
    /// ウィジェットだけ別のコマを描いたり、足りないコマで待受モードの大きな絵に落ちたりする。
    @Test("ウィジェット用の小さい絵（mini）が、待受モードの絵と同じ並びでそろっている")
    func everyMiniFrameExists() throws {
        let catalog = try #require(Self.catalog("Characters"))
        for character in try Catalog.characters() {
            for pose in Pose.allCases {
                let frames = character.poses[pose] ?? []
                let minis = character.miniPoses[pose] ?? []
                #expect(minis == frames.map { $0 + "_mini" },
                        Comment(rawValue: "\(character.id) の \(pose.rawValue): \(minis)"))
            }
            for name in Pose.allCases.flatMap({ character.miniPoses[$0] ?? [] }) {
                let missing = Self.missingFiles(for: name, in: catalog)
                #expect(missing.isEmpty, Comment(rawValue: "\(character.id): \(missing)"))
            }
        }
    }

    @Test("アイテムの絵が全部そろっている")
    func everyItemImageExists() throws {
        let catalog = try #require(Self.catalog("Items"), "Items.xcassets が同梱されていません")
        let items = try Catalog.items()
        #expect(items.count == 7)
        for item in items {
            let missing = Self.missingFiles(for: item.assetName, in: catalog)
            #expect(missing.isEmpty, Comment(rawValue: "\(item.id): \(missing)"))
            #expect(item.aspectRatio > 0, Comment(rawValue: "\(item.id) の縦横比が入っていない"))
        }
    }

    @Test("キャラの絵の枠が読める")
    func spriteGeometryIsReadable() {
        let geometry = Catalog.spriteGeometry()
        // パイプラインは 130x180 の枠・接地線 y=168 で焼く。
        #expect(abs(geometry.aspectRatio - 130.0 / 180.0) < 0.001)
        #expect(abs(geometry.groundRatio - 168.0 / 180.0) < 0.001)
    }

    /// 余っている imageset は、パイプラインの消し忘れか JSON の書き換え漏れ。
    @Test("JSON から呼ばれていない絵が残っていない")
    func noOrphanImagesets() throws {
        let characters = try Catalog.characters()
        let items = try Catalog.items()
        let expected: [(String, Set<String>)] = [
            ("Characters", Set(characters.flatMap { character in
                Pose.allCases.flatMap { (character.poses[$0] ?? []) + (character.miniPoses[$0] ?? []) }
            })),
            ("Items", Set(items.map(\.assetName)))
        ]
        for (name, used) in expected {
            let catalog = try #require(Self.catalog(name))
            let found = try FileManager.default
                .contentsOfDirectory(atPath: catalog.path)
                .filter { $0.hasSuffix(".imageset") }
                .map { String($0.dropLast(".imageset".count)) }
            #expect(Set(found) == used,
                    Comment(rawValue: "\(name): 余り \(Set(found).subtracting(used).sorted())"))
        }
    }
}
