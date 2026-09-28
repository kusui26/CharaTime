import Foundation
import CoreGraphics
import ImageIO
import CTCore
import CTStore
import CTStudio

/// 全キャラ × 全コマのコンタクトシート（Gate 2 の確かめ方「コンタクトシート（全キャラ × 全コマ）」）。
///
/// キャラごとに、`final/` があればそれ（整えたがまだ Asset Catalog に入れていない絵も見られる）、無ければいまの絵
/// （Asset Catalog の @3x）を並べる。下に、どの子も立ち姿を枠の高さ 40pt・24pt（@3x）で並べ、見分けがつくかを見る。
enum CatalogSheet {

    struct Row {
        let id: String
        /// 絵の出どころ（`final/` か、いまの絵か）。
        let source: String
        let cells: [ContactSheet.Cell]
    }

    /// 全キャラの行（`characters.json` の順）。
    static func rows(_ repository: Repository, catalog: BundledCatalog) throws(BakeError) -> [Row] {
        var rows: [Row] = []
        for character in catalog.characters {
            let final = repository.finalFolder(of: character.id)
            let useFinal = FileManager.default.fileExists(atPath: final.path(percentEncoded: false))
            var cells: [ContactSheet.Cell] = []
            for pose in Pose.allCases {
                for (index, name) in (character.poses[pose] ?? []).enumerated() {
                    let finalFile = CharacterImageName.frame(pose, index, kind: .hero) + ".png"
                    let url = useFinal ? final.appending(path: finalFile) : repository.bundledImage(name)
                    cells.append(ContactSheet.Cell(label: ContactSheet.frameLabel(pose, index),
                                                   hero: try image(at: url), mini: nil))
                }
            }
            rows.append(Row(id: character.id, source: useFinal ? "final/" : "いまの絵", cells: cells))
        }
        return rows
    }

    static func image(at url: URL) throws(BakeError) -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw .unreadable(url.path(percentEncoded: false), "画像として読めません")
        }
        return image
    }

    static func render(_ rows: [Row], groundRatio: Double) -> Raster? {
        let layout = CatalogSheetLayout(rows: rows.count, columns: rows.map(\.cells.count).max() ?? 0)
        var canvas = Raster(width: layout.width, height: layout.height)
        let drawn = canvas.draw { context in
            let board = Board(context: context, height: CGFloat(layout.height))
            board.fill(CGRect(x: 0, y: 0, width: layout.width, height: layout.height), Palette.paper)
            board.label("全キャラ × 全コマ（hero の 1/3。赤 = 足元・青 = 接地線・緑 = 横の中央）",
                        at: layout.titleBaseline, size: CharacterSheetLayout.titleSize)
            for (column, cell) in (rows.first?.cells ?? []).enumerated() {
                board.label(cell.label, at: layout.headerBaseline(column),
                            size: CharacterSheetLayout.labelSize)
            }
            for (index, row) in rows.enumerated() {
                draw(row, index: index, layout: layout, board: board, groundRatio: groundRatio)
            }
            drawSmall(rows, layout: layout, board: board)
        }
        return drawn ? canvas : nil
    }

    static func draw(_ row: Row, index: Int, layout: CatalogSheetLayout, board: Board, groundRatio: Double) {
        board.label(row.id, at: layout.rowTitleBaseline(index), size: CharacterSheetLayout.titleSize)
        board.label(row.source, at: layout.rowSourceBaseline(index), size: CharacterSheetLayout.labelSize)
        for (column, cell) in row.cells.enumerated() {
            board.frame(cell.hero, in: layout.frame(row: index, column: column), groundRatio: groundRatio)
        }
    }

    /// どの子も、立ち姿を枠の高さ 40pt と 24pt で横に並べる（見分けがつくか。§5.1）。
    static func drawSmall(_ rows: [Row], layout: CatalogSheetLayout, board: Board) {
        board.fill(layout.smallBand, Palette.room)
        board.label("立ち姿を枠の高さ 40pt・24pt（@3x）で", at: layout.smallTitleBaseline,
                    size: CharacterSheetLayout.labelSize)
        for (index, row) in rows.enumerated() {
            guard let standing = row.cells.first?.hero else { continue }
            board.draw(standing, in: layout.small(index, heightPoints: CharacterSheetLayout.largeSmallPoints))
            board.draw(standing, in: layout.small(index, heightPoints: CharacterSheetLayout.smallestPoints))
        }
    }
}

