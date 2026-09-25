import Foundation

/// ウィジェットの設定。`state.json` の `widget`（プラン §9 Phase 3 の 3-C ⑪）。
///
/// どの項目も、無いとき（3-1 より前の JSON）は「まだ何も選んでいない」として既定で埋める。
/// **1 項目が壊れていても、ほかの項目は生かす。** 壁紙の取り込みや位置合わせは手間がかかるので、
/// ページの型が読めないくらいで、それをやり直させない。
public struct WidgetSettings: Codable, Sendable, Equatable {

    /// 疑似アニメの入／切。**選んでいなければ nil** で、nil は `defaultPseudoAnimation` に従う。
    ///
    /// 選んだ値と「選んでいない」を分けて持つのは、既定を後で入にしたとき（3-2b、Q-15）、
    /// まだ選んでいない人の端末にも届くようにするため。
    public var pseudoAnimation: Bool?

    /// 透過背景の材料にする、壁紙のスクリーンショット（編集モードの空のページ。3-C ⑦）。
    public var wallpaper: AppearanceImages

    /// 位置合わせで決めた、スロットごとの枠と切り抜き。位置合わせをしていないスロットは
    /// 載らず、使う側が iOS 26 の実測の表（3-C ①）で補う（3-3）。
    public var slots: [SlotSetting]

    /// スロットの枠を作ったときの、アプリ名のラベルの有無（3-3）。「表の値に戻す」とき、どちらの表に
    /// 戻すかに使う。透過背景を用意していなければ nil。
    public var iconStyle: SlotGeometry.IconStyle?

    /// ページの型（3-C ⑧）。
    public var pagePreset: PagePreset

    /// 位置合わせの目印をウィジェットに描く期限（3-C ⑦）。nil なら描かない。
    ///
    /// 期限つきにするのは、目印を出したまま取り込みを忘れても、期限を過ぎたエントリから消えるため。
    public var markersUntil: Date?

    /// 疑似アニメの既定。**3-2b で決める**（Q-15: 入と切で丸 1 日ずつ電池を測る）まで切。
    public static let defaultPseudoAnimation = false

    public init(pseudoAnimation: Bool? = nil,
                wallpaper: AppearanceImages = AppearanceImages(),
                slots: [SlotSetting] = [],
                iconStyle: SlotGeometry.IconStyle? = nil,
                pagePreset: PagePreset = .standalone,
                markersUntil: Date? = nil) {
        self.pseudoAnimation = pseudoAnimation
        self.wallpaper = wallpaper
        self.slots = slots
        self.iconStyle = iconStyle
        self.pagePreset = pagePreset
        self.markersUntil = markersUntil
    }

    /// 疑似アニメを使うか。選んでいなければ既定に従う。
    public var usesPseudoAnimation: Bool { pseudoAnimation ?? Self.defaultPseudoAnimation }

    /// 透過背景をやめた設定（壁紙・スロット・ラベルの有無を外す）。ファイルは片づけ
    /// （`ImageStore.removeAll(keeping:)`）が消す。
    public func removingTransparency() -> WidgetSettings {
        var settings = self
        settings.wallpaper = AppearanceImages()
        settings.slots = []
        settings.iconStyle = nil
        return settings
    }

    /// その大きさのウィジェットが使うスロット（3-3）。ページの型は大（上）＋中（下）なので、
    /// 大きさだけで決まる。同じ大きさのスロットが 2 つ以上あれば、先のほうを使う。
    public func slot(for family: WidgetSlot.Family) -> SlotSetting? {
        slots.first { $0.slot.family == family }
    }

    /// 参照している画像の名前（壁紙と切り抜き）。片づけで残す名前に入る（`AppState.referencedImageNames`）。
    var imageNames: [String] {
        wallpaper.names + slots.flatMap(\.crops.names)
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        pseudoAnimation = try? box.decodeIfPresent(Bool.self, forKey: .pseudoAnimation)
        wallpaper = (try? box.decodeIfPresent(AppearanceImages.self, forKey: .wallpaper))
            ?? AppearanceImages()
        // スロットは 1 件ずつ読む。読めない件（知らない大きさなど）だけを捨てる。
        slots = (try? box.decodeIfPresent([Lossy<SlotSetting>].self, forKey: .slots))?
            .compactMap(\.value) ?? []
        iconStyle = try? box.decodeIfPresent(SlotGeometry.IconStyle.self, forKey: .iconStyle)
        pagePreset = (try? box.decodeIfPresent(PagePreset.self, forKey: .pagePreset)) ?? .standalone
        markersUntil = try? box.decodeIfPresent(Date.self, forKey: .markersUntil)
    }
}

