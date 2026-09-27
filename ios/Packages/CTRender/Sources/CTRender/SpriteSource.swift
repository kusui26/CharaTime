import SwiftUI
import CoreGraphics
import CTCore
import CTStore

/// キャラの絵の出どころ（プラン §9 Phase 2 の 2-C ⑥、D-34）。
///
/// **描く所は 1 か所（`SpriteView`）のまま**、絵をどこから引くかだけを切り替える。同梱のキャラは Asset Catalog の
/// 名前で引き、取り込んだキャラは CTStore が読んだ画像で描く（ファイルを読むのは CTStore、CTRender は描くだけ。
/// 透過背景の `WidgetWallpaper` と同じ作法）。着色・クリアの描き分けは、どちらの絵にも同じに掛ける。
///
/// 日課エンジン（CTCore）は出どころを知らない。見るのは、姿勢ごとの絵の数だけ。
public enum SpriteSource: Sendable {
    /// 同梱の絵。名前で Asset Catalog から引く。
    case catalog
    /// 読み込んだ絵（取り込んだキャラ）。名前で引く。
    case loaded(SpriteImages)
}

/// 読み込んだ絵。名前（`CharacterImageName`）→ 画像。
public struct SpriteImages: Sendable {

    private let images: [String: CGImage]

    public init(_ images: [String: CGImage]) {
        self.images = images
    }

    public subscript(name: String) -> CGImage? { images[name] }

    /// 持っている絵の名前。
    public var names: Set<String> { Set(images.keys) }
}

/// 絵 1 枚の引き先（`SpriteView` が描く）。
enum SpriteArt: Equatable {
    case catalog(String)
    case loaded(CGImage)
    /// 読み込んだ絵に、その名前が無い。何も描かない（落とさない）。
    case missing
}

extension SpriteSource {

    /// 名前の絵の引き先。
    func art(named name: String) -> SpriteArt {
        switch self {
        case .catalog: .catalog(name)
        case .loaded(let images): images[name].map(SpriteArt.loaded) ?? .missing
        }
    }
}

public extension SpriteSource {

    /// そのキャラの、その大きさの絵の出どころ。同梱の子は Asset Catalog。取り込んだ子は、その大きさの絵を
    /// すべてフォルダから読んで持つ（待受モードは 60fps で描くので、hero を一度だけ読み、毎コマ読み直さない。
    /// 12 枚で約 22 MB。2-C ⑥）。**1 枚でも読めなければ nil**（呼び出し側が同梱の先頭に戻る。絵の欠けた子を描かない）。
    static func loading(_ character: CTCore.Character, size: SpriteSize,
                        from store: CharacterStore) -> SpriteSource? {
        guard case .user = character.origin else { return .catalog }
        let maxPixelSize = size.imageKind.pixelSize.longSide
        let names = size.pictureNames(of: character)
        let loaded = names.compactMap { name in
            store.image(name, of: character.id, maxPixelSize: maxPixelSize).map { (name, $0) }
        }
        guard loaded.count == names.count else { return nil }
        return .loaded(SpriteImages(Dictionary(loaded, uniquingKeysWith: { first, _ in first })))
    }
}

extension SpriteSize {

    /// 取り込んだキャラの、その大きさの絵の種類。
    var imageKind: CharacterImageKind {
        switch self {
        case .hero: .hero
        case .mini: .mini
        }
    }

    /// その大きさで描く絵の名前（重なりなし、名前の順）。mini は、まぶたの差分も。
    func pictureNames(of character: CTCore.Character) -> [String] {
        let frames = self == .hero ? character.poses : character.miniPoses
        let eyelids = self == .mini ? Array(character.eyelids.values) : []
        return Set(frames.values.flatMap { $0 } + eyelids).sorted()
    }
}
