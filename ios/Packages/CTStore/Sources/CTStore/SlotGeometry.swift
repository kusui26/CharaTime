import Foundation
import CoreGraphics

/// ホーム画面のウィジェットの枠（プラン §9 Phase 3 の 3-C ①⑦、3-3）。iOS 26 の実測の表。
///
/// 402×874pt の iPhone（17 / 17 Pro）で、シミュレータ（iOS 26.5）で測り、実機（26.1）でも同じ位置と
/// 確かめた。**画素（@3x）で持つ。** ポイントの表（26.33pt など）は小数 2 桁に丸めてあり、画素に直すと
/// 1 画素ずれうるため。表の無い機種では透過背景を作らない（位置が分からない枠で切り抜くと継ぎ目がずれる）。
public struct SlotGeometry: Sendable, Equatable {

    /// アプリ名のラベルの有無。「大きいアプリアイコン」にするとラベルが消え、ウィジェットの大きさも位置も変わる。
    public enum IconStyle: String, Codable, Sendable, CaseIterable {
        case labeled
        case labelFree
    }

    /// 1 つのアイコンの大きさでの、列と段の位置と、大きさごとの枠の大きさ（画素）。
    struct Grid: Sendable, Equatable {
        /// 列の左端（x）。左から 0・1。
        var columns: [Int]
        /// 段の上端（y）。上から 0・1・2（アイコン 2 段ぶんごと）。
        var rows: [Int]
        var small: PixelSize
        var medium: PixelSize
        var large: PixelSize

        func size(of family: WidgetSlot.Family) -> PixelSize {
            switch family {
            case .small: small
            case .medium: medium
            case .large: large
            }
        }
    }

    /// スクショの画素の数（縦向き）。
    public let pixelWidth: Int
    public let pixelHeight: Int
    /// 画面の倍率（@3x なら 3）。ウィジェットの大きさ（pt）と見比べるのに使う。
    public let scale: Double
    let labeled: Grid
    let labelFree: Grid

    /// 402×874pt・@3x の iPhone（17 / 17 Pro）。3-C ① の表を画素にしたもの。
    public static let iPhone402x874 = SlotGeometry(
        pixelWidth: 1206, pixelHeight: 2622, scale: 3,
        labeled: Grid(columns: [79, 635], rows: [270, 872, 1474],
                      small: PixelSize(width: 493, height: 493),
                      medium: PixelSize(width: 1049, height: 493),
                      large: PixelSize(width: 1049, height: 1095)),
        labelFree: Grid(columns: [64, 634], rows: [270, 838, 1406],
                        small: PixelSize(width: 509, height: 509),
                        medium: PixelSize(width: 1079, height: 509),
                        large: PixelSize(width: 1079, height: 1077)))

    /// 表のある画面。
    static let known: [SlotGeometry] = [iPhone402x874]

    /// ページの型「大（上）＋中（下）」のスロット（Q-14）。大は 1〜2 段目、中は 3 段目。
    public static let largeOverMedium: [WidgetSlot] = [
        WidgetSlot(family: .large, column: 0, row: 0),
        WidgetSlot(family: .medium, column: 0, row: 2),
    ]

    /// 縦向きのスクショの画素の数から、その画面の表を選ぶ。表が無ければ nil。
    public static func screen(pixelWidth: Int, pixelHeight: Int) -> SlotGeometry? {
        known.first { $0.pixelWidth == pixelWidth && $0.pixelHeight == pixelHeight }
    }

    /// スロットの枠（画素）。そこに置けないスロットなら nil。
    ///
    /// 中と大は横いっぱいなので 1 列目だけ。大は縦に 2 段ぶんなので、最後の段からは置けない。
    public func frame(of slot: WidgetSlot, style: IconStyle) -> PixelRect? {
        let grid = self.grid(style)
        let lastStartRow = slot.family == .large ? grid.rows.count - 2 : grid.rows.count - 1
        let lastColumn = slot.family == .small ? grid.columns.count - 1 : 0
        guard (0...lastColumn).contains(slot.column), (0...lastStartRow).contains(slot.row) else {
            return nil
        }
        let size = grid.size(of: slot.family)
        return PixelRect(x: grid.columns[slot.column], y: grid.rows[slot.row],
                         width: size.width, height: size.height)
    }

    /// ウィジェットの大きさ（pt。ウィジェットが自分で知っている `displaySize`）から、ラベルの有無を読む。
    /// どちらの表とも合わなければ nil。
    public func iconStyle(of family: WidgetSlot.Family, size: CGSize) -> IconStyle? {
        IconStyle.allCases.first { style in
            let expected = grid(style).size(of: family)
            return abs(Double(size.width) * scale - Double(expected.width)) <= Self.sizeTolerancePixels
                && abs(Double(size.height) * scale - Double(expected.height)) <= Self.sizeTolerancePixels
        }
    }

    /// 大きさを見比べるときの許す差（画素）。pt の値は小数 2 桁に丸めてあるので、1 画素まではずれうる。
    static let sizeTolerancePixels: Double = 1.5

    private func grid(_ style: IconStyle) -> Grid {
        style == .labeled ? labeled : labelFree
    }
}

/// 画素で数えた大きさ。
struct PixelSize: Sendable, Equatable {
    var width: Int
    var height: Int
}

/// 枠を寄せる量（画素）。右と下が正。
public struct PixelOffset: Codable, Sendable, Hashable {
    public var dx: Int
    public var dy: Int

    public init(dx: Int, dy: Int) {
        self.dx = dx
        self.dy = dy
    }

    public static let zero = PixelOffset(dx: 0, dy: 0)
}

public extension PixelRect {

    /// 寄せた枠。大きさは変えない。
    func offset(by offset: PixelOffset) -> PixelRect {
        PixelRect(x: x + offset.dx, y: y + offset.dy, width: width, height: height)
    }

    /// スクショ（`width` × `height`）の内側に収めた枠。はみ出す分だけ内へ戻す。
    func clamped(width screenWidth: Int, height screenHeight: Int) -> PixelRect {
        PixelRect(x: Swift.min(Swift.max(x, 0), Swift.max(screenWidth - width, 0)),
                  y: Swift.min(Swift.max(y, 0), Swift.max(screenHeight - height, 0)),
                  width: width, height: height)
    }

    /// CoreGraphics の矩形（画素）。
    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}
