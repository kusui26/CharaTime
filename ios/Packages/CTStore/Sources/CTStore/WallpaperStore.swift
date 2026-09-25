import Foundation
import CoreGraphics

/// 透過背景の材料（壁紙のスクショ）の取り込みと切り抜き（プラン §9 Phase 3 の 3-C ⑦、3-3）。
///
/// 取り込んだスクショは縮めずに置き、ページの型（大（上）＋中（下））のスロットごとに、枠で切り抜いて置く。
/// **枠を変えたら、ライトもダークも切り抜き直す**（外観で枠が食い違うと、切り替えたときにずれる）。
/// ウィジェットは自分のスロットの切り抜きだけを読む。スクショ全体は読まない（拡張のメモリ 30 MB への備え）。
/// 名前には `stamp`（取り込んだ時刻など）を付け、作り直すたびに別のファイルにする。古いファイルは、
/// 設定を保存したあとの片づけ（`ImageStore.removeAll(keeping:)`）が消す。
public struct WallpaperStore: Sendable {

    public enum ImportError: Error, Sendable, Equatable, CustomStringConvertible {
        case notAnImage
        /// 表の無い大きさ（別の機種のスクショ・横向き・写真など）。
        case unknownScreen(width: Int, height: Int)
        case cropFailed(slot: WidgetSlot)
        case noContainer
        case writeFailed(name: String, reason: String)

        public var description: String {
            switch self {
            case .notAnImage:
                "画像として読めませんでした"
            case .unknownScreen(let width, let height):
                "\(width)×\(height) の画像は使えません（この iPhone の画面のスクショ・縦向き・1206×2622 が要ります）"
            case .cropFailed(let slot):
                "\(slot.family.rawValue) の枠で切り抜けませんでした"
            case .noContainer:
                "画像を置けません（App Group が未設定です）"
            case .writeFailed(let name, let reason):
                "\(name) を書けませんでした（\(reason)）"
            }
        }
    }

    public let images: ImageStore

    public init(images: ImageStore) {
        self.images = images
    }

    /// App Group の共有コンテナを使う既定の置き場。
    public static var shared: WallpaperStore { WallpaperStore(images: .shared) }

    /// 壁紙のスクショを取り込む。枠は、同じラベルの有無で作ってあればそれを使い（手で寄せた分を保つ）、
    /// 無ければ表から作る。取り込んだ外観だけでなく、保存してあるほうの外観も同じ枠で切り抜き直す。
    public func importScreenshot(_ data: Data, as appearance: Appearance, style: SlotGeometry.IconStyle,
                                 into settings: WidgetSettings, stamp: String) throws -> WidgetSettings {
        let image = try decode(data)
        guard let geometry = SlotGeometry.screen(pixelWidth: image.width, pixelHeight: image.height) else {
            throw ImportError.unknownScreen(width: image.width, height: image.height)
        }
        let name = "wallpaper-\(appearance.rawValue)-\(stamp)"
        try write(image, as: name)
        var updated = settings
        updated.wallpaper[appearance] = name
        let frames = settings.iconStyle == style
            ? currentFrames(settings, geometry: geometry, style: style)
            : tableFrames(geometry: geometry, style: style)
        return try cropAll(updated, frames: frames, style: style, stamp: stamp)
    }

    /// スロットの枠を寄せて、切り抜き直す。寄せないスロットはそのまま。スクショの外へは出さない。
    public func recrop(_ settings: WidgetSettings, nudging offsets: [WidgetSlot: PixelOffset],
                       stamp: String) throws -> WidgetSettings {
        guard let style = settings.iconStyle, let geometry = geometry(of: settings) else { return settings }
        let frames = currentFrames(settings, geometry: geometry, style: style).map { item in
            guard let offset = offsets[item.slot] else { return item }
            let moved = item.frame.offset(by: offset)
                .clamped(width: geometry.pixelWidth, height: geometry.pixelHeight)
            return (slot: item.slot, frame: moved)
        }
        return try cropAll(settings, frames: frames, style: style, stamp: stamp)
    }

