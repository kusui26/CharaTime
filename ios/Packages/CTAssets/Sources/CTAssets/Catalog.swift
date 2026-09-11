import Foundation
import CTCore

/// 同梱データの読み出し口。
///
/// `characters.json` と `items.json` は **アプリ・ウィジェット・Python の
/// アセットパイプラインが共有する唯一の出どころ**（プラン §5.3）。
/// 画像を足すときは必ずパイプラインを通し、この 2 つの JSON を書き換えさせる。
public enum Catalog {

    public enum CatalogError: Error, CustomStringConvertible {
        case missingResource(String)
        case malformed(String, underlying: String)

        public var description: String {
            switch self {
            case .missingResource(let name):
                "同梱データが見つかりません: \(name)"
            case .malformed(let name, let underlying):
                "同梱データを読めません: \(name)（\(underlying)）"
            }
        }
    }

    /// 同梱キャラクター。並び順はキャラ選択画面の並び順でもある。
    public static func characters() throws -> [CTCore.Character] {
        try decode(CharacterCatalog.self, from: "characters").characters
    }

    /// 同梱アイテム。
    public static func items() throws -> [ItemDefinition] {
        try decode(ItemCatalog.self, from: "items").items
    }

    /// 読めなければ空を返す版。ウィジェットのように落ちてはいけない場所で使う。
    public static func charactersOrEmpty() -> [CTCore.Character] {
        (try? characters()) ?? []
    }

    private static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw CatalogError.missingResource("\(name).json")
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            throw CatalogError.malformed("\(name).json", underlying: String(describing: error))
        }
    }
}

// MARK: - JSON の形

struct CharacterCatalog: Decodable {
    var schemaVersion: Int
    var characters: [CTCore.Character]
}

struct ItemCatalog: Decodable {
    var schemaVersion: Int
    var items: [ItemDefinition]
}

/// 部屋に置けるものの定義。
public struct ItemDefinition: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var kind: ItemKind
    public var displayName: String
    /// アセット名。画像は tools/pipeline が書き出す。
    public var assetName: String
    /// 床の幅に対する大きさの比。
    public var widthRatio: Double
    /// キャラがこのアイテムを使うときに立つ位置（アイテム中心からの相対、正規化座標）。
    public var anchorOffset: RoomPoint
    /// 天井から吊るすか（ミラーボールのようなもの）。
    public var hangsFromCeiling: Bool

    public init(id: String, kind: ItemKind, displayName: String, assetName: String,
                widthRatio: Double, anchorOffset: RoomPoint, hangsFromCeiling: Bool = false) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.assetName = assetName
        self.widthRatio = widthRatio
        self.anchorOffset = anchorOffset
        self.hangsFromCeiling = hangsFromCeiling
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(String.self, forKey: .id)
        kind = try box.decode(ItemKind.self, forKey: .kind)
        displayName = try box.decode(String.self, forKey: .displayName)
        assetName = try box.decode(String.self, forKey: .assetName)
        widthRatio = try box.decodeIfPresent(Double.self, forKey: .widthRatio) ?? 0.2
        anchorOffset = try box.decodeIfPresent(RoomPoint.self, forKey: .anchorOffset) ?? .zero
        hangsFromCeiling = try box.decodeIfPresent(Bool.self, forKey: .hangsFromCeiling) ?? false
    }
}
