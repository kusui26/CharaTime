import Foundation
import CTCore

/// キャラの絵の枠。`tools/pipeline` が焼いた PNG の形をそのまま持つ。
///
/// 絵は姿勢ごとに同じ枠で焼いてあり、余白を詰めていない。詰めると姿勢ごとに
/// 原点がずれ、コマを送るたびにキャラが跳ねて見えるため。
public struct SpriteGeometry: Codable, Sendable, Equatable {
    /// 絵の縦横比（幅 ÷ 高さ）。
    public var aspectRatio: Double
    /// 絵の上端から接地線までの割合。**足元を床に合わせるのに使う。**
    public var groundRatio: Double

    public init(aspectRatio: Double, groundRatio: Double) {
        self.aspectRatio = aspectRatio
        self.groundRatio = groundRatio
    }

    /// JSON に書かれていないときの値（パイプラインの既定と同じ）。
    public static let fallback = SpriteGeometry(aspectRatio: 0.7222, groundRatio: 0.9333)
}

/// 画像が入っているバンドル。
///
/// `Bundle.module` はターゲットの中からしか見えないので、絵を描く CTRender に
/// 渡せるようにここで公開する。
public enum AssetBundle {
    public static let value = Bundle.module
}

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

    /// 読めなければ空を返す版。
    public static func itemsOrEmpty() -> [ItemDefinition] {
        (try? items()) ?? []
    }

    /// キャラの絵の枠。読めなければ既定値を返す（ウィジェットで落とさないため）。
    public static func spriteGeometry() -> SpriteGeometry {
        (try? decode(CharacterCatalog.self, from: "characters").spriteGeometry)
            ?? .fallback
    }

    /// 読めなければ空を返す版。ウィジェットのように落ちてはいけない場所で使う。
    public static func charactersOrEmpty() -> [CTCore.Character] {
        (try? characters()) ?? []
    }

    /// 疑似アニメのマスク書体の一覧（`tools/pipeline/masks.py` が書く `mask_fonts.json`）。
    ///
    /// 書体そのものはアプリとウィジェット拡張の `UIAppFonts` で登録する（パッケージの中の書体は
    /// 登録できない）。ここにあるのは、どの名前の書体があるはずか、だけ。
    public static func maskFonts() throws -> [MaskFontEntry] {
        try decode(MaskFontCatalog.self, from: "mask_fonts").fonts
    }

    /// 読めなければ空を返す版。
    public static func maskFontsOrEmpty() -> [MaskFontEntry] {
        (try? maskFonts()) ?? []
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
    var spriteGeometry: SpriteGeometry?
}

struct ItemCatalog: Decodable {
    var schemaVersion: Int
    var items: [ItemDefinition]
}

struct MaskFontCatalog: Decodable {
    var fonts: [MaskFontEntry]
}

/// マスク書体 1 本。`digits` に入る数字だけが 1em の塗りつぶしで、ほかは空（3-C ④ 原則 3）。
public struct MaskFontEntry: Decodable, Sendable, Equatable {
    /// 書体の名前（PostScript 名）。`CTMask05` の形。
    public var name: String
    public var digits: [Int]

    public init(name: String, digits: [Int]) {
        self.name = name
        self.digits = digits
    }
}

/// 部屋に置けるものの定義。
public struct ItemDefinition: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var kind: ItemKind
    public var displayName: String
    /// アセット名。画像は tools/pipeline が書き出す。
    public var assetName: String
    /// 絵の縦横比（幅 ÷ 高さ）。アプリは幅だけを決めて置くので、高さをこれで出す。
    public var aspectRatio: Double
    /// 床の幅に対する大きさの比。
    public var widthRatio: Double
    /// キャラがこのアイテムを使うときに立つ位置（アイテム中心からの相対、正規化座標）。
    public var anchorOffset: RoomPoint
    /// 天井から吊るすか（ミラーボールのようなもの）。
    public var hangsFromCeiling: Bool

    public init(id: String, kind: ItemKind, displayName: String, assetName: String,
                widthRatio: Double, anchorOffset: RoomPoint, aspectRatio: Double = 1,
                hangsFromCeiling: Bool = false) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.assetName = assetName
        self.widthRatio = widthRatio
        self.anchorOffset = anchorOffset
        self.aspectRatio = aspectRatio
        self.hangsFromCeiling = hangsFromCeiling
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(String.self, forKey: .id)
        kind = try box.decode(ItemKind.self, forKey: .kind)
        displayName = try box.decode(String.self, forKey: .displayName)
        assetName = try box.decode(String.self, forKey: .assetName)
        widthRatio = try box.decodeIfPresent(Double.self, forKey: .widthRatio) ?? 0.2
        aspectRatio = try box.decodeIfPresent(Double.self, forKey: .aspectRatio) ?? 1
        anchorOffset = try box.decodeIfPresent(RoomPoint.self, forKey: .anchorOffset) ?? .zero
        hangsFromCeiling = try box.decodeIfPresent(Bool.self, forKey: .hangsFromCeiling) ?? false
    }
}