    /// ラベルの有無の表で枠を作り直し、切り抜き直す。寄せた分は捨てる（「表の値に戻す」もこれ）。
    public func recrop(_ settings: WidgetSettings, style: SlotGeometry.IconStyle,
                       stamp: String) throws -> WidgetSettings {
        guard let geometry = geometry(of: settings) else { return settings }
        return try cropAll(settings, frames: tableFrames(geometry: geometry, style: style), style: style,
                           stamp: stamp)
    }

    // MARK: - 枠

    private typealias SlotFrame = (slot: WidgetSlot, frame: PixelRect)

    /// 表の枠（ページの型のスロットの順）。
    private func tableFrames(geometry: SlotGeometry, style: SlotGeometry.IconStyle) -> [SlotFrame] {
        SlotGeometry.largeOverMedium.compactMap { slot in
            geometry.frame(of: slot, style: style).map { (slot: slot, frame: $0) }
        }
    }

    /// いまの枠。まだ無いスロットは表で補う。
    private func currentFrames(_ settings: WidgetSettings, geometry: SlotGeometry,
                               style: SlotGeometry.IconStyle) -> [SlotFrame] {
        tableFrames(geometry: geometry, style: style).map { item in
            let saved = settings.slots.first { $0.slot == item.slot }?.frame
            return (slot: item.slot, frame: saved ?? item.frame)
        }
    }

    /// 保存してある壁紙の大きさから、画面の表を選ぶ。
    private func geometry(of settings: WidgetSettings) -> SlotGeometry? {
        settings.wallpaper.names.lazy.compactMap(images.load)
            .compactMap { SlotGeometry.screen(pixelWidth: $0.width, pixelHeight: $0.height) }
            .first
    }

    // MARK: - 切り抜き

    /// 保存してある壁紙（外観ごと）を、スロットごとに切り抜いて置く。読めない外観は切り抜かない。
    private func cropAll(_ settings: WidgetSettings, frames: [SlotFrame], style: SlotGeometry.IconStyle,
                         stamp: String) throws -> WidgetSettings {
        let wallpapers = Appearance.allCases.compactMap { appearance in
            settings.wallpaper[appearance].flatMap(images.load).map { (appearance: appearance, image: $0) }
        }
        var updated = settings
        updated.slots = try frames.map { item in
            let crops = try wallpapers.reduce(into: AppearanceImages()) { crops, wallpaper in
                crops[wallpaper.appearance] = try crop(wallpaper.image, to: item.frame, slot: item.slot,
                                                       appearance: wallpaper.appearance, stamp: stamp)
            }
            return SlotSetting(slot: item.slot, frame: item.frame, crops: crops)
        }
        updated.iconStyle = style
        return updated
    }

    private func crop(_ wallpaper: CGImage, to frame: PixelRect, slot: WidgetSlot, appearance: Appearance,
                      stamp: String) throws -> String {
        guard let image = wallpaper.cropping(to: frame.cgRect),
              image.width == frame.width, image.height == frame.height else {
            throw ImportError.cropFailed(slot: slot)
        }
        let name = "crop-\(slot.family.rawValue)-\(slot.column)-\(slot.row)-\(appearance.rawValue)-\(stamp)"
        try write(image, as: name)
        return name
    }

    // MARK: - 読み書き

    private func decode(_ data: Data) throws -> CGImage {
        do {
            return try ImageStore.decodeExact(data)
        } catch {
            throw ImportError.notAnImage
        }
    }

    private func write(_ image: CGImage, as name: String) throws {
        do {
            try images.storeExact(image, as: name)
        } catch ImageStore.StoreError.noContainer {
            throw ImportError.noContainer
        } catch {
            throw ImportError.writeFailed(name: name, reason: String(describing: error))
        }
    }
}
