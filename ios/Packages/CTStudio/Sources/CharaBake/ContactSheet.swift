import Foundation
import CoreGraphics
import CTCore
import CTStore
import CTStudio

/// 確かめのコンタクトシート（プラン §6.4・§6.5、Gate 2 の「全キャラ × 全コマ」）。
///
/// hero は枠と補助線の上に、mini は暗い地の上に（縁のにじみを見る。§6.5）、小さな姿は枠の高さ 40pt・24pt（@3x）で
/// 並べる（小ウィジェットと Dynamic Island の大きさで、誰か・何をしているかが読めるか。§5.1）。
enum ContactSheet {

    /// 1 コマぶん（名前と絵）。
    struct Cell {
        let label: String
        let hero: CGImage
        /// mini（全キャラの一覧では描かない）。
        let mini: CGImage?
    }

    /// 1 体ぶん: hero（半分の大きさ）・mini（等倍、暗い地）・40pt と 24pt の姿を、コマごとに縦に並べる。
    static func character(_ id: String, result: StudioResult, geometry: BundledCatalog.Geometry) -> Raster? {
        let cells = Self.cells(of: result)
        let layout = CharacterSheetLayout(columns: cells.count)
        var canvas = Raster(width: layout.width, height: layout.height)
        let drawn = canvas.draw { context in
            let board = Board(context: context, height: CGFloat(layout.height))
            board.fill(CGRect(x: 0, y: 0, width: layout.width, height: layout.height), Palette.paper)
            board.label("\(id)　hero（1/2）・mini（等倍、暗い地）・枠の高さ 40pt と 24pt（@3x）",
                        at: layout.titleBaseline, size: CharacterSheetLayout.titleSize)
            board.fill(layout.darkBand, Palette.dark)
            board.fill(layout.smallBand, Palette.room)
            for (column, cell) in cells.enumerated() {
                draw(cell, column: column, layout: layout, board: board, groundRatio: geometry.groundRatio)
            }
        }
        return drawn ? canvas : nil
    }

    static func draw(_ cell: Cell, column: Int, layout: CharacterSheetLayout, board: Board,
                     groundRatio: Double) {
        board.label(cell.label, at: layout.labelBaseline(column), size: CharacterSheetLayout.labelSize)
        board.frame(cell.hero, in: layout.hero(column), groundRatio: groundRatio)
        if let mini = cell.mini { board.draw(mini, in: layout.mini(column)) }
        board.draw(cell.hero, in: layout.small(column, heightPoints: CharacterSheetLayout.largeSmallPoints))
        board.draw(cell.hero, in: layout.small(column, heightPoints: CharacterSheetLayout.smallestPoints))
    }

    /// コマの並び（姿勢の順。アプリが作ったまばたき・寝息と、予備のコマに印を付ける）。
    static func cells(of result: StudioResult) -> [Cell] {
        let frames = Pose.allCases.flatMap { pose in
            (result.frames[pose] ?? []).enumerated().compactMap { index, frame -> Cell? in
                guard let hero = frame.hero.cgImage else { return nil }
                return Cell(label: frameLabel(pose, index), hero: hero, mini: frame.mini.cgImage)
            }
        }
        let spares = Pose.allCases.compactMap { pose -> Cell? in
            guard let frame = result.spares[pose], let hero = frame.hero.cgImage else { return nil }
            return Cell(label: "\(pose.rawValue) 予備", hero: hero, mini: frame.mini.cgImage)
        }
        return frames + spares
    }

    /// コマの名前（`idle_02 まばたき` の形）。
    static func frameLabel(_ pose: Pose, _ index: Int) -> String {
        let name = String(CharacterImageName.frame(pose, index, kind: .hero).dropFirst("hero/".count))
        switch (pose, index) {
        case (.idle, 1), (.sit, 1): return name + " まばたき"
        case (.sleep, 1): return name + " 寝息"
        default: return name
        }
    }