/// 全キャラ × 全コマのコンタクトシートの割り付け（上からの座標）。
struct CatalogSheetLayout {

    static let frameScale = 1.0 / 3
    static let margin: CGFloat = 24
    static let gap: CGFloat = 10
    /// 行の頭の、キャラの名前の欄の幅。
    static let titleColumn: CGFloat = 150
    static let headerHeight: CGFloat = 60
    static let rowGap: CGFloat = 24

    let rows: Int
    let columns: Int

    var frameSize: CGSize {
        CGSize(width: CGFloat(FrameGeometry.hero.width) * Self.frameScale,
               height: CGFloat(FrameGeometry.hero.height) * Self.frameScale)
    }
    var columnStep: CGFloat { frameSize.width + Self.gap }
    var framesLeft: CGFloat { Self.margin + Self.titleColumn }
    var framesTop: CGFloat { Self.margin + Self.headerHeight }
    var rowStep: CGFloat { frameSize.height + Self.rowGap }
    var smallBand: CGRect {
        let large = CharacterSheetLayout.smallSize(points: CharacterSheetLayout.largeSmallPoints)
        return CGRect(x: 0, y: framesTop + rowStep * CGFloat(rows), width: CGFloat(width),
                      height: large.height + Self.headerHeight)
    }
    var width: Int { Int((framesLeft + Self.margin + columnStep * CGFloat(columns)).rounded(.up)) }
    var height: Int { Int((smallBand.maxY + Self.margin).rounded(.up)) }
    var titleBaseline: CGPoint { CGPoint(x: Self.margin, y: Self.margin + CharacterSheetLayout.titleSize) }
    var smallTitleBaseline: CGPoint {
        CGPoint(x: Self.margin, y: smallBand.minY + CharacterSheetLayout.titleSize)
    }

    func left(_ column: Int) -> CGFloat { framesLeft + columnStep * CGFloat(column) }

    func headerBaseline(_ column: Int) -> CGPoint { CGPoint(x: left(column), y: framesTop - Self.gap) }

    func frame(row: Int, column: Int) -> CGRect {
        CGRect(origin: CGPoint(x: left(column), y: framesTop + rowStep * CGFloat(row)), size: frameSize)
    }

    func rowTitleBaseline(_ row: Int) -> CGPoint {
        CGPoint(x: Self.margin, y: framesTop + rowStep * CGFloat(row) + frameSize.height / 2)
    }

    func rowSourceBaseline(_ row: Int) -> CGPoint {
        CGPoint(x: Self.margin, y: rowTitleBaseline(row).y + CharacterSheetLayout.titleSize)
    }

    /// その子の小さな姿（40pt を左に、24pt をその右に、足元をそろえて置く）。
    func small(_ index: Int, heightPoints: CGFloat) -> CGRect {
        let large = CharacterSheetLayout.smallSize(points: CharacterSheetLayout.largeSmallPoints)
        let size = CharacterSheetLayout.smallSize(points: heightPoints)
        let start = framesLeft + (large.width * 2 + Self.gap * 3) * CGFloat(index)
        let shift = heightPoints == CharacterSheetLayout.largeSmallPoints ? 0 : large.width + Self.gap
        let origin = CGPoint(x: start + shift, y: smallBand.maxY - Self.gap - size.height)
        return CGRect(origin: origin, size: size)
    }
}