/// 外観（ライト・ダーク）ごとの画像の名前（`ImageStore` の名前）。
///
/// ダークの外観では壁紙が約 2 割暗くなるので、透過の材料は外観ごとに 1 枚ずつ要る（3-C ⑦、3-0c）。
public struct AppearanceImages: Codable, Sendable, Equatable {
    public var light: String?
    public var dark: String?

    public init(light: String? = nil, dark: String? = nil) {
        self.light = light
        self.dark = dark
    }

    /// 参照している名前。まだ無いものは除く。
    public var names: [String] { [light, dark].compactMap { $0 } }

    /// その外観の名前。
    public subscript(_ appearance: Appearance) -> String? {
        get { appearance == .light ? light : dark }
        set {
            switch appearance {
            case .light: light = newValue
            case .dark: dark = newValue
            }
        }
    }
}

/// 外観（ライト・ダーク）。透過背景の材料は、外観ごとに 1 枚ずつ要る（3-C ⑦、3-0c）。
public enum Appearance: String, Codable, Sendable, CaseIterable {
    case light
    case dark
}

/// ホーム画面の、ウィジェットを置く場所。
///
/// ウィジェットは、アイコン 2×2 ぶんの升目ごとに置かれる（3-C ①）。列は左から 0・1、
/// 段は上から 0・1・2。中と大は横いっぱいなので列は 0。大は縦に 2 段ぶんなので、段は 0 か 1。
public struct WidgetSlot: Codable, Sendable, Hashable {

    public enum Family: String, Codable, Sendable, CaseIterable {
        case small
        case medium
        case large
    }

    public var family: Family
    public var column: Int
    public var row: Int

    public init(family: Family, column: Int, row: Int) {
        self.family = family
        self.column = column
        self.row = row
    }
}

/// スクリーンショットの上の矩形（画素。原点は左上）。
public struct PixelRect: Codable, Sendable, Hashable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// 位置合わせで決めた、1 つのスロットの枠と、壁紙からの切り抜き（3-C ⑦）。
public struct SlotSetting: Codable, Sendable, Equatable {
    public var slot: WidgetSlot
    /// 壁紙のスクリーンショットの上での、このスロットの枠。
    public var frame: PixelRect
    /// 壁紙をこの枠で切り抜いた画像。ウィジェットは、自分のスロットのこの 1 枚だけを読む
    /// （全体のスクリーンショットは読まない。拡張のメモリ 30 MB への備え）。
    public var crops: AppearanceImages

    public init(slot: WidgetSlot, frame: PixelRect, crops: AppearanceImages = AppearanceImages()) {
        self.slot = slot
        self.frame = frame
        self.crops = crops
    }

    // 切り抜きは、枠と壁紙から作り直せる。無い・壊れているときは空にして、
    // 手間のかかる位置合わせの結果（枠）のほうを生かす。
    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        slot = try box.decode(WidgetSlot.self, forKey: .slot)
        frame = try box.decode(PixelRect.self, forKey: .frame)
        crops = (try? box.decodeIfPresent(AppearanceImages.self, forKey: .crops)) ?? AppearanceImages()
    }
}

/// ページの型（3-C ⑧。どれにするかは Q-14）。
public enum PagePreset: String, Codable, Sendable, CaseIterable {
    /// 各ウィジェットが自分の部屋を持つ。既定。
    case standalone
    /// 大（上）＋ 中（下）の 1 ページで、1 つの部屋。
    case largeOverMedium
    /// 中 × 3 の 1 ページで、1 つの部屋。
    case threeMediums
}

/// 配列の 1 件を読む。読めなければ nil にして、ほかの件を巻き添えにしない。
struct Lossy<Wrapped: Decodable>: Decodable {
    let value: Wrapped?

    init(from decoder: any Decoder) throws {
        value = try? Wrapped(from: decoder)
    }
}
