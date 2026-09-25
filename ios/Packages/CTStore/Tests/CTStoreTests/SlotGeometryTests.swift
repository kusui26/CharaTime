import Testing
import Foundation
import CoreGraphics
@testable import CTStore

/// ホーム画面のウィジェットの枠（プラン §9 Phase 3 の 3-C ①⑦、3-3）。
@Suite("ウィジェットの枠")
struct SlotGeometryTests {

    static let screen = SlotGeometry.iPhone402x874
    static let large = WidgetSlot(family: .large, column: 0, row: 0)
    static let medium = WidgetSlot(family: .medium, column: 0, row: 2)

    /// 3-C ① の実測（画素）: 列 x = 79 / 635、段 y = 270 / 872 / 1474。大 1049×1095、中 1049×493。
    @Test("ラベルありの枠は、iOS 26 の実測の表のとおり")
    func labeledFrames() throws {
        #expect(Self.screen.frame(of: Self.large, style: .labeled)
                == PixelRect(x: 79, y: 270, width: 1049, height: 1095))
        #expect(Self.screen.frame(of: Self.medium, style: .labeled)
                == PixelRect(x: 79, y: 1474, width: 1049, height: 493))
        let small = WidgetSlot(family: .small, column: 1, row: 1)
        #expect(Self.screen.frame(of: small, style: .labeled) == PixelRect(x: 635, y: 872, width: 493, height: 493))
    }

    /// 大きいアプリアイコン（ラベルなし）: 列 x = 64 / 634、段 y = 270 / 838 / 1406。大 1079×1077、中 1079×509。
    @Test("ラベルなしの枠は、別の表（大きさも位置も違う）")
    func labelFreeFrames() {
        #expect(Self.screen.frame(of: Self.large, style: .labelFree)
                == PixelRect(x: 64, y: 270, width: 1079, height: 1077))
        #expect(Self.screen.frame(of: Self.medium, style: .labelFree)
                == PixelRect(x: 64, y: 1406, width: 1079, height: 509))
    }

    /// 大は縦に 2 段ぶんなので、3 段目からは置けない。中と大は横いっぱいなので、2 列目には置けない。
    @Test("置けない場所の枠は nil")
    func impossibleSlots() {
        #expect(Self.screen.frame(of: WidgetSlot(family: .large, column: 0, row: 2), style: .labeled) == nil)
        #expect(Self.screen.frame(of: WidgetSlot(family: .medium, column: 1, row: 0), style: .labeled) == nil)
        #expect(Self.screen.frame(of: WidgetSlot(family: .small, column: 2, row: 0), style: .labeled) == nil)
        #expect(Self.screen.frame(of: WidgetSlot(family: .small, column: 0, row: -1), style: .labeled) == nil)
    }

    /// 基本の置き方は、大を 1 つ、ページのいちばん上に（D-31）。透過背景はこの枠で切り抜く。
    @Test("透過背景を敷くのは、ページのいちばん上（1 段目）の大")
    func largeAtTheTop() {
        #expect(SlotGeometry.largeAtTop == Self.large)
        #expect(Self.screen.frame(of: SlotGeometry.largeAtTop, style: .labeled)
                == PixelRect(x: 79, y: 270, width: 1049, height: 1095))
    }

    @Test("表があるのは、1206×2622 画素（402×874pt の @3x）の画面だけ")
    func knownScreens() {
        #expect(SlotGeometry.screen(pixelWidth: 1206, pixelHeight: 2622) == Self.screen)
        #expect(SlotGeometry.screen(pixelWidth: 2622, pixelHeight: 1206) == nil)    // 横向き
        #expect(SlotGeometry.screen(pixelWidth: 1179, pixelHeight: 2556) == nil)    // 393×852pt の機種
    }

    // MARK: - 手で寄せる

    @Test("寄せた量だけ枠が動き、大きさは変わらない")
    func nudging() {
        let frame = PixelRect(x: 79, y: 270, width: 1049, height: 1095)
        #expect(frame.offset(by: PixelOffset(dx: 2, dy: -1)) == PixelRect(x: 81, y: 269, width: 1049, height: 1095))
        #expect(frame.offset(by: .zero) == frame)
    }

    /// 端まで寄せても、スクショの外を切り抜こうとしない。
    @Test("枠はスクショの内側に収める")
    func clampsIntoTheScreenshot() {
        let frame = PixelRect(x: 79, y: 270, width: 1049, height: 1095)
        #expect(frame.offset(by: PixelOffset(dx: -100, dy: -300)).clamped(width: 1206, height: 2622)
                == PixelRect(x: 0, y: 0, width: 1049, height: 1095))
        #expect(frame.offset(by: PixelOffset(dx: 500, dy: 2000)).clamped(width: 1206, height: 2622)
                == PixelRect(x: 157, y: 1527, width: 1049, height: 1095))
    }

    // MARK: - ラベルの有無を見分ける

    /// ウィジェットは自分の大きさを知っている（`context.displaySize`）。それで表を選べる。
    @Test("ウィジェットの大きさ（pt）から、ラベルの有無が分かる。知らない大きさなら nil")
    func iconStyleFromTheWidgetSize() {
        #expect(Self.screen.iconStyle(of: .large, size: CGSize(width: 349.67, height: 365)) == .labeled)
        #expect(Self.screen.iconStyle(of: .large, size: CGSize(width: 359.666, height: 359)) == .labelFree)
        #expect(Self.screen.iconStyle(of: .medium, size: CGSize(width: 349.67, height: 164.33)) == .labeled)
        #expect(Self.screen.iconStyle(of: .medium, size: CGSize(width: 359.67, height: 169.67)) == .labelFree)
        #expect(Self.screen.iconStyle(of: .large, size: CGSize(width: 344, height: 366)) == nil)
        #expect(Self.screen.iconStyle(of: .large, size: CGSize(width: 349.67, height: 164.33)) == nil)
    }

    static func reload(_ family: WidgetSlot.Family, size: CGSize?) -> WidgetReload {
        WidgetReload(date: Date(timeIntervalSince1970: 0), family: family, entryCount: 73,
                     footprintBytes: 1, peakBytes: 1, pseudoAnimation: false, displaySize: size)
    }

    static func reading(_ reloads: [WidgetReload]) -> SlotGeometry.IconStyleReading {
        screen.iconStyleReading(from: WidgetDiagnostics(reloads: reloads))
    }

    /// 置き方のガイドの「いまの様子」（3-4）と透過背景の画面が使う。まだ置いていないのか、
    /// 置いてあっても表に無い大きさなのか（画面の表示を拡大しているときなど）を分けて伝えるため。
    @Test("記録から読むラベルの有無は、まだ置いていない・表に無い大きさ・見分けた、の 3 通り")
    func iconStyleReadingFromTheRecord() {
        let labeledLarge = Self.reload(.large, size: CGSize(width: 349.67, height: 365))
        let zoomedLarge = Self.reload(.large, size: CGSize(width: 320, height: 335))
        let labelFreeMedium = Self.reload(.medium, size: CGSize(width: 359.67, height: 169.67))
        let small = Self.reload(.small, size: CGSize(width: 164.33, height: 164.33))
        let beforeSizes = Self.reload(.large, size: nil)
        #expect(Self.reading([]) == .notYetPlaced)
        // 小だけ、または大きさを残す前（3-3 より前）の記録だけなら、まだ分からない
        #expect(Self.reading([small, beforeSizes]) == .notYetPlaced)
        #expect(Self.reading([zoomedLarge]) == .unknownSize)
        #expect(Self.reading([labeledLarge]) == .detected(.labeled))
        #expect(Self.reading([labeledLarge]).style == .labeled)
        #expect(Self.reading([zoomedLarge]).style == nil)
        // 大が表に無い大きさでも、中で見分けられれば、それを使う
        #expect(Self.reading([zoomedLarge, labelFreeMedium]) == .detected(.labelFree))
    }
}