    /// PNG に書く（フォルダが無ければ作る）。
    static func write(_ raster: Raster?, to url: URL) throws(BakeError) -> URL {
        guard let data = raster?.pngData() else {
            throw .writeFailed(url.path(percentEncoded: false), "コンタクトシートを描けません")
        }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: url)
        } catch {
            throw .writeFailed(url.path(percentEncoded: false), error.localizedDescription)
        }
        return url
    }
}

/// 1 体ぶんのコンタクトシートの割り付け（上からの座標）。
struct CharacterSheetLayout {

    static let heroScale = 0.5
    static let titleSize: CGFloat = 22
    static let labelSize: CGFloat = 13
    /// 小ウィジェットの大きさ（枠の高さ、pt）。§5.1 の「40pt で誰か分かる」。
    static let largeSmallPoints: CGFloat = 40
    /// Dynamic Island のコンパクト表示の大きさ（枠の高さ、pt）。§5.1 の「24pt」。
    static let smallestPoints: CGFloat = 24
    /// @3x の画素と pt の比。
    static let pixelsPerPoint: CGFloat = 3
    static let margin: CGFloat = 24
    static let gap: CGFloat = 16
    static let titleHeight: CGFloat = 40
    static let labelHeight: CGFloat = 22

    let columns: Int

    var heroSize: CGSize {
        CGSize(width: CGFloat(FrameGeometry.hero.width) * Self.heroScale,
               height: CGFloat(FrameGeometry.hero.height) * Self.heroScale)
    }
    var miniSize: CGSize { CGSize(width: FrameGeometry.mini.width, height: FrameGeometry.mini.height) }
    var columnWidth: CGFloat { max(heroSize.width, miniSize.width) + Self.gap }
    var heroTop: CGFloat { Self.margin + Self.titleHeight + Self.labelHeight }
    var darkBand: CGRect {
        CGRect(x: 0, y: heroTop + heroSize.height + Self.gap, width: CGFloat(width),
               height: miniSize.height + Self.gap * 2)
    }
    var smallBand: CGRect {
        CGRect(x: 0, y: darkBand.maxY + Self.gap, width: CGFloat(width),
               height: Self.largeSmallPoints * Self.pixelsPerPoint + Self.gap * 2)
    }
    var width: Int { Int((Self.margin * 2 + columnWidth * CGFloat(columns)).rounded(.up)) }
    var height: Int { Int((smallBand.maxY + Self.margin).rounded(.up)) }
    var titleBaseline: CGPoint { CGPoint(x: Self.margin, y: Self.margin + Self.titleSize) }

    func left(_ column: Int) -> CGFloat { Self.margin + columnWidth * CGFloat(column) }

    func labelBaseline(_ column: Int) -> CGPoint {
        CGPoint(x: left(column), y: heroTop - Self.labelHeight / 3)
    }

    func hero(_ column: Int) -> CGRect {
        CGRect(origin: CGPoint(x: left(column), y: heroTop), size: heroSize)
    }

    func mini(_ column: Int) -> CGRect {
        CGRect(origin: CGPoint(x: left(column), y: darkBand.minY + Self.gap), size: miniSize)
    }

    /// 枠の高さ `points`（pt）の姿の大きさ（@3x の画素）。
    static func smallSize(points: CGFloat) -> CGSize {
        let height = points * pixelsPerPoint
        return CGSize(width: height * CGFloat(FrameGeometry.hero.width) / CGFloat(FrameGeometry.hero.height),
                      height: height)
    }

    /// 枠の高さ `heightPoints`（@3x）の姿。40pt を左に、24pt をその右に、足元をそろえて置く。
    func small(_ column: Int, heightPoints: CGFloat) -> CGRect {
        let size = Self.smallSize(points: heightPoints)
        let large = Self.smallSize(points: Self.largeSmallPoints)
        let shift = heightPoints == Self.largeSmallPoints ? 0 : large.width + Self.gap
        let origin = CGPoint(x: left(column) + shift, y: smallBand.maxY - Self.gap - size.height)
        return CGRect(origin: origin, size: size)
    }
}
